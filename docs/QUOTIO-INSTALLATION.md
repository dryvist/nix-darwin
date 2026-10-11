# Quotio Installation Guide

Quotio is an AI usage monitor menu bar app that provides unified quota tracking and smart
auto-failover across multiple AI providers (Claude, Gemini, OpenAI, and more).

## Overview

- **GitHub**: <https://github.com/nguyenphutrong/quotio>
- **Website**: <https://www.quotio.dev/>
- **Latest Release**: <https://github.com/nguyenphutrong/quotio/releases>

## Features

- Multi-provider tracking (Claude, Gemini, OpenAI, Qwen, Copilot, Vertex AI)
- Menu bar display with at-a-glance quota status (e.g., `G:95% C:42% CP:88%`)
- Real-time dashboard for monitoring requests, tokens, and success rates
- Smart failover to auto-switch between accounts when quotas hit limits
- One-click agent auto-config for Claude Code, OpenCode, and Gemini CLI

## Installation (Manual)

Quotio is not available in Homebrew or nixpkgs. Install manually:

1. Download the latest `.dmg` from [Quotio Releases](https://github.com/nguyenphutrong/quotio/releases)
2. Mount the DMG and drag Quotio.app to `/Applications/`
3. The app is unsigned, so you may need to bypass Gatekeeper:

   ```bash
   xattr -cr /Applications/Quotio.app
   ```

4. Launch Quotio from `/Applications/Quotio.app`
5. Configure API keys for your AI providers (see Configuration below)

## Configuration

On first launch, Quotio will prompt you to configure API keys for AI providers:

1. Open Quotio preferences (menu bar icon → Preferences)
2. Add API keys for providers you use:
   - **Claude**: Anthropic API key
   - **Gemini**: Google AI Studio API key
   - **OpenAI**: OpenAI API key
   - **Others**: See Quotio documentation for additional providers

API keys can be retrieved from:

- **Anthropic**: <https://console.anthropic.com/>
- **Google AI Studio**: <https://aistudio.google.com/apikey>
- **OpenAI**: <https://platform.openai.com/api-keys>

## Launch at Startup (Optional)

To launch Quotio automatically at login:

1. Open System Preferences → Users & Groups → Login Items
2. Click the `+` button and add `/Applications/Quotio.app`

Alternatively, create a LaunchAgent:

```bash
# Create ~/Library/LaunchAgents/dev.quotio.app.plist
cat > ~/Library/LaunchAgents/dev.quotio.app.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>dev.quotio.app</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>/Applications/Quotio.app</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
</dict>
</plist>
EOF

# Load the LaunchAgent
launchctl load ~/Library/LaunchAgents/dev.quotio.app.plist
```

## Future: Nix Derivation

A Nix derivation for Quotio could be created to automate the installation process:

```nix
# Example derivation (not yet implemented)
quotio = pkgs.stdenv.mkDerivation rec {
  pname = "quotio";
  version = "0.4.4";

  src = pkgs.fetchurl {
    url = "https://github.com/nguyenphutrong/quotio/releases/download/v${version}/Quotio-${version}.dmg";
    sha256 = "..."; # Calculate with: nix-prefetch-url <url>
  };

  nativeBuildInputs = [ pkgs.undmg ];

  installPhase = ''
    mkdir -p $out/Applications
    cp -r Quotio.app $out/Applications/
  '';

  # Handle unsigned app
  postInstall = ''
    xattr -cr $out/Applications/Quotio.app
  '';
};
```

This derivation would require:

1. Calculating the SHA256 hash for each release
2. Testing with `nix-build` to ensure proper DMG extraction
3. Adding to `home.packages` or `environment.systemPackages`

## Known Issues

1. **Unsigned App**: Quotio is not Apple-signed, so Gatekeeper will block it on first launch.
   Use `xattr -cr` to bypass (see Installation above).

2. **API Key Storage**: Quotio stores API keys locally. Ensure you trust the application
   before adding production API keys.

3. **Auto-updates**: Manual installations require checking GitHub releases for updates.
   A Nix derivation would require version bumps in the configuration.

## Related

- [Issue #461](https://github.com/dryvist/nix-darwin/issues/461) - Add Quotio app
- [Quotio Documentation](https://www.quotio.dev/)
