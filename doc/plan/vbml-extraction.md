# backend-labs: high performance VBML backends

## Context

The public extractors (yt-dlp, NewPipeExtractor, YoutubeExplode) aim to be compatible and to list everything. Our players (MotionBox, MotionMonkey, tevolution, tevo, Sky-runtime) need the opposite: reach the video bytes as fast as possible, with only the sources and metadata we use.

backend-labs mines those projects, updates the VBML backends gradually under `vbml/`, validates extraction and smooth unthrottled playback, documents findings in `implementation.md`, then exports validated backends to the public `omega-gg/backend` repo.

Pushing to that repo is the sensitive step. Installed deploy builds fetch backends from its `master` when versions change, so a bad push reaches every user.

## Repository layout

`vbml/` holds our backends as plain files committed here, synced with `omega-gg/backend` only on request. `reference/*` keep their `.git` and stay real clones that backend-labs ignores.

```
backend-labs/
  .gitignore         ignores vbml/ and reference/
  setup.sh           clones the reference repos
  pull.sh            pulls them, reports watched changes
  resync.sh          lists what is pending for omega-gg/backend, resync.md explains the steps
  resync.lock        our commit and the public commit of the last resync
  manual.md          how to run the tests
  implementation.md  technical findings
  doc/plan/          copies of our plans
  test/              CLI test suite: one script per backend, all.sh, common.sh, baselines
  .github/           CI workflow that runs the test suite
  vbml/              our backends, committed here
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
- All active `clientVBML/test` cases are reused, except those of Last.fm, which is removed.
- They also run from GitHub CI, with a minimal YAML wrapper around `test/ci.sh`, which runs locally too. It has its own baseline since GitHub's servers can get different answers from sites. Playback stays local, because it needs a Sky-runtime build and a screen.

Results compare with `test/baseline.tsv`: `REGRESSION` when a case that passed now fails or needs more requests, `KNOWN` when it failed in the baseline too.

## Milestones

After M1, each step is one small backend change: bump `version:`, update the index rows, run `dist/generateLite.sh`, get a clean run of that backend's script, up to the play level, record numbers in `implementation.md`. Commits and pushes happen only when requested.

### M0 and M1. Foundation and test suite: done

The repository layout, `manual.md`, the test suite, `baseline.tsv` and the state of each backend in `implementation.md`.

Still to do:

- Refresh the cases that fail only because their URL is stale, and note each one.
- Find out why `twitch TRACK LIVE` crashed once on GitHub's servers, if it happens again. It now prints the end of its log.

### M2. YouTube, one change at a time

Done: the repeated requests, `expiry`, `sw.js_data`, metadata from the player request, and live, which stays on ANDROID (see `implementation.md`).

Still open, each only for a measurable gain:

1. **Client strings.** Move VISIONOS to 1.04. Test ANDROID in safe mode (Chromecast uses it), now 20.10.38 against yt-dlp's 21.26.364, where yt-dlp notes a PO token requirement except for itag 18.
2. **`$fields` on the source POST.** Add a `videoDetails.videoId` check, because YouTube can substitute another video when rate limiting.
3. **Format selection.** AV1 plays smoothly on the test machine, so this only matters for machines without AV1 hardware decoding and for VLC.

### M3. First export

- Before export, run a final check in each consumer: MotionBox, MotionMonkey, tevolution, tevo (`--screen`, otherwise audio only) and Sky-runtime. The user keeps dev apps closed during those runs.
- Show the final diff and numbers, and push on explicit approval only.
- Follow `resync.md` when requested.

### M4. Other backends, one export each

- **Dailymotion:** the `"380"` key falls to default quality, no `expiry` is set while the URLs may expire, and check whether the second m3u8 fetch is needed.
- **Vimeo:** only the `download` field is used, so videos without downloads have no sources. `player.vimeo.com` answers 403 from Cloudflare, and getting past that means TLS impersonation, which we don't do.
- **Odysee:** sources fixed in 1.0.10. Very recent uploads can still have none.
- **Twitch:** video and channel metadata moved to GQL. Still to do: compare usher parameters with yt-dlp and set `expiry`.
- **SoundCloud:** the feed is fixed.
- **TikTok:** to do later, with the web route and its engine changes, see `implementation.md`.
- **Youtube Music:** replaces Last.fm, with tracks, albums and artists. Tracks play through `youtube`.
- **Facebook:** sources fixed in 1.0.11, from the embed page, and related titles in 1.0.12.
- **Blocked:** Vimeo sources, see `implementation.md`.

### Engine proposals (suggest only)

Collected in `implementation.md`, and not implemented without approval:

- Persist `global` (`visitorData`) across process starts, removing the first-play request.
- Allow parallel requests in source flows, to race clients.
- Expose response status and headers to scripts.
- Expose download speed on the player, for the play level of the test suite.

## Critical files

- `vbml/youtube.vbml`: `QUERY_SOURCE`, `QUERY_TRACK`, `EXTRACT_SOURCE`, `EXTRACT_TRACK`
- `vbml/index.vbml`, `vbml/indexLite.vbml`, `vbml/dist/generateLite.sh`
- Reference: `Sky/src/SkBackend/src/media/WBackendUniversal.cpp`, `WBackendIndex.cpp`, `VBML/doc/api.md`, `clientVBML/src/controllers/ControllerCore.cpp`, `Sky-runtime/run/sky-player.sky`
- Sources of truth: NewPipe for VISIONOS request details, yt-dlp for the client landscape, PO token policy and the non-YouTube sites

## Verification

- **Each change:** no regressions from that backend's script, with before and after numbers in `implementation.md`. A step that does not measurably help, or loses metadata, gets reverted and documented.
- **Target for YouTube:** first play in 2 requests at about 8 KB (from about 330 KB), track metadata under 1 KB (from 318 KB), no buffering at 1080p60 and 4K60, and identical metadata on the test videos.
- **Export:** after the push, a deploy-style consumer picks up the new version and plays the test videos.
