local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale("LossOfControlAlerter")
local locaDebuffs = addon.CreateDebuffs()

local container
local isLocked = true

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
          set = function(info, val) locaDebuffs.db.types[1].active = val end
        },
        silence = {
          order = 5,
          type = "toggle",
          name = L["Silence/Disarm"],
          get = function(info) return locaDebuffs.db.types[2].active end,
          set = function(info, val) locaDebuffs.db.types[2].active = val end
        },
        stun = {
          order = 6,
          type = "toggle",
          name = L["Stun"],
          get = function(info) return locaDebuffs.db.types[3].active end,
          set = function(info, val) locaDebuffs.db.types[3].active = val end
        },
        full = {
          order = 7,
          type = "toggle",
          name = L["Full"],
          get = function(info) return locaDebuffs.db.types[4].active end,
          set = function(info, val) locaDebuffs.db.types[4].active = val end
        }
      }
    },
    addCustomDebuff = {
      order = 11,
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
      order = 12,
      type = "group",
      name = L["Tracked Debuffs"],
      childGroups = "select",
      hidden = function() return locaDebuffs.db.mode ~= "custom" end,
      disabled = function() return locaDebuffs.db.mode ~= "custom" end,
      args = {},
    }
  }
}

local initializedDebuffs = {}
local iconFrame

local TIME_COMPARISON_THRESHOLD = 0.1

function locaDebuffs:OnDebuffsChanged()
  local candidatesForActivation = {}
  local candidateDurations = {}
  
  -- Use C_UnitAuras if available (Modern/Anniversary Client), otherwise fallback to UnitDebuff
  if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
    for i = 1, 40 do
      local aura = C_UnitAuras.GetDebuffDataByIndex("player", i)
      if not aura then break end
      
      local name = aura.name
      local icon = aura.icon
      local expirationTime = aura.expirationTime
      
      if name then
        local durationLeft = 0
        if expirationTime and expirationTime > 0 then
             durationLeft = expirationTime - GetTime()
        end

        local debuffIcon = initializedDebuffs[name]

        -- check if the debuff is being monitored for alerts
        if debuffIcon and debuffIcon.active then
          table.insert(candidatesForActivation, debuffIcon)
          table.insert(candidateDurations, durationLeft)
        end
      end
    end
  else
    -- Legacy / Fallback
    for i = 1, 40 do
      local name, _, icon, debuffType, duration, expirationTime, _, _, _, spellId = UnitDebuff("player", i)
      if not name then break end

      local durationLeft = 0
      if expirationTime and expirationTime > 0 then
          durationLeft = expirationTime - GetTime()
      end

      local debuffIcon = initializedDebuffs[name]

      -- check if the debuff is being monitored for alerts
      if debuffIcon and debuffIcon.active then
        table.insert(candidatesForActivation, debuffIcon)
        table.insert(candidateDurations, durationLeft)
      end
    end
  end

  local maxDuration = -1
  local targetIndex = 0
  local maxWeight = 1

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
  local locType = locData.locType;
  local spellID = locData.spellID;
  local text = locData.displayText;
  local iconTexture = locData.iconTexture;
  local startTime = locData.startTime;
  local timeRemaining = locData.timeRemaining;
  local duration = locData.duration;
  local lockoutSchool = locData.lockoutSchool;
  local priority = locData.priority;
  local displayType = locData.displayType;

  if text then
    if locType == "SCHOOL_INTERRUPT" then
      if lockoutSchool and lockoutSchool ~= 0 then
        text = string.format("%s Locked", GetSchoolString(lockoutSchool));
      end
    end
    
    -- make a fake debuff configuration object
    local debuffConfiguration = {
      spellId = spellID,
      name = text,
      icon = iconTexture,
      weight = priority,
      category = text,
      type = LOC_TYPE_MAP[locType]
    }

    -- in case that there's a missed loctype just use the highest one
    if not debuffConfiguration.type then
      debuffConfiguration.type = 4
    end

    if not iconFrame.active or debuffConfiguration.weight > iconFrame.weight then
      locaDebuffs:ActivateNewDebuff(debuffConfiguration, timeRemaining)
    elseif iconFrame.active and debuffConfiguration.weight == iconFrame.weight and (timeRemaining == nil or timeRemaining > iconFrame.timeLeft) then
      locaDebuffs:ActivateNewDebuff(debuffConfiguration, timeRemaining)
    end
  end
end

function locaDebuffs:OnLossOfControlUpdate(locData)
  if locData then
    if iconFrame.active and locData.spellID ~= iconFrame.spellId then
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

function locaDebuffs:UpdateContainer()
  container:SetScale(locaDebuffs.db.scale)
  container:SetAlpha(locaDebuffs.db.alpha)

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
        table.insert(validDebuffs, debuff)
      end
    end
  end

  -- Replace the db table completely with our cleaned, sequential array
  locaDebuffs.db.debuffsTable = validDebuffs

  iconFrame = locaDebuffs:CreateIcon()

  locaDebuffs.options.args.debuffList.args = locaDebuffs:CreateDebuffUIList()

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

  if not locaDebuffs.db.types[newDebuff.type].active then return end

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
    locaDebuffs:DeactivateDebuff()
  else
    self.settimeleft(cooldown)
  end
end

function locaDebuffs:RunTest()
  local name, _, spellicon = GetSpellInfo(8643)

  local testDebuff = {
    spellId = 8643,
    name = name,
    icon = spellicon,
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
    
    locaDebuffs.options.args.debuffList.args = locaDebuffs:CreateDebuffUIList()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
    
    print("|cffffff00LoCA:|r Removed " .. spellName .. " from tracking.")
    locaDebuffs:NotifyUpdate()
  end
end
