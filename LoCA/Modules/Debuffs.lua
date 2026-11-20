local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale("LossOfControlAlerter")
local locaDebuffs = addon.CreateDebuffs()

local container
local isLocked = true
local issecretvalue = _G.issecretvalue

local function IsSecret(v)
  return issecretvalue and issecretvalue(v)
end

local INTERRUPT_DURATIONS = {
  [72] = 6,     -- Shield Bash
  [1766] = 5,   -- Kick
  [2139] = 8,   -- Counterspell
  [6552] = 4,   -- Pummel
  [8042] = 2,   -- Earth Shock
  [16979] = 4,  -- Feral Charge
  [19244] = 6,  -- Spell Lock (Rank 1)
  [19647] = 6,  -- Spell Lock (Rank 2)
  [47528] = 4,  -- Mind Freeze
  [57994] = 2,  -- Wind Shear
  [78675] = 8,  -- Solar Beam
  [96231] = 4,  -- Rebuke
  [116705] = 4, -- Spear Hand Strike
}

local sessionSeenSpells = {}
local activeInterruptLockout = nil
local initializedDebuffs = {}
local initializedDebuffsById = {}
local iconFrame
local activeScaleOverride = nil

local LOC_TYPE_MAP = {
  ROOT = 1,
  SCHOOL_INTERRUPT = 2,
  DISARM = 2,
  PACIFYSILENCE = 2,
  SILENCE = 2,
  STUN_MECHANIC = 3,
  PACIFY = 3,
  STUN = 4,
  FEAR = 4,
  FEAR_MECHANIC = 4,
  CHARM = 4,
  CONFUSE = 4,
  POSSESS = 4,
}

locaDebuffs.options = {
  type = "group",
  name = L["Debuffs"],
  args = {
    lock = {
      order = 1,
      name = function() if isLocked then return L["Unlock"] else return L["Lock"] end end,
      type = "execute",
      desc = L["Unlock/Lock the alerts for movement"],
      func = function()
        if isLocked then
          locaDebuffs:Unlock()
        else
          locaDebuffs:Lock()
        end
      end,
      width = 0.5
    },
    test = {
      order = 2,
      name = L["Test"],
      type = "execute",
      desc = L["Shows a fake alert for testing the look"],
      func = function()
        locaDebuffs:RunTest()
      end,
      width = 0.5
    },
    break1 = {
      order = 3,
      type = "header",
      name = L["Visuals"]
    },
    scale = {
      order = 4,
      name = L["Scale"],
      type = "range",
      min = 0.1,
      max = 3,
      step = 0.1,
      bigStep = 0.1,
      get = function(info) return locaDebuffs:GetScale(info) end,
      set = function(info, val) locaDebuffs:SetScale(info, val) end
    },
    alpha = {
      order = 5,
      name = L["Alpha"],
      type = "range",
      min = 0.1,
      max = 1,
      step = 0.1,
      bigStep = 0.1,
      get = function(info) return locaDebuffs:GetAlpha(info) end,
      set = function(info, val) locaDebuffs:SetAlpha(info, val) end
    },
    break2 = {
      order = 6,
      type = "header",
      name = ""
    },
    showRedLines = {
      order = 7,
      type = "toggle",
      name = L["Show Red Lines"],
      width = "full",
      get = function(info) return locaDebuffs.db.showRedLines end,
      set = function(info, val) locaDebuffs:SetShowRedLines(val) end,
    },
    showBackground = {
      order = 8,
      type = "toggle",
      name = L["Show Background"],
      width = "full",
      get = function(info) return locaDebuffs.db.showBackground end,
      set = function(info, val) locaDebuffs:SetShowBackground(val) end,
    },
    style = {
      order = 9,
      name = L["Style"],
      type = "select",
      style = "dropdown",
      values = {
        box = L["Box (New)"],
        texture = L["Default (Original)"]
      },
      get = function(info) return locaDebuffs.db.style end,
      set = function(info, val) locaDebuffs.db.style = val; locaDebuffs:UpdateContainer() end
    },
    showSecondsLabel = {
      order = 10,
      type = "toggle",
      name = L["Show Seconds Label"],
      width = "full",
      get = function(info) return locaDebuffs.db.showSecondsLabel end,
      set = function(info, val) locaDebuffs:SetShowSecondsLabel(val) end,
    },
    hideBlizzardFrame = {
      order = 10.5,
      type = "toggle",
      name = L["Hide Blizzard Default Frame"],
      desc = L["Hides Blizzard's built-in Loss of Control frame (Retail / Forever) so only LoCA is shown."],
      width = "full",
      hidden = function() return not _G.LossOfControlFrame end,
      get = function(info) return locaDebuffs.db.hideBlizzardFrame end,
      set = function(info, val)
        locaDebuffs.db.hideBlizzardFrame = val
        locaDebuffs:UpdateBlizzardFrameVisibility()
      end,
    },
    debuffCategories = {
      order = 11,
      type = "group",
      name = L["Tracked Categories"],
      childGroups = "select",
      args = {
        header = {
          order = 1,
          type = "header",
          name = L["Tracked Categories"]
        },
        description = {
          order = 2,
          type = "description",
          name = L["Enable/disable whole categories from being showed"]
        },
        break1 = {
          order = 3,
          type = "header",
          name = ""
        },
        root = {
          order = 4,
          type = "toggle",
          name = L["Movement/Root"],
          get = function(info) return locaDebuffs.db.types[1].active end,
          set = function(info, val) locaDebuffs.db.types[1].active = val; locaDebuffs:NotifyUpdate() end
        },
        rootScale = {
          order = 5,
          type = "range",
          name = L["Category Scale"],
          desc = L["Scale multiplier for this category (1.0 = default)."],
          min = 0.3,
          max = 2.0,
          step = 0.1,
          get = function(info) return locaDebuffs.db.types[1].scale or 1 end,
          set = function(info, val) locaDebuffs.db.types[1].scale = val; locaDebuffs:UpdateContainer() end
        },
        silence = {
          order = 6,
          type = "toggle",
          name = L["Silence/Disarm"],
          get = function(info) return locaDebuffs.db.types[2].active end,
          set = function(info, val) locaDebuffs.db.types[2].active = val; locaDebuffs:NotifyUpdate() end
        },
        silenceScale = {
          order = 7,
          type = "range",
          name = L["Category Scale"],
          desc = L["Scale multiplier for this category (1.0 = default)."],
          min = 0.3,
          max = 2.0,
          step = 0.1,
          get = function(info) return locaDebuffs.db.types[2].scale or 1 end,
          set = function(info, val) locaDebuffs.db.types[2].scale = val; locaDebuffs:UpdateContainer() end
        },
        stun = {
          order = 8,
          type = "toggle",
          name = L["Stun"],
          get = function(info) return locaDebuffs.db.types[3].active end,
          set = function(info, val) locaDebuffs.db.types[3].active = val; locaDebuffs:NotifyUpdate() end
        },
        stunScale = {
          order = 9,
          type = "range",
          name = L["Category Scale"],
          desc = L["Scale multiplier for this category (1.0 = default)."],
          min = 0.3,
          max = 2.0,
          step = 0.1,
          get = function(info) return locaDebuffs.db.types[3].scale or 1 end,
          set = function(info, val) locaDebuffs.db.types[3].scale = val; locaDebuffs:UpdateContainer() end
        },
        full = {
          order = 10,
          type = "toggle",
          name = L["Full"],
          get = function(info) return locaDebuffs.db.types[4].active end,
          set = function(info, val) locaDebuffs.db.types[4].active = val; locaDebuffs:NotifyUpdate() end
        },
        fullScale = {
          order = 11,
          type = "range",
          name = L["Category Scale"],
          desc = L["Scale multiplier for this category (1.0 = default)."],
          min = 0.3,
          max = 2.0,
          step = 0.1,
          get = function(info) return locaDebuffs.db.types[4].scale or 1 end,
          set = function(info, val) locaDebuffs.db.types[4].scale = val; locaDebuffs:UpdateContainer() end
        }
      }
    },
    recentSpells = {
      order = 12,
      type = "group",
      name = L["Recent & Quick Filter"],
      args = {},
    },
    blacklist = {
      order = 13,
      type = "group",
      name = L["Blacklist"],
      args = {},
    },
    customGroups = {
      order = 14,
      type = "group",
      name = L["Custom Groups"],
      args = {},
    },
    addCustomDebuff = {
      order = 15,
      type = "group",
      name = L["Add Custom Spell"],
      hidden = function() return locaDebuffs.db.mode ~= "custom" end,
      disabled = function() return locaDebuffs.db.mode ~= "custom" end,
      args = {
        header = {
          order = 1,
          type = "header",
          name = L["Add Missing Spell"],
        },
        desc = {
          order = 2,
          type = "description",
          name = L["If a spell is missing from the default tracker (such as specific stuns or roots in Classic/TBC), enter the exact numeric Spell ID found on websites like Wowhead.\n\nType the Spell ID below, pick a category, and click Add."],
        },
        spellIdInput = {
          order = 3,
          type = "input",
          name = L["Spell ID:"],
          desc = L["Enter a numeric Spell ID (e.g., 5530 for Mace Stun)."],
          get = function(info) return locaDebuffs.tempInputSpellId or "" end,
          set = function(info, val) locaDebuffs.tempInputSpellId = val end,
        },
        categoryDropdown = {
          order = 4,
          type = "select",
          name = L["Loss of Control Type"],
          values = {
            [1] = L["Movement / Root"],
            [2] = L["Silence / Disarm"],
            [3] = L["Stun"],
            [4] = L["Full (Fear/Polymorph/Etc)"]
          },
          get = function(info) return locaDebuffs.tempInputCategory or 3 end,
          set = function(info, val) locaDebuffs.tempInputCategory = val end,
        },
        addButton = {
          order = 5,
          type = "execute",
          name = L["Add Spell"],
          func = function() locaDebuffs:AddCustomSpell() end,
        }
      }
    },
    debuffList = {
      order = 16,
      type = "group",
      name = L["Tracked Debuffs"],
      childGroups = "select",
      hidden = function() return locaDebuffs.db.mode ~= "custom" end,
      disabled = function() return locaDebuffs.db.mode ~= "custom" end,
      args = {},
    }
  }
}

local TIME_COMPARISON_THRESHOLD = 0.1

local function RecordSeenSpell(spellId, name, icon, category)
  if not spellId or IsSecret(spellId) or type(spellId) ~= "number" or spellId <= 0 then
    return
  end
  if not name or IsSecret(name) or type(name) ~= "string" then
    name = "Spell #" .. tostring(spellId)
  end
  if IsSecret(icon) then
    icon = nil
  end
  if not icon then
    local _, _, fetchedIcon = GetSpellInfo(spellId)
    icon = fetchedIcon or 134400
  end
  if not sessionSeenSpells[spellId] then
    sessionSeenSpells[spellId] = {
      spellId = spellId,
      name = name,
      icon = icon,
      category = (not IsSecret(category) and category) or "",
      lastSeen = GetTime(),
    }
    if locaDebuffs.RefreshRecentSpellsUI then
      locaDebuffs:RefreshRecentSpellsUI()
    end
  else
    sessionSeenSpells[spellId].lastSeen = GetTime()
  end
end

local function IsSpellBlacklisted(spellId)
  if not spellId or IsSecret(spellId) or not locaDebuffs.db or not locaDebuffs.db.blacklist then
    return false
  end
  return locaDebuffs.db.blacklist[spellId] ~= nil
end

local function FindCustomGroupForSpell(spellId)
  if not spellId or IsSecret(spellId) or not locaDebuffs.db or not locaDebuffs.db.customGroups then
    return nil, nil
  end
  for groupId, group in pairs(locaDebuffs.db.customGroups) do
    if type(group) == "table" and group.spells and group.spells[spellId] then
      return groupId, group
    end
  end
  return nil, nil
end

local function ResolveEffectiveAlertConfig(spellId, defaultWeight, defaultType)
  if IsSpellBlacklisted(spellId) then
    return nil
  end

  local _, customGroup = FindCustomGroupForSpell(spellId)
  if customGroup then
    if not customGroup.active then
      return nil
    end
    local catType = defaultType or 4
    return {
      active = true,
      weight = customGroup.weight or defaultWeight or 3,
      type = catType,
      scale = (customGroup.overrideScale and customGroup.scale) or nil,
    }
  end

  local catType = defaultType or 4
  local cat = locaDebuffs.db and locaDebuffs.db.types and locaDebuffs.db.types[catType]
  if cat and not cat.active then
    return nil
  end

  return {
    active = true,
    weight = defaultWeight or 3,
    type = catType,
    scale = (cat and cat.scale) or 1,
  }
end

function locaDebuffs:OnCombatLogEvent()
  if not CombatLogGetCurrentEventInfo then return end
  local _, subevent, _, _, _, _, _, destGUID, _, _, _, spellId, spellName, _, _, _, extraSchool = CombatLogGetCurrentEventInfo()
  if subevent ~= "SPELL_INTERRUPT" then return end
  if destGUID ~= UnitGUID("player") then return end

  local duration = INTERRUPT_DURATIONS[spellId] or 4
  local schoolText = (extraSchool and GetSchoolString and GetSchoolString(extraSchool)) or nil
  local displayText = schoolText and string.format("%s Locked", schoolText) or "School Locked"
  local _, _, icon = GetSpellInfo(spellId or 2139)

  RecordSeenSpell(spellId, spellName or displayText, icon, displayText)

  activeInterruptLockout = {
    spellId = spellId or 2139,
    name = displayText,
    icon = icon or 134400,
    weight = 2,
    category = displayText,
    type = 2,
    expiresAt = GetTime() + duration,
  }

  locaDebuffs:OnDebuffsChanged()
end

function locaDebuffs:OnDebuffsChanged()
  local candidatesForActivation = {}
  local candidateDurations = {}
  local now = GetTime()

  -- Evaluate active non-blanket school lockout from combat log
  if activeInterruptLockout then
    if activeInterruptLockout.expiresAt > now then
      local resolved = ResolveEffectiveAlertConfig(activeInterruptLockout.spellId, activeInterruptLockout.weight, activeInterruptLockout.type)
      if resolved then
        local lockoutCandidate = {
          spellId = activeInterruptLockout.spellId,
          name = activeInterruptLockout.name,
          icon = activeInterruptLockout.icon,
          weight = resolved.weight,
          category = activeInterruptLockout.category,
          type = resolved.type,
          scaleOverride = resolved.scale,
        }
        table.insert(candidatesForActivation, lockoutCandidate)
        table.insert(candidateDurations, activeInterruptLockout.expiresAt - now)
      end
    else
      activeInterruptLockout = nil
    end
  end

  local function evaluateAura(name, icon, expirationTime, spellId)
    if not name or IsSecret(name) then return end
    local durationLeft = 0
    if expirationTime and not IsSecret(expirationTime) and expirationTime > 0 then
      durationLeft = expirationTime - now
    end

    local safeSpellId = (spellId and not IsSecret(spellId)) and spellId or nil
    local debuffIcon = (safeSpellId and initializedDebuffsById[safeSpellId]) or initializedDebuffs[name]

    if safeSpellId then
      RecordSeenSpell(safeSpellId, name, icon, debuffIcon and debuffIcon.category or "")
    end

    if debuffIcon and debuffIcon.active then
      local resolved = ResolveEffectiveAlertConfig(debuffIcon.spellId or safeSpellId, debuffIcon.weight, debuffIcon.type)
      if resolved then
        local candidate = {
          spellId = debuffIcon.spellId,
          name = debuffIcon.name,
          icon = debuffIcon.icon or (not IsSecret(icon) and icon),
          weight = resolved.weight,
          category = debuffIcon.category,
          type = resolved.type,
          scaleOverride = resolved.scale,
        }
        table.insert(candidatesForActivation, candidate)
        table.insert(candidateDurations, durationLeft)
      end
    elseif safeSpellId then
      -- Allow spells assigned to an active Custom Group even if not in debuffsTable
      local _, customGroup = FindCustomGroupForSpell(safeSpellId)
      if customGroup and customGroup.active and not IsSpellBlacklisted(safeSpellId) then
        local candidate = {
          spellId = safeSpellId,
          name = name,
          icon = (not IsSecret(icon) and icon) or 134400,
          weight = customGroup.weight or 3,
          category = customGroup.name or name,
          type = 4,
          scaleOverride = (customGroup.overrideScale and customGroup.scale) or nil,
        }
        table.insert(candidatesForActivation, candidate)
        table.insert(candidateDurations, durationLeft)
      end
    end
  end

  -- Use C_UnitAuras if available (Modern/Anniversary Client), otherwise fallback to UnitDebuff
  if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
    for i = 1, 40 do
      local aura = C_UnitAuras.GetDebuffDataByIndex("player", i)
      if not aura then break end
      evaluateAura(aura.name, aura.icon, aura.expirationTime, aura.spellId)
    end
  elseif UnitDebuff then
    -- Legacy / Fallback
    for i = 1, 40 do
      local name, _, icon, _, _, expirationTime, _, _, _, spellId = UnitDebuff("player", i)
      if not name then break end
      evaluateAura(name, icon, expirationTime, spellId)
    end
  end

  local maxDuration = -1
  local targetIndex = 0
  local maxWeight = 0

  for idx, candidateDuration in ipairs(candidateDurations) do
    local candidateWeight = candidatesForActivation[idx].weight

    if candidateWeight > maxWeight then
      maxDuration = candidateDuration
      targetIndex = idx
      maxWeight = candidateWeight
    elseif candidateWeight == maxWeight then
      if candidateDuration > maxDuration then
        maxDuration = candidateDuration
        targetIndex = idx
        maxWeight = candidateWeight
      end
    end
  end

  locaDebuffs:ActivateNewDebuff(candidatesForActivation[targetIndex], candidateDurations[targetIndex])
end

function locaDebuffs:OnLossOfControlEvent(locData, eventIndex)
  if not locData then return end
  local locType = locData.locType
  local spellID = locData.spellID
  local text = locData.displayText
  local iconTexture = locData.iconTexture
  local timeRemaining = locData.timeRemaining
  local lockoutSchool = locData.lockoutSchool
  local priority = locData.priority

  if text then
    if not IsSecret(locType) and locType == "SCHOOL_INTERRUPT" then
      if lockoutSchool and not IsSecret(lockoutSchool) and lockoutSchool ~= 0 and GetSchoolString then
        text = string.format("%s Locked", GetSchoolString(lockoutSchool))
      end
    end

    local mappedType = (not IsSecret(locType) and LOC_TYPE_MAP[locType]) or 4
    local safeWeight = (not IsSecret(priority) and type(priority) == "number") and priority or mappedType
    local safeSpellId = (not IsSecret(spellID) and type(spellID) == "number") and spellID or nil

    if safeSpellId then
      RecordSeenSpell(safeSpellId, text, iconTexture, text)
    end

    local resolved = ResolveEffectiveAlertConfig(safeSpellId, safeWeight, mappedType)
    if not resolved then
      return
    end

    -- make a fake debuff configuration object
    local debuffConfiguration = {
      spellId = safeSpellId or 0,
      name = text,
      icon = iconTexture,
      weight = resolved.weight,
      category = text,
      type = resolved.type,
      scaleOverride = resolved.scale,
    }

    local safeTimeRemaining = (not IsSecret(timeRemaining) and type(timeRemaining) == "number") and timeRemaining or nil

    if not iconFrame.active or debuffConfiguration.weight > iconFrame.weight then
      locaDebuffs:ActivateNewDebuff(debuffConfiguration, safeTimeRemaining)
    elseif iconFrame.active and debuffConfiguration.weight == iconFrame.weight and (safeTimeRemaining == nil or not iconFrame.timeLeft or safeTimeRemaining > iconFrame.timeLeft) then
      locaDebuffs:ActivateNewDebuff(debuffConfiguration, safeTimeRemaining)
    end
  end
end

function locaDebuffs:OnLossOfControlUpdate(locData)
  if locData then
    local spellID = locData.spellID
    local sameSpell = (not IsSecret(spellID)) and (spellID == iconFrame.spellId)
    if iconFrame.active and not sameSpell then
      locaDebuffs:DeactivateDebuff()
    end
    locaDebuffs:OnLossOfControlEvent(locData)
  else
    locaDebuffs:DeactivateDebuff()
  end
end

function locaDebuffs:LoadPosition()
  if locaDebuffs.db.position then
    container:SetPoint(locaDebuffs.db.position.point, UIParent, locaDebuffs.db.position.relativePoint, locaDebuffs.db.position.xOfs, locaDebuffs.db.position.yOfs)
  else
    container:SetPoint("CENTER", UIParent, "CENTER")
  end
end

function locaDebuffs:SavePosition()
  local point, _, relativePoint, xOfs, yOfs = container:GetPoint()

  if not locaDebuffs.db.position then 
    locaDebuffs.db.position = {}
  end

  locaDebuffs.db.position.point = point
  locaDebuffs.db.position.relativePoint = relativePoint
  locaDebuffs.db.position.xOfs = xOfs
  locaDebuffs.db.position.yOfs = yOfs
end

function locaDebuffs:CreateContainerFrame()
  container = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
  container:SetMovable(false)
  container:SetWidth(160)
  container:SetBackdrop({
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  container:SetBackdropBorderColor(0.4, 1, 0.4, 0)
  container:SetHeight(50)
  container:SetClampedToScreen(true) 
  container:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then self:StartMoving() end end)
  container:SetScript("OnMouseUp", function(self, button) if button == "LeftButton" then self:StopMovingOrSizing() locaDebuffs:SavePosition() end end)
  container:EnableMouse(false)
  container:Show()
  container:SetPoint("CENTER", UIParent, "CENTER")
end

local blizzardFrameHooked = false

function locaDebuffs:UpdateBlizzardFrameVisibility()
  local blizzFrame = _G.LossOfControlFrame
  if not blizzFrame then return end

  if not blizzardFrameHooked and blizzFrame.HookScript then
    blizzardFrameHooked = true
    blizzFrame:HookScript("OnShow", function(self)
      if locaDebuffs.db and locaDebuffs.db.hideBlizzardFrame then
        self:SetAlpha(0)
        if self.EnableMouse then
          self:EnableMouse(false)
        end
      end
    end)
  end

  if locaDebuffs.db and locaDebuffs.db.hideBlizzardFrame then
    blizzFrame:SetAlpha(0)
    if blizzFrame.EnableMouse then
      blizzFrame:EnableMouse(false)
    end
  else
    blizzFrame:SetAlpha(1)
    if blizzFrame.EnableMouse then
      blizzFrame:EnableMouse(true)
    end
  end
end

function locaDebuffs:UpdateContainer()
  local mult = activeScaleOverride or 1
  container:SetScale((locaDebuffs.db.scale or 1) * mult)
  container:SetAlpha(locaDebuffs.db.alpha)
  locaDebuffs:UpdateBlizzardFrameVisibility()

  if locaDebuffs.db.showSecondsLabel then
    iconFrame.secondsText:Show()
  else
    iconFrame.secondsText:Hide()
  end
  
  if locaDebuffs.db.showRedLines then
    iconFrame.redLineTop:Show()
    iconFrame.redLineBottom:Show()
    -- Reverted to default texture; no color application needed here
  else
    iconFrame.redLineTop:Hide()
    iconFrame.redLineBottom:Hide()
  end

  if locaDebuffs.db.showBackground then
    if locaDebuffs.db.style == "texture" then
      iconFrame.bgFrame:Hide()
      iconFrame.backgroundTexture:Show()
    else
      -- Default to "box"
      iconFrame.bgFrame:Show()
      iconFrame.backgroundTexture:Hide()
    end
  else
    iconFrame.bgFrame:Hide()
    iconFrame.backgroundTexture:Hide()
  end
end

function locaDebuffs:OnInitialize(db)

  locaDebuffs.db = db
  locaDebuffs.db.blacklist = locaDebuffs.db.blacklist or {}
  locaDebuffs.db.customGroups = locaDebuffs.db.customGroups or {}
  if locaDebuffs.db.types then
    for i = 1, 4 do
      if locaDebuffs.db.types[i] and locaDebuffs.db.types[i].scale == nil then
        locaDebuffs.db.types[i].scale = 1
      end
    end
  end

  locaDebuffs:CreateContainerFrame()

  local defaultDebuffs = addon.defaultSettings.profile.debuffs.debuffsTable

  -- Ensure any default debuffs missing from the user's DB are added
  local userDebuffIds = {}
  for k, debuff in pairs(locaDebuffs.db.debuffsTable) do
    if type(k) == "number" and type(debuff) == "table" and debuff.spellId then
      userDebuffIds[debuff.spellId] = true
    end
  end

  for _, defaultDebuff in ipairs(defaultDebuffs) do
    if not userDebuffIds[defaultDebuff.spellId] then
      table.insert(locaDebuffs.db.debuffsTable, {
        spellId = defaultDebuff.spellId,
        category = defaultDebuff.category,
        weight = defaultDebuff.weight,
        active = defaultDebuff.active,
        type = defaultDebuff.type
      })
    end
  end

  -- Pack the array safely without holes and filter out invalid spells
  local validDebuffs = {}
  for k, debuff in pairs(locaDebuffs.db.debuffsTable) do
    if type(k) == "number" and type(debuff) == "table" then
      local name, _, spellicon = GetSpellInfo(debuff.spellId)
      if name then
        debuff.name = name
        debuff.icon = spellicon
        initializedDebuffs[name] = debuff
        if debuff.spellId then
          initializedDebuffsById[debuff.spellId] = debuff
        end
        table.insert(validDebuffs, debuff)
      end
    end
  end

  -- Replace the db table completely with our cleaned, sequential array
  locaDebuffs.db.debuffsTable = validDebuffs

  iconFrame = locaDebuffs:CreateIcon()

  locaDebuffs.options.args.debuffList.args = locaDebuffs:CreateDebuffUIList()
  locaDebuffs:RefreshRecentSpellsUI()
  locaDebuffs:RefreshBlacklistUI()
  locaDebuffs:RefreshCustomGroupsUI()

  locaDebuffs:OnUpdateSettings()
end

function locaDebuffs:CreateIcon(debuff)
  local btn = CreateFrame("Frame", nil, container)
  btn:SetWidth(40)
  btn:SetHeight(40)
  btn:SetFrameStrata("LOW")
  btn:SetPoint("LEFT", container, "LEFT", 8, 0)

  local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
  cd.noomnicc = true
  cd.noCooldownCount = true
  cd:SetAllPoints(true)
  cd:SetFrameStrata("LOW")
  cd:SetUseCircularEdge(true)
  cd:SetSwipeColor(0.17, 0, 0, 0.8)
  if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    cd:SetEdgeTexture("Interface\\Cooldown\\edge-LoC.blp")
  else
    cd:SetEdgeTexture("Interface\\Cooldown\\edge")
  end
  cd:SetHideCountdownNumbers(true)

  local texture = btn:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(true)

  -- Style 1: Texture (Original)
  local backgroundTexture = btn:CreateTexture(nil, "BACKGROUND")
  if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    backgroundTexture:SetTexture("Interface\\Cooldown\\LoC-ShadowBG")
  else
    backgroundTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
  end
  backgroundTexture:SetPoint("BOTTOM", container, "BOTTOM", 0, 0)
  backgroundTexture:SetWidth(160)
  backgroundTexture:SetHeight(50)
  backgroundTexture:SetVertexColor(1, 1, 1, 0.6)

  -- Style 2: Box (New)
  local bgFrame = CreateFrame("Frame", nil, btn, BackdropTemplateMixin and "BackdropTemplate")
  bgFrame:SetPoint("BOTTOM", container, "BOTTOM", 0, 0)
  bgFrame:SetSize(160, 50)
  bgFrame:SetFrameLevel(btn:GetFrameLevel() == 0 and 1 or btn:GetFrameLevel()) 
  
  bgFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  bgFrame:SetBackdropColor(0, 0, 0, 0.7) 
  bgFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

  local redLineTop = btn:CreateTexture(nil, "BACKGROUND")
  redLineTop:SetTexture("Interface\\Cooldown\\Loc-RedLine")
  redLineTop:SetWidth(160)
  redLineTop:SetHeight(27)
  redLineTop:SetPoint("BOTTOM", container, "TOP", 0, 0)

  local redLineBottom = btn:CreateTexture(nil, "BACKGROUND")
  redLineBottom:SetTexture("Interface\\Cooldown\\Loc-RedLine")
  redLineBottom:SetWidth(160)
  redLineBottom:SetHeight(27)
  redLineBottom:SetTexCoord(0, 1, 1, 0)
  redLineBottom:SetPoint("TOP", container, "BOTTOM", 0, 0)

  local debuffTitle = btn:CreateFontString(nil, "ARTWORK")
  debuffTitle:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
  debuffTitle:SetTextColor(1, 1, 0, 1)
  debuffTitle:SetPoint("LEFT", btn, "RIGHT", 6, 8)

  local text = btn:CreateFontString(nil, "ARTWORK")
  text:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
  text:SetTextColor(1, 1, 1, 1)
  text:SetPoint("LEFT", btn, "RIGHT", 6, -10)

  local secondsText = btn:CreateFontString(nil, "ARTWORK")
  secondsText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
  secondsText:SetTextColor(1, 1, 1, 1)
  secondsText:SetPoint("LEFT", btn, "RIGHT", 36, -10)
  secondsText:SetText("seconds")

  btn.text = text
  btn.secondsText = secondsText
  btn.textureIcon = texture
  btn.cd = cd
  btn.redLineBottom = redLineBottom
  btn.redLineTop = redLineTop
  btn.debuffTitle = debuffTitle
  btn.bgFrame = bgFrame
  btn.backgroundTexture = backgroundTexture

  btn.spellId = 0
  btn.name = ""
  btn.weight = 0
  btn.duration = 0

  btn.activate = function(debuff, timeLeft)
    if btn.active then return end
    
    btn.spellId = debuff.spellId
    btn.name = debuff.name
    btn.weight = debuff.weight
    btn.active = true

    btn.textureIcon:SetTexture(debuff.icon)
    btn.debuffTitle:SetText(debuff.category)

    activeScaleOverride = debuff.scaleOverride
    locaDebuffs:UpdateContainer()

    container:SetBackdropColor(0, 0, 0, 0.4)
    btn:Show()
    if timeLeft then
      btn.cd:Show()
      btn.cd:SetCooldown(GetTime(), timeLeft)
      btn.text:Show()
      btn.start = GetTime()
      btn.duration = timeLeft
      btn.settimeleft(timeLeft)
      btn:SetScript("OnUpdate", function(self) locaDebuffs:OnUpdateTimer(self) end)

      btn.secondsText:SetPoint("LEFT", btn, "RIGHT", 6 + btn.text:GetStringWidth(), -10)
      btn.secondsText:Show()
    else
      btn.cd:Hide()
      btn.text:Hide()
      btn.secondsText:Hide()
    end
  end

  -- called to hide stop the frame
  btn.deactivate = function()
    if not btn.active then return end
    activeScaleOverride = nil
    locaDebuffs:UpdateContainer()
    container:SetBackdropColor(0, 0, 0, 0)
    btn:Hide()
    btn.text:SetText("")
    btn.cd:Hide()
    btn:SetScript("OnUpdate", nil)
    btn.active = false
  end

  btn.settimeleft = function(timeleft)
    btn.timeLeft = timeleft
    btn.text:Show()
    btn.text:SetFormattedText("%.1f", timeleft)

    -- set smaller font if the time left is too big, so it can fit in the icon
    if timeleft > 60 then
      btn.text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    else
      btn.text:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    end
  end

  btn:Hide()

  btn:SetPoint("CENTER", container, "CENTER", 0, 0)

  return btn
end

function locaDebuffs:ActivateNewDebuff(newDebuff, durationLeft)
  if not newDebuff then
    locaDebuffs:DeactivateDebuff()
    return
  end

  local resolved = ResolveEffectiveAlertConfig(newDebuff.spellId, newDebuff.weight, newDebuff.type)
  if not resolved then
    locaDebuffs:DeactivateDebuff()
    return
  end
  if newDebuff.scaleOverride == nil then
    newDebuff.scaleOverride = resolved.scale
  end

  if iconFrame.active then
    -- if the spell has the same time remaining or no duration, there's no need to update it
    if iconFrame.spellId == newDebuff.spellId and (not iconFrame.timeLeft or not durationLeft or math.abs(iconFrame.timeLeft - durationLeft) < TIME_COMPARISON_THRESHOLD) then
      return
    end
    locaDebuffs:DeactivateDebuff()
  end

  iconFrame.activate(newDebuff, durationLeft)
end

function locaDebuffs:DeactivateDebuff()
  if iconFrame.active then
    iconFrame.deactivate()
  end
end

function locaDebuffs:OnUpdateTimer(self)
  local cooldown = self.start + self.duration - GetTime()
  if cooldown <= 0 then
    if activeInterruptLockout and activeInterruptLockout.expiresAt <= GetTime() then
      activeInterruptLockout = nil
    end
    locaDebuffs:DeactivateDebuff()
  else
    self.settimeleft(cooldown)
  end
end

function locaDebuffs:RunTest()
  local name, _, spellicon = GetSpellInfo(8643)
  RecordSeenSpell(8643, name or "Kidney Shot", spellicon, "Stunned")

  local testDebuff = {
    spellId = 8643,
    name = name or "Kidney Shot",
    icon = spellicon or 132298,
    weight = 3,
    category = "Stunned",
    type = 3
  }

  locaDebuffs:ActivateNewDebuff(testDebuff, 5.9)
end

function locaDebuffs:Unlock()
  isLocked = false
  container:SetBackdropBorderColor(0.4, 1, 0.4, 0.7)
  container:SetMovable(true)
  container:EnableMouse(true)
end

function locaDebuffs:Lock()
  isLocked = true
  container:SetBackdropBorderColor(0.4, 1, 0.4, 0)
  container:EnableMouse(false)
  container:SetMovable(false)
end

function locaDebuffs:GetScale(info)
  return locaDebuffs.db.scale
end

function locaDebuffs:SetScale(info, val)
  locaDebuffs.db.scale = val
  locaDebuffs:UpdateContainer()
end

function locaDebuffs:GetAlpha(info)
  return locaDebuffs.db.alpha
end

function locaDebuffs:SetAlpha(info, val)
  locaDebuffs.db.alpha = val
  locaDebuffs:UpdateContainer()
end

function locaDebuffs:OnUpdateSettings()
  locaDebuffs:LoadPosition()

  locaDebuffs:UpdateContainer()
end

function locaDebuffs:SetShowRedLines(val)
  locaDebuffs.db.showRedLines = val

  locaDebuffs:UpdateContainer()
end

function locaDebuffs:SetShowSecondsLabel(val)
  locaDebuffs.db.showSecondsLabel = val
  
  locaDebuffs:UpdateContainer()
end

function locaDebuffs:SetShowBackground(val)
  locaDebuffs.db.showBackground = val
  
  locaDebuffs:UpdateContainer()
end

function locaDebuffs:CreateDebuffUIList()
  local debuffListArgs = { }
  local orderNumber = 1

  for _, debuff in ipairs(locaDebuffs.db.debuffsTable) do
    debuffUI = {
      order = orderNumber,
      type = "group",
      name = debuff.name,
      icon = debuff.icon,
      childGroups = "select",
      inline = true,
      args = {
        icon = {
          order = 1,
          type = "description",
          name = debuff.category,
          image = debuff.icon,
        },
        enable = {
          order = 2,
          type = "toggle",
          name = L["Enabled"],
          get = function(info) return debuff.active end,
          set = function(info, val) debuff.active = val locaDebuffs:NotifyUpdate() end,
        },
        weight = {
          order = 3,
          type = "select",
          name = L["Weight"],
          desc = L["Higher weighted alerts overwrite lower ones"],
          values = {
            [1] = L["1 - Movement/Root"],
            [2] = L["2 - Disarm/Silence"],
            [3] = L["3 - Stun"],
            [4] = L["4 - Full"],
          },
          get = function(info) return debuff.weight end,
          set = function(info, val) debuff.weight = val; locaDebuffs:NotifyUpdate() end
        }
      }
    }

    -- Inject a Remove button dynamically if it was a user-added custom spell
    if debuff.isCustomUserAdded then
      debuffUI.args.removeButton = {
        order = 4,
        type = "execute",
        name = L["Remove"],
        confirm = true,
        confirmText = L["Are you sure you want to stop tracking this spell?"],
        func = function() locaDebuffs:RemoveCustomSpell(debuff.spellId) end
      }
    end

    orderNumber = orderNumber + 1

    debuffListArgs[debuff.name] = debuffUI
  end

  return debuffListArgs
end

function locaDebuffs:AddCustomSpell()
  local input = locaDebuffs.tempInputSpellId
  if not input or input == "" then return end

  local spellId = tonumber(input)
  if not spellId then
    print("|cffff0000LoCA:|r Invalid Spell ID. Please enter numbers only.")
    return
  end

  local categoryValue = locaDebuffs.tempInputCategory or 3
  local categoryNames = { "Snared", "Silenced/Disarmed", "Stunned", "Incapacitated/Feared/Etc" }
  local categoryWeights = { 1, 2, 3, 4 }

  -- Avoid duplicates
  for _, debuff in pairs(locaDebuffs.db.debuffsTable) do
    if debuff.spellId == spellId then
      print("|cffff0000LoCA:|r Spell ID " .. spellId .. " is already being tracked!")
      return
    end
  end

  local name, _, spellicon = GetSpellInfo(spellId)
  if not name then
    print("|cffff0000LoCA:|r Could not find spell info for ID " .. spellId .. ". It may not exist in this version of WoW.")
    return
  end

  local newDebuff = {
    spellId = spellId,
    name = name,
    icon = spellicon,
    category = categoryNames[categoryValue],
    weight = categoryWeights[categoryValue],
    type = categoryValue,
    active = true,
    isCustomUserAdded = true -- Flag to allow easy removal
  }

  table.insert(locaDebuffs.db.debuffsTable, newDebuff)
  initializedDebuffs[name] = newDebuff
  initializedDebuffsById[spellId] = newDebuff

  -- Clear temp data and rebuild list
  locaDebuffs.tempInputSpellId = ""
  locaDebuffs.options.args.debuffList.args = locaDebuffs:CreateDebuffUIList()
  
  -- Force AceConfig to refresh the panel if it's open
  LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
  
  print("|cff00ff00LoCA:|r Added " .. name .. " (" .. spellId .. ") to the tracker!")
  locaDebuffs:NotifyUpdate()
end

function locaDebuffs:RemoveCustomSpell(spellId)
  local indexToRemove
  local spellName = "Unknown"

  for index, debuff in ipairs(locaDebuffs.db.debuffsTable) do
    if debuff.spellId == spellId then
      indexToRemove = index
      spellName = debuff.name
      break
    end
  end

  if indexToRemove then
    table.remove(locaDebuffs.db.debuffsTable, indexToRemove)
    initializedDebuffs[spellName] = nil
    initializedDebuffsById[spellId] = nil
    
    locaDebuffs.options.args.debuffList.args = locaDebuffs:CreateDebuffUIList()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
    
    print("|cffffff00LoCA:|r Removed " .. spellName .. " from tracking.")
    locaDebuffs:NotifyUpdate()
  end
end

local function GetGroupDropdownValues()
  local values = {
    ["__none__"] = L["None (Default)"],
  }
  if locaDebuffs.db and locaDebuffs.db.customGroups then
    for groupId, group in pairs(locaDebuffs.db.customGroups) do
      if type(group) == "table" and group.name then
        values[groupId] = group.name
      end
    end
  end
  return values
end

function locaDebuffs:AddSpellToBlacklist(spellId)
  spellId = tonumber(spellId)
  if not spellId or spellId <= 0 then
    print("|cffff0000LoCA:|r " .. L["Please enter a valid numeric Spell ID."])
    return
  end
  local name, _, icon = GetSpellInfo(spellId)
  local seen = sessionSeenSpells[spellId]
  locaDebuffs.db.blacklist[spellId] = {
    spellId = spellId,
    name = name or (seen and seen.name) or ("Spell #" .. spellId),
    icon = icon or (seen and seen.icon) or 134400,
  }
  locaDebuffs:RefreshBlacklistUI()
  locaDebuffs:RefreshRecentSpellsUI()
  LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
  locaDebuffs:NotifyUpdate()
end

function locaDebuffs:RemoveSpellFromBlacklist(spellId)
  if locaDebuffs.db and locaDebuffs.db.blacklist then
    locaDebuffs.db.blacklist[spellId] = nil
  end
  locaDebuffs:RefreshBlacklistUI()
  locaDebuffs:RefreshRecentSpellsUI()
  LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
  locaDebuffs:NotifyUpdate()
end

function locaDebuffs:AssignSpellToGroup(spellId, targetGroupId)
  spellId = tonumber(spellId)
  if not spellId or spellId <= 0 then return end

  if locaDebuffs.db and locaDebuffs.db.customGroups then
    for _, group in pairs(locaDebuffs.db.customGroups) do
      if type(group) == "table" and group.spells then
        group.spells[spellId] = nil
      end
    end
    if targetGroupId and targetGroupId ~= "__none__" and locaDebuffs.db.customGroups[targetGroupId] then
      local group = locaDebuffs.db.customGroups[targetGroupId]
      group.spells = group.spells or {}
      local name, _, icon = GetSpellInfo(spellId)
      local seen = sessionSeenSpells[spellId]
      group.spells[spellId] = {
        spellId = spellId,
        name = name or (seen and seen.name) or ("Spell #" .. spellId),
        icon = icon or (seen and seen.icon) or 134400,
      }
    end
  end

  locaDebuffs:RefreshCustomGroupsUI()
  locaDebuffs:RefreshRecentSpellsUI()
  LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
  locaDebuffs:NotifyUpdate()
end

function locaDebuffs:CreateCustomGroup(groupName)
  if not groupName or groupName:match("^%s*$") then return end
  groupName = groupName:match("^%s*(.-)%s*$")
  local baseId = groupName:lower():gsub("[^a-z0-9]+", "_")
  if baseId == "" then baseId = "group" end
  local groupId = baseId
  local suffix = 1
  while locaDebuffs.db.customGroups[groupId] do
    suffix = suffix + 1
    groupId = baseId .. "_" .. suffix
  end

  locaDebuffs.db.customGroups[groupId] = {
    id = groupId,
    name = groupName,
    active = true,
    weight = 3,
    overrideScale = false,
    scale = 1.0,
    spells = {},
  }
  locaDebuffs.tempNewGroupName = ""
  locaDebuffs:RefreshCustomGroupsUI()
  locaDebuffs:RefreshRecentSpellsUI()
  LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
  locaDebuffs:NotifyUpdate()
end

function locaDebuffs:DeleteCustomGroup(groupId)
  if locaDebuffs.db and locaDebuffs.db.customGroups then
    locaDebuffs.db.customGroups[groupId] = nil
  end
  locaDebuffs:RefreshCustomGroupsUI()
  locaDebuffs:RefreshRecentSpellsUI()
  LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
  locaDebuffs:NotifyUpdate()
end

function locaDebuffs:RefreshRecentSpellsUI()
  if not locaDebuffs.options or not locaDebuffs.options.args.recentSpells then return end
  local args = {
    header = {
      order = 1,
      type = "header",
      name = L["Recent & Quick Filter"],
    },
    desc = {
      order = 2,
      type = "description",
      name = L["Spells detected during this session appear here automatically. Block unwanted alerts or assign them to a Custom Group with one click—no Spell ID lookup required."],
    },
  }

  local sorted = {}
  for _, entry in pairs(sessionSeenSpells) do
    table.insert(sorted, entry)
  end
  table.sort(sorted, function(a, b) return (a.lastSeen or 0) > (b.lastSeen or 0) end)

  if #sorted == 0 then
    args.empty = {
      order = 3,
      type = "description",
      name = L["No spells have been detected yet this session. Trigger an alert or click Test to populate."],
    }
  else
    local order = 3
    for _, entry in ipairs(sorted) do
      local sid = entry.spellId
      local blocked = IsSpellBlacklisted(sid)
      args["recent_" .. sid] = {
        order = order,
        type = "group",
        inline = true,
        name = string.format("%s (ID: %d)", entry.name, sid),
        args = {
          info = {
            order = 1,
            type = "description",
            name = entry.category ~= "" and entry.category or entry.name,
            image = entry.icon,
            width = 1.2,
          },
          toggleBlock = {
            order = 2,
            type = "execute",
            name = blocked and L["Unblock"] or L["Ignore (Blacklist)"],
            width = 0.9,
            func = function()
              if IsSpellBlacklisted(sid) then
                locaDebuffs:RemoveSpellFromBlacklist(sid)
              else
                locaDebuffs:AddSpellToBlacklist(sid)
              end
            end,
          },
          assignGroup = {
            order = 3,
            type = "select",
            name = L["Group"],
            values = GetGroupDropdownValues,
            width = 1.1,
            get = function()
              local gid = FindCustomGroupForSpell(sid)
              return gid or "__none__"
            end,
            set = function(_, val)
              locaDebuffs:AssignSpellToGroup(sid, val)
            end,
          },
        },
      }
      order = order + 1
    end
  end

  locaDebuffs.options.args.recentSpells.args = args
end

function locaDebuffs:RefreshBlacklistUI()
  if not locaDebuffs.options or not locaDebuffs.options.args.blacklist then return end
  local args = {
    header = {
      order = 1,
      type = "header",
      name = L["Blacklist"],
    },
    desc = {
      order = 2,
      type = "description",
      name = L["Ignored spells will never trigger LoCA alerts in either Retail or Custom mode."],
    },
    addInput = {
      order = 3,
      type = "input",
      name = L["Add Spell ID to Blacklist"],
      get = function() return locaDebuffs.tempBlacklistSpellId or "" end,
      set = function(_, val) locaDebuffs.tempBlacklistSpellId = val end,
    },
    addBtn = {
      order = 4,
      type = "execute",
      name = L["Block Spell"],
      func = function()
        local val = locaDebuffs.tempBlacklistSpellId
        locaDebuffs.tempBlacklistSpellId = ""
        locaDebuffs:AddSpellToBlacklist(val)
      end,
    },
    listHeader = {
      order = 5,
      type = "header",
      name = L["Blacklisted Spells"],
    },
  }

  local entries = {}
  if locaDebuffs.db and locaDebuffs.db.blacklist then
    for sid, entry in pairs(locaDebuffs.db.blacklist) do
      if type(sid) == "number" then
        if type(entry) ~= "table" then
          local name, _, icon = GetSpellInfo(sid)
          entry = { spellId = sid, name = name or ("Spell #" .. sid), icon = icon or 134400 }
          locaDebuffs.db.blacklist[sid] = entry
        end
        table.insert(entries, entry)
      end
    end
  end
  table.sort(entries, function(a, b) return (a.name or "") < (b.name or "") end)

  if #entries == 0 then
    args.empty = {
      order = 6,
      type = "description",
      name = L["No spells are currently blacklisted."],
    }
  else
    local order = 6
    for _, entry in ipairs(entries) do
      local sid = entry.spellId
      args["bl_" .. sid] = {
        order = order,
        type = "group",
        inline = true,
        name = string.format("%s (ID: %d)", entry.name or ("Spell #" .. sid), sid),
        args = {
          info = {
            order = 1,
            type = "description",
            name = string.format("ID: %d", sid),
            image = entry.icon or 134400,
            width = 1.5,
          },
          unblock = {
            order = 2,
            type = "execute",
            name = L["Unblock"],
            width = 0.8,
            func = function() locaDebuffs:RemoveSpellFromBlacklist(sid) end,
          },
        },
      }
      order = order + 1
    end
  end

  locaDebuffs.options.args.blacklist.args = args
end

function locaDebuffs:RefreshCustomGroupsUI()
  if not locaDebuffs.options or not locaDebuffs.options.args.customGroups then return end
  local args = {
    header = {
      order = 1,
      type = "header",
      name = L["Custom Groups"],
    },
    desc = {
      order = 2,
      type = "description",
      name = L["Create custom alert groups with their own priority, enabled toggle, and scale override."],
    },
    newName = {
      order = 3,
      type = "input",
      name = L["New Group Name"],
      get = function() return locaDebuffs.tempNewGroupName or "" end,
      set = function(_, val) locaDebuffs.tempNewGroupName = val end,
    },
    createBtn = {
      order = 4,
      type = "execute",
      name = L["Create Group"],
      func = function() locaDebuffs:CreateCustomGroup(locaDebuffs.tempNewGroupName) end,
    },
  }

  local groups = {}
  if locaDebuffs.db and locaDebuffs.db.customGroups then
    for gid, group in pairs(locaDebuffs.db.customGroups) do
      if type(group) == "table" then
        group.id = group.id or gid
        table.insert(groups, group)
      end
    end
  end
  table.sort(groups, function(a, b) return (a.name or "") < (b.name or "") end)

  local order = 5
  for _, group in ipairs(groups) do
    local gid = group.id
    local spellArgs = {}
    local spellOrder = 1
    if group.spells then
      local spellEntries = {}
      for sid, sdata in pairs(group.spells) do
        if type(sid) == "number" then
          if type(sdata) ~= "table" then
            local name, _, icon = GetSpellInfo(sid)
            sdata = { spellId = sid, name = name or ("Spell #" .. sid), icon = icon or 134400 }
            group.spells[sid] = sdata
          end
          table.insert(spellEntries, sdata)
        end
      end
      table.sort(spellEntries, function(a, b) return (a.name or "") < (b.name or "") end)
      for _, sdata in ipairs(spellEntries) do
        local sid = sdata.spellId
        spellArgs["sp_" .. sid] = {
          order = spellOrder,
          type = "group",
          inline = true,
          name = string.format("%s (ID: %d)", sdata.name, sid),
          args = {
            icon = {
              order = 1,
              type = "description",
              name = string.format("ID: %d", sid),
              image = sdata.icon or 134400,
              width = 1.4,
            },
            remove = {
              order = 2,
              type = "execute",
              name = L["Remove from Group"],
              width = 1.0,
              func = function() locaDebuffs:AssignSpellToGroup(sid, "__none__") end,
            },
          },
        }
        spellOrder = spellOrder + 1
      end
    end

    args["grp_" .. gid] = {
      order = order,
      type = "group",
      name = group.name,
      args = {
        enabled = {
          order = 1,
          type = "toggle",
          name = L["Enabled"],
          get = function() return group.active end,
          set = function(_, val) group.active = val; locaDebuffs:NotifyUpdate() end,
        },
        weight = {
          order = 2,
          type = "select",
          name = L["Priority"],
          values = {
            [1] = L["1 - Lowest (Root)"],
            [2] = L["2 - Low (Silence/Disarm)"],
            [3] = L["3 - Medium (Stun)"],
            [4] = L["4 - High (Full CC)"],
            [5] = L["5 - Highest (Override)"],
          },
          get = function() return group.weight or 3 end,
          set = function(_, val) group.weight = val; locaDebuffs:NotifyUpdate() end,
        },
        overrideScale = {
          order = 3,
          type = "toggle",
          name = L["Override Scale"],
          get = function() return group.overrideScale end,
          set = function(_, val) group.overrideScale = val; locaDebuffs:UpdateContainer() end,
        },
        scale = {
          order = 4,
          type = "range",
          name = L["Group Scale"],
          min = 0.3,
          max = 2.0,
          step = 0.1,
          disabled = function() return not group.overrideScale end,
          get = function() return group.scale or 1.0 end,
          set = function(_, val) group.scale = val; locaDebuffs:UpdateContainer() end,
        },
        addSpellInput = {
          order = 5,
          type = "input",
          name = L["Add Spell ID to Group"],
          get = function() return group._tempSpellId or "" end,
          set = function(_, val) group._tempSpellId = val end,
        },
        addSpellBtn = {
          order = 6,
          type = "execute",
          name = L["Add Spell"],
          func = function()
            local sid = tonumber(group._tempSpellId)
            group._tempSpellId = ""
            if sid then
              locaDebuffs:AssignSpellToGroup(sid, gid)
            else
              print("|cffff0000LoCA:|r " .. L["Please enter a valid numeric Spell ID."])
            end
          end,
        },
        deleteGroup = {
          order = 7,
          type = "execute",
          name = L["Delete Group"],
          confirm = true,
          confirmText = L["Are you sure you want to delete this custom group?"],
          func = function() locaDebuffs:DeleteCustomGroup(gid) end,
        },
        spellsHeader = {
          order = 8,
          type = "header",
          name = L["Assigned Spells"],
        },
        spellsList = {
          order = 9,
          type = "group",
          inline = true,
          name = "",
          args = spellArgs,
        },
      },
    }
    order = order + 1
  end

  locaDebuffs.options.args.customGroups.args = args
end
