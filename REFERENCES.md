# References & Documentation

External documentation and resources for this nix configuration.

## Table of Contents

- [Nix Ecosystem](#nix-ecosystem)
- [nix-darwin](#nix-darwin)
- [home-manager](#home-manager)
- [macOS Defaults](#macos-defaults)
- [Package Search](#package-search)

---

## Nix Ecosystem

| Resource | URL |
| --- | --- |
| Nix Manual | <https://nix.dev/manual/nix/stable/> |
| Nix Pills | <https://nixos.org/guides/nix-pills/> |
| Nix Flakes Wiki | <https://wiki.nixos.org/wiki/Flakes> |
| Determinate Nix | <https://determinate.systems/> |

## nix-darwin

| Resource | URL |
| --- | --- |
| GitHub | <https://github.com/nix-darwin/nix-darwin> |
| Options Reference | <https://nix-darwin.github.io/nix-darwin/manual/options.html> |

### Source Files (for understanding implementations)

| Module | URL |
| --- | --- |
| Dock | <https://raw.githubusercontent.com/nix-darwin/nix-darwin/master/modules/system/defaults/dock.nix> |
| Finder | <https://raw.githubusercontent.com/nix-darwin/nix-darwin/master/modules/system/defaults/finder.nix> |
| NSGlobalDomain | <https://raw.githubusercontent.com/nix-darwin/nix-darwin/master/modules/system/defaults/NSGlobalDomain.nix> |
| Trackpad | <https://raw.githubusercontent.com/nix-darwin/nix-darwin/master/modules/system/defaults/trackpad.nix> |
| Keyboard | <https://raw.githubusercontent.com/nix-darwin/nix-darwin/master/modules/system/defaults/keyboard.nix> |
| Screensaver | <https://raw.githubusercontent.com/nix-darwin/nix-darwin/master/modules/system/defaults/screensaver.nix> |
| menuExtraClock | <https://raw.githubusercontent.com/nix-darwin/nix-darwin/master/modules/system/defaults/menuExtraClock.nix> |
| All Defaults | <https://github.com/nix-darwin/nix-darwin/tree/master/modules/system/defaults> |

## home-manager

| Resource | URL |
| --- | --- |
| GitHub | <https://github.com/nix-community/home-manager> |
| Options Reference | <https://nix-community.github.io/home-manager/options.xhtml> |

## macOS Defaults

| Resource | URL |
| --- | --- |
| macos-defaults.com | <https://macos-defaults.com/> |
| defaults-write.com | <https://www.defaults-write.com/> |
| mathiasbynens/dotfiles | <https://github.com/mathiasbynens/dotfiles/blob/main/.macos> |

Common domains: `com.apple.dock`, `com.apple.finder`, `NSGlobalDomain`, `com.apple.AppleMultitouchTrackpad`

```bash
defaults read com.apple.dock          # Read all dock settings
defaults find "keyword"               # Find setting by keyword
```

## Package Search

| Resource | URL |
| --- | --- |
| NixOS Packages | <https://search.nixos.org/packages> |
| Homebrew | <https://formulae.brew.sh/> |
