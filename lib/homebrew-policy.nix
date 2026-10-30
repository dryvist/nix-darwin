let
  cliCasks = {
    claude-code = "claude-code@latest";
    codex = "codex";
  };
in
{
  # Homebrew owns these CLIs on Darwin; their launchers expect the cask binary.
  inherit cliCasks;

  # Each entry records why the configured Homebrew package is retained.
  exceptions.brews = {
    container = "Homebrew tracks Apple container releases ahead of nixpkgs";
    antigravity-cli = "Homebrew is selected for timely CLI updates";
  };
  exceptions.casks = {
    antigravity = "Homebrew is selected for the required agent IDE version";
    antigravity-ide = "Homebrew is selected for early access to the agent IDE";
    claude = "The nixpkgs package is unavailable on aarch64-darwin";
    claude-code = "Homebrew is selected for timely CLI updates";
    antigravity-cli = "Homebrew is selected for timely CLI updates";
    bitwarden = "The nixpkgs package has an insecure Electron dependency";
    orbstack = "The in-place app preserves macOS privacy grants";
    postman = "The selected vendor app avoids updater schema mismatches";
    ghostty = "The nixpkgs package is unavailable on aarch64-darwin";
    libreoffice = "The nixpkgs package is unavailable on aarch64-darwin";
    neat = "The nixpkgs package is a different application";
    chatgpt = "The vendor app is updated in place under /Applications";
    slack = "The vendor app is updated in place under /Applications";
  }
  // builtins.listToAttrs (
    map (name: {
      inherit name;
      value = "The CLI is owned by its Homebrew cask";
    }) (builtins.attrValues cliCasks)
  );
}
