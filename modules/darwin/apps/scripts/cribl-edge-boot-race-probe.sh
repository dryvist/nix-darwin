#!/usr/bin/env bash
# ponytail: one-shot boot-time evidence for nix-ai Vikunja #1603 (the
# cribl-edge cold-boot race). This daemon is gated on the SAME
# KeepAlive.PathState("/nix/store") the fixed cribl-edge daemon uses, so it
# spawns under identical conditions. Once spawned, it polls whether the
# specific cribl-edge executable is ALREADY resolvable (gap ~0, meaning
# PathState firing already implies the target is ready) or takes further
# iterations to resolve (a real gap between the mount point transitioning and
# the specific store path becoming usable) — the open question the ticket
# needs answered before a third fix attempt. Self-limiting: 60s hard
# deadline, writes once per boot (RunAtLoad, no other KeepAlive condition so
# it never re-fires after this boot). Delete this script and its
# launchd.daemons.cribl-edge-boot-race-probe entry once the ticket is
# resolved.

cribl_path="${1:?cribl_path required}"

store_seen=""
cribl_seen=""
deadline=$((SECONDS + 60))

while [ "$SECONDS" -lt "$deadline" ]; do
  now="${EPOCHREALTIME:0:-3}"
  if [ -z "$store_seen" ] && [ -e /nix/store ]; then
    store_seen="$now"
    echo "store_visible=$now"
  fi
  if [ -z "$cribl_seen" ] && [ -x "$cribl_path" ]; then
    cribl_seen="$now"
    echo "cribl_resolvable=$now"
  fi
  if [ -n "$store_seen" ] && [ -n "$cribl_seen" ]; then
    break
  fi
  sleep 0.05
done

if [ -z "$store_seen" ] || [ -z "$cribl_seen" ]; then
  echo "timed_out store_seen=${store_seen:-never} cribl_seen=${cribl_seen:-never}"
fi
