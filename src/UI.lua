local addonName, addonTable = ...
local addon = addonTable.addon
local L = LibStub("AceLocale-3.0"):GetLocale("TaskManager")

local MAXINT = 10 ^ 300
local COLLAPSED = {}
local COLORS = {
    START = "\124cFF",
    END = "\124r",

    WARN = "fff468",

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

function addon:TimeFriendly(secs)
    local mins = floor(secs / 60)
    if mins < 60 then return COLORS.START .. COLORS.WARN .. format(L["TimeLeftMinutes"], mins) .. COLORS.END end

    local hours = floor(mins / 60)
    if hours < 24 then return format(L["TimeLeftHours"], hours) end

    local days = floor(hours / 24)
    return format(L["TimeLeftDays"], days)
end

function addon:RefreshWindow()
    if TM_FRAME and TM_FRAME:IsShown() then
        addon:ShowWindow(TM_WINDOW.key, true)
    end
end

function addon:ShowWindow(key, refresh)
    TM_WINDOW.key = key

    if not TM_FRAME then
        addon:NormalizeTaskPriority() -- cleanup
        TM_FRAME = addon:CreateMainFrame()
    end

    if not refresh then
        -- TODO remember scroll position when clicking Back button
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
        TM_FRAME.taskDialog:Show()

        if not refresh then
            -- reset the Add Task tab
            addon:CreateAddTaskFrame()
        end
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
    f.header:SetWordWrap(false)
    f.header:SetPoint("LEFT", f, "TOPLEFT", 60, -38)
    f.header:SetPoint("RIGHT", f, "TOPRIGHT", -88, -38)

    -- Rows
    f.rows = {}

    -- Add Task Dialog
    addon:CreateAddTaskFrame()

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

            if not w[name] then
                w[name] = func(addon, row)
                w[name].name = name
            end

            local f = w[name]
            row:SetHeight(f:GetHeight())
            f:Show()
            return f
        end

        function row:GetCurrentWidget()
            for _, f in pairs(row.widgets) do
                if f:IsShown() then return f end
            end
            return nil
        end
    end

    row:Show()
    return row
end

function addon:CreateTaskFrames()
    addon:NormalizeTaskPriority() -- make sure

    local sorted = {}
    local categories = {}
    local count = 0

    -- add tasks to a list
    for key, task in pairs(TM_TASKS) do
        local category = task.category

        -- count # categories
        if not categories[category] then count = count + 1 end
        if COLLAPSED[category] then count = 69 end -- force show

        -- assign category priority
        categories[category] = min(categories[category] or MAXINT, task.priority - .1)

        -- show task only if visible
        if not COLLAPSED[category] then
            local status = TM_STATUS[addon.guid][key]
            table.insert(sorted, { category = category, sort = task.priority, key = key, completed = status and status.completed, ignored = addon:IsIgnored(addon.guid, key), expires = addon:TimeLeft(addon.guid, key) })
        end
    end

    -- only show categories if needed
    if count > 1 then
        for category, priority in pairs(categories) do
            table.insert(sorted, { category = category, sort = priority })
        end
    end

    -- sort our list
    table.sort(sorted, function(a, b) return a.sort < b.sort end)

    -- create rows in UI
    for idx, entry in ipairs(sorted) do
        local row = addon:CreateRowFrame(idx)

        if entry.key then
            local f = row:ShowWidget("task", addon.CreateTaskFrame)
            f.key = entry.key
            f.checkbox:SetChecked(entry.completed)
            f.checkbox:SetEnabled(addon:IsStandardTask(entry.key))
            f:SetSummary(entry.key)
            f:SetTitle(TM_TASKS[entry.key], entry.ignored, entry.expires)
        else
            local f = row:ShowWidget("category", addon.CreateCategoryFrame)
            f.Name:SetText(entry.category)
            f:SetCollapsed(COLLAPSED[entry.category])
        end
    end
end

function addon:CreateCategoryFrame(parent)
    local f = CreateFrame("Button", nil, parent, "TokenHeaderTemplate")
    f:SetPoint("TOPLEFT", 0, 0)
    f:SetPoint("TOPRIGHT", 0, 0)

    f.elementData = {
        isHeaderExpanded = true
    }

    function f:SetCollapsed(collapsed)
        f.elementData.isHeaderExpanded = not collapsed
        f:RefreshCollapseIcon()
    end

    f:SetScript("OnClick", function()
        local category = f.Name:GetText()
        COLLAPSED[category] = not COLLAPSED[category]
        addon:RefreshWindow()
    end)

    addon:AddGrip(f)
    return f
end

function addon:CreateTaskFrame(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 0, 0)
    f:SetPoint("TOPRIGHT", 0, 0)

    f.checkbox = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.checkbox:SetPoint("TOPLEFT")
    f.checkbox:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    f.checkbox:SetSize(20, 20)
    f:SetHeight(20)

    f.checkbox:SetScript("OnClick", function(self)
        addon:UpdateStandardTask(f.key, f.checkbox:GetChecked())
        addon:RefreshWindow()
    end)

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
    f.title:SetWordWrap(false)
    f.title:SetPoint("LEFT", f.checkbox, "RIGHT", 50, 0)
    f.title:SetPoint("RIGHT", -16, 0)
    function f:SetTitle(task, ignored, expires)
        local str = addon:Trim(task.title) or L["MissingTitle"]
        if expires and expires > 0 then
            str = str .. " (" .. addon:TimeFriendly(expires) .. ")"
        elseif task.reset and task.reset ~= "never" then
            str = str .. " (" .. L[task.reset] .. ")"
        end
        if ignored then
            str = COLORS.START .. COLORS.IGNORED .. "-" .. str .. "-" .. COLORS.END
        end
        f.title:SetText(str)
    end

    f.title:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            UIDropDownMenu_Initialize(TM_FRAME.menu, function(frame, level, menuList)
                UIDropDownMenu_AddButton({ text = L["EditTask"], arg1 = f, func = addon.MenuEditTask })
                UIDropDownMenu_AddButton({ text = L["RemoveTask"], arg1 = f, func = addon.MenuRemoveTask })
            end, "MENU")
            ToggleDropDownMenu(1, nil, TM_FRAME.menu, f, 0, 0)
        else
            addon:ShowWindow(f.key)
        end
    end)

    addon:AddGrip(f)
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

        f.guid = entry.guid
        f.key = key
        f.checkbox:SetChecked(entry.completed)
        f.checkbox:SetEnabled(addon:IsStandardTask(key))
        f.text:SetText(entry.text)
    end
end

function addon:CreateStatusFrame(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 0, 0)
    f:SetPoint("TOPRIGHT", 0, 0)

    f.checkbox = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.checkbox:SetPoint("TOPLEFT")
    f.checkbox:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    f.checkbox:SetSize(20, 20)
    f:SetHeight(20)

    f.checkbox:SetScript("OnClick", function(self)
        addon:UpdateStandardTask(f.key, f.checkbox:GetChecked(), f.guid)
        addon:RefreshWindow()
    end)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    f.text:SetPoint("LEFT", f.checkbox, "RIGHT")

    f.text:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            local toon = TM_STATUS[f.guid] or { info={} }

            UIDropDownMenu_Initialize(TM_FRAME.menu, function(frame, level, menuList)
                local text = "IgnoreTask"
                if addon:IsIgnored(f.guid, f.key) then text = "UnignoreTask" end
                UIDropDownMenu_AddButton({ text = L[text], arg1 = f, arg2 = (text == "IgnoreTask"), func = addon.MenuIgnoreTask })

                text = "IgnoreAllTasks"
                if toon.info.ignored then text = "UnignoreAllTasks" end
                UIDropDownMenu_AddButton({ text = L[text], arg1 = f, arg2 = (text == "IgnoreAllTasks"), func = addon.MenuIgnoreAllTasks })

                if f.guid ~= addon.guid then
                    UIDropDownMenu_AddButton({ text = L["DeleteCharacter"], arg1 = f, func = addon.MenuDeleteCharacter })
                end
            end, "MENU")
            ToggleDropDownMenu(1, nil, TM_FRAME.menu, f, 0, 0)
        elseif IsShiftKeyDown() then
            addon:MenuIgnoreTask(f, not addon:IsIgnored(f.guid, f.key))
        end
    end)

    return f
end

function addon:AddGrip(frame)
    frame:SetMovable(true)

    local grip = CreateFrame("Button", nil, frame)
    grip:SetPoint("RIGHT", 0, 0)
    grip:SetSize(16, 16)
    grip:SetNormalTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    grip:GetNormalTexture():SetAlpha(.25)
    grip:SetHighlightTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    grip:SetPushedTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    grip:SetScript("OnMouseDown", function() addon:DragRow(frame) end)
    grip:SetScript("OnMouseUp", function() addon:DropRow(frame) end)
end

function addon:DragRow(frame)
    frame:SetFrameStrata("HIGH")
    frame:StartMoving()

    -- TODO should have scrollbar follow the drag
end

function addon:DropRow(frame)
    frame:StopMovingOrSizing()
    local dropped = (frame:GetTop() + frame:GetBottom()) / 2

    -- reset position
    frame:SetUserPlaced(false)
    frame:SetFrameStrata("MEDIUM")
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", 0, 0)

    -- find out where we were dropped
    local dest = { diff = MAXINT, frame = nil, above = true }
    for _, f in pairs(TM_FRAME.rows) do
        if f:IsShown() then
            local mid = (f:GetTop() + f:GetBottom()) / 2
            local diff = abs(dropped - mid)

            if diff < dest.diff then
                dest.diff = diff
                dest.above = (dropped > mid)
                dest.frame = f
            end
        end
    end

    -- handle move depending on to/from types
    local widget = dest.frame:GetCurrentWidget()
    if frame.name == "task" then
        -- moving a task
        local task = TM_TASKS[frame.key]

        if widget.name == "task" then
            -- dropped near another task
            local t = TM_TASKS[widget.key]
            task.category = t.category
            task.priority = t.priority + (dest.above and -.1 or .1)
        elseif widget.name == "category" then
            -- dropped near a category
            local category = widget.Name:GetText()
            task.category = category
            task.priority = COLLAPSED[category] and MAXINT or -1
        end
    elseif frame.name == "category" then
        -- moving an entire category
        local category = frame.Name:GetText()

        if widget.name == "task" then
            -- dropped near a task
            local t = TM_TASKS[widget.key]

            -- assign all tasks in category to be decimals above/below the given task
            for _, task in pairs(TM_TASKS) do
                if task.category == category then
                    task.priority = t.priority + (.0001 * task.priority) + (dest.above and -1 or 0)
                end
            end
        elseif widget.name == "category" then
            -- dropped near another category
            local c = widget.Name:GetText()

            -- find min priority of other category
            local priority = MAXINT
            for _, task in pairs(TM_TASKS) do
                if task.category == c then priority = min(priority, task.priority) end
            end

            -- assign all tasks in category to be decimals above/below the priority
            for _, task in pairs(TM_TASKS) do
                if task.category == category then
                    task.priority = priority + (.0001 * task.priority) + (dest.above and -1 or 0)
                end
            end
        end
    end
    -- TODO ability to sort characters
    -- TODO ability to rename entire category

    addon:NormalizeTaskPriority()
    addon:RefreshWindow()
end

function addon:CreateAddTaskFrame()
    local f = TM_FRAME

    -- main frame
    if not f.taskDialog then
        f.taskDialog = CreateFrame("Frame", nil, f.scrollChild)
        f.taskDialog:SetPoint("TOPLEFT", 0, 0)
        f.taskDialog:SetPoint("BOTTOMRIGHT", 0, 0)
    end

    -- Type drop-down
    if not f.labelType then
        f.labelType = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        f.labelType:SetPoint("TOPLEFT", 0, -20)
        f.labelType:SetText(L["DialogType"])
    end

    if not f.dropdownType then
        f.dropdownType = CreateFrame("Frame", "TM_FRAME_DROPDOWN_TYPE", f.taskDialog, "UIDropDownMenuTemplate")
        f.dropdownType:SetPoint("LEFT", f.labelType, "LEFT", 80, 0)
        UIDropDownMenu_SetWidth(f.dropdownType, 86)
        UIDropDownMenu_Initialize(f.dropdownType, function(frame, level, menuList)
            local func = function(self, arg1)
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

                -- adjust positioning
                if isquest then
                    f.labelTitle:SetPoint("TOPLEFT", f.labelQuest, "BOTTOMLEFT", 0, -20)
                elseif isboss then
                    f.labelTitle:SetPoint("TOPLEFT", f.labelBoss, "BOTTOMLEFT", 0, -20)
                else
                    f.labelTitle:SetPoint("TOPLEFT", f.labelType, "BOTTOMLEFT", 0, -20)
                end

                UIDropDownMenu_SetText(f.dropdownType, L[arg1])
                f.dropdownType.value = arg1
            end

            UIDropDownMenu_AddButton({ text = L["standard"], arg1 = "standard", func = func })
            UIDropDownMenu_AddButton({ text = L["quest"], arg1 = "quest", func = func })
            UIDropDownMenu_AddButton({ text = L["boss"], arg1 = "boss", func = func })
        end)
    end

    UIDropDownMenu_EnableDropDown(f.dropdownType)
    UIDropDownMenu_SetText(f.dropdownType, L["standard"])
    f.dropdownType.value = "standard"

    -- Quest ID field
    if not f.labelQuest then
        f.labelQuest = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        f.labelQuest:SetPoint("TOPLEFT", f.labelType, "BOTTOMLEFT", 0, -20)
        f.labelQuest:SetText(L["DialogQuest"])
    end

    f.labelQuest:Hide()

    if not f.editQuest then
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
    end

    f.editQuest:Hide()
    f.editQuest:Enable()
    f.editQuest:SetText("")

    -- Boss IDs
    if not f.labelBoss then
        f.labelBoss = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        f.labelBoss:SetPoint("TOPLEFT", f.labelType, "BOTTOMLEFT", 0, -20)
        f.labelBoss:SetText(L["DialogBoss"])
    end

    f.labelBoss:Hide()

    if not f.editBoss then
        f.editBoss = CreateFrame("Button", nil, f.taskDialog, "UIPanelButtonTemplate")
        f.editBoss:SetSize(100, 22)
        f.editBoss:SetPoint("LEFT", f.labelBoss, "LEFT", 100, 0)
        f.editBoss:SetScript("OnClick", function(self, button)
            local num = GetNumSavedInstances()
            if num > 0 then
                UIDropDownMenu_Initialize(TM_FRAME.menu, function(frame, level, menuList)
                    if level == 2 then
                        for idx, entry in ipairs(menuList) do
                            UIDropDownMenu_AddButton(entry, level)
                        end
                    else
                        UIDropDownMenu_AddButton({ text = L["MenuLocks"], isTitle = true })

                        for i = 1, num do
                            local instance, _, _, difficulty, locked, _, _, _, _, difficultyname, bosses, _, _, instanceid = GetSavedInstanceInfo(i)
                            local submenu = {}

                            for j = 1, bosses do
                                local boss, _, _, _ = GetSavedInstanceEncounterInfo(i, j)
                                local title = instance .. " (" .. difficultyname .. "): " .. boss
                                table.insert(submenu, { text = boss, arg1 = { instanceid = instanceid, difficulty = difficulty, boss = j, title = title }, func = addon.MenuSelectBoss })
                            end

                            UIDropDownMenu_AddButton({ text = instance .. " (" .. difficultyname .. ")", hasArrow = true, keepShownOnClick = true, menuList = submenu })
                        end
                    end
                end, "MENU")
                ToggleDropDownMenu(1, nil, TM_FRAME.menu, f.editBoss, 0, 0)
            end
        end)
    end

    f.editBoss:Hide()
    f.editBoss:Enable()
    f.editBoss:SetText(L["DialogNoBoss"])
    f.editBoss.instanceid = nil
    f.editBoss.difficulty = nil
    f.editBoss.boss = nil

    -- Title field
    if not f.labelTitle then
        f.labelTitle = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        f.labelTitle:SetText(L["DialogTitle"])
    end

    f.labelTitle:SetPoint("TOPLEFT", f.labelType, "BOTTOMLEFT", 0, -20)

    if not f.editTitle then
        f.editTitle = CreateFrame("EditBox", nil, f.taskDialog, "InputBoxTemplate")
        f.editTitle:SetSize(100, 22)
        f.editTitle:SetAutoFocus(false)
        f.editTitle:SetPoint("LEFT", f.labelTitle, "LEFT", 100, 0)
        f.editTitle:SetPoint("RIGHT", 0, 0)

        f.editTitle:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end

            if f.dropdownType.value == "standard" then
                f.saveButton:SetEnabled(string.len(self:GetText()) > 0)
            end
        end)
    end

    f.editTitle:SetText("")

    -- Category field
    if not f.labelCategory then
        f.labelCategory = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        f.labelCategory:SetPoint("TOPLEFT", f.labelTitle, "BOTTOMLEFT", 0, -20)
        f.labelCategory:SetText(L["DialogCategory"])
    end

    if not f.editCategory then
        f.editCategory = CreateFrame("EditBox", nil, f.taskDialog, "InputBoxTemplate")
        f.editCategory:SetSize(100, 22)
        f.editCategory:SetAutoFocus(false)
        f.editCategory:SetPoint("LEFT", f.labelCategory, "LEFT", 100, 0)
        f.editCategory:SetPoint("RIGHT", 0, 0)
    end

    f.editCategory:SetText("")

    -- Reset drop-down
    if not f.labelReset then
        f.labelReset = f.taskDialog:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        f.labelReset:SetPoint("TOPLEFT", f.labelCategory, "BOTTOMLEFT", 0, -20)
        f.labelReset:SetText(L["DialogReset"])
    end

    if not f.dropdownReset then
        f.dropdownReset = CreateFrame("Frame", "TM_FRAME_DROPDOWN_RESET", f.taskDialog, "UIDropDownMenuTemplate")
        f.dropdownReset:SetPoint("LEFT", f.labelReset, "LEFT", 80, 0)
        UIDropDownMenu_SetWidth(f.dropdownReset, 86)
        UIDropDownMenu_Initialize(f.dropdownReset, function(frame, level, menuList)
            local func = function(self, arg1)
                f.dropdownReset.value = arg1
                UIDropDownMenu_SetText(f.dropdownReset, L[arg1])
            end

            UIDropDownMenu_AddButton({ text = L["daily"], arg1 = "daily", func = func })
            UIDropDownMenu_AddButton({ text = L["weekly"], arg1 = "weekly", func = func })
            UIDropDownMenu_AddButton({ text = L["never"], arg1 = "never", func = func })
        end)
    end

    UIDropDownMenu_SetText(f.dropdownReset, L["daily"])
    f.dropdownReset.value = "daily"
    f.priority = MAXINT

    -- Save/Cancel Buttons
    if not f.cancelButton then
        f.cancelButton = CreateFrame("Button", nil, f.taskDialog, "UIPanelButtonTemplate")
        f.cancelButton:SetSize(80, 22)
        f.cancelButton:SetText(L["CancelButton"])
        f.cancelButton:SetPoint("RIGHT", f.taskDialog, "CENTER", -4, 0)
        f.cancelButton:SetPoint("TOP", f.labelReset, "BOTTOM", 0, -20)
        f.cancelButton:SetScript("OnClick", function() addon:ShowWindow() end)
    end

    if not f.saveButton then
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
                addon:AddQuestTask(quest, title, category, f.dropdownReset.value, f.priority)
            elseif f.editBoss:IsShown() then
                addon:AddBossTask(f.editBoss.instanceid, f.editBoss.difficulty, f.editBoss.boss, title, category, f.dropdownReset.value, f.priority)
            else
                addon:AddStandardTask(f.saveButton.key, title, category, f.dropdownReset.value, f.priority)
            end

            addon:ShowWindow()
        end)
    end

    f.saveButton:Disable()
    f.saveButton.key = nil
end

-- Context Menu functions
function addon:MenuEditTask(f)
    -- show the Add Task tab
    addon:ShowWindow("add")

    -- then fill in the options of the chosen task
    local task = TM_TASKS[f.key]
    if task.instanceid then
        TM_FRAME.dropdownType.value = "boss"
        UIDropDownMenu_SetText(TM_FRAME.dropdownType, L["boss"])

        -- setup boss ids
        TM_FRAME.labelBoss:Show()

        TM_FRAME.editBoss:Show()
        TM_FRAME.editBoss:Disable()
        TM_FRAME.editBoss:SetText(L["DialogYesBoss"])
        TM_FRAME.editBoss.instanceid = task.instanceid
        TM_FRAME.editBoss.difficulty = task.difficulty
        TM_FRAME.editBoss.boss = task.boss

        -- positioning
        TM_FRAME.labelTitle:SetPoint("TOPLEFT", TM_FRAME.labelBoss, "BOTTOMLEFT", 0, -20)
    elseif task.questid then
        TM_FRAME.dropdownType.value = "quest"
        UIDropDownMenu_SetText(TM_FRAME.dropdownType, L["quest"])

        -- setup quest id
        TM_FRAME.labelQuest:Show()

        TM_FRAME.editQuest:Show()
        TM_FRAME.editQuest:Disable()
        TM_FRAME.editQuest:SetText(task.questid or "")

        -- positioning
        TM_FRAME.labelTitle:SetPoint("TOPLEFT", TM_FRAME.labelQuest, "BOTTOMLEFT", 0, -20)
    end

    UIDropDownMenu_DisableDropDown(TM_FRAME.dropdownType)
    TM_FRAME.editTitle:SetText(task.title or "")
    TM_FRAME.editCategory:SetText(task.category or "")
    TM_FRAME.priority = (task.priority or MAXINT)
    TM_FRAME.dropdownReset.value = (task.reset or "never")
    UIDropDownMenu_SetText(TM_FRAME.dropdownReset, L[task.reset or "never"])
    TM_FRAME.saveButton:Enable()
    TM_FRAME.saveButton.key = f.key
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

function addon:MenuDeleteCharacter(f)
    local toon = TM_STATUS[f.guid]
    StaticPopupDialogs["TM_DELETE_CHARACTER"] = {
        text = format(L["DeleteCharacterConfirmation"], toon.info.name .. "-" .. toon.info.realm),
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            addon:DeleteCharacter(f.guid)
            addon:RefreshWindow()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }
    StaticPopup_Show("TM_DELETE_CHARACTER")
end

function addon:MenuSelectBoss(info)
    TM_FRAME.editBoss.instanceid = info.instanceid
    TM_FRAME.editBoss.difficulty = info.difficulty
    TM_FRAME.editBoss.boss = info.boss

    TM_FRAME.editBoss:SetText(L["DialogYesBoss"])
    TM_FRAME.editTitle:SetText(info.title or "")
    TM_FRAME.saveButton:Enable()

    -- force the menu to close
    ToggleDropDownMenu(1, nil, TM_FRAME.menu, nil, 0, 0)
end