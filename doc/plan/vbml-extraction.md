# backend-labs: high performance VBML backends

## Context

The public extractors (yt-dlp, NewPipeExtractor, YoutubeExplode) aim to be compatible and to list everything. Our players (MotionBox, MotionMonkey, tevolution, tevo, Sky-runtime) need the opposite: reach the video bytes as fast as possible, with only the sources and metadata we use.

backend-labs mines those projects, updates the VBML backends gradually under `vbml/`, validates extraction and smooth unthrottled playback, documents findings in `implementation.md`, then exports validated backends to the public `omega-gg/backend` repo.

Pushing to that repo is the sensitive step. Installed deploy builds fetch backends from its `master` when versions change, so a bad push reaches every user.

## Repository layout

`vbml/` and `reference/*` keep their `.git` and stay real clones. backend-labs ignores them.

```
backend-labs/
  .gitignore         ignores vbml/ and reference/
  setup.sh           clones all four repos at the hashes in reference.lock
  pull.sh            pulls all four, rewrites reference.lock, reports watched changes
  reference.lock     commit hash of each clone
  manual.md          how to run the tests
  implementation.md  technical findings
  doc/plan/          copies of our plans
  test/              CLI test suite: one script per backend, all.sh, common.sh, baseline.tsv
  vbml/              clone of omega-gg/backend, work happens on a local `labs` branch
  reference/         yt-dlp, NewPipeExtractor, YoutubeExplode
```

`pull.sh` also prints new commits touching the files that define YouTube clients (yt-dlp `extractor/youtube/_base.py` and `_video.py`, NewPipe `ClientsConstants.java`, YoutubeExplode `VideoController.cs`), so client breakage is noticed early.

Rule for reference code: record protocol facts (endpoints, fields, client strings), never translate code. NewPipeExtractor is GPLv3.

## CLI test suite

Bash scripts in `test/`, in the style of `clientVBML/test`, documented in `manual.md`. They cover every backend and are the check that compatibility and performance still hold. Requirements from review:

- Anyone can run them from a bash CLI, and they stay simple. No machine specific paths, optional tools get skipped.
- Everything we run to test goes through a script, so every number in `implementation.md` can be reproduced.
- They run often, so they are quick: every backend in about a minute, because backends run in parallel. No retries.
- Throttling is opt-in, with the `throttle` level and `PLAY_SECONDS`, for when we have doubts.
- All 72 active `clientVBML/test` cases are reused.

Results compare with `test/baseline.tsv`: `REGRESSION` when a case that passed now fails or needs more requests, `KNOWN` when it failed in the baseline too.

## Milestones

After M1, each step is one small backend change: bump `version:`, update the index rows, run `dist/generateLite.sh`, get a clean run of that backend's script, up to the play level, record numbers in `implementation.md`. Commits and pushes happen only when requested.

### M0 and M1. Foundation and test suite: done

The repository layout, `manual.md`, the test suite, `baseline.tsv` and the state of each backend in `implementation.md`.

Still to do from M1: refresh the cases that fail only because their URL is stale, and note each one.

### M2. YouTube, one change at a time

1. **Repeated requests.** Find out why clientVBML logs the watch page 3 times for a track, and how much of that happens in the players.
2. **Expiry.** Fix the 60 second value to the intended duration, checked against `expiresInSeconds`.
3. **Visitor data.** Replace the first-play watch page with `sw.js_data`, keeping the watch page as fallback. Read the value without JS if possible, because `JS_CALL` builds a new engine per call. Check whether ANDROID still needs STS, and drop it if not.
4. **Client strings.** Move VISIONOS to 1.04. Test ANDROID in safe mode (Chromecast uses it), now 20.10.38 against yt-dlp's 21.26.364, where yt-dlp notes a PO token requirement except for itag 18.
5. **`$fields` on the source POST.** Confirm `$` survives VBML and URL handling. Add a `videoDetails.videoId` check, because YouTube can substitute another video when rate limiting.
6. **Track metadata.** Replace the watch page with a WEB player `$fields` request. Compare title, author, cover, duration, date and live detection on the test videos. Remove the 1 s delay only if rate limit testing allows it.
7. **Format selection.** AV1 plays smoothly on the test machine, so this only matters for machines without AV1 hardware decoding and for VLC. Change the selection only if the numbers justify it, and keep the mp4 over webm rule that protects VLC.
8. **Live.** Use `hlsManifestUrl` from VISIONOS directly, tested well past 30 s, to remove the ANDROID refetch.
9. **Cleanup.** Merge duplicated client bodies where possible to stay under the statement limit, and fix the stale `ANDROID_VR` comment.

### M3. First export

- Before export, run a final check in each consumer: MotionBox, MotionMonkey, tevolution, tevo (`--screen`, otherwise audio only) and Sky-runtime. The user keeps dev apps closed during those runs.
- Show the final diff and numbers, and push on explicit approval only.
- Merge `labs` into `master` in `vbml/`, push, then pull in the public `backend` checkout. A running MotionBox reloads when that folder changes.

### M4. Other backends, one export each

- **Dailymotion:** the `"380"` key falls to default quality, no `expiry` is set while the URLs may expire, and check whether the second m3u8 fetch is needed.
- **Vimeo:** only the `download` field is used, so videos without downloads have no sources. Evaluate `player.vimeo.com` config, which yt-dlp says can require TLS impersonation, a possible engine limit.
- **Twitch:** compare usher parameters with yt-dlp, set `expiry`, and look at the channel page that sometimes returns empty and forces `reload`.
- **Others:** ordered by the M1 results and player usage, decided with the user after M3.

### Engine proposals (suggest only)

Collected in `implementation.md`, and not implemented without approval:

- Persist `global` (`visitorData`) across process starts, removing the first-play request.
- Allow parallel requests in source flows, to race clients.
- Expose response status and headers to scripts.
- Expose download speed on the player, for the play level of the test suite.

## Critical files

- `vbml/youtube.vbml`: `QUERY_SOURCE` (line 90), `QUERY_TRACK` (141), visitor branch (236), format loops (371 to 476), `expiry` (502), `EXTRACT_TRACK` (504)
- `vbml/index.vbml`, `vbml/indexLite.vbml`, `vbml/dist/generateLite.sh`
- Reference: `Sky/src/SkBackend/src/media/WBackendUniversal.cpp`, `WBackendIndex.cpp`, `VBML/doc/api.md`, `clientVBML/src/controllers/ControllerCore.cpp`, `Sky-runtime/run/sky-player.sky`
- Sources of truth: NewPipe for VISIONOS request details, yt-dlp for the client landscape, PO token policy and the non-YouTube sites

## Verification

- **Each change:** no regressions from that backend's script, with before and after numbers in `implementation.md`. A step that does not measurably help, or loses metadata, gets reverted and documented.
- **Target for YouTube:** first play in 2 requests at about 8 KB (from about 330 KB), track metadata under 1 KB (from 318 KB), no buffering at 1080p60 and 4K60, and identical metadata on the test videos.
- **Export:** after the push, a deploy-style consumer picks up the new version and plays the test videos.
