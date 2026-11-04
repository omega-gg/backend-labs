backend-labs
---
[![Discord](https://img.shields.io/discord/705770212485496852)](https://omega.gg/discord)
[![CI](https://github.com/omega-gg/backend-labs/actions/workflows/test.yml/badge.svg)](https://github.com/omega-gg/backend-labs/actions/workflows/test.yml)

Turns the video platform knowledge in public extractors into fast VBML backends for MotionBox, MotionMonkey, tevolution, tevo and Sky-runtime.

Those extractors aim to list everything a site offers. We aim to reach the video bytes as fast as possible, with only the sources and metadata our players use. Validated backends get exported to the public [backend](https://github.com/omega-gg/backend) repository.

## Layout

| Path | Content |
| --- | --- |
| `manual.md` | How to run the tests |
| `resync.md` | How to apply our changes to the public backend repository |
| `implementation.md` | Technical findings |
| `doc/plan/` | Plans |
| `test/` | CLI test suite for every backend, with a baseline for home connections and one for the CI |
| `.github/` | CI workflow that runs the test suite |
| `reference.lock` | Commit of each clone below |
| `vbml/` | Our backends, synced with the public backend repository from time to time |
| `reference/` | Clones of yt-dlp, NewPipeExtractor and YoutubeExplode, not committed here |

## Setup

The clones keep their own history, which keeps this repository small.

```sh
sh setup.sh    # clones reference at the commits in reference.lock
sh pull.sh     # pulls reference, updates reference.lock, reports YouTube client changes
```

## Using the reference projects

Record protocol facts like endpoints, fields and client strings, and never translate their code. NewPipeExtractor is GPLv3.

## Testing

See [manual.md](manual.md) for how to run the tests.

## Syncing with the public backend

Fixes are committed here under `vbml/`. Deploy builds fetch backends from `master` of the public repository when versions change, so a push there reaches every installed player. Syncing is a deliberate step, only after a backend passes the test suite. `sh resync.sh` lists what is pending, and [resync.md](resync.md) explains how to apply it.
