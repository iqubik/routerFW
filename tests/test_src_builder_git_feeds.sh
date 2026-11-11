#!/usr/bin/env bash
# file: tests/test_src_builder_git_feeds.sh
# Offline Source Builder Git/feed state regressions; no Docker, network or firmware compilation.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

awk '
    /^# BEGIN SOURCE GIT AND FEEDS HELPERS / { active=1; next }
    /^# END SOURCE GIT AND FEEDS HELPERS/ { active=0; done=1; exit }
    active { print }
    END { if (!done) exit 1 }
' "$ROOT/system/src_builder.sh" > "$TMP/functions.sh"
bash -n "$TMP/functions.sh"
# shellcheck source=/dev/null
source "$TMP/functions.sh"

PASS=0
pass() { printf '[OK] %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || fail "$3: expected <$2>, got <$1>"; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "$3: missing <$2>"; }
assert_calls() {
    local actual=''
    [[ -f "$TMP/feeds_calls" ]] && actual=$(cat "$TMP/feeds_calls")
    assert_eq "$actual" "$1" "$2"
}

export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
export GIT_TERMINAL_PROMPT=0
export TEST_FEED_LOG="$TMP/feeds_calls"
export ROUTERFW_FEEDS_STATE_DIR="$TMP/cache"
mkdir -p "$ROUTERFW_FEEDS_STATE_DIR" "$TMP/origin-one" "$TMP/origin-two" "$TMP/worktree/dl"
printf 'preserve separately mounted download cache\n' > "$TMP/worktree/dl/cached.tar.gz"

git -C "$TMP/origin-one" init -q -b main
git -C "$TMP/origin-one" config user.name tester
git -C "$TMP/origin-one" config user.email tester@invalid.test
mkdir -p "$TMP/origin-one/scripts"
cat > "$TMP/origin-one/scripts/feeds" <<'SH'
#!/bin/sh
printf '%s %s\n' "$1" "$2" >> "$TEST_FEED_LOG"
case "${FEEDS_FAIL_MODE:-}" in
    update) [ "$1" = update ] && exit 1 ;;
    install) [ "$1" = install ] && exit 1 ;;
esac
mkdir -p feeds/mock
printf 'updated\n' > feeds/mock/marker
SH
chmod +x "$TMP/origin-one/scripts/feeds"
printf 'src-git-feeds-fixture\n' > "$TMP/origin-one/feeds.conf.default"
printf 'first branch\n' > "$TMP/origin-one/source.txt"
git -C "$TMP/origin-one" add .
git -C "$TMP/origin-one" commit -qm 'fixture main'
MAIN_SHA=$(git -C "$TMP/origin-one" rev-parse HEAD)
git -C "$TMP/origin-one" checkout -qb alternate
printf 'alternate branch\n' > "$TMP/origin-one/source.txt"
git -C "$TMP/origin-one" commit -qam 'fixture alternate'
ALT_SHA=$(git -C "$TMP/origin-one" rev-parse HEAD)
git -C "$TMP/origin-one" checkout -q main

git -C "$TMP/origin-two" init -q -b main
git -C "$TMP/origin-two" config user.name tester
git -C "$TMP/origin-two" config user.email tester@invalid.test
printf 'different upstream\n' > "$TMP/origin-two/source.txt"
git -C "$TMP/origin-two" add .
git -C "$TMP/origin-two" commit -qm 'other upstream'

SRC_REPO="$TMP/origin-one"
SRC_BRANCH=main
SRC_FEEDS_MAX_AGE_HOURS=24
cd "$TMP/worktree"

source_sync_git > "$TMP/log" 2>&1 || { cat "$TMP/log"; fail 'fresh git checkout'; }
assert_eq "$(git rev-parse HEAD)" "$MAIN_SHA" 'fresh checkout commit'
assert_eq "$SOURCE_COMMIT" "$MAIN_SHA" 'exported selected commit'
[[ -f dl/cached.tar.gz ]] || fail 'git initialization damaged dl mounted cache'
pass 'first checkout allows the mandatory dl volume and preserves cached downloads'
pass 'first checkout selects configured origin and exact FETCH_HEAD commit'

source_sync_feeds > "$TMP/log" 2>&1 || { cat "$TMP/log"; fail 'feeds first install'; }
assert_calls $'update -a\ninstall -a' 'first feeds calls'
[[ -f "$ROUTERFW_FEEDS_STATE_DIR/.routerfw_feeds_state_v2" ]] || fail 'state file missing'
pass 'initial feeds update and install stores completed state'

source_sync_git > "$TMP/log" 2>&1 || fail 'second git checkout'
source_sync_feeds > "$TMP/log" 2>&1 || fail 'feeds cache reuse'
assert_calls $'update -a\ninstall -a' 'feeds skip calls'
assert_contains "$TMP/log" 'Cached feeds still valid' 'cache skip reason'
pass 'identical sources and fresh feeds cache -> skip slow update'

printf 'extra src-git feeds data\n' >> feeds.conf.default
source_sync_feeds > "$TMP/log" 2>&1 || fail 'config change refresh'
assert_eq "$(wc -l < "$TMP/feeds_calls" | tr -d ' ')" 4 'config change call count'
pass 'effective feed configuration changed -> refresh despite same Git commit'

# Simulate elapsed 25 hours without modifying the selected Git commit.
state="$ROUTERFW_FEEDS_STATE_DIR/.routerfw_feeds_state_v2"
read -r v fp stamp < "$state"
printf '%s %s %s\n' "$v" "$fp" "$((stamp-25*3600))" > "$state"
source_sync_feeds > "$TMP/log" 2>&1 || fail 'expired feeds refresh'
assert_eq "$(wc -l < "$TMP/feeds_calls" | tr -d ' ')" 6 'expired feeds calls'
pass 'independently moving feeds -> periodic refresh'

SRC_FEEDS_MAX_AGE_HOURS=0
source_sync_feeds > "$TMP/log" 2>&1 || fail 'forced refresh'
assert_eq "$(wc -l < "$TMP/feeds_calls" | tr -d ' ')" 8 'forced refresh calls'
pass 'SRC_FEEDS_MAX_AGE_HOURS=0 forces refresh'
SRC_FEEDS_MAX_AGE_HOURS=24

rm -rf feeds
source_sync_feeds > "$TMP/log" 2>&1 || fail 'missing feeds recovery'
assert_eq "$(wc -l < "$TMP/feeds_calls" | tr -d ' ')" 10 'missing feeds calls'
pass 'missing feeds directory forces reinstall even with fresh marker'

read -r v fp stamp < "$state"
printf '%s %s %s\n' "$v" "$fp" "$((stamp+25*3600))" > "$state"
source_sync_feeds > "$TMP/log" 2>&1 || fail 'future timestamp refresh'
assert_eq "$(wc -l < "$TMP/feeds_calls" | tr -d ' ')" 12 'clock-skew calls'
pass 'clock skew invalidates cache'

printf 'not a valid state\n' > "$state"
source_sync_feeds > "$TMP/log" 2>&1 || fail 'invalid marker refresh'
assert_eq "$(wc -l < "$TMP/feeds_calls" | tr -d ' ')" 14 'invalid marker calls'
pass 'corrupted state marker triggers refresh'

# A failed update must invalidate state even if the previous state was valid.
printf 'different feed config\n' >> feeds.conf.default
FEEDS_FAIL_MODE=update
export FEEDS_FAIL_MODE
if source_sync_feeds > "$TMP/log" 2>&1; then fail 'simulated update failure unexpectedly succeeded'; fi
[[ ! -e "$state" ]] || fail 'failed update left valid marker'
pass 'failed feeds update invalidates state and propagates failure'
unset FEEDS_FAIL_MODE
source_sync_feeds > "$TMP/log" 2>&1 || fail 'feeds retry after failed update'
assert_eq "$(wc -l < "$TMP/feeds_calls" | tr -d ' ')" 17 'failed update then retry count'
pass 'retry after failed update performs full update/install'

printf 'another feed config\n' >> feeds.conf.default
FEEDS_FAIL_MODE=install
export FEEDS_FAIL_MODE
if source_sync_feeds > "$TMP/log" 2>&1; then fail 'simulated install failure unexpectedly succeeded'; fi
[[ ! -e "$state" ]] || fail 'failed install left valid marker'
pass 'failed feeds install invalidates state and propagates failure'
unset FEEDS_FAIL_MODE
source_sync_feeds > "$TMP/log" 2>&1 || fail 'feeds retry after failed install'
pass 'retry after failed install performs full update/install'

SRC_FEEDS_MAX_AGE_HOURS=invalid
if source_sync_feeds > "$TMP/log" 2>&1; then fail 'invalid refresh interval accepted'; fi
assert_contains "$TMP/log" 'nonnegative integer' 'invalid interval error'
pass 'invalid age configuration rejected'
SRC_FEEDS_MAX_AGE_HOURS=99999
if source_sync_feeds > "$TMP/log" 2>&1; then fail 'excessive refresh interval accepted'; fi
pass 'unreasonable refresh interval rejected'
SRC_FEEDS_MAX_AGE_HOURS=024
source_sync_feeds > "$TMP/log" 2>&1 || fail 'leading zero interval failure'
pass 'decimal parsing handles leading zeros'
SRC_FEEDS_MAX_AGE_HOURS=24

# Preserve the main workdir and any locally generated/untracked files on branch switch.
printf 'valuable local state\n' > private-untracked.txt
SRC_BRANCH=alternate
source_sync_git > "$TMP/log" 2>&1 || { cat "$TMP/log"; fail 'alternate branch checkout'; }
assert_eq "$(git rev-parse HEAD)" "$ALT_SHA" 'alternate branch selected HEAD'
assert_eq "$(cat source.txt)" 'alternate branch' 'alternate branch source'
[[ -f private-untracked.txt ]] || fail 'branch switch deleted untracked workdir file'
pass 'branch changes select correct commit without deleting untracked files'

source_sync_feeds > "$TMP/log" 2>&1 || fail 'branch change refresh'
assert_contains "$TMP/log" 'repository/branch/commit/feed configuration changed' 'branch state refresh'
pass 'branch revision change invalidates feed state'

# Same branch can move without a profile change: always fetch fresh upstream HEAD.
git -C "$TMP/origin-one" checkout -q main
printf 'upstream fast-forward\n' > "$TMP/origin-one/source.txt"
git -C "$TMP/origin-one" commit -qam 'fixture main advanced'
NEW_MAIN_SHA=$(git -C "$TMP/origin-one" rev-parse HEAD)
SRC_BRANCH=main
source_sync_git > "$TMP/log" 2>&1 || { cat "$TMP/log"; fail 'branch fast forward'; }
assert_eq "$(git rev-parse HEAD)" "$NEW_MAIN_SHA" 'latest selected commit'
[[ -f private-untracked.txt ]] || fail 'fast-forward checkout deleted untracked file'
pass 'same branch advances to latest fetched commit without deleting untracked data'
source_sync_feeds > "$TMP/log" 2>&1 || fail 'main branch advanced refresh'
assert_contains "$TMP/log" 'repository/branch/commit/feed configuration changed' 'new commit refresh'
pass 'new upstream commit triggers reinstall regardless of feeds TTL'

# A different upstream cannot silently reuse an existing populated OpenWrt worktree.
old_origin=$(git remote get-url origin)
SRC_REPO="$TMP/origin-two"
if source_sync_git > "$TMP/log" 2>&1; then fail 'changing repository in populated workdir succeeded'; fi
assert_contains "$TMP/log" 'clean only this profile src-workdir' 'repo switch explanation'
assert_eq "$(git remote get-url origin)" "$old_origin" 'remote not changed on refusal'
assert_eq "$(git rev-parse HEAD)" "$NEW_MAIN_SHA" 'HEAD not changed on refusal'
[[ -f private-untracked.txt ]] || fail 'repo mismatch deleted user data'
pass 'source repository switch fails closed and preserves persistent data'

SRC_REPO="$TMP/origin-one"
SRC_BRANCH='--upload-pack=bogus'
if source_sync_git > "$TMP/log" 2>&1; then fail 'invalid branch accepted'; fi
pass 'fetch argument injection is rejected as invalid branch'
SRC_BRANCH=main

# Workdir with .git but without origin must not guess provenance of existing HEAD.
git remote remove origin
if source_sync_git > "$TMP/log" 2>&1; then fail 'existing origin-less repo accepted'; fi
pass 'populated workdir without origin fails closed'
git remote add origin "$TMP/origin-one"

# A directory without Git metadata but with unknown data is never initialized over.
mkdir -p "$TMP/non-git" && printf 'keep\n' > "$TMP/non-git/important.txt"
(cd "$TMP/non-git" && if source_sync_git > "$TMP/log" 2>&1; then exit 1; fi) || fail 'non-git workdir safety'
[[ ! -e "$TMP/non-git/.git" ]] || fail 'non-git workdir was initialized'
pass 'nonempty folder without .git refuses unsafe git init'

mkdir -p "$TMP/file-dotgit"
printf 'gitdir: other\n' > "$TMP/file-dotgit/.git"
(cd "$TMP/file-dotgit" && if source_sync_git > "$TMP/log" 2>&1; then exit 1; fi) || fail 'file .git safety'
pass 'Git worktree pointer file never overwritten'

# Unborn Git state may safely have origin repaired, because it has no existing source checkout.
mkdir -p "$TMP/unborn"
git -C "$TMP/unborn" init -q
git -C "$TMP/unborn" remote add origin "$TMP/origin-two"
(cd "$TMP/unborn" && source_sync_git > "$TMP/log" 2>&1) || { cat "$TMP/log"; fail 'unborn origin repair'; }
assert_eq "$(git -C "$TMP/unborn" remote get-url origin)" "$TMP/origin-one" 'unborn origin updated'
assert_eq "$(git -C "$TMP/unborn" rev-parse HEAD)" "$NEW_MAIN_SHA" 'unborn checkout selected commit'
pass 'unborn repository may safely update incorrect origin'
mkdir -p "$TMP/unborn-dirty"
git -C "$TMP/unborn-dirty" init -q
printf 'keep\n' > "$TMP/unborn-dirty/user-file.txt"
(cd "$TMP/unborn-dirty" && if source_sync_git > "$TMP/log" 2>&1; then exit 1; fi) || fail 'unborn workdir unknown data safety'
[[ -f "$TMP/unborn-dirty/user-file.txt" ]] || fail 'unborn checkout deleted unknown data'
pass 'unborn repository with unknown data refuses destructive checkout'

# Removing a feeds configuration cannot be interpreted as a valid fresh feed state.
cd "$TMP/worktree"
mv feeds.conf.default "$TMP/saved-feeds.conf.default"
if source_sync_feeds > "$TMP/log" 2>&1; then fail 'missing feeds configuration accepted'; fi
assert_contains "$TMP/log" 'Neither feeds.conf nor feeds.conf.default' 'missing config error'
mv "$TMP/saved-feeds.conf.default" feeds.conf.default
pass 'missing feed config fails with actionable error'

# Regression: tests must exercise functions that production actually invokes.
grep -Fxq 'source_sync_git || exit 1' "$ROOT/system/src_builder.sh" || fail 'production Git call site missing'
grep -Fxq 'source_sync_feeds || exit 1' "$ROOT/system/src_builder.sh" || fail 'production feeds call site missing'
pass 'production code actually invokes tested Git and feeds helpers'

# Existing marker created by the old Source Builder is not trusted as proof of feed freshness.
rm -f "$state"
printf '%s\n' "$MAIN_SHA" > "$ROUTERFW_FEEDS_STATE_DIR/.last_build_commit"
source_sync_feeds > "$TMP/log" 2>&1 || fail 'old marker migration'
assert_contains "$TMP/log" 'no validated feed state' 'legacy marker ignored'
pass 'legacy .last_build_commit marker cannot mask feed staleness'

if compgen -G "$ROUTERFW_FEEDS_STATE_DIR/.routerfw-feeds.*" > /dev/null; then
    fail 'temporary feed state files leaked'
fi
pass 'atomic state update leaves no staging files'

printf 'Source Builder Git/Feeds Consistency: %d tests passed\n' "$PASS"
