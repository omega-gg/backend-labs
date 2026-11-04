# backend-labs

Turns the video platform knowledge in public extractors into fast VBML backends for MotionBox, MotionMonkey, tevolution, tevo and Sky-runtime.

Those extractors aim to list everything a site offers. We aim to reach the video bytes as fast as possible, with only the sources and metadata our players use. Validated backends get exported to the public [backend](https://github.com/omega-gg/backend) repository.

## Layout

| Path | Content |
| --- | --- |
| `manual.md` | How to run the tests |
| `implementation.md` | Technical findings |
| `doc/plan/` | Plans |
| `test/` | CLI test suite for every backend |
| `reference.lock` | Commit of each clone below |
| `vbml/` | Clone of the public backend repository, not committed here |
| `reference/` | Clones of yt-dlp, NewPipeExtractor and YoutubeExplode, not committed here |

## Setup

The clones keep their own history, which keeps this repository small.

```sh
sh setup.sh    # clones everything at the commits in reference.lock
sh pull.sh     # pulls everything, updates reference.lock, reports YouTube client changes
```

## Using the reference projects

Record protocol facts like endpoints, fields and client strings, and never translate their code. NewPipeExtractor is GPLv3.

## Testing

See [manual.md](manual.md) for how to run the tests.

## Exporting

Work happens on a local `labs` branch in `vbml/`. Deploy builds fetch backends from `master` of the public repository when versions change, so a push reaches every installed player. A backend gets merged and pushed only after passing the test suite.
