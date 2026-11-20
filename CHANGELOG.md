# Changelog

All notable changes to this project will be documented in this file.

## [1.23] - 2026-11-20
### Changed
- **Expansion & Interface Updates**: Updated TOC interface versions for **Classic Era (`11509`)**, **TBC Anniversary (`20505`, `20506`)**, and added **`LoCA_Mists.toc` (`50504`)** for Mists of Pandaria Classic.
- **Retail Removal**: Removed `LoCA_Mainline.toc` (Retail and WoW Forever both have built-in Loss of Control alerts and do not need LoCA).
- **Release & CI Automation**: Added `.pkgmeta`, `.tools/`, `package.json`, and GitHub Actions workflow (`curseforge-release.yml`) for automated Lua/structure validation, immutable release packaging, and CurseForge deployment.

### Fixed
- **`C_Spell.GetSpellInfo` Shim**: Updated the `GetSpellInfo` compatibility shim in `LoCA.lua` to unpack the `C_Spell.GetSpellInfo` table into legacy multiple return values on modern Classic/Progression clients where `GetSpellInfo` is absent.

## [1.22] - Base TOC Visibility Fix
### Fixed
- **Addon Visibility**: Restored base `LoCA.toc` file to serve as a universal fallback, fixing an issue where the addon was completely invisible on older expansion clients (like private servers), clients running non-latest patch versions, and certain AddOn managers that don't support flavor-specific TOC files.

## [1.21] - Custom Spells UI & Array Fixes
### Added
- **Localization**: Added full language scaffolding framework (`AceLocale-3.0`). 100% of the UI and Alerts are now ready to be translated (seeking translators on GitHub!).
- **Multi-Expansion Support**: LoCA now transparently supports all 5 active client platforms: Vanilla, TBC, WotLK, Cataclysm, and Retail.
- **Custom Spells UI**: Added an "Add Custom Spell" interface in the AceConfig `/loca` options menu. Users can now uniquely and permanently track untracked or missing CCs by manually inputting their exact numeric Spell IDs (such as `5530` for Mace Stun) through the game. Custom spells instantly populate a "Remove" button alongside them for complete UI administration.
- **New Default Spells**: Added Mace Stun Effects (`5530` & `34510`) directly into the classic fallback tracker.

### Fixed
- **Missing Categories Bug**: Isolated and completely resolved a loop destruction bug on classic-era client architectures where older invalid default spells (e.g., specific Cataclysm spell mappings) would silently break the IPairs debuff tracking loop, rendering the rest of the major status categories (like stuns and fears) completely invisible to the player during PvP.
- **AceDB Overrides**: Auto-injection added to ensure newly patched default spells safely append themselves without overwriting older customizations of existing Classic users.
