local ADDON_NAME, NS = ...
local LSM = LibStub("LibSharedMedia-3.0")
local pendingSpellID = ""
local pendingScope = "account"
-- ============================================================
-- Shared value tables
-- ============================================================
local CHANNEL_VALUES = {
	Master = "Master",
	SFX = "Sound Effects",
	Music = "Music",
	Ambience = "Ambience",
	Dialog = "Dialog",
}
local SCOPE_VALUES = {
	account = "Account-wide",
	class = "Class",
	spec = "Specialization",
	char = "Character",
}
local OUTLINE_VALUES = {
	NONE = "None",
	OUTLINE = "Thin",
	THICKOUTLINE = "Thick",
}
local ANCHOR_VALUES = {
	CURSOR = "Cursor",
	CENTER = "Center",
	TOP = "Top",
	BOTTOM = "Bottom",
	LEFT = "Left",
	RIGHT = "Right",
	TOPLEFT = "Top Left",
	TOPRIGHT = "Top Right",
	BOTTOMLEFT = "Bottom Left",
	BOTTOMRIGHT = "Bottom Right",
}
local MODE_VALUES = {
	single = "Latest Only",
	scroll = "Scrolling List",
}
-- ============================================================
-- Sound Picker Popup (virtual scroll)
-- ============================================================
local PICKER_WIDTH = 420
local PICKER_HEIGHT = 480
local ROW_HEIGHT = 22
local VISIBLE_ROWS = 17
local SEARCH_HEIGHT = 26
local HEADER_HEIGHT = 30
local pickerFrame
local pickerRows = {}
local filteredList = {}
local activePoolKey
local ENTRY_SOUND = 1
local ENTRY_SEPARATOR = 2
local ENTRY_HEADER = 3
local RebuildFilteredList, UpdatePickerRows
RebuildFilteredList = function(searchText)
	wipe(filteredList)
	searchText = searchText and searchText:lower():trim() or ""
	local pool = NS.db and NS.db.soundAlerts[activePoolKey]
	if not pool then return end

	local allSounds = LSM:List("sound")
	local enabledNames = {}
	for _, name in ipairs(allSounds) do
		if pool[name] then
			if searchText == "" or name:lower():find(searchText, 1, true) then
				enabledNames[#enabledNames + 1] = name
			end
		end
	end

	table.sort(enabledNames)
	if #enabledNames > 0 then
		filteredList[#filteredList + 1] = { type = ENTRY_HEADER, text = "Enabled (" .. #enabledNames .. ")" }
		for _, name in ipairs(enabledNames) do
			filteredList[#filteredList + 1] = { type = ENTRY_SOUND, name = name }
		end

		filteredList[#filteredList + 1] = { type = ENTRY_SEPARATOR }
	end

	local mqtNames, otherNames = {}, {}
	for _, name in ipairs(allSounds) do
		if searchText == "" or name:lower():find(searchText, 1, true) then
			if NS.MQT_SOUND_SET[name] then
				mqtNames[#mqtNames + 1] = name
			else
				otherNames[#otherNames + 1] = name
			end
		end
	end

	table.sort(mqtNames)
	table.sort(otherNames)
	if #mqtNames > 0 then
		filteredList[#filteredList + 1] = { type = ENTRY_HEADER, text = "MQT Sounds" }
		for _, name in ipairs(mqtNames) do
			filteredList[#filteredList + 1] = { type = ENTRY_SOUND, name = name }
		end
	end

	if #mqtNames > 0 and #otherNames > 0 then
		filteredList[#filteredList + 1] = { type = ENTRY_SEPARATOR }
	end

	if #otherNames > 0 then
		filteredList[#filteredList + 1] = { type = ENTRY_HEADER, text = "Other Sounds (LibSharedMedia)" }
		for _, name in ipairs(otherNames) do
			filteredList[#filteredList + 1] = { type = ENTRY_SOUND, name = name }
		end
	end
end
UpdatePickerRows = function()
	if not pickerFrame or not activePoolKey then return end

	local pool = NS.db.soundAlerts[activePoolKey]
	local offset = FauxScrollFrame_GetOffset(pickerFrame.scrollFrame)
	for i = 1, VISIBLE_ROWS do
		local row = pickerRows[i]
		local entry = filteredList[offset + i]
		if entry and entry.type == ENTRY_SOUND then
			row.check:Show()
			row.check:SetChecked(pool[entry.name] and true or false)
			row.label:SetText(entry.name)
			row.label:Show()
			row.preview:Show()
			row.header:Hide()
			row.separator:Hide()
			row.soundName = entry.name
			row:Show()
		elseif entry and entry.type == ENTRY_HEADER then
			row.check:Hide()
			row.label:Hide()
			row.preview:Hide()
			row.separator:Hide()
			row.header:SetText("|cFFFFD100" .. entry.text .. "|r")
			row.header:Show()
			row.soundName = nil
			row:Show()
		elseif entry and entry.type == ENTRY_SEPARATOR then
			row.check:Hide()
			row.label:Hide()
			row.preview:Hide()
			row.header:Hide()
			row.separator:Show()
			row.soundName = nil
			row:Show()
		else
			row:Hide()
		end
	end

	FauxScrollFrame_Update(pickerFrame.scrollFrame, #filteredList, VISIBLE_ROWS, ROW_HEIGHT)
end
local function OnSoundToggled()
	RebuildFilteredList(pickerFrame and pickerFrame.search:GetText() or "")
	UpdatePickerRows()
	LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
end

local function CreatePickerFrame()
	local f = CreateFrame("Frame", "MQTSoundPickerFrame", UIParent, "BackdropTemplate")
	f:SetSize(PICKER_WIDTH, PICKER_HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata("TOOLTIP")
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	f.title:SetPoint("TOP", 0, -16)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)
	f:SetScript("OnHide", function()
		LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
	end)
	local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	search:SetSize(PICKER_WIDTH - 60, SEARCH_HEIGHT)
	search:SetPoint("TOPLEFT", 20, -(HEADER_HEIGHT + 16))
	search:SetAutoFocus(false)
	search:SetMaxLetters(60)
	local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	searchLabel:SetPoint("RIGHT", search, "LEFT", -6, 0)
	searchLabel:SetText("Search:")
	search:SetScript("OnTextChanged", function(self)
		RebuildFilteredList(self:GetText())
		FauxScrollFrame_SetOffset(f.scrollFrame, 0)
		UpdatePickerRows()
	end)
	search:SetScript("OnEscapePressed", search.ClearFocus)
	f.search = search
	local scrollParent = CreateFrame("Frame", nil, f)
	scrollParent:SetPoint("TOPLEFT", 16, -(HEADER_HEIGHT + SEARCH_HEIGHT + 22))
	scrollParent:SetPoint("BOTTOMRIGHT", -36, 12)
	local scroll = CreateFrame("ScrollFrame", "MQTSoundPickerScroll", scrollParent, "FauxScrollFrameTemplate")
	scroll:SetAllPoints()
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UpdatePickerRows)
	end)
	f.scrollFrame = scroll
	for i = 1, VISIBLE_ROWS do
		local row = CreateFrame("Frame", nil, scrollParent)
		row:SetSize(PICKER_WIDTH - 60, ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
		local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		check:SetSize(22, 22)
		check:SetPoint("LEFT", 0, 0)
		check:SetScript("OnClick", function(self)
			if not activePoolKey or not row.soundName then return end

			local pool = NS.db.soundAlerts[activePoolKey]
			pool[row.soundName] = self:GetChecked() and true or nil
			OnSoundToggled()
		end)
		row.check = check
		local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("LEFT", check, "RIGHT", 4, 0)
		label:SetPoint("RIGHT", row, "RIGHT", -70, 0)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		row.label = label
		local preview = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		preview:SetSize(60, 20)
		preview:SetPoint("RIGHT", 0, 0)
		preview:SetText("Preview")
		preview:SetScript("OnClick", function()
			if not row.soundName then return end

			local path = LSM:Fetch("sound", row.soundName)
			if path then PlaySoundFile(path, "Master") end
		end)
		row.preview = preview
		local header = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		header:SetPoint("LEFT", 4, 0)
		header:SetJustifyH("LEFT")
		header:Hide()
		row.header = header
		local sep = row:CreateTexture(nil, "OVERLAY")
		sep:SetHeight(1)
		sep:SetPoint("LEFT", 4, 0)
		sep:SetPoint("RIGHT", -4, 0)
		sep:SetColorTexture(0.5, 0.5, 0.5, 0.4)
		sep:Hide()
		row.separator = sep
		pickerRows[i] = row
	end

	tinsert(UISpecialFrames, "MQTSoundPickerFrame")
	f:Hide()
	return f
end

function NS.OpenSoundPicker(poolKey, title)
	if not pickerFrame then pickerFrame = CreatePickerFrame() end

	activePoolKey = poolKey
	pickerFrame.title:SetText(title or "Sound Pool")
	pickerFrame.search:SetText("")
	RebuildFilteredList("")
	FauxScrollFrame_SetOffset(pickerFrame.scrollFrame, 0)
	UpdatePickerRows()
	pickerFrame:Show()
	pickerFrame:Raise()
end

local function CountPool(poolKey)
	local pool = NS.db and NS.db.soundAlerts[poolKey]
	if not pool then return 0 end

	local n = 0
	-- Only count sounds that LSM can still resolve to a path.
	-- A sound may be enabled in SavedVariables but its source
	-- addon (e.g. a SharedMedia pack) may have since been removed,
	-- leaving a stale entry that can never actually play.
	for name, v in pairs(pool) do
		if v and LSM:IsValid("sound", name) then n = n + 1 end
	end

	return n
end

-- ============================================================
-- Build the Spell Fails tree node args.
-- Master group: master toggle, channel, suppression, throttle.
-- Per-category groups: enable toggle, sound count, Edit button.
-- ============================================================
local function BuildFailSoundsNodeArgs()
	local args = {}
	local db = NS.db
	if not db then return args end

	args.masterGroup = {
		type = "group",
		name = "General",
		inline = true,
		order = 1,
		args = {
			failEnabled = {
				type = "toggle",
				name = "Enable",
				desc = "Master toggle for all spell fail sound categories.",
				order = 1,
				width = 1,
				get = function() return db.soundAlerts.failEnabled end,
				set = function(_, v) db.soundAlerts.failEnabled = v end,
				disabled = function() return not db.soundAlerts.enabled end,
			},
			failChannel = {
				type = "select",
				name = "Sound Channel",
				desc = "Audio channel used for all spell fail sounds.",
				order = 2,
				width = 1,
				values = CHANNEL_VALUES,
				get = function() return db.soundAlerts.failChannel end,
				set = function(_, v) db.soundAlerts.failChannel = v end,
				disabled = function() return not db.soundAlerts.enabled or not db.soundAlerts.failEnabled end,
			},
			spacer1 = { type = "description", name = "", order = 2.5, width = "full" },
			suppressionEnabled = {
				type = "toggle",
				name = "Post-Cast Suppression",
				desc =
				"Suppress fail sounds for a short window after a successful cast. Prevents alerts from button-mashing overlap where extra keypresses land just after a spell goes off.",
				order = 3,
				width = 1,
				get = function() return db.soundAlerts.suppressionEnabled end,
				set = function(_, v) db.soundAlerts.suppressionEnabled = v end,
				disabled = function() return not db.soundAlerts.enabled or not db.soundAlerts.failEnabled end,
			},
			suppressionWindow = {
				type = "range",
				name = "Suppression Window",
				desc = "How long after a successful cast to suppress fail sounds (seconds).",
				order = 4,
				width = 1,
				min = 0.01,
				max = 0.5,
				step = 0.01,
				get = function() return db.soundAlerts.suppressionWindow end,
				set = function(_, v) db.soundAlerts.suppressionWindow = v end,
				disabled = function()
					return not db.soundAlerts.enabled
							or not db.soundAlerts.failEnabled
							or not db.soundAlerts.suppressionEnabled
				end,
			},
			spacer2 = { type = "description", name = "", order = 4.9, width = 0.2 },
			throttleEnabled = {
				type = "toggle",
				name = "Throttle Alerts",
				desc = "Prevent the same fail category from triggering sounds more often than the throttle window allows.",
				order = 5,
				width = 0.8,
				get = function() return db.soundAlerts.throttleEnabled end,
				set = function(_, v) db.soundAlerts.throttleEnabled = v end,
				disabled = function() return not db.soundAlerts.enabled or not db.soundAlerts.failEnabled end,
			},
			throttleWindow = {
				type = "range",
				name = "Throttle Window",
				desc = "Minimum seconds between alerts of the same fail category.",
				order = 6,
				width = 1,
				min = 0.1,
				max = 1.0,
				step = 0.1,
				get = function() return db.soundAlerts.throttleWindow end,
				set = function(_, v) db.soundAlerts.throttleWindow = v end,
				disabled = function()
					return not db.soundAlerts.enabled
							or not db.soundAlerts.failEnabled
							or not db.soundAlerts.throttleEnabled
				end,
			},
		},
	}
	-- All 12 categories as flat rows inside a single inline group.
	-- Eliminates 12 individual bordered boxes in favour of a compact table.
	local catArgs = {}
	for i, key in ipairs(NS.FAIL_REASON_ORDER) do
		local label = NS.FAIL_REASON_LABELS[key]
		local poolKey = "fail_" .. key
		local capturedKey = key
		local capturedPoolKey = poolKey
		local capturedLabel = label
		local base = i * 10
		catArgs["enabled_" .. key] = {
			type = "toggle",
			name = label,
			desc = "Play a sound when a cast fails due to: " .. label,
			order = base + 1,
			width = 1.3,
			get = function() return db.soundAlerts.failReasons[capturedKey] end,
			set = function(_, v) db.soundAlerts.failReasons[capturedKey] = v end,
			disabled = function() return not db.soundAlerts.enabled or not db.soundAlerts.failEnabled end,
		}
		catArgs["edit_" .. key] = {
			type = "execute",
			name = function()
				local n = CountPool(capturedPoolKey)
				return "Edit (" .. n .. ")"
			end,
			order = base + 2,
			width = 0.6,
			func = function() NS.OpenSoundPicker(capturedPoolKey, capturedLabel) end,
			disabled = function() return not db.soundAlerts.enabled end,
		}
		if i % 2 == 0 then
			catArgs["spacer_" .. key] = {
				type = "description",
				name = "",
				order = base + 3,
				width = "full",
			}
		end
	end

	args.categoriesGroup = {
		type = "group",
		name = "Categories",
		inline = true,
		order = 2,
		args = catArgs,
	}
	return args
end

-- ============================================================
-- Build ignore list display args dynamically
-- ============================================================
local function BuildIgnoreListArgs()
	local args = {}
	local db = NS.db
	if not db or not db.ignoreList then return args end

	local il = db.ignoreList
	local order = 1
	local function addEntries(tbl, scopeLabel, scopeKey)
		for spellID in pairs(tbl) do
			local name = C_Spell.GetSpellName(spellID) or "Unknown"
			local key = scopeKey .. "_" .. spellID
			args[key] = {
				type = "description",
				name = "|cFFFFD100[" .. scopeLabel .. "]|r  " .. name .. "  |cFF888888(" .. spellID .. ")|r",
				order = order,
				width = 2.4,
				fontSize = "medium",
			}
			order = order + 1
			args[key .. "_rm"] = {
				type = "execute",
				name = "Remove",
				order = order,
				width = 0.6,
				func = function()
					NS.RemoveIgnored(spellID, scopeKey)
					LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
				end,
				disabled = function() return not db.soundAlerts.enabled end,
			}
			order = order + 1
		end
	end

	addEntries(il.account, "Account", "account")
	if NS.classKey and il.class[NS.classKey] then addEntries(il.class[NS.classKey], "Class", "class") end

	if NS.specKey and il.spec[NS.specKey] then addEntries(il.spec[NS.specKey], "Spec", "spec") end

	if NS.charKey and il.char[NS.charKey] then addEntries(il.char[NS.charKey], "Char", "char") end

	if order == 1 then
		args.empty = {
			type = "description",
			name = "|cFF888888No spells ignored. Ignored spells will not trigger sound or text alerts.|r",
			order = 1,
			fontSize = "medium",
		}
	end

	return args
end

-- ============================================================
-- Build Shared Media → Sounds args
-- ============================================================
local VOICE_PACK_KEYS = { voice_f1 = true, voice_m1 = true }
-- voiceOnly: true = voice packs only, false = SFX packs only, nil = all
local function BuildSharedMediaSoundsArgs(voiceOnly)
	local args = {}
	local db = NS.db
	if not db then return args end

	args.desc = {
		type = "description",
		name = "Control which MQT sound packs are registered with LibSharedMedia. "
				.. "Disabling a sound prevents it from playing and hides it from the sound picker. "
				.. "Pool assignments are preserved, so re-enabling restores everything as it was. "
				.. "\n|cFFFF0000Changes in this menu require a UI reload to take effect.|r",
		order = 1,
		width = "full",
		fontSize = "medium",
	}
	args.spacer0 = { type = "description", name = "", order = 2, width = "full" }
	for i, pack in ipairs(NS.MQT_SOUND_PACKS) do
		local isVoice = VOICE_PACK_KEYS[pack.key] and true or false
		if voiceOnly == nil or isVoice == voiceOnly then
			local packKey = pack.key
			local packLabel = pack.label
			local packSounds = NS.MQT_SOUND_PACK_SOUNDS[packKey] or {}
			local packArgs = {}
			-- Pack master toggle: on if every sound in the pack is enabled.
			packArgs.packToggle = {
				type = "toggle",
				name = "Toggle All",
				order = 1,
				width = "full",
				get = function()
					local sm = db.sharedMedia.sounds
					for _, name in ipairs(packSounds) do
						if sm[name] == false then return false end
					end

					return true
				end,
				set = function(_, v)
					local sm = db.sharedMedia.sounds
					for _, name in ipairs(packSounds) do
						if v then
							sm[name] = nil
							LSM:Register("sound", name, NS.SOUND_FILE_FOR_NAME[name])
							NS.MQT_SOUND_SET[name] = true
						else
							sm[name] = false
							NS.MQT_SOUND_SET[name] = nil
						end
					end

					LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
				end,
			}
			-- Individual sound toggles.
			for j, soundName in ipairs(packSounds) do
				local capturedName = soundName
				local shortName = soundName:gsub("^MQT: ", "")
				packArgs["sound_" .. j] = {
					type = "toggle",
					name = shortName,
					order = 10 + j,
					width = 0.75,
					get = function()
						return db.sharedMedia.sounds[capturedName] ~= false
					end,
					set = function(_, v)
						local sm = db.sharedMedia.sounds
						if v then
							sm[capturedName] = nil
							LSM:Register("sound", capturedName, NS.SOUND_FILE_FOR_NAME[capturedName])
							NS.MQT_SOUND_SET[capturedName] = true
						else
							sm[capturedName] = false
							NS.MQT_SOUND_SET[capturedName] = nil
						end

						LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
					end,
				}
			end

			args[packKey .. "Group"] = {
				type = "group",
				name = packLabel,
				inline = true,
				order = 10 + i,
				args = packArgs,
			}
		end
	end

	return args
end

-- ============================================================
-- Build Shared Media → Fonts args
-- ============================================================
local function BuildSharedMediaFontsArgs()
	local args = {}
	local db = NS.db
	if not db then return args end

	args.desc = {
		type = "description",
		name = "Control which MQT fonts are registered with LibSharedMedia. "
				.. "\nC = condensation (00 = normal width, 30 = most condensed). "
				.. "\nT = thickness/weight (00 = thin, 30 = heavy). "
				.. "\n|cFFFF0000Changes in this menu require a UI reload to take effect.|r",
		order = 1,
		width = "full",
		fontSize = "medium",
	}
	args.spacer0 = { type = "description", name = "", order = 2, width = "full" }
	for i, c in ipairs(NS.COND_STEPS) do
		local setFonts = NS.MQT_FONT_PACK_FONTS[c] or {}
		local setArgs = {}
		-- Set master toggle: on if every font in this C-group is enabled.
		setArgs.setToggle = {
			type = "toggle",
			name = "Toggle All",
			order = 1,
			width = "full",
			get = function()
				local sm = db.sharedMedia.fonts
				for _, name in ipairs(setFonts) do
					if sm[name] == false then return false end
				end

				return true
			end,
			set = function(_, v)
				local sm = db.sharedMedia.fonts
				for _, name in ipairs(setFonts) do
					if v then
						sm[name] = nil
						LSM:Register("font", name, NS.FONT_FILE_FOR_NAME[name])
					else
						sm[name] = false
					end
				end

				LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
			end,
		}
		-- Individual thickness toggles.
		for j, fontName in ipairs(setFonts) do
			local capturedName = fontName
			local tVal = fontName:match("T(%d+)$") or "??"
			setArgs["font_" .. j] = {
				type = "toggle",
				name = "T: " .. tVal,
				order = 10 + j,
				width = 0.5,
				get = function()
					return db.sharedMedia.fonts[capturedName] ~= false
				end,
				set = function(_, v)
					local sm = db.sharedMedia.fonts
					if v then
						sm[capturedName] = nil
						LSM:Register("font", capturedName, NS.FONT_FILE_FOR_NAME[capturedName])
					else
						sm[capturedName] = false
					end

					LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
				end,
			}
		end

		args["cond_" .. c .. "_Group"] = {
			type = "group",
			name = "C: " .. c,
			inline = true,
			order = 10 + i,
			args = setArgs,
		}
	end

	return args
end

-- ============================================================
-- AceConfig options table
-- ============================================================
local function BuildOptionsTable()
	local db = NS.db
	return {
		type = "group",
		name = "Mellow |cFF00FFFFQoL|r Tweaks",
		childGroups = "tab",
		args = {

			-- ═══════════════════════════════════════════════════════
			-- Tab 1: Sound Alerts (tree inside)
			-- ═══════════════════════════════════════════════════════
			soundAlerts = {
				type = "group",
				name = "Sound Alerts",
				order = 1,
				childGroups = "tree",
				args = {
					general = {
						type = "group",
						name = "General",
						order = 1,
						args = {
							infoGroup = {
								type = "group",
								name = "Info",
								inline = true,
								order = 0,
								args = {
									desc = {
										type = "description",
										name =
										"Plays a sound or voiceline when |cFFFF0000you|r fail to cast or get interrupted. Configure which type of fails/interrupts you want to hear in Spell fails and Interrupts tabs.",
										order = 1,
										fontSize = "medium",
									},
								},
							},
							enabledGroup = {
								type = "group",
								name = "General",
								inline = true,
								order = 1,
								args = {
									enabled = {
										type = "toggle",
										name = "Enable Module",
										desc = "Master toggle for all spell fail and interrupt sound notifications.",
										order = 1,
										width = 1,
										get = function() return db.soundAlerts.enabled end,
										set = function(_, v) db.soundAlerts.enabled = v end,
									},
									debugMode = {
										type = "toggle",
										name = "Debug Mode",
										desc =
										"Print to chat every time an alert fires, showing the resolved category, spell name, and raw error message. Useful for identifying why a spell ends up in a particular category.",
										order = 2,
										width = 1,
										get = function() return db.soundAlerts.debugMode end,
										set = function(_, v) db.soundAlerts.debugMode = v end,
										disabled = function() return not db.soundAlerts.enabled end,
									},
								},
							},
							conditionsGroup = {
								type = "group",
								name = "Suppress Alerts",
								inline = true,
								order = 3,
								args = {
									desc = {
										type = "description",
										name = "Prevent all sound and text alerts when the selected conditions apply.",
										order = 1,
										width = "full",
										fontSize = "medium",
									},
									spacer0 = { type = "description", name = "", order = 2, width = "full" },
									inCombat = {
										type = "toggle",
										name = "In Combat",
										order = 3,
										width = 1,
										get = function() return db.soundAlerts.suppressConditions.inCombat end,
										set = function(_, v) db.soundAlerts.suppressConditions.inCombat = v end,
										disabled = function() return not db.soundAlerts.enabled end,
									},
									outOfCombat = {
										type = "toggle",
										name = "Out of Combat",
										order = 4,
										width = 1,
										get = function() return db.soundAlerts.suppressConditions.outOfCombat end,
										set = function(_, v) db.soundAlerts.suppressConditions.outOfCombat = v end,
										disabled = function() return not db.soundAlerts.enabled end,
									},
									mounted = {
										type = "toggle",
										name = "Mounted",
										order = 5,
										width = 1,
										get = function() return db.soundAlerts.suppressConditions.mounted end,
										set = function(_, v) db.soundAlerts.suppressConditions.mounted = v end,
										disabled = function() return not db.soundAlerts.enabled end,
									},
									inVehicle = {
										type = "toggle",
										name = "In Vehicle",
										order = 6,
										width = 1,
										get = function() return db.soundAlerts.suppressConditions.inVehicle end,
										set = function(_, v) db.soundAlerts.suppressConditions.inVehicle = v end,
										disabled = function() return not db.soundAlerts.enabled end,
									},
									overrideBar = {
										type = "toggle",
										name = "Override Bar (Minigames)",
										desc =
										"Suppress alerts during minigames and scripted scenario controls that replace your action bar (e.g. Delve puzzles).",
										order = 7,
										width = 1,
										get = function() return db.soundAlerts.suppressConditions.overrideBar end,
										set = function(_, v) db.soundAlerts.suppressConditions.overrideBar = v end,
										disabled = function() return not db.soundAlerts.enabled end,
									},
								},
							},
							smartResourceGroup = {
								type = "group",
								name = "Smart Resource Voice",
								inline = true,
								order = 4,
								args = {
									desc = {
										type = "description",
										name =
										"When enabled, resource fail alerts play the voiced sound matching your current spec's resource instead of the manually assigned sound pool.",
										order = 1,
										width = "full",
										fontSize = "medium",
									},
									spacer0 = { type = "description", name = "", order = 2, width = "full" },
									enabled = {
										type = "toggle",
										name = "Enable Smart Resource Voice",
										order = 3,
										width = 1.5,
										get = function() return db.soundAlerts.smartResource.enabled end,
										set = function(_, v)
											db.soundAlerts.smartResource.enabled = v
											NS.UpdateResourceVoiceMap()
										end,
										disabled = function() return not db.soundAlerts.enabled or not db.soundAlerts.failEnabled end,
									},
									gender = {
										type = "select",
										name = "Voice",
										order = 4,
										width = 0.9,
										values = { F1 = "Female (F1)", M1 = "Male (M1)" },
										get = function() return db.soundAlerts.smartResource.gender end,
										set = function(_, v)
											db.soundAlerts.smartResource.gender = v
											NS.UpdateResourceVoiceMap()
										end,
										disabled = function()
											return not db.soundAlerts.enabled
													or not db.soundAlerts.failEnabled
													or not db.soundAlerts.smartResource.enabled
										end,
									},
									mappingDesc = {
										type = "description",
										name = function()
											local arv = NS.activeResourceVoice
											if not db.soundAlerts.smartResource.enabled then
												return "|cFF888888Enable to see current spec mapping.|r"
											end

											if not arv then
												return "|cFFFF4444No mapping available for current spec.|r"
											end

											local p = arv.primary and arv.primary:gsub("^MQT: %a+: ", "") or "—"
											local s = arv.secondary and arv.secondary:gsub("^MQT: %a+: ", "") or "—"
											return "Current: primary = |cFFFFD100" .. p .. "|r, secondary = |cFFFFD100" .. s .. "|r"
										end,
										order = 5,
										width = "full",
										fontSize = "medium",
									},
								},
							},
						},
					},

					spellFails = {
						type = "group",
						name = "Spell Fails",
						order = 2,
						args = BuildFailSoundsNodeArgs(),
					},

					interrupts = {
						type = "group",
						name = "Interrupts",
						order = 3,
						args = {
							interruptGroup = {
								type = "group",
								name = "General",
								inline = true,
								order = 1,
								args = {
									interruptEnabled = {
										type = "toggle",
										name = "Enable Interrupt Sounds",
										desc = "Play a sound when a spell cast is interrupted or a channel is broken.",
										order = 1,
										width = 1.5,
										get = function() return db.soundAlerts.interruptEnabled end,
										set = function(_, v) db.soundAlerts.interruptEnabled = v end,
										disabled = function() return not db.soundAlerts.enabled end,
									},
									interruptChannel = {
										type = "select",
										name = "Sound Channel",
										desc = "Audio channel used for interrupt sounds.",
										order = 2,
										width = 1,
										values = CHANNEL_VALUES,
										get = function() return db.soundAlerts.interruptChannel end,
										set = function(_, v) db.soundAlerts.interruptChannel = v end,
										disabled = function() return not db.soundAlerts.enabled or not db.soundAlerts.interruptEnabled end,
									},
									spacer1 = { type = "description", name = "", order = 3, width = 0.8 },
									edit = {
										type = "execute",
										name = function()
											local n = CountPool("interruptSounds")
											return "Edit (" .. n .. ")"
										end,
										order = 5,
										width = 0.6,
										func = function() NS.OpenSoundPicker("interruptSounds", "Interrupt Sound Pool") end,
										disabled = function() return not db.soundAlerts.enabled or not db.soundAlerts.interruptEnabled end,
									},
								},
							},
						},
					},

					floatingText = {
						type = "group",
						name = "Floating Text",
						order = 4,
						args = {
							floatingTextGroup = {
								type = "group",
								name = "Floating Text",
								inline = true,
								order = 1,
								args = {
									desc = {
										type = "description",
										name =
										"Shows the spell name as floating text that drifts upward and fades out when a cast fails or is interrupted.",
										order = 1,
										fontSize = "medium",
									},
									spacer0 = { type = "description", name = "", order = 2, width = "full" },
									enabled = {
										type = "toggle",
										name = "Enable Floating Text",
										desc = "Master toggle for floating spell name text.",
										order = 3,
										width = "full",
										get = function() return db.floatingText.enabled end,
										set = function(_, v) db.floatingText.enabled = v end,
										disabled = function() return not db.soundAlerts.enabled end,
									},
									failEnabled = {
										type = "toggle",
										name = "Show on Spell Fail",
										order = 4,
										width = 1,
										get = function() return db.floatingText.failEnabled end,
										set = function(_, v) db.floatingText.failEnabled = v end,
										disabled = function() return not db.soundAlerts.enabled or not db.floatingText.enabled end,
									},
									interruptEnabled = {
										type = "toggle",
										name = "Show on Interrupt",
										order = 5,
										width = 1,
										get = function() return db.floatingText.interruptEnabled end,
										set = function(_, v) db.floatingText.interruptEnabled = v end,
										disabled = function() return not db.soundAlerts.enabled or not db.floatingText.enabled end,
									},
									spacer1 = { type = "description", name = "", order = 6, width = "full" },
									mode = {
										type = "select",
										name = "Display Mode",
										desc =
										"Latest Only: replaces the previous text each time. Scrolling List: stacks multiple entries upward so rapid failures don't overlap.",
										order = 7,
										width = 1,
										values = MODE_VALUES,
										get = function() return db.floatingText.mode end,
										set = function(_, v) db.floatingText.mode = v end,
										disabled = function() return not db.soundAlerts.enabled or not db.floatingText.enabled end,
									},
									anchor = {
										type = "select",
										name = "Anchor",
										desc =
										"Where the floating text appears. Cursor follows the mouse. Other options anchor to a fixed screen position.",
										order = 8,
										width = 1,
										values = ANCHOR_VALUES,
										get = function() return db.floatingText.anchor end,
										set = function(_, v) db.floatingText.anchor = v end,
										disabled = function() return not db.soundAlerts.enabled or not db.floatingText.enabled end,
									},
									x = {
										type = "range",
										name = "X Offset",
										order = 10,
										width = 1,
										min = -500,
										max = 500,
										step = 1,
										get = function() return db.floatingText.x end,
										set = function(_, v) db.floatingText.x = v end,
										disabled = function() return not db.soundAlerts.enabled or not db.floatingText.enabled end,
									},
									y = {
										type = "range",
										name = "Y Offset",
										order = 11,
										width = 1,
										min = -500,
										max = 500,
										step = 1,
										get = function() return db.floatingText.y end,
										set = function(_, v) db.floatingText.y = v end,
										disabled = function() return not db.soundAlerts.enabled or not db.floatingText.enabled end,
									},
									spacer3 = { type = "description", name = "", order = 12, width = "full" },
									font = {
										type = "select",
										name = "Font",
										order = 13,
										width = 1,
										values = NS.GetFontList,
										get = function() return db.floatingText.font end,
										set = function(_, v) db.floatingText.font = v end,
										disabled = function() return not db.soundAlerts.enabled or not db.floatingText.enabled end,
									},
									outline = {
										type = "select",
										name = "Outline",
										order = 14,
										width = 1,
										values = OUTLINE_VALUES,
										get = function() return db.floatingText.outline end,
										set = function(_, v) db.floatingText.outline = v end,
										disabled = function() return not db.soundAlerts.enabled or not db.floatingText.enabled end,
									},
									fontSize = {
										type = "range",
										name = "Font Size",
										order = 15,
										width = 1,
										min = 8,
										max = 48,
										step = 1,
										get = function() return db.floatingText.fontSize end,
										set = function(_, v) db.floatingText.fontSize = v end,
										disabled = function() return not db.soundAlerts.enabled or not db.floatingText.enabled end,
									},
								},
							},
						},
					},

					ignoreList = {
						type = "group",
						name = "Ignore List",
						order = 5,
						args = {
							addGroup = {
								type = "group",
								name = "Add Spell",
								inline = true,
								order = 1,
								args = {
									desc = {
										type = "description",
										name = "Enter a spell ID to suppress its sound and text alerts. You can find spell IDs on Wowhead.",
										order = 1,
										fontSize = "medium",
									},
									spellInput = {
										type = "input",
										name = "Spell ID",
										order = 2,
										width = 1,
										get = function() return pendingSpellID end,
										set = function(_, v) pendingSpellID = v end,
										disabled = function() return not db.soundAlerts.enabled end,
									},
									scopeSelect = {
										type = "select",
										name = "Scope",
										order = 3,
										width = 1,
										values = SCOPE_VALUES,
										get = function() return pendingScope end,
										set = function(_, v) pendingScope = v end,
										disabled = function() return not db.soundAlerts.enabled end,
									},
									addBtn = {
										type = "execute",
										name = "Add",
										order = 4,
										width = 0.5,
										func = function()
											local id = tonumber(pendingSpellID)
											if not id then
												NS.Msg("Invalid spell ID.")
												return
											end

											if NS.AddIgnored(id, pendingScope) then
												pendingSpellID = ""
												LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
											end
										end,
										disabled = function() return not db.soundAlerts.enabled end,
									},
								},
							},
							ignoreListGroup = {
								type = "group",
								name = "Ignored Spells",
								inline = true,
								order = 2,
								args = BuildIgnoreListArgs(),
							},
						},
					},

				},
			},

			-- ═══════════════════════════════════════════════════════
			-- Tab 2: Auto Mute
			-- ═══════════════════════════════════════════════════════
			autoMute = {
				type = "group",
				name = "Auto Mute",
				order = 2,
				args = {
					muteGroup = {
						type = "group",
						name = "AFK Logout Music Mute",
						inline = true,
						order = 1,
						args = {
							desc = {
								type = "description",
								name =
								"When you get automatically logged out for being AFK, this will mute the music in the last few seconds to prevent the repetitive music from character select menu from playing. Your music setting is automatically restored the next time you log in.\n\nManual logouts are not affected. If you already have music disabled, this will not do anything.",
								order = 1,
								fontSize = "medium",
							},
							spacer = { type = "description", name = "", order = 2 },
							enabled = {
								type = "toggle",
								name = "Enable Auto Mute",
								desc = "Automatically mute music when the AFK auto-logout countdown begins.",
								order = 3,
								width = "full",
								get = function() return db.autoMute.enabled end,
								set = function(_, v) db.autoMute.enabled = v end,
							},
						},
					},
				},
			},

			-- ═══════════════════════════════════════════════════════
			-- Tab 3: UI Scale
			-- ═══════════════════════════════════════════════════════
			uiScale = {
				type = "group",
				name = "UI Scale",
				order = 3,
				args = {
					scaleGroup = {
						type = "group",
						name = "Persistent UI Scale",
						inline = true,
						order = 1,
						args = {
							desc = {
								type = "description",
								name =
								"Persistently ets the UI Scale to the specified value, even if you change the WoW window dimeansions, the scaling will reapply.\nFor 1080p, I recommend using 0.7111.\nFor 1040p, I recommend using 0.5333.",
								order = 1,
								fontSize = "medium",
							},
							spacer = { type = "description", name = "", order = 2 },
							enabled = {
								type = "toggle",
								name = "Enable UI Scale Lock",
								order = 3,
								width = "full",
								get = function() return db.uiScale.enabled end,
								set = function(_, v)
									db.uiScale.enabled = v
									if v then NS.ApplyUIScale() end
								end,
							},
							scale = {
								type = "range",
								name = "UI Scale",
								desc = "The exact UI scale value to maintain. Type a precise value in the input box (e.g. 0.5333).",
								order = 4,
								width = 2,
								min = 0.1,
								max = 2.0,
								bigStep = 0.01,
								step = 0.0001,
								get = function() return db.uiScale.scale end,
								set = function(_, v)
									db.uiScale.scale = v
									NS.ApplyUIScale()
								end,
								disabled = function() return not db.uiScale.enabled end,
							},
							scaleInput = {
								type = "input",
								name = "Precise Value",
								desc = "Type an exact scale value for full precision (e.g. 0.5333).",
								order = 5,
								width = 0.8,
								get = function() return tostring(db.uiScale.scale) end,
								set = function(_, v)
									local num = tonumber(v)
									if num and num >= 0.1 and num <= 2.0 then
										db.uiScale.scale = num
										NS.ApplyUIScale()
										LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
									else
										NS.Msg("Scale must be between 0.1 and 2.0")
									end
								end,
								disabled = function() return not db.uiScale.enabled end,
							},
						},
					},
				},
			},

			-- ═══════════════════════════════════════════════════════
			-- Tab 4: Shared Media
			-- ═══════════════════════════════════════════════════════
			sharedMedia = {
				type = "group",
				name = "Shared Media",
				order = 4,
				childGroups = "tree",
				args = {
					sounds_sfx = {
						type = "group",
						name = "Sounds: SFX",
						order = 1,
						args = BuildSharedMediaSoundsArgs(false),
					},
					sounds_voice = {
						type = "group",
						name = "Sounds: Voice",
						order = 2,
						args = BuildSharedMediaSoundsArgs(true),
					},
					fonts = {
						type = "group",
						name = "Fonts",
						order = 3,
						args = BuildSharedMediaFontsArgs(),
					},
				},
			},

		},
	}
end

-- ============================================================
-- Settings registration
-- ============================================================
function NS.OpenSettings()
	LibStub("AceConfigDialog-3.0"):Open(ADDON_NAME)
end

function NS.SetupSettings()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, BuildOptionsTable)
	LibStub("AceConfigDialog-3.0"):SetDefaultSize(ADDON_NAME, 980, 550)
	local panel = CreateFrame("Frame")
	local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	btn:SetText("Open Mellow |cFF00FFFFQoL|r Tweaks Settings")
	btn:SetPoint("TOPLEFT", 16, -16)
	btn:SetWidth(280)
	btn:SetScript("OnClick", NS.OpenSettings)
	local category = Settings.RegisterCanvasLayoutCategory(panel, "Mellow |cFF00FFFFQoL|r Tweaks")
	Settings.RegisterAddOnCategory(category)
end
