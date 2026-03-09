# Technical Changes for TBC Anniversary Edition

This document details the modifications made to port **Loss of Control Alerter (LoCA)** to the **TBC Anniversary Edition (2.5.5)**.

## Overview

The TBC Anniversary Edition runs on a modern WoW client engine (Dragonflight-based), which introduced significant API namespace changes compared to original TBC/Classic. This port adds compatibility shims and logic updates to ensure LoCA functions correctly on this hybrid engine.

---

## API & Namespace Migrations

### 1. Debuff Scanning (Critical)
**File:** `Modules/Debuffs.lua`

The legacy `UnitDebuff` API (and its shim) in the Anniversary client is unreliable and often fails to return expected values or handle the modern debuff limit. We migrated the scanning logic to the modern `C_UnitAuras` system.

```lua
-- Modern / Anniversary Client Logic
if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
    for i = 1, 40 do
        local aura = C_UnitAuras.GetDebuffDataByIndex("player", i)
        -- Parsing aura.name, aura.icon, etc.
    end
else
    -- Fallback for legacy clients
    -- ...
end
```

**Changes:**
- Implementation of `C_UnitAuras.GetDebuffDataByIndex`.
- Increased scan limit from **20** to **40** auras to match modern client capabilities.

### 2. C_AddOns Namespace
**File:** `LoCA.lua`

The global `GetAddOnMetadata` and `LoadAddOn` functions have been deprecated and moved to the `C_AddOns` namespace.

```lua
-- Shim for GetAddOnMetadata
if not GetAddOnMetadata and C_AddOns and C_AddOns.GetAddOnMetadata then
  GetAddOnMetadata = C_AddOns.GetAddOnMetadata
end

-- Shim for LoadAddOn
if not LoadAddOn and C_AddOns and C_AddOns.LoadAddOn then
  LoadAddOn = C_AddOns.LoadAddOn
end
```

### 3. C_Spell Namespace
**File:** `LoCA.lua`

`GetSpellInfo` has moved to `C_Spell` in modern retailers, so a prophylactic shim was added to ensure stability across version updates.

```lua
if not GetSpellInfo and C_Spell and C_Spell.GetSpellInfo then
  GetSpellInfo = C_Spell.GetSpellInfo
end
```

---

## Visual Updates

### Backdrop & Styling
**File:** `Modules/Debuffs.lua`

To address visual artifacts and allow for cleaner UI integration, a new **Style Toggle** was implemented.

1.  **Box Style (New Default):** Uses a `BackdropTemplate`-based frame standardizing the look with WoW's Tooltip style (Border + Semi-transparent background).
2.  **Texture Style (Classic):** Retains the original internal shadow texture logic for users preferring the legacy appearance.

**Implementation:**
- Added `BackdropTemplate` inheritance to frames: `CreateFrame(..., BackdropTemplateMixin and "BackdropTemplate")`.
- Added dynamic toggling logic in `UpdateContainer` to switch visibility between `bgFrame` (Box) and `backgroundTexture` (Texture).

---

## Configuration

**File:** `LoCA_TBC.toc`
- Created specific TOC for Interface **20504** (TBC Anniversary).
- **Default Mode:** Forced logic in `OnInitialize` to default the addon to **"Custom"** mode on Classic clients, preventing the "Retail" mode (which relies on `LOSS_OF_CONTROL_ADDED` events not present in Classic) from causing errors.

---

## Technical Bug Fixes & User Input Enhancements

### 1. `ipairs` Array Destruction Fix (Classic Engine)
**File:** `Modules/Debuffs.lua`

In legacy expansions (like Classic/TBC), spells from newer expansions included in the addon’s defaults table (e.g., Cataclysm spells) naturally failed the `GetSpellInfo(spellId)` lookup.
Previously, the addon removed invalid spells by setting their index in the tracking array to `nil`. In Lua, removing indices this way creates a "hole" in the array. Since the addon iterated across the debuffs using `ipairs`, checking would immediately halt at the first hole, abandoning all subsequent default spells and resulting in **missing states/categories** (e.g. tracking only 1 out of 4 effect types).
The array map generation was rewritten to securely pack validated spells continuously via `table.insert()`, ensuring 100% stable tracking execution on all client patches.

### 2. Dynamic AceConfig "Custom Spell" Injection
**File:** `Modules/Debuffs.lua`

Older WoW clients lack the modern `LOSS_OF_CONTROL_ADDED` hook, so they rely on a hardcoded list of `spellId` numbers to detect CC.
To prevent users from having to repeatedly edit `LoCA.lua` when they discover untracked spells, a dynamic user-input interface was built into the `AceConfig` generated panel:
- `tempInputSpellId` & `tempInputCategory`: Temporarily stores typed inputs (Spell IDs and weight types) before validation.
- Validation validates that the Spell ID actually maps to a real spell using the game engine before successfully binding.
- New entries flag `isCustomUserAdded = true`, signaling the UI list generator (`CreateDebuffUIList()`) to dynamically inject a **Remove (Delete)** `execute` button adjacent to that spell in the interface.
- Modified lists are packed into `AceDB-3.0` and force-refreshed instantly via `AceConfigRegistry-3.0:NotifyChange(addonName)`.
