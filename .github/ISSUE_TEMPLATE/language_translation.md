---
name: Language Translation Request
about: Submit a new localization file or language translation fix for Loss of Control Alerter.
title: 'Localization: [Language Name]'
labels: 'localization, enhancement'
assignees: ''

---

**Which language are you translating?**
- [ ] German (deDE)
- [ ] French (frFR)
- [ ] Spanish (esES/esMX)
- [ ] Russian (ruRU)
- [ ] Chinese (zhCN/zhTW)
- [ ] Korean (koKR)
- [ ] Portuguese (ptBR)
- [ ] Italian (itIT)
- [ ] Other: ______

**Are you submitting a Pull Request, or just providing the translated `enUS.lua` text?**
- [ ] I have opened a Pull Request with the new/updated `.lua` file.
- [ ] I am pasting the translated content below.

### Instructions for Translators
1. Find the `LoCA/Locales/enUS.lua` file in the source code.
2. Duplicate it and rename the file to your locale's code (e.g., `deDE.lua`).
3. Inside the new file, change `LibStub("AceLocale-3.0"):NewLocale("LossOfControlAlerter", "enUS", true)` to target your language (e.g., `"deDE"`). You do not need the `true` flag at the end for non-English locales.
4. Translate the strings on the *right* side of the equals sign. Do not alter the keys on the left.
5. Either open a Pull Request with your `.lua` file, or paste its contents directly below!

### Paste Your Translated Code Here (If not opening a PR)
```lua
-- Paste your localized Lua code here...
```
