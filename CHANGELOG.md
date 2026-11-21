# Changelog

All notable changes to this project will be documented in this file.

## [1.32] - 2026-11-21
### Fixed
- **WoW Forever / Midnight `ADDON_ACTION_FORBIDDEN`**: Stopped registering `COMBAT_LOG_EVENT_UNFILTERED` on clients with `issecretvalue` (WoW Forever `1.60.1` and Retail `12.x`), eliminating the `ADDON_ACTION_FORBIDDEN` error on login/reload.
- **Native `C_LossOfControl` on Forever**: Enabled `retail` mode (`C_LossOfControl`) on non-Mainline clients that provide `C_LossOfControl.GetActiveLossOfControlData` (such as WoW Forever), so school lockouts and Loss of Control events work natively without needing `COMBAT_LOG_EVENT_UNFILTERED`.
- **Combat-Safe Blizzard Frame Hiding**: Removed `EnableMouse` mutation on `LossOfControlFrame` in `UpdateBlizzardFrameVisibility()` so hiding the built-in frame only uses `SetAlpha(0)`.

## [1.31] - 2026-11-20
### Added
- **Hide Blizzard Default Frame**: Added a `Hide Blizzard Default Frame` toggle under `/loca` -> `Debuffs` (visible on Retail and WoW Forever where `LossOfControlFrame` exists) to hide Blizzard's built-in Loss of Control frame in a taint-safe way (`SetAlpha(0)` + `EnableMouse(false)`) while keeping `C_LossOfControl` events active for LoCA.

## [1.30] - 2026-11-20
### Added
- **Recent & Quick Filter Tab**: Auto-captures detected LoC spells/debuffs/interrupts during your session with their icon, name, and Spell ID so you can block or group them with one click—no manual Spell ID lookup required.
- **Per-Spell Blacklist**: Ignore any specific spell in both Retail and Custom modes via the visual Recent list or by Spell ID.
- **Custom Alert Groups**: Create named groups with independent **Enabled** toggles, **Priority/Weight**, and **Scale Override** (e.g., smaller roots or high-priority PvE mechanics).
- **Per-Category Scale**: Added a `Category Scale` multiplier slider to each built-in category (`Movement/Root`, `Silence/Disarm`, `Stun`, `Full`).
- **Non-Blanket Interrupt Lockout Alerts**: Added `COMBAT_LOG_EVENT_UNFILTERED` (`SPELL_INTERRUPT`) tracking in Custom mode so partial/school interrupts display `"<School> Locked"` (e.g., `"Fire Locked"`).
- **Retail & WoW Forever Support**: Re-added `LoCA_Mainline.toc` (`120005, 120105, 120107`) with `issecretvalue` guards for Midnight, and added `LoCA_Camelot.toc` (`16001`) for WoW Forever.

### Fixed
- **Disabled Category Filtering**: Fixed `OnDebuffsChanged` so disabled categories (such as `Movement/Root`) are excluded before selecting the highest-priority alert instead of suppressing lower-priority active debuffs.
- **Options & `/loca` Reliability**: Wrapped `AceConfigDialog:AddToBlizOptions` in `pcall` with an `addonTitle` fallback so `/loca` always registers even if another addon loads an incompatible `AceConfigDialog-3.0`.

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
