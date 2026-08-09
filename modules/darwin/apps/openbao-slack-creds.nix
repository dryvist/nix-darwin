# OpenBao-backed Slack app configuration token provider
#
# Installs `openbao-slack-creds`, which mints and rotates the Slack app
# configuration token pair stored in OpenBao KV-v2 at
# secrets-external/data/platform/slack-admin. The refresh token in that pair
# is single-use; the rotation and write-back safety contract that follows
# from that lives in modules/darwin/scripts/openbao-slack-creds.sh.
#
# Also carries `channel` subcommands (create/rename/topic/purpose/invite/
# archive/members/list) for Slack channel lifecycle management, backed by a
# separate bot token minted from the oauthapp secrets engine.
#
# The helper consumes ambient OpenBao secret-zero (`BAO_ADDR`, with legacy
# `VAULT_ADDR` accepted, plus the slack-admin AppRole for the app-config
# token and the oauthapp-slack-poc-read AppRole for the bot token) only at
# invocation time. It stores no Slack credential locally; jq and curl are
# its only runtime dependencies.
#
# This module is purely additive: it ships the wrapper on PATH and changes
# nothing else.

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.openbao-slack-creds;

  slackCredsScript = pkgs.writeShellApplication {
    name = "openbao-slack-creds";
    runtimeInputs = [
      pkgs.jq
      pkgs.curl
    ];
    text = builtins.readFile ./../scripts/openbao-slack-creds.sh;
  };
in
{
  options.programs.openbao-slack-creds.enable = lib.mkEnableOption "the OpenBao-backed Slack app configuration token provider";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ slackCredsScript ];
  };
}
