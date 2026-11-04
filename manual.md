# Manual

How to test the VBML backends from a bash command line. On Windows, use Git Bash. Linux should work too, but this has only been run on Windows. macOS is not supported, its `date` and `cp` differ.

## What you need

| Tool | For | Required |
| --- | --- | --- |
| `curl`, `git` | everything | yes |
| A dev build of [clientVBML](https://github.com/omega-gg/clientVBML) | all the tests | yes |
| [Sky-runtime](https://github.com/omega-gg/Sky-runtime) built, with Qt and MinGW in your `PATH` | `play` level | for `play` |
| `ffprobe` in your `PATH` | codec checks, `throttle` level | no, skipped without it |
| `gdb` in your `PATH` | `backtrace.sh` | no |

The tests look for these builds next to this repository, in `../clientVBML/bin` and `../Sky-runtime/bin`. If yours are somewhere else, set `CLIENT_BIN` and `SKY_BIN`:

```sh
CLIENT_BIN=/path/to/clientVBML/bin sh test/all.sh
```

The tests only use copies inside `build/`, so they never change your builds or their storage.

If you don't have a clientVBML build, this one takes a while the first time and stays inside `build/`:

```sh
sh test/build-client.sh
CLIENT_BIN=$PWD/build/ci/bin sh test/all.sh
```

Don't use a build made with `sh build.sh <platform> all` or `deploy`. A deploy build ignores the local backends and downloads the public ones, and the tests stop when they see that.

Use an unfiltered network. A VPN or a company network can block video sites, and those blocks look like backend failures.

## First time

```sh
sh setup.sh    # clones reference, you only need it to read the public extractors
```

## Running the tests

Every backend has its own script, and `all.sh` runs them all.

```sh
sh test/youtube.sh          # one backend
sh test/all.sh              # every backend
```

Both take a level, then the backends to use:

```sh
sh test/all.sh stream           # also checks the video bytes
sh test/all.sh play             # also plays in Sky-runtime, this opens a window
sh test/all.sh extract master   # uses the public backend repository, not the vbml folder
```

| Level | What it checks |
| --- | --- |
| `extract` (default) | Sources, titles and entries come back, with time and request count |
| `stream` | `extract`, and the highest quality and the audio of each track decode and download 1 MB |
| `play` | Only the selected videos: they play for 5 s with no buffering, then seek |

### When you suspect a problem

These are slower, so run them on the backend you have doubts about. A stream is throttled when it can't reach 3x its playback rate.

```sh
sh test/youtube.sh throttle         # 10 MB per stream, compared with the playback rate
PLAY_SECONDS=60 sh test/youtube.sh play
```

## Reading the results

```
TRACK https://www.youtube.com/watch?v=aqz-KE-bpKQ
[OK] 602 ms, 3 requests (baseline 2089 ms, 3 requests)
```

| Result | Meaning |
| --- | --- |
| `OK` | It works, with no more requests than the baseline |
| `FAIL` | It failed, and there is no baseline for it |
| `KNOWN` | It failed, and it failed in the baseline too |
| `REGRESSION` | It worked in the baseline and now fails, or it needs more requests |

The scripts exit with an error on `FAIL` or `REGRESSION`.

A query times out after 20 s. When a backend has two timeouts before anything has answered, its remaining cases fail as `skipped, the site is not responding`, so a dead site stays quick.

Timing depends on your network, so compare it with the baseline yourself. To know if a site changed or if your edit broke something, run the same test with `master`. If `master` fails as well, the site changed.

Each case keeps what it returned in `build/results/<backend>/`: the `.vbml` output, and the `.log` with every request.

## The baseline

`test/baseline.tsv` holds the last accepted results. To update it, run every backend, read the results, then record them:

```sh
sh test/all.sh stream
sh test/all.sh baseline
```

## CI

The workflow in `.github/workflows/test.yml` is a thin wrapper around this script, which you can run yourself:

```sh
sh test/ci.sh                   # builds clientVBML if needed, then runs the tests
sh test/ci.sh stream            # with a level
sh test/ci.sh measure           # how YouTube treats this network, with measure-youtube.sh
```

It runs on every push and pull request, and once a day because sites change on their own. You can also start it from the Actions tab.

- It tests the `vbml` folder of this repository, so a fix gets tested as soon as it's pushed here, long before it reaches a player.
- It takes a while the first time, then clientVBML is only built again when clientVBML or Sky changes.
- There is no `play` level, because it needs a Sky-runtime build and a screen.
- On GitHub, the results are in the `results` artifact of each run.

GitHub's servers don't answer like a home connection, and some sites can refuse them, so the CI has its own baseline in `test/baseline-ci.tsv`. To update it, download `all.tsv` from the `results` artifact of a run you trust, then:

```sh
cut -f1-5 all.tsv | sort > test/baseline-ci.tsv
```

## Other scripts

```sh
sh test/lint.sh                  # checks the versions in both indexes, without any network
sh test/failure.sh               # a failed request has to exit cleanly, without any network
sh test/measure-youtube.sh       # what each YouTube request costs, and how streams are throttled
sh test/measure-youtube-live.sh  # the YouTube live manifests of the VISIONOS and ANDROID clients
sh test/measure-twitch.sh        # the Twitch video page against its GraphQL API
sh test/measure-twitch-ads.sh    # the ad markers in a Twitch live playlist, for each player type
sh test/measure-vimeo.sh         # the ways of getting Vimeo sources: the API and the player config
sh test/measure-tiktok.sh        # the ways of getting a TikTok video: the app API and the web page
sh test/measure-odysee.sh        # the sources of an Odysee video, with and without a referer
sh test/measure-facebook.sh      # the source fields of a Facebook video on each of its pages
sh test/twitch-live.sh 10        # the channels live right now, with their ad markers, add play to watch
sh test/backtrace.sh "<url>"     # where clientVBML crashes on a query, in gdb
sh pull.sh                       # updates reference, and reports YouTube client changes
sh resync.sh                     # lists our changes still to apply to the public backend, see resync.md
```

## Adding a test

Add a line to the backend's script. The label tells what is expected: `TRACK` needs sources and a title, `COVER` needs a cover, `COVER NO MATCH` needs none, and anything else needs at least one entry.

```sh
test "TRACK" "https://www.youtube.com/watch?v=aqz-KE-bpKQ"

test "SEARCH TRACKS" "vbml:run?backend=youtube&method=search&label=tracks&q=chillwave"

play "TRACK" "https://www.youtube.com/watch?v=aqz-KE-bpKQ" 2160
```
