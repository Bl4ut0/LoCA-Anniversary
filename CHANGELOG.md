# Changelog

All notable changes to this project will be documented in this file.

## [1.21] - Custom Spells UI & Array Fixes
### Added
- **Localization**: Added full language scaffolding framework (`AceLocale-3.0`). 100% of the UI and Alerts are now ready to be translated (seeking translators on GitHub!).
- **Multi-Expansion Support**: LoCA now transparently supports all 5 active client platforms: Vanilla, TBC, WotLK, Cataclysm, and Retail.
- **Custom Spells UI**: Added an "Add Custom Spell" interface in the AceConfig `/loca` options menu. Users can now uniquely and permanently track untracked or missing CCs by manually inputting their exact numeric Spell IDs (such as `5530` for Mace Stun) through the game. Custom spells instantly populate a "Remove" button alongside them for complete UI administration.
- **New Default Spells**: Added Mace Stun Effects (`5530` & `34510`) directly into the classic fallback tracker.

### Fixed
- **Missing Categories Bug**: Isolated and completely resolved a loop destruction bug on classic-era client architectures where older invalid default spells (e.g., specific Cataclysm spell mappings) would silently break the IPairs debuff tracking loop, rendering the rest of the major status categories (like stuns and fears) completely invisible to the player during PvP.
- **AceDB Overrides**: Auto-injection added to ensure newly patched default spells safely append themselves without overwriting older customizations of existing Classic users.
