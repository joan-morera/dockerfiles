# IPv6 ULA selection patch (Option A)

Runtime patch applied to i2pd at image build time.

- **Patch script:** `docker/patch-ipv6-ula.sh`
- **Applied in:** `docker/Dockerfile` (Alpine build) right after the source is extracted and before `make`.
- **CI guard:** `.github/workflows/build-i2pd.yml` (step `Verify upstream IPv6-ULA patch target`) fails fast if upstream code drifts.

This image tracks the **latest i2pd release** (resolved dynamically from GitHub tags), so everything here is written to survive i2pd version bumps: the patch either applies and verifies, or the build fails loudly instead of shipping a silently-broken image.

---

## 1. Symptom

On a host running i2pd with `ipv6 = true` and **no `ifname`/`address6`** configured:

- `router.info` publishes v6 NTCP2/SSU2 entries with an **empty `host=`** (effectively `0.0.0.0` / no IPv6).
- Peers report the router's IPv6 as unusable; IPv6 sessions fail.
- Debug logs show SSU2/UDP and NTCP2 v6 address negotiation never completing (`SSU2 session was not established after 5 seconds`).
- IPv4 works fine; outbound IPv6 works fine (the box can reach the IPv6 internet).

## 2. Environment where it was reproduced

- Host: Debian / Raspberry Pi OS aarch64, single NIC `eth0`.
- `eth0` carries **both** a reachable ULA and public global IPv6 (typical LAN where the ULA is the internal DNS address):
  1. `fd42:1a2b:3c4d:1::100` (ULA — the LAN DNS server)
  2. `2a0c:5a82:250c:3c00:da3a:ddff:fe0a:ee41` (public global)
  3. `2a0c:5a82:250c:3c00:e162:d004:8b79:1d1` (public global)
  4. `fe80::…` (link-local)

  The ULA is **first** in `getifaddrs()` order — order is insertion/enumeration order, not numeric.

- i2pd `2.61.0` (image `ghcr.io/purplei2p/i2pd:latest-release`), rootless podman, `network_mode: host`.

## 3. Root cause

i2pd resolves its "clearnet" IPv6 host in `libi2pd/util.cpp`:

```
GetLocalIPV6Address(check)        // util.cpp:698
  → walks getifaddrs(), returns the FIRST AF_INET6 entry passing check

GetClearnetIPV6Address()          // util.cpp:783
  → check: (addr[0] & 0xF0) == 0x20   // 2000::/3  (public global)
        || (addr[0] & 0xFC) == 0xFC   // fc00::/7  (ULA)   ← added in 2.6x
```

Two facts combine into the bug:

1. **i2pd >= 2.6x added ULA (`fc00::/7`) to the "clearnet" predicate.** Older i2pd only accepted `2000::/3`, which is why this used to work.
2. **The resolver returns the first match, with no priority.** So on any host whose ULA happens to come before its public global in `getifaddrs()` order, the ULA is selected.

Worse, the rest of i2pd is **inconsistent** with that choice:

- `IsInReservedRange()` (`util.cpp:802`, list at `:834`) still classifies all of `fc00::`–`fdff:…` as **reserved**.
- SSU2's learned-external-address path (`SSU2Session::HandleAddress`, `SSU2Session.cpp:2080`) therefore refuses to publish a ULA: `if (!IsInReservedRange(ep.address())) UpdateAddress(ep)` (`:2086`).
- `UpdateAddress` (`RouterContext.cpp:556`) is what writes `host=` into the v6 NTCP2/SSU2 entries (`:576`-`585`).

Net effect: the resolver *selects* a ULA, but the rest of the stack *refuses to publish* it — you get a published v6 address with an empty host. The 2.6x "ULA support" changelog entries ("Failed to bind to ipv6 ULA address", "Unique local address for server tunnels") only cover explicitly-configured/bind scenarios, not the auto-selection path.

The `ifname = eth0` config option makes it deterministic but **worse**: `InitAddressFromIface` (`Transports.cpp:1538`) sets `address6` from `GetInterfaceAddress(ifname, true)` (`util.cpp:602`), which is also first-match → `fd42:…` (the ULA) → SSU2 then binds a specific ULA address instead of `[::]`, so even inbound IPv6 to the public global breaks.

## 4. The fix in this image (Option A — revert to old behavior)

Minimal one-line revert in `GetClearnetIPV6Address`:

```cpp
// before (i2pd >= 2.6x)
return (addr[0] & 0xF0) == 0x20 || (addr[0] & 0xFC) == 0xFC; // 2000::/3 or FC00:/7

// after (this patch)
return (addr[0] & 0xF0) == 0x20; // 2000::/3 only (ULA not selected as clearnet - local patch)
```

Applied by `docker/patch-ipv6-ula.sh` during the image build, using a literal line match (no fragile regex) with a verification guard. The CI workflow additionally re-checks the same line against the **exact upstream version being built** and aborts before Docker even starts if upstream changed it.

Result on the affected host: wildcard mode picks the first **public global** (`2a0c:…`), which i2pd publishes as a reachable v6 host in `router.info` (verified against a throwaway build).

## 5. Why Option A and not something else

| Option | What | Verdict |
|--------|------|---------|
| **A — revert predicate** (chosen) | Drop `fc00::/7` from `GetClearnetIPV6Address`. | Smallest change; restores the behavior that worked for years. Caveat: a ULA-only box now reports "clearnet ipv6 not found" and disables v6 (that's acceptable — a ULA-only box is not reachable from the public IPv6 internet anyway). |
| B — real priority ordering | Public global (`2000::/3`) preferred, ULA used only as fallback, implemented by a rank pass inside `GetLocalIPV6Address`/`GetClearnetIPV6Address` (and ideally `GetInterfaceAddress` for the `ifname` path). | The correct long-term fix, and it keeps the 2.6x "ULA allowed" feature. Slightly more code and needs care in the `ifname` path too. This is what should be proposed upstream. |
| C — un-reserve `fc00::` | Remove the ULA range from `IsInReservedRange` so the auto-learn path publishes it. | Makes i2pd publish a ULA that most of the IPv6 internet cannot reach — undesirable for a public router. Rejected. |

We ship A now because it is minimal, provably restores the previously-working behavior, and unblocks the production router immediately. **B is the direction for a proper upstream fix** (see below).

## 6. How to move forward (proper upstream fix)

For an upstream contribution, implement **Option B**: make IPv6 host selection priority-aware rather than first-match, so a public global always beats a ULA regardless of `getifaddrs()` order, while still allowing ULA-only boxes to function.

Relevant code locations (i2pd `openssl` branch):

- `libi2pd/util.cpp`
  - `GetLocalIPV6Address` — the first-match `getifaddrs` walk (`:698`)
  - `GetClearnetIPV6Address` — the `2000::/3 || fc00::/7` predicate (`:783`)
  - `GetInterfaceAddress` — same first-match problem for the `ifname` path (`:602`)
  - `IsInReservedRange` — ULA still listed reserved (`:802`, `:834`)
- `libi2pd/Transports.cpp` — `InitAddressFromIface` sets `address6` from `GetInterfaceAddress` (`:1538`); `Transports::InitTransports` disables v6 when no clearnet v6 is found (`:1596`)
- `libi2pd/SSU2Session.cpp` — `HandleAddress` drops reserved hosts (`:2080`, `:2086`)
- `libi2pd/RouterContext.cpp` — `UpdateAddress` writes `host=` into v6 entries (`:556`)

Desired upstream behavior: two-pass selection — first `2000::/3` public global, then fall back to `fc00::/7` ULA only if no global exists; apply the same priority inside `GetInterfaceAddress` so `ifname` does not regress to ULA-first.

## 7. How the pieces fit together

1. `docker/patch-ipv6-ula.sh` — the patch logic + verification guard.
2. `docker/Dockerfile` — `COPY patch-ipv6-ula.sh /tmp/` and `sh /tmp/patch-ipv6-ula.sh libi2pd/util.cpp` after extraction, before `make`.
3. `.github/workflows/build-i2pd.yml` — `Verify upstream IPv6-ULA patch target` downloads the resolved `I2PD_VERSION` tarball and asserts the upstream line still matches; aborts early if it does not.
4. Build runs automatically on schedule / on demand (see `build-i2pd.yml`), so every published image carries the fix and the CI never ships one that silently lost it.

## 8. Verification after a rebuild

1. Build/push, then run with `ipv6 = true` and **no** `ifname` / `address6`.
2. Wait ~30 s for the router to publish, then inspect `router.info` (it's a compressed binary — read with `strings` or `zcat`):
   - v6 NTCP2 and SSU2 entries must carry a **public global** `host=` (e.g. `2a0c:5a82:…`).
   - No v6 entry may carry the ULA or an empty host.
3. If upstream i2pd later changes the predicate line, the workflow step fails with a clear message pointing at this document — at which point re-evaluate Option A vs. Option B.
