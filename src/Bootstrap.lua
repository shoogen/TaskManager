local addonName, addonTable = ...

local L = LibStub("AceLocale-3.0"):GetLocale("TaskManager")
local addon = LibStub("AceAddon-3.0"):NewAddon("TaskManager", "AceEvent-3.0")
addonTable.addon = addon

----------------------------
-- Addon Lifecycle functions
----------------------------

function addon:OnInitialize()
    addon.guid = UnitGUID("player") -- cache guid call

    -- TODO back up config in case of crash?
    -- TODO and/or use import strings so people can share QuestIDs they find
    if not TM_TASKS then TM_TASKS = {} end
    if not TM_STATUS then TM_STATUS = {} end
    if not TM_WINDOW then TM_WINDOW = { width = 333, height = 500 } end

    LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(L["Title"], {
        type = "launcher",
        icon = "Interface\\Icons\\inv_10_inscription_illusoryspellscrolls_color10",
        OnClick = function(frame, buttonName) TM_AddonCompartmentFunc(addonName, buttonName) end
    })
end

function addon:OnEnable()
    addon.guid = UnitGUID("player") -- just in case init didn't work

    -- in an ideal world, we could listen for specific events and update only relevant data
    -- for now, it is WAY more straightforward to just update all data on a timer
    if TM_TIMER then TM_TIMER:Cancel() end
    TM_TIMER = C_Timer.NewTicker(1, function()
        --local start = debugprofilestop()

        if not InCombatLockdown() then
            addon:PurgeExpired() -- could be daily
            local changed = addon:UpdateAll()
            if changed then addon:RefreshWindow() end
        end

        --local finish = debugprofilestop()
        --print(finish - start)
    end)
end

function addon:OnDisable()
    if TM_TIMER then TM_TIMER:Cancel() end
    TM_TIMER = nil

    addon:UpdateAll()
end

-----------------
-- Minimap button
-----------------

function TM_AddonCompartmentFunc(addonName, buttonName, menuButtonFrame)
    if TM_FRAME and TM_FRAME:IsShown() then
        TM_FRAME:Hide()
    else
        addon:ShowWindow()
    end
end

------------------
-- Slash commands
------------------

SLASH_TASKMANAGER1 = "/taskmanager"
SLASH_TASKMANAGER2 = "/tm"
SlashCmdList.TASKMANAGER = function(msg)
    local tokens = {}
    for token in string.gmatch(msg, "(%w+)") do
        table.insert(tokens, token)
    end

    if tokens[1] == "show" then
        addon:ShowWindow()
        return
    end

    if tokens[1] == "boss" then
        local i = tonumber(tokens[2])
        local j = tonumber(tokens[3])
        local k = tonumber(tokens[4])

        addon:AddBoss(i, j, k, "BOSS", "", "never")
        addon:RefreshWindow()
        return
    end

    print("Unknown command")
end