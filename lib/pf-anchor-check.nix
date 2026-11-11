# Parse check and rule-order test for a rendered nix-hardening pf anchor.
#
# Exported as `lib.pfAnchorCheck` so a downstream flake can run the same checks
# on its own fully rendered host anchor:
#
#   nixDarwinPub.lib.pfAnchorCheck {
#     inherit pkgs;
#     name = "my-host";
#     anchorText = config.environment.etc."pf.anchors/nix-hardening".text;
#     cases = [ { name = "..."; expect = "pass"; packet = { ... }; } ];
#   }
#
# `pfctl -n -f` parses and expands the anchor without loading it; host names in
# the anchor must resolve where the check runs. With `cases`, each case is
# evaluated against the rule lines by lib/checks/pf-rule-order.py (case format in
# its header), which accepts only `any`, addresses and CIDRs as sources, so an
# anchor with host-name sources fails there. Darwin-only: pfctl is a macOS
# system binary.
{
  pkgs,
  name,
  anchorText,
  cases ? [ ],
}:
let
  anchor = pkgs.writeText "${name}-nix-hardening-anchor.conf" anchorText;
  casesFile = pkgs.writeText "${name}-pf-cases.json" (builtins.toJSON cases);
in
pkgs.runCommand "check-pf-anchor-${name}" { } ''
  /sbin/pfctl -n -f ${anchor}
  ${pkgs.lib.optionalString (cases != [ ]) ''
    ${pkgs.python3}/bin/python3 -I ${./checks/pf-rule-order.py} ${anchor} ${casesFile}
  ''}
  touch $out
''
