{
  # Each entry records why the configured Homebrew package is retained.
  exceptions.brews = {
    container = "Homebrew tracks Apple container releases ahead of nixpkgs";
    antigravity-cli = "Homebrew is selected for timely CLI updates";
  };
  exceptions.casks = {
    antigravity = "Homebrew is selected for the required agent IDE version";
    antigravity-ide = "Homebrew is selected for early access to the agent IDE";
    claude = "The nixpkgs package is unavailable on aarch64-darwin";
    bitwarden = "The nixpkgs package has an insecure Electron dependency";
    postman = "The selected vendor app avoids updater schema mismatches";
    raycast = "The selected vendor app avoids updater schema mismatches";
    ghostty = "The nixpkgs package is unavailable on aarch64-darwin";
    libreoffice = "The nixpkgs package is unavailable on aarch64-darwin";
    neat = "The nixpkgs package is a different application";
    chatgpt = "The vendor app is updated in place under /Applications";
    slack = "The vendor app is updated in place under /Applications";
    # Set only when a host selects programs.claude.install = "brew".
    "claude-code@latest" = "The CLI is owned by its Homebrew cask (programs.claude.install = brew)";
  };
}
