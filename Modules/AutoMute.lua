local ADDON_NAME, NS = ...
-- ============================================================
-- Feature: Auto Mute on AFK Logout
-- ============================================================
local muteTimer = nil
local savedMusicSetting = nil
local autoMuteFrame = CreateFrame("Frame")
autoMuteFrame:RegisterEvent("PLAYER_CAMPING")
autoMuteFrame:RegisterEvent("LOGOUT_CANCEL")
autoMuteFrame:SetScript("OnEvent", function(_, event)
	local db = NS.db
	if not db or not db.autoMute.enabled then return end

	if event == "PLAYER_CAMPING" then
		if UnitIsAFK("player") then
			savedMusicSetting = GetCVar("Sound_EnableMusic")
			if savedMusicSetting == "1" then
				NS.Msg(
					"AFK logout detected. Music will be muted in 19 seconds to silence the login screen. Cancel logout to prevent this.")
				muteTimer = C_Timer.After(19, function()
					SetCVar("Sound_EnableMusic", "0")
					db.autoMute.autoMuted = true
					db.autoMute.savedSetting = savedMusicSetting
					muteTimer = nil
				end)
			end
		end
	elseif event == "LOGOUT_CANCEL" then
		if muteTimer then
			muteTimer:Cancel()
			muteTimer = nil
			savedMusicSetting = nil
		end
		db.autoMute.autoMuted = false
		db.autoMute.savedSetting = nil
	end
end)

-- Called from Core.lua at PLAYER_LOGIN to restore music if
-- the previous session ended with an AFK auto-logout.
function NS.AutoMuteOnLogin()
	local db = NS.db
	if db.autoMute.autoMuted and db.autoMute.savedSetting then
		SetCVar("Sound_EnableMusic", db.autoMute.savedSetting)
		NS.Msg("Your last logout was automatic. Music has been re-enabled.")
		db.autoMute.autoMuted = false
		db.autoMute.savedSetting = nil
	end
end
