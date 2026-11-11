"""Rule-order verdicts for a rendered nix-hardening pf anchor.

pfctl has no mode that returns a verdict for a described packet, so this
evaluates cases against the rendered rule lines by pf.conf(5) semantics:
state is checked before rules, the last matching rule decides, a `quick`
match is final, a pass without `no state` creates state, and a stateful
TCP pass defaults to `flags S/SA`. With no match the packet passes.

It understands only the rule forms modules/darwin/pf-hardening.nix emits
and exits non-zero on any other line.

usage: python3 -I pf-rule-order.py <anchor-file> <cases.json>
cases.json: [{"name", "expect": "pass"|"block", "packet", "opener"?, "by"?}];
a packet is {"dir", "proto", "src", "dst", "iface"?, "sport"?, "dport"?,
"flags"?, "icmp_type"?}. An opener is evaluated first; it must pass, and
the state it creates is in place for the packet. `by`, when given, must be
part of the deciding rule line (or "matches existing state").

The state model is pf's lookup by protocol, addresses and ports in both
directions. It assumes a state matches every later packet of its flow and
does not model TCP sequence or window tracking, so it cannot show what a
state created from a mid-flow packet (`flags any`) does with window scaling.
"""

import ipaddress
import json
import re
import sys

FLAG_BITS = "FSRPAUEW"


class ParseError(Exception):
    pass


def tokenize(line):
    return re.findall(r"\(.*?\)|[{},]|[^\s{},]+", line)


def take_list(toks, i):
    """Read one item or a `{ a, b }` list starting at toks[i]."""
    if toks[i] != "{":
        return [toks[i]], i + 1
    items, i = [], i + 1
    while toks[i] != "}":
        if toks[i] != ",":
            items.append(toks[i])
        i += 1
    return items, i + 1


def check_addrs(items, line):
    for item in items:
        if item.startswith("!"):
            raise ParseError(f"negated address not supported: {line}")
    return items


def check_ports(items, line):
    for item in items:
        if not item.isdigit():
            raise ParseError(f"only numeric single ports are supported: {line}")
    return items


def flag_set(text):
    return set(text)


def parse_rule(line):
    toks = tokenize(line)
    r = {"line": line, "dir": None, "quick": False, "iface": None, "af": None,
         "proto": None, "src": None, "sport": None, "dst": None, "dport": None,
         "flags": None, "icmp": None, "state": None}
    i = 0
    if toks[i] not in ("pass", "block"):
        raise ParseError(f"unknown action: {line}")
    r["action"] = toks[i]
    i += 1

    def at(*words):
        return i < len(toks) and toks[i] in words

    if at("in", "out"):
        r["dir"] = toks[i]
        i += 1
    if at("quick"):
        r["quick"] = True
        i += 1
    if at("on"):
        r["iface"] = toks[i + 1]
        i += 2
    if at("inet", "inet6"):
        r["af"] = 4 if toks[i] == "inet" else 6
        i += 1
    if at("proto"):
        r["proto"] = toks[i + 1]
        i += 2
    if at("all"):
        i += 1
    elif at("from"):
        r["src"], i = take_list(toks, i + 1)
        check_addrs(r["src"], line)
        if at("port"):
            r["sport"], i = take_list(toks, i + 1)
            check_ports(r["sport"], line)
        if not at("to"):
            raise ParseError(f"expected `to`: {line}")
        r["dst"], i = take_list(toks, i + 1)
        check_addrs(r["dst"], line)
        if at("port"):
            r["dport"], i = take_list(toks, i + 1)
            check_ports(r["dport"], line)
    if at("flags"):
        spec = toks[i + 1]
        if spec != "any":
            if "/" not in spec:
                raise ParseError(f"unknown flags: {line}")
            want, mask = spec.split("/")
            r["flags"] = (flag_set(want), flag_set(mask))
        else:
            r["flags"] = "any"
        i += 2
    if at("icmp-type", "icmp6-type"):
        r["icmp"], i = take_list(toks, i + 1)
        if any(t.isdigit() for t in r["icmp"]):
            raise ParseError(f"numeric ICMP types not supported: {line}")
    if at("no"):
        if toks[i + 1] != "state":
            raise ParseError(f"unknown `no` option: {line}")
        r["state"] = False
        i += 2
    elif at("keep"):
        if toks[i + 1] != "state":
            raise ParseError(f"unknown `keep` option: {line}")
        r["state"] = True
        i += 2
        # State options (max-src-conn and the like) limit how many states a
        # source may hold; they never change a single packet's verdict.
        if i < len(toks) and toks[i].startswith("("):
            i += 1
    if i != len(toks):
        raise ParseError(f"unparsed tokens {toks[i:]}: {line}")
    if r["action"] == "pass" and r["state"] is None:
        r["state"] = True  # pf.conf(5): state is created unless `no state`
    if r["action"] == "pass" and r["state"] and r["flags"] is None:
        r["flags"] = (flag_set("S"), flag_set("SA"))  # default for stateful
    if r["flags"] == "any":
        r["flags"] = None
    return r


def parse_anchor(text):
    rules = []
    for raw in text.splitlines():
        line = raw.strip()
        if line and not line.startswith("#"):
            rules.append(parse_rule(line))
    if not rules:
        raise ParseError("anchor has no rules")
    return rules


def addr_match(token, addr):
    if token == "any":
        return True
    try:
        net = ipaddress.ip_network(token, strict=False)
    except ValueError:
        return token == addr  # a host name matches only the same name
    try:
        ip = ipaddress.ip_address(addr)
    except ValueError:
        return False
    return ip.version == net.version and ip in net


def family(addr):
    try:
        return ipaddress.ip_address(addr).version
    except ValueError:
        return None


def matches(rule, pkt):
    if rule["dir"] and rule["dir"] != pkt["dir"]:
        return False
    if rule["iface"] and rule["iface"] != pkt.get("iface", "en0"):
        return False
    if rule["af"] and rule["af"] != family(pkt["src"]):
        return False
    if rule["proto"]:
        want = "icmp6" if rule["proto"] == "ipv6-icmp" else rule["proto"]
        if want != pkt["proto"]:
            return False
    if rule["src"] and not any(addr_match(t, pkt["src"]) for t in rule["src"]):
        return False
    if rule["dst"] and not any(addr_match(t, pkt["dst"]) for t in rule["dst"]):
        return False
    if rule["sport"] and str(pkt.get("sport")) not in rule["sport"]:
        return False
    if rule["dport"] and str(pkt.get("dport")) not in rule["dport"]:
        return False
    if rule["flags"] and pkt["proto"] == "tcp":
        want, mask = rule["flags"]
        if flag_set(pkt.get("flags", "")) & mask != want:
            return False
    if rule["icmp"] and pkt.get("icmp_type") not in rule["icmp"]:
        return False
    return True


def state_key(pkt):
    ends = sorted([(pkt["src"], pkt.get("sport")), (pkt["dst"], pkt.get("dport"))],
                  key=str)
    return (pkt["proto"], tuple(ends))


def verdict(rules, pkt, states):
    """Return (action, rule line or reason) and record any state created."""
    if state_key(pkt) in states:
        return "pass", "matches existing state"
    last = None
    for rule in rules:
        if matches(rule, pkt):
            last = rule
            if rule["quick"]:
                break
    if last is None:
        return "pass", "no rule matched (pf default pass)"
    if last["action"] == "pass" and last["state"]:
        states.add(state_key(pkt))
    return last["action"], last["line"]


def main(anchor_file, cases_file):
    with open(anchor_file) as f:
        rules = parse_anchor(f.read())
    with open(cases_file) as f:
        cases = json.load(f)
    if not cases:
        raise ParseError("no cases")
    failed = 0
    for case in cases:
        for pkt in [case.get("opener"), case["packet"]]:
            if pkt and set(pkt.get("flags", "")) - set(FLAG_BITS):
                raise ParseError(f"{case['name']}: unknown TCP flag in {pkt['flags']}")
        states = set()
        note = ""
        if case.get("opener"):
            action, why = verdict(rules, case["opener"], states)
            if action != "pass":
                failed += 1
                print(f"FAIL {case['name']}: opener blocked by `{why}`")
                continue
            note = f" (opener passed by `{why}`)"
        action, why = verdict(rules, case["packet"], states)
        ok = action == case["expect"] and case.get("by", "") in why
        failed += not ok
        print(f"{'ok  ' if ok else 'FAIL'} {case['name']}: {action} by `{why}`{note}")
    print(f"{len(cases) - failed}/{len(cases)} cases match")
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main(*sys.argv[1:]))
    except (ParseError, IndexError, KeyError, TypeError) as err:
        print(f"pf-rule-order: cannot evaluate: {err!r}", file=sys.stderr)
        sys.exit(2)
