# Ghostty terminfo DB (just the DB, not the GUI app) on every host, so SSHing
# in from a Ghostty terminal — which sets TERM=xterm-ghostty — resolves cleanly
# even on a headless server that drops the workstation GUI package list.
#
# Split out of home.nix to keep that file under the per-file byte cap
# (_file-size.yml). Must be the `-bin` variant: ghostty.terminfo (source build)
# fails its darwin assert. macbook-m4 already pulls this store path via ghostty-bin.
{ pkgs, ... }:
{
  home.packages = [ pkgs.ghostty-bin.terminfo ];

  # Also expose it via ~/.terminfo — the directory ncurses searches by DEFAULT,
  # with no env var. The nix profile terminfo is only found once hm-session-vars.sh
  # exports TERMINFO_DIRS, and that runs AFTER early login-shell init — so SSHing
  # in printed "can't find terminal definition for xterm-ghostty" 4x before it
  # took effect. ~/.terminfo resolves from the very first line of shell init.
  home.file.".terminfo".source = "${pkgs.ghostty-bin.terminfo}/share/terminfo";
}
