local addonName, addonTable = ...
local addon = addonTable.addon
local L = LibStub("AceLocale-3.0"):GetLocale("TaskManager")

local COLLAPSED = {}
local COLORS = {
    START = "\124cFF",
    END = "\124r",

    PROGRESS = "fff468",
    IGNORED = "c0c0c0",
    DONE = "00ffba",

    WARRIOR = "c69b6d",
    PALADIN = "f48cba",
    HUNTER = "aad372",
    ROGUE = "fff468",
    PRIEST = "f0ebe0",
    DEATHKNIGHT = "c41e3b",
    SHAMAN = "2359ff",
    MAGE = "68ccef",
    WARLOCK = "9382c9",
    MONK = "00ffba",
    DRUID = "ff7c0a",
    DEMONHUNTER = "a330c9",
    EVOKER = "33937F"
}

function addon:Trim(str)
    if str == nil then return nil end

    str = str:match("^%s*(.-)%s*$")

    if str == "" then return nil end
    return str
end

function addon:RefreshWindow()
    if TM_FRAME and TM_FRAME:IsShown() then
        addon:ShowWindow(TM_WINDOW.key, true)
    end
end

function addon:ShowWindow(key, refresh)
    TM_WINDOW.key = key

    if not TM_FRAME then
        TM_FRAME = addon:CreateMainFrame()
    end

    if not refresh then
        TM_FRAME.scrollFrame:SetVerticalScroll(0)
    end

    -- hide old tab elements
    for _, f in pairs(TM_FRAME.rows) do
        f:Hide()
    end

    TM_FRAME.backButton:Hide()
    TM_FRAME.plusButton:Hide()
    TM_FRAME.header:Hide()
    TM_FRAME.taskDialog:Hide()

    -- build and show new tab
    if key == "add" then
        -- Reset Type field
        UIDropDownMenu_EnableDropDown(TM_FRAME.dropdownType)
        UIDropDownMenu_SetText(TM_FRAME.dropdownType, L["quest"])

        -- Reset Quest field
        TM_FRAME.labelQuest:Show()

        TM_FRAME.editQuest:Show()
        TM_FRAME.editQuest:Enable()
        TM_FRAME.editQuest:SetText("")

        -- Reset Boss field(s)
        TM_FRAME.labelBoss:Hide()

        TM_FRAME.editBoss:Hide()
        TM_FRAME.editBoss:Enable()
        TM_FRAME.editBoss:SetText(L["DialogNoBoss"])
        TM_FRAME.editBoss.instanceid = nil
        TM_FRAME.editBoss.difficulty = nil
        TM_FRAME.editBoss.boss = nil

        -- Reset other fields
        TM_FRAME.editTitle:SetText("")
        TM_FRAME.editCategory:SetText("")
        TM_FRAME.saveButton:Disable()

        TM_FRAME.taskDialog:Show()
    elseif key then
        TM_FRAME.backButton:Show()
        TM_FRAME.header:SetText(TM_TASKS[key].title)
        TM_FRAME.header:Show()
        addon:CreateStatusFrames(key)
    else
        TM_FRAME.plusButton:Show()
        addon:CreateTaskFrames()
    end

    TM_FRAME:Show()
end

function addon:CreateMainFrame()
    local f = CreateFrame("Frame", "TM_FRAME", UIParent, "PortraitFrameTemplate")
    f:SetTitle(L["Title"])
    f:SetPortraitToAsset("Interface\\Icons\\inv_10_inscription_illusoryspellscrolls_color10")

    f:SetSize(TM_WINDOW.width or 333, TM_WINDOW.height or 500)
    if TM_WINDOW.top then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", TM_WINDOW.left, TM_WINDOW.top)
    else
        f:SetPoint("CENTER")
    end

    -- Movable
    f:SetMovable(true)
    f:SetClampedToScreen(true)

    f.TitleContainer:EnableMouse(true)
    f.TitleContainer:SetScript("OnMouseDown", function() f:StartMoving() end)
    f.TitleContainer:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        TM_WINDOW.left = f:GetLeft()
        TM_WINDOW.top = f:GetTop()
    end)

    -- Resizable
    f:SetResizable(true)
    f:SetResizeBounds(200, 100, 2000, 2000)

    f.resizeButton = CreateFrame("Button", nil, f)
    f.resizeButton:SetPoint("BOTTOMRIGHT", -6, 7)
    f.resizeButton:SetSize(16, 16)
    f.resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    f.resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    f.resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    f.resizeButton:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    f.resizeButton:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        TM_WINDOW.width = f:GetWidth()
        TM_WINDOW.height = f:GetHeight()
    end)

    -- Context Menu
    f.menu = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")

    -- Scroll Frame
    f.scrollFrame = CreateFrame("ScrollFrame", nil, f, "ScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", 16, -60)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", -27, 24)

    f.scrollChild = CreateFrame("Frame", nil, f.scrollFrame)
    f.scrollChild:SetSize(f.scrollFrame:GetWidth(), 10)
    f.scrollFrame:SetScrollChild(f.scrollChild)
    f.scrollFrame:SetScript("OnSizeChanged", function()
        f.scrollChild:SetWidth(f.scrollFrame:GetWidth())
    end)

    -- Buttons
    f.backButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.backButton:SetSize(80, 22)
    f.backButton:SetText(L["BackButton"])
    f.backButton:SetPoint("RIGHT", f, "TOPRIGHT", -8, -38)
    f.backButton:SetScript("OnClick", function() addon:ShowWindow() end)

    f.plusButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.plusButton:SetSize(30, 22)
    f.plusButton:SetText("+")
    f.plusButton:SetPoint("RIGHT", f, "TOPRIGHT", -8, -38)
    f.plusButton:SetScript("OnClick", function() addon:ShowWindow("add") end)

    -- Header Text
    f.header = f:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.header:SetPoint("LEFT", f, "TOPLEFT", 60, -38)

    -- Rows
    f.rows = {}

    -- Add Task Dialog
    addon:CreateAddTaskFrame(f)

    return f
end

function addon:CreateRowFrame(idx)
    local row = TM_FRAME.rows[idx]
    if not row then
        row = CreateFrame("Frame", nil, TM_FRAME.scrollChild)
        TM_FRAME.rows[idx] = row
        row.widgets = {}

        local prev = TM_FRAME.rows[idx - 1]
        if prev then
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, 0)
        else
            row:SetPoint("TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", 0, 0)
        end

        function row:ShowWidget(name, func)
            local w = row.widgets
            for _, f in pairs(w) do
                f:Hide()
            end

            if not w[name] then w[name] = func(addon, row) end

            local f = w[name]
            row:SetHeight(f:GetHeight())
            f:Show()
            return f
        end
    end

    row:Show()
    return row
end

function addon:CreateTaskFrames()
    local sorted = {}
    local categories = {}
    local count = 0
    for key, task in pairs(TM_TASKS) do
        -- add tasks to the list
        local status = TM_STATUS[addon.guid][key]
        local category = addon:Trim(task.category) or L["MissingCategory"]

        if not categories[category] then count = count + 1 end
        if COLLAPSED[category] then count = count + 69 end -- force show
        categories[category] = true

        -- only if visible
        if not COLLAPSED[category] then
            table.insert(sorted, { category = category, sort = task.questid or task.instanceid, key = key, completed = status and status.completed, ignored = addon:IsIgnored(addon.guid, key) })
        end
    end

    -- only show categories if needed
    if count > 1 then
        for category, _ in pairs(categories) do
            table.insert(sorted, { category = category, sort = -1 })
        end
    end

    -- TODO should allow user-defined ordering
    -- sort our list by category, then by questid
    table.sort(sorted, function(a, b)
        if a.category == b.category then
            return a.sort < b.sort
        else
            return a.category < b.category
        end
    end)

    -- create rows in UI
    for idx, entry in ipairs(sorted) do
        local row = addon:CreateRowFrame(idx)

        if entry.key then
            local f = row:ShowWidget("task", addon.CreateTaskFrame)
            f.key = entry.key
            f.checkbox:SetChecked(entry.completed)
            f:SetSummary(entry.key)
            f:SetTitle(TM_TASKS[entry.key], entry.ignored)
        else
            local f = row:ShowWidget("category", addon.CreateCategoryFrame)
            f.Name:SetText(entry.category)
            f:SetCollapsed(COLLAPSED[entry.category])
        end
    end
end

function addon:CreateCategoryFrame(parent)
    local f = CreateFrame("Button", nil, parent, "TokenButtonTemplate")
    f:SetPoint("TOPLEFT", 0, 0)
    f:SetPoint("TOPRIGHT", 0, 0)

    f.Name:SetFontObject("GameFontNormal")
    f.Name:SetPoint("LEFT", 22, 0)

    f.Check:Hide()
    f.LinkButton:Hide()

    f.Highlight:SetTexture("Interface\\TokenFrame\\UI-TokenFrame-CategoryButton")
    f.Highlight:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -2)
    f.Highlight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 2)

    f.ExpandIcon:Show()
    function f:SetCollapsed(collapsed)
        if collapsed then
            f.ExpandIcon:SetTexCoord(0, 0.4375, 0, 0.4375)
        else
            f.ExpandIcon:SetTexCoord(0.5625, 1, 0, 0.4375)
        end
    end

    f:SetScript("OnClick", function()
        local category = f.Name:GetText()
        COLLAPSED[category] = not COLLAPSED[category]
        addon:RefreshWindow()
    end)

    return f
end

function addon:CreateTaskFrame(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 0, 0)
    f:SetPoint("TOPRIGHT", 0, 0)

    f.checkbox = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.checkbox:SetPoint("TOPLEFT")
    f.checkbox:Disable()
    f.checkbox:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    f.checkbox:SetSize(20, 20)
    f:SetHeight(20)

    f.summary = f:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.summary:SetPoint("LEFT", f.checkbox, "RIGHT")
    function f:SetSummary(key)
        local complete, total = 0, 0

        for guid, toon in pairs(TM_STATUS) do
            if not addon:IsIgnored(guid, key) then
                total = total + 1

                local status = toon[key]
                if status and status.completed then
                    complete = complete + 1
                end
            end
        end

        local color = COLORS.PROGRESS
        if complete >= total then color = COLORS.DONE end

        f.summary:SetText(COLORS.START .. color .. tostring(complete) .. "/" .. tostring(total) .. COLORS.END)
    end

    f.title = f:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.title:SetPoint("LEFT", f.checkbox, "RIGHT", 50, 0)
    function f:SetTitle(task, ignored)
        local str = addon:Trim(task.title) or L["MissingTitle"]
        if task.reset and task.reset ~= "never" then
            str = str .. " (" .. L[task.reset] .. ")"
        end
        if ignored then
            str = COLORS.START .. COLORS.IGNORED .. "-" .. str .. "-" .. COLORS.END
        end
        f.title:SetText(str)
    end

    f.title:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            local menu = {
                { text = L["EditTask"], arg1 = f, func = addon.MenuEditTask },
                { text = L["RemoveTask"], arg1 = f, func = addon.MenuRemoveTask }
            }

            EasyMenu(menu, TM_FRAME.menu, "cursor", 0 , 0, "MENU")
        else
            addon:ShowWindow(f.key)
        end
    end)

    return f
end

function addon:CreateStatusFrames(key)
    local myrealm = TM_STATUS[addon.guid].info.realm

    local sorted = {}
    for guid, toon in pairs(TM_STATUS) do
        local ignored = addon:IsIgnored(guid, key)

        local color = COLORS[toon.info.class]
        if ignored then color = COLORS.IGNORED end

        local realm = ""
        if toon.info.realm ~= myrealm then realm = "-" .. toon.info.realm end

        local text = COLORS.START .. color .. toon.info.level .. " " .. toon.info.name .. realm .. COLORS.END
        local sort = "a"
        local completed = false

        -- determine status
        local status = TM_STATUS[guid][key]
        if status and status.completed then
            sort = "k"
            completed = true
        elseif status and status.progress then
            text = text .. " " .. status.progress
        else
            sort = "b"
        end

        -- disable ignored characters
        if ignored then
            sort = "z"
            text = COLORS.START .. COLORS.IGNORED .. "-" .. text .. "-" .. COLORS.END
        end

        table.insert(sorted, { text = text, completed = completed, guid = guid, sort = sort .. "#" .. (toon.info.realm or "") .. "#" .. toon.info.name })
    end
    table.sort(sorted, function(a, b) return a.sort < b.sort end)

    for idx, entry in ipairs(sorted) do
        local row = addon:CreateRowFrame(idx)
        local f = row:ShowWidget("status", addon.CreateStatusFrame)

        f.checkbox:SetChecked(entry.completed)
        f.text:SetText(entry.text)
        f.guid = entry.guid
        f.key = key
    end
end

function addon:CreateStatusFrame(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 0, 0)
    f:SetPoint("TOPRIGHT", 0, 0)

    f.checkbox = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.checkbox:SetPoint("TOPLEFT")
    f.checkbox:Disable()
    f.checkbox:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    f.checkbox:SetSize(20, 20)
    f:SetHeight(20)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.text:SetPoint("LEFT", f.checkbox, "RIGHT")

    f.text:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            local menu = {}
            local toon = TM_STATUS[f.guid] or { info={} }

            local text = "IgnoreTask"
            if addon:IsIgnored(f.guid, f.key) then text = "UnignoreTask" end
            table.insert(menu, { text = L[text], arg1 = f, arg2 = (text == "IgnoreTask"), func = addon.MenuIgnoreTask })

            text = "IgnoreAllTasks"
            if toon.info.ignored then text = "UnignoreAllTasks" end
            table.insert(menu, { text = L[text], arg1 = f, arg2 = (text == "IgnoreAllTasks"), func = addon.MenuIgnoreAllTasks })

            EasyMenu(menu, TM_FRAME.menu, "cursor", 0 , 0, "MENU")
        end
    end)

    return f
end

function addon:CreateAddTaskFrame(f)
    f.taskDialog = CreateFrame("Frame", nil, f.scrollChild)
    f.taskDialog:SetPoint("TOPLEFT", 0, 0)
    f.taskDialog:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Type drop-down
    f.labelType = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.labelType:SetPoint("TOPLEFT", 0, -20)
    f.labelType:SetText(L["DialogType"])

    f.dropdownType = CreateFrame("Frame", "TM_FRAME_DROPDOWN_TYPE", f.taskDialog, "UIDropDownMenuTemplate")
    f.dropdownType:SetPoint("LEFT", f.labelType, "LEFT", 80, 0)
    UIDropDownMenu_SetWidth(f.dropdownType, 86)
    UIDropDownMenu_SetText(f.dropdownType, L["quest"])
    UIDropDownMenu_Initialize(f.dropdownType, function(frame, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        info.func = function(self, arg1)
            local isquest = (arg1 == "quest")
            f.labelQuest:SetShown(isquest)
            f.editQuest:SetShown(isquest)
            f.editQuest:SetText("")

            local isboss = (arg1 == "boss")
            f.labelBoss:SetShown(isboss)
            f.editBoss:SetShown(isboss)
            f.editBoss:SetText(L["DialogNoBoss"])
            f.editBoss.instanceid = nil
            f.editBoss.difficulty = nil
            f.editBoss.boss = nil

            f.editTitle:SetText("")
            f.saveButton:Disable()

            UIDropDownMenu_SetText(f.dropdownType, L[arg1])
        end

        info.arg1, info.text = "quest", L["quest"]
        UIDropDownMenu_AddButton(info)

        info.arg1, info.text = "boss", L["boss"]
        UIDropDownMenu_AddButton(info)
    end)

    -- Quest ID field
    f.labelQuest = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.labelQuest:SetPoint("TOPLEFT", f.labelType, "BOTTOMLEFT", 0, -20)
    f.labelQuest:SetText(L["DialogQuest"])

    f.editQuest = CreateFrame("EditBox", nil, f.taskDialog, "InputBoxTemplate")
    f.editQuest:SetSize(100, 22)
    f.editQuest:SetNumeric(true)
    f.editQuest:SetAutoFocus(false)
    f.editQuest:SetPoint("LEFT", f.labelQuest, "LEFT", 100, 0)

    f.editQuest:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end

        local id = self:GetNumber()
        local title = C_QuestLog.GetTitleForQuestID(id)

        f.saveButton:SetEnabled(id > 0)

        if id < 1 then
            f.editTitle:SetText("")
        elseif title then
            f.editTitle:SetText(title)
        else
            f.editTitle:SetText(format(L["MissingQuest"], id))
            QuestEventListener:AddCallback(id, function()
                local title = C_QuestLog.GetTitleForQuestID(id)
                f.editTitle:SetText(title)
            end)
        end
    end)

    -- Boss IDs
    f.labelBoss = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.labelBoss:SetPoint("TOPLEFT", f.labelType, "BOTTOMLEFT", 0, -20)
    f.labelBoss:SetText(L["DialogBoss"])

    f.editBoss = CreateFrame("Button", nil, f.taskDialog, "UIPanelButtonTemplate")
    f.editBoss:SetSize(100, 22)
    f.editBoss:SetText(L["DialogNoBoss"])
    f.editBoss:SetPoint("LEFT", f.labelBoss, "LEFT", 100, 0)
    f.editBoss:SetScript("OnClick", function(self, button)
        local num = GetNumSavedInstances()
        if num > 0 then
            local menu = {
                { text = L["MenuLocks"], isTitle = true }
            }

            for i = 1, num do
                local instance, _, _, difficulty, locked, _, _, _, _, difficultyname, bosses, _, _, instanceid = GetSavedInstanceInfo(i)
                local submenu = {}

                for j = 1, bosses do
                    local boss, _, _, _ = GetSavedInstanceEncounterInfo(i, j)
                    local title = instance .. " (" .. difficultyname .. "): " .. boss
                    table.insert(submenu, { text = boss, arg1 = { instanceid = instanceid, difficulty = difficulty, boss = j, title = title }, func = addon.MenuSelectBoss })
                end

                table.insert(menu, { text = instance .. " (" .. difficultyname .. ")", hasArrow = true, keepShownOnClick = true, menuList = submenu })
            end

            EasyMenu(menu, TM_FRAME.menu, "cursor", 0 , 0, "MENU")
        end
    end)

    -- Title field
    f.labelTitle = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.labelTitle:SetPoint("TOPLEFT", f.labelQuest, "BOTTOMLEFT", 0, -20)
    f.labelTitle:SetText(L["DialogTitle"])

    f.editTitle = CreateFrame("EditBox", nil, f.taskDialog, "InputBoxTemplate")
    f.editTitle:SetSize(100, 22)
    f.editTitle:SetAutoFocus(false)
    f.editTitle:SetPoint("LEFT", f.labelTitle, "LEFT", 100, 0)
    f.editTitle:SetPoint("RIGHT", 0, 0)

    -- Category field
    f.labelCategory = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.labelCategory:SetPoint("TOPLEFT", f.labelTitle, "BOTTOMLEFT", 0, -20)
    f.labelCategory:SetText(L["DialogCategory"])

    f.editCategory = CreateFrame("EditBox", nil, f.taskDialog, "InputBoxTemplate")
    f.editCategory:SetSize(100, 22)
    f.editCategory:SetAutoFocus(false)
    f.editCategory:SetPoint("LEFT", f.labelCategory, "LEFT", 100, 0)
    f.editCategory:SetPoint("RIGHT", 0, 0)

    -- Reset drop-down
    f.labelReset = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.labelReset:SetPoint("TOPLEFT", f.labelCategory, "BOTTOMLEFT", 0, -20)
    f.labelReset:SetText(L["DialogReset"])

    f.dropdownReset = CreateFrame("Frame", "TM_FRAME_DROPDOWN_RESET", f.taskDialog, "UIDropDownMenuTemplate")
    f.dropdownReset:SetPoint("LEFT", f.labelReset, "LEFT", 80, 0)
    UIDropDownMenu_SetWidth(f.dropdownReset, 86)
    UIDropDownMenu_SetText(f.dropdownReset, L["daily"])
    f.dropdownResetValue = "daily"
    UIDropDownMenu_Initialize(f.dropdownReset, function(frame, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        info.func = function(self, arg1)
            f.dropdownResetValue = arg1
            UIDropDownMenu_SetText(f.dropdownReset, L[arg1])
        end

        info.arg1, info.text = "daily", L["daily"]
        UIDropDownMenu_AddButton(info)

        info.arg1, info.text = "weekly", L["weekly"]
        UIDropDownMenu_AddButton(info)

        info.arg1, info.text = "never", L["never"]
        UIDropDownMenu_AddButton(info)
    end)

    -- Save/Cancel Buttons
    f.cancelButton = CreateFrame("Button", nil, f.taskDialog, "UIPanelButtonTemplate")
    f.cancelButton:SetSize(80, 22)
    f.cancelButton:SetText(L["CancelButton"])
    f.cancelButton:SetPoint("RIGHT", f.taskDialog, "CENTER", -4, 0)
    f.cancelButton:SetPoint("TOP", f.labelReset, "BOTTOM", 0, -20)
    f.cancelButton:SetScript("OnClick", function() addon:ShowWindow() end)

    f.saveButton = CreateFrame("Button", nil, f.taskDialog, "UIPanelButtonTemplate")
    f.saveButton:SetSize(80, 22)
    f.saveButton:SetText(L["SaveButton"])
    f.saveButton:SetPoint("LEFT", f.taskDialog, "CENTER", 4, 0)
    f.saveButton:SetPoint("TOP", f.labelReset, "BOTTOM", 0, -20)
    f.saveButton:SetScript("OnClick", function()
        local title = f.editTitle:GetText()
        local category = f.editCategory:GetText()

        if f.editQuest:IsShown() then
            local quest = f.editQuest:GetNumber()
            addon:AddQuest(quest, title, category, f.dropdownResetValue)
        elseif f.editBoss:IsShown() then
            addon:AddBoss(f.editBoss.instanceid, f.editBoss.difficulty, f.editBoss.boss, title, category, f.dropdownResetValue)
        end

        addon:ShowWindow()
    end)
end

-- Context Menu functions
function addon:MenuEditTask(f)
    addon:ShowWindow("add")

    UIDropDownMenu_DisableDropDown(TM_FRAME.dropdownType)

    local task = TM_TASKS[f.key]
    if task.instanceid then
        UIDropDownMenu_SetText(TM_FRAME.dropdownType, L["boss"])

        -- hide quest
        TM_FRAME.labelQuest:Hide()
        TM_FRAME.editQuest:Hide()

        -- setup boss ids
        TM_FRAME.labelBoss:Show()

        TM_FRAME.editBoss:Show()
        TM_FRAME.editBoss:Disable()
        TM_FRAME.editBoss:SetText(L["DialogYesBoss"])
        TM_FRAME.editBoss.instanceid = task.instanceid
        TM_FRAME.editBoss.difficulty = task.difficulty
        TM_FRAME.editBoss.boss = task.boss
    else
        -- setup quest id
        TM_FRAME.editQuest:Disable()
        TM_FRAME.editQuest:SetText(task.questid or "")
    end

    TM_FRAME.editTitle:SetText(task.title or "")
    TM_FRAME.editCategory:SetText(task.category or "")
    TM_FRAME.saveButton:Enable()

    TM_FRAME.dropdownResetValue = (task.reset or "never")
    UIDropDownMenu_SetText(TM_FRAME.dropdownReset, L[task.reset])
end

function addon:MenuRemoveTask(f)
    addon:RemoveTask(f.key)
    addon:RefreshWindow()
end

function addon:MenuIgnoreTask(f, ignore)
    addon:IgnoreTask(f.guid, f.key, ignore)
    addon:RefreshWindow()
end

function addon:MenuIgnoreAllTasks(f, ignore)
    addon:IgnoreAllTasks(f.guid, ignore)
    addon:RefreshWindow()
end

function addon:MenuSelectBoss(info)
    TM_FRAME.editBoss.instanceid = info.instanceid
    TM_FRAME.editBoss.difficulty = info.difficulty
    TM_FRAME.editBoss.boss = info.boss

    TM_FRAME.editBoss:SetText(L["DialogYesBoss"])
    TM_FRAME.editTitle:SetText(info.title or "")
    TM_FRAME.saveButton:Enable()

    -- force the menu to close
    EasyMenu({}, TM_FRAME.menu, "cursor", 0 , 0, "MENU")
end