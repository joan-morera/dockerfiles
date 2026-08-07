#!/bin/sh
# IPv6 ULA selection patch for i2pd (applied at image build time).
#
# What this does
# --------------
# Reverts i2pd's "clearnet IPv6" resolver so an IPv6 ULA (fc00::/7) is no
# longer auto-selected as the router's published IPv6 host.
#
# Background: i2pd >= 2.6x added "|| (addr[0] & 0xFC) == 0xFC" (ULA / fc00::/7) to
# the GetClearnetIPV6Address predicate (libi2pd/util.cpp). Because that function
# returns the FIRST matching getifaddrs(*) entry, a box whose eth0 lists a ULA
# before its public global (a typical reachable-LAN/DNS-ULA setup) will latch onto
# the ULA and publish an unreachable/empty v6 RouterInfo.
#
# Option A (this patch): drop the fc00::/7 clause so only the public global
# (2000::/3) qualifies. See i2pd/PATCH-IPv6-ULA.md for the analysis and for the
# future-proof Option B (priority ordering) we may switch to upstream.
#
# Forward-compatibility guard
#   The script fails loudly (exit non-zero) if the exact upstream line is not
#   found, so a future i2pd refactor triggers a visible build error instead of a
#   silently-unpatched image. The matching workflow step (build-i2pd.yml,
#   "Verify upstream IPv6-ULA patch target") fails even earlier, before Docker
#   starts building.
#
# Usage
#   sh patch-ipv6-ula.sh [libi2pd/util.cpp]
set -e

# Path is relative to the i2pd source root (caller cd's there first).
SRC="${1:-libi2pd/util.cpp}"

# The exact upstream line in i2pd >= 2.6x. It is unique in the codebase.
BEFORE='return (addr[0] & 0xF0) == 0x20 || (addr[0] & 0xFC) == 0xFC; // 2000::/3 or FC00:/7'
# Our replacement for Option A.
AFTER='return (addr[0] & 0xF0) == 0x20; // 2000::/3 only (ULA not selected as clearnet - local patch)'

if ! grep -qF "$BEFORE" "$SRC"; then
  printf >&2 '[PATCH-IPv6-ULA] ERROR: upstream predicate line not found in %s.\n' "$SRC"
  printf >&2 '[PATCH-IPv6-ULA] Expected:\n  %s\n' "$BEFORE"
  printf >&2 '[PATCH-IPv6-ULA] Upstream code moved. Re-evaluate i2pd/PATCH-IPv6-ULA.md before building.\n'
  exit 1
fi

# Literal, line-oriented replacement. index() avoids regex/& escaping issues
# from the (addr[0] & 0xF0) ... characters present in these strings.
awk -v b="$BEFORE" -v a="$AFTER" 'index($0, b) { print a; next } { print }' "$SRC" > "$SRC.tmp"
cat "$SRC.tmp" > "$SRC"
rm -f "$SRC.tmp"

if grep -qF "$AFTER" "$SRC" && ! grep -qF "$BEFORE" "$SRC"; then
  printf '[PATCH-IPv6-ULA] OK: Option A applied (ULA no longer selected as clearnet IPv6).\n'
  exit 0
else
  printf '[PATCH-IPv6-ULA] FAIL: patch did not apply cleanly.\n'
  exit 1
fi