# Rule-order verdicts for the Studio's rendered pf anchor.
#
# Renders the anchor from the real Studio config with documentation-range
# sources (RFC 5737) in place of host values, then asserts each case's verdict
# with lib/checks/pf-rule-order.py. Roles:
#   A  allowed sources        192.0.2.0/24 (P and R are single hosts in it)
#   B  second LAN             203.0.113.0/25 (M is the laptop on it)
#   X  outside every source   203.0.113.200
#   C  cluster link           198.51.100.0/24
# A last case feeds the evaluator a rule form it does not know and requires it
# to refuse.
{
  pkgs,
  studio,
  pfAnchorCheck,
}:
let
  inherit (pkgs) lib;
  me = "192.0.2.1";
  a = "192.0.2.30";
  p = "192.0.2.50";
  r = "192.0.2.60";
  m = "203.0.113.10";
  b = "203.0.113.20";
  x = "203.0.113.200";
  cfg =
    (studio.extendModules {
      modules = [
        {
          security.pf = {
            allowedSshSources = lib.mkForce [ "192.0.2.0/24" ];
            exemptNetworks = lib.mkForce [ "198.51.100.0/24" ];
            # The shapes a host flake adds: a proxy-only port, router sources on
            # the API port, and the laptop's SSH and Screen Sharing on any LAN.
            allowedTcpServices = [
              {
                port = 8787;
                sources = [ p ];
              }
              {
                port = studio.config.programs.llm-gate.apiPort;
                sources = [ r ];
              }
              {
                port = 22;
                sources = [ m ];
              }
              {
                port = 5900;
                sources = [ m ];
              }
            ];
          };
        }
      ];
    }).config;
  inherit (cfg.programs.llm-gate) apiPort clusterPort;
  metricsPort = cfg.services.macmon-exporter.port;

  tcpIn = src: dport: flags: {
    dir = "in";
    proto = "tcp";
    inherit src dport flags;
    dst = me;
    sport = 50123;
  };
  syn = src: dport: tcpIn src dport "S";
  case = name: expect: packet: { inherit name expect packet; };
  # `by` pins the mechanism: part of the deciding rule line, or the state.
  caseBy =
    name: expect: by: packet:
    case name expect packet // { inherit by; };
  # A packet the Studio sends mid-flow, as the first packet pf sees of it.
  tcpOut = sport: dst: dport: flags: {
    dir = "out";
    proto = "tcp";
    src = me;
    inherit
      sport
      dst
      dport
      flags
      ;
  };

  cases = [
    (case "01 A ssh new" "pass" (syn a 22))
    (case "02 B ssh new" "block" (syn b 22))
    (case "03 X ssh new" "block" (syn x 22))
    (case "04 A metrics" "pass" (syn a metricsPort))
    (case "05 A gateway api" "pass" (syn a apiPort))
    (case "06 R gateway api" "pass" (syn r apiPort))
    (case "07 A gateway cluster port" "pass" (syn a clusterPort))
    (case "08 P session server" "pass" (syn p 8787))
    (case "09 A not proxy, session server" "block" (syn a 8787))
    (case "10 A screen sharing" "pass" (syn a 5900))
    (case "11 A gateway api udp" "block" {
      dir = "in";
      proto = "udp";
      src = a;
      dst = me;
      sport = 50123;
      dport = apiPort;
    })
    (case "12 X icmp echo" "pass" {
      dir = "in";
      proto = "icmp";
      src = x;
      dst = me;
      icmp_type = "echoreq";
    })
    (case "13 icmp6 echo" "block" {
      dir = "in";
      proto = "icmp6";
      src = "2001:db8::10";
      dst = "2001:db8::1";
      icmp_type = "echoreq";
    })
    (case "14 loopback model port" "pass" (
      syn "127.0.0.1" 11435
      // {
        dst = "127.0.0.1";
        iface = "lo0";
      }
    ))
    (case "15 C cluster peer any port" "pass" (
      syn "198.51.100.3" 40000
      // {
        dst = "198.51.100.2";
        iface = "en5";
      }
    ))
    (
      case "16 X reply to flow opened after enforce" "pass" {
        dir = "in";
        proto = "tcp";
        src = x;
        sport = 443;
        dst = me;
        dport = 50000;
        flags = "SA";
      }
      // {
        opener = {
          dir = "out";
          proto = "tcp";
          src = me;
          sport = 50000;
          dst = x;
          dport = 443;
          flags = "S";
        };
      }
    )
    (caseBy "17 A ssh session open before enforce" "pass" "port 22 flags /S no state" (tcpIn a 22 "A"))
    (
      caseBy "18 X reply to outbound tcp open before enforce, after the Studio sends" "pass"
        "matches existing state"
        (tcpIn x 50001 "PA" // { sport = 443; })
      // {
        opener = tcpOut 50001 x 443 "A";
      }
    )
    (case "19 A remote management" "block" (syn a 3283))
    (case "20 A airplay 5000" "block" (syn a 5000))
    (case "21 A airplay 7000" "block" (syn a 7000))
    (case "22 M on B ssh new" "pass" (syn m 22))
    (case "23 M on B screen sharing" "pass" (syn m 5900))
    (case "24 M on B metrics" "block" (syn m metricsPort))
    (case "25 X screen sharing" "block" (syn x 5900))
    (case "26 X non-SYN to ssh" "block" (tcpIn x 22 "A"))
    (case "27 A remote management udp" "block" {
      dir = "in";
      proto = "udp";
      src = a;
      dst = me;
      sport = 50123;
      dport = 3283;
    })
    (case "28 X udp reply to flow open before enforce" "block" {
      dir = "in";
      proto = "udp";
      src = x;
      sport = 53;
      dst = me;
      dport = 50002;
    })
    (case "29 X non-SYN to metrics" "block" (tcpIn x metricsPort "A"))
    (case "30 X non-SYN to an unlistened port" "block" (tcpIn x 60000 "A"))
    (caseBy "31 A screen sharing mid-stream" "pass" "port 5900 no state" (tcpIn a 5900 "PA"))
    (case "32 X reply to outbound tcp open before enforce, before the Studio sends" "block" (
      tcpIn x 50001 "PA" // { sport = 443; }
    ))
    (
      caseBy "33 A metrics mid-stream after the Studio's reply creates no state" "pass"
        "port ${toString metricsPort} no state"
        (tcpIn a metricsPort "A")
      // {
        opener = tcpOut metricsPort a 50123 "A";
      }
    )
    (
      caseBy "34 A ssh session open before enforce, Studio sends first" "pass" "port 22 flags /S no state"
        (tcpIn a 22 "A")
      // {
        opener = tcpOut 22 a 50123 "PA";
      }
    )
    (case "35 A non-SYN to an unlistened port" "block" (tcpIn a 60000 "A"))
  ];

  unknownRule = pkgs.writeText "pf-unknown-rule.conf" ''
    rdr pass on en0 proto tcp to any port 80 -> 127.0.0.1
  '';
in
pkgs.runCommand "check-pf-rule-order"
  {
    hostCheck = pfAnchorCheck {
      inherit pkgs cases;
      name = "studio-documentation-sources";
      anchorText = cfg.environment.etc."pf.anchors/nix-hardening".text;
    };
  }
  ''
    status=0
    ${pkgs.python3}/bin/python3 -I ${./pf-rule-order.py} ${unknownRule} \
      ${
        pkgs.writeText "one-case.json" (builtins.toJSON [ (case "any" "pass" (syn a 80)) ])
      } || status=$?
    [ "$status" -eq 2 ] || {
      echo "pf-rule-order accepted a rule form it does not understand (exit $status)" >&2
      exit 1
    }
    touch $out
  ''
