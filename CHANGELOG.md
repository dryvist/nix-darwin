# Changelog

## [2.26.0](https://github.com/dryvist/nix-darwin/compare/v2.25.1...v2.26.0) (2026-08-05)


### Features

* **ci:** relock the whole flake into a single pull request ([#2044](https://github.com/dryvist/nix-darwin/issues/2044)) ([f7d50c3](https://github.com/dryvist/nix-darwin/commit/f7d50c33ef6b8f1cd40aed7ad35e5e355c1cd4d7))
* **mac-studio:** two resident workers, 48 GiB each ([#2045](https://github.com/dryvist/nix-darwin/issues/2045)) ([a68b4bc](https://github.com/dryvist/nix-darwin/commit/a68b4bcbf7af9ec8c8fc619be036b3cf3e122375))

## [2.25.1](https://github.com/dryvist/nix-darwin/compare/v2.25.0...v2.25.1) (2026-08-05)


### Bug Fixes

* **mlx:** disable cluster mode on both ranks while the link is disconnected ([#2039](https://github.com/dryvist/nix-darwin/issues/2039)) ([53028d1](https://github.com/dryvist/nix-darwin/commit/53028d1a14958ae8f755dcea8e8bd2a7fb00dd8e))

## [2.25.0](https://github.com/dryvist/nix-darwin/compare/v2.24.0...v2.25.0) (2026-08-05)


### Features

* **openbao-github-creds:** route write minting per repository ([#2034](https://github.com/dryvist/nix-darwin/issues/2034)) ([304111b](https://github.com/dryvist/nix-darwin/commit/304111b5e8f5bf092d161eeb692e333cdfd3b1bb))

## [2.24.0](https://github.com/dryvist/nix-darwin/compare/v2.23.6...v2.24.0) (2026-08-03)


### Features

* **apfs-volumes:** optional per-volume size ceiling ([#1970](https://github.com/dryvist/nix-darwin/issues/1970)) ([a001c34](https://github.com/dryvist/nix-darwin/commit/a001c3476f23d746afabc7b6078ce239d94e2c32))

## [2.23.6](https://github.com/dryvist/nix-darwin/compare/v2.23.5...v2.23.6) (2026-08-02)


### Bug Fixes

* **ai:** point the open-harness endpoint at the internal services zone ([#2003](https://github.com/dryvist/nix-darwin/issues/2003)) ([28945bf](https://github.com/dryvist/nix-darwin/commit/28945bf892d85745ff455a4a7b4304b8c48665ec))

## [2.23.5](https://github.com/dryvist/nix-darwin/compare/v2.23.4...v2.23.5) (2026-08-02)


### Bug Fixes

* **ci:** drop unused id-token: write from ci-fix.yml ([#2000](https://github.com/dryvist/nix-darwin/issues/2000)) ([e1589c5](https://github.com/dryvist/nix-darwin/commit/e1589c5add528783dd6766f64ef88f20c7e40ea2))
* **power:** enforce High Power Mode instead of writing Low Power ([#2001](https://github.com/dryvist/nix-darwin/issues/2001)) ([bc96f80](https://github.com/dryvist/nix-darwin/commit/bc96f803a8e14bb6bdacd60e248944cd50da2590))

## [2.23.4](https://github.com/dryvist/nix-darwin/compare/v2.23.3...v2.23.4) (2026-08-02)


### Bug Fixes

* **llm-gate:** launch through Apple's interpreter so the gate keeps LAN access ([#1959](https://github.com/dryvist/nix-darwin/issues/1959)) ([483a77b](https://github.com/dryvist/nix-darwin/commit/483a77beb168ff8afee5c13661a8a9de7164c906))

## [2.23.3](https://github.com/dryvist/nix-darwin/compare/v2.23.2...v2.23.3) (2026-08-02)


### Bug Fixes

* **mac-studio:** stop preload from carrying a misleading alias name ([cc206d8](https://github.com/dryvist/nix-darwin/commit/cc206d850fe86e256db85b59ed72ed87bf5ef432))
* **mac-studio:** stop preload from carrying a misleading alias name ([75f44ce](https://github.com/dryvist/nix-darwin/commit/75f44ce497080e7d92e35578c832051cd7c0fb0e))

## [2.23.2](https://github.com/dryvist/nix-darwin/compare/v2.23.1...v2.23.2) (2026-08-02)


### Bug Fixes

* **mac-studio:** enforce llm-concurrency parity with tofu-proxmox via CI ([2c52d82](https://github.com/dryvist/nix-darwin/commit/2c52d824aa528346298546220b06c03ac612563b))
* **mac-studio:** enforce llm-concurrency parity with tofu-proxmox via CI ([6d98bab](https://github.com/dryvist/nix-darwin/commit/6d98babff6d91090a281e8a93c576882a7c8aa47))

## [2.23.1](https://github.com/dryvist/nix-darwin/compare/v2.23.0...v2.23.1) (2026-08-02)


### Bug Fixes

* **mlx-cluster:** no unattended auto-reboot where FileVault blocks the boot ([e6c0157](https://github.com/dryvist/nix-darwin/commit/e6c01570408d279966ec53a6a6b9e69ecf89097e))

## [2.23.0](https://github.com/dryvist/nix-darwin/compare/v2.22.1...v2.23.0) (2026-08-02)


### Features

* **tunables:** actually set High Power Mode instead of warning about it ([7897e2f](https://github.com/dryvist/nix-darwin/commit/7897e2f2a833291eca35e7cba64343dceb73d49d))
* **tunables:** actually set High Power Mode instead of warning about it ([4a5aa4f](https://github.com/dryvist/nix-darwin/commit/4a5aa4fdbbbbe528082b21fa50f239eab0c63c44))

## [2.22.1](https://github.com/dryvist/nix-darwin/compare/v2.22.0...v2.22.1) (2026-08-01)


### Bug Fixes

* **mlx-cluster:** revert wiredCeilingMb, it reaps healthy ranks ([d317a7f](https://github.com/dryvist/nix-darwin/commit/d317a7fb5cd28b31c7ddd304c6d37c9ced2fd01e))
* **mlx-cluster:** revert wiredCeilingMb, it reaps healthy ranks ([8f964d1](https://github.com/dryvist/nix-darwin/commit/8f964d177348ceb3d4210f7e082d5fd5c767c538))

## [2.22.0](https://github.com/dryvist/nix-darwin/compare/v2.21.2...v2.22.0) (2026-08-01)


### Features

* **mlx-cluster:** set shardMemoryMb for the memory-headroom rung ([0d986cc](https://github.com/dryvist/nix-darwin/commit/0d986cce3a3520a13d898dd01c6b77356f249319))
* **mlx-cluster:** set shardMemoryMb for the memory-headroom rung ([3fdb891](https://github.com/dryvist/nix-darwin/commit/3fdb891f7aa099893753f09a358ce46b681e5b10))
* **mlx-cluster:** set wiredCeilingMb so the runtime guard is not decorative ([c235cc3](https://github.com/dryvist/nix-darwin/commit/c235cc3971a5d959627283c879d92d38e2fd0c13))

## [2.21.2](https://github.com/dryvist/nix-darwin/compare/v2.21.1...v2.21.2) (2026-08-01)


### Bug Fixes

* **darwin:** remove ineffective GUI limits agent ([#1966](https://github.com/dryvist/nix-darwin/issues/1966)) ([26c9290](https://github.com/dryvist/nix-darwin/commit/26c92907ab4aeee71e0c2eb135ae1dc95cff59c8))

## [2.21.1](https://github.com/dryvist/nix-darwin/compare/v2.21.0...v2.21.1) (2026-08-01)


### Bug Fixes

* **darwin:** apply maxfiles in GUI sessions ([#1962](https://github.com/dryvist/nix-darwin/issues/1962)) ([b32cf3a](https://github.com/dryvist/nix-darwin/commit/b32cf3abbf4657510ffdd9124b117f922a9a1095))

## [2.21.0](https://github.com/dryvist/nix-darwin/compare/v2.20.0...v2.21.0) (2026-07-30)


### Features

* **offbox:** per-job min-age override to stop immutable jobs wedging ([#1944](https://github.com/dryvist/nix-darwin/issues/1944)) ([8d599f3](https://github.com/dryvist/nix-darwin/commit/8d599f3c0a2da37fb415a9b8a910981a0415e67b))


### Bug Fixes

* **darwin:** drop gimp, unavailable on darwin in the current nixpkgs pin ([#1956](https://github.com/dryvist/nix-darwin/issues/1956)) ([9d71715](https://github.com/dryvist/nix-darwin/commit/9d71715ddbe79c6a989c317e228836bc1d11bf22))

## [2.20.0](https://github.com/dryvist/nix-darwin/compare/v2.19.0...v2.20.0) (2026-07-30)


### Features

* **dock:** add GIMP and refresh app layout ([c7b9f56](https://github.com/dryvist/nix-darwin/commit/c7b9f56b1383a0729f2be19a729ada5ea31a2b07))


### Bug Fixes

* **auto-upgrade:** pin self-referencing flake urls to main ([#1948](https://github.com/dryvist/nix-darwin/issues/1948)) ([623e54e](https://github.com/dryvist/nix-darwin/commit/623e54efd99ff69860eeab8e2f5b5473946e2592))

## [2.19.0](https://github.com/dryvist/nix-darwin/compare/v2.18.2...v2.19.0) (2026-07-30)


### Features

* **homebrew:** add Superwhisper cask ([5697846](https://github.com/dryvist/nix-darwin/commit/5697846cf09349b6b1449adcca3fb4e11913cd65))


### Bug Fixes

* **ghostty:** install via greedy cask so TCC grants survive activation ([#1935](https://github.com/dryvist/nix-darwin/issues/1935)) ([023f8b7](https://github.com/dryvist/nix-darwin/commit/023f8b71fcff2b814cb19f1d77ae0f2ea4fd7e36))
* **homebrew:** pin current cask runtime ([#1943](https://github.com/dryvist/nix-darwin/issues/1943)) ([c8c5186](https://github.com/dryvist/nix-darwin/commit/c8c51862d4960d31d84d87ff78acf8ec75a5915d))

## [2.18.2](https://github.com/dryvist/nix-darwin/compare/v2.18.1...v2.18.2) (2026-07-29)


### Bug Fixes

* **offbox-sync:** keep versions via --suffix, not --backup-dir ([1f7118a](https://github.com/dryvist/nix-darwin/commit/1f7118a7769e2e472ad25bab2c6d0e3c070fe4a4))
* **offbox-sync:** keep versions via --suffix, not --backup-dir ([4d7e25a](https://github.com/dryvist/nix-darwin/commit/4d7e25a917eb3a816c32c69c46e18402ec8c1d1c))

## [2.18.1](https://github.com/dryvist/nix-darwin/compare/v2.18.0...v2.18.1) (2026-07-29)


### Bug Fixes

* **offbox-sync:** expand OFFBOX_ROOT in the destination ([c0699ae](https://github.com/dryvist/nix-darwin/commit/c0699aea67edc4140cf0ef382a2385ac1c2c4d42))
* **offbox-sync:** expand OFFBOX_ROOT in the destination ([eecce79](https://github.com/dryvist/nix-darwin/commit/eecce79d79c1a7a7ae0ef568696fdae4bc151cff))

## [2.18.0](https://github.com/dryvist/nix-darwin/compare/v2.17.1...v2.18.0) (2026-07-29)


### Features

* **offbox-sync:** one-way replication of local data to an SFTP target ([d1925e1](https://github.com/dryvist/nix-darwin/commit/d1925e1e844cb5e866c293e197b428b12ab37951))
* **offbox-sync:** one-way replication of local data to an SFTP target ([a80b3a3](https://github.com/dryvist/nix-darwin/commit/a80b3a333f4a1887489783b359daba4b3b9937b6))

## [2.17.1](https://github.com/dryvist/nix-darwin/compare/v2.17.0...v2.17.1) (2026-07-29)


### Bug Fixes

* **deps:** pin nix-ai input to main, not its develop default ([#1925](https://github.com/dryvist/nix-darwin/issues/1925)) ([b5c3436](https://github.com/dryvist/nix-darwin/commit/b5c3436af6a3497be70e1aab337a7ba2eed5a0a0))

## [2.17.0](https://github.com/dryvist/nix-darwin/compare/v2.16.0...v2.17.0) (2026-07-29)


### Features

* **ci:** refresh nixpkgs channel pin on a schedule ([#1916](https://github.com/dryvist/nix-darwin/issues/1916)) ([c44afc6](https://github.com/dryvist/nix-darwin/commit/c44afc6ec3c5ee90b107ec73cd4d3d0bb510783c))

## [2.16.0](https://github.com/dryvist/nix-darwin/compare/v2.15.1...v2.16.0) (2026-07-27)


### Features

* **mac-studio:** serve Qwen3.6-35B-A3B standalone at concurrency 1 ([#1907](https://github.com/dryvist/nix-darwin/issues/1907)) ([a83144f](https://github.com/dryvist/nix-darwin/commit/a83144fbc096f93812385f3fd984edb78f5d8b9e))
* **mlx-cluster:** give the cluster executables an identity that survives a rebuild ([#1890](https://github.com/dryvist/nix-darwin/issues/1890)) ([f7b0ab0](https://github.com/dryvist/nix-darwin/commit/f7b0ab0324f37df633d6a129de05d0b9230fa7c2))


### Bug Fixes

* **mac-studio:** derive the serving concurrency from one number, and scrub a private term ([#1891](https://github.com/dryvist/nix-darwin/issues/1891)) ([7dd93e9](https://github.com/dryvist/nix-darwin/commit/7dd93e9a6c72b5bf24353b160f0709a71f72a263))
* **macbook:** drop the last orphan concurrency literal ([#1892](https://github.com/dryvist/nix-darwin/issues/1892)) ([46f8540](https://github.com/dryvist/nix-darwin/commit/46f8540290c464f3d69a96dc30f013a6a7e9b7e8))
* **mlx-cluster:** drop hardened runtime from binary signing ([#1894](https://github.com/dryvist/nix-darwin/issues/1894)) ([0fad33c](https://github.com/dryvist/nix-darwin/commit/0fad33c0c0d9ca9ece10f838d0b18c0298e48ea8))
* **mlx-cluster:** narrow the rank-python signing glob to one version ([#1900](https://github.com/dryvist/nix-darwin/issues/1900)) ([a03c119](https://github.com/dryvist/nix-darwin/commit/a03c1199cdfa84ed8394554f8d57194b29237607))
* **openbao-run:** parameterize KV mount for per-secret override ([#1902](https://github.com/dryvist/nix-darwin/issues/1902)) ([d61cdb6](https://github.com/dryvist/nix-darwin/commit/d61cdb66a9309fb3917cf50c0e66d07a8bf976fe))
* **orbstack:** stop the container symlink wedging home-manager activation ([#1888](https://github.com/dryvist/nix-darwin/issues/1888)) ([52b4843](https://github.com/dryvist/nix-darwin/commit/52b4843cdcd6b2f57212ed0984303a9199314acd))

## [2.15.1](https://github.com/dryvist/nix-darwin/compare/v2.15.0...v2.15.1) (2026-07-25)


### Bug Fixes

* **mac-studio:** bring per-model concurrency within the 1-4 policy range ([#1881](https://github.com/dryvist/nix-darwin/issues/1881)) ([3fae9a8](https://github.com/dryvist/nix-darwin/commit/3fae9a830469d89081b8d08627682c5d5e52dfc8))

## [2.15.0](https://github.com/dryvist/nix-darwin/compare/v2.14.0...v2.15.0) (2026-07-25)


### Features

* **llm-gate:** refuse oversized request bodies at the gate ([#1870](https://github.com/dryvist/nix-darwin/issues/1870)) ([13c803e](https://github.com/dryvist/nix-darwin/commit/13c803e566f5c6b2ceae12b89b00f22f81a722d3))


### Bug Fixes

* **logging:** rotate AI serving logs via the root-run system newsyslog ([#1869](https://github.com/dryvist/nix-darwin/issues/1869)) ([f6398b5](https://github.com/dryvist/nix-darwin/commit/f6398b5b23d49bd9301b242d23660af7e6ed90e5))

## [2.14.0](https://github.com/dryvist/nix-darwin/compare/v2.13.1...v2.14.0) (2026-07-25)


### Features

* **mlx:** 24/7 small 9B swap slot on both Macs ([#1864](https://github.com/dryvist/nix-darwin/issues/1864)) ([0ad3568](https://github.com/dryvist/nix-darwin/commit/0ad35682f16a391e78812cc87e2e2f0c8c9dbd2d))


### Bug Fixes

* **cluster:** bring Thunderbolt ports up so the link address is assigned ([#1871](https://github.com/dryvist/nix-darwin/issues/1871)) ([a3d656c](https://github.com/dryvist/nix-darwin/commit/a3d656c3e9b6a331097d7d71343e35cf620e2f59))

## [2.13.1](https://github.com/dryvist/nix-darwin/compare/v2.13.0...v2.13.1) (2026-07-24)


### Bug Fixes

* **mlx:** single-model mode — everything routes to Coder-30B ([#1860](https://github.com/dryvist/nix-darwin/issues/1860)) ([36882be](https://github.com/dryvist/nix-darwin/commit/36882be7d92178554231a43336b831560fe1ae4a))

## [2.13.0](https://github.com/dryvist/nix-darwin/compare/v2.12.3...v2.13.0) (2026-07-23)


### Features

* **mlx:** expose qwen 9b for hermes ([569c062](https://github.com/dryvist/nix-darwin/commit/569c0623823224b1d3632a9f82c153f41cf31a54))
* **mlx:** preload catalog-selected Hermes judge ([#1843](https://github.com/dryvist/nix-darwin/issues/1843)) ([81f80cb](https://github.com/dryvist/nix-darwin/commit/81f80cbd136a4e2b7e363e5b030472b6515d5e86))
* **mlx:** unify Mac wired ceilings to 100 GiB with 28 GiB reserve ([#1848](https://github.com/dryvist/nix-darwin/issues/1848)) ([8176e97](https://github.com/dryvist/nix-darwin/commit/8176e97f591891c03b0297915758aaee230c234c))


### Bug Fixes

* **cribl:** classify mlx worker log lines ([fd36595](https://github.com/dryvist/nix-darwin/commit/fd36595ecbb6fa0b2605500f39c2020e60bbe644))
* **mlx:** drop empty env keys so the wired-limit daemon can spawn ([#1854](https://github.com/dryvist/nix-darwin/issues/1854)) ([cad1c49](https://github.com/dryvist/nix-darwin/commit/cad1c4983231b178967f80bfbbe7b051ec049381))
* **mlx:** follow generic model server contract ([#1844](https://github.com/dryvist/nix-darwin/issues/1844)) ([1924f9d](https://github.com/dryvist/nix-darwin/commit/1924f9daf5ac1367696a17f173578d6328188610))
* **mlx:** run the wired-limit activation on switch, not only at boot ([#1851](https://github.com/dryvist/nix-darwin/issues/1851)) ([184c0ae](https://github.com/dryvist/nix-darwin/commit/184c0ae99b7cbb420c200d5a3e83814d3a376e6c))
* **renovate:** switch weekly github-actions/cribl-edge groups to Fri/Mon ([#1847](https://github.com/dryvist/nix-darwin/issues/1847)) ([4d5fb06](https://github.com/dryvist/nix-darwin/commit/4d5fb06cf69c30a5fddd4fe0acc0a3e16fc39e5a))

## [2.12.3](https://github.com/dryvist/nix-darwin/compare/v2.12.2...v2.12.3) (2026-07-22)


### Bug Fixes

* deploy watchdog progress tracking to Studio ([a806ebd](https://github.com/dryvist/nix-darwin/commit/a806ebd12cc5e982f0bd9e69ff252a355d450408))
* deploy watchdog progress tracking to Studio ([72e1072](https://github.com/dryvist/nix-darwin/commit/72e10720b3b1f1921dce2f84db19b4502d5aea43))

## [2.12.2](https://github.com/dryvist/nix-darwin/compare/v2.12.1...v2.12.2) (2026-07-22)


### Bug Fixes

* deploy Hermes stability fixes to Studio ([2e5c9bf](https://github.com/dryvist/nix-darwin/commit/2e5c9bf9704cac257f561aead2ab7a1f3db23768))
* deploy Hermes stability fixes to Studio ([c67e8ba](https://github.com/dryvist/nix-darwin/commit/c67e8ba42d7e46029594a8d60b4ef3f186428a84))
* include ShellCheck-clean Splunk MCP wrapper ([8bc63d6](https://github.com/dryvist/nix-darwin/commit/8bc63d6a4645fe6a14a0b538505b85b935be6952))

## [2.12.1](https://github.com/dryvist/nix-darwin/compare/v2.12.0...v2.12.1) (2026-07-21)


### Bug Fixes

* **cribl:** revert os_metrics stamp to event path; crashreport tailOnly ([08fac45](https://github.com/dryvist/nix-darwin/commit/08fac453f2146cce14c7a5c3fa49655fcff56f7e))

## [2.12.0](https://github.com/dryvist/nix-darwin/compare/v2.11.1...v2.12.0) (2026-07-21)


### Features

* **cribl:** route Mac OS metrics to os_metrics + capture critical macOS logs ([#1824](https://github.com/dryvist/nix-darwin/issues/1824)) ([e7257fe](https://github.com/dryvist/nix-darwin/commit/e7257fedf91086b22bf9fb34f89b9220116f15a7))

## [2.11.1](https://github.com/dryvist/nix-darwin/compare/v2.11.0...v2.11.1) (2026-07-21)


### Bug Fixes

* **llm-gate:** bind gate sites to LAN address only — never capture loopback ([#1816](https://github.com/dryvist/nix-darwin/issues/1816)) ([d71ce39](https://github.com/dryvist/nix-darwin/commit/d71ce39cf3efa194fb5d9254b66db62e78152bb2))

## [2.11.0](https://github.com/dryvist/nix-darwin/compare/v2.10.0...v2.11.0) (2026-07-21)


### Features

* **cribl:** ship codex + gemini transcripts through the cc-edge pack pipelines ([#1814](https://github.com/dryvist/nix-darwin/issues/1814)) ([ada1c60](https://github.com/dryvist/nix-darwin/commit/ada1c60780e3ca54c99663dcf9285b376235048f))
* **github-auth:** gh-read / gh-claim shell helpers over OpenBao ([#1787](https://github.com/dryvist/nix-darwin/issues/1787)) ([d8089a8](https://github.com/dryvist/nix-darwin/commit/d8089a8beed53679f3a88092a3deee89150b863f))
* **macbook:** raise the standalone LLM ceiling to ~105 GB (util 0.68) ([e4395b6](https://github.com/dryvist/nix-darwin/commit/e4395b67b4e0cd8cb7c2376e00786a5ebd3b79ef))
* **macbook:** raise the standalone LLM ceiling to ~105 GB, util 0.68 ([6dea146](https://github.com/dryvist/nix-darwin/commit/6dea146a21ff15c8d62b0e4967d5b5998804f31b))


### Bug Fixes

* **ci:** repair unreadable cache scope and halve the build closure ([#1800](https://github.com/dryvist/nix-darwin/issues/1800)) ([d555f92](https://github.com/dryvist/nix-darwin/commit/d555f924147629d5f49cf9fce80eea12f2abe507))
* **ci:** stop cancelling the runs that save the Nix cache ([#1811](https://github.com/dryvist/nix-darwin/issues/1811)) ([f28b581](https://github.com/dryvist/nix-darwin/commit/f28b581dfa4fb22b5fffe88617f797859160b65f))
* **github-auth:** repair permanent write-lease deadlock after deadman expiry ([#1801](https://github.com/dryvist/nix-darwin/issues/1801)) ([dfa6318](https://github.com/dryvist/nix-darwin/commit/dfa6318bbb6a8771b1ae3a2c502b465b0b45fd80))
* **llm-gate:** update caddy plugin FOD hash after the nixpkgs realign ([#1808](https://github.com/dryvist/nix-darwin/issues/1808)) ([9b31b37](https://github.com/dryvist/nix-darwin/commit/9b31b376d42d20723a2343fd4cd8b151d59f4336))
* **macbook:** bound the standalone MLX wired ceiling with a paired utilization ([#1809](https://github.com/dryvist/nix-darwin/issues/1809)) ([9bbcfd6](https://github.com/dryvist/nix-darwin/commit/9bbcfd67fdd79873cc52c3d4998bce41c3854573))

## [2.10.0](https://github.com/dryvist/nix-darwin/compare/v2.9.0...v2.10.0) (2026-07-20)


### Features

* **cluster:** stamp configurationRevision + wire generation auto-heal dir ([#1788](https://github.com/dryvist/nix-darwin/issues/1788)) ([37c8566](https://github.com/dryvist/nix-darwin/commit/37c8566c79e5ca2b683fe5a589dc1921c4d59854))


### Bug Fixes

* **ci:** pass OPENAI_API_KEY through to the shared AI workflows ([#1797](https://github.com/dryvist/nix-darwin/issues/1797)) ([bb94453](https://github.com/dryvist/nix-darwin/commit/bb9445305cb214eaab6f3540ccef1bbb2196a701))
* **cluster:** drop local-path generation heal wiring; heal from remote flake ([#1790](https://github.com/dryvist/nix-darwin/issues/1790)) ([6e87a92](https://github.com/dryvist/nix-darwin/commit/6e87a9290e96ac2b3d6df021587f21689e6edda7))
* **github-auth:** clear osxkeychain helper, explain write-mint denials ([#1789](https://github.com/dryvist/nix-darwin/issues/1789)) ([32085dc](https://github.com/dryvist/nix-darwin/commit/32085dc601962837ed0d5eb56bf2f1db6029db15))

## [2.9.0](https://github.com/dryvist/nix-darwin/compare/v2.8.0...v2.9.0) (2026-07-20)


### Features

* **github-auth:** break-glass App-JWT mint fallback for GitHub creds ([#1776](https://github.com/dryvist/nix-darwin/issues/1776)) ([4e30831](https://github.com/dryvist/nix-darwin/commit/4e30831a2b88fee51f08294764e069cebe462d13))
* **github-auth:** cut git over to the OpenBao credential wrapper ([#1773](https://github.com/dryvist/nix-darwin/issues/1773)) ([d02b2be](https://github.com/dryvist/nix-darwin/commit/d02b2beff8b199f94cd916b7109513534d4833c6))
* **security:** NOPASSWD grants for the vllm-mlx serving-restore ladder ([#1772](https://github.com/dryvist/nix-darwin/issues/1772)) ([6245b35](https://github.com/dryvist/nix-darwin/commit/6245b3587ffe0a707e728c87b1bcb93797099c7d))


### Bug Fixes

* **cluster:** wire wired-ceiling values into nix-ai clusterMode so the guard is live ([#1769](https://github.com/dryvist/nix-darwin/issues/1769)) ([78e0798](https://github.com/dryvist/nix-darwin/commit/78e079893411dfe2772c0d798c85ad943d320d5b))

## [2.8.0](https://github.com/dryvist/nix-darwin/compare/v2.7.1...v2.8.0) (2026-07-18)


### Features

* add Codex desktop app cask ([316ea6e](https://github.com/dryvist/nix-darwin/commit/316ea6e39c5c001b7e417c5032abb4c7e94df686))
* add Codex desktop app cask ([#1759](https://github.com/dryvist/nix-darwin/issues/1759)) ([c8a6b69](https://github.com/dryvist/nix-darwin/commit/c8a6b6914373a2fcb40169068097ce4d6d143896))


### Bug Fixes

* **openbao-github-creds:** send string-form mint params — server ACL cannot match lists ([#1760](https://github.com/dryvist/nix-darwin/issues/1760)) ([7198a89](https://github.com/dryvist/nix-darwin/commit/7198a89af57e1a5d5ccfc96ab2f995843dd04516))

## [2.7.1](https://github.com/dryvist/nix-darwin/compare/v2.7.0...v2.7.1) (2026-07-18)


### Bug Fixes

* **security:** unset AppRole bootstrap creds before exec + un-silence diagnostics ([#1754](https://github.com/dryvist/nix-darwin/issues/1754)) ([43a2111](https://github.com/dryvist/nix-darwin/commit/43a2111abb86b9342bd0c2e1d550fbfd91fd23a8))

## [2.7.0](https://github.com/dryvist/nix-darwin/compare/v2.6.0...v2.7.0) (2026-07-18)


### Features

* **openbao-github-creds:** rewrite for per-repo write minting + lease ([622610a](https://github.com/dryvist/nix-darwin/commit/622610a9d0353f0d71be6e8b7dc3815db4169ae9))

## [2.6.0](https://github.com/dryvist/nix-darwin/compare/v2.5.0...v2.6.0) (2026-07-17)


### Features

* **cluster:** link-state wired-limit profile + explicit REAP-50 cluster model ([#1719](https://github.com/dryvist/nix-darwin/issues/1719)) ([579e612](https://github.com/dryvist/nix-darwin/commit/579e612e7343077ec4efa72afaf0585fb7569d56))


### Bug Fixes

* **cluster:** guard alf-allow in postActivation so it cannot fail activation ([#1734](https://github.com/dryvist/nix-darwin/issues/1734)) ([a07cddf](https://github.com/dryvist/nix-darwin/commit/a07cddfe1e83eefd7fc36162b1834235d5e62c8c))
* **cluster:** keep failed labels for retry on partial cluster-restore ([#1720](https://github.com/dryvist/nix-darwin/issues/1720)) ([8b87b51](https://github.com/dryvist/nix-darwin/commit/8b87b51b8fbeece7469c215e4bcce127a31dff09))
* **mlx:** remove the wedge trigger and guarantee recovery on the Macs ([#1730](https://github.com/dryvist/nix-darwin/issues/1730)) ([3b0d5da](https://github.com/dryvist/nix-darwin/commit/3b0d5da09d6a8852d46e472c6c94db12d306fc1f))

## [2.5.0](https://github.com/dryvist/nix-darwin/compare/v2.4.0...v2.5.0) (2026-07-16)


### Features

* **openbao:** GitHub token provider wrapper to retire GH_PAT keychain tiers ([#1699](https://github.com/dryvist/nix-darwin/issues/1699)) ([b41d54f](https://github.com/dryvist/nix-darwin/commit/b41d54f493e7a8687d0964e8f2e3c3f8f30eb27d))
* **packages:** add entire CLI to core system packages ([#1710](https://github.com/dryvist/nix-darwin/issues/1710)) ([a32db0f](https://github.com/dryvist/nix-darwin/commit/a32db0fb1e75bc112954ee1562f690f095abfe3e))


### Bug Fixes

* **cluster-link:** allow uv CPython through the application firewall ([#1708](https://github.com/dryvist/nix-darwin/issues/1708)) ([ccde5ed](https://github.com/dryvist/nix-darwin/commit/ccde5ed6dc7b956b7df24828ed5155c70a0be547))
* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1712](https://github.com/dryvist/nix-darwin/issues/1712)) ([98382dd](https://github.com/dryvist/nix-darwin/commit/98382dd356d13c6c1c3ba13e455f51c9fcb576d5))

## [2.4.0](https://github.com/dryvist/nix-darwin/compare/v2.3.0...v2.4.0) (2026-07-16)


### Features

* **llm-gate:** migrate the gate from Doppler to OpenBao (openbao-run) ([b4dfeea](https://github.com/dryvist/nix-darwin/commit/b4dfeea24d563b79b13b275fb11e2eae450c80d1))
* **openbao:** add openbao-run, an AppRole env-injector (doppler run replacement) ([a90f9b3](https://github.com/dryvist/nix-darwin/commit/a90f9b380f3bd5c9313f295e3d526bfcd02cafef))
* **openbao:** migrate the llm-large gate off Doppler onto OpenBao ([40552e6](https://github.com/dryvist/nix-darwin/commit/40552e67b1e4763fe93dde87bb697b71a5984902))

## [2.3.0](https://github.com/dryvist/nix-darwin/compare/v2.2.1...v2.3.0) (2026-07-15)


### Features

* **launchd:** self-heal penalty-boxed critical KeepAlive daemons ([#1697](https://github.com/dryvist/nix-darwin/issues/1697)) ([0491098](https://github.com/dryvist/nix-darwin/commit/04910981e74720cdb4948bde6dd483bd407767b1))


### Bug Fixes

* **launchd:** harden self-heal checks ([#1704](https://github.com/dryvist/nix-darwin/issues/1704)) ([3d59a68](https://github.com/dryvist/nix-darwin/commit/3d59a68f17be3ae4c0751a79774a688d6721e893))
* **llm-gate:** stop XDG_CONFIG_HOME from breaking doppler token lookup ([76aba4f](https://github.com/dryvist/nix-darwin/commit/76aba4ff84dc73f5d182c768c7244d527417e6e9))
* **llm-gate:** stop XDG_CONFIG_HOME from breaking doppler token lookup ([9c76019](https://github.com/dryvist/nix-darwin/commit/9c76019d9ee8dbdb61e71a688c111105e3ef2054))
* **skills:** unify Codex plugin source ([23cb8e6](https://github.com/dryvist/nix-darwin/commit/23cb8e6f822a30ea3aeb984db3b616c30dc59250))

## [2.2.1](https://github.com/dryvist/nix-darwin/compare/v2.2.0...v2.2.1) (2026-07-14)


### Bug Fixes

* **mac-studio:** make stock 35B the resident tool-calling brain ([#1694](https://github.com/dryvist/nix-darwin/issues/1694)) ([a63e95c](https://github.com/dryvist/nix-darwin/commit/a63e95cf0e2172ef9755fa2c0f8af4bf292f0133))

## [2.2.0](https://github.com/dryvist/nix-darwin/compare/v2.1.0...v2.2.0) (2026-07-13)


### Features

* **cluster-link:** disable Thunderbolt Bridge service to stop RDMA port re-enslavement ([#1684](https://github.com/dryvist/nix-darwin/issues/1684)) ([3eb3170](https://github.com/dryvist/nix-darwin/commit/3eb3170b2c6f9380b5fcb1b0ea69a389a0d8d608))


### Bug Fixes

* **security:** enumerate sudoers args + cluster-link-prep awk exit ([#1690](https://github.com/dryvist/nix-darwin/issues/1690)) ([a6ad162](https://github.com/dryvist/nix-darwin/commit/a6ad1623210be1aa01d682d3055f96d37fc8f393))

## [2.1.0](https://github.com/dryvist/nix-darwin/compare/v2.0.0...v2.1.0) (2026-07-13)


### Features

* **apfs:** git APFS volume on every Mac; chore: remove shellcheck ([#1674](https://github.com/dryvist/nix-darwin/issues/1674)) ([e36a421](https://github.com/dryvist/nix-darwin/commit/e36a421fb433962977a74c1e5f8b9b3fa216400d))
* enable macOS Screen Sharing by default on all Macs ([#1675](https://github.com/dryvist/nix-darwin/issues/1675)) ([01e3f0f](https://github.com/dryvist/nix-darwin/commit/01e3f0f078e7ba16e200379bd622d67ee13d32bb))
* **hosts:** auto-login on both Macs; disable cluster auto-bring-up ([#1668](https://github.com/dryvist/nix-darwin/issues/1668)) ([81ee684](https://github.com/dryvist/nix-darwin/commit/81ee684d1f18cbbce63f617814604d593c3277e2))
* **security:** grant passwordless fdesetup authrestart ([#1677](https://github.com/dryvist/nix-darwin/issues/1677)) ([f03ec0e](https://github.com/dryvist/nix-darwin/commit/f03ec0e78714c31bdea731b29da2a8f68a8c5f6f))
* **security:** grant passwordless reboot for unattended cluster recovery ([#1676](https://github.com/dryvist/nix-darwin/issues/1676)) ([cfa4c99](https://github.com/dryvist/nix-darwin/commit/cfa4c99c4c657d3013f357a9fe2d73b6755921c8))


### Bug Fixes

* **activation:** correct elapsed_time escape and drop ls parsing ([6aa550d](https://github.com/dryvist/nix-darwin/commit/6aa550d25719436f8d336aceb26acbff02a9208e))
* address promotion review findings ([#1679](https://github.com/dryvist/nix-darwin/issues/1679)) ([873f31f](https://github.com/dryvist/nix-darwin/commit/873f31f867f6b30d0ad4f7b5511aa49f1d110f48))
* cover nix-ai-open-harness in flake-update automation ([00561b8](https://github.com/dryvist/nix-darwin/commit/00561b87e86b1abc4eed8209e9c243948c0cac13))

## [2.0.0](https://github.com/dryvist/nix-darwin/compare/v1.76.0...v2.0.0) (2026-07-12)


### ⚠ BREAKING CHANGES

* **cluster:** rename night/day naming to clustered/normal mode ([#1666](https://github.com/dryvist/nix-darwin/issues/1666))

### Features

* **continuity:** login-time auto-resume of an armed Claude mission ([#1664](https://github.com/dryvist/nix-darwin/issues/1664)) ([8ba62e4](https://github.com/dryvist/nix-darwin/commit/8ba62e4decccefa1b2e95b8bdac3df890cfdfa30))
* **darwin:** scoped NOPASSWD sudoers for cluster ops ([289b66c](https://github.com/dryvist/nix-darwin/commit/289b66cc950d27b2fcd432498e4f8cbd744067a4))
* **energy:** AC-power display sleep via displaysleepAc ([#1655](https://github.com/dryvist/nix-darwin/issues/1655)) ([8503c79](https://github.com/dryvist/nix-darwin/commit/8503c79ccbec1ef5fe0840433e72b2d41a8ccfb5))
* **macbook-m4:** enable tmux cc-session autostart ([c521089](https://github.com/dryvist/nix-darwin/commit/c521089c2bd63d5041c6c9f9f8c612c23117f391))
* **mcp:** enable vikunja MCP on jevans-mbp ([#1646](https://github.com/dryvist/nix-darwin/issues/1646)) ([f802d81](https://github.com/dryvist/nix-darwin/commit/f802d81d79a337bdaec5ad1daeaa1b93427092cc))
* **night-link:** auto-detect the RDMA port, zero written IP ([#1657](https://github.com/dryvist/nix-darwin/issues/1657)) ([67d1ab2](https://github.com/dryvist/nix-darwin/commit/67d1ab2ab96ca6b2f33383fc6e92ab4e1b4ab08a))
* **night-link:** RDMA link prep — bridge detach, IPv6, role-IP converge daemon ([#1656](https://github.com/dryvist/nix-darwin/issues/1656)) ([6bbf78a](https://github.com/dryvist/nix-darwin/commit/6bbf78acf3c58e24e09d7394a3434bf1ac354241))
* **openbao-keychain:** AWS credential_process wrapper for tf-proxmox ([#1663](https://github.com/dryvist/nix-darwin/issues/1663)) ([2474e04](https://github.com/dryvist/nix-darwin/commit/2474e04c1730c2599b124184551c4fce373d8562))


### Bug Fixes

* **hosts:** pin server timezone to GMT, not UTC ([894a3ff](https://github.com/dryvist/nix-darwin/commit/894a3ffa38ddeba64b3e8795d7f9e375853e2ae1))
* **night-link:** address review findings from promotion [#1660](https://github.com/dryvist/nix-darwin/issues/1660) ([#1665](https://github.com/dryvist/nix-darwin/issues/1665)) ([e475939](https://github.com/dryvist/nix-darwin/commit/e475939ba9bff01309610a30c0f4d7a7e3a9e2a8))
* server timezone GMT + pull marketplace settings-merge fix ([#1650](https://github.com/dryvist/nix-darwin/issues/1650)) ([d9b901f](https://github.com/dryvist/nix-darwin/commit/d9b901f1b537ebf46985e461a0101f76c6a61aa5))
* set-iogpu-wired-limit boot daemon did not run at boot (Studio, Jul 4) ([#1644](https://github.com/dryvist/nix-darwin/issues/1644)) ([#1645](https://github.com/dryvist/nix-darwin/issues/1645)) ([fb3146a](https://github.com/dryvist/nix-darwin/commit/fb3146a2ccfac58de1a7fca5d43d8f89121936c9))
* use absolute paths for grep/awk in cluster-link-converge.sh ([9b7695b](https://github.com/dryvist/nix-darwin/commit/9b7695be2d74278d0fa6c0473f2985689411b562))


### Refactoring

* **cluster:** rename night/day naming to clustered/normal mode ([#1666](https://github.com/dryvist/nix-darwin/issues/1666)) ([5c0aa5e](https://github.com/dryvist/nix-darwin/commit/5c0aa5e3f5f137589931aab71795342983feed6d))

## [1.76.0](https://github.com/dryvist/nix-darwin/compare/v1.75.0...v1.76.0) (2026-07-10)


### Features

* **cribl:** ship mlx bench-events feed to Splunk (mlx:bench) ([#1640](https://github.com/dryvist/nix-darwin/issues/1640)) ([7e0522a](https://github.com/dryvist/nix-darwin/commit/7e0522a2a89dd34a52108736b6cee612202b233f))


### Bug Fixes

* **hosts:** codify application firewall on (Studio drift closes firewall.log gap) ([#1643](https://github.com/dryvist/nix-darwin/issues/1643)) ([700ac6c](https://github.com/dryvist/nix-darwin/commit/700ac6c90ccd728ff52cfed5757bf2f49291b492))

## [1.75.0](https://github.com/dryvist/nix-darwin/compare/v1.74.3...v1.75.0) (2026-07-10)


### Features

* add AI PR care caller (dep review + release highlights) ([#1433](https://github.com/dryvist/nix-darwin/issues/1433)) ([2454bb2](https://github.com/dryvist/nix-darwin/commit/2454bb2f669449492bbb1a7e7f7b095c51c7e61e))
* add issue-backlog-sweep caller ([#1470](https://github.com/dryvist/nix-darwin/issues/1470)) ([a5b6791](https://github.com/dryvist/nix-darwin/commit/a5b67916876cec482d09a1697966dfde53b91417))
* add MacBook open harness tools ([#1530](https://github.com/dryvist/nix-darwin/issues/1530)) ([6db6171](https://github.com/dryvist/nix-darwin/commit/6db61713ef8cb993d989df78458565089d26463f))
* add review-thread-resolver caller for instant bot-thread resolution ([#1448](https://github.com/dryvist/nix-darwin/issues/1448)) ([c326c3f](https://github.com/dryvist/nix-darwin/commit/c326c3f1f95df9660dddbefaab690080a8dc81dc))
* bump nixpkgs to 26.05; resolve all 26.05 breakage ([#1481](https://github.com/dryvist/nix-darwin/issues/1481)) ([bd0a62b](https://github.com/dryvist/nix-darwin/commit/bd0a62ba83cfb8c166e0ee0e8929c8885f1766e5))
* **ci:** migrate Linux CI to self-hosted RunsOn runners ([#1104](https://github.com/dryvist/nix-darwin/issues/1104)) ([7f9d8d7](https://github.com/dryvist/nix-darwin/commit/7f9d8d7578807c266ad008183488e8acf08e8e13))
* **ci:** receive update-flake-input dispatch from nix-ai ([#1174](https://github.com/dryvist/nix-darwin/issues/1174)) ([09ddd30](https://github.com/dryvist/nix-darwin/commit/09ddd30e10d03b90cf5e7b1b41a4024fe12fb447))
* **claude:** adopt nix-claude-code module ([#1160](https://github.com/dryvist/nix-darwin/issues/1160)) ([83f987f](https://github.com/dryvist/nix-darwin/commit/83f987fe488e547289f8caeed99e2887f2d35b35))
* **claude:** re-inject homelab auto-mode context after nix-ai de-personalization ([#1280](https://github.com/dryvist/nix-darwin/issues/1280)) ([6e6c884](https://github.com/dryvist/nix-darwin/commit/6e6c8840588f29b2854e575f95575cd6a678c768))
* **cribl-edge:** bump to 4.18.0 and fix cloud enrollment (URL + port) ([#1123](https://github.com/dryvist/nix-darwin/issues/1123)) ([d9100d9](https://github.com/dryvist/nix-darwin/commit/d9100d9109f15361cd7416516b4323273babc23d))
* **cribl-edge:** standalone GitOps mode + inline LLM-stack sources ([#1235](https://github.com/dryvist/nix-darwin/issues/1235)) ([0a21177](https://github.com/dryvist/nix-darwin/commit/0a211776824c859a20f610b5e46240a8035988d4))
* **cribl-stream:** add local Cribl Stream node in Apple container ([#1244](https://github.com/dryvist/nix-darwin/issues/1244)) ([358db35](https://github.com/dryvist/nix-darwin/commit/358db35f69f064441ae2a2ba471a23f1f3c44403))
* **cribl:** bump mac pack v0.1.0 -&gt; v0.3.0 (native 4.18 sources) ([ef10105](https://github.com/dryvist/nix-darwin/commit/ef10105f9368f266a59e45585fbcdc42d9de6b46))
* **darwin:** exhaustive macOS LLM-inference tuning parameters (M4 Max / Tahoe) ([#1220](https://github.com/dryvist/nix-darwin/issues/1220)) ([6e9ed97](https://github.com/dryvist/nix-darwin/commit/6e9ed97842b53d085714c9ea8d29f0903500e908))
* enable issues:labeled trigger to close the auto-resolve loop ([#1502](https://github.com/dryvist/nix-darwin/issues/1502)) ([74419a2](https://github.com/dryvist/nix-darwin/commit/74419a29d510a6bf432d37f7c4009a43c20edaa1))
* HF_TOKEN via sops on server-class hosts (keychain-free real secrets) ([#1401](https://github.com/dryvist/nix-darwin/issues/1401)) ([35095fb](https://github.com/dryvist/nix-darwin/commit/35095fbc446d64e8d22487c11b3439c72e5a2bb2))
* **homebrew:** add Apple container runtime ([#1239](https://github.com/dryvist/nix-darwin/issues/1239)) ([6affebc](https://github.com/dryvist/nix-darwin/commit/6affebc356d62230639cd8d4342e529b786dd617))
* **homebrew:** add firefox cask and add to dock ([#1091](https://github.com/dryvist/nix-darwin/issues/1091)) ([84b328e](https://github.com/dryvist/nix-darwin/commit/84b328e6b273b69311bd8402566a0116f631cc9a))
* **homebrew:** install Homebrew declaratively via nix-homebrew ([#1474](https://github.com/dryvist/nix-darwin/issues/1474)) ([104635d](https://github.com/dryvist/nix-darwin/commit/104635d67c8917071c0e99644357116f3696dd51))
* **homebrew:** integrate with nix-ai trustedTaps option for aws/tap ([#1226](https://github.com/dryvist/nix-darwin/issues/1226)) ([66ddd9b](https://github.com/dryvist/nix-darwin/commit/66ddd9be3ced677efd5efa15a4fbe70cc022a04b))
* **hosts:** add mac-studio (jevans-ms) headless inference host ([9e53db8](https://github.com/dryvist/nix-darwin/commit/9e53db888db2e656a56738fb2cedf68d35512ffd))
* lean-host cleanup — declarative app removal + _brew prune + strict deadnix ([#1490](https://github.com/dryvist/nix-darwin/issues/1490)) ([090a6ef](https://github.com/dryvist/nix-darwin/commit/090a6efadadf32b1625628832ac758a3da49343a))
* **llm-gate:** API-only gate, extraHostnames cert SAN, route53 on studio ([#1467](https://github.com/dryvist/nix-darwin/issues/1467)) ([1c2a80d](https://github.com/dryvist/nix-darwin/commit/1c2a80d09d8c131b2484cb80c8753fd636c39d16))
* **llm:** dedicated Cribl service ports for LLM logs + gate access log ([#1562](https://github.com/dryvist/nix-darwin/issues/1562)) ([74d2ac7](https://github.com/dryvist/nix-darwin/commit/74d2ac7581996edaad7f8d48be0471c0aec0804a))
* **llm:** scrape llama-swap Prometheus metrics into the llm_metrics index ([#1564](https://github.com/dryvist/nix-darwin/issues/1564)) ([d359d22](https://github.com/dryvist/nix-darwin/commit/d359d22a9225c0c318a2ae6717fb9ceff583d8d7))
* **logging:** per-AI-CLI log capture + dedicated Cribl Edge shipping ([#1561](https://github.com/dryvist/nix-darwin/issues/1561)) ([33578c1](https://github.com/dryvist/nix-darwin/commit/33578c1be06fdcc6e9eda46db8efd4cca73a6f32))
* **logging:** retire syslogd remote forward, ship firewall unified-log via Cribl Edge ([#1584](https://github.com/dryvist/nix-darwin/issues/1584)) ([bbee58d](https://github.com/dryvist/nix-darwin/commit/bbee58daa08f1651bd7f442f85e3977b394c683b))
* mac-studio llm-large serving gate, ephemeral GitHub runner, web UI wiring ([#1395](https://github.com/dryvist/nix-darwin/issues/1395)) ([7fae032](https://github.com/dryvist/nix-darwin/commit/7fae03228ab05495d15d8005c58236e795600877))
* mac-studio two-resident models (gpt-oss-120b + Qwen3-Coder-30B), Studio age recipient ([#1397](https://github.com/dryvist/nix-darwin/issues/1397)) ([c5fac39](https://github.com/dryvist/nix-darwin/commit/c5fac39e2c840c928d033d9b3b0d08515e1347c1))
* **mlx:** file-first AI_MODEL_LOCAL_LLM read + disable HF autodiscover ([#1192](https://github.com/dryvist/nix-darwin/issues/1192)) ([d7dbe38](https://github.com/dryvist/nix-darwin/commit/d7dbe38ccedcda088ab30b7cc9799d04c52ea9f5))
* **mlx:** make OptiQ-4bit 35B the resident tool-calling brain on jevans-ms ([#1589](https://github.com/dryvist/nix-darwin/issues/1589)) ([33dc416](https://github.com/dryvist/nix-darwin/commit/33dc41685c52981465e26e41bde5ac8c2321452b))
* **mlx:** register Qwen3-Next-80B Thinking as the swap-tier large brain ([#1591](https://github.com/dryvist/nix-darwin/issues/1591)) ([4036108](https://github.com/dryvist/nix-darwin/commit/403610880056ba5576b8929fc82bbe996746ddde))
* **mlx:** wire services.aiStack.defaultLocalModelId from automation keychain ([f30c357](https://github.com/dryvist/nix-darwin/commit/f30c357b978f7c309bce7d068a326d2127583a64))
* **night-cluster:** host wiring, worker quiesce, gated night endpoint, runbook ([7e1b744](https://github.com/dryvist/nix-darwin/commit/7e1b74475de2f243c8600a5ecd7d3bfbda4be745))
* **openbao:** dedicated keychain + resolver LaunchAgent for secret-zero ([#1493](https://github.com/dryvist/nix-darwin/issues/1493)) ([9aab7a1](https://github.com/dryvist/nix-darwin/commit/9aab7a178da0e5d10f40477d3aec6cebad4b5d34))
* **packages:** add neat menu-bar app via homebrew cask ([#1444](https://github.com/dryvist/nix-darwin/issues/1444)) ([1f1fb9c](https://github.com/dryvist/nix-darwin/commit/1f1fb9c600e07677c7606f0a5fe051372a6707a5))
* schedule auto-upgrade directly ([#1535](https://github.com/dryvist/nix-darwin/issues/1535)) ([45caee9](https://github.com/dryvist/nix-darwin/commit/45caee9abc3d61d4963561b21a811ecdee522070))
* seed global git excludes from dryvist/.github org-default gitignore ([#1256](https://github.com/dryvist/nix-darwin/issues/1256)) ([8b0d348](https://github.com/dryvist/nix-darwin/commit/8b0d3486b83e77bf3caa7c0b1a4faf207bc18bd3))
* **studio:** add nix-managed scheduled claude jobs ([8ba4177](https://github.com/dryvist/nix-darwin/commit/8ba4177138ab4a1436b8bc6f32f694b9eb3f8aa8))
* **tokens:** formalize DRYVIST/ORG_ADMIN tiers, dryvist default, post-rename signing fix ([#1153](https://github.com/dryvist/nix-darwin/issues/1153)) ([20357b8](https://github.com/dryvist/nix-darwin/commit/20357b84e94acd0398c86ad2a7f134b8d32bd411))
* **tunables:** lower iogpu wired limit to 104000 for 24GB pageable headroom ([#1233](https://github.com/dryvist/nix-darwin/issues/1233)) ([50d36b5](https://github.com/dryvist/nix-darwin/commit/50d36b5f089e3e162e21fa0b567d4d1f2500d0f4))
* tune Mac Studio serving stack for Qwen3.6 ([#1545](https://github.com/dryvist/nix-darwin/issues/1545)) ([a86c5e7](https://github.com/dryvist/nix-darwin/commit/a86c5e7bf8d897569372b2651f740fa8090ac59c))


### Bug Fixes

* **ai-stack:** source defaultLocalModelId from committed config ([cd0f29f](https://github.com/dryvist/nix-darwin/commit/cd0f29fb22e169c1c1de65645072c5a065afc23a))
* **ai:** swap local LLM default to Qwen3-30B-A3B-Instruct-2507 + unbreak main build ([#1230](https://github.com/dryvist/nix-darwin/issues/1230)) ([5a8a28a](https://github.com/dryvist/nix-darwin/commit/5a8a28aeb6a39a50943a73b816b21565068e5905))
* **chatgpt:** install via greedy homebrew cask; remove claudebar ([#1617](https://github.com/dryvist/nix-darwin/issues/1617)) ([bf69cd0](https://github.com/dryvist/nix-darwin/commit/bf69cd02c2918363ec5baf57620da9c5d19f5cbb))
* **ci:** opt out of --all-systems for nix-validate ([#1093](https://github.com/dryvist/nix-darwin/issues/1093)) ([8e14a8e](https://github.com/dryvist/nix-darwin/commit/8e14a8e2bf6af1747637f8c051f1cdc0e943f004))
* **ci:** quote workflow_dispatch description to avoid YAML parse error ([#1188](https://github.com/dryvist/nix-darwin/issues/1188)) ([aec06a3](https://github.com/dryvist/nix-darwin/commit/aec06a32e8c94e4fa6246b9974501a4d72da450f))
* **ci:** repoint release-please caller to org-native reusable workflow ([#1171](https://github.com/dryvist/nix-darwin/issues/1171)) ([1ae9a40](https://github.com/dryvist/nix-darwin/commit/1ae9a40c4acab75a197ebe4a7311bb9519ce31d6))
* **ci:** repoint shared workflows to dryvist hub ([#1242](https://github.com/dryvist/nix-darwin/issues/1242)) ([572f0d0](https://github.com/dryvist/nix-darwin/commit/572f0d0081867bc5f310c4d258e27a58c9c99722))
* **ci:** retarget reusable-workflow uses: refs to current org homes ([#1154](https://github.com/dryvist/nix-darwin/issues/1154)) ([c9a66a5](https://github.com/dryvist/nix-darwin/commit/c9a66a5ec89888ed22d1c72ecfdeb4e7de3181a7))
* **ci:** update jacobpevans-cc-plugins, not anthropics claude-code-plugins ([#1117](https://github.com/dryvist/nix-darwin/issues/1117)) ([131c2de](https://github.com/dryvist/nix-darwin/commit/131c2dea502bc0d776f824aed903e021afb525a6))
* Cribl Edge in_llm_logs ships nothing — vllm-mlx.log never reaches Splunk ([#1623](https://github.com/dryvist/nix-darwin/issues/1623)) ([#1624](https://github.com/dryvist/nix-darwin/issues/1624)) ([c39ab21](https://github.com/dryvist/nix-darwin/commit/c39ab212dbcbe47835f99b70d7fe66dacaeb12d1))
* **cribl-edge:** install standalone config into the edge tree, not cribl ([#1415](https://github.com/dryvist/nix-darwin/issues/1415)) ([dab4879](https://github.com/dryvist/nix-darwin/commit/dab48790a68fea68e49f5af20d74c3b0c1b636bc))
* **cribl-edge:** restart the daemon when declared config content changes ([#1569](https://github.com/dryvist/nix-darwin/issues/1569)) ([d796841](https://github.com/dryvist/nix-darwin/commit/d7968419c6da92b84f262a6c874e44fe3359aecf))
* **cribl-edge:** valid file-input schema, tcpjson transport, config-before-launchd ordering ([#1419](https://github.com/dryvist/nix-darwin/issues/1419)) ([7bf0743](https://github.com/dryvist/nix-darwin/commit/7bf0743c12d68535369e34e2ae147b8aca5ea59a))
* **cribl:** drop the llm_prom scraper — prometheus source not allowed standalone ([#1582](https://github.com/dryvist/nix-darwin/issues/1582)) ([27efc6c](https://github.com/dryvist/nix-darwin/commit/27efc6c3b273c34eb3b8a035f3ed5fb614b314e3))
* **cribl:** file-source filenames must be globs — literal names match nothing ([#1633](https://github.com/dryvist/nix-darwin/issues/1633)) ([eb9e1a9](https://github.com/dryvist/nix-darwin/commit/eb9e1a90c046befad5d3ff4fbc27642935cc66af)), closes [#1623](https://github.com/dryvist/nix-darwin/issues/1623)
* **cribl:** filenames match the full path — lead patterns with */ ([#1634](https://github.com/dryvist/nix-darwin/issues/1634)) ([eef5587](https://github.com/dryvist/nix-darwin/commit/eef5587a72b9df464d60988de143d769ec4be356))
* **cribl:** logLevel is required on the prometheus input schema ([#1580](https://github.com/dryvist/nix-darwin/issues/1580)) ([67e594f](https://github.com/dryvist/nix-darwin/commit/67e594f9f10605c51af7895426098a435f36ac07))
* **cribl:** point Edge tcpjson output at the live Stream port 10300 ([#1560](https://github.com/dryvist/nix-darwin/issues/1560)) ([730a54c](https://github.com/dryvist/nix-darwin/commit/730a54c1f7ec361a2eaf5ef4bf1ab9ae720df213))
* **cribl:** ship Claude Code transcripts natively; drop stray conflict marker ([#1577](https://github.com/dryvist/nix-darwin/issues/1577)) ([a5665f2](https://github.com/dryvist/nix-darwin/commit/a5665f23b4e5eee45eb8c3168c5773a7ad1d47fe))
* **deps:** bump nix-ai for the transformers 5.12.0 pin (serving outage) ([4d56877](https://github.com/dryvist/nix-darwin/commit/4d5687749fca16f6a870914be4cec7661d128745))
* **deps:** refresh gh-aw action SHA pins ([#1088](https://github.com/dryvist/nix-darwin/issues/1088)) ([eb14ada](https://github.com/dryvist/nix-darwin/commit/eb14ada0778dfffca6f191aed9076da5b2cb7716))
* **deps:** refresh gh-aw action SHA pins ([#1099](https://github.com/dryvist/nix-darwin/issues/1099)) ([8d9f0c9](https://github.com/dryvist/nix-darwin/commit/8d9f0c9457e96b48abc7c135c2a4ad14f8928371))
* **deps:** refresh gh-aw action SHA pins ([#1110](https://github.com/dryvist/nix-darwin/issues/1110)) ([5ed0801](https://github.com/dryvist/nix-darwin/commit/5ed0801f5d7f508d7cdbae4389edc90a1378f151))
* **deps:** refresh gh-aw action SHA pins ([#1126](https://github.com/dryvist/nix-darwin/issues/1126)) ([f11500f](https://github.com/dryvist/nix-darwin/commit/f11500f6f5785beb5931f0f65c0b82aaed713501))
* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1144](https://github.com/dryvist/nix-darwin/issues/1144)) ([442d44e](https://github.com/dryvist/nix-darwin/commit/442d44e89762b5b07f6a1160bab668c4b91019ba))
* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1285](https://github.com/dryvist/nix-darwin/issues/1285)) ([ac30ea9](https://github.com/dryvist/nix-darwin/commit/ac30ea9df6c6399d41bc4f8358aeb093ddf8edd0))
* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1314](https://github.com/dryvist/nix-darwin/issues/1314)) ([2833047](https://github.com/dryvist/nix-darwin/commit/28330477f1f5ea9535c7df5cb032e86aac18108e))
* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1346](https://github.com/dryvist/nix-darwin/issues/1346)) ([7866ac7](https://github.com/dryvist/nix-darwin/commit/7866ac7dca86bd4c4d7a62172d19e380d67c333d))
* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1390](https://github.com/dryvist/nix-darwin/issues/1390)) ([ff9e41e](https://github.com/dryvist/nix-darwin/commit/ff9e41e61944d72a0ce6a50be371ba15a1af6662))
* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1532](https://github.com/dryvist/nix-darwin/issues/1532)) ([709a878](https://github.com/dryvist/nix-darwin/commit/709a87807e12e0d938a1202ae2684eb6de9e9abd))
* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1605](https://github.com/dryvist/nix-darwin/issues/1605)) ([217319a](https://github.com/dryvist/nix-darwin/commit/217319ac8922c954849b5ff3bf806dafe3315e1f))
* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1629](https://github.com/dryvist/nix-darwin/issues/1629)) ([efb1d00](https://github.com/dryvist/nix-darwin/commit/efb1d002feb88211160c497a68915e2a984ee140))
* **deps:** update jacobpevans-cc-plugins to 3.4.2 (git-guard -C fix) ([#1096](https://github.com/dryvist/nix-darwin/issues/1096)) ([f055040](https://github.com/dryvist/nix-darwin/commit/f05504009ccf8649cbf13c4e3aff6a790de4afff))
* drop the custom /run pre-check that aborts first bootstrap ([#1403](https://github.com/dryvist/nix-darwin/issues/1403)) ([8a31b70](https://github.com/dryvist/nix-darwin/commit/8a31b7092f73b2866992f3136fa662596ac7c5a8))
* first-bootstrap fixes — adopt installer nix.custom.conf; lean server-class (Homebrew/GUI gating) ([#1406](https://github.com/dryvist/nix-darwin/issues/1406)) ([c024872](https://github.com/dryvist/nix-darwin/commit/c0248726cb7ebafbebcd673a2ba51d0414c1a51b))
* **flake:** scope checks to x86_64-linux; restore --all-systems default ([#1101](https://github.com/dryvist/nix-darwin/issues/1101)) ([1d90ff9](https://github.com/dryvist/nix-darwin/commit/1d90ff9365c3c773f943866f3a0defdbd3d37649))
* **homebrew:** add powershell@preview cask ([#1184](https://github.com/dryvist/nix-darwin/issues/1184)) ([d88f8ff](https://github.com/dryvist/nix-darwin/commit/d88f8ff2212d109c0e69fdba64969262db571845))
* **homebrew:** declare claude-code@latest cask to match install ([#1167](https://github.com/dryvist/nix-darwin/issues/1167)) ([b40291d](https://github.com/dryvist/nix-darwin/commit/b40291d0b59c67c6ac3aa98e059124c865e07a09))
* **homebrew:** drop powershell@preview cask, migrate to nix-devenv ([#1195](https://github.com/dryvist/nix-darwin/issues/1195)) ([c3249b1](https://github.com/dryvist/nix-darwin/commit/c3249b1800648ef63d25e134348d62ce85d879a0))
* **homebrew:** drop Shortwave for Apple Mail; move bitwarden-desktop to cask ([#1181](https://github.com/dryvist/nix-darwin/issues/1181)) ([e770edb](https://github.com/dryvist/nix-darwin/commit/e770edb34ecf69a98b6b4a83160f376fcd5f9313))
* **homebrew:** nixfmt-required whitespace in taps list append ([#1214](https://github.com/dryvist/nix-darwin/issues/1214)) ([ac93fa1](https://github.com/dryvist/nix-darwin/commit/ac93fa1a42d773b1d2d4d2ab4d07181afc1eb31c))
* **homebrew:** pass -H to sudo so brew bootsnap finds the user cache ([#1120](https://github.com/dryvist/nix-darwin/issues/1120)) ([8195386](https://github.com/dryvist/nix-darwin/commit/819538662d4b75d7311d2e694654e63f8682a191))
* **homebrew:** stop managing OneDrive via masApps ([#1324](https://github.com/dryvist/nix-darwin/issues/1324)) ([a75ffed](https://github.com/dryvist/nix-darwin/commit/a75ffed1f08a3274550722239bf92cb0a7c68431))
* **home:** guard brew block and ship ghostty terminfo to all hosts ([#1462](https://github.com/dryvist/nix-darwin/issues/1462)) ([a8ddce9](https://github.com/dryvist/nix-darwin/commit/a8ddce99a18b11acc515dcc7b0df3c194c5f006e))
* **home:** resolve xterm-ghostty terminfo at early login-shell init ([3a80b59](https://github.com/dryvist/nix-darwin/commit/3a80b598729c08d207518d95378a91472adf0db9))
* **identity:** keep fullName "JacobPEvans" for cross-repo consistency ([#1157](https://github.com/dryvist/nix-darwin/issues/1157)) ([56b3689](https://github.com/dryvist/nix-darwin/commit/56b3689976bf797788363fb7b1bbc34a82c67847)), closes [#1155](https://github.com/dryvist/nix-darwin/issues/1155)
* **identity:** point git identity at renamed JacobPEvans-personal account ([#1155](https://github.com/dryvist/nix-darwin/issues/1155)) ([a2ac84b](https://github.com/dryvist/nix-darwin/commit/a2ac84bfdb7a491195b4875e3239ff8f8e38e4f4))
* **launchd:** disable orbstack-background agent and remove procps shadow ([#1083](https://github.com/dryvist/nix-darwin/issues/1083)) ([2beca55](https://github.com/dryvist/nix-darwin/commit/2beca55d8ebdf39e8d37a53c8f5740951c2d752e))
* **llm-gate,gh-runner:** drop RunAtLoad so KeepAlive.PathState governs startup ([e0b82c7](https://github.com/dryvist/nix-darwin/commit/e0b82c77a5e14123929b40d50776059758ac9e11))
* **llm-gate,gh-runner:** KeepAlive PathState on sops-rendered inputs ([#1425](https://github.com/dryvist/nix-darwin/issues/1425)) ([d62e85b](https://github.com/dryvist/nix-darwin/commit/d62e85bc65cee79cc7221e847905af5dbbbf0036))
* **llm-gate:** bind all interfaces — drop the bind-IP secret entirely ([#1409](https://github.com/dryvist/nix-darwin/issues/1409)) ([664ed35](https://github.com/dryvist/nix-darwin/commit/664ed35fc13ee9644819d3b75ef80596ff570ddc))
* **llm-gate:** move service alias to the public zone so DNS-01 issues ([#1518](https://github.com/dryvist/nix-darwin/issues/1518)) ([cd0e74f](https://github.com/dryvist/nix-darwin/commit/cd0e74fc0d8e2dbeda4046aab93ae2b5f4367fc0))
* log the app removal + silence local nixfmt/menu-bar noise ([#1495](https://github.com/dryvist/nix-darwin/issues/1495)) ([241f7e7](https://github.com/dryvist/nix-darwin/commit/241f7e793167a4d9587a17d78997c3d2f0834779))
* **logging:** HUP syslogd after /etc/syslog.conf changes ([#1586](https://github.com/dryvist/nix-darwin/issues/1586)) ([531d96a](https://github.com/dryvist/nix-darwin/commit/531d96acac6a42e5d8b10e8283aada38fd7d187d))
* **mac-studio:** 256-token paged-cache blocks + DRY serving groups ([#1609](https://github.com/dryvist/nix-darwin/issues/1609)) ([4774f37](https://github.com/dryvist/nix-darwin/commit/4774f37d693f7647cd3e7993473b40d8a1ef09a3))
* **mac-studio:** disable idle eviction for resident models ([#1417](https://github.com/dryvist/nix-darwin/issues/1417)) ([8114598](https://github.com/dryvist/nix-darwin/commit/8114598c26b00812c092d016797ce4c123f29869))
* **mac-studio:** disable paged KV cache for gpt-oss-120b ([#1413](https://github.com/dryvist/nix-darwin/issues/1413)) ([8bf5f1e](https://github.com/dryvist/nix-darwin/commit/8bf5f1e69336fb289d176cfaf343df68ce4cafc8))
* **mac-studio:** raise llama-swap concurrency limit for the serving host ([#1421](https://github.com/dryvist/nix-darwin/issues/1421)) ([6eb1ae6](https://github.com/dryvist/nix-darwin/commit/6eb1ae6988e6ad458cd1ba915831ae272af2cf71))
* **mac-studio:** raise Qwen3-Coder output cap to 32768 for the Hermes brain ([#1539](https://github.com/dryvist/nix-darwin/issues/1539)) ([822d85a](https://github.com/dryvist/nix-darwin/commit/822d85a8ee1e7ddb19e7419652b8e00d4ca27baa))
* **mac-studio:** rotate real runner PAT into github-runner secret ([#1423](https://github.com/dryvist/nix-darwin/issues/1423)) ([154eaf9](https://github.com/dryvist/nix-darwin/commit/154eaf95c184ef73a126ef3ba7e0280401ba0910))
* **mlx:** enable gpt-oss reasoning parser to stop harmony channel leak ([#1537](https://github.com/dryvist/nix-darwin/issues/1537)) ([c4e3ce3](https://github.com/dryvist/nix-darwin/commit/c4e3ce3dd8a14841808fd6172e5d4b7f66695941))
* **mlx:** quote Qwen3.6 chat-template kwargs for llama-swap shell parsing ([#1557](https://github.com/dryvist/nix-darwin/issues/1557)) ([a70f810](https://github.com/dryvist/nix-darwin/commit/a70f81027b12f900cef9b070babe4bca6ba65b37))
* **mlx:** Qwen3.6 swap models crash on load — parser args were in the wrong attr ([#1550](https://github.com/dryvist/nix-darwin/issues/1550)) ([f6c0427](https://github.com/dryvist/nix-darwin/commit/f6c042707a239c185c1b3c9defb9142522f006f5))
* **mlx:** Qwen3.6-27B swap model pointed at a nonexistent HF repo ([#1552](https://github.com/dryvist/nix-darwin/issues/1552)) ([593faa1](https://github.com/dryvist/nix-darwin/commit/593faa134e665a25d11693a15c17250223b5c8a2))
* **mlx:** set safer vllm-mlx thinking defaults ([#1555](https://github.com/dryvist/nix-darwin/issues/1555)) ([e5bb5b5](https://github.com/dryvist/nix-darwin/commit/e5bb5b511895934a44f5ef0a1fcffb0398e5d2ad))
* **night-cluster:** shebangs on the quiesce fragment scripts for the shellcheck sweep ([3fb3eba](https://github.com/dryvist/nix-darwin/commit/3fb3ebaf8a2e8f0901668e18b72b28b3ed35114e))
* **night-quiesce:** attribute-existence gate + double-quiesce state guard ([930c860](https://github.com/dryvist/nix-darwin/commit/930c860014d15e8c40bd12fb966c5051aed8234a))
* point callers at renamed cc- reusable workflows ([e53c631](https://github.com/dryvist/nix-darwin/commit/e53c631402eee33bc70006b4d3009b28b3206961))
* **python:** consume PyYAML-enabled home env ([#1265](https://github.com/dryvist/nix-darwin/issues/1265)) ([d94dca7](https://github.com/dryvist/nix-darwin/commit/d94dca752c0e293918998af3f9972dbf88106d2e))
* **renovate:** repair cribl-edge datasource transform + migrate deprecated options ([#1488](https://github.com/dryvist/nix-darwin/issues/1488)) ([c006e8d](https://github.com/dryvist/nix-darwin/commit/c006e8dd19763c78036a6cbd0281c739777e86e1))
* shorten MANIFEST service rows to the MD013 line limit ([#1399](https://github.com/dryvist/nix-darwin/issues/1399)) ([4825060](https://github.com/dryvist/nix-darwin/commit/4825060161f032391e085e7af5e7479adabbc1da))
* stop running brew update/doctor on login under nix-homebrew ([#1485](https://github.com/dryvist/nix-darwin/issues/1485)) ([0c297e1](https://github.com/dryvist/nix-darwin/commit/0c297e1d4640724238ca3d0bc24e042adb82821d))
* **studio:** claude jobs use the vendor install path; ship ghostty terminfo on servers ([87f0c6e](https://github.com/dryvist/nix-darwin/commit/87f0c6e641322db0b7f3b0d1cbd78040127aee05))

## [1.74.3](https://github.com/dryvist/nix-darwin/compare/v1.74.2...v1.74.3) (2026-07-10)


### Bug Fixes

* Cribl Edge in_llm_logs ships nothing — vllm-mlx.log never reaches Splunk ([#1623](https://github.com/dryvist/nix-darwin/issues/1623)) ([#1624](https://github.com/dryvist/nix-darwin/issues/1624)) ([c39ab21](https://github.com/dryvist/nix-darwin/commit/c39ab212dbcbe47835f99b70d7fe66dacaeb12d1))

## [1.74.2](https://github.com/dryvist/nix-darwin/compare/v1.74.1...v1.74.2) (2026-07-09)


### Bug Fixes

* **mac-studio:** 256-token paged-cache blocks + DRY serving groups ([#1609](https://github.com/dryvist/nix-darwin/issues/1609)) ([4774f37](https://github.com/dryvist/nix-darwin/commit/4774f37d693f7647cd3e7993473b40d8a1ef09a3))

## [1.74.1](https://github.com/dryvist/nix-darwin/compare/v1.74.0...v1.74.1) (2026-07-09)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1605](https://github.com/dryvist/nix-darwin/issues/1605)) ([217319a](https://github.com/dryvist/nix-darwin/commit/217319ac8922c954849b5ff3bf806dafe3315e1f))

## [1.74.0](https://github.com/dryvist/nix-darwin/compare/v1.73.0...v1.74.0) (2026-07-08)


### Features

* **mlx:** register Qwen3-Next-80B Thinking as the swap-tier large brain ([#1591](https://github.com/dryvist/nix-darwin/issues/1591)) ([4036108](https://github.com/dryvist/nix-darwin/commit/403610880056ba5576b8929fc82bbe996746ddde))

## [1.73.0](https://github.com/dryvist/nix-darwin/compare/v1.72.1...v1.73.0) (2026-07-08)


### Features

* **mlx:** make OptiQ-4bit 35B the resident tool-calling brain on jevans-ms ([#1589](https://github.com/dryvist/nix-darwin/issues/1589)) ([33dc416](https://github.com/dryvist/nix-darwin/commit/33dc41685c52981465e26e41bde5ac8c2321452b))

## [1.72.1](https://github.com/dryvist/nix-darwin/compare/v1.72.0...v1.72.1) (2026-07-08)


### Bug Fixes

* **logging:** HUP syslogd after /etc/syslog.conf changes ([#1586](https://github.com/dryvist/nix-darwin/issues/1586)) ([531d96a](https://github.com/dryvist/nix-darwin/commit/531d96acac6a42e5d8b10e8283aada38fd7d187d))

## [1.72.0](https://github.com/dryvist/nix-darwin/compare/v1.71.3...v1.72.0) (2026-07-08)


### Features

* **logging:** retire syslogd remote forward, ship firewall unified-log via Cribl Edge ([#1584](https://github.com/dryvist/nix-darwin/issues/1584)) ([bbee58d](https://github.com/dryvist/nix-darwin/commit/bbee58daa08f1651bd7f442f85e3977b394c683b))

## [1.71.3](https://github.com/dryvist/nix-darwin/compare/v1.71.2...v1.71.3) (2026-07-08)


### Bug Fixes

* **cribl:** drop the llm_prom scraper — prometheus source not allowed standalone ([#1582](https://github.com/dryvist/nix-darwin/issues/1582)) ([27efc6c](https://github.com/dryvist/nix-darwin/commit/27efc6c3b273c34eb3b8a035f3ed5fb614b314e3))

## [1.71.2](https://github.com/dryvist/nix-darwin/compare/v1.71.1...v1.71.2) (2026-07-08)


### Bug Fixes

* **cribl:** logLevel is required on the prometheus input schema ([#1580](https://github.com/dryvist/nix-darwin/issues/1580)) ([67e594f](https://github.com/dryvist/nix-darwin/commit/67e594f9f10605c51af7895426098a435f36ac07))

## [1.71.1](https://github.com/dryvist/nix-darwin/compare/v1.71.0...v1.71.1) (2026-07-08)


### Bug Fixes

* **cribl:** ship Claude Code transcripts natively; drop stray conflict marker ([#1577](https://github.com/dryvist/nix-darwin/issues/1577)) ([a5665f2](https://github.com/dryvist/nix-darwin/commit/a5665f23b4e5eee45eb8c3168c5773a7ad1d47fe))

## [1.71.0](https://github.com/dryvist/nix-darwin/compare/v1.70.1...v1.71.0) (2026-07-08)


### Features

* **llm:** scrape llama-swap Prometheus metrics into the llm_metrics index ([#1564](https://github.com/dryvist/nix-darwin/issues/1564)) ([d359d22](https://github.com/dryvist/nix-darwin/commit/d359d22a9225c0c318a2ae6717fb9ceff583d8d7))

## [1.70.1](https://github.com/dryvist/nix-darwin/compare/v1.70.0...v1.70.1) (2026-07-07)


### Bug Fixes

* **cribl-edge:** restart the daemon when declared config content changes ([#1569](https://github.com/dryvist/nix-darwin/issues/1569)) ([d796841](https://github.com/dryvist/nix-darwin/commit/d7968419c6da92b84f262a6c874e44fe3359aecf))

## [1.70.0](https://github.com/dryvist/nix-darwin/compare/v1.69.0...v1.70.0) (2026-07-07)


### Features

* **llm:** dedicated Cribl service ports for LLM logs + gate access log ([#1562](https://github.com/dryvist/nix-darwin/issues/1562)) ([74d2ac7](https://github.com/dryvist/nix-darwin/commit/74d2ac7581996edaad7f8d48be0471c0aec0804a))

## [1.69.0](https://github.com/dryvist/nix-darwin/compare/v1.68.5...v1.69.0) (2026-07-07)


### Features

* **logging:** per-AI-CLI log capture + dedicated Cribl Edge shipping ([#1561](https://github.com/dryvist/nix-darwin/issues/1561)) ([33578c1](https://github.com/dryvist/nix-darwin/commit/33578c1be06fdcc6e9eda46db8efd4cca73a6f32))

## [1.68.5](https://github.com/dryvist/nix-darwin/compare/v1.68.4...v1.68.5) (2026-07-07)


### Bug Fixes

* **cribl:** point Edge tcpjson output at the live Stream port 10300 ([#1560](https://github.com/dryvist/nix-darwin/issues/1560)) ([730a54c](https://github.com/dryvist/nix-darwin/commit/730a54c1f7ec361a2eaf5ef4bf1ab9ae720df213))

## [1.68.4](https://github.com/dryvist/nix-darwin/compare/v1.68.3...v1.68.4) (2026-07-07)


### Bug Fixes

* **mlx:** quote Qwen3.6 chat-template kwargs for llama-swap shell parsing ([#1557](https://github.com/dryvist/nix-darwin/issues/1557)) ([a70f810](https://github.com/dryvist/nix-darwin/commit/a70f81027b12f900cef9b070babe4bca6ba65b37))

## [1.68.3](https://github.com/dryvist/nix-darwin/compare/v1.68.2...v1.68.3) (2026-07-07)


### Bug Fixes

* **mlx:** set safer vllm-mlx thinking defaults ([#1555](https://github.com/dryvist/nix-darwin/issues/1555)) ([e5bb5b5](https://github.com/dryvist/nix-darwin/commit/e5bb5b511895934a44f5ef0a1fcffb0398e5d2ad))

## [1.68.2](https://github.com/dryvist/nix-darwin/compare/v1.68.1...v1.68.2) (2026-07-07)


### Bug Fixes

* **mlx:** Qwen3.6-27B swap model pointed at a nonexistent HF repo ([#1552](https://github.com/dryvist/nix-darwin/issues/1552)) ([593faa1](https://github.com/dryvist/nix-darwin/commit/593faa134e665a25d11693a15c17250223b5c8a2))

## [1.68.1](https://github.com/dryvist/nix-darwin/compare/v1.68.0...v1.68.1) (2026-07-07)


### Bug Fixes

* **mlx:** Qwen3.6 swap models crash on load — parser args were in the wrong attr ([#1550](https://github.com/dryvist/nix-darwin/issues/1550)) ([f6c0427](https://github.com/dryvist/nix-darwin/commit/f6c042707a239c185c1b3c9defb9142522f006f5))

## [1.68.0](https://github.com/dryvist/nix-darwin/compare/v1.67.2...v1.68.0) (2026-07-07)


### Features

* tune Mac Studio serving stack for Qwen3.6 ([#1545](https://github.com/dryvist/nix-darwin/issues/1545)) ([a86c5e7](https://github.com/dryvist/nix-darwin/commit/a86c5e7bf8d897569372b2651f740fa8090ac59c))

## [1.67.2](https://github.com/dryvist/nix-darwin/compare/v1.67.1...v1.67.2) (2026-07-07)


### Bug Fixes

* **mac-studio:** raise Qwen3-Coder output cap to 32768 for the Hermes brain ([#1539](https://github.com/dryvist/nix-darwin/issues/1539)) ([822d85a](https://github.com/dryvist/nix-darwin/commit/822d85a8ee1e7ddb19e7419652b8e00d4ca27baa))

## [1.67.1](https://github.com/dryvist/nix-darwin/compare/v1.67.0...v1.67.1) (2026-07-06)


### Bug Fixes

* **mlx:** enable gpt-oss reasoning parser to stop harmony channel leak ([#1537](https://github.com/dryvist/nix-darwin/issues/1537)) ([c4e3ce3](https://github.com/dryvist/nix-darwin/commit/c4e3ce3dd8a14841808fd6172e5d4b7f66695941))

## [1.67.0](https://github.com/dryvist/nix-darwin/compare/v1.66.1...v1.67.0) (2026-07-06)


### Features

* schedule auto-upgrade directly ([#1535](https://github.com/dryvist/nix-darwin/issues/1535)) ([45caee9](https://github.com/dryvist/nix-darwin/commit/45caee9abc3d61d4963561b21a811ecdee522070))

## [1.66.1](https://github.com/dryvist/nix-darwin/compare/v1.66.0...v1.66.1) (2026-07-06)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1532](https://github.com/dryvist/nix-darwin/issues/1532)) ([709a878](https://github.com/dryvist/nix-darwin/commit/709a87807e12e0d938a1202ae2684eb6de9e9abd))

## [1.66.0](https://github.com/dryvist/nix-darwin/compare/v1.65.0...v1.66.0) (2026-07-05)


### Features

* add MacBook open harness tools ([#1530](https://github.com/dryvist/nix-darwin/issues/1530)) ([6db6171](https://github.com/dryvist/nix-darwin/commit/6db61713ef8cb993d989df78458565089d26463f))

## [1.65.0](https://github.com/dryvist/nix-darwin/compare/v1.64.4...v1.65.0) (2026-07-05)


### Features

* **openbao:** dedicated keychain + resolver LaunchAgent for secret-zero ([#1493](https://github.com/dryvist/nix-darwin/issues/1493)) ([9aab7a1](https://github.com/dryvist/nix-darwin/commit/9aab7a178da0e5d10f40477d3aec6cebad4b5d34))

## [1.64.4](https://github.com/dryvist/nix-darwin/compare/v1.64.3...v1.64.4) (2026-07-04)


### Bug Fixes

* **llm-gate:** move service alias to the public zone so DNS-01 issues ([#1518](https://github.com/dryvist/nix-darwin/issues/1518)) ([cd0e74f](https://github.com/dryvist/nix-darwin/commit/cd0e74fc0d8e2dbeda4046aab93ae2b5f4367fc0))

## [1.64.3](https://github.com/dryvist/nix-darwin/compare/v1.64.2...v1.64.3) (2026-07-04)


### Bug Fixes

* **home:** resolve xterm-ghostty terminfo at early login-shell init ([3a80b59](https://github.com/dryvist/nix-darwin/commit/3a80b598729c08d207518d95378a91472adf0db9))

## [1.64.2](https://github.com/dryvist/nix-darwin/compare/v1.64.1...v1.64.2) (2026-07-04)


### Bug Fixes

* **llm-gate,gh-runner:** drop RunAtLoad so KeepAlive.PathState governs startup ([e0b82c7](https://github.com/dryvist/nix-darwin/commit/e0b82c77a5e14123929b40d50776059758ac9e11))

## [1.64.1](https://github.com/dryvist/nix-darwin/compare/v1.64.0...v1.64.1) (2026-07-04)


### Bug Fixes

* **deps:** bump nix-ai for the transformers 5.12.0 pin (serving outage) ([4d56877](https://github.com/dryvist/nix-darwin/commit/4d5687749fca16f6a870914be4cec7661d128745))

## [1.64.0](https://github.com/dryvist/nix-darwin/compare/v1.63.2...v1.64.0) (2026-07-04)


### Features

* enable issues:labeled trigger to close the auto-resolve loop ([#1502](https://github.com/dryvist/nix-darwin/issues/1502)) ([74419a2](https://github.com/dryvist/nix-darwin/commit/74419a29d510a6bf432d37f7c4009a43c20edaa1))

## [1.63.2](https://github.com/dryvist/nix-darwin/compare/v1.63.1...v1.63.2) (2026-07-04)


### Bug Fixes

* log the app removal + silence local nixfmt/menu-bar noise ([#1495](https://github.com/dryvist/nix-darwin/issues/1495)) ([241f7e7](https://github.com/dryvist/nix-darwin/commit/241f7e793167a4d9587a17d78997c3d2f0834779))

## [1.63.1](https://github.com/dryvist/nix-darwin/compare/v1.63.0...v1.63.1) (2026-07-04)


### Bug Fixes

* **studio:** claude jobs use the vendor install path; ship ghostty terminfo on servers ([87f0c6e](https://github.com/dryvist/nix-darwin/commit/87f0c6e641322db0b7f3b0d1cbd78040127aee05))

## [1.63.0](https://github.com/dryvist/nix-darwin/compare/v1.62.2...v1.63.0) (2026-07-04)


### Features

* lean-host cleanup — declarative app removal + _brew prune + strict deadnix ([#1490](https://github.com/dryvist/nix-darwin/issues/1490)) ([090a6ef](https://github.com/dryvist/nix-darwin/commit/090a6efadadf32b1625628832ac758a3da49343a))

## [1.62.2](https://github.com/dryvist/nix-darwin/compare/v1.62.1...v1.62.2) (2026-07-04)


### Bug Fixes

* **renovate:** repair cribl-edge datasource transform + migrate deprecated options ([#1488](https://github.com/dryvist/nix-darwin/issues/1488)) ([c006e8d](https://github.com/dryvist/nix-darwin/commit/c006e8dd19763c78036a6cbd0281c739777e86e1))

## [1.62.1](https://github.com/dryvist/nix-darwin/compare/v1.62.0...v1.62.1) (2026-07-04)


### Bug Fixes

* stop running brew update/doctor on login under nix-homebrew ([#1485](https://github.com/dryvist/nix-darwin/issues/1485)) ([0c297e1](https://github.com/dryvist/nix-darwin/commit/0c297e1d4640724238ca3d0bc24e042adb82821d))

## [1.62.0](https://github.com/dryvist/nix-darwin/compare/v1.61.1...v1.62.0) (2026-07-04)


### Features

* bump nixpkgs to 26.05; resolve all 26.05 breakage ([#1481](https://github.com/dryvist/nix-darwin/issues/1481)) ([bd0a62b](https://github.com/dryvist/nix-darwin/commit/bd0a62ba83cfb8c166e0ee0e8929c8885f1766e5))

## [1.61.1](https://github.com/dryvist/nix-darwin/compare/v1.61.0...v1.61.1) (2026-07-04)


### Bug Fixes

* **home:** guard brew block and ship ghostty terminfo to all hosts ([#1462](https://github.com/dryvist/nix-darwin/issues/1462)) ([a8ddce9](https://github.com/dryvist/nix-darwin/commit/a8ddce99a18b11acc515dcc7b0df3c194c5f006e))

## [1.61.0](https://github.com/dryvist/nix-darwin/compare/v1.60.0...v1.61.0) (2026-07-03)


### Features

* **homebrew:** install Homebrew declaratively via nix-homebrew ([#1474](https://github.com/dryvist/nix-darwin/issues/1474)) ([104635d](https://github.com/dryvist/nix-darwin/commit/104635d67c8917071c0e99644357116f3696dd51))

## [1.60.0](https://github.com/dryvist/nix-darwin/compare/v1.59.0...v1.60.0) (2026-07-03)


### Features

* add issue-backlog-sweep caller ([#1470](https://github.com/dryvist/nix-darwin/issues/1470)) ([a5b6791](https://github.com/dryvist/nix-darwin/commit/a5b67916876cec482d09a1697966dfde53b91417))

## [1.59.0](https://github.com/dryvist/nix-darwin/compare/v1.58.0...v1.59.0) (2026-07-03)


### Features

* **llm-gate:** API-only gate, extraHostnames cert SAN, route53 on studio ([#1467](https://github.com/dryvist/nix-darwin/issues/1467)) ([1c2a80d](https://github.com/dryvist/nix-darwin/commit/1c2a80d09d8c131b2484cb80c8753fd636c39d16))

## [1.58.0](https://github.com/dryvist/nix-darwin/compare/v1.57.0...v1.58.0) (2026-07-03)


### Features

* **studio:** add nix-managed scheduled claude jobs ([8ba4177](https://github.com/dryvist/nix-darwin/commit/8ba4177138ab4a1436b8bc6f32f694b9eb3f8aa8))

## [1.57.0](https://github.com/dryvist/nix-darwin/compare/v1.56.0...v1.57.0) (2026-07-03)


### Features

* add review-thread-resolver caller for instant bot-thread resolution ([#1448](https://github.com/dryvist/nix-darwin/issues/1448)) ([c326c3f](https://github.com/dryvist/nix-darwin/commit/c326c3f1f95df9660dddbefaab690080a8dc81dc))

## [1.56.0](https://github.com/dryvist/nix-darwin/compare/v1.55.0...v1.56.0) (2026-07-03)


### Features

* **packages:** add neat menu-bar app via homebrew cask ([#1444](https://github.com/dryvist/nix-darwin/issues/1444)) ([1f1fb9c](https://github.com/dryvist/nix-darwin/commit/1f1fb9c600e07677c7606f0a5fe051372a6707a5))

## [1.55.0](https://github.com/dryvist/nix-darwin/compare/v1.54.10...v1.55.0) (2026-07-03)


### Features

* add AI PR care caller (dep review + release highlights) ([#1433](https://github.com/dryvist/nix-darwin/issues/1433)) ([2454bb2](https://github.com/dryvist/nix-darwin/commit/2454bb2f669449492bbb1a7e7f7b095c51c7e61e))

## [1.54.10](https://github.com/dryvist/nix-darwin/compare/v1.54.9...v1.54.10) (2026-07-03)


### Bug Fixes

* **llm-gate,gh-runner:** KeepAlive PathState on sops-rendered inputs ([#1425](https://github.com/dryvist/nix-darwin/issues/1425)) ([d62e85b](https://github.com/dryvist/nix-darwin/commit/d62e85bc65cee79cc7221e847905af5dbbbf0036))

## [1.54.9](https://github.com/dryvist/nix-darwin/compare/v1.54.8...v1.54.9) (2026-07-03)


### Bug Fixes

* **mac-studio:** rotate real runner PAT into github-runner secret ([#1423](https://github.com/dryvist/nix-darwin/issues/1423)) ([154eaf9](https://github.com/dryvist/nix-darwin/commit/154eaf95c184ef73a126ef3ba7e0280401ba0910))

## [1.54.8](https://github.com/dryvist/nix-darwin/compare/v1.54.7...v1.54.8) (2026-07-03)


### Bug Fixes

* **mac-studio:** raise llama-swap concurrency limit for the serving host ([#1421](https://github.com/dryvist/nix-darwin/issues/1421)) ([6eb1ae6](https://github.com/dryvist/nix-darwin/commit/6eb1ae6988e6ad458cd1ba915831ae272af2cf71))

## [1.54.7](https://github.com/dryvist/nix-darwin/compare/v1.54.6...v1.54.7) (2026-07-03)


### Bug Fixes

* **cribl-edge:** valid file-input schema, tcpjson transport, config-before-launchd ordering ([#1419](https://github.com/dryvist/nix-darwin/issues/1419)) ([7bf0743](https://github.com/dryvist/nix-darwin/commit/7bf0743c12d68535369e34e2ae147b8aca5ea59a))

## [1.54.6](https://github.com/dryvist/nix-darwin/compare/v1.54.5...v1.54.6) (2026-07-03)


### Bug Fixes

* **mac-studio:** disable idle eviction for resident models ([#1417](https://github.com/dryvist/nix-darwin/issues/1417)) ([8114598](https://github.com/dryvist/nix-darwin/commit/8114598c26b00812c092d016797ce4c123f29869))

## [1.54.5](https://github.com/dryvist/nix-darwin/compare/v1.54.4...v1.54.5) (2026-07-03)


### Bug Fixes

* **cribl-edge:** install standalone config into the edge tree, not cribl ([#1415](https://github.com/dryvist/nix-darwin/issues/1415)) ([dab4879](https://github.com/dryvist/nix-darwin/commit/dab48790a68fea68e49f5af20d74c3b0c1b636bc))

## [1.54.4](https://github.com/dryvist/nix-darwin/compare/v1.54.3...v1.54.4) (2026-07-02)


### Bug Fixes

* **mac-studio:** disable paged KV cache for gpt-oss-120b ([#1413](https://github.com/dryvist/nix-darwin/issues/1413)) ([8bf5f1e](https://github.com/dryvist/nix-darwin/commit/8bf5f1e69336fb289d176cfaf343df68ce4cafc8))

## [1.54.3](https://github.com/dryvist/nix-darwin/compare/v1.54.2...v1.54.3) (2026-07-02)


### Bug Fixes

* **llm-gate:** bind all interfaces — drop the bind-IP secret entirely ([#1409](https://github.com/dryvist/nix-darwin/issues/1409)) ([664ed35](https://github.com/dryvist/nix-darwin/commit/664ed35fc13ee9644819d3b75ef80596ff570ddc))

## [1.54.2](https://github.com/dryvist/nix-darwin/compare/v1.54.1...v1.54.2) (2026-07-02)


### Bug Fixes

* first-bootstrap fixes — adopt installer nix.custom.conf; lean server-class (Homebrew/GUI gating) ([#1406](https://github.com/dryvist/nix-darwin/issues/1406)) ([c024872](https://github.com/dryvist/nix-darwin/commit/c0248726cb7ebafbebcd673a2ba51d0414c1a51b))

## [1.54.1](https://github.com/dryvist/nix-darwin/compare/v1.54.0...v1.54.1) (2026-07-02)


### Bug Fixes

* drop the custom /run pre-check that aborts first bootstrap ([#1403](https://github.com/dryvist/nix-darwin/issues/1403)) ([8a31b70](https://github.com/dryvist/nix-darwin/commit/8a31b7092f73b2866992f3136fa662596ac7c5a8))

## [1.54.0](https://github.com/dryvist/nix-darwin/compare/v1.53.1...v1.54.0) (2026-07-02)


### Features

* HF_TOKEN via sops on server-class hosts (keychain-free real secrets) ([#1401](https://github.com/dryvist/nix-darwin/issues/1401)) ([35095fb](https://github.com/dryvist/nix-darwin/commit/35095fbc446d64e8d22487c11b3439c72e5a2bb2))

## [1.53.1](https://github.com/dryvist/nix-darwin/compare/v1.53.0...v1.53.1) (2026-07-02)


### Bug Fixes

* shorten MANIFEST service rows to the MD013 line limit ([#1399](https://github.com/dryvist/nix-darwin/issues/1399)) ([4825060](https://github.com/dryvist/nix-darwin/commit/4825060161f032391e085e7af5e7479adabbc1da))

## [1.53.0](https://github.com/dryvist/nix-darwin/compare/v1.52.0...v1.53.0) (2026-07-02)


### Features

* mac-studio two-resident models (gpt-oss-120b + Qwen3-Coder-30B), Studio age recipient ([#1397](https://github.com/dryvist/nix-darwin/issues/1397)) ([c5fac39](https://github.com/dryvist/nix-darwin/commit/c5fac39e2c840c928d033d9b3b0d08515e1347c1))

## [1.52.0](https://github.com/dryvist/nix-darwin/compare/v1.51.2...v1.52.0) (2026-07-02)


### Features

* mac-studio llm-large serving gate, ephemeral GitHub runner, web UI wiring ([#1395](https://github.com/dryvist/nix-darwin/issues/1395)) ([7fae032](https://github.com/dryvist/nix-darwin/commit/7fae03228ab05495d15d8005c58236e795600877))

## [1.51.2](https://github.com/dryvist/nix-darwin/compare/v1.51.1...v1.51.2) (2026-07-02)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1390](https://github.com/dryvist/nix-darwin/issues/1390)) ([ff9e41e](https://github.com/dryvist/nix-darwin/commit/ff9e41e61944d72a0ce6a50be371ba15a1af6662))

## [1.51.1](https://github.com/dryvist/nix-darwin/compare/v1.51.0...v1.51.1) (2026-07-02)


### Bug Fixes

* point callers at renamed cc- reusable workflows ([e53c631](https://github.com/dryvist/nix-darwin/commit/e53c631402eee33bc70006b4d3009b28b3206961))

## [1.51.0](https://github.com/dryvist/nix-darwin/compare/v1.50.0...v1.51.0) (2026-07-02)


### Features

* **hosts:** add mac-studio (jevans-ms) headless inference host ([9e53db8](https://github.com/dryvist/nix-darwin/commit/9e53db888db2e656a56738fb2cedf68d35512ffd))

## [1.50.0](https://github.com/dryvist/nix-darwin/compare/v1.49.4...v1.50.0) (2026-07-01)


### Features

* **darwin:** exhaustive macOS LLM-inference tuning parameters (M4 Max / Tahoe) ([#1220](https://github.com/dryvist/nix-darwin/issues/1220)) ([6e9ed97](https://github.com/dryvist/nix-darwin/commit/6e9ed97842b53d085714c9ea8d29f0903500e908))

## [1.49.4](https://github.com/dryvist/nix-darwin/compare/v1.49.3...v1.49.4) (2026-06-29)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1346](https://github.com/dryvist/nix-darwin/issues/1346)) ([7866ac7](https://github.com/dryvist/nix-darwin/commit/7866ac7dca86bd4c4d7a62172d19e380d67c333d))

## [1.49.3](https://github.com/dryvist/nix-darwin/compare/v1.49.2...v1.49.3) (2026-06-26)


### Bug Fixes

* **homebrew:** stop managing OneDrive via masApps ([#1324](https://github.com/dryvist/nix-darwin/issues/1324)) ([a75ffed](https://github.com/dryvist/nix-darwin/commit/a75ffed1f08a3274550722239bf92cb0a7c68431))

## [1.49.2](https://github.com/dryvist/nix-darwin/compare/v1.49.1...v1.49.2) (2026-06-25)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1314](https://github.com/dryvist/nix-darwin/issues/1314)) ([2833047](https://github.com/dryvist/nix-darwin/commit/28330477f1f5ea9535c7df5cb032e86aac18108e))

## [1.49.1](https://github.com/dryvist/nix-darwin/compare/v1.49.0...v1.49.1) (2026-06-22)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1285](https://github.com/dryvist/nix-darwin/issues/1285)) ([ac30ea9](https://github.com/dryvist/nix-darwin/commit/ac30ea9df6c6399d41bc4f8358aeb093ddf8edd0))

## [1.49.0](https://github.com/dryvist/nix-darwin/compare/v1.48.1...v1.49.0) (2026-06-21)


### Features

* **claude:** re-inject homelab auto-mode context after nix-ai de-personalization ([#1280](https://github.com/dryvist/nix-darwin/issues/1280)) ([6e6c884](https://github.com/dryvist/nix-darwin/commit/6e6c8840588f29b2854e575f95575cd6a678c768))

## [1.48.1](https://github.com/dryvist/nix-darwin/compare/v1.48.0...v1.48.1) (2026-06-19)


### Bug Fixes

* **python:** consume PyYAML-enabled home env ([#1265](https://github.com/dryvist/nix-darwin/issues/1265)) ([d94dca7](https://github.com/dryvist/nix-darwin/commit/d94dca752c0e293918998af3f9972dbf88106d2e))

## [1.48.0](https://github.com/dryvist/nix-darwin/compare/v1.47.0...v1.48.0) (2026-06-18)


### Features

* seed global git excludes from dryvist/.github org-default gitignore ([#1256](https://github.com/dryvist/nix-darwin/issues/1256)) ([8b0d348](https://github.com/dryvist/nix-darwin/commit/8b0d3486b83e77bf3caa7c0b1a4faf207bc18bd3))

## [1.47.0](https://github.com/dryvist/nix-darwin/compare/v1.46.1...v1.47.0) (2026-06-13)


### Features

* **cribl-stream:** add local Cribl Stream node in Apple container ([#1244](https://github.com/dryvist/nix-darwin/issues/1244)) ([358db35](https://github.com/dryvist/nix-darwin/commit/358db35f69f064441ae2a2ba471a23f1f3c44403))

## [1.46.1](https://github.com/dryvist/nix-darwin/compare/v1.46.0...v1.46.1) (2026-06-12)


### Bug Fixes

* **ci:** repoint shared workflows to dryvist hub ([#1242](https://github.com/dryvist/nix-darwin/issues/1242)) ([572f0d0](https://github.com/dryvist/nix-darwin/commit/572f0d0081867bc5f310c4d258e27a58c9c99722))

## [1.46.0](https://github.com/dryvist/nix-darwin/compare/v1.45.0...v1.46.0) (2026-06-12)


### Features

* **cribl-edge:** standalone GitOps mode + inline LLM-stack sources ([#1235](https://github.com/dryvist/nix-darwin/issues/1235)) ([0a21177](https://github.com/dryvist/nix-darwin/commit/0a211776824c859a20f610b5e46240a8035988d4))

## [1.45.0](https://github.com/dryvist/nix-darwin/compare/v1.44.0...v1.45.0) (2026-06-12)


### Features

* **homebrew:** add Apple container runtime ([#1239](https://github.com/dryvist/nix-darwin/issues/1239)) ([6affebc](https://github.com/dryvist/nix-darwin/commit/6affebc356d62230639cd8d4342e529b786dd617))

## [1.44.0](https://github.com/dryvist/nix-darwin/compare/v1.43.1...v1.44.0) (2026-06-11)


### Features

* **tunables:** lower iogpu wired limit to 104000 for 24GB pageable headroom ([#1233](https://github.com/dryvist/nix-darwin/issues/1233)) ([50d36b5](https://github.com/dryvist/nix-darwin/commit/50d36b5f089e3e162e21fa0b567d4d1f2500d0f4))

## [1.43.1](https://github.com/dryvist/nix-darwin/compare/v1.43.0...v1.43.1) (2026-06-10)


### Bug Fixes

* **ai:** swap local LLM default to Qwen3-30B-A3B-Instruct-2507 + unbreak main build ([#1230](https://github.com/dryvist/nix-darwin/issues/1230)) ([5a8a28a](https://github.com/dryvist/nix-darwin/commit/5a8a28aeb6a39a50943a73b816b21565068e5905))

## [1.43.0](https://github.com/dryvist/nix-darwin/compare/v1.42.3...v1.43.0) (2026-06-08)


### Features

* **homebrew:** integrate with nix-ai trustedTaps option for aws/tap ([#1226](https://github.com/dryvist/nix-darwin/issues/1226)) ([66ddd9b](https://github.com/dryvist/nix-darwin/commit/66ddd9be3ced677efd5efa15a4fbe70cc022a04b))

## [1.42.3](https://github.com/dryvist/nix-darwin/compare/v1.42.2...v1.42.3) (2026-06-07)


### Bug Fixes

* **homebrew:** nixfmt-required whitespace in taps list append ([#1214](https://github.com/dryvist/nix-darwin/issues/1214)) ([ac93fa1](https://github.com/dryvist/nix-darwin/commit/ac93fa1a42d773b1d2d4d2ab4d07181afc1eb31c))

## [1.42.2](https://github.com/dryvist/nix-darwin/compare/v1.42.1...v1.42.2) (2026-06-04)


### Bug Fixes

* **ai-stack:** source defaultLocalModelId from committed config ([cd0f29f](https://github.com/dryvist/nix-darwin/commit/cd0f29fb22e169c1c1de65645072c5a065afc23a))

## [1.42.1](https://github.com/dryvist/nix-darwin/compare/v1.42.0...v1.42.1) (2026-06-04)


### Bug Fixes

* **homebrew:** drop powershell@preview cask, migrate to nix-devenv ([#1195](https://github.com/dryvist/nix-darwin/issues/1195)) ([c3249b1](https://github.com/dryvist/nix-darwin/commit/c3249b1800648ef63d25e134348d62ce85d879a0))

## [1.42.0](https://github.com/dryvist/nix-darwin/compare/v1.41.0...v1.42.0) (2026-06-04)


### Features

* **mlx:** file-first AI_MODEL_LOCAL_LLM read + disable HF autodiscover ([#1192](https://github.com/dryvist/nix-darwin/issues/1192)) ([d7dbe38](https://github.com/dryvist/nix-darwin/commit/d7dbe38ccedcda088ab30b7cc9799d04c52ea9f5))

## [1.41.0](https://github.com/dryvist/nix-darwin/compare/v1.40.2...v1.41.0) (2026-06-04)


### Features

* **mlx:** wire services.aiStack.defaultLocalModelId from automation keychain ([f30c357](https://github.com/dryvist/nix-darwin/commit/f30c357b978f7c309bce7d068a326d2127583a64))

## [1.40.2](https://github.com/dryvist/nix-darwin/compare/v1.40.1...v1.40.2) (2026-06-04)


### Bug Fixes

* **ci:** quote workflow_dispatch description to avoid YAML parse error ([#1188](https://github.com/dryvist/nix-darwin/issues/1188)) ([aec06a3](https://github.com/dryvist/nix-darwin/commit/aec06a32e8c94e4fa6246b9974501a4d72da450f))

## [1.40.1](https://github.com/dryvist/nix-darwin/compare/v1.40.0...v1.40.1) (2026-06-03)


### Bug Fixes

* **homebrew:** add powershell@preview cask ([#1184](https://github.com/dryvist/nix-darwin/issues/1184)) ([d88f8ff](https://github.com/dryvist/nix-darwin/commit/d88f8ff2212d109c0e69fdba64969262db571845))

## [1.40.0](https://github.com/dryvist/nix-darwin/compare/v1.39.0...v1.40.0) (2026-06-03)


### Features

* **ci:** receive update-flake-input dispatch from nix-ai ([#1174](https://github.com/dryvist/nix-darwin/issues/1174)) ([09ddd30](https://github.com/dryvist/nix-darwin/commit/09ddd30e10d03b90cf5e7b1b41a4024fe12fb447))


### Bug Fixes

* **ci:** repoint release-please caller to org-native reusable workflow ([#1171](https://github.com/dryvist/nix-darwin/issues/1171)) ([1ae9a40](https://github.com/dryvist/nix-darwin/commit/1ae9a40c4acab75a197ebe4a7311bb9519ce31d6))
* **homebrew:** drop Shortwave for Apple Mail; move bitwarden-desktop to cask ([#1181](https://github.com/dryvist/nix-darwin/issues/1181)) ([e770edb](https://github.com/dryvist/nix-darwin/commit/e770edb34ecf69a98b6b4a83160f376fcd5f9313))

## [1.39.0](https://github.com/dryvist/nix-darwin/compare/v1.38.1...v1.39.0) (2026-06-01)


### Features

* **claude:** adopt nix-claude-code module ([#1160](https://github.com/dryvist/nix-darwin/issues/1160)) ([83f987f](https://github.com/dryvist/nix-darwin/commit/83f987fe488e547289f8caeed99e2887f2d35b35))
* **tokens:** formalize DRYVIST/ORG_ADMIN tiers, dryvist default, post-rename signing fix ([#1153](https://github.com/dryvist/nix-darwin/issues/1153)) ([20357b8](https://github.com/dryvist/nix-darwin/commit/20357b84e94acd0398c86ad2a7f134b8d32bd411))


### Bug Fixes

* **ci:** retarget reusable-workflow uses: refs to current org homes ([#1154](https://github.com/dryvist/nix-darwin/issues/1154)) ([c9a66a5](https://github.com/dryvist/nix-darwin/commit/c9a66a5ec89888ed22d1c72ecfdeb4e7de3181a7))
* **homebrew:** declare claude-code@latest cask to match install ([#1167](https://github.com/dryvist/nix-darwin/issues/1167)) ([b40291d](https://github.com/dryvist/nix-darwin/commit/b40291d0b59c67c6ac3aa98e059124c865e07a09))
* **identity:** keep fullName "JacobPEvans" for cross-repo consistency ([#1157](https://github.com/dryvist/nix-darwin/issues/1157)) ([56b3689](https://github.com/dryvist/nix-darwin/commit/56b3689976bf797788363fb7b1bbc34a82c67847)), closes [#1155](https://github.com/dryvist/nix-darwin/issues/1155)
* **identity:** point git identity at renamed JacobPEvans-personal account ([#1155](https://github.com/dryvist/nix-darwin/issues/1155)) ([a2ac84b](https://github.com/dryvist/nix-darwin/commit/a2ac84bfdb7a491195b4875e3239ff8f8e38e4f4))

## [1.38.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.38.0...v1.38.1) (2026-05-25)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins [aw:gh-aw-pin-refresh] ([#1144](https://github.com/JacobPEvans/nix-darwin/issues/1144)) ([442d44e](https://github.com/JacobPEvans/nix-darwin/commit/442d44e89762b5b07f6a1160bab668c4b91019ba))

## [1.38.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.37.0...v1.38.0) (2026-05-24)


### Features

* **cribl:** bump mac pack v0.1.0 -&gt; v0.3.0 (native 4.18 sources) ([ef10105](https://github.com/JacobPEvans/nix-darwin/commit/ef10105f9368f266a59e45585fbcdc42d9de6b46))

## [1.37.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.36.4...v1.37.0) (2026-05-22)


### Features

* **cribl-edge:** bump to 4.18.0 and fix cloud enrollment (URL + port) ([#1123](https://github.com/JacobPEvans/nix-darwin/issues/1123)) ([d9100d9](https://github.com/JacobPEvans/nix-darwin/commit/d9100d9109f15361cd7416516b4323273babc23d))

## [1.36.4](https://github.com/JacobPEvans/nix-darwin/compare/v1.36.3...v1.36.4) (2026-05-21)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins ([#1126](https://github.com/JacobPEvans/nix-darwin/issues/1126)) ([f11500f](https://github.com/JacobPEvans/nix-darwin/commit/f11500f6f5785beb5931f0f65c0b82aaed713501))

## [1.36.3](https://github.com/JacobPEvans/nix-darwin/compare/v1.36.2...v1.36.3) (2026-05-19)


### Bug Fixes

* **homebrew:** pass -H to sudo so brew bootsnap finds the user cache ([#1120](https://github.com/JacobPEvans/nix-darwin/issues/1120)) ([8195386](https://github.com/JacobPEvans/nix-darwin/commit/819538662d4b75d7311d2e694654e63f8682a191))

## [1.36.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.36.1...v1.36.2) (2026-05-19)


### Bug Fixes

* **ci:** update jacobpevans-cc-plugins, not anthropics claude-code-plugins ([#1117](https://github.com/JacobPEvans/nix-darwin/issues/1117)) ([131c2de](https://github.com/JacobPEvans/nix-darwin/commit/131c2dea502bc0d776f824aed903e021afb525a6))

## [1.36.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.36.0...v1.36.1) (2026-05-18)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins ([#1110](https://github.com/JacobPEvans/nix-darwin/issues/1110)) ([5ed0801](https://github.com/JacobPEvans/nix-darwin/commit/5ed0801f5d7f508d7cdbae4389edc90a1378f151))

## [1.36.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.35.3...v1.36.0) (2026-05-15)


### Features

* **ci:** migrate Linux CI to self-hosted RunsOn runners ([#1104](https://github.com/JacobPEvans/nix-darwin/issues/1104)) ([7f9d8d7](https://github.com/JacobPEvans/nix-darwin/commit/7f9d8d7578807c266ad008183488e8acf08e8e13))

## [1.35.3](https://github.com/JacobPEvans/nix-darwin/compare/v1.35.2...v1.35.3) (2026-05-14)


### Bug Fixes

* **flake:** scope checks to x86_64-linux; restore --all-systems default ([#1101](https://github.com/JacobPEvans/nix-darwin/issues/1101)) ([1d90ff9](https://github.com/JacobPEvans/nix-darwin/commit/1d90ff9365c3c773f943866f3a0defdbd3d37649))

## [1.35.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.35.1...v1.35.2) (2026-05-14)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins ([#1099](https://github.com/JacobPEvans/nix-darwin/issues/1099)) ([8d9f0c9](https://github.com/JacobPEvans/nix-darwin/commit/8d9f0c9457e96b48abc7c135c2a4ad14f8928371))

## [1.35.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.35.0...v1.35.1) (2026-05-13)


### Bug Fixes

* **deps:** update jacobpevans-cc-plugins to 3.4.2 (git-guard -C fix) ([#1096](https://github.com/JacobPEvans/nix-darwin/issues/1096)) ([f055040](https://github.com/JacobPEvans/nix-darwin/commit/f05504009ccf8649cbf13c4e3aff6a790de4afff))

## [1.35.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.34.3...v1.35.0) (2026-05-12)


### Features

* **homebrew:** add firefox cask and add to dock ([#1091](https://github.com/JacobPEvans/nix-darwin/issues/1091)) ([84b328e](https://github.com/JacobPEvans/nix-darwin/commit/84b328e6b273b69311bd8402566a0116f631cc9a))

## [1.34.3](https://github.com/JacobPEvans/nix-darwin/compare/v1.34.2...v1.34.3) (2026-05-11)


### Bug Fixes

* **ci:** opt out of --all-systems for nix-validate ([#1093](https://github.com/JacobPEvans/nix-darwin/issues/1093)) ([8e14a8e](https://github.com/JacobPEvans/nix-darwin/commit/8e14a8e2bf6af1747637f8c051f1cdc0e943f004))

## [1.34.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.34.1...v1.34.2) (2026-05-11)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins ([#1088](https://github.com/JacobPEvans/nix-darwin/issues/1088)) ([eb14ada](https://github.com/JacobPEvans/nix-darwin/commit/eb14ada0778dfffca6f191aed9076da5b2cb7716))

## [1.34.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.34.0...v1.34.1) (2026-05-10)


### Bug Fixes

* **launchd:** disable orbstack-background agent and remove procps shadow ([#1083](https://github.com/JacobPEvans/nix-darwin/issues/1083)) ([2beca55](https://github.com/JacobPEvans/nix-darwin/commit/2beca55d8ebdf39e8d37a53c8f5740951c2d752e))

## [1.34.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.33.1...v1.34.0) (2026-05-10)


### Features

* **homebrew:** add openwebstart cask for iDRAC6 vKVM access ([#1080](https://github.com/JacobPEvans/nix-darwin/issues/1080)) ([e221582](https://github.com/JacobPEvans/nix-darwin/commit/e221582d026b8dcbcc725265320a6e2f89b79e93))

## [1.33.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.33.0...v1.33.1) (2026-05-07)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins ([#1077](https://github.com/JacobPEvans/nix-darwin/issues/1077)) ([84fea46](https://github.com/JacobPEvans/nix-darwin/commit/84fea46d45cb27ff01f2f6dd9540c0b4b957e985))

## [1.33.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.32.3...v1.33.0) (2026-05-05)


### Features

* **homebrew:** consume nix-ai lib.brewFormulae for per-agent formulae ([#1072](https://github.com/JacobPEvans/nix-darwin/issues/1072)) ([922f286](https://github.com/JacobPEvans/nix-darwin/commit/922f286c51194be6f57423ea8c56a69179d04dfa))

## [1.32.3](https://github.com/JacobPEvans/nix-darwin/compare/v1.32.2...v1.32.3) (2026-05-05)


### Bug Fixes

* **renovate:** correct cribl-edge customManager file path and schema ([#1071](https://github.com/JacobPEvans/nix-darwin/issues/1071)) ([54fa5e2](https://github.com/JacobPEvans/nix-darwin/commit/54fa5e2d1eacb10c15e8119b515a86d3c4fadde7))

## [1.32.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.32.1...v1.32.2) (2026-05-04)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins ([#1069](https://github.com/JacobPEvans/nix-darwin/issues/1069)) ([48c1a7e](https://github.com/JacobPEvans/nix-darwin/commit/48c1a7eaf43c74d66aef81506ce9fc4e5b66b3c4))

## [1.32.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.32.0...v1.32.1) (2026-05-03)


### Bug Fixes

* **ci:** remove deprecated app-id secret passthrough ([f5b1091](https://github.com/JacobPEvans/nix-darwin/commit/f5b1091a2ca5150c99339b0535b2eb96d44a109b))
* **claude:** remove dead auto-claude references ([e450461](https://github.com/JacobPEvans/nix-darwin/commit/e450461126f2b0cb1ef953a1a82301da05a8fe72))

## [1.32.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.31.1...v1.32.0) (2026-05-03)


### Features

* **macbook-m4:** enable programs.mlx ([#1061](https://github.com/JacobPEvans/nix-darwin/issues/1061)) ([0ae10a6](https://github.com/JacobPEvans/nix-darwin/commit/0ae10a6d53ff5a5d1255f7e5d84c47cf20bb3a8a))

## [1.31.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.31.0...v1.31.1) (2026-05-03)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins ([#1060](https://github.com/JacobPEvans/nix-darwin/issues/1060)) ([88d1425](https://github.com/JacobPEvans/nix-darwin/commit/88d1425864f2e4f8d3f86d559e41aae30e4333fe))

## [1.31.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.30.10...v1.31.0) (2026-04-29)


### Features

* **darwin:** :sparkles: apple-silicon-tunables for AI inference workloads ([#1056](https://github.com/JacobPEvans/nix-darwin/issues/1056)) ([078a101](https://github.com/JacobPEvans/nix-darwin/commit/078a1018e4b61117a8d8b5eb132d6173099f966f))

## [1.30.10](https://github.com/JacobPEvans/nix-darwin/compare/v1.30.9...v1.30.10) (2026-04-29)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins ([#1054](https://github.com/JacobPEvans/nix-darwin/issues/1054)) ([a9b9491](https://github.com/JacobPEvans/nix-darwin/commit/a9b94919599e7dbead7bb64b928a594c762fa1ce))

## [1.30.9](https://github.com/JacobPEvans/nix-darwin/compare/v1.30.8...v1.30.9) (2026-04-26)


### Bug Fixes

* **ci:** fix silent deps-update failures (runner OS bug) ([#1047](https://github.com/JacobPEvans/nix-darwin/issues/1047)) ([95914c7](https://github.com/JacobPEvans/nix-darwin/commit/95914c7fc35d21edc86521dbbe3e1264783688ed))

## [1.30.8](https://github.com/JacobPEvans/nix-darwin/compare/v1.30.7...v1.30.8) (2026-04-24)


### Bug Fixes

* **deps:** refresh gh-aw action SHA pins ([#1043](https://github.com/JacobPEvans/nix-darwin/issues/1043)) ([2195a37](https://github.com/JacobPEvans/nix-darwin/commit/2195a377ddeda0d58e5958bebc297bc24ec631c6))

## [1.30.7](https://github.com/JacobPEvans/nix-darwin/compare/v1.30.6...v1.30.7) (2026-04-22)


### Bug Fixes

* **ci:** guard against nixpkgs binary cache misses ([#1034](https://github.com/JacobPEvans/nix-darwin/issues/1034)) ([9893498](https://github.com/JacobPEvans/nix-darwin/commit/989349809972ebf41a581cbe534066f7cc55935e))

## [1.30.6](https://github.com/JacobPEvans/nix-darwin/compare/v1.30.5...v1.30.6) (2026-04-22)


### Bug Fixes

* **deps:** update ClaudeBar to 0.4.59 ([#1038](https://github.com/JacobPEvans/nix-darwin/issues/1038)) ([a67eb75](https://github.com/JacobPEvans/nix-darwin/commit/a67eb75e5f57826dbab70e12b83713b9d3b90c93))

## [1.30.5](https://github.com/JacobPEvans/nix-darwin/compare/v1.30.4...v1.30.5) (2026-04-21)


### Bug Fixes

* **ci:** add gh-aw-pin-refresh workflow and recompile lock files ([b639ee3](https://github.com/JacobPEvans/nix-darwin/commit/b639ee3c6a6125d3cd5c72642cd2d72b9a9644ab))

## [1.30.4](https://github.com/JacobPEvans/nix-darwin/compare/v1.30.3...v1.30.4) (2026-04-19)


### Bug Fixes

* **cribl-edge:** replace Doppler CLI with sops-nix for root-safe secrets ([75519fb](https://github.com/JacobPEvans/nix-darwin/commit/75519fb3321b7a0a40efdb675095b89e51722b13))

## [1.30.3](https://github.com/JacobPEvans/nix-darwin/compare/v1.30.2...v1.30.3) (2026-04-19)


### Bug Fixes

* **cribl-edge:** replace cc-edge-macos-power with cc-edge-the-mac-pack-io ([#1028](https://github.com/JacobPEvans/nix-darwin/issues/1028)) ([69b6102](https://github.com/JacobPEvans/nix-darwin/commit/69b610203f08e47e9d63be3440a466d34dc69080))

## [1.30.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.30.1...v1.30.2) (2026-04-19)


### Bug Fixes

* **cribl-edge:** run secret-fetch commands as primaryUser ([8db1f73](https://github.com/JacobPEvans/nix-darwin/commit/8db1f73b66161d040aedea1e2f2a0becb3a4060d))

## [1.30.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.30.0...v1.30.1) (2026-04-19)


### Bug Fixes

* **cribl-edge:** use primaryUser for doppler access in activation ([#1023](https://github.com/JacobPEvans/nix-darwin/issues/1023)) ([5d09a5c](https://github.com/JacobPEvans/nix-darwin/commit/5d09a5cac3dced5399e37809d8147300b4bf8cf7))

## [1.30.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.29.2...v1.30.0) (2026-04-19)


### Features

* **cribl-edge:** declarative management with Renovate tracking ([#1019](https://github.com/JacobPEvans/nix-darwin/issues/1019)) ([41b2328](https://github.com/JacobPEvans/nix-darwin/commit/41b2328cb0c81c95a27983b01f174fcdbfb4e4fa))

## [1.29.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.29.1...v1.29.2) (2026-04-18)


### Bug Fixes

* **home-manager:** replace backupFileExtension with backupCommand rm -rf ([#1018](https://github.com/JacobPEvans/nix-darwin/issues/1018)) ([23d5d64](https://github.com/JacobPEvans/nix-darwin/commit/23d5d64eb0f0eed807a6b578961cd99e20f7f6d9))

## [1.29.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.29.0...v1.29.1) (2026-04-17)


### Bug Fixes

* **dock:** remove dock spacers ([#1016](https://github.com/JacobPEvans/nix-darwin/issues/1016)) ([3b82879](https://github.com/JacobPEvans/nix-darwin/commit/3b82879623168d556341704f155fa61af7bc616a))

## [1.29.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.28.1...v1.29.0) (2026-04-17)


### Features

* **dock:** add Discord, reorder with spacers, add private local config ([b318721](https://github.com/JacobPEvans/nix-darwin/commit/b3187219add173c501ea1ff8b0ea2d2ed08a3fa9))

## [1.28.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.27.3...v1.28.0) (2026-04-15)


### Features

* **zsh:** throttle brew update/doctor daily, add outdated check ([#1007](https://github.com/JacobPEvans/nix-darwin/issues/1007)) ([f779505](https://github.com/JacobPEvans/nix-darwin/commit/f779505b8f05e3dd8601644c5965ef6a0ed78d64))

## [1.27.3](https://github.com/JacobPEvans/nix-darwin/compare/v1.27.2...v1.27.3) (2026-04-14)


### Bug Fixes

* add automation bots to AI Moderator skip-bots ([#1000](https://github.com/JacobPEvans/nix-darwin/issues/1000)) ([4ba9671](https://github.com/JacobPEvans/nix-darwin/commit/4ba9671cd6c8dab9a127f008aafe00efd83501b2))

## [1.27.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.27.1...v1.27.2) (2026-04-13)


### Bug Fixes

* recompile gh-aw workflows with v0.68.1 ([60574fd](https://github.com/JacobPEvans/nix-darwin/commit/60574fdea25ecd0d91ca42a8ab55c59b5085e74f))

## [1.27.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.27.0...v1.27.1) (2026-04-12)


### Bug Fixes

* **deps:** add nix-home to Renovate GROUP 1 + parameterize deps-update-flake ([cb9c1e1](https://github.com/JacobPEvans/nix-darwin/commit/cb9c1e17f7b707a8c0ff1cb90bf6c35549eae1f6))

## [1.26.3](https://github.com/JacobPEvans/nix-darwin/compare/v1.26.2...v1.26.3) (2026-04-12)


### Bug Fixes

* **ci:** add hosts/** to nix path filter in ci-gate ([#990](https://github.com/JacobPEvans/nix-darwin/issues/990)) ([3e11f51](https://github.com/JacobPEvans/nix-darwin/commit/3e11f51548e40abfa29f915e05f27399d082f52f))

## [1.26.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.26.1...v1.26.2) (2026-04-12)


### Bug Fixes

* **zsh:** rename 'status' local to 'rc' to avoid zsh read-only special ([#985](https://github.com/JacobPEvans/nix-darwin/issues/985)) ([2f99db3](https://github.com/JacobPEvans/nix-darwin/commit/2f99db33278c3d2c021f1d35598d972d636575ae))

## [1.26.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.26.0...v1.26.1) (2026-04-11)


### Bug Fixes

* **agents:** drop "quartet" and "all four repos" language ([#983](https://github.com/JacobPEvans/nix-darwin/issues/983)) ([6daaf5f](https://github.com/JacobPEvans/nix-darwin/commit/6daaf5f48f7235d8b4138b9ccfb4231b0c8b5f80))

## [1.26.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.25.0...v1.26.0) (2026-04-11)


### Features

* add AI merge gate ([#966](https://github.com/JacobPEvans/nix-darwin/issues/966)) ([f8d19ed](https://github.com/JacobPEvans/nix-darwin/commit/f8d19edee02ce42f3f1f82d5c377807f033a7742))
* add ansible Python package set with paramiko and jsondiff ([#531](https://github.com/JacobPEvans/nix-darwin/issues/531)) ([454d393](https://github.com/JacobPEvans/nix-darwin/commit/454d393e23f3eeaa96cd556b0d434324d2b7a65a))
* add APFS volume quota support and AI model volumes ([#832](https://github.com/JacobPEvans/nix-darwin/issues/832)) ([4d0aea3](https://github.com/JacobPEvans/nix-darwin/commit/4d0aea3b6cd6bddc15fc52ae1d9095a3c198f36f))
* add CI auto-fix workflow and enable Claude review ([#624](https://github.com/JacobPEvans/nix-darwin/issues/624)) ([e7645f2](https://github.com/JacobPEvans/nix-darwin/commit/e7645f25d3b35cca9b876f23fc239875d7415ba3))
* add Cribl Edge nix-darwin module ([#871](https://github.com/JacobPEvans/nix-darwin/issues/871)) ([3d1758b](https://github.com/JacobPEvans/nix-darwin/commit/3d1758b4f0dc683032dcde0559f4fa9c4f796726))
* add Cribl MCP server via Nix-managed SSE transport ([#728](https://github.com/JacobPEvans/nix-darwin/issues/728)) ([89c9544](https://github.com/JacobPEvans/nix-darwin/commit/89c9544d4e1c2788f69ac9b4270bd5510cb0415e))
* add cryptography to system Python environment ([#563](https://github.com/JacobPEvans/nix-darwin/issues/563)) ([2beeeb1](https://github.com/JacobPEvans/nix-darwin/commit/2beeeb1d4ea1c71fad42795eb11ee33bd4e1d610))
* add daily repo health audit agentic workflow ([#822](https://github.com/JacobPEvans/nix-darwin/issues/822)) ([974b393](https://github.com/JacobPEvans/nix-darwin/commit/974b393379a2409cd1c431d55154904a5d25fbb2))
* add Docker daemon log rotation and builder GC config ([#803](https://github.com/JacobPEvans/nix-darwin/issues/803)) ([26e5ca0](https://github.com/JacobPEvans/nix-darwin/commit/26e5ca07dc53c1b3b1c2005010fe0cc5892e0e0f))
* add doppler-mcp wrapper for MCP server secret injection ([#732](https://github.com/JacobPEvans/nix-darwin/issues/732)) ([42de771](https://github.com/JacobPEvans/nix-darwin/commit/42de771a190036e76dacf5c769ba3811670219fc))
* add event-based cleanup for orphaned MCP server processes ([#652](https://github.com/JacobPEvans/nix-darwin/issues/652)) ([f6157f8](https://github.com/JacobPEvans/nix-darwin/commit/f6157f8670b6db46787070df2e39e99885706621))
* add ffmpeg media encoding tool ([#534](https://github.com/JacobPEvans/nix-darwin/issues/534)) ([309ff05](https://github.com/JacobPEvans/nix-darwin/commit/309ff05228781c8968defd6b4ed662837f5d3ce0))
* add final PR review workflow ([#626](https://github.com/JacobPEvans/nix-darwin/issues/626)) ([d6d5db8](https://github.com/JacobPEvans/nix-darwin/commit/d6d5db81750ebef2396cd5042c1682e86a52de21))
* add gh-aw agentic workflows ([#766](https://github.com/JacobPEvans/nix-darwin/issues/766)) ([8489738](https://github.com/JacobPEvans/nix-darwin/commit/8489738fb4333401fe79a0c41edfd4fc4e8e4072))
* add gh-aw CLI extension via Home Manager ([#597](https://github.com/JacobPEvans/nix-darwin/issues/597)) ([6e94831](https://github.com/JacobPEvans/nix-darwin/commit/6e94831d57dd9afedfe2f23e3929419f897e9cf2))
* add git-bug as universally available system tool ([#678](https://github.com/JacobPEvans/nix-darwin/issues/678)) ([9258edf](https://github.com/JacobPEvans/nix-darwin/commit/9258edfb602b81216759c4f6c4f2ea90d1e7fd68))
* add granola-watcher LaunchAgent for auto-migration ([#629](https://github.com/JacobPEvans/nix-darwin/issues/629)) ([58f9b2f](https://github.com/JacobPEvans/nix-darwin/commit/58f9b2f367f9c43f24d36db9418e5a140289339e))
* add HF_TOKEN to macOS Keychain exports for HuggingFace MCP ([#827](https://github.com/JacobPEvans/nix-darwin/issues/827)) ([9fa5d56](https://github.com/JacobPEvans/nix-darwin/commit/9fa5d56b782f7f802da2a6d8ee69349dc91a4fe5))
* add kubernetes dev shell with validation tooling ([#640](https://github.com/JacobPEvans/nix-darwin/issues/640)) ([c69caff](https://github.com/JacobPEvans/nix-darwin/commit/c69caff29654e896cf11c271842054f5ee9b64c7))
* add libreoffice homebrew cask for document-skills ([#974](https://github.com/JacobPEvans/nix-darwin/issues/974)) ([8fb828f](https://github.com/JacobPEvans/nix-darwin/commit/8fb828ff4a5cfbb0d1ac075a39dfc52392c7164d))
* add LM Studio and update nix-ai/nix-home inputs ([4e6c828](https://github.com/JacobPEvans/nix-darwin/commit/4e6c82866afd6124486c70333a4f0c1c4fcde2be))
* add maestro auto run integration for automated issue resolution ([#513](https://github.com/JacobPEvans/nix-darwin/issues/513)) ([af24e42](https://github.com/JacobPEvans/nix-darwin/commit/af24e427b00c31729010bcb18d4a1cee64523717))
* add MCP server packages and fix CLI registration docs ([108d8ca](https://github.com/JacobPEvans/nix-darwin/commit/108d8ca52a572b54900bbfe2d3adec8bbff15918))
* add Microsoft Teams cask and migrate OrbStack to Homebrew for TCC stability ([#653](https://github.com/JacobPEvans/nix-darwin/issues/653)) ([be2be35](https://github.com/JacobPEvans/nix-darwin/commit/be2be35dee540305d93456fe48db553ca712450a))
* add nixpkgs-unstable overlay for GUI apps ([#524](https://github.com/JacobPEvans/nix-darwin/issues/524)) ([f9424a6](https://github.com/JacobPEvans/nix-darwin/commit/f9424a61882ecd695b465a96cc91103183ad3e0b))
* add Obsidian skills plugins ([#574](https://github.com/JacobPEvans/nix-darwin/issues/574)) ([66e1de9](https://github.com/JacobPEvans/nix-darwin/commit/66e1de9945e3c3aa499f74d45c57213c97426443))
* add official Claude plugins and pyright tool ([#501](https://github.com/JacobPEvans/nix-darwin/issues/501)) ([9629bd0](https://github.com/JacobPEvans/nix-darwin/commit/9629bd0ea46d45d59dceeab6c50f44adccaf9666))
* add plugin auto-update support and stable update channel ([#566](https://github.com/JacobPEvans/nix-darwin/issues/566)) ([55572c9](https://github.com/JacobPEvans/nix-darwin/commit/55572c9c79942e23b2c2d7289dee18f685e25cb5))
* add Python multi-version support (3.10, 3.12) with uv-based 3.9 ([#506](https://github.com/JacobPEvans/nix-darwin/issues/506)) ([a4dc4cb](https://github.com/JacobPEvans/nix-darwin/commit/a4dc4cba4213355e6e9410b9d9542977808dd3d6))
* add SOPS_AGE_KEY_FILE and EDITOR=vim to session variables ([#635](https://github.com/JacobPEvans/nix-darwin/issues/635)) ([59e5a56](https://github.com/JacobPEvans/nix-darwin/commit/59e5a565406378de1a1c6eba368676ba3afe3365))
* add SOPS-encrypted pre-commit hook for keyword scanning ([#725](https://github.com/JacobPEvans/nix-darwin/issues/725)) ([396fee2](https://github.com/JacobPEvans/nix-darwin/commit/396fee2bbc49209c8952b2fbe4bc5b317e105bb1))
* add Splunk MCP server to Claude Code mcpServers ([#829](https://github.com/JacobPEvans/nix-darwin/issues/829)) ([f212edd](https://github.com/JacobPEvans/nix-darwin/commit/f212edd3660b7dde9f5bb0e134df6857481996b0))
* add upstream-repo-updated dispatch for cross-repo triggers ([#560](https://github.com/JacobPEvans/nix-darwin/issues/560)) ([914eed2](https://github.com/JacobPEvans/nix-darwin/commit/914eed2a2c90eb73c4791e2b761f5b8c0dfec783))
* add watchexec package and create MANIFEST.md inventory ([#628](https://github.com/JacobPEvans/nix-darwin/issues/628)) ([45215bb](https://github.com/JacobPEvans/nix-darwin/commit/45215bb9e860c8f103273a9d5c111b97922f0ee3))
* add wispr-flow voice dictation app ([#493](https://github.com/JacobPEvans/nix-darwin/issues/493)) ([0404e9a](https://github.com/JacobPEvans/nix-darwin/commit/0404e9a62a620cf29155d87ecb398b60e53b2c0a))
* **ai:** install codex cli and official gemini vscode extension ([#570](https://github.com/JacobPEvans/nix-darwin/issues/570)) ([3cbf944](https://github.com/JacobPEvans/nix-darwin/commit/3cbf944c89ea337bf06fa146c096e3195247638a))
* **aliases:** add d-claude for Doppler secrets injection ([da3c2ca](https://github.com/JacobPEvans/nix-darwin/commit/da3c2cafc499e2febe37c03a4f2703df17eaaf6d))
* auto-discover JacobPEvans plugins from flake input ([#557](https://github.com/JacobPEvans/nix-darwin/issues/557)) ([091b681](https://github.com/JacobPEvans/nix-darwin/commit/091b6812ef63a3a306ec2c87547e019e74dd9bc3))
* auto-enable squash merge on all PRs when opened ([#742](https://github.com/JacobPEvans/nix-darwin/issues/742)) ([f9d55a7](https://github.com/JacobPEvans/nix-darwin/commit/f9d55a7633729ef4d6e6402d95d6686ad7b1a345))
* **aws:** add terraform-bedrock and iam-user profiles ([#488](https://github.com/JacobPEvans/nix-darwin/issues/488)) ([e3be0ac](https://github.com/JacobPEvans/nix-darwin/commit/e3be0acfc89c2a192cfb0268e7b2000b1c388e2d))
* **ci:** add nix-ai to AI_INPUTS allowlist in deps-update-flake ([#750](https://github.com/JacobPEvans/nix-darwin/issues/750)) ([04f012e](https://github.com/JacobPEvans/nix-darwin/commit/04f012ebd5aa3677864616d19ad906b9087304f3))
* **ci:** unified issue dispatch pattern with AI-created issue support ([#710](https://github.com/JacobPEvans/nix-darwin/issues/710)) ([e603c25](https://github.com/JacobPEvans/nix-darwin/commit/e603c251d262912f1d726b59687326dfab9506ba))
* **claude:** add remoteControlAtStartup option, extract activation scripts to shell files ([#713](https://github.com/JacobPEvans/nix-darwin/issues/713)) ([a3cca1a](https://github.com/JacobPEvans/nix-darwin/commit/a3cca1a172d4647bff268448635af7ed5f2a2108))
* **claude:** disable redundant MCP servers and playwright plugin globally ([#748](https://github.com/JacobPEvans/nix-darwin/issues/748)) ([dfeb7c3](https://github.com/JacobPEvans/nix-darwin/commit/dfeb7c30e9ca62e77f6a6515065c15707803cb67))
* **claude:** enable agent teams and use default model ([#551](https://github.com/JacobPEvans/nix-darwin/issues/551)) ([1468168](https://github.com/JacobPEvans/nix-darwin/commit/14681686f8505a4729d4ed38b8543fcd28515e7a))
* **claude:** pin statusline to semver ^1, set effort medium, add 1M context disable ([#700](https://github.com/JacobPEvans/nix-darwin/issues/700)) ([0e3801c](https://github.com/JacobPEvans/nix-darwin/commit/0e3801cd4d65f78ebad31b498c1600c44a5b2c01))
* **claude:** set default startup model to opusplan ([#599](https://github.com/JacobPEvans/nix-darwin/issues/599)) ([56f9c1b](https://github.com/JacobPEvans/nix-darwin/commit/56f9c1bfe8b165339ab7debf7ff23ec9f0863021))
* configure plugin marketplaces via Nix ([#478](https://github.com/JacobPEvans/nix-darwin/issues/478)) ([107e538](https://github.com/JacobPEvans/nix-darwin/commit/107e5381c6cd1dce09b3527a35baa402f82fd65e))
* **copilot:** add Copilot coding agent support + CI fail issue workflow ([#740](https://github.com/JacobPEvans/nix-darwin/issues/740)) ([07de9b2](https://github.com/JacobPEvans/nix-darwin/commit/07de9b21400618fa1d2705e72f3ec98a2c447a59))
* create infrastructure-automation shell combining packer and terraform ([#459](https://github.com/JacobPEvans/nix-darwin/issues/459)) ([9f522f6](https://github.com/JacobPEvans/nix-darwin/commit/9f522f6ac4e12127176a3a4ff18b3c2065ed96fa))
* **cribl-edge:** declarative pack deployment ([#928](https://github.com/JacobPEvans/nix-darwin/issues/928)) ([6fb6ccc](https://github.com/JacobPEvans/nix-darwin/commit/6fb6cccf92ff7e205025ed36eeb1189be9a347d2))
* **darwin:** add local whisper/voice/AI tooling ([#702](https://github.com/JacobPEvans/nix-darwin/issues/702)) ([30f1ebb](https://github.com/JacobPEvans/nix-darwin/commit/30f1ebbf6e463ba33735d8beb15670eedd35c737))
* **darwin:** add streamline-login module for updater disabling ([#931](https://github.com/JacobPEvans/nix-darwin/issues/931)) ([89b2a30](https://github.com/JacobPEvans/nix-darwin/commit/89b2a301d701ed3f81543ab6126f0743a44ca30b))
* **darwin:** add syslog forwarding to remote server ([#514](https://github.com/JacobPEvans/nix-darwin/issues/514)) ([3d46baa](https://github.com/JacobPEvans/nix-darwin/commit/3d46baa0e115437c67a6e887738fc7ad203c7b95))
* disable auto-updaters for Nix-managed macOS apps ([#605](https://github.com/JacobPEvans/nix-darwin/issues/605)) ([26afe5e](https://github.com/JacobPEvans/nix-darwin/commit/26afe5e08861324512a703439e21a43921910f41))
* disable automatic triggers on Claude-executing workflows ([cbe315e](https://github.com/JacobPEvans/nix-darwin/commit/cbe315ebe544ba3e234cfdf04083cf1ac751a8a4))
* **dock:** add iPhone Mirroring and Microsoft Teams ([#787](https://github.com/JacobPEvans/nix-darwin/issues/787)) ([9c88430](https://github.com/JacobPEvans/nix-darwin/commit/9c8843051214575dfeb50e8f9accc5148a5c6b97))
* **dock:** add Microsoft Outlook to persistent Dock bar ([#693](https://github.com/JacobPEvans/nix-darwin/issues/693)) ([006dd94](https://github.com/JacobPEvans/nix-darwin/commit/006dd9417099dd135c1937453760873b604f01cd))
* enable full Claude Code OTEL telemetry ([#637](https://github.com/JacobPEvans/nix-darwin/issues/637)) ([4879940](https://github.com/JacobPEvans/nix-darwin/commit/48799405c3d8b7ef24974efd868637ed9c55f28c))
* enable PAL MCP with proper timeouts ([b314467](https://github.com/JacobPEvans/nix-darwin/commit/b314467abf19f2f87001bc6a15d1ab713fc31073))
* extract claudebar package and add nix-update to flake workflow ([#811](https://github.com/JacobPEvans/nix-darwin/issues/811)) ([0992eb4](https://github.com/JacobPEvans/nix-darwin/commit/0992eb4d6085830701829cb3b5c92dabcaca1ba4))
* **flake-rebuild:** add issue investigation and plan generation prompt ([#895](https://github.com/JacobPEvans/nix-darwin/issues/895)) ([cac974f](https://github.com/JacobPEvans/nix-darwin/commit/cac974f55c2ad3070d2bf1d8d34e9bd5081575c3))
* **flake:** decouple nix-ai non-flake inputs via follows ([#857](https://github.com/JacobPEvans/nix-darwin/issues/857)) ([8fb3fdc](https://github.com/JacobPEvans/nix-darwin/commit/8fb3fdc90ccb8bad95eb68f7c8b28e40cce07df2))
* **gc:** add weekly LaunchDaemon to prune old profile generations ([#830](https://github.com/JacobPEvans/nix-darwin/issues/830)) ([d3cac5b](https://github.com/JacobPEvans/nix-darwin/commit/d3cac5b3e8c2e08fa5429a730e146503b48ce291))
* **homebrew:** add Microsoft 365 apps via Mac App Store ([#548](https://github.com/JacobPEvans/nix-darwin/issues/548)) ([de24eb6](https://github.com/JacobPEvans/nix-darwin/commit/de24eb60db1e20544449bbb3c50156382d76c5f2))
* **homebrew:** enable brew autoupdate with greedy upgrades every 30h ([#904](https://github.com/JacobPEvans/nix-darwin/issues/904)) ([ba3562d](https://github.com/JacobPEvans/nix-darwin/commit/ba3562d868a46811ad40a87464c76e00a2aaabb8))
* implement Claude Code hooks with notifications ([#520](https://github.com/JacobPEvans/nix-darwin/issues/520)) ([3f621d5](https://github.com/JacobPEvans/nix-darwin/commit/3f621d5aa051aefa805434f779d71ca16e2f2780))
* include claude-code in daily AI dependency updates ([#511](https://github.com/JacobPEvans/nix-darwin/issues/511)) ([1a8ebe0](https://github.com/JacobPEvans/nix-darwin/commit/1a8ebe0ab730b300bcc7632509186aae0b17dd42))
* install git-flow-next v1.0.0 via custom buildGoModule ([#642](https://github.com/JacobPEvans/nix-darwin/issues/642)) ([5650029](https://github.com/JacobPEvans/nix-darwin/commit/565002903da422f9c108d1353d70d385048376c0))
* **mcp:** Add Nix-native MCP servers with Docker and Context7 ([#494](https://github.com/JacobPEvans/nix-darwin/issues/494)) ([d11ff97](https://github.com/JacobPEvans/nix-darwin/commit/d11ff975f505c7b629792a5f24a640a84c3fac47))
* **mcp:** integrate PAL MCP and remove dead code ([#497](https://github.com/JacobPEvans/nix-darwin/issues/497)) ([90e4509](https://github.com/JacobPEvans/nix-darwin/commit/90e45090918db9ab98aad9362a8910c4e97bf82b))
* migrate flake.lock updates to Renovate nix manager ([#835](https://github.com/JacobPEvans/nix-darwin/issues/835)) ([92bbb71](https://github.com/JacobPEvans/nix-darwin/commit/92bbb71e8b960bab4acd0c6f5bda5d20604c7192))
* migrate granola-watcher to vault, remove from public repo ([#724](https://github.com/JacobPEvans/nix-darwin/issues/724)) ([70dad9c](https://github.com/JacobPEvans/nix-darwin/commit/70dad9c8b91ba6b516c80bb862d0da512598d8cf))
* **monitoring:** add NVMe disk I/O tracking to ws-monitor ([#944](https://github.com/JacobPEvans/nix-darwin/issues/944)) ([1cfe820](https://github.com/JacobPEvans/nix-darwin/commit/1cfe8205329d6b8ca72fe502cfe96d7ba05120c8))
* **monitoring:** add WindowServer performance monitor LaunchDaemon ([dbedd55](https://github.com/JacobPEvans/nix-darwin/commit/dbedd550da186f8ee3711d3c42647ea23dcb8922))
* move gemini-cli and antigravity to homebrew for Gemini 3.1 Pro support ([#685](https://github.com/JacobPEvans/nix-darwin/issues/685)) ([33a2486](https://github.com/JacobPEvans/nix-darwin/commit/33a2486baf9d634c55759e17a96740dac059f8cb))
* move module-eval check into lib/checks.nix ([#761](https://github.com/JacobPEvans/nix-darwin/issues/761)) ([3f80d47](https://github.com/JacobPEvans/nix-darwin/commit/3f80d476883387e8633a760643c9bff636885c37))
* **nix:** add trusted-users and devenv cachix binary cache ([#837](https://github.com/JacobPEvans/nix-darwin/issues/837)) ([cf31065](https://github.com/JacobPEvans/nix-darwin/commit/cf310650e36d3d773150fad0034b68bd4411e3a4))
* **nix:** migrate to official determinateNix module with automatic GC ([#792](https://github.com/JacobPEvans/nix-darwin/issues/792)) ([cdc21c6](https://github.com/JacobPEvans/nix-darwin/commit/cdc21c6ca047fc5cbe8fd4e101b286db5051e790))
* **ollama:** upgrade to unstable channel and clean up plans ([#573](https://github.com/JacobPEvans/nix-darwin/issues/573)) ([90a6709](https://github.com/JacobPEvans/nix-darwin/commit/90a67094e03edbc84d64b2d7844115455ed0a6fc))
* optimize CI workflow performance ([#519](https://github.com/JacobPEvans/nix-darwin/issues/519)) ([845e16b](https://github.com/JacobPEvans/nix-darwin/commit/845e16bc69dd9b33efb0cb0079bafa5a58b94f84))
* package placement audit — move whisper tools to nix-ai, group AI brews ([#981](https://github.com/JacobPEvans/nix-darwin/issues/981)) ([195000b](https://github.com/JacobPEvans/nix-darwin/commit/195000bb93683ddd2eb8e62e0e2f8efdd85665a4))
* **plugins:** add community plugins and multi-model integrations ([#503](https://github.com/JacobPEvans/nix-darwin/issues/503)) ([48d283f](https://github.com/JacobPEvans/nix-darwin/commit/48d283fe481e7b77c8ef006faf0ad40c9d248db9))
* release polish — MIT license, README rewrite, and doc cleanup ([#751](https://github.com/JacobPEvans/nix-darwin/issues/751)) ([2c9f33a](https://github.com/JacobPEvans/nix-darwin/commit/2c9f33af8b07ac17fcd026aa6b5d412bf2b5f6ef))
* remove nodejs and python310 from global packages ([#765](https://github.com/JacobPEvans/nix-darwin/issues/765)) ([024eab9](https://github.com/JacobPEvans/nix-darwin/commit/024eab9d743c68dbb832f6e8654f79d44c43c356))
* replace issue-triage with full issue pipeline ([#658](https://github.com/JacobPEvans/nix-darwin/issues/658)) ([c6d19f3](https://github.com/JacobPEvans/nix-darwin/commit/c6d19f3b338861d11e6e69149577ba33f9e55516))
* **settings:** add effortLevel option with medium default ([ce0d574](https://github.com/JacobPEvans/nix-darwin/commit/ce0d574d15a0681099032298f18ee6d08a6af319))
* **shells:** add PowerShell development shell ([#575](https://github.com/JacobPEvans/nix-darwin/issues/575)) ([ceede10](https://github.com/JacobPEvans/nix-darwin/commit/ceede1048bec4a6992db86784f10d762c546b1f3))
* **shells:** add sops/age, split ansible shell, fix direnv performance ([#595](https://github.com/JacobPEvans/nix-darwin/issues/595)) ([d9fc1d4](https://github.com/JacobPEvans/nix-darwin/commit/d9fc1d4d1524bee361a8db2ed2ac3ece845a32f4))
* switch to ai-workflows reusable workflows ([#634](https://github.com/JacobPEvans/nix-darwin/issues/634)) ([fa98038](https://github.com/JacobPEvans/nix-darwin/commit/fa980384fb69677c5ff5ebbdb13eb8310b67091b))
* tiered GitHub token context switching ([#971](https://github.com/JacobPEvans/nix-darwin/issues/971)) ([cf83afc](https://github.com/JacobPEvans/nix-darwin/commit/cf83afc16c037416c8ecca1fda9c3380021ab9ad))
* **tmux:** add programs.tmux config with session persistence and mosh ([#618](https://github.com/JacobPEvans/nix-darwin/issues/618)) ([0e44a2e](https://github.com/JacobPEvans/nix-darwin/commit/0e44a2eaed4ab913b3d83de6d10f75b2f0bfbe0d))
* update ollama to latest nixpkgs, add claude-flow ([#543](https://github.com/JacobPEvans/nix-darwin/issues/543)) ([aada2a0](https://github.com/JacobPEvans/nix-darwin/commit/aada2a0594806a2a234c985e2c5cfd36d2517acd))
* update to claude-code-plugins v2.0.0 (8 consolidated plugins) ([#579](https://github.com/JacobPEvans/nix-darwin/issues/579)) ([0518c89](https://github.com/JacobPEvans/nix-darwin/commit/0518c89cd0d4c37e92e9c85ded161a2e2b8c348a))
* **vscode:** use activation script for writable settings ([#620](https://github.com/JacobPEvans/nix-darwin/issues/620)) ([5287eaf](https://github.com/JacobPEvans/nix-darwin/commit/5287eaf118bad42ebcbe77860529e413ffc9217f))
* **zsh:** add brew update on startup, fix background tasks, clean initContent ([#718](https://github.com/JacobPEvans/nix-darwin/issues/718)) ([dff5b8b](https://github.com/JacobPEvans/nix-darwin/commit/dff5b8bbc92256286f789a55d938229c00de6bde))
* **zsh:** add custom-auth claude launchers (av-claude, gh-claude-*) ([#978](https://github.com/JacobPEvans/nix-darwin/issues/978)) ([2f2ccd4](https://github.com/JacobPEvans/nix-darwin/commit/2f2ccd4133543453616c1a2bab88ade83c393185))


### Bug Fixes

* add 'with lib;' to options.nix to fix mkOption scope issue ([54dc6f4](https://github.com/JacobPEvans/nix-darwin/commit/54dc6f43a03cda0b82cbb2336e1904c5dc50703f))
* add bridge job for reusable workflow always() limitation ([#664](https://github.com/JacobPEvans/nix-darwin/issues/664)) ([3ba2cb0](https://github.com/JacobPEvans/nix-darwin/commit/3ba2cb0a45456cff3859a183b200be9b052c22ac))
* add cryptography to home-manager Python environments ([#565](https://github.com/JacobPEvans/nix-darwin/issues/565)) ([98eaed8](https://github.com/JacobPEvans/nix-darwin/commit/98eaed81d05aac8204703430f9dd0c6a31170e75))
* add explicit baseBranches to Renovate config ([#518](https://github.com/JacobPEvans/nix-darwin/issues/518)) ([98f8a5c](https://github.com/JacobPEvans/nix-darwin/commit/98f8a5c58b0a999bb2c9b7177890b14ed099df49))
* add explicit if condition on resolve job for skipped ancestors ([#667](https://github.com/JacobPEvans/nix-darwin/issues/667)) ([2680737](https://github.com/JacobPEvans/nix-darwin/commit/2680737c6efcddab5808dc47a90946586f53eeda))
* add explicit permissions to issue pipeline for cross-repo calls ([#663](https://github.com/JacobPEvans/nix-darwin/issues/663)) ([fc84108](https://github.com/JacobPEvans/nix-darwin/commit/fc84108f855660ff864231e62ccd5994f08df1a1))
* add missing lib. prefixes for types, lib functions ([343b6c2](https://github.com/JacobPEvans/nix-darwin/commit/343b6c2646ff36e9640c3ab99fade7c0e65bee3d))
* add release-please config for manifest mode ([84ed18b](https://github.com/JacobPEvans/nix-darwin/commit/84ed18b8c92816da83577e3441da52e47f4fd024))
* add schedule→dispatch workaround for OIDC bug (claude-code-action[#814](https://github.com/JacobPEvans/nix-darwin/issues/814)) ([#779](https://github.com/JacobPEvans/nix-darwin/issues/779)) ([f6a48d6](https://github.com/JacobPEvans/nix-darwin/commit/f6a48d6f9127a7001d364fc9c1d25b46cc8501bc))
* address PR review feedback ([399222e](https://github.com/JacobPEvans/nix-darwin/commit/399222eaee34e1e02f4d4621a9f4fee1548b9900))
* address PR review feedback on configuration patterns ([e00c1e0](https://github.com/JacobPEvans/nix-darwin/commit/e00c1e0dd8c18506869d14e77f26657ba7649719))
* align ai-assistant-instructions command source path with discovery path ([c6a84a6](https://github.com/JacobPEvans/nix-darwin/commit/c6a84a62040a1ba977b4f806b901574a3bf963a0))
* **auto-claude:** add Slack channel validation and keychain error handling ([#454](https://github.com/JacobPEvans/nix-darwin/issues/454)) ([6f6f402](https://github.com/JacobPEvans/nix-darwin/commit/6f6f4027f43d242885ac5e5ff1326f5d98ee5a9a))
* **auto-claude:** add SSH agent setup and headless authentication ([#453](https://github.com/JacobPEvans/nix-darwin/issues/453)) ([ba266b9](https://github.com/JacobPEvans/nix-darwin/commit/ba266b988348063e7bdfafcb12a01c6b1e7505fa))
* bump ai-workflows to v0.2.6 and add id-token:write ([#674](https://github.com/JacobPEvans/nix-darwin/issues/674)) ([dfe23e9](https://github.com/JacobPEvans/nix-darwin/commit/dfe23e939720317d3da0fded19a5da22e3c0604a))
* bump all ai-workflows callers to v0.2.7 ([#677](https://github.com/JacobPEvans/nix-darwin/issues/677)) ([ae28776](https://github.com/JacobPEvans/nix-darwin/commit/ae287761908ff2a89fbd60406d26b2cee269e91b))
* bump all ai-workflows callers to v0.2.8 ([#681](https://github.com/JacobPEvans/nix-darwin/issues/681)) ([9db24ea](https://github.com/JacobPEvans/nix-darwin/commit/9db24ead24c3811a751024109a0162e6777edf35))
* bump all ai-workflows callers to v0.2.9 ([#682](https://github.com/JacobPEvans/nix-darwin/issues/682)) ([09406d9](https://github.com/JacobPEvans/nix-darwin/commit/09406d972359caf73aac0cceae75fe12f3ed98d0))
* bump homeManagerStateVersion to 25.11 ([#873](https://github.com/JacobPEvans/nix-darwin/issues/873)) ([12fd1ee](https://github.com/JacobPEvans/nix-darwin/commit/12fd1ee4c2dd9f69429c50a80986b6a152aedc83))
* bump issue resolver/triage callers to v0.2.5 ([#673](https://github.com/JacobPEvans/nix-darwin/issues/673)) ([588015f](https://github.com/JacobPEvans/nix-darwin/commit/588015f79092ff62772ce659b6a45efb93217bcf))
* bump issue-resolver callers to v0.2.4 ([#670](https://github.com/JacobPEvans/nix-darwin/issues/670)) ([b08c3a4](https://github.com/JacobPEvans/nix-darwin/commit/b08c3a4e3aee0cd6b83f91fe9e776c8d55ad30bc))
* bump stateVersion to 25.11 with drift assertion ([#877](https://github.com/JacobPEvans/nix-darwin/issues/877)) ([887a41a](https://github.com/JacobPEvans/nix-darwin/commit/887a41acd16da94220c9cfbb1b8bd5bae0ebf3fc))
* change issue_number input type from number to string ([#675](https://github.com/JacobPEvans/nix-darwin/issues/675)) ([64872a7](https://github.com/JacobPEvans/nix-darwin/commit/64872a7d87c6b993a3a868b0036f0e13154e59fb))
* **ci:** add dispatch pattern for post-merge workflows ([#701](https://github.com/JacobPEvans/nix-darwin/issues/701)) ([41b8ad7](https://github.com/JacobPEvans/nix-darwin/commit/41b8ad79fb4f762f60e85963d33ef5359a415a33))
* **ci:** add nix-home to AI_INPUTS allowlist for dispatch events ([#754](https://github.com/JacobPEvans/nix-darwin/issues/754)) ([172519b](https://github.com/JacobPEvans/nix-darwin/commit/172519bb3d8e5ae9455dff1660887fc061a51ead))
* **ci:** add pull-requests: write for release-please auto-approval ([#848](https://github.com/JacobPEvans/nix-darwin/issues/848)) ([b9cb5a8](https://github.com/JacobPEvans/nix-darwin/commit/b9cb5a83b6aca2f7536cfd5ead8837e57f25c7b4))
* **ci:** add pull-requests: write for release-please auto-approval ([#850](https://github.com/JacobPEvans/nix-darwin/issues/850)) ([b561b18](https://github.com/JacobPEvans/nix-darwin/commit/b561b18c56b06549fe10dd18a757db6e72b1174e))
* **ci:** migrate copilot-setup-steps to determinate-nix-action@v3 ([#842](https://github.com/JacobPEvans/nix-darwin/issues/842)) ([63d82ef](https://github.com/JacobPEvans/nix-darwin/commit/63d82efed576f6921a68abfb0aa70ccb0f366f2a))
* **ci:** prevent Merge Gate false failures from cancelled runs ([#590](https://github.com/JacobPEvans/nix-darwin/issues/590)) ([f937654](https://github.com/JacobPEvans/nix-darwin/commit/f937654047bfeb5f77afcdf048ccb3c42e45f8bb))
* **ci:** remove jacobpevans-cc-plugins from AI_INPUTS ([#784](https://github.com/JacobPEvans/nix-darwin/issues/784)) ([669c2d8](https://github.com/JacobPEvans/nix-darwin/commit/669c2d83453d4335d795d9f37d2c08b5f727e214))
* **ci:** replace actions/cache with magic-nix-cache-action for Nix store ([#810](https://github.com/JacobPEvans/nix-darwin/issues/810)) ([631162b](https://github.com/JacobPEvans/nix-darwin/commit/631162bbea80b4c465e3a40448936478f31333e6))
* **ci:** use GitHub App token for release-please to trigger CI Gate ([#828](https://github.com/JacobPEvans/nix-darwin/issues/828)) ([7013a0e](https://github.com/JacobPEvans/nix-darwin/commit/7013a0edfe4fb48552a6a9ba6c3629827de043e6))
* **claude:** add marketplace cache integrity verification ([#611](https://github.com/JacobPEvans/nix-darwin/issues/611)) ([92a8c6a](https://github.com/JacobPEvans/nix-darwin/commit/92a8c6afe4d3a19b5108039f32129df115b00ffd))
* **claude:** add validation, shellcheck, and modular architecture ([32a0235](https://github.com/JacobPEvans/nix-darwin/commit/32a023511ef4608ec07ff95899434d44318bec88))
* **claude:** make attribution a proper Nix option, remove hardcoded Co-Authored-By ([#711](https://github.com/JacobPEvans/nix-darwin/issues/711)) ([7e93854](https://github.com/JacobPEvans/nix-darwin/commit/7e93854f704853dd2e31727b9b46a7c46c654f7a))
* **claude:** remove invalid MultiEdit tool from permissions ([#474](https://github.com/JacobPEvans/nix-darwin/issues/474)) ([fdbc0fb](https://github.com/JacobPEvans/nix-darwin/commit/fdbc0fbfde1fd63234c9bbbedbfe317463e1842e))
* **claude:** resolve marketplace symlink permission errors on darwin-rebuild ([#698](https://github.com/JacobPEvans/nix-darwin/issues/698)) ([bc42a5f](https://github.com/JacobPEvans/nix-darwin/commit/bc42a5ff98efea8e13b6c9e6acf5da40e0d8dc93))
* **claude:** restore opusplan as default model ([#633](https://github.com/JacobPEvans/nix-darwin/issues/633)) ([bd172ca](https://github.com/JacobPEvans/nix-darwin/commit/bd172ca4113b61a44e15eb8269906481c043f573))
* **claude:** use recursive=true for marketplace dirs, remove cleanup scripts ([#688](https://github.com/JacobPEvans/nix-darwin/issues/688)) ([974c549](https://github.com/JacobPEvans/nix-darwin/commit/974c549800452470365dfa17a95820593903ae53))
* configure markdownlint MD013 line length to 160 characters ([#517](https://github.com/JacobPEvans/nix-darwin/issues/517)) ([82e31e4](https://github.com/JacobPEvans/nix-darwin/commit/82e31e4b6518bc0deca18c3496f582d4a9d02254))
* consolidate file-size config into .file-size.yml with shared defaults ([#889](https://github.com/JacobPEvans/nix-darwin/issues/889)) ([a141129](https://github.com/JacobPEvans/nix-darwin/commit/a14112941c77b33bab77abb00d72edce7c806f42))
* consolidate Renovate config and remove broken postUpgradeTasks ([#886](https://github.com/JacobPEvans/nix-darwin/issues/886)) ([d0fe728](https://github.com/JacobPEvans/nix-darwin/commit/d0fe728e278c3b5594e539b38ea35e1f4c327f0c))
* correct broken nix repo reference in Renovate troubleshooting docs ([#813](https://github.com/JacobPEvans/nix-darwin/issues/813)) ([e663882](https://github.com/JacobPEvans/nix-darwin/commit/e6638829affb6eb81e617b370c766d0ffe4c8b54))
* correct document-skills plugin reference ([#572](https://github.com/JacobPEvans/nix-darwin/issues/572)) ([fc2e934](https://github.com/JacobPEvans/nix-darwin/commit/fc2e93443e7ca3e7d79c6e4b04173d5390d2b923))
* correct MANIFEST.md cask upgrade docs and Teams greedy flag ([#958](https://github.com/JacobPEvans/nix-darwin/issues/958)) ([b7cd0fe](https://github.com/JacobPEvans/nix-darwin/commit/b7cd0fe79342f2e9cd2d5378c20522c01930aa8b))
* **darwin:** remove Paw defaults write (sandboxed container app) ([#856](https://github.com/JacobPEvans/nix-darwin/issues/856)) ([3abb0fb](https://github.com/JacobPEvans/nix-darwin/commit/3abb0fbb58e4a855acc305446a8181d258c7fb05))
* **deps:** add Renovate annotation for ClaudeBar package ([#917](https://github.com/JacobPEvans/nix-darwin/issues/917)) ([b55018c](https://github.com/JacobPEvans/nix-darwin/commit/b55018c70ffab98830cf9523349067068e9ca2bd))
* **deps:** update all flake inputs and ClaudeBar to 0.4.57 ([#938](https://github.com/JacobPEvans/nix-darwin/issues/938)) ([b234826](https://github.com/JacobPEvans/nix-darwin/commit/b2348269769faa166dd7a194e0c2b2ff04c73f58))
* **deps:** update flake inputs and fix gh-aw hash mismatch ([#924](https://github.com/JacobPEvans/nix-darwin/issues/924)) ([a4559b5](https://github.com/JacobPEvans/nix-darwin/commit/a4559b57627f9415c165c5befc5b8b8796e42cb6))
* **deps:** update jacobpevans-cc-plugins to register pal-health plugin ([#906](https://github.com/JacobPEvans/nix-darwin/issues/906)) ([f8d4578](https://github.com/JacobPEvans/nix-darwin/commit/f8d4578d7f3c614b5f20aea634b28fe969f2cdde))
* disable hash pinning for trusted actions, use version tags ([#790](https://github.com/JacobPEvans/nix-darwin/issues/790)) ([94630a1](https://github.com/JacobPEvans/nix-darwin/commit/94630a1a1d838628d8d1f37c504152ef8ca009b5))
* drastically reduce Claude Code context token usage ([ec8899e](https://github.com/JacobPEvans/nix-darwin/commit/ec8899e845b6edf158265e7cc636ab110e63a9b7))
* exempt CHANGELOG.md from file size limit ([#887](https://github.com/JacobPEvans/nix-darwin/issues/887)) ([c071d53](https://github.com/JacobPEvans/nix-darwin/commit/c071d53cf3c35d7b8bce874bff2cc21e1ccb5a43))
* **flake-rebuild:** clarify command must always execute the rebuild ([#893](https://github.com/JacobPEvans/nix-darwin/issues/893)) ([c0c2960](https://github.com/JacobPEvans/nix-darwin/commit/c0c2960115222eb6522b6f8cd4f2737666d86ced))
* **flake-rebuild:** only skip PR creation when an open PR exists ([#898](https://github.com/JacobPEvans/nix-darwin/issues/898)) ([64c5af0](https://github.com/JacobPEvans/nix-darwin/commit/64c5af04ac76fe64b21305c843f20e1aff938f14))
* **gemini:** use activation script for writable settings ([#613](https://github.com/JacobPEvans/nix-darwin/issues/613)) ([b307d7f](https://github.com/JacobPEvans/nix-darwin/commit/b307d7f201cbdb9e4197e2c4be68b766249f78d0))
* gitignore plugin-generated .claude/skills/ directory ([#910](https://github.com/JacobPEvans/nix-darwin/issues/910)) ([739070f](https://github.com/JacobPEvans/nix-darwin/commit/739070f373bfe86fb635013b86162662d16aeb05))
* **git:** run pre-push hook on changed files only, handle deletions and use read -r ([9c16611](https://github.com/JacobPEvans/nix-darwin/commit/9c16611dafaf6da12aa7c6f966f1cba6a1379675))
* **git:** use merge-base with remote default branch for new-branch pre-push ([49b2fe2](https://github.com/JacobPEvans/nix-darwin/commit/49b2fe2e4ce1dc186acfb8c45655e9c13e3f0782))
* **homebrew:** add greedy flag to microsoft-teams cask ([#853](https://github.com/JacobPEvans/nix-darwin/issues/853)) ([3191d05](https://github.com/JacobPEvans/nix-darwin/commit/3191d0535fbf9e61ae7e3ecdb4b82bbfd6716b7d))
* **homebrew:** brew autoupdate LaunchAgent never created on darwin-rebuild ([9256aa3](https://github.com/JacobPEvans/nix-darwin/commit/9256aa3a72adfa4a7b22e278ba86afa69ffc37ee))
* **homebrew:** use /usr/bin/stat to avoid GNU stat in Nix PATH ([#916](https://github.com/JacobPEvans/nix-darwin/issues/916)) ([9ebbce5](https://github.com/JacobPEvans/nix-darwin/commit/9ebbce555196460c99bbc935d322810924d62ec9))
* **mcp:** reorganize external MCP plugins and enable Context7 ([#491](https://github.com/JacobPEvans/nix-darwin/issues/491)) ([34c74d3](https://github.com/JacobPEvans/nix-darwin/commit/34c74d359367d6701d5a78c2ef46e16f4c1429ec))
* **mcp:** reorganize MCP plugins and add Context7 server ([#487](https://github.com/JacobPEvans/nix-darwin/issues/487)) ([e41ac04](https://github.com/JacobPEvans/nix-darwin/commit/e41ac046d35f452ac09739ae004e917607e3dea2))
* migrate Bash permissions to space format and expand command tools ([#846](https://github.com/JacobPEvans/nix-darwin/issues/846)) ([48d7e81](https://github.com/JacobPEvans/nix-darwin/commit/48d7e811436fc42b458e4411011e41b23b179847))
* **monitoring:** ensure ws-monitor produces output on every run ([#956](https://github.com/JacobPEvans/nix-darwin/issues/956)) ([07e5426](https://github.com/JacobPEvans/nix-darwin/commit/07e5426dd96b614d6496aca79197193db8fea225))
* **monitoring:** use absolute paths and fix log dir permissions ([baaa6e0](https://github.com/JacobPEvans/nix-darwin/commit/baaa6e0cd5f8d8720d0b54e2f11aa7396d9b4413))
* move Postman from nixpkgs to Homebrew cask ([#809](https://github.com/JacobPEvans/nix-darwin/issues/809)) ([35b28f9](https://github.com/JacobPEvans/nix-darwin/commit/35b28f90238f03a0f98894294393787a5c6d42b6))
* **nix:** use list type for determinateNix.customSettings ([#840](https://github.com/JacobPEvans/nix-darwin/issues/840)) ([29ec20e](https://github.com/JacobPEvans/nix-darwin/commit/29ec20e257dfb95c2b7ebd8ae1ee00472c34b96e))
* **permissions:** support MCP tool permissions in pipeline ([4767fe4](https://github.com/JacobPEvans/nix-darwin/commit/4767fe436a9d7a3e460165388e48f5e602c528dc))
* **plugins:** exclude schemas dir from plugin auto-discovery ([6390149](https://github.com/JacobPEvans/nix-darwin/commit/63901499239aeebf22d908af77e23ab4989bdcce))
* **plugins:** improve activation script diff error handling ([#470](https://github.com/JacobPEvans/nix-darwin/issues/470)) ([9aac29b](https://github.com/JacobPEvans/nix-darwin/commit/9aac29b19faa5a8a358ae1533ccd479b805a7f9f))
* **plugins:** remove non-existent clerk-auth and add missing official plugins ([#587](https://github.com/JacobPEvans/nix-darwin/issues/587)) ([b14f443](https://github.com/JacobPEvans/nix-darwin/commit/b14f443ece5fc6694a4410f31a25ba76605d9eef))
* **pre-commit:** remove darwin-rebuild from pre-push hook ([#709](https://github.com/JacobPEvans/nix-darwin/issues/709)) ([3bfbb19](https://github.com/JacobPEvans/nix-darwin/commit/3bfbb19ddbe5fb13630ae43adbcdb51762b32750))
* prevent bot review comments from cancelling Claude review ([#630](https://github.com/JacobPEvans/nix-darwin/issues/630)) ([a9975c3](https://github.com/JacobPEvans/nix-darwin/commit/a9975c341c6bf7d8be1dbe6af009b35cb6dc0c76))
* prevent Claude from guessing incorrect skill namespaces ([#504](https://github.com/JacobPEvans/nix-darwin/issues/504)) ([7c12012](https://github.com/JacobPEvans/nix-darwin/commit/7c12012805d38f908da9e6b4a8e38f2d84f8db7d))
* remove blanket auto-merge workflow ([#789](https://github.com/JacobPEvans/nix-darwin/issues/789)) ([618eca9](https://github.com/JacobPEvans/nix-darwin/commit/618eca9f4f85adea87e0cffd570c42213227fee8))
* remove claude-review workflow, migrate review-deps to OpenRouter ([#957](https://github.com/JacobPEvans/nix-darwin/issues/957)) ([4df33bb](https://github.com/JacobPEvans/nix-darwin/commit/4df33bb2dc36b8188581090b889a5226c61664ce))
* remove deprecated SlashCommand permission ([#646](https://github.com/JacobPEvans/nix-darwin/issues/646)) ([9a78cbc](https://github.com/JacobPEvans/nix-darwin/commit/9a78cbc73348ee3aba3fcffcb1a15ab4e8da0979))
* remove mcpServers from settings.json (wrong location) ([ceb4798](https://github.com/JacobPEvans/nix-darwin/commit/ceb4798eea8c50414352d03da8f14361b93e26aa))
* remove nixpkgs-unstable overlay ([#879](https://github.com/JacobPEvans/nix-darwin/issues/879)) ([a870f35](https://github.com/JacobPEvans/nix-darwin/commit/a870f356a4d6f6a55043c2f021593151647024a4))
* remove Ollama from system packages and disable volume ([#875](https://github.com/JacobPEvans/nix-darwin/issues/875)) ([58ef9f9](https://github.com/JacobPEvans/nix-darwin/commit/58ef9f9b693ab7193e7066ec1bbe5f420837ae47))
* remove unused lambda parameters flagged by deadnix ([#808](https://github.com/JacobPEvans/nix-darwin/issues/808)) ([862c660](https://github.com/JacobPEvans/nix-darwin/commit/862c66092e4f62680425866dcb979b5578e99f58))
* remove unused OpenHands AI workflow ([#951](https://github.com/JacobPEvans/nix-darwin/issues/951)) ([e612245](https://github.com/JacobPEvans/nix-darwin/commit/e612245cff36f04d2c64bc56c367177210fd29d1))
* rename caller job keys to avoid reusable workflow name collision ([#671](https://github.com/JacobPEvans/nix-darwin/issues/671)) ([e23660a](https://github.com/JacobPEvans/nix-darwin/commit/e23660ab562ccfd32ca45aa9b72049c9af387833))
* rename GH_APP_ID secret to GH_ACTION_JACOBPEVANS_APP_ID ([#814](https://github.com/JacobPEvans/nix-darwin/issues/814)) ([8be189b](https://github.com/JacobPEvans/nix-darwin/commit/8be189b02f82642a6f4f00612fab985411364d27))
* **renovate:** add shared preset, remove global automerge, fix deprecated matchers ([#796](https://github.com/JacobPEvans/nix-darwin/issues/796)) ([315907d](https://github.com/JacobPEvans/nix-darwin/commit/315907d3ec7a2d9a51902c29f9c92d0a8596b574))
* **renovate:** deduplicate config and guard git-refs major updates ([#797](https://github.com/JacobPEvans/nix-darwin/issues/797)) ([e5d6251](https://github.com/JacobPEvans/nix-darwin/commit/e5d625123a1bf198b8557daf30be7aa834a52dee))
* **renovate:** remove duplicate automerge from AI tools group ([#937](https://github.com/JacobPEvans/nix-darwin/issues/937)) ([85c5513](https://github.com/JacobPEvans/nix-darwin/commit/85c5513d933426806513b60a99c8b8fc998d0b78))
* **renovate:** trust ai-tools group for all update types ([#902](https://github.com/JacobPEvans/nix-darwin/issues/902)) ([2dc7a39](https://github.com/JacobPEvans/nix-darwin/commit/2dc7a39a32bdae29f78c57db09d7d7047d8a68f7))
* reorder dock apps, document Quotio install, and trampoline permissions ([#521](https://github.com/JacobPEvans/nix-darwin/issues/521)) ([b1bc3f7](https://github.com/JacobPEvans/nix-darwin/commit/b1bc3f7b2cbbdec8d12592a31e8d115a82a385d2)), closes [#461](https://github.com/JacobPEvans/nix-darwin/issues/461) [#438](https://github.com/JacobPEvans/nix-darwin/issues/438) [#424](https://github.com/JacobPEvans/nix-darwin/issues/424)
* replace renovate annotation with nix-update convention in claudebar ([#964](https://github.com/JacobPEvans/nix-darwin/issues/964)) ([0a435e2](https://github.com/JacobPEvans/nix-darwin/commit/0a435e21a40fdde1e07453c87a7f978cffdfec76))
* resolve build warnings and resolve agent symlink conflict ([#457](https://github.com/JacobPEvans/nix-darwin/issues/457)) ([b55b777](https://github.com/JacobPEvans/nix-darwin/commit/b55b777a41f19fd20de1fa15a6f6ffc6d8ecd76b))
* resolve Claude Code + Nix configuration issues ([1f547af](https://github.com/JacobPEvans/nix-darwin/commit/1f547afb9b8c8889edc7fef59efdde2370a97994))
* resolve darwin-rebuild warnings for options.json and lsregister ([#621](https://github.com/JacobPEvans/nix-darwin/issues/621)) ([5d431e4](https://github.com/JacobPEvans/nix-darwin/commit/5d431e496376c1e2acb527d886c877fe70dffcdb))
* resolve GitHub code scanning alerts ([#499](https://github.com/JacobPEvans/nix-darwin/issues/499)) ([98594e8](https://github.com/JacobPEvans/nix-darwin/commit/98594e8722d3c028de63d258692c8a1f0663543b))
* resolve home-manager rebuild warnings and orphan symlinks ([a67bc46](https://github.com/JacobPEvans/nix-darwin/commit/a67bc4633e2cb696319a6af37b31d89a632a812d))
* restore plugins, upgrade claude-code, fix marketplace naming ([3d5643e](https://github.com/JacobPEvans/nix-darwin/commit/3d5643e83a874efec5101ea69e5a6fbb6d385bd4))
* robustly handle filenames with spaces/newlines in symlink cleanup ([a2a5696](https://github.com/JacobPEvans/nix-darwin/commit/a2a56965180531acd9180f7ad22394cccf965086))
* scope gitignore to only exclude retrospecting reports, not all skills ([#912](https://github.com/JacobPEvans/nix-darwin/issues/912)) ([a055c94](https://github.com/JacobPEvans/nix-darwin/commit/a055c9488f025cc0db2f82dce1a04c8890c786ff))
* **security:** add 3-day stabilization to vulnerability alert PRs ([#922](https://github.com/JacobPEvans/nix-darwin/issues/922)) ([ebf5647](https://github.com/JacobPEvans/nix-darwin/commit/ebf56475bdf8202a97eab108a72677659b5825ed))
* **security:** harden CI gate for flake.lock changes on deps-only PRs ([#925](https://github.com/JacobPEvans/nix-darwin/issues/925)) ([0b1d458](https://github.com/JacobPEvans/nix-darwin/commit/0b1d458df2bf07cab32229bec761d8ea781668ef))
* source AI CLI tools from unstable overlay for version currency ([#619](https://github.com/JacobPEvans/nix-darwin/issues/619)) ([ca186fb](https://github.com/JacobPEvans/nix-darwin/commit/ca186fbb8d69782fc34952b1e2530e1686f5b009))
* split issue pipeline and fix permissions/version on all callers ([#669](https://github.com/JacobPEvans/nix-darwin/issues/669)) ([fd1add1](https://github.com/JacobPEvans/nix-darwin/commit/fd1add1cd2c65150501ba896bd40cc89bb2a92a0))
* split resolve into auto and manual paths ([#668](https://github.com/JacobPEvans/nix-darwin/issues/668)) ([8c7f690](https://github.com/JacobPEvans/nix-darwin/commit/8c7f690a65a50bd8e1d0fa1b482d30058407a2dd))
* Standardize logging format and improve darwin-rebuild diagnostics ([#475](https://github.com/JacobPEvans/nix-darwin/issues/475)) ([ccd96da](https://github.com/JacobPEvans/nix-darwin/commit/ccd96da8ea8af10d0c811001ede5f7725b371caf))
* **startup:** consolidate startup-tuning into streamline-login ([#935](https://github.com/JacobPEvans/nix-darwin/issues/935)) ([644c909](https://github.com/JacobPEvans/nix-darwin/commit/644c9095cb261f53fc087072c8bbfa3b32950d6f))
* **startup:** disable unnecessary Apple LaunchAgents that degrade boot performance ([#930](https://github.com/JacobPEvans/nix-darwin/issues/930)) ([1e833c8](https://github.com/JacobPEvans/nix-darwin/commit/1e833c8d2c6989680a073d32185d12f4af229c9e))
* switch to stable 25.11 (nixpkgs, darwin, home-manager) ([473432a](https://github.com/JacobPEvans/nix-darwin/commit/473432a494536e6bcae717f9bbb98e3973b0d180))
* sync release-please permissions and VERSION ([ba0eb02](https://github.com/JacobPEvans/nix-darwin/commit/ba0eb02830635cbc36ab81f4ee1c15c556e96dd0))
* **terraform-shell:** remove broken checkov and terrascan packages ([#706](https://github.com/JacobPEvans/nix-darwin/issues/706)) ([c275e70](https://github.com/JacobPEvans/nix-darwin/commit/c275e70bf1619d76b3e9ada1747d5adea2447fec))
* update CLAUDE.md to reference three companion repos (quartet) ([#881](https://github.com/JacobPEvans/nix-darwin/issues/881)) ([82ca482](https://github.com/JacobPEvans/nix-darwin/commit/82ca482825280f53b03c007bff894d3260695076))
* update ClaudeBar to v0.4.43 ([#818](https://github.com/JacobPEvans/nix-darwin/issues/818)) ([35b6dfa](https://github.com/JacobPEvans/nix-darwin/commit/35b6dfad18fcfa17e3d3fd5dec50d5c16fc616d7))
* update Copilot setup source to ai-workflows ([#968](https://github.com/JacobPEvans/nix-darwin/issues/968)) ([3400d66](https://github.com/JacobPEvans/nix-darwin/commit/3400d66cdfcc896789de256911d02b0a3e4e4e2a))
* update dispatch pipeline with ai:ready trigger and daily limit ([#759](https://github.com/JacobPEvans/nix-darwin/issues/759)) ([f564201](https://github.com/JacobPEvans/nix-darwin/commit/f564201e328c7bfd7a314ffed59b11b35a9527a8))
* update flake inputs after nix-ai and nix-home cleanup PRs ([#882](https://github.com/JacobPEvans/nix-darwin/issues/882)) ([0a05872](https://github.com/JacobPEvans/nix-darwin/commit/0a058724ace7d6f192702aa90d99c26bb1f44832))
* update issue pipeline to ai-workflows v0.2.1 ([#665](https://github.com/JacobPEvans/nix-darwin/issues/665)) ([ad8fbab](https://github.com/JacobPEvans/nix-darwin/commit/ad8fbab5d25091c4c951e22e4c96a125de23a8ba))
* update issue pipeline to ai-workflows v0.2.2 ([#666](https://github.com/JacobPEvans/nix-darwin/issues/666)) ([98b2c75](https://github.com/JacobPEvans/nix-darwin/commit/98b2c7541330451f5e6b7c2612eda5a1187a56b6))
* update nix-ai (MLX port 11435→11436, port conflict) ([#869](https://github.com/JacobPEvans/nix-darwin/issues/869)) ([d399876](https://github.com/JacobPEvans/nix-darwin/commit/d39987629c25af1c7f02425e3aa56d13b6564f75))
* update nix-ai flake input to latest ([#860](https://github.com/JacobPEvans/nix-darwin/issues/860)) ([10c6032](https://github.com/JacobPEvans/nix-darwin/commit/10c6032b08cfa47d4dd3f926e173f2df38013b65))
* update nix-ai input (v0.2.6 CLI flags + checks split) ([#885](https://github.com/JacobPEvans/nix-darwin/issues/885)) ([7e19da6](https://github.com/JacobPEvans/nix-darwin/commit/7e19da6d768fe680957c5ba15940a82e98c0081a))
* use full path /opt/homebrew/bin/brew, fall back to stat -f '%Su' /dev/console for user detection. ([9256aa3](https://github.com/JacobPEvans/nix-darwin/commit/9256aa3a72adfa4a7b22e278ba86afa69ffc37ee))
* wire up ask permissions in Claude Code config ([#483](https://github.com/JacobPEvans/nix-darwin/issues/483)) ([b2aecb0](https://github.com/JacobPEvans/nix-darwin/commit/b2aecb0d1ea393405a2a09977c0bad5628bb94fa))


### Performance

* **ci:** optimize Nix build CI from 11m 40s to 9m 35s per PR ([#552](https://github.com/JacobPEvans/nix-darwin/issues/552)) ([e962d8d](https://github.com/JacobPEvans/nix-darwin/commit/e962d8dd84244cccaa789d200e989d655a3f8785))

## [1.25.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.24.0...v1.25.0) (2026-04-11)


### Features

* **zsh:** add custom-auth claude launchers (av-claude, gh-claude-*) ([#978](https://github.com/JacobPEvans/nix-darwin/issues/978)) ([2f2ccd4](https://github.com/JacobPEvans/nix-darwin/commit/2f2ccd4133543453616c1a2bab88ade83c393185))

## [1.24.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.23.0...v1.24.0) (2026-04-10)


### Features

* add libreoffice homebrew cask for document-skills ([#974](https://github.com/JacobPEvans/nix-darwin/issues/974)) ([8fb828f](https://github.com/JacobPEvans/nix-darwin/commit/8fb828ff4a5cfbb0d1ac075a39dfc52392c7164d))

## [1.23.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.22.1...v1.23.0) (2026-04-10)


### Features

* tiered GitHub token context switching ([#971](https://github.com/JacobPEvans/nix-darwin/issues/971)) ([cf83afc](https://github.com/JacobPEvans/nix-darwin/commit/cf83afc16c037416c8ecca1fda9c3380021ab9ad))

## [1.22.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.22.0...v1.22.1) (2026-04-08)


### Bug Fixes

* update Copilot setup source to ai-workflows ([#968](https://github.com/JacobPEvans/nix-darwin/issues/968)) ([3400d66](https://github.com/JacobPEvans/nix-darwin/commit/3400d66cdfcc896789de256911d02b0a3e4e4e2a))

## [1.22.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.21.3...v1.22.0) (2026-04-07)


### Features

* add AI merge gate ([#966](https://github.com/JacobPEvans/nix-darwin/issues/966)) ([f8d19ed](https://github.com/JacobPEvans/nix-darwin/commit/f8d19edee02ce42f3f1f82d5c377807f033a7742))

## [1.21.3](https://github.com/JacobPEvans/nix-darwin/compare/v1.21.2...v1.21.3) (2026-04-07)


### Bug Fixes

* replace renovate annotation with nix-update convention in claudebar ([#964](https://github.com/JacobPEvans/nix-darwin/issues/964)) ([0a435e2](https://github.com/JacobPEvans/nix-darwin/commit/0a435e21a40fdde1e07453c87a7f978cffdfec76))

## [1.21.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.21.1...v1.21.2) (2026-04-04)


### Bug Fixes

* correct MANIFEST.md cask upgrade docs and Teams greedy flag ([#958](https://github.com/JacobPEvans/nix-darwin/issues/958)) ([b7cd0fe](https://github.com/JacobPEvans/nix-darwin/commit/b7cd0fe79342f2e9cd2d5378c20522c01930aa8b))

## [1.21.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.21.0...v1.21.1) (2026-04-04)


### Bug Fixes

* **monitoring:** ensure ws-monitor produces output on every run ([#956](https://github.com/JacobPEvans/nix-darwin/issues/956)) ([07e5426](https://github.com/JacobPEvans/nix-darwin/commit/07e5426dd96b614d6496aca79197193db8fea225))
* remove claude-review workflow, migrate review-deps to OpenRouter ([#957](https://github.com/JacobPEvans/nix-darwin/issues/957)) ([4df33bb](https://github.com/JacobPEvans/nix-darwin/commit/4df33bb2dc36b8188581090b889a5226c61664ce))

## [1.21.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.20.2...v1.21.0) (2026-04-02)


### Features

* add ansible Python package set with paramiko and jsondiff ([#531](https://github.com/JacobPEvans/nix-darwin/issues/531)) ([454d393](https://github.com/JacobPEvans/nix-darwin/commit/454d393e23f3eeaa96cd556b0d434324d2b7a65a))
* add APFS volume quota support and AI model volumes ([#832](https://github.com/JacobPEvans/nix-darwin/issues/832)) ([4d0aea3](https://github.com/JacobPEvans/nix-darwin/commit/4d0aea3b6cd6bddc15fc52ae1d9095a3c198f36f))
* add CI auto-fix workflow and enable Claude review ([#624](https://github.com/JacobPEvans/nix-darwin/issues/624)) ([e7645f2](https://github.com/JacobPEvans/nix-darwin/commit/e7645f25d3b35cca9b876f23fc239875d7415ba3))
* add Cribl Edge nix-darwin module ([#871](https://github.com/JacobPEvans/nix-darwin/issues/871)) ([3d1758b](https://github.com/JacobPEvans/nix-darwin/commit/3d1758b4f0dc683032dcde0559f4fa9c4f796726))
* add Cribl MCP server via Nix-managed SSE transport ([#728](https://github.com/JacobPEvans/nix-darwin/issues/728)) ([89c9544](https://github.com/JacobPEvans/nix-darwin/commit/89c9544d4e1c2788f69ac9b4270bd5510cb0415e))
* add cryptography to system Python environment ([#563](https://github.com/JacobPEvans/nix-darwin/issues/563)) ([2beeeb1](https://github.com/JacobPEvans/nix-darwin/commit/2beeeb1d4ea1c71fad42795eb11ee33bd4e1d610))
* add daily repo health audit agentic workflow ([#822](https://github.com/JacobPEvans/nix-darwin/issues/822)) ([974b393](https://github.com/JacobPEvans/nix-darwin/commit/974b393379a2409cd1c431d55154904a5d25fbb2))
* add Docker daemon log rotation and builder GC config ([#803](https://github.com/JacobPEvans/nix-darwin/issues/803)) ([26e5ca0](https://github.com/JacobPEvans/nix-darwin/commit/26e5ca07dc53c1b3b1c2005010fe0cc5892e0e0f))
* add doppler-mcp wrapper for MCP server secret injection ([#732](https://github.com/JacobPEvans/nix-darwin/issues/732)) ([42de771](https://github.com/JacobPEvans/nix-darwin/commit/42de771a190036e76dacf5c769ba3811670219fc))
* add event-based cleanup for orphaned MCP server processes ([#652](https://github.com/JacobPEvans/nix-darwin/issues/652)) ([f6157f8](https://github.com/JacobPEvans/nix-darwin/commit/f6157f8670b6db46787070df2e39e99885706621))
* add ffmpeg media encoding tool ([#534](https://github.com/JacobPEvans/nix-darwin/issues/534)) ([309ff05](https://github.com/JacobPEvans/nix-darwin/commit/309ff05228781c8968defd6b4ed662837f5d3ce0))
* add final PR review workflow ([#626](https://github.com/JacobPEvans/nix-darwin/issues/626)) ([d6d5db8](https://github.com/JacobPEvans/nix-darwin/commit/d6d5db81750ebef2396cd5042c1682e86a52de21))
* add gh-aw agentic workflows ([#766](https://github.com/JacobPEvans/nix-darwin/issues/766)) ([8489738](https://github.com/JacobPEvans/nix-darwin/commit/8489738fb4333401fe79a0c41edfd4fc4e8e4072))
* add gh-aw CLI extension via Home Manager ([#597](https://github.com/JacobPEvans/nix-darwin/issues/597)) ([6e94831](https://github.com/JacobPEvans/nix-darwin/commit/6e94831d57dd9afedfe2f23e3929419f897e9cf2))
* add git-bug as universally available system tool ([#678](https://github.com/JacobPEvans/nix-darwin/issues/678)) ([9258edf](https://github.com/JacobPEvans/nix-darwin/commit/9258edfb602b81216759c4f6c4f2ea90d1e7fd68))
* add granola-watcher LaunchAgent for auto-migration ([#629](https://github.com/JacobPEvans/nix-darwin/issues/629)) ([58f9b2f](https://github.com/JacobPEvans/nix-darwin/commit/58f9b2f367f9c43f24d36db9418e5a140289339e))
* add HF_TOKEN to macOS Keychain exports for HuggingFace MCP ([#827](https://github.com/JacobPEvans/nix-darwin/issues/827)) ([9fa5d56](https://github.com/JacobPEvans/nix-darwin/commit/9fa5d56b782f7f802da2a6d8ee69349dc91a4fe5))
* add kubernetes dev shell with validation tooling ([#640](https://github.com/JacobPEvans/nix-darwin/issues/640)) ([c69caff](https://github.com/JacobPEvans/nix-darwin/commit/c69caff29654e896cf11c271842054f5ee9b64c7))
* add LM Studio and update nix-ai/nix-home inputs ([4e6c828](https://github.com/JacobPEvans/nix-darwin/commit/4e6c82866afd6124486c70333a4f0c1c4fcde2be))
* add maestro auto run integration for automated issue resolution ([#513](https://github.com/JacobPEvans/nix-darwin/issues/513)) ([af24e42](https://github.com/JacobPEvans/nix-darwin/commit/af24e427b00c31729010bcb18d4a1cee64523717))
* add MCP server packages and fix CLI registration docs ([108d8ca](https://github.com/JacobPEvans/nix-darwin/commit/108d8ca52a572b54900bbfe2d3adec8bbff15918))
* add Microsoft Teams cask and migrate OrbStack to Homebrew for TCC stability ([#653](https://github.com/JacobPEvans/nix-darwin/issues/653)) ([be2be35](https://github.com/JacobPEvans/nix-darwin/commit/be2be35dee540305d93456fe48db553ca712450a))
* add nixpkgs-unstable overlay for GUI apps ([#524](https://github.com/JacobPEvans/nix-darwin/issues/524)) ([f9424a6](https://github.com/JacobPEvans/nix-darwin/commit/f9424a61882ecd695b465a96cc91103183ad3e0b))
* add Obsidian skills plugins ([#574](https://github.com/JacobPEvans/nix-darwin/issues/574)) ([66e1de9](https://github.com/JacobPEvans/nix-darwin/commit/66e1de9945e3c3aa499f74d45c57213c97426443))
* add official Claude plugins and pyright tool ([#501](https://github.com/JacobPEvans/nix-darwin/issues/501)) ([9629bd0](https://github.com/JacobPEvans/nix-darwin/commit/9629bd0ea46d45d59dceeab6c50f44adccaf9666))
* add plugin auto-update support and stable update channel ([#566](https://github.com/JacobPEvans/nix-darwin/issues/566)) ([55572c9](https://github.com/JacobPEvans/nix-darwin/commit/55572c9c79942e23b2c2d7289dee18f685e25cb5))
* add Python multi-version support (3.10, 3.12) with uv-based 3.9 ([#506](https://github.com/JacobPEvans/nix-darwin/issues/506)) ([a4dc4cb](https://github.com/JacobPEvans/nix-darwin/commit/a4dc4cba4213355e6e9410b9d9542977808dd3d6))
* add SOPS_AGE_KEY_FILE and EDITOR=vim to session variables ([#635](https://github.com/JacobPEvans/nix-darwin/issues/635)) ([59e5a56](https://github.com/JacobPEvans/nix-darwin/commit/59e5a565406378de1a1c6eba368676ba3afe3365))
* add SOPS-encrypted pre-commit hook for keyword scanning ([#725](https://github.com/JacobPEvans/nix-darwin/issues/725)) ([396fee2](https://github.com/JacobPEvans/nix-darwin/commit/396fee2bbc49209c8952b2fbe4bc5b317e105bb1))
* add Splunk MCP server to Claude Code mcpServers ([#829](https://github.com/JacobPEvans/nix-darwin/issues/829)) ([f212edd](https://github.com/JacobPEvans/nix-darwin/commit/f212edd3660b7dde9f5bb0e134df6857481996b0))
* add upstream-repo-updated dispatch for cross-repo triggers ([#560](https://github.com/JacobPEvans/nix-darwin/issues/560)) ([914eed2](https://github.com/JacobPEvans/nix-darwin/commit/914eed2a2c90eb73c4791e2b761f5b8c0dfec783))
* add watchexec package and create MANIFEST.md inventory ([#628](https://github.com/JacobPEvans/nix-darwin/issues/628)) ([45215bb](https://github.com/JacobPEvans/nix-darwin/commit/45215bb9e860c8f103273a9d5c111b97922f0ee3))
* add wispr-flow voice dictation app ([#493](https://github.com/JacobPEvans/nix-darwin/issues/493)) ([0404e9a](https://github.com/JacobPEvans/nix-darwin/commit/0404e9a62a620cf29155d87ecb398b60e53b2c0a))
* **ai:** install codex cli and official gemini vscode extension ([#570](https://github.com/JacobPEvans/nix-darwin/issues/570)) ([3cbf944](https://github.com/JacobPEvans/nix-darwin/commit/3cbf944c89ea337bf06fa146c096e3195247638a))
* **aliases:** add d-claude for Doppler secrets injection ([da3c2ca](https://github.com/JacobPEvans/nix-darwin/commit/da3c2cafc499e2febe37c03a4f2703df17eaaf6d))
* auto-discover JacobPEvans plugins from flake input ([#557](https://github.com/JacobPEvans/nix-darwin/issues/557)) ([091b681](https://github.com/JacobPEvans/nix-darwin/commit/091b6812ef63a3a306ec2c87547e019e74dd9bc3))
* auto-enable squash merge on all PRs when opened ([#742](https://github.com/JacobPEvans/nix-darwin/issues/742)) ([f9d55a7](https://github.com/JacobPEvans/nix-darwin/commit/f9d55a7633729ef4d6e6402d95d6686ad7b1a345))
* **aws:** add terraform-bedrock and iam-user profiles ([#488](https://github.com/JacobPEvans/nix-darwin/issues/488)) ([e3be0ac](https://github.com/JacobPEvans/nix-darwin/commit/e3be0acfc89c2a192cfb0268e7b2000b1c388e2d))
* **ci:** add nix-ai to AI_INPUTS allowlist in deps-update-flake ([#750](https://github.com/JacobPEvans/nix-darwin/issues/750)) ([04f012e](https://github.com/JacobPEvans/nix-darwin/commit/04f012ebd5aa3677864616d19ad906b9087304f3))
* **ci:** unified issue dispatch pattern with AI-created issue support ([#710](https://github.com/JacobPEvans/nix-darwin/issues/710)) ([e603c25](https://github.com/JacobPEvans/nix-darwin/commit/e603c251d262912f1d726b59687326dfab9506ba))
* **claude:** add remoteControlAtStartup option, extract activation scripts to shell files ([#713](https://github.com/JacobPEvans/nix-darwin/issues/713)) ([a3cca1a](https://github.com/JacobPEvans/nix-darwin/commit/a3cca1a172d4647bff268448635af7ed5f2a2108))
* **claude:** disable redundant MCP servers and playwright plugin globally ([#748](https://github.com/JacobPEvans/nix-darwin/issues/748)) ([dfeb7c3](https://github.com/JacobPEvans/nix-darwin/commit/dfeb7c30e9ca62e77f6a6515065c15707803cb67))
* **claude:** enable agent teams and use default model ([#551](https://github.com/JacobPEvans/nix-darwin/issues/551)) ([1468168](https://github.com/JacobPEvans/nix-darwin/commit/14681686f8505a4729d4ed38b8543fcd28515e7a))
* **claude:** pin statusline to semver ^1, set effort medium, add 1M context disable ([#700](https://github.com/JacobPEvans/nix-darwin/issues/700)) ([0e3801c](https://github.com/JacobPEvans/nix-darwin/commit/0e3801cd4d65f78ebad31b498c1600c44a5b2c01))
* **claude:** set default startup model to opusplan ([#599](https://github.com/JacobPEvans/nix-darwin/issues/599)) ([56f9c1b](https://github.com/JacobPEvans/nix-darwin/commit/56f9c1bfe8b165339ab7debf7ff23ec9f0863021))
* configure plugin marketplaces via Nix ([#478](https://github.com/JacobPEvans/nix-darwin/issues/478)) ([107e538](https://github.com/JacobPEvans/nix-darwin/commit/107e5381c6cd1dce09b3527a35baa402f82fd65e))
* **copilot:** add Copilot coding agent support + CI fail issue workflow ([#740](https://github.com/JacobPEvans/nix-darwin/issues/740)) ([07de9b2](https://github.com/JacobPEvans/nix-darwin/commit/07de9b21400618fa1d2705e72f3ec98a2c447a59))
* create infrastructure-automation shell combining packer and terraform ([#459](https://github.com/JacobPEvans/nix-darwin/issues/459)) ([9f522f6](https://github.com/JacobPEvans/nix-darwin/commit/9f522f6ac4e12127176a3a4ff18b3c2065ed96fa))
* **cribl-edge:** declarative pack deployment ([#928](https://github.com/JacobPEvans/nix-darwin/issues/928)) ([6fb6ccc](https://github.com/JacobPEvans/nix-darwin/commit/6fb6cccf92ff7e205025ed36eeb1189be9a347d2))
* **darwin:** add clock settings, energy module, and UI customizations ([#429](https://github.com/JacobPEvans/nix-darwin/issues/429)) ([4d8636e](https://github.com/JacobPEvans/nix-darwin/commit/4d8636e36488019568e54ab257a377f53ac86126))
* **darwin:** add local whisper/voice/AI tooling ([#702](https://github.com/JacobPEvans/nix-darwin/issues/702)) ([30f1ebb](https://github.com/JacobPEvans/nix-darwin/commit/30f1ebbf6e463ba33735d8beb15670eedd35c737))
* **darwin:** add streamline-login module for updater disabling ([#931](https://github.com/JacobPEvans/nix-darwin/issues/931)) ([89b2a30](https://github.com/JacobPEvans/nix-darwin/commit/89b2a301d701ed3f81543ab6126f0743a44ca30b))
* **darwin:** add syslog forwarding to remote server ([#514](https://github.com/JacobPEvans/nix-darwin/issues/514)) ([3d46baa](https://github.com/JacobPEvans/nix-darwin/commit/3d46baa0e115437c67a6e887738fc7ad203c7b95))
* **deps:** implement comprehensive dependency monitoring system ([fb4c3dc](https://github.com/JacobPEvans/nix-darwin/commit/fb4c3dc833abbf1febaece88dd9c937f75f43047))
* disable auto-updaters for Nix-managed macOS apps ([#605](https://github.com/JacobPEvans/nix-darwin/issues/605)) ([26afe5e](https://github.com/JacobPEvans/nix-darwin/commit/26afe5e08861324512a703439e21a43921910f41))
* disable automatic triggers on Claude-executing workflows ([cbe315e](https://github.com/JacobPEvans/nix-darwin/commit/cbe315ebe544ba3e234cfdf04083cf1ac751a8a4))
* **dock:** add iPhone Mirroring and Microsoft Teams ([#787](https://github.com/JacobPEvans/nix-darwin/issues/787)) ([9c88430](https://github.com/JacobPEvans/nix-darwin/commit/9c8843051214575dfeb50e8f9accc5148a5c6b97))
* **dock:** add Microsoft Outlook to persistent Dock bar ([#693](https://github.com/JacobPEvans/nix-darwin/issues/693)) ([006dd94](https://github.com/JacobPEvans/nix-darwin/commit/006dd9417099dd135c1937453760873b604f01cd))
* enable full Claude Code OTEL telemetry ([#637](https://github.com/JacobPEvans/nix-darwin/issues/637)) ([4879940](https://github.com/JacobPEvans/nix-darwin/commit/48799405c3d8b7ef24974efd868637ed9c55f28c))
* enable PAL MCP with proper timeouts ([b314467](https://github.com/JacobPEvans/nix-darwin/commit/b314467abf19f2f87001bc6a15d1ab713fc31073))
* enable ralph-wiggum autonomous iteration plugin ([c143fab](https://github.com/JacobPEvans/nix-darwin/commit/c143fabfed7d3e9f76b5f028cfb17295696aceb0))
* extract claudebar package and add nix-update to flake workflow ([#811](https://github.com/JacobPEvans/nix-darwin/issues/811)) ([0992eb4](https://github.com/JacobPEvans/nix-darwin/commit/0992eb4d6085830701829cb3b5c92dabcaca1ba4))
* **flake-rebuild:** add issue investigation and plan generation prompt ([#895](https://github.com/JacobPEvans/nix-darwin/issues/895)) ([cac974f](https://github.com/JacobPEvans/nix-darwin/commit/cac974f55c2ad3070d2bf1d8d34e9bd5081575c3))
* **flake:** decouple nix-ai non-flake inputs via follows ([#857](https://github.com/JacobPEvans/nix-darwin/issues/857)) ([8fb3fdc](https://github.com/JacobPEvans/nix-darwin/commit/8fb3fdc90ccb8bad95eb68f7c8b28e40cce07df2))
* **gc:** add weekly LaunchDaemon to prune old profile generations ([#830](https://github.com/JacobPEvans/nix-darwin/issues/830)) ([d3cac5b](https://github.com/JacobPEvans/nix-darwin/commit/d3cac5b3e8c2e08fa5429a730e146503b48ce291))
* **homebrew:** add Microsoft 365 apps via Mac App Store ([#548](https://github.com/JacobPEvans/nix-darwin/issues/548)) ([de24eb6](https://github.com/JacobPEvans/nix-darwin/commit/de24eb60db1e20544449bbb3c50156382d76c5f2))
* **homebrew:** enable brew autoupdate with greedy upgrades every 30h ([#904](https://github.com/JacobPEvans/nix-darwin/issues/904)) ([ba3562d](https://github.com/JacobPEvans/nix-darwin/commit/ba3562d868a46811ad40a87464c76e00a2aaabb8))
* implement Claude Code hooks with notifications ([#520](https://github.com/JacobPEvans/nix-darwin/issues/520)) ([3f621d5](https://github.com/JacobPEvans/nix-darwin/commit/3f621d5aa051aefa805434f779d71ca16e2f2780))
* include claude-code in daily AI dependency updates ([#511](https://github.com/JacobPEvans/nix-darwin/issues/511)) ([1a8ebe0](https://github.com/JacobPEvans/nix-darwin/commit/1a8ebe0ab730b300bcc7632509186aae0b17dd42))
* install git-flow-next v1.0.0 via custom buildGoModule ([#642](https://github.com/JacobPEvans/nix-darwin/issues/642)) ([5650029](https://github.com/JacobPEvans/nix-darwin/commit/565002903da422f9c108d1353d70d385048376c0))
* **mcp:** Add Nix-native MCP servers with Docker and Context7 ([#494](https://github.com/JacobPEvans/nix-darwin/issues/494)) ([d11ff97](https://github.com/JacobPEvans/nix-darwin/commit/d11ff975f505c7b629792a5f24a640a84c3fac47))
* **mcp:** integrate PAL MCP and remove dead code ([#497](https://github.com/JacobPEvans/nix-darwin/issues/497)) ([90e4509](https://github.com/JacobPEvans/nix-darwin/commit/90e45090918db9ab98aad9362a8910c4e97bf82b))
* migrate flake.lock updates to Renovate nix manager ([#835](https://github.com/JacobPEvans/nix-darwin/issues/835)) ([92bbb71](https://github.com/JacobPEvans/nix-darwin/commit/92bbb71e8b960bab4acd0c6f5bda5d20604c7192))
* migrate granola-watcher to vault, remove from public repo ([#724](https://github.com/JacobPEvans/nix-darwin/issues/724)) ([70dad9c](https://github.com/JacobPEvans/nix-darwin/commit/70dad9c8b91ba6b516c80bb862d0da512598d8cf))
* **monitoring:** add NVMe disk I/O tracking to ws-monitor ([#944](https://github.com/JacobPEvans/nix-darwin/issues/944)) ([1cfe820](https://github.com/JacobPEvans/nix-darwin/commit/1cfe8205329d6b8ca72fe502cfe96d7ba05120c8))
* **monitoring:** add WindowServer performance monitor LaunchDaemon ([dbedd55](https://github.com/JacobPEvans/nix-darwin/commit/dbedd550da186f8ee3711d3c42647ea23dcb8922))
* move gemini-cli and antigravity to homebrew for Gemini 3.1 Pro support ([#685](https://github.com/JacobPEvans/nix-darwin/issues/685)) ([33a2486](https://github.com/JacobPEvans/nix-darwin/commit/33a2486baf9d634c55759e17a96740dac059f8cb))
* move module-eval check into lib/checks.nix ([#761](https://github.com/JacobPEvans/nix-darwin/issues/761)) ([3f80d47](https://github.com/JacobPEvans/nix-darwin/commit/3f80d476883387e8633a760643c9bff636885c37))
* **nix:** add trusted-users and devenv cachix binary cache ([#837](https://github.com/JacobPEvans/nix-darwin/issues/837)) ([cf31065](https://github.com/JacobPEvans/nix-darwin/commit/cf310650e36d3d773150fad0034b68bd4411e3a4))
* **nix:** migrate to official determinateNix module with automatic GC ([#792](https://github.com/JacobPEvans/nix-darwin/issues/792)) ([cdc21c6](https://github.com/JacobPEvans/nix-darwin/commit/cdc21c6ca047fc5cbe8fd4e101b286db5051e790))
* **ollama:** upgrade to unstable channel and clean up plans ([#573](https://github.com/JacobPEvans/nix-darwin/issues/573)) ([90a6709](https://github.com/JacobPEvans/nix-darwin/commit/90a67094e03edbc84d64b2d7844115455ed0a6fc))
* optimize CI workflow performance ([#519](https://github.com/JacobPEvans/nix-darwin/issues/519)) ([845e16b](https://github.com/JacobPEvans/nix-darwin/commit/845e16bc69dd9b33efb0cb0079bafa5a58b94f84))
* **packages:** enforce package hierarchy with validation hooks ([e8de606](https://github.com/JacobPEvans/nix-darwin/commit/e8de606b8afbaa07e2c64261fee050dab147e29b))
* **plugins:** add community plugins and multi-model integrations ([#503](https://github.com/JacobPEvans/nix-darwin/issues/503)) ([48d283f](https://github.com/JacobPEvans/nix-darwin/commit/48d283fe481e7b77c8ef006faf0ad40c9d248db9))
* release polish — MIT license, README rewrite, and doc cleanup ([#751](https://github.com/JacobPEvans/nix-darwin/issues/751)) ([2c9f33a](https://github.com/JacobPEvans/nix-darwin/commit/2c9f33af8b07ac17fcd026aa6b5d412bf2b5f6ef))
* remove nodejs and python310 from global packages ([#765](https://github.com/JacobPEvans/nix-darwin/issues/765)) ([024eab9](https://github.com/JacobPEvans/nix-darwin/commit/024eab9d743c68dbb832f6e8654f79d44c43c356))
* replace issue-triage with full issue pipeline ([#658](https://github.com/JacobPEvans/nix-darwin/issues/658)) ([c6d19f3](https://github.com/JacobPEvans/nix-darwin/commit/c6d19f3b338861d11e6e69149577ba33f9e55516))
* **settings:** add effortLevel option with medium default ([ce0d574](https://github.com/JacobPEvans/nix-darwin/commit/ce0d574d15a0681099032298f18ee6d08a6af319))
* **shells:** add PowerShell development shell ([#575](https://github.com/JacobPEvans/nix-darwin/issues/575)) ([ceede10](https://github.com/JacobPEvans/nix-darwin/commit/ceede1048bec4a6992db86784f10d762c546b1f3))
* **shells:** add sops/age, split ansible shell, fix direnv performance ([#595](https://github.com/JacobPEvans/nix-darwin/issues/595)) ([d9fc1d4](https://github.com/JacobPEvans/nix-darwin/commit/d9fc1d4d1524bee361a8db2ed2ac3ece845a32f4))
* switch to ai-workflows reusable workflows ([#634](https://github.com/JacobPEvans/nix-darwin/issues/634)) ([fa98038](https://github.com/JacobPEvans/nix-darwin/commit/fa980384fb69677c5ff5ebbdb13eb8310b67091b))
* **tmux:** add programs.tmux config with session persistence and mosh ([#618](https://github.com/JacobPEvans/nix-darwin/issues/618)) ([0e44a2e](https://github.com/JacobPEvans/nix-darwin/commit/0e44a2eaed4ab913b3d83de6d10f75b2f0bfbe0d))
* update ollama to latest nixpkgs, add claude-flow ([#543](https://github.com/JacobPEvans/nix-darwin/issues/543)) ([aada2a0](https://github.com/JacobPEvans/nix-darwin/commit/aada2a0594806a2a234c985e2c5cfd36d2517acd))
* update to claude-code-plugins v2.0.0 (8 consolidated plugins) ([#579](https://github.com/JacobPEvans/nix-darwin/issues/579)) ([0518c89](https://github.com/JacobPEvans/nix-darwin/commit/0518c89cd0d4c37e92e9c85ded161a2e2b8c348a))
* **vscode:** use activation script for writable settings ([#620](https://github.com/JacobPEvans/nix-darwin/issues/620)) ([5287eaf](https://github.com/JacobPEvans/nix-darwin/commit/5287eaf118bad42ebcbe77860529e413ffc9217f))
* **zsh:** add brew update on startup, fix background tasks, clean initContent ([#718](https://github.com/JacobPEvans/nix-darwin/issues/718)) ([dff5b8b](https://github.com/JacobPEvans/nix-darwin/commit/dff5b8bbc92256286f789a55d938229c00de6bde))


### Bug Fixes

* add 'with lib;' to options.nix to fix mkOption scope issue ([54dc6f4](https://github.com/JacobPEvans/nix-darwin/commit/54dc6f43a03cda0b82cbb2336e1904c5dc50703f))
* add bridge job for reusable workflow always() limitation ([#664](https://github.com/JacobPEvans/nix-darwin/issues/664)) ([3ba2cb0](https://github.com/JacobPEvans/nix-darwin/commit/3ba2cb0a45456cff3859a183b200be9b052c22ac))
* add cryptography to home-manager Python environments ([#565](https://github.com/JacobPEvans/nix-darwin/issues/565)) ([98eaed8](https://github.com/JacobPEvans/nix-darwin/commit/98eaed81d05aac8204703430f9dd0c6a31170e75))
* add explicit baseBranches to Renovate config ([#518](https://github.com/JacobPEvans/nix-darwin/issues/518)) ([98f8a5c](https://github.com/JacobPEvans/nix-darwin/commit/98f8a5c58b0a999bb2c9b7177890b14ed099df49))
* add explicit if condition on resolve job for skipped ancestors ([#667](https://github.com/JacobPEvans/nix-darwin/issues/667)) ([2680737](https://github.com/JacobPEvans/nix-darwin/commit/2680737c6efcddab5808dc47a90946586f53eeda))
* add explicit permissions to issue pipeline for cross-repo calls ([#663](https://github.com/JacobPEvans/nix-darwin/issues/663)) ([fc84108](https://github.com/JacobPEvans/nix-darwin/commit/fc84108f855660ff864231e62ccd5994f08df1a1))
* add missing lib. prefixes for types, lib functions ([343b6c2](https://github.com/JacobPEvans/nix-darwin/commit/343b6c2646ff36e9640c3ab99fade7c0e65bee3d))
* add release-please config for manifest mode ([84ed18b](https://github.com/JacobPEvans/nix-darwin/commit/84ed18b8c92816da83577e3441da52e47f4fd024))
* add schedule→dispatch workaround for OIDC bug (claude-code-action[#814](https://github.com/JacobPEvans/nix-darwin/issues/814)) ([#779](https://github.com/JacobPEvans/nix-darwin/issues/779)) ([f6a48d6](https://github.com/JacobPEvans/nix-darwin/commit/f6a48d6f9127a7001d364fc9c1d25b46cc8501bc))
* add security comment for FLAKE_INPUTS variable handling ([33f891a](https://github.com/JacobPEvans/nix-darwin/commit/33f891af508db7520d646151758ca67e3b8aa257))
* address all 12 remaining PR review thread issues ([a16e884](https://github.com/JacobPEvans/nix-darwin/commit/a16e8840730971bca43d75d6ce32ef7fd924e1e1))
* address PR review feedback ([399222e](https://github.com/JacobPEvans/nix-darwin/commit/399222eaee34e1e02f4d4621a9f4fee1548b9900))
* address PR review feedback on configuration patterns ([e00c1e0](https://github.com/JacobPEvans/nix-darwin/commit/e00c1e0dd8c18506869d14e77f26657ba7649719))
* address PR review feedback on validation scripts and documentation ([1230d22](https://github.com/JacobPEvans/nix-darwin/commit/1230d22ed2b5e7b5dfbc72cd1641011588818834))
* align ai-assistant-instructions command source path with discovery path ([c6a84a6](https://github.com/JacobPEvans/nix-darwin/commit/c6a84a62040a1ba977b4f806b901574a3bf963a0))
* **auto-claude:** add Slack channel validation and keychain error handling ([#454](https://github.com/JacobPEvans/nix-darwin/issues/454)) ([6f6f402](https://github.com/JacobPEvans/nix-darwin/commit/6f6f4027f43d242885ac5e5ff1326f5d98ee5a9a))
* **auto-claude:** add SSH agent setup and headless authentication ([#453](https://github.com/JacobPEvans/nix-darwin/issues/453)) ([ba266b9](https://github.com/JacobPEvans/nix-darwin/commit/ba266b988348063e7bdfafcb12a01c6b1e7505fa))
* bump ai-workflows to v0.2.6 and add id-token:write ([#674](https://github.com/JacobPEvans/nix-darwin/issues/674)) ([dfe23e9](https://github.com/JacobPEvans/nix-darwin/commit/dfe23e939720317d3da0fded19a5da22e3c0604a))
* bump all ai-workflows callers to v0.2.7 ([#677](https://github.com/JacobPEvans/nix-darwin/issues/677)) ([ae28776](https://github.com/JacobPEvans/nix-darwin/commit/ae287761908ff2a89fbd60406d26b2cee269e91b))
* bump all ai-workflows callers to v0.2.8 ([#681](https://github.com/JacobPEvans/nix-darwin/issues/681)) ([9db24ea](https://github.com/JacobPEvans/nix-darwin/commit/9db24ead24c3811a751024109a0162e6777edf35))
* bump all ai-workflows callers to v0.2.9 ([#682](https://github.com/JacobPEvans/nix-darwin/issues/682)) ([09406d9](https://github.com/JacobPEvans/nix-darwin/commit/09406d972359caf73aac0cceae75fe12f3ed98d0))
* bump homeManagerStateVersion to 25.11 ([#873](https://github.com/JacobPEvans/nix-darwin/issues/873)) ([12fd1ee](https://github.com/JacobPEvans/nix-darwin/commit/12fd1ee4c2dd9f69429c50a80986b6a152aedc83))
* bump issue resolver/triage callers to v0.2.5 ([#673](https://github.com/JacobPEvans/nix-darwin/issues/673)) ([588015f](https://github.com/JacobPEvans/nix-darwin/commit/588015f79092ff62772ce659b6a45efb93217bcf))
* bump issue-resolver callers to v0.2.4 ([#670](https://github.com/JacobPEvans/nix-darwin/issues/670)) ([b08c3a4](https://github.com/JacobPEvans/nix-darwin/commit/b08c3a4e3aee0cd6b83f91fe9e776c8d55ad30bc))
* bump stateVersion to 25.11 with drift assertion ([#877](https://github.com/JacobPEvans/nix-darwin/issues/877)) ([887a41a](https://github.com/JacobPEvans/nix-darwin/commit/887a41acd16da94220c9cfbb1b8bd5bae0ebf3fc))
* change issue_number input type from number to string ([#675](https://github.com/JacobPEvans/nix-darwin/issues/675)) ([64872a7](https://github.com/JacobPEvans/nix-darwin/commit/64872a7d87c6b993a3a868b0036f0e13154e59fb))
* **ci:** add dispatch pattern for post-merge workflows ([#701](https://github.com/JacobPEvans/nix-darwin/issues/701)) ([41b8ad7](https://github.com/JacobPEvans/nix-darwin/commit/41b8ad79fb4f762f60e85963d33ef5359a415a33))
* **ci:** add nix-home to AI_INPUTS allowlist for dispatch events ([#754](https://github.com/JacobPEvans/nix-darwin/issues/754)) ([172519b](https://github.com/JacobPEvans/nix-darwin/commit/172519bb3d8e5ae9455dff1660887fc061a51ead))
* **ci:** add pull-requests: write for release-please auto-approval ([#848](https://github.com/JacobPEvans/nix-darwin/issues/848)) ([b9cb5a8](https://github.com/JacobPEvans/nix-darwin/commit/b9cb5a83b6aca2f7536cfd5ead8837e57f25c7b4))
* **ci:** add pull-requests: write for release-please auto-approval ([#850](https://github.com/JacobPEvans/nix-darwin/issues/850)) ([b561b18](https://github.com/JacobPEvans/nix-darwin/commit/b561b18c56b06549fe10dd18a757db6e72b1174e))
* **ci:** migrate copilot-setup-steps to determinate-nix-action@v3 ([#842](https://github.com/JacobPEvans/nix-darwin/issues/842)) ([63d82ef](https://github.com/JacobPEvans/nix-darwin/commit/63d82efed576f6921a68abfb0aa70ccb0f366f2a))
* **ci:** prevent Merge Gate false failures from cancelled runs ([#590](https://github.com/JacobPEvans/nix-darwin/issues/590)) ([f937654](https://github.com/JacobPEvans/nix-darwin/commit/f937654047bfeb5f77afcdf048ccb3c42e45f8bb))
* **ci:** remove jacobpevans-cc-plugins from AI_INPUTS ([#784](https://github.com/JacobPEvans/nix-darwin/issues/784)) ([669c2d8](https://github.com/JacobPEvans/nix-darwin/commit/669c2d83453d4335d795d9f37d2c08b5f727e214))
* **ci:** replace actions/cache with magic-nix-cache-action for Nix store ([#810](https://github.com/JacobPEvans/nix-darwin/issues/810)) ([631162b](https://github.com/JacobPEvans/nix-darwin/commit/631162bbea80b4c465e3a40448936478f31333e6))
* **ci:** use GitHub App token for release-please to trigger CI Gate ([#828](https://github.com/JacobPEvans/nix-darwin/issues/828)) ([7013a0e](https://github.com/JacobPEvans/nix-darwin/commit/7013a0edfe4fb48552a6a9ba6c3629827de043e6))
* **claude:** add marketplace cache integrity verification ([#611](https://github.com/JacobPEvans/nix-darwin/issues/611)) ([92a8c6a](https://github.com/JacobPEvans/nix-darwin/commit/92a8c6afe4d3a19b5108039f32129df115b00ffd))
* **claude:** add validation, shellcheck, and modular architecture ([32a0235](https://github.com/JacobPEvans/nix-darwin/commit/32a023511ef4608ec07ff95899434d44318bec88))
* **claude:** make attribution a proper Nix option, remove hardcoded Co-Authored-By ([#711](https://github.com/JacobPEvans/nix-darwin/issues/711)) ([7e93854](https://github.com/JacobPEvans/nix-darwin/commit/7e93854f704853dd2e31727b9b46a7c46c654f7a))
* **claude:** remove invalid MultiEdit tool from permissions ([#474](https://github.com/JacobPEvans/nix-darwin/issues/474)) ([fdbc0fb](https://github.com/JacobPEvans/nix-darwin/commit/fdbc0fbfde1fd63234c9bbbedbfe317463e1842e))
* **claude:** resolve marketplace symlink permission errors on darwin-rebuild ([#698](https://github.com/JacobPEvans/nix-darwin/issues/698)) ([bc42a5f](https://github.com/JacobPEvans/nix-darwin/commit/bc42a5ff98efea8e13b6c9e6acf5da40e0d8dc93))
* **claude:** restore opusplan as default model ([#633](https://github.com/JacobPEvans/nix-darwin/issues/633)) ([bd172ca](https://github.com/JacobPEvans/nix-darwin/commit/bd172ca4113b61a44e15eb8269906481c043f573))
* **claude:** use recursive=true for marketplace dirs, remove cleanup scripts ([#688](https://github.com/JacobPEvans/nix-darwin/issues/688)) ([974c549](https://github.com/JacobPEvans/nix-darwin/commit/974c549800452470365dfa17a95820593903ae53))
* configure markdownlint MD013 line length to 160 characters ([#517](https://github.com/JacobPEvans/nix-darwin/issues/517)) ([82e31e4](https://github.com/JacobPEvans/nix-darwin/commit/82e31e4b6518bc0deca18c3496f582d4a9d02254))
* consolidate file-size config into .file-size.yml with shared defaults ([#889](https://github.com/JacobPEvans/nix-darwin/issues/889)) ([a141129](https://github.com/JacobPEvans/nix-darwin/commit/a14112941c77b33bab77abb00d72edce7c806f42))
* consolidate Renovate config and remove broken postUpgradeTasks ([#886](https://github.com/JacobPEvans/nix-darwin/issues/886)) ([d0fe728](https://github.com/JacobPEvans/nix-darwin/commit/d0fe728e278c3b5594e539b38ea35e1f4c327f0c))
* correct broken nix repo reference in Renovate troubleshooting docs ([#813](https://github.com/JacobPEvans/nix-darwin/issues/813)) ([e663882](https://github.com/JacobPEvans/nix-darwin/commit/e6638829affb6eb81e617b370c766d0ffe4c8b54))
* correct document-skills plugin reference ([#572](https://github.com/JacobPEvans/nix-darwin/issues/572)) ([fc2e934](https://github.com/JacobPEvans/nix-darwin/commit/fc2e93443e7ca3e7d79c6e4b04173d5390d2b923))
* correct plugin count from 13 to 12 in ANTHROPIC-ECOSYSTEM.md ([6696a24](https://github.com/JacobPEvans/nix-darwin/commit/6696a24918fd61a227059a4324b37d6b0533d107))
* **darwin:** remove Paw defaults write (sandboxed container app) ([#856](https://github.com/JacobPEvans/nix-darwin/issues/856)) ([3abb0fb](https://github.com/JacobPEvans/nix-darwin/commit/3abb0fbb58e4a855acc305446a8181d258c7fb05))
* **deps:** add Renovate annotation for ClaudeBar package ([#917](https://github.com/JacobPEvans/nix-darwin/issues/917)) ([b55018c](https://github.com/JacobPEvans/nix-darwin/commit/b55018c70ffab98830cf9523349067068e9ca2bd))
* **deps:** update all flake inputs and ClaudeBar to 0.4.57 ([#938](https://github.com/JacobPEvans/nix-darwin/issues/938)) ([b234826](https://github.com/JacobPEvans/nix-darwin/commit/b2348269769faa166dd7a194e0c2b2ff04c73f58))
* **deps:** update flake inputs and fix gh-aw hash mismatch ([#924](https://github.com/JacobPEvans/nix-darwin/issues/924)) ([a4559b5](https://github.com/JacobPEvans/nix-darwin/commit/a4559b57627f9415c165c5befc5b8b8796e42cb6))
* **deps:** update jacobpevans-cc-plugins to register pal-health plugin ([#906](https://github.com/JacobPEvans/nix-darwin/issues/906)) ([f8d4578](https://github.com/JacobPEvans/nix-darwin/commit/f8d4578d7f3c614b5f20aea634b28fe969f2cdde))
* disable hash pinning for trusted actions, use version tags ([#790](https://github.com/JacobPEvans/nix-darwin/issues/790)) ([94630a1](https://github.com/JacobPEvans/nix-darwin/commit/94630a1a1d838628d8d1f37c504152ef8ca009b5))
* drastically reduce Claude Code context token usage ([ec8899e](https://github.com/JacobPEvans/nix-darwin/commit/ec8899e845b6edf158265e7cc636ab110e63a9b7))
* exempt CHANGELOG.md from file size limit ([#887](https://github.com/JacobPEvans/nix-darwin/issues/887)) ([c071d53](https://github.com/JacobPEvans/nix-darwin/commit/c071d53cf3c35d7b8bce874bff2cc21e1ccb5a43))
* **flake-rebuild:** clarify command must always execute the rebuild ([#893](https://github.com/JacobPEvans/nix-darwin/issues/893)) ([c0c2960](https://github.com/JacobPEvans/nix-darwin/commit/c0c2960115222eb6522b6f8cd4f2737666d86ced))
* **flake-rebuild:** only skip PR creation when an open PR exists ([#898](https://github.com/JacobPEvans/nix-darwin/issues/898)) ([64c5af0](https://github.com/JacobPEvans/nix-darwin/commit/64c5af04ac76fe64b21305c843f20e1aff938f14))
* **gemini:** use activation script for writable settings ([#613](https://github.com/JacobPEvans/nix-darwin/issues/613)) ([b307d7f](https://github.com/JacobPEvans/nix-darwin/commit/b307d7f201cbdb9e4197e2c4be68b766249f78d0))
* gitignore plugin-generated .claude/skills/ directory ([#910](https://github.com/JacobPEvans/nix-darwin/issues/910)) ([739070f](https://github.com/JacobPEvans/nix-darwin/commit/739070f373bfe86fb635013b86162662d16aeb05))
* **git:** run pre-push hook on changed files only, handle deletions and use read -r ([9c16611](https://github.com/JacobPEvans/nix-darwin/commit/9c16611dafaf6da12aa7c6f966f1cba6a1379675))
* **git:** use merge-base with remote default branch for new-branch pre-push ([49b2fe2](https://github.com/JacobPEvans/nix-darwin/commit/49b2fe2e4ce1dc186acfb8c45655e9c13e3f0782))
* **homebrew:** add greedy flag to microsoft-teams cask ([#853](https://github.com/JacobPEvans/nix-darwin/issues/853)) ([3191d05](https://github.com/JacobPEvans/nix-darwin/commit/3191d0535fbf9e61ae7e3ecdb4b82bbfd6716b7d))
* **homebrew:** brew autoupdate LaunchAgent never created on darwin-rebuild ([9256aa3](https://github.com/JacobPEvans/nix-darwin/commit/9256aa3a72adfa4a7b22e278ba86afa69ffc37ee))
* **homebrew:** use /usr/bin/stat to avoid GNU stat in Nix PATH ([#916](https://github.com/JacobPEvans/nix-darwin/issues/916)) ([9ebbce5](https://github.com/JacobPEvans/nix-darwin/commit/9ebbce555196460c99bbc935d322810924d62ec9))
* **mcp:** reorganize external MCP plugins and enable Context7 ([#491](https://github.com/JacobPEvans/nix-darwin/issues/491)) ([34c74d3](https://github.com/JacobPEvans/nix-darwin/commit/34c74d359367d6701d5a78c2ef46e16f4c1429ec))
* **mcp:** reorganize MCP plugins and add Context7 server ([#487](https://github.com/JacobPEvans/nix-darwin/issues/487)) ([e41ac04](https://github.com/JacobPEvans/nix-darwin/commit/e41ac046d35f452ac09739ae004e917607e3dea2))
* migrate Bash permissions to space format and expand command tools ([#846](https://github.com/JacobPEvans/nix-darwin/issues/846)) ([48d7e81](https://github.com/JacobPEvans/nix-darwin/commit/48d7e811436fc42b458e4411011e41b23b179847))
* **monitoring:** use absolute paths and fix log dir permissions ([baaa6e0](https://github.com/JacobPEvans/nix-darwin/commit/baaa6e0cd5f8d8720d0b54e2f11aa7396d9b4413))
* move Postman from nixpkgs to Homebrew cask ([#809](https://github.com/JacobPEvans/nix-darwin/issues/809)) ([35b28f9](https://github.com/JacobPEvans/nix-darwin/commit/35b28f90238f03a0f98894294393787a5c6d42b6))
* **nix:** use list type for determinateNix.customSettings ([#840](https://github.com/JacobPEvans/nix-darwin/issues/840)) ([29ec20e](https://github.com/JacobPEvans/nix-darwin/commit/29ec20e257dfb95c2b7ebd8ae1ee00472c34b96e))
* **permissions:** support MCP tool permissions in pipeline ([4767fe4](https://github.com/JacobPEvans/nix-darwin/commit/4767fe436a9d7a3e460165388e48f5e602c528dc))
* **plugins:** exclude schemas dir from plugin auto-discovery ([6390149](https://github.com/JacobPEvans/nix-darwin/commit/63901499239aeebf22d908af77e23ab4989bdcce))
* **plugins:** improve activation script diff error handling ([#470](https://github.com/JacobPEvans/nix-darwin/issues/470)) ([9aac29b](https://github.com/JacobPEvans/nix-darwin/commit/9aac29b19faa5a8a358ae1533ccd479b805a7f9f))
* **plugins:** remove non-existent clerk-auth and add missing official plugins ([#587](https://github.com/JacobPEvans/nix-darwin/issues/587)) ([b14f443](https://github.com/JacobPEvans/nix-darwin/commit/b14f443ece5fc6694a4410f31a25ba76605d9eef))
* **pre-commit:** remove darwin-rebuild from pre-push hook ([#709](https://github.com/JacobPEvans/nix-darwin/issues/709)) ([3bfbb19](https://github.com/JacobPEvans/nix-darwin/commit/3bfbb19ddbe5fb13630ae43adbcdb51762b32750))
* prevent bot review comments from cancelling Claude review ([#630](https://github.com/JacobPEvans/nix-darwin/issues/630)) ([a9975c3](https://github.com/JacobPEvans/nix-darwin/commit/a9975c341c6bf7d8be1dbe6af009b35cb6dc0c76))
* prevent Claude from guessing incorrect skill namespaces ([#504](https://github.com/JacobPEvans/nix-darwin/issues/504)) ([7c12012](https://github.com/JacobPEvans/nix-darwin/commit/7c12012805d38f908da9e6b4a8e38f2d84f8db7d))
* remove blanket auto-merge workflow ([#789](https://github.com/JacobPEvans/nix-darwin/issues/789)) ([618eca9](https://github.com/JacobPEvans/nix-darwin/commit/618eca9f4f85adea87e0cffd570c42213227fee8))
* remove deprecated SlashCommand permission ([#646](https://github.com/JacobPEvans/nix-darwin/issues/646)) ([9a78cbc](https://github.com/JacobPEvans/nix-darwin/commit/9a78cbc73348ee3aba3fcffcb1a15ab4e8da0979))
* remove mcpServers from settings.json (wrong location) ([ceb4798](https://github.com/JacobPEvans/nix-darwin/commit/ceb4798eea8c50414352d03da8f14361b93e26aa))
* remove nixpkgs-unstable overlay ([#879](https://github.com/JacobPEvans/nix-darwin/issues/879)) ([a870f35](https://github.com/JacobPEvans/nix-darwin/commit/a870f356a4d6f6a55043c2f021593151647024a4))
* remove Ollama from system packages and disable volume ([#875](https://github.com/JacobPEvans/nix-darwin/issues/875)) ([58ef9f9](https://github.com/JacobPEvans/nix-darwin/commit/58ef9f9b693ab7193e7066ec1bbe5f420837ae47))
* remove unused lambda parameters flagged by deadnix ([#808](https://github.com/JacobPEvans/nix-darwin/issues/808)) ([862c660](https://github.com/JacobPEvans/nix-darwin/commit/862c66092e4f62680425866dcb979b5578e99f58))
* remove unused OpenHands AI workflow ([#951](https://github.com/JacobPEvans/nix-darwin/issues/951)) ([e612245](https://github.com/JacobPEvans/nix-darwin/commit/e612245cff36f04d2c64bc56c367177210fd29d1))
* rename caller job keys to avoid reusable workflow name collision ([#671](https://github.com/JacobPEvans/nix-darwin/issues/671)) ([e23660a](https://github.com/JacobPEvans/nix-darwin/commit/e23660ab562ccfd32ca45aa9b72049c9af387833))
* rename GH_APP_ID secret to GH_ACTION_JACOBPEVANS_APP_ID ([#814](https://github.com/JacobPEvans/nix-darwin/issues/814)) ([8be189b](https://github.com/JacobPEvans/nix-darwin/commit/8be189b02f82642a6f4f00612fab985411364d27))
* **renovate:** add shared preset, remove global automerge, fix deprecated matchers ([#796](https://github.com/JacobPEvans/nix-darwin/issues/796)) ([315907d](https://github.com/JacobPEvans/nix-darwin/commit/315907d3ec7a2d9a51902c29f9c92d0a8596b574))
* **renovate:** deduplicate config and guard git-refs major updates ([#797](https://github.com/JacobPEvans/nix-darwin/issues/797)) ([e5d6251](https://github.com/JacobPEvans/nix-darwin/commit/e5d625123a1bf198b8557daf30be7aa834a52dee))
* **renovate:** remove duplicate automerge from AI tools group ([#937](https://github.com/JacobPEvans/nix-darwin/issues/937)) ([85c5513](https://github.com/JacobPEvans/nix-darwin/commit/85c5513d933426806513b60a99c8b8fc998d0b78))
* **renovate:** trust ai-tools group for all update types ([#902](https://github.com/JacobPEvans/nix-darwin/issues/902)) ([2dc7a39](https://github.com/JacobPEvans/nix-darwin/commit/2dc7a39a32bdae29f78c57db09d7d7047d8a68f7))
* reorder dock apps, document Quotio install, and trampoline permissions ([#521](https://github.com/JacobPEvans/nix-darwin/issues/521)) ([b1bc3f7](https://github.com/JacobPEvans/nix-darwin/commit/b1bc3f7b2cbbdec8d12592a31e8d115a82a385d2)), closes [#461](https://github.com/JacobPEvans/nix-darwin/issues/461) [#438](https://github.com/JacobPEvans/nix-darwin/issues/438) [#424](https://github.com/JacobPEvans/nix-darwin/issues/424)
* resolve all 6 review thread issues from copilot-pull-request-reviewer ([a900ff9](https://github.com/JacobPEvans/nix-darwin/commit/a900ff961d87883163d7c02f053a13e71e4fbd4a))
* resolve all review thread issues ([c41057b](https://github.com/JacobPEvans/nix-darwin/commit/c41057baa8a9994cd63a5fe4044343bb0fd41d45))
* resolve all review thread issues ([3f8354d](https://github.com/JacobPEvans/nix-darwin/commit/3f8354d969c19e395fdd17db76f105dc18d38a6c))
* resolve build warnings and resolve agent symlink conflict ([#457](https://github.com/JacobPEvans/nix-darwin/issues/457)) ([b55b777](https://github.com/JacobPEvans/nix-darwin/commit/b55b777a41f19fd20de1fa15a6f6ffc6d8ecd76b))
* resolve Claude Code + Nix configuration issues ([1f547af](https://github.com/JacobPEvans/nix-darwin/commit/1f547afb9b8c8889edc7fef59efdde2370a97994))
* resolve darwin-rebuild warnings for options.json and lsregister ([#621](https://github.com/JacobPEvans/nix-darwin/issues/621)) ([5d431e4](https://github.com/JacobPEvans/nix-darwin/commit/5d431e496376c1e2acb527d886c877fe70dffcdb))
* resolve GitHub code scanning alerts ([#499](https://github.com/JacobPEvans/nix-darwin/issues/499)) ([98594e8](https://github.com/JacobPEvans/nix-darwin/commit/98594e8722d3c028de63d258692c8a1f0663543b))
* resolve home-manager rebuild warnings and orphan symlinks ([a67bc46](https://github.com/JacobPEvans/nix-darwin/commit/a67bc4633e2cb696319a6af37b31d89a632a812d))
* restore plugins, upgrade claude-code, fix marketplace naming ([3d5643e](https://github.com/JacobPEvans/nix-darwin/commit/3d5643e83a874efec5101ea69e5a6fbb6d385bd4))
* robustly handle filenames with spaces/newlines in symlink cleanup ([a2a5696](https://github.com/JacobPEvans/nix-darwin/commit/a2a56965180531acd9180f7ad22394cccf965086))
* scope gitignore to only exclude retrospecting reports, not all skills ([#912](https://github.com/JacobPEvans/nix-darwin/issues/912)) ([a055c94](https://github.com/JacobPEvans/nix-darwin/commit/a055c9488f025cc0db2f82dce1a04c8890c786ff))
* **security:** add 3-day stabilization to vulnerability alert PRs ([#922](https://github.com/JacobPEvans/nix-darwin/issues/922)) ([ebf5647](https://github.com/JacobPEvans/nix-darwin/commit/ebf56475bdf8202a97eab108a72677659b5825ed))
* **security:** harden CI gate for flake.lock changes on deps-only PRs ([#925](https://github.com/JacobPEvans/nix-darwin/issues/925)) ([0b1d458](https://github.com/JacobPEvans/nix-darwin/commit/0b1d458df2bf07cab32229bec761d8ea781668ef))
* source AI CLI tools from unstable overlay for version currency ([#619](https://github.com/JacobPEvans/nix-darwin/issues/619)) ([ca186fb](https://github.com/JacobPEvans/nix-darwin/commit/ca186fbb8d69782fc34952b1e2530e1686f5b009))
* split issue pipeline and fix permissions/version on all callers ([#669](https://github.com/JacobPEvans/nix-darwin/issues/669)) ([fd1add1](https://github.com/JacobPEvans/nix-darwin/commit/fd1add1cd2c65150501ba896bd40cc89bb2a92a0))
* split resolve into auto and manual paths ([#668](https://github.com/JacobPEvans/nix-darwin/issues/668)) ([8c7f690](https://github.com/JacobPEvans/nix-darwin/commit/8c7f690a65a50bd8e1d0fa1b482d30058407a2dd))
* standardize comment formatting for consistency ([f5be920](https://github.com/JacobPEvans/nix-darwin/commit/f5be9203c878da564d0827178941f552b8d85d2b))
* Standardize logging format and improve darwin-rebuild diagnostics ([#475](https://github.com/JacobPEvans/nix-darwin/issues/475)) ([ccd96da](https://github.com/JacobPEvans/nix-darwin/commit/ccd96da8ea8af10d0c811001ede5f7725b371caf))
* **startup:** consolidate startup-tuning into streamline-login ([#935](https://github.com/JacobPEvans/nix-darwin/issues/935)) ([644c909](https://github.com/JacobPEvans/nix-darwin/commit/644c9095cb261f53fc087072c8bbfa3b32950d6f))
* **startup:** disable unnecessary Apple LaunchAgents that degrade boot performance ([#930](https://github.com/JacobPEvans/nix-darwin/issues/930)) ([1e833c8](https://github.com/JacobPEvans/nix-darwin/commit/1e833c8d2c6989680a073d32185d12f4af229c9e))
* switch to stable 25.11 (nixpkgs, darwin, home-manager) ([473432a](https://github.com/JacobPEvans/nix-darwin/commit/473432a494536e6bcae717f9bbb98e3973b0d180))
* sync release-please permissions and VERSION ([ba0eb02](https://github.com/JacobPEvans/nix-darwin/commit/ba0eb02830635cbc36ab81f4ee1c15c556e96dd0))
* **terraform-shell:** remove broken checkov and terrascan packages ([#706](https://github.com/JacobPEvans/nix-darwin/issues/706)) ([c275e70](https://github.com/JacobPEvans/nix-darwin/commit/c275e70bf1619d76b3e9ada1747d5adea2447fec))
* update CLAUDE.md to reference three companion repos (quartet) ([#881](https://github.com/JacobPEvans/nix-darwin/issues/881)) ([82ca482](https://github.com/JacobPEvans/nix-darwin/commit/82ca482825280f53b03c007bff894d3260695076))
* update ClaudeBar to v0.4.43 ([#818](https://github.com/JacobPEvans/nix-darwin/issues/818)) ([35b6dfa](https://github.com/JacobPEvans/nix-darwin/commit/35b6dfad18fcfa17e3d3fd5dec50d5c16fc616d7))
* update dispatch pipeline with ai:ready trigger and daily limit ([#759](https://github.com/JacobPEvans/nix-darwin/issues/759)) ([f564201](https://github.com/JacobPEvans/nix-darwin/commit/f564201e328c7bfd7a314ffed59b11b35a9527a8))
* update flake inputs after nix-ai and nix-home cleanup PRs ([#882](https://github.com/JacobPEvans/nix-darwin/issues/882)) ([0a05872](https://github.com/JacobPEvans/nix-darwin/commit/0a058724ace7d6f192702aa90d99c26bb1f44832))
* update issue pipeline to ai-workflows v0.2.1 ([#665](https://github.com/JacobPEvans/nix-darwin/issues/665)) ([ad8fbab](https://github.com/JacobPEvans/nix-darwin/commit/ad8fbab5d25091c4c951e22e4c96a125de23a8ba))
* update issue pipeline to ai-workflows v0.2.2 ([#666](https://github.com/JacobPEvans/nix-darwin/issues/666)) ([98b2c75](https://github.com/JacobPEvans/nix-darwin/commit/98b2c7541330451f5e6b7c2612eda5a1187a56b6))
* update nix-ai (MLX port 11435→11436, port conflict) ([#869](https://github.com/JacobPEvans/nix-darwin/issues/869)) ([d399876](https://github.com/JacobPEvans/nix-darwin/commit/d39987629c25af1c7f02425e3aa56d13b6564f75))
* update nix-ai flake input to latest ([#860](https://github.com/JacobPEvans/nix-darwin/issues/860)) ([10c6032](https://github.com/JacobPEvans/nix-darwin/commit/10c6032b08cfa47d4dd3f926e173f2df38013b65))
* update nix-ai input (v0.2.6 CLI flags + checks split) ([#885](https://github.com/JacobPEvans/nix-darwin/issues/885)) ([7e19da6](https://github.com/JacobPEvans/nix-darwin/commit/7e19da6d768fe680957c5ba15940a82e98c0081a))
* use array expansion for safe flake inputs handling ([e414ede](https://github.com/JacobPEvans/nix-darwin/commit/e414edee4be9bb94b63bf7c2d2f54956e8415e6f))
* use brew info instead of brew search for exact matching ([8a79e04](https://github.com/JacobPEvans/nix-darwin/commit/8a79e04627ceac1aefe31fb4bad6856dc9fbd969))
* use full path /opt/homebrew/bin/brew, fall back to stat -f '%Su' /dev/console for user detection. ([9256aa3](https://github.com/JacobPEvans/nix-darwin/commit/9256aa3a72adfa4a7b22e278ba86afa69ffc37ee))
* use word boundary matching for brew search verification ([ffd4fc2](https://github.com/JacobPEvans/nix-darwin/commit/ffd4fc235479417704b0ca926d1180620c875ef2))
* **validation:** address PR review feedback on regex and for loops ([d21f9ee](https://github.com/JacobPEvans/nix-darwin/commit/d21f9eed670a736fe973762dbd4fc75bfe488494))
* wire up ask permissions in Claude Code config ([#483](https://github.com/JacobPEvans/nix-darwin/issues/483)) ([b2aecb0](https://github.com/JacobPEvans/nix-darwin/commit/b2aecb0d1ea393405a2a09977c0bad5628bb94fa))


### Performance

* **ci:** optimize Nix build CI from 11m 40s to 9m 35s per PR ([#552](https://github.com/JacobPEvans/nix-darwin/issues/552)) ([e962d8d](https://github.com/JacobPEvans/nix-darwin/commit/e962d8dd84244cccaa789d200e989d655a3f8785))

## [1.20.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.20.1...v1.20.2) (2026-04-02)


### Bug Fixes

* remove unused OpenHands AI workflow ([#951](https://github.com/JacobPEvans/nix-darwin/issues/951)) ([e612245](https://github.com/JacobPEvans/nix-darwin/commit/e612245cff36f04d2c64bc56c367177210fd29d1))

## [1.20.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.20.0...v1.20.1) (2026-04-01)


### Bug Fixes

* **renovate:** remove duplicate automerge from AI tools group ([#937](https://github.com/JacobPEvans/nix-darwin/issues/937)) ([85c5513](https://github.com/JacobPEvans/nix-darwin/commit/85c5513d933426806513b60a99c8b8fc998d0b78))

## [1.20.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.19.1...v1.20.0) (2026-04-01)


### Features

* **monitoring:** add NVMe disk I/O tracking to ws-monitor ([#944](https://github.com/JacobPEvans/nix-darwin/issues/944)) ([1cfe820](https://github.com/JacobPEvans/nix-darwin/commit/1cfe8205329d6b8ca72fe502cfe96d7ba05120c8))

## [1.19.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.19.0...v1.19.1) (2026-03-31)


### Bug Fixes

* **monitoring:** use absolute paths and fix log dir permissions ([baaa6e0](https://github.com/JacobPEvans/nix-darwin/commit/baaa6e0cd5f8d8720d0b54e2f11aa7396d9b4413))

## [1.19.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.18.2...v1.19.0) (2026-03-31)


### Features

* **monitoring:** add WindowServer performance monitor LaunchDaemon ([dbedd55](https://github.com/JacobPEvans/nix-darwin/commit/dbedd550da186f8ee3711d3c42647ea23dcb8922))

## [1.18.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.18.1...v1.18.2) (2026-03-31)


### Bug Fixes

* **deps:** update all flake inputs and ClaudeBar to 0.4.57 ([#938](https://github.com/JacobPEvans/nix-darwin/issues/938)) ([b234826](https://github.com/JacobPEvans/nix-darwin/commit/b2348269769faa166dd7a194e0c2b2ff04c73f58))

## [1.18.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.18.0...v1.18.1) (2026-03-31)


### Bug Fixes

* **startup:** consolidate startup-tuning into streamline-login ([#935](https://github.com/JacobPEvans/nix-darwin/issues/935)) ([644c909](https://github.com/JacobPEvans/nix-darwin/commit/644c9095cb261f53fc087072c8bbfa3b32950d6f))

## [1.18.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.17.0...v1.18.0) (2026-03-30)


### Features

* **cribl-edge:** declarative pack deployment ([#928](https://github.com/JacobPEvans/nix-darwin/issues/928)) ([6fb6ccc](https://github.com/JacobPEvans/nix-darwin/commit/6fb6cccf92ff7e205025ed36eeb1189be9a347d2))

## [1.17.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.16.10...v1.17.0) (2026-03-30)


### Features

* **darwin:** add streamline-login module for updater disabling ([#931](https://github.com/JacobPEvans/nix-darwin/issues/931)) ([89b2a30](https://github.com/JacobPEvans/nix-darwin/commit/89b2a301d701ed3f81543ab6126f0743a44ca30b))

## [1.16.10](https://github.com/JacobPEvans/nix-darwin/compare/v1.16.9...v1.16.10) (2026-03-30)


### Bug Fixes

* **startup:** disable unnecessary Apple LaunchAgents that degrade boot performance ([#930](https://github.com/JacobPEvans/nix-darwin/issues/930)) ([1e833c8](https://github.com/JacobPEvans/nix-darwin/commit/1e833c8d2c6989680a073d32185d12f4af229c9e))

## [1.16.9](https://github.com/JacobPEvans/nix-darwin/compare/v1.16.8...v1.16.9) (2026-03-26)


### Bug Fixes

* **deps:** update flake inputs and fix gh-aw hash mismatch ([#924](https://github.com/JacobPEvans/nix-darwin/issues/924)) ([a4559b5](https://github.com/JacobPEvans/nix-darwin/commit/a4559b57627f9415c165c5befc5b8b8796e42cb6))

## [1.16.8](https://github.com/JacobPEvans/nix-darwin/compare/v1.16.7...v1.16.8) (2026-03-26)


### Bug Fixes

* **security:** harden CI gate for flake.lock changes on deps-only PRs ([#925](https://github.com/JacobPEvans/nix-darwin/issues/925)) ([0b1d458](https://github.com/JacobPEvans/nix-darwin/commit/0b1d458df2bf07cab32229bec761d8ea781668ef))

## [1.16.7](https://github.com/JacobPEvans/nix-darwin/compare/v1.16.6...v1.16.7) (2026-03-25)


### Bug Fixes

* **security:** add 3-day stabilization to vulnerability alert PRs ([#922](https://github.com/JacobPEvans/nix-darwin/issues/922)) ([ebf5647](https://github.com/JacobPEvans/nix-darwin/commit/ebf56475bdf8202a97eab108a72677659b5825ed))

## [1.16.6](https://github.com/JacobPEvans/nix-darwin/compare/v1.16.5...v1.16.6) (2026-03-24)


### Bug Fixes

* **homebrew:** use /usr/bin/stat to avoid GNU stat in Nix PATH ([#916](https://github.com/JacobPEvans/nix-darwin/issues/916)) ([9ebbce5](https://github.com/JacobPEvans/nix-darwin/commit/9ebbce555196460c99bbc935d322810924d62ec9))

## [1.16.5](https://github.com/JacobPEvans/nix-darwin/compare/v1.16.4...v1.16.5) (2026-03-24)


### Bug Fixes

* **deps:** add Renovate annotation for ClaudeBar package ([#917](https://github.com/JacobPEvans/nix-darwin/issues/917)) ([b55018c](https://github.com/JacobPEvans/nix-darwin/commit/b55018c70ffab98830cf9523349067068e9ca2bd))

## [1.16.4](https://github.com/JacobPEvans/nix-darwin/compare/v1.16.3...v1.16.4) (2026-03-24)


### Bug Fixes

* **homebrew:** brew autoupdate LaunchAgent never created on darwin-rebuild ([9256aa3](https://github.com/JacobPEvans/nix-darwin/commit/9256aa3a72adfa4a7b22e278ba86afa69ffc37ee))
* use full path /opt/homebrew/bin/brew, fall back to stat -f '%Su' /dev/console for user detection. ([9256aa3](https://github.com/JacobPEvans/nix-darwin/commit/9256aa3a72adfa4a7b22e278ba86afa69ffc37ee))

## [1.16.3](https://github.com/JacobPEvans/nix-darwin/compare/v1.16.2...v1.16.3) (2026-03-24)


### Bug Fixes

* scope gitignore to only exclude retrospecting reports, not all skills ([#912](https://github.com/JacobPEvans/nix-darwin/issues/912)) ([a055c94](https://github.com/JacobPEvans/nix-darwin/commit/a055c9488f025cc0db2f82dce1a04c8890c786ff))

## [1.16.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.16.1...v1.16.2) (2026-03-24)


### Bug Fixes

* gitignore plugin-generated .claude/skills/ directory ([#910](https://github.com/JacobPEvans/nix-darwin/issues/910)) ([739070f](https://github.com/JacobPEvans/nix-darwin/commit/739070f373bfe86fb635013b86162662d16aeb05))

## [1.16.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.16.0...v1.16.1) (2026-03-23)


### Bug Fixes

* **deps:** update jacobpevans-cc-plugins to register pal-health plugin ([#906](https://github.com/JacobPEvans/nix-darwin/issues/906)) ([f8d4578](https://github.com/JacobPEvans/nix-darwin/commit/f8d4578d7f3c614b5f20aea634b28fe969f2cdde))

## [1.16.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.15.1...v1.16.0) (2026-03-23)


### Features

* **homebrew:** enable brew autoupdate with greedy upgrades every 30h ([#904](https://github.com/JacobPEvans/nix-darwin/issues/904)) ([ba3562d](https://github.com/JacobPEvans/nix-darwin/commit/ba3562d868a46811ad40a87464c76e00a2aaabb8))

## [1.15.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.15.0...v1.15.1) (2026-03-23)


### Bug Fixes

* **renovate:** trust ai-tools group for all update types ([#902](https://github.com/JacobPEvans/nix-darwin/issues/902)) ([2dc7a39](https://github.com/JacobPEvans/nix-darwin/commit/2dc7a39a32bdae29f78c57db09d7d7047d8a68f7))

## [1.15.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.14.1...v1.15.0) (2026-03-23)


### Features

* add ansible Python package set with paramiko and jsondiff ([#531](https://github.com/JacobPEvans/nix-darwin/issues/531)) ([454d393](https://github.com/JacobPEvans/nix-darwin/commit/454d393e23f3eeaa96cd556b0d434324d2b7a65a))
* add APFS volume quota support and AI model volumes ([#832](https://github.com/JacobPEvans/nix-darwin/issues/832)) ([4d0aea3](https://github.com/JacobPEvans/nix-darwin/commit/4d0aea3b6cd6bddc15fc52ae1d9095a3c198f36f))
* add CI auto-fix workflow and enable Claude review ([#624](https://github.com/JacobPEvans/nix-darwin/issues/624)) ([e7645f2](https://github.com/JacobPEvans/nix-darwin/commit/e7645f25d3b35cca9b876f23fc239875d7415ba3))
* add Cribl Edge nix-darwin module ([#871](https://github.com/JacobPEvans/nix-darwin/issues/871)) ([3d1758b](https://github.com/JacobPEvans/nix-darwin/commit/3d1758b4f0dc683032dcde0559f4fa9c4f796726))
* add Cribl MCP server via Nix-managed SSE transport ([#728](https://github.com/JacobPEvans/nix-darwin/issues/728)) ([89c9544](https://github.com/JacobPEvans/nix-darwin/commit/89c9544d4e1c2788f69ac9b4270bd5510cb0415e))
* add cryptography to system Python environment ([#563](https://github.com/JacobPEvans/nix-darwin/issues/563)) ([2beeeb1](https://github.com/JacobPEvans/nix-darwin/commit/2beeeb1d4ea1c71fad42795eb11ee33bd4e1d610))
* add daily repo health audit agentic workflow ([#822](https://github.com/JacobPEvans/nix-darwin/issues/822)) ([974b393](https://github.com/JacobPEvans/nix-darwin/commit/974b393379a2409cd1c431d55154904a5d25fbb2))
* add Docker daemon log rotation and builder GC config ([#803](https://github.com/JacobPEvans/nix-darwin/issues/803)) ([26e5ca0](https://github.com/JacobPEvans/nix-darwin/commit/26e5ca07dc53c1b3b1c2005010fe0cc5892e0e0f))
* add doppler-mcp wrapper for MCP server secret injection ([#732](https://github.com/JacobPEvans/nix-darwin/issues/732)) ([42de771](https://github.com/JacobPEvans/nix-darwin/commit/42de771a190036e76dacf5c769ba3811670219fc))
* add event-based cleanup for orphaned MCP server processes ([#652](https://github.com/JacobPEvans/nix-darwin/issues/652)) ([f6157f8](https://github.com/JacobPEvans/nix-darwin/commit/f6157f8670b6db46787070df2e39e99885706621))
* add ffmpeg media encoding tool ([#534](https://github.com/JacobPEvans/nix-darwin/issues/534)) ([309ff05](https://github.com/JacobPEvans/nix-darwin/commit/309ff05228781c8968defd6b4ed662837f5d3ce0))
* add final PR review workflow ([#626](https://github.com/JacobPEvans/nix-darwin/issues/626)) ([d6d5db8](https://github.com/JacobPEvans/nix-darwin/commit/d6d5db81750ebef2396cd5042c1682e86a52de21))
* add gh-aw agentic workflows ([#766](https://github.com/JacobPEvans/nix-darwin/issues/766)) ([8489738](https://github.com/JacobPEvans/nix-darwin/commit/8489738fb4333401fe79a0c41edfd4fc4e8e4072))
* add gh-aw CLI extension via Home Manager ([#597](https://github.com/JacobPEvans/nix-darwin/issues/597)) ([6e94831](https://github.com/JacobPEvans/nix-darwin/commit/6e94831d57dd9afedfe2f23e3929419f897e9cf2))
* add git-bug as universally available system tool ([#678](https://github.com/JacobPEvans/nix-darwin/issues/678)) ([9258edf](https://github.com/JacobPEvans/nix-darwin/commit/9258edfb602b81216759c4f6c4f2ea90d1e7fd68))
* add granola-watcher LaunchAgent for auto-migration ([#629](https://github.com/JacobPEvans/nix-darwin/issues/629)) ([58f9b2f](https://github.com/JacobPEvans/nix-darwin/commit/58f9b2f367f9c43f24d36db9418e5a140289339e))
* add HF_TOKEN to macOS Keychain exports for HuggingFace MCP ([#827](https://github.com/JacobPEvans/nix-darwin/issues/827)) ([9fa5d56](https://github.com/JacobPEvans/nix-darwin/commit/9fa5d56b782f7f802da2a6d8ee69349dc91a4fe5))
* add kubernetes dev shell with validation tooling ([#640](https://github.com/JacobPEvans/nix-darwin/issues/640)) ([c69caff](https://github.com/JacobPEvans/nix-darwin/commit/c69caff29654e896cf11c271842054f5ee9b64c7))
* add LM Studio and update nix-ai/nix-home inputs ([4e6c828](https://github.com/JacobPEvans/nix-darwin/commit/4e6c82866afd6124486c70333a4f0c1c4fcde2be))
* add maestro auto run integration for automated issue resolution ([#513](https://github.com/JacobPEvans/nix-darwin/issues/513)) ([af24e42](https://github.com/JacobPEvans/nix-darwin/commit/af24e427b00c31729010bcb18d4a1cee64523717))
* add MCP server packages and fix CLI registration docs ([108d8ca](https://github.com/JacobPEvans/nix-darwin/commit/108d8ca52a572b54900bbfe2d3adec8bbff15918))
* add Microsoft Teams cask and migrate OrbStack to Homebrew for TCC stability ([#653](https://github.com/JacobPEvans/nix-darwin/issues/653)) ([be2be35](https://github.com/JacobPEvans/nix-darwin/commit/be2be35dee540305d93456fe48db553ca712450a))
* add nixpkgs-unstable overlay for GUI apps ([#524](https://github.com/JacobPEvans/nix-darwin/issues/524)) ([f9424a6](https://github.com/JacobPEvans/nix-darwin/commit/f9424a61882ecd695b465a96cc91103183ad3e0b))
* add Obsidian skills plugins ([#574](https://github.com/JacobPEvans/nix-darwin/issues/574)) ([66e1de9](https://github.com/JacobPEvans/nix-darwin/commit/66e1de9945e3c3aa499f74d45c57213c97426443))
* add official Claude plugins and pyright tool ([#501](https://github.com/JacobPEvans/nix-darwin/issues/501)) ([9629bd0](https://github.com/JacobPEvans/nix-darwin/commit/9629bd0ea46d45d59dceeab6c50f44adccaf9666))
* add plugin auto-update support and stable update channel ([#566](https://github.com/JacobPEvans/nix-darwin/issues/566)) ([55572c9](https://github.com/JacobPEvans/nix-darwin/commit/55572c9c79942e23b2c2d7289dee18f685e25cb5))
* add Python multi-version support (3.10, 3.12) with uv-based 3.9 ([#506](https://github.com/JacobPEvans/nix-darwin/issues/506)) ([a4dc4cb](https://github.com/JacobPEvans/nix-darwin/commit/a4dc4cba4213355e6e9410b9d9542977808dd3d6))
* add SOPS_AGE_KEY_FILE and EDITOR=vim to session variables ([#635](https://github.com/JacobPEvans/nix-darwin/issues/635)) ([59e5a56](https://github.com/JacobPEvans/nix-darwin/commit/59e5a565406378de1a1c6eba368676ba3afe3365))
* add SOPS-encrypted pre-commit hook for keyword scanning ([#725](https://github.com/JacobPEvans/nix-darwin/issues/725)) ([396fee2](https://github.com/JacobPEvans/nix-darwin/commit/396fee2bbc49209c8952b2fbe4bc5b317e105bb1))
* add Splunk MCP server to Claude Code mcpServers ([#829](https://github.com/JacobPEvans/nix-darwin/issues/829)) ([f212edd](https://github.com/JacobPEvans/nix-darwin/commit/f212edd3660b7dde9f5bb0e134df6857481996b0))
* add upstream-repo-updated dispatch for cross-repo triggers ([#560](https://github.com/JacobPEvans/nix-darwin/issues/560)) ([914eed2](https://github.com/JacobPEvans/nix-darwin/commit/914eed2a2c90eb73c4791e2b761f5b8c0dfec783))
* add watchexec package and create MANIFEST.md inventory ([#628](https://github.com/JacobPEvans/nix-darwin/issues/628)) ([45215bb](https://github.com/JacobPEvans/nix-darwin/commit/45215bb9e860c8f103273a9d5c111b97922f0ee3))
* add wispr-flow voice dictation app ([#493](https://github.com/JacobPEvans/nix-darwin/issues/493)) ([0404e9a](https://github.com/JacobPEvans/nix-darwin/commit/0404e9a62a620cf29155d87ecb398b60e53b2c0a))
* **ai:** install codex cli and official gemini vscode extension ([#570](https://github.com/JacobPEvans/nix-darwin/issues/570)) ([3cbf944](https://github.com/JacobPEvans/nix-darwin/commit/3cbf944c89ea337bf06fa146c096e3195247638a))
* **aliases:** add d-claude for Doppler secrets injection ([da3c2ca](https://github.com/JacobPEvans/nix-darwin/commit/da3c2cafc499e2febe37c03a4f2703df17eaaf6d))
* **auto-claude:** Add terraform-proxmox repo, update schedule to 4-hour intervals, implement worktree workflow ([a5a2d35](https://github.com/JacobPEvans/nix-darwin/commit/a5a2d358f02feb5cc04f89260fb52c7406b33746))
* **auto-claude:** autonomous continuation, stale instance cleanup, and haiku-only budget increase ([360528a](https://github.com/JacobPEvans/nix-darwin/commit/360528aaea69dd99f955956f268a80e0ae7673da))
* auto-discover JacobPEvans plugins from flake input ([#557](https://github.com/JacobPEvans/nix-darwin/issues/557)) ([091b681](https://github.com/JacobPEvans/nix-darwin/commit/091b6812ef63a3a306ec2c87547e019e74dd9bc3))
* auto-enable squash merge on all PRs when opened ([#742](https://github.com/JacobPEvans/nix-darwin/issues/742)) ([f9d55a7](https://github.com/JacobPEvans/nix-darwin/commit/f9d55a7633729ef4d6e6402d95d6686ad7b1a345))
* **aws:** add terraform-bedrock and iam-user profiles ([#488](https://github.com/JacobPEvans/nix-darwin/issues/488)) ([e3be0ac](https://github.com/JacobPEvans/nix-darwin/commit/e3be0acfc89c2a192cfb0268e7b2000b1c388e2d))
* **ci:** add nix-ai to AI_INPUTS allowlist in deps-update-flake ([#750](https://github.com/JacobPEvans/nix-darwin/issues/750)) ([04f012e](https://github.com/JacobPEvans/nix-darwin/commit/04f012ebd5aa3677864616d19ad906b9087304f3))
* **ci:** unified issue dispatch pattern with AI-created issue support ([#710](https://github.com/JacobPEvans/nix-darwin/issues/710)) ([e603c25](https://github.com/JacobPEvans/nix-darwin/commit/e603c251d262912f1d726b59687326dfab9506ba))
* **claude:** add remoteControlAtStartup option, extract activation scripts to shell files ([#713](https://github.com/JacobPEvans/nix-darwin/issues/713)) ([a3cca1a](https://github.com/JacobPEvans/nix-darwin/commit/a3cca1a172d4647bff268448635af7ed5f2a2108))
* **claude:** disable redundant MCP servers and playwright plugin globally ([#748](https://github.com/JacobPEvans/nix-darwin/issues/748)) ([dfeb7c3](https://github.com/JacobPEvans/nix-darwin/commit/dfeb7c30e9ca62e77f6a6515065c15707803cb67))
* **claude:** enable agent teams and use default model ([#551](https://github.com/JacobPEvans/nix-darwin/issues/551)) ([1468168](https://github.com/JacobPEvans/nix-darwin/commit/14681686f8505a4729d4ed38b8543fcd28515e7a))
* **claude:** pin statusline to semver ^1, set effort medium, add 1M context disable ([#700](https://github.com/JacobPEvans/nix-darwin/issues/700)) ([0e3801c](https://github.com/JacobPEvans/nix-darwin/commit/0e3801cd4d65f78ebad31b498c1600c44a5b2c01))
* **claude:** set default startup model to opusplan ([#599](https://github.com/JacobPEvans/nix-darwin/issues/599)) ([56f9c1b](https://github.com/JacobPEvans/nix-darwin/commit/56f9c1bfe8b165339ab7debf7ff23ec9f0863021))
* configure plugin marketplaces via Nix ([#478](https://github.com/JacobPEvans/nix-darwin/issues/478)) ([107e538](https://github.com/JacobPEvans/nix-darwin/commit/107e5381c6cd1dce09b3527a35baa402f82fd65e))
* **contributing:** restore personality and humor to CONTRIBUTING.md ([02b8732](https://github.com/JacobPEvans/nix-darwin/commit/02b8732aa0032b4fbfdc582354cd51d38fc23b9a))
* **copilot:** add Copilot coding agent support + CI fail issue workflow ([#740](https://github.com/JacobPEvans/nix-darwin/issues/740)) ([07de9b2](https://github.com/JacobPEvans/nix-darwin/commit/07de9b21400618fa1d2705e72f3ec98a2c447a59))
* create infrastructure-automation shell combining packer and terraform ([#459](https://github.com/JacobPEvans/nix-darwin/issues/459)) ([9f522f6](https://github.com/JacobPEvans/nix-darwin/commit/9f522f6ac4e12127176a3a4ff18b3c2065ed96fa))
* **darwin:** add automatic boot failure detection with recovery helper ([4ea9c99](https://github.com/JacobPEvans/nix-darwin/commit/4ea9c99df5dfa61c2a7fe0b2224171d6256de0d0))
* **darwin:** add clock settings, energy module, and UI customizations ([#429](https://github.com/JacobPEvans/nix-darwin/issues/429)) ([4d8636e](https://github.com/JacobPEvans/nix-darwin/commit/4d8636e36488019568e54ab257a377f53ac86126))
* **darwin:** add local whisper/voice/AI tooling ([#702](https://github.com/JacobPEvans/nix-darwin/issues/702)) ([30f1ebb](https://github.com/JacobPEvans/nix-darwin/commit/30f1ebbf6e463ba33735d8beb15670eedd35c737))
* **darwin:** add syslog forwarding to remote server ([#514](https://github.com/JacobPEvans/nix-darwin/issues/514)) ([3d46baa](https://github.com/JacobPEvans/nix-darwin/commit/3d46baa0e115437c67a6e887738fc7ad203c7b95))
* **deps:** implement comprehensive dependency monitoring system ([fb4c3dc](https://github.com/JacobPEvans/nix-darwin/commit/fb4c3dc833abbf1febaece88dd9c937f75f43047))
* disable auto-updaters for Nix-managed macOS apps ([#605](https://github.com/JacobPEvans/nix-darwin/issues/605)) ([26afe5e](https://github.com/JacobPEvans/nix-darwin/commit/26afe5e08861324512a703439e21a43921910f41))
* disable automatic triggers on Claude-executing workflows ([cbe315e](https://github.com/JacobPEvans/nix-darwin/commit/cbe315ebe544ba3e234cfdf04083cf1ac751a8a4))
* **dock:** add iPhone Mirroring and Microsoft Teams ([#787](https://github.com/JacobPEvans/nix-darwin/issues/787)) ([9c88430](https://github.com/JacobPEvans/nix-darwin/commit/9c8843051214575dfeb50e8f9accc5148a5c6b97))
* **dock:** add Microsoft Outlook to persistent Dock bar ([#693](https://github.com/JacobPEvans/nix-darwin/issues/693)) ([006dd94](https://github.com/JacobPEvans/nix-darwin/commit/006dd9417099dd135c1937453760873b604f01cd))
* enable full Claude Code OTEL telemetry ([#637](https://github.com/JacobPEvans/nix-darwin/issues/637)) ([4879940](https://github.com/JacobPEvans/nix-darwin/commit/48799405c3d8b7ef24974efd868637ed9c55f28c))
* enable PAL MCP with proper timeouts ([b314467](https://github.com/JacobPEvans/nix-darwin/commit/b314467abf19f2f87001bc6a15d1ab713fc31073))
* enable ralph-wiggum autonomous iteration plugin ([c143fab](https://github.com/JacobPEvans/nix-darwin/commit/c143fabfed7d3e9f76b5f028cfb17295696aceb0))
* extract claudebar package and add nix-update to flake workflow ([#811](https://github.com/JacobPEvans/nix-darwin/issues/811)) ([0992eb4](https://github.com/JacobPEvans/nix-darwin/commit/0992eb4d6085830701829cb3b5c92dabcaca1ba4))
* **flake-rebuild:** add issue investigation and plan generation prompt ([#895](https://github.com/JacobPEvans/nix-darwin/issues/895)) ([cac974f](https://github.com/JacobPEvans/nix-darwin/commit/cac974f55c2ad3070d2bf1d8d34e9bd5081575c3))
* **flake:** decouple nix-ai non-flake inputs via follows ([#857](https://github.com/JacobPEvans/nix-darwin/issues/857)) ([8fb3fdc](https://github.com/JacobPEvans/nix-darwin/commit/8fb3fdc90ccb8bad95eb68f7c8b28e40cce07df2))
* **gc:** add weekly LaunchDaemon to prune old profile generations ([#830](https://github.com/JacobPEvans/nix-darwin/issues/830)) ([d3cac5b](https://github.com/JacobPEvans/nix-darwin/commit/d3cac5b3e8c2e08fa5429a730e146503b48ce291))
* **homebrew:** add Microsoft 365 apps via Mac App Store ([#548](https://github.com/JacobPEvans/nix-darwin/issues/548)) ([de24eb6](https://github.com/JacobPEvans/nix-darwin/commit/de24eb60db1e20544449bbb3c50156382d76c5f2))
* implement Claude Code hooks with notifications ([#520](https://github.com/JacobPEvans/nix-darwin/issues/520)) ([3f621d5](https://github.com/JacobPEvans/nix-darwin/commit/3f621d5aa051aefa805434f779d71ca16e2f2780))
* include claude-code in daily AI dependency updates ([#511](https://github.com/JacobPEvans/nix-darwin/issues/511)) ([1a8ebe0](https://github.com/JacobPEvans/nix-darwin/commit/1a8ebe0ab730b300bcc7632509186aae0b17dd42))
* install git-flow-next v1.0.0 via custom buildGoModule ([#642](https://github.com/JacobPEvans/nix-darwin/issues/642)) ([5650029](https://github.com/JacobPEvans/nix-darwin/commit/565002903da422f9c108d1353d70d385048376c0))
* **keychain:** add comprehensive keychain error handler and event tracking ([d37d46a](https://github.com/JacobPEvans/nix-darwin/commit/d37d46aacc986eb11dc3759e3c4a37937fb5bd2b))
* **macos:** switch to copyApps for stable TCC permissions ([ab07d77](https://github.com/JacobPEvans/nix-darwin/commit/ab07d7751b77f4d4a329279c53ab4f56656889c0))
* **mcp:** Add Nix-native MCP servers with Docker and Context7 ([#494](https://github.com/JacobPEvans/nix-darwin/issues/494)) ([d11ff97](https://github.com/JacobPEvans/nix-darwin/commit/d11ff975f505c7b629792a5f24a640a84c3fac47))
* **mcp:** integrate PAL MCP and remove dead code ([#497](https://github.com/JacobPEvans/nix-darwin/issues/497)) ([90e4509](https://github.com/JacobPEvans/nix-darwin/commit/90e45090918db9ab98aad9362a8910c4e97bf82b))
* migrate flake.lock updates to Renovate nix manager ([#835](https://github.com/JacobPEvans/nix-darwin/issues/835)) ([92bbb71](https://github.com/JacobPEvans/nix-darwin/commit/92bbb71e8b960bab4acd0c6f5bda5d20604c7192))
* migrate granola-watcher to vault, remove from public repo ([#724](https://github.com/JacobPEvans/nix-darwin/issues/724)) ([70dad9c](https://github.com/JacobPEvans/nix-darwin/commit/70dad9c8b91ba6b516c80bb862d0da512598d8cf))
* move gemini-cli and antigravity to homebrew for Gemini 3.1 Pro support ([#685](https://github.com/JacobPEvans/nix-darwin/issues/685)) ([33a2486](https://github.com/JacobPEvans/nix-darwin/commit/33a2486baf9d634c55759e17a96740dac059f8cb))
* move module-eval check into lib/checks.nix ([#761](https://github.com/JacobPEvans/nix-darwin/issues/761)) ([3f80d47](https://github.com/JacobPEvans/nix-darwin/commit/3f80d476883387e8633a760643c9bff636885c37))
* **nix:** add trusted-users and devenv cachix binary cache ([#837](https://github.com/JacobPEvans/nix-darwin/issues/837)) ([cf31065](https://github.com/JacobPEvans/nix-darwin/commit/cf310650e36d3d773150fad0034b68bd4411e3a4))
* **nix:** migrate to official determinateNix module with automatic GC ([#792](https://github.com/JacobPEvans/nix-darwin/issues/792)) ([cdc21c6](https://github.com/JacobPEvans/nix-darwin/commit/cdc21c6ca047fc5cbe8fd4e101b286db5051e790))
* **ollama:** upgrade to unstable channel and clean up plans ([#573](https://github.com/JacobPEvans/nix-darwin/issues/573)) ([90a6709](https://github.com/JacobPEvans/nix-darwin/commit/90a67094e03edbc84d64b2d7844115455ed0a6fc))
* **opencode:** replace sugar plugin with enhanced OpenCode integration ([#317](https://github.com/JacobPEvans/nix-darwin/issues/317)) ([e817256](https://github.com/JacobPEvans/nix-darwin/commit/e8172569a131201c98680e6c51d2195047a123bf))
* optimize CI workflow performance ([#519](https://github.com/JacobPEvans/nix-darwin/issues/519)) ([845e16b](https://github.com/JacobPEvans/nix-darwin/commit/845e16bc69dd9b33efb0cb0079bafa5a58b94f84))
* **packages:** enforce package hierarchy with validation hooks ([e8de606](https://github.com/JacobPEvans/nix-darwin/commit/e8de606b8afbaa07e2c64261fee050dab147e29b))
* **plugins:** add community plugins and multi-model integrations ([#503](https://github.com/JacobPEvans/nix-darwin/issues/503)) ([48d283f](https://github.com/JacobPEvans/nix-darwin/commit/48d283fe481e7b77c8ef006faf0ad40c9d248db9))
* **precommit:** add lychee and comprehensive pre-commit tooling module ([ef9525d](https://github.com/JacobPEvans/nix-darwin/commit/ef9525db7484fc67525aab6b159a9ad54fde94e9))
* release polish — MIT license, README rewrite, and doc cleanup ([#751](https://github.com/JacobPEvans/nix-darwin/issues/751)) ([2c9f33a](https://github.com/JacobPEvans/nix-darwin/commit/2c9f33af8b07ac17fcd026aa6b5d412bf2b5f6ef))
* remove nodejs and python310 from global packages ([#765](https://github.com/JacobPEvans/nix-darwin/issues/765)) ([024eab9](https://github.com/JacobPEvans/nix-darwin/commit/024eab9d743c68dbb832f6e8654f79d44c43c356))
* replace issue-triage with full issue pipeline ([#658](https://github.com/JacobPEvans/nix-darwin/issues/658)) ([c6d19f3](https://github.com/JacobPEvans/nix-darwin/commit/c6d19f3b338861d11e6e69149577ba33f9e55516))
* **settings:** add effortLevel option with medium default ([ce0d574](https://github.com/JacobPEvans/nix-darwin/commit/ce0d574d15a0681099032298f18ee6d08a6af319))
* **shells:** add PowerShell development shell ([#575](https://github.com/JacobPEvans/nix-darwin/issues/575)) ([ceede10](https://github.com/JacobPEvans/nix-darwin/commit/ceede1048bec4a6992db86784f10d762c546b1f3))
* **shells:** add sops/age, split ansible shell, fix direnv performance ([#595](https://github.com/JacobPEvans/nix-darwin/issues/595)) ([d9fc1d4](https://github.com/JacobPEvans/nix-darwin/commit/d9fc1d4d1524bee361a8db2ed2ac3ece845a32f4))
* switch to ai-workflows reusable workflows ([#634](https://github.com/JacobPEvans/nix-darwin/issues/634)) ([fa98038](https://github.com/JacobPEvans/nix-darwin/commit/fa980384fb69677c5ff5ebbdb13eb8310b67091b))
* **testing:** add BATS testing framework with comprehensive shell tests ([#404](https://github.com/JacobPEvans/nix-darwin/issues/404)) ([57a8a68](https://github.com/JacobPEvans/nix-darwin/commit/57a8a681b17e223e3e93d29c781fb9a7351bd46b))
* **tmux:** add programs.tmux config with session persistence and mosh ([#618](https://github.com/JacobPEvans/nix-darwin/issues/618)) ([0e44a2e](https://github.com/JacobPEvans/nix-darwin/commit/0e44a2eaed4ab913b3d83de6d10f75b2f0bfbe0d))
* update ollama to latest nixpkgs, add claude-flow ([#543](https://github.com/JacobPEvans/nix-darwin/issues/543)) ([aada2a0](https://github.com/JacobPEvans/nix-darwin/commit/aada2a0594806a2a234c985e2c5cfd36d2517acd))
* update to claude-code-plugins v2.0.0 (8 consolidated plugins) ([#579](https://github.com/JacobPEvans/nix-darwin/issues/579)) ([0518c89](https://github.com/JacobPEvans/nix-darwin/commit/0518c89cd0d4c37e92e9c85ded161a2e2b8c348a))
* **vscode:** use activation script for writable settings ([#620](https://github.com/JacobPEvans/nix-darwin/issues/620)) ([5287eaf](https://github.com/JacobPEvans/nix-darwin/commit/5287eaf118bad42ebcbe77860529e413ffc9217f))
* **zsh:** add brew update on startup, fix background tasks, clean initContent ([#718](https://github.com/JacobPEvans/nix-darwin/issues/718)) ([dff5b8b](https://github.com/JacobPEvans/nix-darwin/commit/dff5b8bbc92256286f789a55d938229c00de6bde))


### Bug Fixes

* add 'with lib;' to options.nix to fix mkOption scope issue ([54dc6f4](https://github.com/JacobPEvans/nix-darwin/commit/54dc6f43a03cda0b82cbb2336e1904c5dc50703f))
* add bridge job for reusable workflow always() limitation ([#664](https://github.com/JacobPEvans/nix-darwin/issues/664)) ([3ba2cb0](https://github.com/JacobPEvans/nix-darwin/commit/3ba2cb0a45456cff3859a183b200be9b052c22ac))
* add cryptography to home-manager Python environments ([#565](https://github.com/JacobPEvans/nix-darwin/issues/565)) ([98eaed8](https://github.com/JacobPEvans/nix-darwin/commit/98eaed81d05aac8204703430f9dd0c6a31170e75))
* add explicit baseBranches to Renovate config ([#518](https://github.com/JacobPEvans/nix-darwin/issues/518)) ([98f8a5c](https://github.com/JacobPEvans/nix-darwin/commit/98f8a5c58b0a999bb2c9b7177890b14ed099df49))
* add explicit if condition on resolve job for skipped ancestors ([#667](https://github.com/JacobPEvans/nix-darwin/issues/667)) ([2680737](https://github.com/JacobPEvans/nix-darwin/commit/2680737c6efcddab5808dc47a90946586f53eeda))
* add explicit permissions to issue pipeline for cross-repo calls ([#663](https://github.com/JacobPEvans/nix-darwin/issues/663)) ([fc84108](https://github.com/JacobPEvans/nix-darwin/commit/fc84108f855660ff864231e62ccd5994f08df1a1))
* add missing lib. prefixes for types, lib functions ([343b6c2](https://github.com/JacobPEvans/nix-darwin/commit/343b6c2646ff36e9640c3ab99fade7c0e65bee3d))
* add release-please config for manifest mode ([84ed18b](https://github.com/JacobPEvans/nix-darwin/commit/84ed18b8c92816da83577e3441da52e47f4fd024))
* add schedule→dispatch workaround for OIDC bug (claude-code-action[#814](https://github.com/JacobPEvans/nix-darwin/issues/814)) ([#779](https://github.com/JacobPEvans/nix-darwin/issues/779)) ([f6a48d6](https://github.com/JacobPEvans/nix-darwin/commit/f6a48d6f9127a7001d364fc9c1d25b46cc8501bc))
* add security comment for FLAKE_INPUTS variable handling ([33f891a](https://github.com/JacobPEvans/nix-darwin/commit/33f891af508db7520d646151758ca67e3b8aa257))
* address all 12 remaining PR review thread issues ([a16e884](https://github.com/JacobPEvans/nix-darwin/commit/a16e8840730971bca43d75d6ce32ef7fd924e1e1))
* address PR review feedback ([399222e](https://github.com/JacobPEvans/nix-darwin/commit/399222eaee34e1e02f4d4621a9f4fee1548b9900))
* address PR review feedback on configuration patterns ([e00c1e0](https://github.com/JacobPEvans/nix-darwin/commit/e00c1e0dd8c18506869d14e77f26657ba7649719))
* address PR review feedback on validation scripts and documentation ([1230d22](https://github.com/JacobPEvans/nix-darwin/commit/1230d22ed2b5e7b5dfbc72cd1641011588818834))
* address review feedback - useless cat, symlink-boot recovery, Gemini comment ([6a3a8c6](https://github.com/JacobPEvans/nix-darwin/commit/6a3a8c6fa61222b6bd84136aea5a42790afdafc7))
* align ai-assistant-instructions command source path with discovery path ([c6a84a6](https://github.com/JacobPEvans/nix-darwin/commit/c6a84a62040a1ba977b4f806b901574a3bf963a0))
* **auto-claude:** add hard enforcement for 50 ai-created issue limit ([5a718bf](https://github.com/JacobPEvans/nix-darwin/commit/5a718bf351f01d8edd413ac38bff1b4dc4c68d30))
* **auto-claude:** add hard limits and content routing to prevent issue spam ([#421](https://github.com/JacobPEvans/nix-darwin/issues/421)) ([48efe8f](https://github.com/JacobPEvans/nix-darwin/commit/48efe8fe1cdbff739ff112d726384801a62392f8))
* **auto-claude:** add Slack channel validation and keychain error handling ([#454](https://github.com/JacobPEvans/nix-darwin/issues/454)) ([6f6f402](https://github.com/JacobPEvans/nix-darwin/commit/6f6f4027f43d242885ac5e5ff1326f5d98ee5a9a))
* **auto-claude:** add SSH agent setup and headless authentication ([#453](https://github.com/JacobPEvans/nix-darwin/issues/453)) ([ba266b9](https://github.com/JacobPEvans/nix-darwin/commit/ba266b988348063e7bdfafcb12a01c6b1e7505fa))
* **auto-claude:** address code review feedback ([0c39ca3](https://github.com/JacobPEvans/nix-darwin/commit/0c39ca3c4678ea7b73440f80bb69c021f32ebb7b))
* **auto-claude:** address review comments - improve PID detection and exception logging ([c840130](https://github.com/JacobPEvans/nix-darwin/commit/c840130680dadc3949df6f987f464c631aea1eba))
* **auto-claude:** change recent activity threshold from 4 hours to 1 hour ([5011a7c](https://github.com/JacobPEvans/nix-darwin/commit/5011a7cc52771e76c30896ac5e13a3063b4b5249))
* **auto-claude:** remove all git -C usage, use cwd parameter instead ([3c49794](https://github.com/JacobPEvans/nix-darwin/commit/3c4979435a921805ad85fed3cc4a203201ab07e4))
* **boot:** add wait4path to fix race condition with /nix/store mount ([6196244](https://github.com/JacobPEvans/nix-darwin/commit/6196244f97f932b59c328923daf620ec81dcf3a2))
* **boot:** address all PR review comments comprehensively ([f9ed0bc](https://github.com/JacobPEvans/nix-darwin/commit/f9ed0bcc16304cbf474964f815cd22719a5721d0))
* bump ai-workflows to v0.2.6 and add id-token:write ([#674](https://github.com/JacobPEvans/nix-darwin/issues/674)) ([dfe23e9](https://github.com/JacobPEvans/nix-darwin/commit/dfe23e939720317d3da0fded19a5da22e3c0604a))
* bump all ai-workflows callers to v0.2.7 ([#677](https://github.com/JacobPEvans/nix-darwin/issues/677)) ([ae28776](https://github.com/JacobPEvans/nix-darwin/commit/ae287761908ff2a89fbd60406d26b2cee269e91b))
* bump all ai-workflows callers to v0.2.8 ([#681](https://github.com/JacobPEvans/nix-darwin/issues/681)) ([9db24ea](https://github.com/JacobPEvans/nix-darwin/commit/9db24ead24c3811a751024109a0162e6777edf35))
* bump all ai-workflows callers to v0.2.9 ([#682](https://github.com/JacobPEvans/nix-darwin/issues/682)) ([09406d9](https://github.com/JacobPEvans/nix-darwin/commit/09406d972359caf73aac0cceae75fe12f3ed98d0))
* bump homeManagerStateVersion to 25.11 ([#873](https://github.com/JacobPEvans/nix-darwin/issues/873)) ([12fd1ee](https://github.com/JacobPEvans/nix-darwin/commit/12fd1ee4c2dd9f69429c50a80986b6a152aedc83))
* bump issue resolver/triage callers to v0.2.5 ([#673](https://github.com/JacobPEvans/nix-darwin/issues/673)) ([588015f](https://github.com/JacobPEvans/nix-darwin/commit/588015f79092ff62772ce659b6a45efb93217bcf))
* bump issue-resolver callers to v0.2.4 ([#670](https://github.com/JacobPEvans/nix-darwin/issues/670)) ([b08c3a4](https://github.com/JacobPEvans/nix-darwin/commit/b08c3a4e3aee0cd6b83f91fe9e776c8d55ad30bc))
* bump stateVersion to 25.11 with drift assertion ([#877](https://github.com/JacobPEvans/nix-darwin/issues/877)) ([887a41a](https://github.com/JacobPEvans/nix-darwin/commit/887a41acd16da94220c9cfbb1b8bd5bae0ebf3fc))
* change issue_number input type from number to string ([#675](https://github.com/JacobPEvans/nix-darwin/issues/675)) ([64872a7](https://github.com/JacobPEvans/nix-darwin/commit/64872a7d87c6b993a3a868b0036f0e13154e59fb))
* **ci:** add dispatch pattern for post-merge workflows ([#701](https://github.com/JacobPEvans/nix-darwin/issues/701)) ([41b8ad7](https://github.com/JacobPEvans/nix-darwin/commit/41b8ad79fb4f762f60e85963d33ef5359a415a33))
* **ci:** add nix-home to AI_INPUTS allowlist for dispatch events ([#754](https://github.com/JacobPEvans/nix-darwin/issues/754)) ([172519b](https://github.com/JacobPEvans/nix-darwin/commit/172519bb3d8e5ae9455dff1660887fc061a51ead))
* **ci:** add pull-requests: write for release-please auto-approval ([#848](https://github.com/JacobPEvans/nix-darwin/issues/848)) ([b9cb5a8](https://github.com/JacobPEvans/nix-darwin/commit/b9cb5a83b6aca2f7536cfd5ead8837e57f25c7b4))
* **ci:** add pull-requests: write for release-please auto-approval ([#850](https://github.com/JacobPEvans/nix-darwin/issues/850)) ([b561b18](https://github.com/JacobPEvans/nix-darwin/commit/b561b18c56b06549fe10dd18a757db6e72b1174e))
* **ci:** migrate copilot-setup-steps to determinate-nix-action@v3 ([#842](https://github.com/JacobPEvans/nix-darwin/issues/842)) ([63d82ef](https://github.com/JacobPEvans/nix-darwin/commit/63d82efed576f6921a68abfb0aa70ccb0f366f2a))
* **ci:** prevent Merge Gate false failures from cancelled runs ([#590](https://github.com/JacobPEvans/nix-darwin/issues/590)) ([f937654](https://github.com/JacobPEvans/nix-darwin/commit/f937654047bfeb5f77afcdf048ccb3c42e45f8bb))
* **ci:** remove jacobpevans-cc-plugins from AI_INPUTS ([#784](https://github.com/JacobPEvans/nix-darwin/issues/784)) ([669c2d8](https://github.com/JacobPEvans/nix-darwin/commit/669c2d83453d4335d795d9f37d2c08b5f727e214))
* **ci:** replace actions/cache with magic-nix-cache-action for Nix store ([#810](https://github.com/JacobPEvans/nix-darwin/issues/810)) ([631162b](https://github.com/JacobPEvans/nix-darwin/commit/631162bbea80b4c465e3a40448936478f31333e6))
* **ci:** use GitHub App token for release-please to trigger CI Gate ([#828](https://github.com/JacobPEvans/nix-darwin/issues/828)) ([7013a0e](https://github.com/JacobPEvans/nix-darwin/commit/7013a0edfe4fb48552a6a9ba6c3629827de043e6))
* **claude:** add marketplace cache integrity verification ([#611](https://github.com/JacobPEvans/nix-darwin/issues/611)) ([92a8c6a](https://github.com/JacobPEvans/nix-darwin/commit/92a8c6afe4d3a19b5108039f32129df115b00ffd))
* **claude:** add validation, shellcheck, and modular architecture ([32a0235](https://github.com/JacobPEvans/nix-darwin/commit/32a023511ef4608ec07ff95899434d44318bec88))
* **claude:** Fix marketplace keys and plugin references ([#422](https://github.com/JacobPEvans/nix-darwin/issues/422)) ([fcbc027](https://github.com/JacobPEvans/nix-darwin/commit/fcbc0275f505f1d2bac0a702db315d5ce27b8752))
* **claude:** make attribution a proper Nix option, remove hardcoded Co-Authored-By ([#711](https://github.com/JacobPEvans/nix-darwin/issues/711)) ([7e93854](https://github.com/JacobPEvans/nix-darwin/commit/7e93854f704853dd2e31727b9b46a7c46c654f7a))
* **claude:** remove invalid MultiEdit tool from permissions ([#474](https://github.com/JacobPEvans/nix-darwin/issues/474)) ([fdbc0fb](https://github.com/JacobPEvans/nix-darwin/commit/fdbc0fbfde1fd63234c9bbbedbfe317463e1842e))
* **claude:** resolve marketplace symlink permission errors on darwin-rebuild ([#698](https://github.com/JacobPEvans/nix-darwin/issues/698)) ([bc42a5f](https://github.com/JacobPEvans/nix-darwin/commit/bc42a5ff98efea8e13b6c9e6acf5da40e0d8dc93))
* **claude:** restore opusplan as default model ([#633](https://github.com/JacobPEvans/nix-darwin/issues/633)) ([bd172ca](https://github.com/JacobPEvans/nix-darwin/commit/bd172ca4113b61a44e15eb8269906481c043f573))
* **claude:** use recursive=true for marketplace dirs, remove cleanup scripts ([#688](https://github.com/JacobPEvans/nix-darwin/issues/688)) ([974c549](https://github.com/JacobPEvans/nix-darwin/commit/974c549800452470365dfa17a95820593903ae53))
* configure markdownlint MD013 line length to 160 characters ([#517](https://github.com/JacobPEvans/nix-darwin/issues/517)) ([82e31e4](https://github.com/JacobPEvans/nix-darwin/commit/82e31e4b6518bc0deca18c3496f582d4a9d02254))
* consolidate file-size config into .file-size.yml with shared defaults ([#889](https://github.com/JacobPEvans/nix-darwin/issues/889)) ([a141129](https://github.com/JacobPEvans/nix-darwin/commit/a14112941c77b33bab77abb00d72edce7c806f42))
* consolidate Renovate config and remove broken postUpgradeTasks ([#886](https://github.com/JacobPEvans/nix-darwin/issues/886)) ([d0fe728](https://github.com/JacobPEvans/nix-darwin/commit/d0fe728e278c3b5594e539b38ea35e1f4c327f0c))
* correct broken nix repo reference in Renovate troubleshooting docs ([#813](https://github.com/JacobPEvans/nix-darwin/issues/813)) ([e663882](https://github.com/JacobPEvans/nix-darwin/commit/e6638829affb6eb81e617b370c766d0ffe4c8b54))
* correct document-skills plugin reference ([#572](https://github.com/JacobPEvans/nix-darwin/issues/572)) ([fc2e934](https://github.com/JacobPEvans/nix-darwin/commit/fc2e93443e7ca3e7d79c6e4b04173d5390d2b923))
* correct plugin count from 13 to 12 in ANTHROPIC-ECOSYSTEM.md ([6696a24](https://github.com/JacobPEvans/nix-darwin/commit/6696a24918fd61a227059a4324b37d6b0533d107))
* **darwin:** add boot-activation for reliable symlink creation ([e9836a8](https://github.com/JacobPEvans/nix-darwin/commit/e9836a8e84493099bb97324447e177bd6440bc98))
* **darwin:** disable packages with broken upstream dependencies ([#427](https://github.com/JacobPEvans/nix-darwin/issues/427)) ([96b6c23](https://github.com/JacobPEvans/nix-darwin/commit/96b6c23064e74d74dfd7b9e7a62426d5f938667a))
* **darwin:** ensure LaunchDaemons are bootstrapped at activation ([3527285](https://github.com/JacobPEvans/nix-darwin/commit/35272852d6b8da11920057edd626139e222368ff))
* **darwin:** remove Paw defaults write (sandboxed container app) ([#856](https://github.com/JacobPEvans/nix-darwin/issues/856)) ([3abb0fb](https://github.com/JacobPEvans/nix-darwin/commit/3abb0fbb58e4a855acc305446a8181d258c7fb05))
* **darwin:** use nixpkgs for AI packages instead of llm-agents.nix ([#428](https://github.com/JacobPEvans/nix-darwin/issues/428)) ([04ea0da](https://github.com/JacobPEvans/nix-darwin/commit/04ea0daeec4311f92fe5c468836a05db6ed331e2))
* disable hash pinning for trusted actions, use version tags ([#790](https://github.com/JacobPEvans/nix-darwin/issues/790)) ([94630a1](https://github.com/JacobPEvans/nix-darwin/commit/94630a1a1d838628d8d1f37c504152ef8ca009b5))
* drastically reduce Claude Code context token usage ([ec8899e](https://github.com/JacobPEvans/nix-darwin/commit/ec8899e845b6edf158265e7cc636ab110e63a9b7))
* exempt CHANGELOG.md from file size limit ([#887](https://github.com/JacobPEvans/nix-darwin/issues/887)) ([c071d53](https://github.com/JacobPEvans/nix-darwin/commit/c071d53cf3c35d7b8bce874bff2cc21e1ccb5a43))
* **flake-rebuild:** clarify command must always execute the rebuild ([#893](https://github.com/JacobPEvans/nix-darwin/issues/893)) ([c0c2960](https://github.com/JacobPEvans/nix-darwin/commit/c0c2960115222eb6522b6f8cd4f2737666d86ced))
* **flake-rebuild:** only skip PR creation when an open PR exists ([#898](https://github.com/JacobPEvans/nix-darwin/issues/898)) ([64c5af0](https://github.com/JacobPEvans/nix-darwin/commit/64c5af04ac76fe64b21305c843f20e1aff938f14))
* **gemini:** use activation script for writable settings ([#613](https://github.com/JacobPEvans/nix-darwin/issues/613)) ([b307d7f](https://github.com/JacobPEvans/nix-darwin/commit/b307d7f201cbdb9e4197e2c4be68b766249f78d0))
* **git:** run pre-push hook on changed files only, handle deletions and use read -r ([9c16611](https://github.com/JacobPEvans/nix-darwin/commit/9c16611dafaf6da12aa7c6f966f1cba6a1379675))
* **git:** use merge-base with remote default branch for new-branch pre-push ([49b2fe2](https://github.com/JacobPEvans/nix-darwin/commit/49b2fe2e4ce1dc186acfb8c45655e9c13e3f0782))
* **homebrew:** add greedy flag to microsoft-teams cask ([#853](https://github.com/JacobPEvans/nix-darwin/issues/853)) ([3191d05](https://github.com/JacobPEvans/nix-darwin/commit/3191d0535fbf9e61ae7e3ecdb4b82bbfd6716b7d))
* **keychain:** add error handling and clean up imports ([f040512](https://github.com/JacobPEvans/nix-darwin/commit/f040512a00e4d0a2c3637d0d20482804f7aaf594))
* **mcp:** reorganize external MCP plugins and enable Context7 ([#491](https://github.com/JacobPEvans/nix-darwin/issues/491)) ([34c74d3](https://github.com/JacobPEvans/nix-darwin/commit/34c74d359367d6701d5a78c2ef46e16f4c1429ec))
* **mcp:** reorganize MCP plugins and add Context7 server ([#487](https://github.com/JacobPEvans/nix-darwin/issues/487)) ([e41ac04](https://github.com/JacobPEvans/nix-darwin/commit/e41ac046d35f452ac09739ae004e917607e3dea2))
* **menu-bar:** restore full menu structure with status, last run, and controls ([#319](https://github.com/JacobPEvans/nix-darwin/issues/319)) ([502b62d](https://github.com/JacobPEvans/nix-darwin/commit/502b62dc523269946cc726062b03bf02ee7373bf))
* migrate Bash permissions to space format and expand command tools ([#846](https://github.com/JacobPEvans/nix-darwin/issues/846)) ([48d7e81](https://github.com/JacobPEvans/nix-darwin/commit/48d7e811436fc42b458e4411011e41b23b179847))
* move Postman from nixpkgs to Homebrew cask ([#809](https://github.com/JacobPEvans/nix-darwin/issues/809)) ([35b28f9](https://github.com/JacobPEvans/nix-darwin/commit/35b28f90238f03a0f98894294393787a5c6d42b6))
* **nix:** use list type for determinateNix.customSettings ([#840](https://github.com/JacobPEvans/nix-darwin/issues/840)) ([29ec20e](https://github.com/JacobPEvans/nix-darwin/commit/29ec20e257dfb95c2b7ebd8ae1ee00472c34b96e))
* **permissions:** support MCP tool permissions in pipeline ([4767fe4](https://github.com/JacobPEvans/nix-darwin/commit/4767fe436a9d7a3e460165388e48f5e602c528dc))
* **plugins:** exclude schemas dir from plugin auto-discovery ([6390149](https://github.com/JacobPEvans/nix-darwin/commit/63901499239aeebf22d908af77e23ab4989bdcce))
* **plugins:** improve activation script diff error handling ([#470](https://github.com/JacobPEvans/nix-darwin/issues/470)) ([9aac29b](https://github.com/JacobPEvans/nix-darwin/commit/9aac29b19faa5a8a358ae1533ccd479b805a7f9f))
* **plugins:** remove non-existent clerk-auth and add missing official plugins ([#587](https://github.com/JacobPEvans/nix-darwin/issues/587)) ([b14f443](https://github.com/JacobPEvans/nix-darwin/commit/b14f443ece5fc6694a4410f31a25ba76605d9eef))
* **pre-commit:** remove darwin-rebuild from pre-push hook ([#709](https://github.com/JacobPEvans/nix-darwin/issues/709)) ([3bfbb19](https://github.com/JacobPEvans/nix-darwin/commit/3bfbb19ddbe5fb13630ae43adbcdb51762b32750))
* **precommit:** resolve review feedback - remove user-specific paths, 500 status code, and manual hook references ([94bb2fe](https://github.com/JacobPEvans/nix-darwin/commit/94bb2feaac1e6bfbe208a8d22355ca382dd7dadd))
* prevent bot review comments from cancelling Claude review ([#630](https://github.com/JacobPEvans/nix-darwin/issues/630)) ([a9975c3](https://github.com/JacobPEvans/nix-darwin/commit/a9975c341c6bf7d8be1dbe6af009b35cb6dc0c76))
* prevent Claude from guessing incorrect skill namespaces ([#504](https://github.com/JacobPEvans/nix-darwin/issues/504)) ([7c12012](https://github.com/JacobPEvans/nix-darwin/commit/7c12012805d38f908da9e6b4a8e38f2d84f8db7d))
* **recovery:** fallback to Terminal.app for App Management permission ([f26d8f0](https://github.com/JacobPEvans/nix-darwin/commit/f26d8f0b8a6eb579ff5475c62d843d41c3c4ff81))
* remove blanket auto-merge workflow ([#789](https://github.com/JacobPEvans/nix-darwin/issues/789)) ([618eca9](https://github.com/JacobPEvans/nix-darwin/commit/618eca9f4f85adea87e0cffd570c42213227fee8))
* remove deprecated SlashCommand permission ([#646](https://github.com/JacobPEvans/nix-darwin/issues/646)) ([9a78cbc](https://github.com/JacobPEvans/nix-darwin/commit/9a78cbc73348ee3aba3fcffcb1a15ab4e8da0979))
* remove mcpServers from settings.json (wrong location) ([ceb4798](https://github.com/JacobPEvans/nix-darwin/commit/ceb4798eea8c50414352d03da8f14361b93e26aa))
* remove nixpkgs-unstable overlay ([#879](https://github.com/JacobPEvans/nix-darwin/issues/879)) ([a870f35](https://github.com/JacobPEvans/nix-darwin/commit/a870f356a4d6f6a55043c2f021593151647024a4))
* remove Ollama from system packages and disable volume ([#875](https://github.com/JacobPEvans/nix-darwin/issues/875)) ([58ef9f9](https://github.com/JacobPEvans/nix-darwin/commit/58ef9f9b693ab7193e7066ec1bbe5f420837ae47))
* remove unused lambda parameters flagged by deadnix ([#808](https://github.com/JacobPEvans/nix-darwin/issues/808)) ([862c660](https://github.com/JacobPEvans/nix-darwin/commit/862c66092e4f62680425866dcb979b5578e99f58))
* rename caller job keys to avoid reusable workflow name collision ([#671](https://github.com/JacobPEvans/nix-darwin/issues/671)) ([e23660a](https://github.com/JacobPEvans/nix-darwin/commit/e23660ab562ccfd32ca45aa9b72049c9af387833))
* rename GH_APP_ID secret to GH_ACTION_JACOBPEVANS_APP_ID ([#814](https://github.com/JacobPEvans/nix-darwin/issues/814)) ([8be189b](https://github.com/JacobPEvans/nix-darwin/commit/8be189b02f82642a6f4f00612fab985411364d27))
* **renovate:** add shared preset, remove global automerge, fix deprecated matchers ([#796](https://github.com/JacobPEvans/nix-darwin/issues/796)) ([315907d](https://github.com/JacobPEvans/nix-darwin/commit/315907d3ec7a2d9a51902c29f9c92d0a8596b574))
* **renovate:** deduplicate config and guard git-refs major updates ([#797](https://github.com/JacobPEvans/nix-darwin/issues/797)) ([e5d6251](https://github.com/JacobPEvans/nix-darwin/commit/e5d625123a1bf198b8557daf30be7aa834a52dee))
* reorder dock apps, document Quotio install, and trampoline permissions ([#521](https://github.com/JacobPEvans/nix-darwin/issues/521)) ([b1bc3f7](https://github.com/JacobPEvans/nix-darwin/commit/b1bc3f7b2cbbdec8d12592a31e8d115a82a385d2)), closes [#461](https://github.com/JacobPEvans/nix-darwin/issues/461) [#438](https://github.com/JacobPEvans/nix-darwin/issues/438) [#424](https://github.com/JacobPEvans/nix-darwin/issues/424)
* resolve all 6 review thread issues from copilot-pull-request-reviewer ([a900ff9](https://github.com/JacobPEvans/nix-darwin/commit/a900ff961d87883163d7c02f053a13e71e4fbd4a))
* resolve all review thread issues ([c41057b](https://github.com/JacobPEvans/nix-darwin/commit/c41057baa8a9994cd63a5fe4044343bb0fd41d45))
* resolve all review thread issues ([3f8354d](https://github.com/JacobPEvans/nix-darwin/commit/3f8354d969c19e395fdd17db76f105dc18d38a6c))
* Resolve auto-claude permission and module import issues ([#425](https://github.com/JacobPEvans/nix-darwin/issues/425)) ([4a92f93](https://github.com/JacobPEvans/nix-darwin/commit/4a92f93212194a37dee13bedb07f7ce63d179393))
* resolve build warnings and resolve agent symlink conflict ([#457](https://github.com/JacobPEvans/nix-darwin/issues/457)) ([b55b777](https://github.com/JacobPEvans/nix-darwin/commit/b55b777a41f19fd20de1fa15a6f6ffc6d8ecd76b))
* resolve Claude Code + Nix configuration issues ([1f547af](https://github.com/JacobPEvans/nix-darwin/commit/1f547afb9b8c8889edc7fef59efdde2370a97994))
* resolve darwin-rebuild warnings for options.json and lsregister ([#621](https://github.com/JacobPEvans/nix-darwin/issues/621)) ([5d431e4](https://github.com/JacobPEvans/nix-darwin/commit/5d431e496376c1e2acb527d886c877fe70dffcdb))
* resolve GitHub code scanning alerts ([#499](https://github.com/JacobPEvans/nix-darwin/issues/499)) ([98594e8](https://github.com/JacobPEvans/nix-darwin/commit/98594e8722d3c028de63d258692c8a1f0663543b))
* resolve home-manager rebuild warnings and orphan symlinks ([a67bc46](https://github.com/JacobPEvans/nix-darwin/commit/a67bc4633e2cb696319a6af37b31d89a632a812d))
* restore plugins, upgrade claude-code, fix marketplace naming ([3d5643e](https://github.com/JacobPEvans/nix-darwin/commit/3d5643e83a874efec5101ea69e5a6fbb6d385bd4))
* robustly handle filenames with spaces/newlines in symlink cleanup ([a2a5696](https://github.com/JacobPEvans/nix-darwin/commit/a2a56965180531acd9180f7ad22394cccf965086))
* source AI CLI tools from unstable overlay for version currency ([#619](https://github.com/JacobPEvans/nix-darwin/issues/619)) ([ca186fb](https://github.com/JacobPEvans/nix-darwin/commit/ca186fbb8d69782fc34952b1e2530e1686f5b009))
* split issue pipeline and fix permissions/version on all callers ([#669](https://github.com/JacobPEvans/nix-darwin/issues/669)) ([fd1add1](https://github.com/JacobPEvans/nix-darwin/commit/fd1add1cd2c65150501ba896bd40cc89bb2a92a0))
* split resolve into auto and manual paths ([#668](https://github.com/JacobPEvans/nix-darwin/issues/668)) ([8c7f690](https://github.com/JacobPEvans/nix-darwin/commit/8c7f690a65a50bd8e1d0fa1b482d30058407a2dd))
* standardize comment formatting for consistency ([f5be920](https://github.com/JacobPEvans/nix-darwin/commit/f5be9203c878da564d0827178941f552b8d85d2b))
* Standardize logging format and improve darwin-rebuild diagnostics ([#475](https://github.com/JacobPEvans/nix-darwin/issues/475)) ([ccd96da](https://github.com/JacobPEvans/nix-darwin/commit/ccd96da8ea8af10d0c811001ede5f7725b371caf))
* switch to stable 25.11 (nixpkgs, darwin, home-manager) ([473432a](https://github.com/JacobPEvans/nix-darwin/commit/473432a494536e6bcae717f9bbb98e3973b0d180))
* sync release-please permissions and VERSION ([ba0eb02](https://github.com/JacobPEvans/nix-darwin/commit/ba0eb02830635cbc36ab81f4ee1c15c556e96dd0))
* **terraform-shell:** remove broken checkov and terrascan packages ([#706](https://github.com/JacobPEvans/nix-darwin/issues/706)) ([c275e70](https://github.com/JacobPEvans/nix-darwin/commit/c275e70bf1619d76b3e9ada1747d5adea2447fec))
* update CLAUDE.md to reference three companion repos (quartet) ([#881](https://github.com/JacobPEvans/nix-darwin/issues/881)) ([82ca482](https://github.com/JacobPEvans/nix-darwin/commit/82ca482825280f53b03c007bff894d3260695076))
* update ClaudeBar to v0.4.43 ([#818](https://github.com/JacobPEvans/nix-darwin/issues/818)) ([35b6dfa](https://github.com/JacobPEvans/nix-darwin/commit/35b6dfad18fcfa17e3d3fd5dec50d5c16fc616d7))
* update dispatch pipeline with ai:ready trigger and daily limit ([#759](https://github.com/JacobPEvans/nix-darwin/issues/759)) ([f564201](https://github.com/JacobPEvans/nix-darwin/commit/f564201e328c7bfd7a314ffed59b11b35a9527a8))
* update flake inputs after nix-ai and nix-home cleanup PRs ([#882](https://github.com/JacobPEvans/nix-darwin/issues/882)) ([0a05872](https://github.com/JacobPEvans/nix-darwin/commit/0a058724ace7d6f192702aa90d99c26bb1f44832))
* update issue pipeline to ai-workflows v0.2.1 ([#665](https://github.com/JacobPEvans/nix-darwin/issues/665)) ([ad8fbab](https://github.com/JacobPEvans/nix-darwin/commit/ad8fbab5d25091c4c951e22e4c96a125de23a8ba))
* update issue pipeline to ai-workflows v0.2.2 ([#666](https://github.com/JacobPEvans/nix-darwin/issues/666)) ([98b2c75](https://github.com/JacobPEvans/nix-darwin/commit/98b2c7541330451f5e6b7c2612eda5a1187a56b6))
* update nix-ai (MLX port 11435→11436, port conflict) ([#869](https://github.com/JacobPEvans/nix-darwin/issues/869)) ([d399876](https://github.com/JacobPEvans/nix-darwin/commit/d39987629c25af1c7f02425e3aa56d13b6564f75))
* update nix-ai flake input to latest ([#860](https://github.com/JacobPEvans/nix-darwin/issues/860)) ([10c6032](https://github.com/JacobPEvans/nix-darwin/commit/10c6032b08cfa47d4dd3f926e173f2df38013b65))
* update nix-ai input (v0.2.6 CLI flags + checks split) ([#885](https://github.com/JacobPEvans/nix-darwin/issues/885)) ([7e19da6](https://github.com/JacobPEvans/nix-darwin/commit/7e19da6d768fe680957c5ba15940a82e98c0081a))
* use array expansion for safe flake inputs handling ([e414ede](https://github.com/JacobPEvans/nix-darwin/commit/e414edee4be9bb94b63bf7c2d2f54956e8415e6f))
* use brew info instead of brew search for exact matching ([8a79e04](https://github.com/JacobPEvans/nix-darwin/commit/8a79e04627ceac1aefe31fb4bad6856dc9fbd969))
* use word boundary matching for brew search verification ([ffd4fc2](https://github.com/JacobPEvans/nix-darwin/commit/ffd4fc235479417704b0ca926d1180620c875ef2))
* **validation:** address PR review feedback on regex and for loops ([d21f9ee](https://github.com/JacobPEvans/nix-darwin/commit/d21f9eed670a736fe973762dbd4fc75bfe488494))
* **wakatime:** use source.url for marketplace repo field ([#402](https://github.com/JacobPEvans/nix-darwin/issues/402)) ([9aab069](https://github.com/JacobPEvans/nix-darwin/commit/9aab0694fa33d7d32fe842ee3fe6327ebe2d2dc5))
* wire up ask permissions in Claude Code config ([#483](https://github.com/JacobPEvans/nix-darwin/issues/483)) ([b2aecb0](https://github.com/JacobPEvans/nix-darwin/commit/b2aecb0d1ea393405a2a09977c0bad5628bb94fa))


### Performance

* **ci:** optimize Nix build CI from 11m 40s to 9m 35s per PR ([#552](https://github.com/JacobPEvans/nix-darwin/issues/552)) ([e962d8d](https://github.com/JacobPEvans/nix-darwin/commit/e962d8dd84244cccaa789d200e989d655a3f8785))

## [1.14.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.14.0...v1.14.1) (2026-03-22)


### Bug Fixes

* **flake-rebuild:** only skip PR creation when an open PR exists ([#898](https://github.com/JacobPEvans/nix-darwin/issues/898)) ([64c5af0](https://github.com/JacobPEvans/nix-darwin/commit/64c5af04ac76fe64b21305c843f20e1aff938f14))

## [1.14.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.13.6...v1.14.0) (2026-03-22)


### Features

* **flake-rebuild:** add issue investigation and plan generation prompt ([#895](https://github.com/JacobPEvans/nix-darwin/issues/895)) ([cac974f](https://github.com/JacobPEvans/nix-darwin/commit/cac974f55c2ad3070d2bf1d8d34e9bd5081575c3))

## [1.13.6](https://github.com/JacobPEvans/nix-darwin/compare/v1.13.5...v1.13.6) (2026-03-22)


### Bug Fixes

* **flake-rebuild:** clarify command must always execute the rebuild ([#893](https://github.com/JacobPEvans/nix-darwin/issues/893)) ([c0c2960](https://github.com/JacobPEvans/nix-darwin/commit/c0c2960115222eb6522b6f8cd4f2737666d86ced))

## [1.13.5](https://github.com/JacobPEvans/nix-darwin/compare/v1.13.4...v1.13.5) (2026-03-21)


### Bug Fixes

* consolidate file-size config into .file-size.yml with shared defaults ([#889](https://github.com/JacobPEvans/nix-darwin/issues/889)) ([a141129](https://github.com/JacobPEvans/nix-darwin/commit/a14112941c77b33bab77abb00d72edce7c806f42))

## [1.13.4](https://github.com/JacobPEvans/nix-darwin/compare/v1.13.3...v1.13.4) (2026-03-21)


### Bug Fixes

* consolidate Renovate config and remove broken postUpgradeTasks ([#886](https://github.com/JacobPEvans/nix-darwin/issues/886)) ([d0fe728](https://github.com/JacobPEvans/nix-darwin/commit/d0fe728e278c3b5594e539b38ea35e1f4c327f0c))
* exempt CHANGELOG.md from file size limit ([#887](https://github.com/JacobPEvans/nix-darwin/issues/887)) ([c071d53](https://github.com/JacobPEvans/nix-darwin/commit/c071d53cf3c35d7b8bce874bff2cc21e1ccb5a43))
* update flake inputs after nix-ai and nix-home cleanup PRs ([#882](https://github.com/JacobPEvans/nix-darwin/issues/882)) ([0a05872](https://github.com/JacobPEvans/nix-darwin/commit/0a058724ace7d6f192702aa90d99c26bb1f44832))
* update nix-ai input (v0.2.6 CLI flags + checks split) ([#885](https://github.com/JacobPEvans/nix-darwin/issues/885)) ([7e19da6](https://github.com/JacobPEvans/nix-darwin/commit/7e19da6d768fe680957c5ba15940a82e98c0081a))

## [1.13.3](https://github.com/JacobPEvans/nix-darwin/compare/v1.13.2...v1.13.3) (2026-03-20)


### Bug Fixes

* remove nixpkgs-unstable overlay ([#879](https://github.com/JacobPEvans/nix-darwin/issues/879)) ([a870f35](https://github.com/JacobPEvans/nix-darwin/commit/a870f356a4d6f6a55043c2f021593151647024a4))
* update CLAUDE.md to reference three companion repos (quartet) ([#881](https://github.com/JacobPEvans/nix-darwin/issues/881)) ([82ca482](https://github.com/JacobPEvans/nix-darwin/commit/82ca482825280f53b03c007bff894d3260695076))

## [1.13.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.13.1...v1.13.2) (2026-03-20)


### Bug Fixes

* bump stateVersion to 25.11 with drift assertion ([#877](https://github.com/JacobPEvans/nix-darwin/issues/877)) ([887a41a](https://github.com/JacobPEvans/nix-darwin/commit/887a41acd16da94220c9cfbb1b8bd5bae0ebf3fc))

## [1.13.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.13.0...v1.13.1) (2026-03-20)


### Bug Fixes

* bump homeManagerStateVersion to 25.11 ([#873](https://github.com/JacobPEvans/nix-darwin/issues/873)) ([12fd1ee](https://github.com/JacobPEvans/nix-darwin/commit/12fd1ee4c2dd9f69429c50a80986b6a152aedc83))
* remove Ollama from system packages and disable volume ([#875](https://github.com/JacobPEvans/nix-darwin/issues/875)) ([58ef9f9](https://github.com/JacobPEvans/nix-darwin/commit/58ef9f9b693ab7193e7066ec1bbe5f420837ae47))

## [1.13.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.12.2...v1.13.0) (2026-03-20)


### Features

* add Cribl Edge nix-darwin module ([#871](https://github.com/JacobPEvans/nix-darwin/issues/871)) ([3d1758b](https://github.com/JacobPEvans/nix-darwin/commit/3d1758b4f0dc683032dcde0559f4fa9c4f796726))

## [1.12.2](https://github.com/JacobPEvans/nix-darwin/compare/v1.12.1...v1.12.2) (2026-03-19)


### Bug Fixes

* update nix-ai (MLX port 11435→11436, port conflict) ([#869](https://github.com/JacobPEvans/nix-darwin/issues/869)) ([d399876](https://github.com/JacobPEvans/nix-darwin/commit/d39987629c25af1c7f02425e3aa56d13b6564f75))

## [1.12.1](https://github.com/JacobPEvans/nix-darwin/compare/v1.12.0...v1.12.1) (2026-03-19)


### Bug Fixes

* add release-please config for manifest mode ([84ed18b](https://github.com/JacobPEvans/nix-darwin/commit/84ed18b8c92816da83577e3441da52e47f4fd024))
* sync release-please permissions and VERSION ([ba0eb02](https://github.com/JacobPEvans/nix-darwin/commit/ba0eb02830635cbc36ab81f4ee1c15c556e96dd0))
* update nix-ai flake input to latest ([#860](https://github.com/JacobPEvans/nix-darwin/issues/860)) ([10c6032](https://github.com/JacobPEvans/nix-darwin/commit/10c6032b08cfa47d4dd3f926e173f2df38013b65))

## [1.12.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.11.0...v1.12.0) (2026-03-17)


### Bug Fixes

* **darwin:** remove Paw defaults write (sandboxed container app) ([#856](https://github.com/JacobPEvans/nix-darwin/issues/856)) ([3abb0fb](https://github.com/JacobPEvans/nix-darwin/commit/3abb0fbb58e4a855acc305446a8181d258c7fb05))

## [1.11.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.10.0...v1.11.0) (2026-03-16)


### Bug Fixes

* **homebrew:** add greedy flag to microsoft-teams cask ([#853](https://github.com/JacobPEvans/nix-darwin/issues/853)) ([3191d05](https://github.com/JacobPEvans/nix-darwin/commit/3191d0535fbf9e61ae7e3ecdb4b82bbfd6716b7d))

## [1.10.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.9.0...v1.10.0) (2026-03-15)


### Bug Fixes

* **ci:** add pull-requests: write for release-please auto-approval ([#850](https://github.com/JacobPEvans/nix-darwin/issues/850)) ([b561b18](https://github.com/JacobPEvans/nix-darwin/commit/b561b18c56b06549fe10dd18a757db6e72b1174e))

## [1.9.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.8.0...v1.9.0) (2026-03-15)


### Bug Fixes

* **ci:** add pull-requests: write for release-please auto-approval ([#848](https://github.com/JacobPEvans/nix-darwin/issues/848)) ([b9cb5a8](https://github.com/JacobPEvans/nix-darwin/commit/b9cb5a83b6aca2f7536cfd5ead8837e57f25c7b4))

## [1.8.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.7.0...v1.8.0) (2026-03-15)


### Bug Fixes

* migrate Bash permissions to space format and expand command tools ([#846](https://github.com/JacobPEvans/nix-darwin/issues/846)) ([48d7e81](https://github.com/JacobPEvans/nix-darwin/commit/48d7e811436fc42b458e4411011e41b23b179847))

## [1.7.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.6.0...v1.7.0) (2026-03-15)


### Bug Fixes

* **ci:** migrate copilot-setup-steps to determinate-nix-action@v3 ([#842](https://github.com/JacobPEvans/nix-darwin/issues/842)) ([63d82ef](https://github.com/JacobPEvans/nix-darwin/commit/63d82efed576f6921a68abfb0aa70ccb0f366f2a))

## [1.6.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.5.0...v1.6.0) (2026-03-15)


### Bug Fixes

* **nix:** use list type for determinateNix.customSettings ([#840](https://github.com/JacobPEvans/nix-darwin/issues/840)) ([29ec20e](https://github.com/JacobPEvans/nix-darwin/commit/29ec20e257dfb95c2b7ebd8ae1ee00472c34b96e))

## [1.5.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.4.0...v1.5.0) (2026-03-14)


### Features

* **nix:** add trusted-users and devenv cachix binary cache ([#837](https://github.com/JacobPEvans/nix-darwin/issues/837)) ([cf31065](https://github.com/JacobPEvans/nix-darwin/commit/cf310650e36d3d773150fad0034b68bd4411e3a4))

## [1.4.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.3.0...v1.4.0) (2026-03-14)


### Features

* migrate flake.lock updates to Renovate nix manager ([#835](https://github.com/JacobPEvans/nix-darwin/issues/835)) ([92bbb71](https://github.com/JacobPEvans/nix-darwin/commit/92bbb71e8b960bab4acd0c6f5bda5d20604c7192))

## [1.3.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.2.0...v1.3.0) (2026-03-14)


### Features

* add APFS volume quota support and AI model volumes ([#832](https://github.com/JacobPEvans/nix-darwin/issues/832)) ([4d0aea3](https://github.com/JacobPEvans/nix-darwin/commit/4d0aea3b6cd6bddc15fc52ae1d9095a3c198f36f))

## [1.2.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.1.0...v1.2.0) (2026-03-13)


### Features

* add Splunk MCP server to Claude Code mcpServers ([#829](https://github.com/JacobPEvans/nix-darwin/issues/829)) ([f212edd](https://github.com/JacobPEvans/nix-darwin/commit/f212edd3660b7dde9f5bb0e134df6857481996b0))
* **gc:** add weekly LaunchDaemon to prune old profile generations ([#830](https://github.com/JacobPEvans/nix-darwin/issues/830)) ([d3cac5b](https://github.com/JacobPEvans/nix-darwin/commit/d3cac5b3e8c2e08fa5429a730e146503b48ce291))

## [1.1.0](https://github.com/JacobPEvans/nix-darwin/compare/v1.0.0...v1.1.0) (2026-03-13)


### Features

* add daily repo health audit agentic workflow ([#822](https://github.com/JacobPEvans/nix-darwin/issues/822)) ([974b393](https://github.com/JacobPEvans/nix-darwin/commit/974b393379a2409cd1c431d55154904a5d25fbb2))
* add Docker daemon log rotation and builder GC config ([#803](https://github.com/JacobPEvans/nix-darwin/issues/803)) ([26e5ca0](https://github.com/JacobPEvans/nix-darwin/commit/26e5ca07dc53c1b3b1c2005010fe0cc5892e0e0f))
* add gh-aw agentic workflows ([#766](https://github.com/JacobPEvans/nix-darwin/issues/766)) ([8489738](https://github.com/JacobPEvans/nix-darwin/commit/8489738fb4333401fe79a0c41edfd4fc4e8e4072))
* add HF_TOKEN to macOS Keychain exports for HuggingFace MCP ([#827](https://github.com/JacobPEvans/nix-darwin/issues/827)) ([9fa5d56](https://github.com/JacobPEvans/nix-darwin/commit/9fa5d56b782f7f802da2a6d8ee69349dc91a4fe5))
* add LM Studio and update nix-ai/nix-home inputs ([4e6c828](https://github.com/JacobPEvans/nix-darwin/commit/4e6c82866afd6124486c70333a4f0c1c4fcde2be))
* disable automatic triggers on Claude-executing workflows ([cbe315e](https://github.com/JacobPEvans/nix-darwin/commit/cbe315ebe544ba3e234cfdf04083cf1ac751a8a4))
* **dock:** add iPhone Mirroring and Microsoft Teams ([#787](https://github.com/JacobPEvans/nix-darwin/issues/787)) ([9c88430](https://github.com/JacobPEvans/nix-darwin/commit/9c8843051214575dfeb50e8f9accc5148a5c6b97))
* extract claudebar package and add nix-update to flake workflow ([#811](https://github.com/JacobPEvans/nix-darwin/issues/811)) ([0992eb4](https://github.com/JacobPEvans/nix-darwin/commit/0992eb4d6085830701829cb3b5c92dabcaca1ba4))
* move module-eval check into lib/checks.nix ([#761](https://github.com/JacobPEvans/nix-darwin/issues/761)) ([3f80d47](https://github.com/JacobPEvans/nix-darwin/commit/3f80d476883387e8633a760643c9bff636885c37))
* **nix:** migrate to official determinateNix module with automatic GC ([#792](https://github.com/JacobPEvans/nix-darwin/issues/792)) ([cdc21c6](https://github.com/JacobPEvans/nix-darwin/commit/cdc21c6ca047fc5cbe8fd4e101b286db5051e790))
* remove nodejs and python310 from global packages ([#765](https://github.com/JacobPEvans/nix-darwin/issues/765)) ([024eab9](https://github.com/JacobPEvans/nix-darwin/commit/024eab9d743c68dbb832f6e8654f79d44c43c356))


### Bug Fixes

* add schedule→dispatch workaround for OIDC bug (claude-code-action[#814](https://github.com/JacobPEvans/nix-darwin/issues/814)) ([#779](https://github.com/JacobPEvans/nix-darwin/issues/779)) ([f6a48d6](https://github.com/JacobPEvans/nix-darwin/commit/f6a48d6f9127a7001d364fc9c1d25b46cc8501bc))
* **ci:** remove jacobpevans-cc-plugins from AI_INPUTS ([#784](https://github.com/JacobPEvans/nix-darwin/issues/784)) ([669c2d8](https://github.com/JacobPEvans/nix-darwin/commit/669c2d83453d4335d795d9f37d2c08b5f727e214))
* **ci:** replace actions/cache with magic-nix-cache-action for Nix store ([#810](https://github.com/JacobPEvans/nix-darwin/issues/810)) ([631162b](https://github.com/JacobPEvans/nix-darwin/commit/631162bbea80b4c465e3a40448936478f31333e6))
* **ci:** use GitHub App token for release-please to trigger CI Gate ([#828](https://github.com/JacobPEvans/nix-darwin/issues/828)) ([7013a0e](https://github.com/JacobPEvans/nix-darwin/commit/7013a0edfe4fb48552a6a9ba6c3629827de043e6))
* correct broken nix repo reference in Renovate troubleshooting docs ([#813](https://github.com/JacobPEvans/nix-darwin/issues/813)) ([e663882](https://github.com/JacobPEvans/nix-darwin/commit/e6638829affb6eb81e617b370c766d0ffe4c8b54))
* disable hash pinning for trusted actions, use version tags ([#790](https://github.com/JacobPEvans/nix-darwin/issues/790)) ([94630a1](https://github.com/JacobPEvans/nix-darwin/commit/94630a1a1d838628d8d1f37c504152ef8ca009b5))
* move Postman from nixpkgs to Homebrew cask ([#809](https://github.com/JacobPEvans/nix-darwin/issues/809)) ([35b28f9](https://github.com/JacobPEvans/nix-darwin/commit/35b28f90238f03a0f98894294393787a5c6d42b6))
* remove blanket auto-merge workflow ([#789](https://github.com/JacobPEvans/nix-darwin/issues/789)) ([618eca9](https://github.com/JacobPEvans/nix-darwin/commit/618eca9f4f85adea87e0cffd570c42213227fee8))
* remove unused lambda parameters flagged by deadnix ([#808](https://github.com/JacobPEvans/nix-darwin/issues/808)) ([862c660](https://github.com/JacobPEvans/nix-darwin/commit/862c66092e4f62680425866dcb979b5578e99f58))
* rename GH_APP_ID secret to GH_ACTION_JACOBPEVANS_APP_ID ([#814](https://github.com/JacobPEvans/nix-darwin/issues/814)) ([8be189b](https://github.com/JacobPEvans/nix-darwin/commit/8be189b02f82642a6f4f00612fab985411364d27))
* **renovate:** add shared preset, remove global automerge, fix deprecated matchers ([#796](https://github.com/JacobPEvans/nix-darwin/issues/796)) ([315907d](https://github.com/JacobPEvans/nix-darwin/commit/315907d3ec7a2d9a51902c29f9c92d0a8596b574))
* **renovate:** deduplicate config and guard git-refs major updates ([#797](https://github.com/JacobPEvans/nix-darwin/issues/797)) ([e5d6251](https://github.com/JacobPEvans/nix-darwin/commit/e5d625123a1bf198b8557daf30be7aa834a52dee))
* update ClaudeBar to v0.4.43 ([#818](https://github.com/JacobPEvans/nix-darwin/issues/818)) ([35b6dfa](https://github.com/JacobPEvans/nix-darwin/commit/35b6dfad18fcfa17e3d3fd5dec50d5c16fc616d7))
