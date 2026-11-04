# Manual

How to test the VBML backends from a bash command line. On Windows, use Git Bash. Linux should work too, but this has only been run on Windows. macOS is not supported, its `date` and `cp` differ.

## What you need

| Tool | For | Required |
| --- | --- | --- |
| `curl`, `git` | everything | yes |
| [clientVBML](https://github.com/omega-gg/clientVBML) built, with `sh build.sh win64 all` | all the tests | yes |
| [Sky-runtime](https://github.com/omega-gg/Sky-runtime) built, with Qt and MinGW in your `PATH` | `play` level | for `play` |
| `ffprobe` in your `PATH` | codec checks, `throttle` level | no, skipped without it |
| `gdb` in your `PATH` | `backtrace.sh` | no |

The tests look for these builds next to this repository, in `../clientVBML/bin` and `../Sky-runtime/bin`. If yours are somewhere else, set `CLIENT_BIN` and `SKY_BIN`:

```sh
CLIENT_BIN=/path/to/clientVBML/bin sh test/all.sh
```

The tests only use copies inside `build/`, so they never change your builds or their storage. Building is different: `sh build.sh win64 all` wipes `clientVBML/bin`, so move out anything of yours first.

Use an unfiltered network. A VPN or a company network can block video sites, and those blocks look like backend failures.

## First time

```sh
sh setup.sh    # clones vbml and reference
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
sh test/all.sh extract master   # uses the public master branch, not the vbml folder
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
[OK] 2701 ms, 4 requests (baseline 2842 ms, 4 requests)
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

## Other scripts

```sh
sh test/lint.sh                  # checks the versions in both indexes, without any network
sh test/failure.sh               # a failed request has to exit cleanly, without any network
sh test/measure-youtube.sh       # what each YouTube request costs, and how streams are throttled
sh test/backtrace.sh "<url>"     # where clientVBML crashes on a query, in gdb
sh pull.sh                       # updates vbml and reference, and reports YouTube client changes
```

## Adding a test

Add a line to the backend's script. The label tells what is expected: `TRACK` needs sources and a title, `COVER` needs a cover, and anything else needs at least one entry.

```sh
test "TRACK" "https://www.youtube.com/watch?v=aqz-KE-bpKQ"

test "SEARCH TRACKS" "vbml:run?backend=youtube&method=search&label=tracks&q=chillwave"

play "TRACK" "https://www.youtube.com/watch?v=aqz-KE-bpKQ" 2160
```
