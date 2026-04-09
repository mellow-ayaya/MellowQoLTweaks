local ADDON_NAME, NS = ...
local LSM = LibStub("LibSharedMedia-3.0")
-- ============================================================
-- Fail reason categories
-- ============================================================
-- Maps GlobalString variable names to named categories.
-- These variable names are stable across patches; their
-- values are locale-specific but resolved at load time.
-- errorType indices shift between patches so we match
-- against the message string (arg2) instead.
local FAIL_REASON_GLOBALS = {
	cooldown = {
		"ERR_ITEM_COOLDOWN",
		"ERR_POTION_COOLDOWN",
		"ERR_FOOD_COOLDOWN",
		"ERR_SPELL_COOLDOWN",
		"ERR_ABILITY_COOLDOWN",
		"SPELL_FAILED_NOT_READY",
		"SPELL_FAILED_NO_CHARGES_REMAIN",
	},
	gcd = {
		"ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS",
		"SPELL_FAILED_SPELL_IN_PROGRESS",
	},
	range = {
		"ERR_OUT_OF_RANGE",
		"ERR_BADATTACKPOS",
		"ERR_SPELL_OUT_OF_RANGE",
		"ERR_USE_TOO_FAR",
		"ERR_TOO_FAR_TO_INTERACT",
		"SPELL_FAILED_OUT_OF_RANGE",
	},
	resourcePrimary = {
		"ERR_OUT_OF_MANA",
		"ERR_OUT_OF_RAGE",
		"ERR_OUT_OF_FOCUS",
		"ERR_OUT_OF_ENERGY",
		"ERR_OUT_OF_RUNIC_POWER",
		"ERR_OUT_OF_FURY",
		"ERR_OUT_OF_PAIN",
		"ERR_OUT_OF_INSANITY",
		"ERR_OUT_OF_MAELSTROM",
		"ERR_OUT_OF_HEALTH",
	},
	resourceSecondary = {
		"ERR_OUT_OF_COMBO_POINTS",
		"ERR_OUT_OF_CHI",
		"ERR_OUT_OF_HOLY_POWER",
		"ERR_OUT_OF_SOUL_SHARDS",
		"ERR_OUT_OF_LUNAR_POWER",
		"ERR_OUT_OF_ARCANE_CHARGES",
		"ERR_OUT_OF_RUNES",
		"SPELL_FAILED_NO_COMBO_POINTS",
	},
	noTarget = {
		"ERR_NO_ATTACK_TARGET",
		"ERR_GENERIC_NO_TARGET",
		"ERR_GENERIC_NO_VALID_TARGETS",
		"SPELL_FAILED_BAD_IMPLICIT_TARGETS",
	},
	invalidTarget = {
		"ERR_INVALID_ATTACK_TARGET",
		"SPELL_FAILED_BAD_TARGETS",
		"SPELL_FAILED_DAMAGE_IMMUNE",
		"SPELL_FAILED_IMMUNE",
		"SPELL_FAILED_TARGETS_DEAD",
		"SPELL_FAILED_TARGET_FRIENDLY",
	},
	facing = {
		"ERR_BADATTACKFACING",
		"ERR_USE_BAD_ANGLE",
		"SPELL_FAILED_NOT_BEHIND",
		"SPELL_FAILED_NOT_INFRONT",
		"SPELL_FAILED_UNIT_NOT_BEHIND",
		"SPELL_FAILED_UNIT_NOT_INFRONT",
	},
	crowdControl = {
		"ERR_ATTACK_STUNNED",
		"ERR_ATTACK_PACIFIED",
		"ERR_ATTACK_CONFUSED",
		"ERR_ATTACK_CHARMED",
		"ERR_GENERIC_STUNNED",
		"SPELL_FAILED_STUNNED",
		"SPELL_FAILED_CHARMED",
		"SPELL_FAILED_CONFUSED",
		"SPELL_FAILED_PACIFIED",
		"SPELL_FAILED_POSSESSED",
		"SPELL_FAILED_ROOTED",
		"SPELL_FAILED_SILENCED",
		"SPELL_FAILED_FLEEING",
	},
	moving = {
		"ERR_NOT_WHILE_MOVING",
		"SPELL_FAILED_MOVING",
	},
	los = {
		"SPELL_FAILED_LINE_OF_SIGHT",
		"SPELL_FAILED_NOPATH",
	},
}
local MESSAGE_TO_CATEGORY = {}
local POWER_DISPLAY_PREFIX = nil
-- Power type display name globals → category.
-- Used to generate formatted ERR_OUT_OF_POWER_DISPLAY
-- messages at load time for resources that lack their
-- own dedicated ERR_OUT_OF_* global (e.g. Astral Power).
local POWER_DISPLAY_GLOBALS = {
	resourcePrimary = {
		"MANA", "RAGE", "FOCUS", "ENERGY", "RUNIC_POWER",
		"FURY", "PAIN", "INSANITY", "MAELSTROM", "HEALTH",
	},
	resourceSecondary = {
		"COMBO_POINTS", "CHI", "HOLY_POWER", "SOUL_SHARDS",
		"LUNAR_POWER", "ARCANE_CHARGES", "RUNES",
	},
}
-- Called from Core.lua's InitDB after the DB is ready.
function NS.BuildMessageToCategory()
	wipe(MESSAGE_TO_CATEGORY)
	-- 1. Direct GlobalString entries (ERR_OUT_OF_MANA, etc.)
	for cat, globals in pairs(FAIL_REASON_GLOBALS) do
		for _, gName in ipairs(globals) do
			local str = _G[gName]
			if str and not str:find("%%") then
				MESSAGE_TO_CATEGORY[str] = cat
			end
		end
	end

	-- 2. Generated entries from ERR_OUT_OF_POWER_DISPLAY.
	--    Covers resources that only use the generic format
	--    string (e.g. "Not enough Astral Power").
	local powerFmt = _G["ERR_OUT_OF_POWER_DISPLAY"]
	if powerFmt then
		POWER_DISPLAY_PREFIX = powerFmt:match("^(.-)%%s")
		for cat, displayGlobals in pairs(POWER_DISPLAY_GLOBALS) do
			for _, gName in ipairs(displayGlobals) do
				local powerName = _G[gName]
				if powerName then
					local msg = string.format(powerFmt, powerName)
					-- Don't overwrite entries from step 1
					if not MESSAGE_TO_CATEGORY[msg] then
						MESSAGE_TO_CATEGORY[msg] = cat
					end
				end
			end
		end
	end
end

-- Exposed for options UI ordering/labels
NS.FAIL_REASON_ORDER = {
	"cooldown", "gcd", "range",
	"resourcePrimary", "resourceSecondary",
	"noTarget", "invalidTarget", "facing", "crowdControl", "moving",
	"los", "other",
}
NS.FAIL_REASON_LABELS = {
	cooldown = "Cooldown",
	gcd = "GCD / Already Casting",
	range = "Out of Range",
	resourcePrimary = "Not Enough Resource (Primary)",
	resourceSecondary = "Not Enough Resource (Secondary)",
	noTarget = "No Target",
	invalidTarget = "Invalid Target",
	facing = "Wrong Facing",
	crowdControl = "Stunned / CC'd",
	moving = "Moving",
	los = "Line of Sight",
	other = "Other / Uncategorized",
}
-- ============================================================
-- Floating text system
-- ============================================================
local MAX_SCROLL_ENTRIES = 5
local SCROLL_SPACING = 24
local ANIM_FADE_DELAY = 0.4
local ANIM_FADE_DURATION = 1.2
local ANIM_DRIFT = 30
local ANIM_TOTAL = 1.6
local floatPool = {}
local activeFloats = {}
local function CreateFloatFrame()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(300, 30)
	f:SetFrameStrata("TOOLTIP")
	f:Hide()
	f.text = f:CreateFontString(nil, "OVERLAY")
	f.text:SetAllPoints()
	f.text:SetTextColor(1, 1, 1, 1)
	f.ag = f:CreateAnimationGroup()
	f.ag:SetToFinalAlpha(true)
	f.fadeOut = f.ag:CreateAnimation("Alpha")
	f.fadeOut:SetFromAlpha(1)
	f.fadeOut:SetToAlpha(0)
	f.fadeOut:SetDuration(ANIM_FADE_DURATION)
	f.fadeOut:SetStartDelay(ANIM_FADE_DELAY)
	f.fadeOut:SetOrder(1)
	f.moveUp = f.ag:CreateAnimation("Translation")
	f.moveUp:SetOffset(0, ANIM_DRIFT)
	f.moveUp:SetDuration(ANIM_TOTAL)
	f.moveUp:SetOrder(1)
	f.ag:SetScript("OnFinished", function()
		f:Hide()
		for i, af in ipairs(activeFloats) do
			if af == f then
				table.remove(activeFloats, i)
				break
			end
		end

		floatPool[#floatPool + 1] = f
	end)
	return f
end

local function GetFloatFrame()
	if #floatPool > 0 then return table.remove(floatPool) end

	return CreateFloatFrame()
end

local function ApplyFloatFont(f)
	local ft = NS.db.floatingText
	local path = NS.GetFontPath(ft.font)
	f.text:SetFont(path, ft.fontSize, ft.outline ~= "NONE" and ft.outline or "")
end

local function GetFloatAnchorPoint()
	local ft = NS.db.floatingText
	if ft.anchor == "CURSOR" then
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		return x / scale + ft.x, y / scale + ft.y
	else
		local refX, refY = 0, 0
		local a = ft.anchor
		local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
		if a == "CENTER" then
			refX, refY = pw / 2, ph / 2
		elseif a == "TOP" then
			refX, refY = pw / 2, ph
		elseif a == "BOTTOM" then
			refX, refY = pw / 2, 0
		elseif a == "LEFT" then
			refX, refY = 0, ph / 2
		elseif a == "RIGHT" then
			refX, refY = pw, ph / 2
		elseif a == "TOPLEFT" then
			refX, refY = 0, ph
		elseif a == "TOPRIGHT" then
			refX, refY = pw, ph
		elseif a == "BOTTOMLEFT" then
			refX, refY = 0, 0
		elseif a == "BOTTOMRIGHT" then
			refX, refY = pw, 0
		end

		return refX + ft.x, refY + ft.y
	end
end

local function ShowSpellFloatText(spellName)
	local db = NS.db
	if not db.floatingText.enabled then return end

	local mode = db.floatingText.mode
	if mode == "single" then
		if not NS._singleFloat then
			NS._singleFloat = CreateFloatFrame()
		end

		local f = NS._singleFloat
		f.ag:Stop()
		ApplyFloatFont(f)
		local bx, by = GetFloatAnchorPoint()
		f:ClearAllPoints()
		f:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", bx, by)
		f:SetAlpha(1)
		f.text:SetText(spellName)
		f:Show()
		f.ag:Play()
	else -- "scroll"
		for _, af in ipairs(activeFloats) do
			local point, rel, relPt, ox, oy = af:GetPoint(1)
			af:ClearAllPoints()
			af:SetPoint(point, rel, relPt, ox, oy + SCROLL_SPACING)
		end

		if #activeFloats >= MAX_SCROLL_ENTRIES then
			local oldest = table.remove(activeFloats, 1)
			oldest.ag:Stop()
			oldest:Hide()
			floatPool[#floatPool + 1] = oldest
		end

		local f = GetFloatFrame()
		ApplyFloatFont(f)
		local bx, by = GetFloatAnchorPoint()
		f:ClearAllPoints()
		f:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", bx, by)
		f:SetAlpha(1)
		f.text:SetText(spellName)
		f:Show()
		f.ag:Play()
		activeFloats[#activeFloats + 1] = f
	end
end

-- ============================================================
-- Ignore list helpers
-- ============================================================
function NS.InitIgnoreList()
	NS.db.ignoreList = NS.db.ignoreList or {}
	local il = NS.db.ignoreList
	il.account = il.account or {}
	il.class = il.class or {}
	il.spec = il.spec or {}
	il.char = il.char or {}
end

function NS.IsIgnored(spellID)
	local il = NS.db.ignoreList
	if not il then return false end

	return (il.char[NS.charKey] and il.char[NS.charKey][spellID])
			or (il.spec[NS.specKey] and il.spec[NS.specKey][spellID])
			or (il.class[NS.classKey] and il.class[NS.classKey][spellID])
			or il.account[spellID]
end

local VALID_SCOPES = { account = true, class = true, spec = true, char = true }
NS.VALID_SCOPES = VALID_SCOPES
function NS.AddIgnored(spellID, scope)
	NS.InitIgnoreList()
	local il = NS.db.ignoreList
	local name = C_Spell.GetSpellName(spellID) or "Unknown"
	scope = scope or "account"
	if not VALID_SCOPES[scope] then
		NS.Msg("Invalid scope. Use: account, class, spec, char")
		return false
	end

	if scope == "account" then
		il.account[spellID] = true
	elseif scope == "class" then
		il.class[NS.classKey] = il.class[NS.classKey] or {}
		il.class[NS.classKey][spellID] = true
	elseif scope == "spec" then
		il.spec[NS.specKey] = il.spec[NS.specKey] or {}
		il.spec[NS.specKey][spellID] = true
	elseif scope == "char" then
		il.char[NS.charKey] = il.char[NS.charKey] or {}
		il.char[NS.charKey][spellID] = true
	end

	NS.Msg(name .. " (" .. spellID .. ") added to ignore list [" .. scope .. "]")
	return true
end

function NS.RemoveIgnored(spellID, scope)
	NS.InitIgnoreList()
	local il = NS.db.ignoreList
	local name = C_Spell.GetSpellName(spellID) or "Unknown"
	if not scope then
		NS.Msg("Specify scope: all, account, class, spec, char")
		return
	end

	if scope == "all" then
		il.account[spellID] = nil
		if il.class[NS.classKey] then il.class[NS.classKey][spellID] = nil end

		if il.spec[NS.specKey] then il.spec[NS.specKey][spellID] = nil end

		if il.char[NS.charKey] then il.char[NS.charKey][spellID] = nil end

		NS.Msg(name .. " (" .. spellID .. ") removed from all scopes")
	elseif VALID_SCOPES[scope] then
		if scope == "account" then
			il.account[spellID] = nil
		elseif scope == "class" then
			if il.class[NS.classKey] then il.class[NS.classKey][spellID] = nil end
		elseif scope == "spec" then
			if il.spec[NS.specKey] then il.spec[NS.specKey][spellID] = nil end
		elseif scope == "char" then
			if il.char[NS.charKey] then il.char[NS.charKey][spellID] = nil end
		end

		NS.Msg(name .. " (" .. spellID .. ") removed [" .. scope .. "]")
	else
		NS.Msg("Invalid scope. Use: all, account, class, spec, char")
	end
end

-- ============================================================
-- Post-cast suppression & fail reason tracking
-- ============================================================
local lastSuccessTime = 0
local lastErrorMessage = nil
local lastErrorTime = 0
local lastDirectAlertTime = 0
local lastAnyFailAlertTime = 0   -- GetTime() of last fail alert from ANY path
local lastAlertTimes = {}
local DIRECT_DEDUP_WINDOW = 0.25 -- suppress direct alerts for this long after a fail-handler alert
local ERROR_CORRELATION_WINDOW = 0.15
-- ============================================================
-- Spec → resource voice mapping
-- ============================================================
-- Maps numeric spec IDs to the sound label for each resource slot.
-- Labels must match the suffix of registered LSM sound names,
-- e.g. "Energy" resolves to "MQT: F1: Energy" or "MQT: M1: Energy".
-- nil means no matching voice file exists for that resource.
local SPEC_RESOURCE_MAP = {
	-- Death Knight
	[250] = { primary = "Runes", secondary = "RP" },     -- Blood
	[251] = { primary = "Runes", secondary = "RP" },     -- Frost
	[252] = { primary = "Runes", secondary = "RP" },     -- Unholy
	-- Demon Hunter (Vengeance uses Pain; no Pain file, treated as Fury)
	[577] = { primary = "Fury" },                        -- Havoc
	[581] = { primary = "Fury" },                        -- Vengeance
	-- Druid
	[102] = { primary = "AP" },                          -- Balance (Astral Power)
	[103] = { primary = "Energy", secondary = "CP" },    -- Feral
	[104] = { primary = "Rage" },                        -- Guardian
	[105] = { primary = "Mana" },                        -- Restoration
	-- Evoker
	[1467] = { primary = "Mana", secondary = "Essence" }, -- Devastation
	[1468] = { primary = "Mana", secondary = "Essence" }, -- Preservation
	[1473] = { primary = "Mana", secondary = "Essence" }, -- Augmentation
	-- Hunter
	[253] = { primary = "Focus" },                       -- Beast Mastery
	[254] = { primary = "Focus" },                       -- Marksmanship
	[255] = { primary = "Focus" },                       -- Survival
	-- Mage
	[62] = { primary = "Mana", secondary = "AC" },       -- Arcane
	[63] = { primary = "Mana" },                         -- Fire
	[64] = { primary = "Mana" },                         -- Frost
	-- Monk
	[268] = { primary = "Energy" },                      -- Brewmaster
	[270] = { primary = "Mana" },                        -- Mistweaver
	[269] = { primary = "Energy", secondary = "Chi" },   -- Windwalker
	-- Paladin
	[65] = { primary = "Mana" },                         -- Holy
	[66] = { primary = "Mana", secondary = "Holy" },     -- Protection
	[70] = { primary = "Mana", secondary = "Holy" },     -- Retribution
	-- Priest
	[256] = { primary = "Mana" },                        -- Discipline
	[257] = { primary = "Mana" },                        -- Holy
	[258] = { primary = "Mana" },                        -- Shadow (Insanity: no file, Mana is secondary)
	-- Rogue
	[259] = { primary = "Energy", secondary = "CP" },    -- Assassination
	[260] = { primary = "Energy", secondary = "CP" },    -- Outlaw
	[261] = { primary = "Energy", secondary = "CP" },    -- Subtlety
	-- Shaman (Maelstrom: no file; Elemental secondary is Mana)
	[262] = { primary = "Mana" },                        -- Elemental
	[263] = { primary = "Mana" },                        -- Enhancement
	[264] = { primary = "Mana" },                        -- Restoration
	-- Warlock
	[265] = { primary = "Mana", secondary = "Shards" },  -- Affliction
	[266] = { primary = "Mana", secondary = "Shards" },  -- Demonology
	[267] = { primary = "Mana", secondary = "Shards" },  -- Destruction
	-- Warrior
	[71] = { primary = "Rage" },                         -- Arms
	[72] = { primary = "Rage" },                         -- Fury
	[73] = { primary = "Rage" },                         -- Protection
}
-- Called at login and on PLAYER_SPECIALIZATION_CHANGED.
-- Resolves the current spec + configured gender to concrete LSM sound
-- names, stored in NS.activeResourceVoice for use by FireAlert.
function NS.UpdateResourceVoiceMap()
	local db = NS.db
	if not db then return end

	local sr = db.soundAlerts.smartResource
	if not sr or not sr.enabled then
		NS.activeResourceVoice = nil
		return
	end

	local gender = sr.gender or "F1"
	local specID = tonumber(NS.specKey)
	local map = specID and SPEC_RESOURCE_MAP[specID]
	if not map then
		NS.activeResourceVoice = nil
		return
	end

	local function resolve(label)
		if not label then return nil end

		local name = "MQT: " .. gender .. ": " .. label
		return LSM:IsValid("sound", name) and name or nil
	end
	NS.activeResourceVoice = {
		primary = resolve(map.primary),
		secondary = resolve(map.secondary),
	}
end

-- ============================================================
-- Alert condition suppression
-- ============================================================
local function IsConditionSuppressed()
	local sc = NS.db.soundAlerts.suppressConditions
	if not sc then return false end

	if sc.inCombat and UnitAffectingCombat("player") then return true end

	if sc.outOfCombat and not UnitAffectingCombat("player") then return true end

	if sc.mounted and IsMounted() then return true end

	if sc.inVehicle and UnitInVehicle("player") then return true end

	return false
end

local FireAlert -- forward declaration; defined below
local function IsSuppressedByRecentCast()
	local db = NS.db
	if not db.soundAlerts.suppressionEnabled then return false end

	return (GetTime() - lastSuccessTime) < db.soundAlerts.suppressionWindow
end

local function IsThrottled(category)
	local db = NS.db
	if not db.soundAlerts.throttleEnabled then return false end

	local last = lastAlertTimes[category]
	if not last then return false end

	return (GetTime() - last) < db.soundAlerts.throttleWindow
end

local auxFrame = CreateFrame("Frame")
auxFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
auxFrame:RegisterEvent("UI_ERROR_MESSAGE")
auxFrame:RegisterEvent("UI_INFO_MESSAGE")
auxFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if arg1 == "player" then
			lastSuccessTime = GetTime()
		end
	elseif event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE" then
		lastErrorMessage = arg2
		lastErrorTime = GetTime()
		local capturedMsg = arg2
		local capturedTime = lastErrorTime
		C_Timer.After(0, function()
			local db = NS.db
			if not db or not db.soundAlerts.enabled then return end

			if not db.soundAlerts.failEnabled then return end

			if lastDirectAlertTime == capturedTime then return end

			-- Suppress if the fail handler recently fired
			-- an alert (prevents duplicate sounds on rapid
			-- button mashing when WoW throttles UNIT_SPELLCAST_FAILED).
			if (GetTime() - lastAnyFailAlertTime) < DIRECT_DEDUP_WINDOW then return end

			if IsSuppressedByRecentCast() then return end

			local category = MESSAGE_TO_CATEGORY[capturedMsg]
			if not category and POWER_DISPLAY_PREFIX
					and capturedMsg:find(POWER_DISPLAY_PREFIX, 1, true) then
				category = "resourcePrimary"
			end

			if not category then return end

			local fr = db.soundAlerts.failReasons
			if fr and not fr[category] then return end

			lastDirectAlertTime = capturedTime
			FireAlert(true, nil, category, capturedMsg)
		end)
	end
end)
-- ============================================================
-- Heuristic fallbacks for channeled spells
-- ============================================================
-- Channeled spells (Fists of Fury, Blizzard, etc.) fire
-- UNIT_SPELLCAST_FAILED but NOT UI_ERROR_MESSAGE on most
-- failure types.  These heuristics inspect game state to
-- classify the failure when no error message correlates.
-- All APIs used here are read-only and combat-safe.
local POWER_TYPE_TO_CATEGORY = {
	[0] = "resourcePrimary",   -- Mana
	[1] = "resourcePrimary",   -- Rage
	[2] = "resourcePrimary",   -- Focus
	[3] = "resourcePrimary",   -- Energy
	[4] = "resourceSecondary", -- Combo Points
	[5] = "resourceSecondary", -- Runes
	[6] = "resourcePrimary",   -- Runic Power
	[7] = "resourceSecondary", -- Soul Shards
	[8] = "resourceSecondary", -- Lunar Power
	[9] = "resourceSecondary", -- Holy Power
	[11] = "resourcePrimary",  -- Maelstrom
	[12] = "resourceSecondary", -- Chi
	[13] = "resourcePrimary",  -- Insanity
	[16] = "resourceSecondary", -- Arcane Charges
	[17] = "resourcePrimary",  -- Fury
	[18] = "resourcePrimary",  -- Pain
}
local function CheckCCFallback()
	if not C_LossOfControl or not C_LossOfControl.GetActiveLossOfControlDataCount then return nil end

	local ok, count = pcall(C_LossOfControl.GetActiveLossOfControlDataCount)
	if ok and count and count > 0 then return "crowdControl" end

	return nil
end

local function CheckResourceFallback(spellID)
	if not spellID then return nil end

	local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
	if not ok or not costs then return nil end

	for _, cost in ipairs(costs) do
		if cost.cost and cost.cost > 0 then
			local canAfford, affordable = pcall(function()
				return UnitPower("player", cost.type) >= cost.cost
			end)
			if not canAfford or not affordable then
				return POWER_TYPE_TO_CATEGORY[cost.type] or "resourcePrimary"
			end
		end
	end

	return nil
end

local GCD_SPELL_ID = 61304
local function ClassifySpellFailCooldown(spellID)
	local spellCD = C_Spell.GetSpellCooldown(spellID)
	if not spellCD then return "gcd" end

	if spellCD.isOnGCD then return "gcd" end

	local ok, result = pcall(function()
		if not spellCD.duration or spellCD.duration == 0 then return "gcd" end

		local gcd = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
		local gcdDuration = (gcd and gcd.duration and gcd.duration > 0) and gcd.duration or 1.5
		return spellCD.duration <= gcdDuration + 0.05 and "gcd" or "cooldown"
	end)
	if not ok then return "cooldown" end

	return result
end

local function CheckCooldownFallback(spellID)
	if not spellID then return nil end

	local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, spellID)
	if not ok or not cdInfo then return nil end

	if cdInfo.isOnGCD then return "gcd" end

	local hasCD, cdCheck = pcall(function()
		return cdInfo.duration and cdInfo.duration > 0
	end)
	if not hasCD then return "cooldown" end

	if not cdCheck then return nil end

	return ClassifySpellFailCooldown(spellID)
end

local function CheckNoTargetFallback()
	if not UnitExists("target") then return "noTarget" end

	return nil
end

local function CheckInvalidTargetFallback()
	if not UnitExists("target") then return nil end

	if UnitIsDeadOrGhost("target") then return "invalidTarget" end

	return nil
end

local function CheckRangeFallback(spellID)
	if not spellID then return nil end

	if not UnitExists("target") then return nil end

	local ok, inRange = pcall(C_Spell.IsSpellInRange, spellID, "target")
	if ok and inRange == false then return "range" end

	return nil
end

local function CheckMovingFallback()
	local speed = GetUnitSpeed("player")
	if speed and speed > 0 then return "moving" end

	return nil
end

-- NOTE: Facing and Line of Sight have no read API in combat.
-- UnitPosition() only works in instances. These remain "other".
-- Chain: most-definitive first, weakest last.
-- CD/GCD before resource: a spell on cooldown fails for that
-- reason even if you also lack the resource to cast it.
local function RunFallbackChain(spellID)
	return CheckCCFallback()
			or CheckCooldownFallback(spellID)
			or CheckResourceFallback(spellID)
			or CheckNoTargetFallback()
			or CheckInvalidTargetFallback()
			or CheckRangeFallback(spellID)
			or CheckMovingFallback()
end

local function ResolveFailCategory(errorMessage, errorTime, spellID)
	-- Try error message correlation first
	local category = nil
	local hadCorrelatedError = false
	if (GetTime() - errorTime) <= ERROR_CORRELATION_WINDOW then
		-- An error arrived within the window, even if we can't map it.
		-- This flag prevents the heuristic fallbacks from running on
		-- unmapped messages (e.g. "You can't do that while polymorphed"),
		-- which would otherwise guess from game state and misclassify.
		hadCorrelatedError = (errorMessage ~= nil)
		category = errorMessage and MESSAGE_TO_CATEGORY[errorMessage]
		if not category and POWER_DISPLAY_PREFIX and errorMessage
				and errorMessage:find(POWER_DISPLAY_PREFIX, 1, true) then
			category = "resourcePrimary"
		end
	end

	-- Fallback heuristics only when no error message correlated at all.
	-- Channeled spells fire UNIT_SPELLCAST_FAILED but NOT UI_ERROR_MESSAGE
	-- on many failure types, so heuristics are their only classification path.
	-- If we got a message but couldn't map it, the correct outcome is "other" —
	-- not whatever game state happens to look like right now.
	if not category and not hadCorrelatedError then
		category = RunFallbackChain(spellID)
	end

	-- Refine ambiguous cooldown/GCD from error path
	if (category == "cooldown" or category == "gcd") and spellID then
		category = ClassifySpellFailCooldown(spellID)
	end

	return category
end

local function IsSuppressedByFailReason(errorMessage, errorTime, spellID)
	local fr = NS.db.soundAlerts.failReasons
	if not fr then return false end

	local category = ResolveFailCategory(errorMessage, errorTime, spellID) or "other"
	return not fr[category]
end

-- ============================================================
-- Shared alert dispatch (sound + floating text)
-- ============================================================
-- errorMsg: the specific error message that triggered this alert,
-- captured at call time so debug output is always accurate.
FireAlert = function(isFail, spellID, category, errorMsg)
	local db = NS.db
	if IsConditionSuppressed() then return end

	if isFail and category and IsThrottled(category) then return end

	if isFail then
		lastAnyFailAlertTime = GetTime()
	end

	local channel = isFail and db.soundAlerts.failChannel or db.soundAlerts.interruptChannel
	-- Smart resource voice: if enabled and this is a resource fail, play
	-- the spec-mapped voice sound instead of the manually assigned pool.
	-- Falls back to the pool if no sound resolves for this spec/category.
	local smartPlayed = false
	if isFail and NS.activeResourceVoice then
		local arv = NS.activeResourceVoice
		local voiceName = (category == "resourcePrimary" and arv.primary)
				or (category == "resourceSecondary" and arv.secondary)
		if voiceName then
			PlaySoundFile(LSM:Fetch("sound", voiceName), channel)
			smartPlayed = true
		end
	end

	if not smartPlayed then
		local poolKey = isFail and ("fail_" .. (category or "other")) or "interruptSounds"
		NS.PlayRandomFromPool(poolKey, channel)
	end

	if isFail and category then
		lastAlertTimes[category] = GetTime()
	end

	if db.soundAlerts.debugMode then
		local spellName = spellID and C_Spell.GetSpellName(spellID)
		local spellPart = spellName
				and ("|cFFFFD100" .. spellName .. "|r |cFF888888(" .. spellID .. ")|r")
				or "|cFF888888(no spell ID)|r"
		local catPart = "|cFFAAFFAA" .. (category or (isFail and "other" or "interrupt")) .. "|r"
		local msgPart = errorMsg
				and ("|cFFAAAAAA\"" .. errorMsg .. "\"|r")
				or "|cFF888888(no error msg)|r"
		local alertType = isFail and "fail" or "interrupt"
		NS.Msg("|cFFFF8800[debug]|r " .. alertType .. " cat=" .. catPart .. " spell=" .. spellPart .. " msg=" .. msgPart)
	end

	if spellID then
		local ft = db.floatingText
		local showText = ft.enabled
		if showText and isFail and not ft.failEnabled then showText = false end

		if showText and not isFail and not ft.interruptEnabled then showText = false end

		if showText then
			local spellName = C_Spell.GetSpellName(spellID)
			if spellName then ShowSpellFloatText(spellName) end
		end
	end
end
-- ============================================================
-- Spell fail/interrupt event handler
-- ============================================================
local lastHandledCastGUID = nil
local failFrame = CreateFrame("Frame")
failFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
failFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
failFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
failFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
-- Track succeeded casts so their GUIDs can be deduplicated
-- against any spurious INTERRUPTED events WoW emits for the
-- same cast (e.g. instant spells buffed by TFT).
failFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
failFrame:SetScript("OnEvent", function(_, event, unit, castGUID, spellID, arg4)
	local db = NS.db
	if not db or not db.soundAlerts.enabled then return end

	if unit ~= "player" then return end

	-- A completed cast cannot be interrupted.
	-- Stamp its GUID so any later spurious INTERRUPTED event
	-- (e.g. WoW emitting both SUCCEEDED and INTERRUPTED for
	-- an instant spell or a TFT-buffed EM) is silently dropped
	-- by the dedup check below.
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		lastHandledCastGUID = castGUID
		return
	end

	-- Deduplicate: WoW fires both INTERRUPTED and FAILED for
	-- the same cast. The first event seen wins; the second is
	-- skipped so we only play one sound per cast attempt.
	if castGUID == lastHandledCastGUID then return end

	-- Suppress internal Blizzard spells whose names start with "[DNT]".
	-- These fire spurious no-target / out-of-range errors that are
	-- meaningless to the player. Stamping both guards blocks the
	-- UI_ERROR_MESSAGE fallback path from firing a sound for the same event.
	if spellID then
		local spellName = C_Spell.GetSpellName(spellID)
		if spellName and spellName:sub(1, 5) == "[DNT]" then
			lastHandledCastGUID = castGUID
			lastAnyFailAlertTime = GetTime()
			return
		end
	end

	local isFail = (event == "UNIT_SPELLCAST_FAILED")
	if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if not arg4 then return end
	elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
		if arg4 then return end
	end

	if isFail and not db.soundAlerts.failEnabled then return end

	if not isFail and not db.soundAlerts.interruptEnabled then return end

	if spellID and NS.IsIgnored(spellID) then return end

	-- Post-cast suppression (fails only)
	if isFail and IsSuppressedByRecentCast() then return end

	if isFail then
		-- Stamp both UI_ERROR_MESSAGE dedup guards immediately, before
		-- deferring.  UI_ERROR_MESSAGE sometimes fires before
		-- UNIT_SPELLCAST_FAILED (movement checks are client-side and
		-- instant), so its deferred handler can run first in frame N+1
		-- and fire an immediate alert before the fail defer has a chance
		-- to set these.  Stamping here in frame N ensures the guards are
		-- in place regardless of which defer runs first.
		-- GetTime() is constant within a frame, so it matches capturedTime
		-- captured by the UI_ERROR_MESSAGE handler in the same frame.
		lastDirectAlertTime = GetTime()
		lastAnyFailAlertTime = GetTime()
		-- Defer fail processing by one frame so UI_ERROR_MESSAGE
		-- has time to fire. Without this, the error hasn't arrived
		-- yet and fail reason filtering can't match a category.
		local capturedGUID = castGUID
		local capturedSpellID = spellID
		-- Snapshot the error state NOW, before deferring.
		-- In the deferred handler we only accept the error if the
		-- timestamp changed — meaning a NEW error arrived during
		-- the deferral.  This prevents stale messages from a
		-- previous spell leaking into this fail event.
		local snapshotErrorTime = lastErrorTime
		C_Timer.After(0, function()
			if capturedGUID == lastHandledCastGUID then return end

			-- Re-check suppression here: a spell may have succeeded
			-- in the same frame as the fail (e.g. a dual-purpose macro
			-- where one branch fails and another succeeds simultaneously).
			if IsSuppressedByRecentCast() then return end

			local capturedErrorMsg = nil
			local capturedErrorTime = 0
			if lastErrorTime ~= snapshotErrorTime then
				-- A new UI_ERROR_MESSAGE arrived during the deferral
				capturedErrorMsg = lastErrorMessage
				capturedErrorTime = lastErrorTime
			end

			local category = ResolveFailCategory(capturedErrorMsg, capturedErrorTime, capturedSpellID) or "other"
			local fr = NS.db.soundAlerts.failReasons
			if fr and not fr[category] then return end

			lastDirectAlertTime = lastErrorTime
			lastHandledCastGUID = capturedGUID
			FireAlert(true, capturedSpellID, category, capturedErrorMsg)
		end)
	else
		-- Interrupts: no error correlation needed, fire immediately
		lastHandledCastGUID = castGUID
		FireAlert(false, spellID, nil, nil)
	end
end)
