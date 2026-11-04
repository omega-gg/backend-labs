# Implementation notes

Technical findings on reaching video bytes quickly from VBML. Numbers are measurements unless marked otherwise, with their date and sample size, because these sites change often.

## VBML engine

### Limits that shape a backend

| Limit | Value | Source |
| --- | --- | --- |
| Statements per routine | 300, the script is rejected above that | `WBackendUniversal.cpp` |
| `FOREACH` nesting | 3 levels | `WBackendUniversal.cpp` |
| Chained requests | 100 | `WControllerMedia.cpp` |
| `reload` retries | 10 | `WControllerMedia.cpp` |
| `JS_CALL` | new engine per call, 5 s limit, string arguments, no `fetch` | `WBackendUniversal.cpp` |

- A routine sets `url`, the engine downloads it, and the script gets the whole body as `data`. A script cannot stream or stop a response early, so response size is a direct cost.
- Source flows follow only the first next query, so a source flow cannot race two clients.
- Scripts see `data`, `url` and `urlRedirect`, but no status or response headers. `skipError` delivers error bodies.
- There is no JSON parser. `JSON_EXTRACT` is a text search and can match a value reading `"name"`.
- A non-empty `body` makes a POST. A non-null empty `header` sends a GET and drops the body.
- `global` lives in memory per backend, so it is lost on every process start. `reload()` does not clear it.
- `DATE` is in seconds. `expiry` is an absolute time in seconds.
- `# VBML x.y.z` on the first line is the effective API version. The `api:` key is never read.

### Quality selection

`medias` and `audios` are hashes keyed by `144` through `2160`. Any other key becomes the default quality. The player picks the exact quality, then the nearest lower, then the nearest higher.

### Version propagation

- **Releasing a backend change:** bump its `version:`, update its row in `index.vbml`, bump the index `version:`, run `dist/generateLite.sh`.
- **Comparison:** rows are compared with equality, not order, so a downgrade propagates too.
- **Testing trap:** a row that differs from the file's `version:`, or from the stored index, downloads the file from GitHub `master` over the local copy, even in dev builds.
- **Index rows:** a row with a space in any field is silently dropped, because it must split into exactly 4 values.

### Where apps load backends

| Build | Behavior |
| --- | --- |
| Dev (`SK_BACKEND_LOCAL`) | Copies `<exe dir>/../../backend` to storage on every start, without an index update. MotionBox, MotionMonkey, tevolution and Sky-runtime also watch that folder and reload |
| Deploy (`SK_DEPLOY`) | Copies the bundled `backend` on first run, then updates from GitHub `master` |

There is no command line or environment override. Tests therefore run in a copied folder layout.

### Quitting from a handler

`QCoreApplication::exit()` emits `aboutToQuit` right away in Qt 6.10, and `WControllerApplicationPrivate::onAboutToQuit` then deletes every controller. Calling it from a query signal crashes when the stack unwinds, as `WControllerPlaylistPrivate::onLoaded` goes on to `delete data` after `setQueryDefault()`. Only failed requests reach this path, since success paths have nothing left to do.

clientVBML crashed this way (exit code 139) on failed queries. It now defers the exit to the event loop. Scripts should do the same with `Qt.callLater(sk.quit)`. `test/failure.sh` covers this using a local port, without leaving the machine.

### Testing notes

- qmake replaces the word `debug` in `DESTDIR` under `debug_and_release`, so a custom output folder can't have that word in its name.
- A VPN or a filtering network makes blocked sites look like backend failures. All baselines have to come from an unfiltered network.
- Not explained yet: `sky` logs `ControllerCore::loadData: Failed to load .../bin/bin/skz/run/mport.sky` when running a script that starts with `import`. It looks like `import` gets misread, and playback still works.

## State of the backends

From `sh test/all.sh stream` and `sh test/all.sh play`, 2026-11-04, on backends unchanged from public `master` 984d9f4, with 10 s of playback. The cases come from `clientVBML/test`, and most date from 2025, so a failure can also mean a stale URL. Failures are not diagnosed yet.

| Backend | Queries passing | Failing | Streams and playback |
| --- | --- | --- | --- |
| youtube | 13/13 | | Streams valid. 4K60 and 1080p60 play at 1.00x with no buffering |
| tmdb | 10/10 | | Metadata only |
| twitch | 7/7 | | HLS valid. Plays at 1.00x with no buffering |
| peertube | 6/6 | | Streams valid. Blocked on some filtering networks |
| duckduckgo | 6/6 | | `SEARCH SITE` fails now and then, it may be rate limiting |
| dailymotion | 5/5 | | HLS valid. Plays at 1.01x with no buffering |
| twitter | 1/1 | | Stream valid, title and cover only |
| iptv | 1/1 | | |
| odysee | 1/1 | | Stream returns HTTP 401 to curl, it may need a header |
| soundcloud | 5/6 | `FEED`, HTTP 302 on its API | Streams valid |
| vimeo | 1/2 | `TRACK`, no sources | Cannot play |
| facebook | 1/3 | `TRACK` HTTP 401, `RELATED` | |
| lastfm | 1/5 | `FEED`, `RELATED`, `SEARCH TRACKS`, `COVER` | |
| tiktok | 0/1 | `TRACK`, HTTP 299 on its API | |
| opensubtitles | 0/1 | `SEARCH SUBTITLES`, no entries | |
| vox | 0/7 | Connection times out | |

Two kinds of noise to know about when reading a run. `twitch TRACK` varies in its request count, probably because its backend retries on an empty channel page. And during one stretch of a few minutes every query was slow enough to time out, including a local port. Right after that, 17 parallel runs of the same query were stable at about 5.3 s, so load does not explain it, and the cause is unknown. A surprising result is worth rerunning once.

## YouTube

### Clients

Client landscape on 2026-11-04, from yt-dlp, NewPipeExtractor and YoutubeExplode.

| Client | Version | JS needed | PO token for streams | Notes |
| --- | --- | --- | --- | --- |
| VISIONOS | 1.04 (NewPipe), 1.02 (others) | no | no | The only no JS, no token client. All three projects rely on it. No made-for-kids videos |
| ANDROID | 21.26.364 | no | yes, except itag 18 | Kids fallback in YoutubeExplode, with one muxed itag 18 |
| IOS | 21.26.4 | no | yes | |
| ANDROID_VR | 1.65.10 | no | yes | Returning 403 on all formats since 2026-08-17 |
| TVHTML5 (samsung) | 5.20260707 | yes | no | Default in yt-dlp since 2026-10-10 |

VISIONOS is a single point of failure. `android_vr` went from working to 403 in a day. `pull.sh` reports upstream changes to client definitions so that we notice early.

VISIONOS responses have direct `url` fields with no `signatureCipher` and no `n`, so no JS is needed for ordinary public videos. They have no muxed formats (`formats` was empty in the 17 playable recordings in NewPipeExtractor, and in our 2 samples) and no `microformat`, so no upload date.

### First play cost

From one run of `sh test/measure-youtube.sh`, on `aqz-KE-bpKQ`, 2026-11-04, compressed size. To be confirmed through the engine.

clientVBML logs 4 requests for a YouTube track and 6 for a live one, with the watch page requested 3 times. It asks for the track and the media at once, so part of this may not apply to the players.

| Step | Today | Candidate |
| --- | --- | --- |
| `visitorData` | watch page, 319 KB, 0.69 s | `sw.js_data`, 1.5 KB, 0.13 s |
| VISIONOS player POST | 13.4 KB, 0.17 s | `$fields=playabilityStatus,streamingData,videoDetails`, 6.9 KB, 0.17 s |
| Track metadata | watch page, 319 KB, plus a 1 s spacing delay | WEB player with `$fields`, 571 bytes, 0.18 s |

- **`visitorData` is required:** VISIONOS returns `LOGIN_REQUIRED` without it.
- **Not needed for VISIONOS:** `signatureTimestamp` and `html5Preference`, the script sends neither.
- **In `sw.js_data`:** the value is at `[0][2][0][0][13]`, after stripping the `)]}'` prefix.
- **Client version:** both 1.02, in `youtube.vbml`, and 1.04, in the script, work with the Safari user agent.
- **Check `videoDetails.videoId`:** yt-dlp and NewPipeExtractor both report YouTube substituting another video when rate limiting an IP.

### Throttling

From one run of `sh test/measure-youtube.sh`, on `aqz-KE-bpKQ`, 2026-11-04. The 10 MB range rates are probably limited by the local connection. `sh test/youtube.sh throttle` checks the streams a backend actually returns.

| Stream | Needs | Open-ended GET, 15 s | 10 MB range |
| --- | --- | --- | --- |
| itag 299 (avc1, 1080p60) | 405 kB/s | 789 kB/s | 10343 kB/s |
| itag 140 (mp4a) | 16 kB/s | 31 kB/s | 10391 kB/s |

Open-ended requests are paced at about 2x playback rate, and 10 MB ranges are not. `WFfmpegPlayer.cpp` already requests 10 MB at a time for this reason. Whether the VLC path chunks too is not verified.

### Format selection

`youtube.vbml` returns AV1 at every quality for regular videos, even where AVC exists at 720p and 1080p, because the last mp4 entry for a quality wins and AV1 comes after AVC. `sh test/youtube.sh stream` shows the codec. Live streams are H.264.

This does not hurt on the test machine: `sh test/youtube.sh play` gives 1.00x with no buffering at 4K60 and 1080p60. Machines without AV1 hardware decoding are not tested.

### Known issues in youtube.vbml 1.0.128

- `SET expiry (ADD (DATE) 60) # Two hours` caches sources for 60 seconds.
- Live in default mode refetches with ANDROID, costing 3 to 4 requests.
- The comment above the `UNPLAYABLE` fallback mentions `ANDROID_VR`, and the code uses ANDROID.

## Other sites

Found by reading the backends and yt-dlp, not yet measured.

- **Dailymotion:** 2 source requests. `"380"` is not a known quality key, so it becomes the default quality. No `expiry`.
- **Vimeo:** 2 source requests on first play, then 1. Uses only the API `download` field, so videos without downloads have no sources. yt-dlp's `player.vimeo.com` route can need TLS impersonation, which scripts cannot do.
- **Twitch:** 2 source requests, GQL playback token then usher m3u8. No `expiry`. The channel page sometimes returns empty and forces `reload`.

## Engine proposals

Suggestions only.

- Persist `global` across process starts, to remove the first play `visitorData` request.
- Allow parallel requests in source flows, to race clients.
- Expose response status and headers to scripts.
- Expose download speed on the player, for playback tests.
