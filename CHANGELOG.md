# Changelog

## [0.4.2](https://github.com/Klafyvel/nvim-smuggler/compare/v0.4.1...v0.4.2) (2024-09-12)


### Bug Fixes

* evaluated/invalidated signs are optional ([3bcee97](https://github.com/Klafyvel/nvim-smuggler/commit/3bcee970b5ee853e9747008f5a831b9451497801))
* indent formatting ([60a0b36](https://github.com/Klafyvel/nvim-smuggler/commit/60a0b3648926b30835cdbed95d41b789436b2655))
* seperate events for textchangedI and textchanged, former uses cursor position to invalidate, latter uses marks ([c9866b8](https://github.com/Klafyvel/nvim-smuggler/commit/c9866b83298538d229344ce04c440cffec63186b))
* treat textchange as single character chunk , use get_cursor instead of marks [ and ] ([03ec10c](https://github.com/Klafyvel/nvim-smuggler/commit/03ec10c30587d19809b45f8409868b982f7a2fa2))


### Documentation

* **vimdoc:** Update configuration in vimdoc to reflect the README. ([8f3ee0d](https://github.com/Klafyvel/nvim-smuggler/commit/8f3ee0d1cd56500ab1c9059a7bd7094e85a936de))


### Miscellaneous Chores

* release 0.4.2 ([c8b11c1](https://github.com/Klafyvel/nvim-smuggler/commit/c8b11c1302207584676b7f3f7e773546054d27b3))

## [0.4.1](https://github.com/Klafyvel/nvim-smuggler/compare/v0.4.0...v0.4.1) (2024-09-11)


### Bug Fixes

* Fix SmuggleHideEvaluated command. ([59bd4ca](https://github.com/Klafyvel/nvim-smuggler/commit/59bd4ca5770b9716fac32110a1179612b17ac659))
* **neovim version:** Add checks for neovim version. ([d7b1e2d](https://github.com/Klafyvel/nvim-smuggler/commit/d7b1e2d919284e2441d4be9d866341886f02adde))
* **protocol:** Fix nested array de-serizalization. ([116d685](https://github.com/Klafyvel/nvim-smuggler/commit/116d685f51e5c3ff2a4e3c74c321e4833a127284))


### Miscellaneous Chores

* release 0.4.1 ([9cdf8c5](https://github.com/Klafyvel/nvim-smuggler/commit/9cdf8c5dc1dae3cb8da24572ffdedfea0b2b0a6f))

## [0.4.0](https://github.com/Klafyvel/nvim-smuggler/compare/v0.3.0...v0.4.0) (2024-09-10)


### ⚠ BREAKING CHANGES

* **config:** Changed the organization of configuration. See documentation.
* **ui:** THe syntax for the configuration of mappings changed. See the documentation `:help smuggler-configuration` for details.

### Features

* **buffers:** Delete invalidated chunks and results when evaluating a new chunk. ([f91987d](https://github.com/Klafyvel/nvim-smuggler/commit/f91987d77dc530147ab822908b05dc5fd6839407))
* **config:** Add a configuration option to not show evaluation results and images. ([fb8a6a2](https://github.com/Klafyvel/nvim-smuggler/commit/fb8a6a246fbd1a97a6a23f56a2b600755ce1c0e7))
* **config:** Added a configuration option for images sizes. ([32009b1](https://github.com/Klafyvel/nvim-smuggler/commit/32009b13de5c58ac1500b46bce219f3deb81276b))
* **config:** Implement Julia's IOContext buffer settings. ([c07fe8a](https://github.com/Klafyvel/nvim-smuggler/commit/c07fe8a2a13f0a4516a44ad0ef06ab39efd807ad))
* **configuration:** Add an option to automatically select the only available socket when applicable. ([8e74d4b](https://github.com/Klafyvel/nvim-smuggler/commit/8e74d4bec8848e79cfa3869d90f312af01c06184))
* **images:** Display image results if image.nvim is present! ([9e49b38](https://github.com/Klafyvel/nvim-smuggler/commit/9e49b384b137cb36a02df1c095927b6857a01dd9))
* **protocol:** Perform protocol version verification after handshake. ([255bd8c](https://github.com/Klafyvel/nvim-smuggler/commit/255bd8c333c4bb1b0191370082e236bb9b2d90a1))
* **results:** Display evaluation results. ([7f85b72](https://github.com/Klafyvel/nvim-smuggler/commit/7f85b724c0a524ca649dda3e106af9a4c2f79216))
* **ui:** Added configuration options for display of results. ([a869907](https://github.com/Klafyvel/nvim-smuggler/commit/a8699071139106e856444974aa83f7fae3a76a62))
* **ui:** Highlight evaluated chunks in buffers. ([f02c41d](https://github.com/Klafyvel/nvim-smuggler/commit/f02c41d1576deaf70d493f29e5d3a4844c4da4bc))


### Bug Fixes

* **buffers:** Detect chunks invalidation consistently. ([1cd54ca](https://github.com/Klafyvel/nvim-smuggler/commit/1cd54ca5f29c0be421854b64993a08dcaeb819ad))
* **client:** Fix async socket selection. ([de6e60d](https://github.com/Klafyvel/nvim-smuggler/commit/de6e60dc450bfde4a5f210a58b4a7b0b3453b70f))
* **client:** Smarter client to handle partial or overlapping server responses. ([cef2b4e](https://github.com/Klafyvel/nvim-smuggler/commit/cef2b4e025ab4f6f2e4b1b4b580f87f56311e3ef))
* **reslime:** set column position correctly for smuggling visual lines. ([37b7d42](https://github.com/Klafyvel/nvim-smuggler/commit/37b7d42269824cb93c2d76aa803d26443b33c383))
* **socket:** Fix default socket directory for MacOS. ([aeaf90f](https://github.com/Klafyvel/nvim-smuggler/commit/aeaf90f093a8e1aefa382cef20035b416cf26d6d))
* **ui:** nil-guard results display. ([8afc63c](https://github.com/Klafyvel/nvim-smuggler/commit/8afc63c20300ca2840a8e2c9dd4748492c8d3703))


### Miscellaneous Chores

* release 0.4 ([3dc71b5](https://github.com/Klafyvel/nvim-smuggler/commit/3dc71b51c4ba837ddad6b70a3b23cc3c48497422))


### Code Refactoring

* **config:** Spearate logging, configuration, and application status. ([50ae13f](https://github.com/Klafyvel/nvim-smuggler/commit/50ae13f8c28953ce45bc0c606e504f7adbdc51f4))
* **ui:** Created a dedicated module for managing the ui. ([cc4e6dd](https://github.com/Klafyvel/nvim-smuggler/commit/cc4e6dda3515aa049d2e0ab9269b815476a319ad))

## [0.3.0](https://github.com/Klafyvel/nvim-smuggler/compare/v0.2.0...v0.3.0) (2024-08-11)


### Features

* **diagnostics:** Include frame number in stacktrace diagnostics ([44722c0](https://github.com/Klafyvel/nvim-smuggler/commit/44722c00b887d4a38ed651d4c8c0f52a401261c2))
* **protocol:** Handle protocol v0.2 (diagnostics in notifications). ([dd8b3e7](https://github.com/Klafyvel/nvim-smuggler/commit/dd8b3e798aba504c40a67b68f4b107a4ac9acd5c))
* **protocol:** Implement protocol v0.3 ([f89e206](https://github.com/Klafyvel/nvim-smuggler/commit/f89e20659bb956e17b7a7cd2cdb4493d6ec53477))
* **send-range:** Make block visal selection work. ([8723d8c](https://github.com/Klafyvel/nvim-smuggler/commit/8723d8ca8af1e4ad680f9951022f41976545e6c9))
* **smuggle-range:** Split visual selection send and range send. ([51bdbff](https://github.com/Klafyvel/nvim-smuggler/commit/51bdbffe8d11c67adc0bf62d27cbd85af90b265f))
* Update release-please.yml ([9fc79fb](https://github.com/Klafyvel/nvim-smuggler/commit/9fc79fb97517b1a28ba35db1398604037b567df2))


### Bug Fixes

* **config:** Make bufconfig use the defined default configuration. ([cebcbc6](https://github.com/Klafyvel/nvim-smuggler/commit/cebcbc6f985ab7b3ed872825ab1ad00491eed443))
* **send-range:** Fix variable closure error when fetching selected text. ([97c7b55](https://github.com/Klafyvel/nvim-smuggler/commit/97c7b5591ce5687664ed8f3d0f8b27e4a0d8d08b))

## [0.2.0](https://github.com/Klafyvel/nvim-smuggler/compare/v0.1.2...v0.2.0) (2024-03-16)


### Features

* add commands to toggle diagnostics. ([4ee73e2](https://github.com/Klafyvel/nvim-smuggler/commit/4ee73e252e355770fbf3f668c3e8b1f8002d4dd0))
* Add demo to README.md ([124cd3d](https://github.com/Klafyvel/nvim-smuggler/commit/124cd3d9f81a9d018132eb87d358ef60c9b9114d))


### Bug Fixes

* Do not create the smuggler.log file when we are not debugging. ([f6465df](https://github.com/Klafyvel/nvim-smuggler/commit/f6465dfc463804571a680da69f83c27aa1a88006))

## [0.1.2](https://github.com/Klafyvel/nvim-smuggler/compare/v0.1.1...v0.1.2) (2024-03-10)


### Bug Fixes

* Line numbering when using the operator mode. ([7510439](https://github.com/Klafyvel/nvim-smuggler/commit/75104394369f76efd995092edd28aeb8da165301))
* remove debug prints. ([48ff11c](https://github.com/Klafyvel/nvim-smuggler/commit/48ff11c7ff88649c72ee8081be1dd9c8c6e1c2b7))

## 0.1.1 (2024-02-28)


### Features

* Support for interrupt and exit. ([83697d5](https://github.com/Klafyvel/nvim-smuggler/commit/83697d5ff81081f282b1d1e44fceba23b36803b9))


### Bug Fixes

* Added the license file to the repository. ([1f875c1](https://github.com/Klafyvel/nvim-smuggler/commit/1f875c143cc62d6c9bdd32749fdc3004dbe33109))
* bufconfig return code is not ignored when sending data. ([80ec83d](https://github.com/Klafyvel/nvim-smuggler/commit/80ec83d87021015312ee86dafe0b2a4ac606bb8a))
* moved nvim-smuggler to its own namespace, and fixed the configuration instructions. ([5d7a5e6](https://github.com/Klafyvel/nvim-smuggler/commit/5d7a5e6bbd1d4ef1d2d804a9f002cf74fa198588))


### Miscellaneous Chores

* release 0.1.1 ([8c95386](https://github.com/Klafyvel/nvim-smuggler/commit/8c9538604a897dad5c5b3b652633ed9fbc92f55c))
