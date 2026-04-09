local ADDON_NAME, NS = ...
-- ============================================================
-- LibSharedMedia – media tables
-- Registration is deferred to RegisterMedia() after the DB
-- loads so per-sound/font enable state can be respected.
-- ============================================================
local LSM = LibStub("LibSharedMedia-3.0")
local SOUND_DIR = "Interface\\AddOns\\MellowQoLTweaks\\Sounds\\"
local VOICE_DIR = "Interface\\AddOns\\MellowQoLTweaks\\Voice\\"
local FONT_DIR = "Interface\\AddOns\\MellowQoLTweaks\\Fonts\\"
local MQT_SOUNDS = {
	{ name = "MQT: Blow 1", file = "blow1.ogg", pack = "blow" },
	{ name = "MQT: Blow 2", file = "blow2.ogg", pack = "blow" },
	{ name = "MQT: Blow 3", file = "blow3.ogg", pack = "blow" },
	{ name = "MQT: Blow 4", file = "blow4.ogg", pack = "blow" },
	{ name = "MQT: Blow 5", file = "blow5.ogg", pack = "blow" },
	{ name = "MQT: Error 1", file = "error1.ogg", pack = "error" },
	{ name = "MQT: Error 2", file = "error2.ogg", pack = "error" },
	{ name = "MQT: Error 3", file = "error3.ogg", pack = "error" },
	{ name = "MQT: Error 4", file = "error4.ogg", pack = "error" },
	{ name = "MQT: Error 5", file = "error5.ogg", pack = "error" },
	{ name = "MQT: Error2X 21", file = "error2x21.ogg", pack = "error2x" },
	{ name = "MQT: Error2X 23", file = "error2x23.ogg", pack = "error2x" },
	{ name = "MQT: Error2X 24", file = "error2x24.ogg", pack = "error2x" },
	{ name = "MQT: Error2X 25", file = "error2x25.ogg", pack = "error2x" },
	{ name = "MQT: Error2X 2", file = "error2x2.ogg", pack = "error2x" },
	{ name = "MQT: Error2X 5", file = "error2x5.ogg", pack = "error2x" },
	{ name = "MQT: Huh 1", file = "huh1_loud.ogg", pack = "huh" },
	{ name = "MQT: Huh 3", file = "huh3_loud.ogg", pack = "huh" },
	{ name = "MQT: Huh 4", file = "huh4_loud.ogg", pack = "huh" },
	{ name = "MQT: Huh 5", file = "huh5_loud.ogg", pack = "huh" },
	{ name = "MQT: Huh 6", file = "huh6_loud.ogg", pack = "huh" },
	{ name = "MQT: Huh 7", file = "huh7_loud.ogg", pack = "huh" },
	{ name = "MQT: Locked 1", file = "locked1.ogg", pack = "locked" },
	{ name = "MQT: Locked 2", file = "locked2.ogg", pack = "locked" },
	{ name = "MQT: Locked 3", file = "locked3.ogg", pack = "locked" },
	{ name = "MQT: Locked 4", file = "locked4.ogg", pack = "locked" },
	{ name = "MQT: Locked 5", file = "locked5.ogg", pack = "locked" },
	{ name = "MQT: Locked 6", file = "locked6.ogg", pack = "locked" },
	{ name = "MQT: WaterP 1", file = "waterp1.ogg", pack = "waterp" },
	{ name = "MQT: WaterP 2", file = "waterp2.ogg", pack = "waterp" },
	{ name = "MQT: WaterP 3", file = "waterp3.ogg", pack = "waterp" },
	{ name = "MQT: WaterP 4", file = "waterp4.ogg", pack = "waterp" },
	{ name = "MQT: WaterP 5", file = "waterp5.ogg", pack = "waterp" },
	{ name = "MQT: WaterP 6", file = "waterp6.ogg", pack = "waterp" },
	{ name = "MQT: WaterP 7", file = "waterp7.ogg", pack = "waterp" },
	{ name = "MQT: WaterP 8", file = "waterp8.ogg", pack = "waterp" },
	{ name = "MQT: WaterP 9", file = "waterp9.ogg", pack = "waterp" },
	{ name = "MQT: Watery 1", file = "watery1.ogg", pack = "watery" },
	{ name = "MQT: Watery 2", file = "watery2.ogg", pack = "watery" },
	{ name = "MQT: Watery 3", file = "watery3.ogg", pack = "watery" },
	{ name = "MQT: Watery 4", file = "watery4.ogg", pack = "watery" },
	{ name = "MQT: Watery 5", file = "watery5.ogg", pack = "watery" },
	{ name = "MQT: Woosh 10", file = "woosh10.ogg", pack = "woosh" },
	{ name = "MQT: Woosh 11", file = "woosh11.ogg", pack = "woosh" },
	{ name = "MQT: Woosh 12", file = "woosh12.ogg", pack = "woosh" },
	{ name = "MQT: Woosh 1", file = "woosh1.ogg", pack = "woosh" },
	{ name = "MQT: Woosh 2", file = "woosh2.ogg", pack = "woosh" },
	{ name = "MQT: Woosh 3", file = "woosh3.ogg", pack = "woosh" },
	{ name = "MQT: Woosh 4", file = "woosh4.ogg", pack = "woosh" },
	{ name = "MQT: Woosh 5", file = "woosh5.ogg", pack = "woosh" },
	{ name = "MQT: Woosh 6", file = "woosh6.ogg", pack = "woosh" },
	{ name = "MQT: Woosh 7", file = "woosh7.ogg", pack = "woosh" },
	{ name = "MQT: Woosh 8", file = "woosh8.ogg", pack = "woosh" },
	{ name = "MQT: Woosh 9", file = "woosh9.ogg", pack = "woosh" },
}
-- Voice sound entries (TTS, stored in Voice\ subfolder).
-- F1 = female voice 1, M1 = male voice 1.
local VOICE_LABELS = {
	"AC", "AP", "Cancelled", "CD", "Chi", "CP", "Energy", "Essence",
	"Focus", "Fury", "GCD", "Holy", "INS", "Invalid", "LoS", "Mana", "MS", "OOM",
	"Points", "Primary", "Rage", "Range", "RP", "Runes", "Secondary", "Shards", "Stop", "Target", "Turn",
}
local MQT_VOICE_SOUNDS = {}
for _, label in ipairs(VOICE_LABELS) do
	MQT_VOICE_SOUNDS[#MQT_VOICE_SOUNDS + 1] = {
		name = "MQT: F1: " .. label,
		file = label .. "_F1.ogg",
		pack = "voice_f1",
	}
	MQT_VOICE_SOUNDS[#MQT_VOICE_SOUNDS + 1] = {
		name = "MQT: M1: " .. label,
		file = label .. "_M1.ogg",
		pack = "voice_m1",
	}
end

-- Merge voice sounds into the master list
for _, v in ipairs(MQT_VOICE_SOUNDS) do
	MQT_SOUNDS[#MQT_SOUNDS + 1] = v
end

-- Sound pack metadata (display order for the options UI)
NS.MQT_SOUND_PACKS = {
	{ key = "blow", label = "Blow" },
	{ key = "error", label = "Error" },
	{ key = "error2x", label = "Error2X" },
	{ key = "huh", label = "Huh" },
	{ key = "locked", label = "Locked" },
	{ key = "waterp", label = "WaterP" },
	{ key = "watery", label = "Watery" },
	{ key = "woosh", label = "Woosh" },
	{ key = "voice_f1", label = "Voice (Female)" },
	{ key = "voice_m1", label = "Voice (Male)" },
}
-- Build lookup tables from MQT_SOUNDS.
-- MQT_SOUND_SET starts empty; RegisterMedia() populates it
-- based on what is actually enabled in the DB.
local MQT_SOUND_SET = {}
local SOUND_FILE_FOR_NAME = {}   -- soundName → full file path
local MQT_SOUND_PACK_SOUNDS = {} -- packKey → { soundName, ... }
for _, s in ipairs(MQT_SOUNDS) do
	local dir = (s.pack == "voice_f1" or s.pack == "voice_m1") and VOICE_DIR or SOUND_DIR
	SOUND_FILE_FOR_NAME[s.name] = dir .. s.file
	local p = s.pack
	if not MQT_SOUND_PACK_SOUNDS[p] then MQT_SOUND_PACK_SOUNDS[p] = {} end

	MQT_SOUND_PACK_SOUNDS[p][#MQT_SOUND_PACK_SOUNDS[p] + 1] = s.name
end

NS.MQT_SOUND_SET = MQT_SOUND_SET -- reference; populated by RegisterMedia()
NS.MQT_SOUND_PACK_SOUNDS = MQT_SOUND_PACK_SOUNDS
NS.SOUND_FILE_FOR_NAME = SOUND_FILE_FOR_NAME
-- ============================================================
-- Font table
-- ============================================================
-- Filename format: 00FQcCXXTYY.ttf
-- XX = condensation step, YY = thickness step.
-- Both axes use the same set of values.
local COND_STEPS = { "00", "05", "10", "15", "20", "25", "30" }
local THICK_STEPS = { "00", "05", "10", "15", "20", "25", "30" }
local MQT_FONTS = {}
for _, c in ipairs(COND_STEPS) do
	for _, t in ipairs(THICK_STEPS) do
		MQT_FONTS[#MQT_FONTS + 1] = {
			name = string.format("MQT: FQ C%s T%s", c, t),
			file = string.format("00FQcC%sT%s.ttf", c, t),
			cond = c,
			thick = t,
		}
	end
end

local FONT_FILE_FOR_NAME = {}  -- fontName → full file path
local MQT_FONT_PACK_FONTS = {} -- condStep → { fontName, ... }
for _, f in ipairs(MQT_FONTS) do
	FONT_FILE_FOR_NAME[f.name] = FONT_DIR .. f.file
	if not MQT_FONT_PACK_FONTS[f.cond] then MQT_FONT_PACK_FONTS[f.cond] = {} end

	MQT_FONT_PACK_FONTS[f.cond][#MQT_FONT_PACK_FONTS[f.cond] + 1] = f.name
end

NS.MQT_FONTS = MQT_FONTS
NS.FONT_FILE_FOR_NAME = FONT_FILE_FOR_NAME
NS.MQT_FONT_PACK_FONTS = MQT_FONT_PACK_FONTS
NS.COND_STEPS = COND_STEPS
NS.THICK_STEPS = THICK_STEPS
-- ============================================================
-- Defaults
-- ============================================================
-- ============================================================
-- Per-category default sound pools
-- ============================================================
-- Defined after the sound/font loops so MQT_SOUND_PACK_SOUNDS
-- is already populated and we can build pack-based pools cleanly.
-- InitDB uses these when a pool key is missing from SavedVariables.
local function PoolFromPack(packKey)
	local t = {}
	for _, name in ipairs(MQT_SOUND_PACK_SOUNDS[packKey] or {}) do
		t[name] = true
	end

	return t
end

local DEFAULT_POOL_FOR
local function BuildDefaultPools()
	DEFAULT_POOL_FOR = {
		fail_cooldown = { ["MQT: F1: CD"] = true },
		fail_gcd = PoolFromPack("error"),
		fail_range = { ["MQT: F1: Range"] = true },
		fail_resourcePrimary = PoolFromPack("waterp"),
		fail_resourceSecondary = PoolFromPack("watery"),
		fail_noTarget = { ["MQT: F1: Target"] = true },
		fail_invalidTarget = { ["MQT: F1: Invalid"] = true },
		fail_facing = { ["MQT: F1: Turn"] = true },
		fail_crowdControl = {},
		fail_moving = PoolFromPack("error2x"),
		fail_los = { ["MQT: F1: LoS"] = true },
		fail_other = {},
		interruptSounds = PoolFromPack("error2x"),
	}
end

-- ============================================================
-- Disabled-by-default SharedMedia entries
-- ============================================================
-- Male voice sounds and selected font condensation steps are
-- off by default. Built here so DEFAULTS can reference them.
local DEFAULT_SM_SOUNDS = {}
for _, label in ipairs(VOICE_LABELS) do
	DEFAULT_SM_SOUNDS["MQT: M1: " .. label] = false
end

local DEFAULT_SM_FONTS = {}
local DISABLED_COND = { ["05"] = true, ["20"] = true, ["25"] = true, ["30"] = true }
for _, f in ipairs(MQT_FONTS) do
	if DISABLED_COND[f.cond] then
		DEFAULT_SM_FONTS[f.name] = false
	end
end

local DEFAULTS = {
	soundAlerts = {
		enabled = true,
		failEnabled = true,
		interruptEnabled = true,
		failChannel = "SFX",
		interruptChannel = "SFX",
		-- Post-cast suppression
		suppressionEnabled = true,
		suppressionWindow = 0.1,
		-- Fail reason filtering (per-category toggles)
		failReasons = {
			cooldown = false,
			gcd = true,
			range = true,
			resourcePrimary = true,
			resourceSecondary = true,
			noTarget = true,
			invalidTarget = true,
			facing = true,
			crowdControl = false,
			moving = false,
			los = true,
			other = false,
		},
		throttleEnabled = true,
		throttleWindow = 0.4,
		debugMode = false,
		-- Smart resource voice
		smartResource = {
			enabled = true,
			gender = "F1",
		},
		-- Alert condition suppression
		suppressConditions = {
			inCombat = false,
			outOfCombat = false,
			mounted = false,
			inVehicle = true,
		},
	},
	floatingText = {
		enabled = true,
		failEnabled = true,
		interruptEnabled = true,
		mode = "scroll",
		anchor = "CURSOR",
		x = 0,
		y = 50,
		fontSize = 16,
		outline = "OUTLINE",
		font = "Friz Quadrata TT",
	},
	autoMute = {
		enabled = true,
		autoMuted = false,
		savedSetting = nil,
	},
	uiScale = {
		enabled = false,
		scale = 0.5333,
	},
	ignoreList = {
		account = {},
		class = {},
		spec = {},
		char = {},
	},
	sharedMedia = {
		sounds = DEFAULT_SM_SOUNDS,
		fonts = DEFAULT_SM_FONTS,
	},
}
-- ============================================================
-- Saved variable bootstrap
-- ============================================================
local db
local function DeepCopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end

			DeepCopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

-- ============================================================
-- Media registration
-- ============================================================
-- Called from InitDB after the DB is ready.
-- Only enabled sounds/fonts are registered so disabled media
-- is not made available to other addons via LSM.
local function RegisterMedia()
	local sm = db.sharedMedia
	wipe(MQT_SOUND_SET)
	for _, s in ipairs(MQT_SOUNDS) do
		if sm.sounds[s.name] ~= false then
			LSM:Register("sound", s.name, SOUND_FILE_FOR_NAME[s.name])
			MQT_SOUND_SET[s.name] = true
		end
	end

	for _, f in ipairs(MQT_FONTS) do
		if sm.fonts[f.name] ~= false then
			LSM:Register("font", f.name, FONT_FILE_FOR_NAME[f.name])
		end
	end
end
-- Register bundled statusbar textures for use in other addons (e.g. Better Timeline).
LSM:Register("background", "MQT: Middle Fade", "Interface\\AddOns\\MellowQoLTweaks\\Textures\\MiddleFade.tga")
LSM:Register("background", "MQT: Middle Fade V2", "Interface\\AddOns\\MellowQoLTweaks\\Textures\\MiddleFadeV2.tga")
NS.RegisterMedia = RegisterMedia
-- Remove a sound from every MQT sound pool in the DB.
-- Called immediately when a sound is disabled in the
-- Shared Media options so it stops playing this session.
function NS.RemoveSoundFromAllPools(soundName)
	if not db then return end

	local sa = db.soundAlerts
	for _, key in ipairs(NS.FAIL_REASON_ORDER) do
		local pool = sa["fail_" .. key]
		if pool then pool[soundName] = nil end
	end

	if sa.interruptSounds then sa.interruptSounds[soundName] = nil end
end

local function InitDB()
	BuildDefaultPools()
	MellowQoLTweaksDB = MellowQoLTweaksDB or {}
	DeepCopyDefaults(DEFAULTS, MellowQoLTweaksDB)
	local sa = MellowQoLTweaksDB.soundAlerts
	for _, key in ipairs(NS.FAIL_REASON_ORDER) do
		local poolKey = "fail_" .. key
		if not sa[poolKey] then
			sa[poolKey] = DEFAULT_POOL_FOR[poolKey] or {}
		end
	end

	if not sa.interruptSounds then
		sa.interruptSounds = DEFAULT_POOL_FOR.interruptSounds or {}
	end

	db = MellowQoLTweaksDB
	NS.db = db
	NS.BuildMessageToCategory() -- defined in Modules\SoundAlerts.lua
	RegisterMedia()
end

-- ============================================================
-- Helpers
-- ============================================================
local function Msg(text)
	print("|cFF00FF00[Mellow QoL]|r " .. text)
end
NS.Msg = Msg
-- ============================================================
-- Font helpers
-- ============================================================
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local BUILTIN_FONTS = {
	["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
	["Arial Narrow"] = "Fonts\\ARIALN.TTF",
	["Morpheus"] = "Fonts\\MORPHEUS.TTF",
	["Skurri"] = "Fonts\\SKURRI.TTF",
}
function NS.GetFontList()
	local list = {}
	for _, name in ipairs(LSM:List("font")) do
		list[name] = name
	end

	return list
end

function NS.GetFontPath(name)
	local path = LSM:Fetch("font", name)
	if path then return path end

	return BUILTIN_FONTS[name] or DEFAULT_FONT
end

-- ============================================================
-- Sound pool playback
-- ============================================================
function NS.PlayRandomFromPool(poolKey, channel)
	local pool = db.soundAlerts[poolKey]
	if not pool then return end

	-- Gate on IsValid before Fetch: LSM:Fetch falls back to a
	-- default path for unregistered sounds rather than returning
	-- nil, so a plain nil-check is not sufficient.  IsValid is
	-- the same guard CountPool uses for the options UI count.
	local paths = {}
	for name, v in pairs(pool) do
		if v and LSM:IsValid("sound", name) then
			paths[#paths + 1] = LSM:Fetch("sound", name)
		end
	end

	if #paths == 0 then return end

	PlaySoundFile(paths[math.random(#paths)], channel)
end

-- ============================================================
-- Identity keys
-- ============================================================
local charKey, classKey, specKey
local function UpdateKeys()
	local _, classFile = UnitClass("player")
	charKey = UnitName("player") .. "-" .. GetRealmName()
	classKey = classFile
	specKey = tostring(GetSpecializationInfo(GetSpecialization() or 1))
	NS.charKey = charKey
	NS.classKey = classKey
	NS.specKey = specKey
end
NS.UpdateKeys = UpdateKeys
-- ============================================================
-- Slash commands
-- ============================================================
SLASH_MELLOWQOL1 = "/mqt"
SLASH_MELLOWQOL2 = "/mellow"
SlashCmdList["MELLOWQOL"] = function()
	NS.OpenSettings()
end
-- ============================================================
-- PLAYER_LOGIN
-- ============================================================
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("ADDON_LOADED")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
loginFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		InitDB()
	elseif event == "PLAYER_LOGIN" then
		UpdateKeys()
		NS.AutoMuteOnLogin()      -- defined in Modules\AutoMute.lua
		NS.ApplyUIScale()         -- defined in Modules\UIScale.lua
		NS.UpdateResourceVoiceMap() -- defined in Modules\SoundAlerts.lua
		NS.SetupSettings()        -- defined in Options.lua
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		UpdateKeys()
		NS.UpdateResourceVoiceMap()
	end
end)
