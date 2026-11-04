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

`sh build.sh <platform> all` makes a deploy build, because it ends with `build.sh <platform> deploy`. So testing local backends needs the separate steps, as in `test/build-client.sh`.

### Quitting from a handler

`QCoreApplication::exit()` emits `aboutToQuit` right away in Qt 6.10, and `WControllerApplicationPrivate::onAboutToQuit` then deletes every controller. Calling it from a query signal crashes when the stack unwinds, as `WControllerPlaylistPrivate::onLoaded` goes on to `delete data` after `setQueryDefault()`. Only failed requests reach this path, since success paths have nothing left to do.

clientVBML crashed this way (exit code 139) on failed queries. It now defers the exit to the event loop. Scripts should do the same with `Qt.callLater(sk.quit)`. `test/failure.sh` covers this using a local port, without leaving the machine.

### Testing notes

- qmake replaces the word `debug` in `DESTDIR` under `debug_and_release`, so a custom output folder can't have that word in its name.
- A VPN or a filtering network makes blocked sites look like backend failures. All baselines have to come from an unfiltered network.
- The first launch of a freshly built clientVBML is slower, 9.6 s against 4.5 s for the same query, and maybe security software scanning it. After a rebuild, the first run can time out on a few cases and is worth rerunning.
- Not explained yet: on Twitch live channels, clientVBML sometimes leaves the track out of its output while the sources come through, so `TRACK LIVE` can pass on the title of the hub playlist.
- Not explained yet: `sky` logs `ControllerCore::loadData: Failed to load .../bin/bin/skz/run/mport.sky` when running a script that starts with `import`. It looks like `import` gets misread, and playback still works.

## State of the backends

From `sh test/all.sh stream` and `sh test/all.sh play`, 2026-11-04, on backends close to public `master` 984d9f4, with 10 s of playback. The cases come from `clientVBML/test`, and most date from 2025, so a failure can also mean a stale URL. Failures are not diagnosed yet.

| Backend | Queries passing | Failing | Streams and playback |
| --- | --- | --- | --- |
| youtube | 13/13 | | Streams valid. 4K60 and 1080p60 play at 1.00x with no buffering |
| youtubemusic | 8/8 | | Metadata only, tracks play through `youtube` |
| tmdb | 10/10 | | Metadata only |
| twitch | 8/8 | | HLS valid. Plays at 1.00x with no buffering |
| peertube | 6/6 | | Streams valid. Blocked on some filtering networks |
| duckduckgo | 6/6 | | `SEARCH SITE` fails now and then, it may be rate limiting |
| dailymotion | 5/5 | | HLS valid. Plays at 1.01x with no buffering |
| twitter | 1/1 | | Stream valid, title and cover only |
| iptv | 1/1 | | |
| odysee | 1/1 | | Stream returns HTTP 401 to curl, it may need a header |
| soundcloud | 6/6 | | Streams valid |
| vimeo | 1/2 | `TRACK`, no sources | Cannot play |
| facebook | 1/3 | `TRACK` no sources, `RELATED` | See below |
| tiktok | 0/1 | `TRACK` varies | See below |
| opensubtitles | 1/1 | | |

One kind of noise to know about when reading a run: during one stretch of a few minutes every query was slow enough to time out, including a local port. Right after that, 17 parallel runs of the same query were stable at about 5.3 s, so load does not explain it, and the cause is unknown. A surprising result is worth rerunning once.

### On GitHub's servers

First two CI runs, 2026-11-04: `clientVBML` builds in about 6 minutes and the tests take 44 s. 53 of 78 cases pass. The differences with the table above:

- **youtube:** all 7 `TRACK` cases have no sources in both runs, while feeds, search and related pass. YouTube refuses the player request from GitHub's servers: `sh test/ci.sh measure` from the Actions tab gets `LOGIN_REQUIRED`, "Sign in to confirm you're not a bot", while the watch page still works. So YouTube sources and playback can only be tested from a home connection.

  The watch page it serves there has no `videoDetails`, and `EXTRACT_TRACK` then returns wrong metadata: for `aqz-KE-bpKQ` the title is `"simpleText":"Big Buck Bunny...` and the author is `@randmstrnger176`, which looks like a commenter rather than the channel. The feed is empty, and there is no cover, duration or date. Local runs are clean, so this should only affect networks YouTube flags. Since 1.0.131, `EXTRACT_TRACK` returns no metadata when `channelId` is missing from `videoDetails`.
- **twitch:** `TRACK LIVE` crashed clientVBML once with exit code 139, and passes locally. The cause is not known.

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

From one run of `sh test/measure-youtube.sh`, on `aqz-KE-bpKQ`, 2026-11-04, compressed size.

A track costs 3 requests on first play: `sw.js_data` for `visitorData` (the watch page until 1.0.130), a WEB player request for the metadata (the watch page until 1.0.132), and the VISIONOS player request. In `sh test/youtube.sh` that took tracks from about 2.1 to 2.8 s, to 1.2 to 1.9 s with `sw.js_data`, and to about 0.6 s with the metadata request, in one run each. Builds with `SK_NO_TORRENT`, which are clientVBML and the iOS apps, used to send the metadata request twice because of a bug in `WPlaylistPrivate::applyTrack`, so every backend's track took one more request.

| Step | Before | Now |
| --- | --- | --- |
| `visitorData` | watch page, 319 KB, 0.69 s | `sw.js_data`, 1.5 KB, 0.13 s |
| VISIONOS player POST | 13.4 KB, 0.17 s | Same. `$fields=playabilityStatus,streamingData,videoDetails` would make it 6.9 KB |
| Track metadata | watch page, 319 KB, plus a 1 s spacing delay | WEB player with `$fields`, 571 bytes, 0.18 s |

- **`visitorData` is required:** VISIONOS returns `LOGIN_REQUIRED` without it.
- **Fallback:** if the value from `sw.js_data` doesn't work, the player answers `LOGIN_REQUIRED` and the backend gets a new one from the watch page. Tested by pointing it at another URL: it costs 2 more requests, and metadata and sources stay correct.
- **ANDROID:** it also works without `signatureTimestamp`, in `sh test/measure-youtube.sh`. clientVBML can't reach safe mode, so the backend path itself is not tested.
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

### Metadata from the player request

The WEB client answers `UNPLAYABLE`, and still returns the title, author, channel, duration, date, live flag and thumbnails, in about 1.2 KB. Three things to know:

- The thumbnails depend on the user agent: a Chrome one gets `.webp`, the Safari one gets `.jpg`.
- The largest thumbnail can have a `?sqp=` parameter that gives a smaller image, so the backend removes it. 6 of 7 test covers stay byte-identical, the 7th is 68.5 KB against 69.7 KB.
- A live video now gets `type: live`. It got `track` from the watch page, because the check for `hlsManifestUrl` no longer matched there.

On a network YouTube flags the request is refused, and there is no metadata, which is also what the watch page gives since 1.0.131.

### Live

Live sources come from a second request with the ANDROID client. `sh test/measure-youtube-live.sh` shows why: the VISIONOS manifest is `demuxed/1`, with video only and separate audio tracks, and the ANDROID one has both together. Skipping that request would save about 0.15 s, for parsing and syncing separate audio, so the backend keeps it. A live video plays 60 s at 1.00x with no buffering.

### Known issues in youtube.vbml 1.0.132

- The comment above the `UNPLAYABLE` fallback mentions `ANDROID_VR`, and the code uses ANDROID.

## Other sites

- **Dailymotion:** 2 source requests. `"380"` is not a known quality key, so it becomes the default quality. No `expiry`.
- **Vimeo:** sources are blocked from VBML for now, metadata and feeds work. With `sh test/measure-vimeo.sh`, 2026-11-04: the API `download` field was empty on all 5 public videos tried that exist, and `play`, `files` and `config_url` are empty for the viewer token. `player.vimeo.com` answers 403 from Cloudflare to curl and to the engine, and the video page has no `config_url`. yt-dlp gets through with TLS impersonation, which scripts can't do, or with saved login tokens.
- **Twitch:** 2 source requests, GQL playback token then usher m3u8. No `expiry`. Video metadata comes from GQL since 1.0.31: `sh test/measure-twitch.sh` gets 437 bytes and 0 of 10 failures where the page was 80 KB and came back empty 1 time in 10, which made the backend retry up to 10 times. Channels use GQL too since 1.0.33: their page lists clips as `VideoObject`, so the backend took any channel with clips as live, with the clip description in the title and a broken feed.

- **SoundCloud:** the user `uri` now holds `soundcloud%3Ausers%3A<id>`, and the API answers an error for that form. The backend removes the prefix since 1.0.12.
- **Facebook:** `dash_mpd_debug.mpd` answers HTTP 500 on all the videos tried, including those of the yt-dlp tests, and the page of a video has none of the source fields yt-dlp looks for without a login. When the page is generic, the backend also returns wrong metadata, like the title "Discover Popular Videos".
- **Last.fm:** removed in index 1.0.299. Every page answered a 3 KB challenge page, and its API needs a key. Youtube Music replaces it, for music search and audio covers.
- **Youtube Music:** InnerTube `search` and `browse` on `music.youtube.com` with `WEB_REMIX`, no key needed. The `params` of a search pick songs, albums or artists. Tracks point at `www.youtube.com/watch?v=`, so playback, metadata and related stay with `youtube`. An album takes 1 request, and its tracks have no thumbnail of their own, so they get the album cover. An artist takes 2, because its page only lists the top songs, with a `VL` playlist for the rest when there is one. Thumbnails hold their size, so `w60-h60` can become `w544-h544`. Links to `music.youtube.com/watch` are not handled. From `sh test/youtubemusic.sh`, 2026-11-04: 0.6 to 1.2 s per query.
- **IPTV:** iptv-org moved the logos out of `channels.json` to `logos.json`, 846 KB, so a search takes a third request since 1.0.10. About 1.4% of the logos are SVG, which may not display. A search matches channel ids, so `cnn` also finds `RCNNovelas`.
- **TikTok:** unreliable for now, see below.

### TikTok

The backend uses the app API, and it fails often. We left it there for now, because the proper fix needs engine changes. All of this comes from `sh test/measure-tiktok.sh`, 2026-11-04.

| Route | Result |
|---|---|
| App API (`api16`), what the backend uses | HTTP 429 on 3 of 5 tries. It can also answer a generic feed of 300 to 600 KB without the requested video |
| Web page | Metadata and `playAddr` in 406 KB, with the plain engine user agent |
| `oembed` | 543 bytes, title and author, no stream |
| `player/v1`, `embed/v2` | No `playAddr` |

A stream from the web page depends on how it's requested:

| Request | Result |
|---|---|
| Alone, or with a `Referer` | HTTP 403 |
| ffprobe with `-cookies` | HTTP 403 |
| curl with the page's cookies | HTTP 206 |
| ffprobe with `-headers` holding `Cookie` and `Referer` | Opens, `h264 aac` |

The backend plays the first video of whatever comes back, so a generic feed plays the wrong video. Checking the id stops that, but TikTok then fails most of the time: sources came through on 2 of 8 tries. That isn't a real fix, so the backend stays as it is until the web route is done.

The proper fix is the web route:

1. In the engine, let scripts read the cookies a response sets. Scripts only see `data` today, and `cookies` only turns on the engine's own jar.
2. In the engine, let `WFfmpegPlayer` apply request headers from `options`. They already reach its `setSource`, which ignores them, and `WBackendVlc` would need its own check.
3. In the backend, read sources and metadata from the web page, and set a short `expiry`.

Open questions: how long the cookies last, whether they're tied to the IP, how seeking behaves, and whether some users get a challenge page, since yt-dlp has code to solve one. It also costs a 406 KB page per play.

### Twitch live ads

Twitch stitches ads into the live playlist, and they depend on the `playerType` of the token request. Measured 2026-11-04 with `sh test/measure-twitch-ads.sh`: `site` had ad markers on 5 of 6 channels, with 3 segments in the playlist. `embed`, `popout` and `frontpage` had none on all 6, with 15 segments and the same qualities.

The backend uses `embed` since 1.0.32. `sh test/twitch-live.sh` got 0 markers on 9 live channels, and 5 of them played 15 s at 1.00x with no buffering, and `esl_sc2` played 60 s. This is a snapshot near the start of a stream, ad breaks later in a stream are not tested, and Twitch can change this at any time.

## Engine proposals

Suggestions only.

- Persist `global` across process starts, to remove the first play `visitorData` request.
- Allow parallel requests in source flows, to race clients.
- Expose response status and headers to scripts.
- Expose download speed on the player, for playback tests.
- For TikTok web streams: let scripts read the cookies a response sets, and let `WFfmpegPlayer` apply request headers from `options`. See the TikTok section.
