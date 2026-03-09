# Loss of Control Alerter (LoCA) - TBC Anniversary Edition

**Loss of Control Alerter (LoCA)** is a lightweight addon that detects and displays Crowd Control (CC) effects on your character. It provides a highly visible, customizable alert showing the type of CC (Stun, Fear, Root, etc.) and its remaining duration.

This repository hosts the updated version compatible with **World of Warcraft: TBC Anniversary (Classic)**.

## Features

*   **Instant Alerts**: Immediately shows an icon and timer when you are hit by CC.
*   **Categories**: Supports all major CC types including:
    *   **Stuns** (Kidney Shot, Hammer of Justice, etc.)
    *   **Fears** (Psychic Scream, Fear)
    *   **Roots** (Entangling Roots, Frost Nova)
    *   **Silences** & **Disarms**
    *   **Polymorphs** & **Cyclones**
*   **Visual Styles**: Choose between:
    *   **Box Style**: A clean, bordered frame (Modern look).
    *   **Default Style**: The classic shadow/glow look.
*   **Lightweight**: Minimal CPU/Memory usage.

## Compatibility

This version has been specifically updated for the **TBC Anniversary (2.5.5)** client.

### Recent Updates
*   **Modern API Support**: logic updated to use `C_UnitAuras` for reliable debuff scanning on the Anniversary engine.
*   **Crash Fixes**: Patched `C_AddOns` and `C_Spell` namespace changes to prevent Lua errors.
*   **Visual Options**: Added a configuration toggle for frame styling.

Provides an audible and visual alert when you acquire a loss of control debuff and also creates a central UI icon with a countdown timer to denote when the CC effect will expire.

## Supported Game Versions
Loss of Control Alerter is designed to function seamlessly across almost all versions of World of Warcraft. Including the following:
- **Retail / Mainline** (`11.0.7`)
- **Cataclysm Classic** (`4.4.0`)
- **Wrath of the Lich King Classic** (`3.4.3`)
- **The Burning Crusade (Anniversary)** (`2.5.5`)
- **Classic Era / SoD / Hardcore** (`1.15.7`)

The codebase automatically utilizes modern C_LossOfControl events if available, and gracefully falls back to combat log parsing for older Classic clients.

## Installation

1.  Download the latest release.
2.  Extract the `LoCA` folder into your WoW AddOns directory:
    *   `_classic_\Interface\AddOns\`
3.  Launch the game.

## Configuration

Type `/loca` or go to **Interface Options -> AddOns -> Loss of Control Alerter**.
*   **Unlock**: Move the alert frame anywhere on your screen.
*   **Test**: Preview the alert to adjust scale and positioning.
*   **Style**: Switch between "Box" and "Default" visuals.
*   **Add Custom Spell**: Dynamically add unsupported or missing abilities (such as `5530` Mace Stun) by inputting their Spell ID directly in the game, categorized exactly how you want. These immediately save to your profile and can be removed later!

## Credits

*   **Original Author**: [Rdmx](https://www.curseforge.com/wow/addons/loca-loss-of-control-alerter-for-tbc-classic)
*   **Anniversary Port**: Updated by the community to support client v2.5.5.

All creative rights belong to the original author. This repository simply serves to provide compatibility for the Anniversary game client.
