local ADDON_NAME, NS = ...
-- ============================================================
-- Feature: UI Scale Lock
-- ============================================================
local applyingScale = false
local scaleFrame = CreateFrame("Frame")
scaleFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
scaleFrame:SetScript("OnEvent", function()
	local db = NS.db
	if not db or not db.uiScale.enabled then return end
	if applyingScale then return end
	applyingScale = true
	SetCVar("uiScale", db.uiScale.scale)
	UIParent:SetScale(db.uiScale.scale)
	applyingScale = false
end)

function NS.ApplyUIScale()
	local db = NS.db
	if not db or not db.uiScale.enabled then return end
	applyingScale = true
	SetCVar("uiScale", db.uiScale.scale)
	UIParent:SetScale(db.uiScale.scale)
	applyingScale = false
end
