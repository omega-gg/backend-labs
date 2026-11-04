# Resync

How to apply our changes from the `vbml` folder to the public [backend](https://github.com/omega-gg/backend) repository.

Fixes are committed in this repository first. They only reach the public repository through the steps below, and only when we decide to. Installed players fetch their backends from its `master` as soon as a version changes, so **a push there reaches every user**.

## See what is pending

This changes nothing:

```sh
sh resync.sh
```

It lists our commits since the last resync, and the files that differ from the public backend. It also tells you if the public backend has moved since then.

## Apply the changes

The commands below expect a checkout of the backend repository next to this one, in `../backend`.

**1. Update the checkout.** A running MotionBox watches this folder and reloads when it changes, so close it, or expect that.

```sh
git -C ../backend pull
```

**2. Bring in public changes first.** If `resync.sh` says the public backend moved, compare and copy those changes into `vbml`, commit them here, and run the tests. Otherwise we would overwrite them.

**3. Test the backends you are about to apply.** There should be no `REGRESSION`. Do this from a home connection, because some sites refuse GitHub's servers, so a passing CI is not enough. YouTube sources in particular can only be checked locally.

```sh
sh test/youtube.sh stream
sh test/youtube.sh play
```

**4. Check the versions.** Every changed backend needs a higher `version:`, the same version in its rows in `index.vbml` and `indexLite.vbml`, and a higher `version:` for both indexes. `dist/generateLite.sh` writes `indexLite.vbml`.

Players compare versions for equality, not order, so **a lower version would still be installed everywhere**. If the public backend has moved past our number, renumber ours first.

**5. Copy only what changed**, as listed by `resync.sh`. `youtube` here is an example:

```sh
cp vbml/youtube.vbml vbml/index.vbml vbml/indexLite.vbml ../backend
sh test/lint.sh ../backend
git -C ../backend diff
```

Read the diff. It should only hold the changes `resync.sh` listed.

**6. Commit and push.** One commit per change is the easiest to revert, for example `youtube: Fix the expiry duration`.

```sh
git -C ../backend add -A
git -C ../backend commit -m "youtube: ..."
git -C ../backend push
```

**7. Record the resync** in `resync.lock`, then commit it here. Its first line is our current commit, and its second line is the new public commit:

```sh
git rev-parse --short HEAD > resync.lock
git -C ../backend rev-parse --short HEAD >> resync.lock
```

**8. Check the result.** `resync.sh` should list no files, and the tests should behave the same on the public backend. Then open a video in a deploy build, which picks up the new version on its own.

```sh
sh resync.sh
sh test/youtube.sh extract master
```

## If something goes wrong

Revert the commit in the backend repository, raise the versions of the backend and the indexes again, and push. Then apply the same revert in `vbml`, or it comes back at the next resync.

## Good to know

- Only `.vbml` files propagate to players. Covers do not.
- An index row with a space in any field gets dropped silently. `sh test/lint.sh` catches that, as well as versions that differ from the files.
- The `reference` folder is unrelated, `sh pull.sh` updates it.
