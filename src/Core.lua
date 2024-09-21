local addonName, addonTable = ...
local addon = addonTable.addon
local L = LibStub("AceLocale-3.0"):GetLocale("TaskManager")

local MAXINT = 10 ^ 300

function addon:Expires(reset)
    if reset == "weekly" then
        return time() + C_DateAndTime.GetSecondsUntilWeeklyReset()
    end

    if reset == "daily" then
        local secs = GetQuestResetTime()
        if not secs or secs < 1 then return 0 end -- error handling

        return time() + secs
    end

    -- default to never
    return MAXINT
end

function addon:AddStandardTask(key, title, category, reset, priority)
    if reset ~= "weekly" and reset ~= "daily" then
        -- default to never
        reset = "never"
    end

    key = key or ("s" .. tostring(time()))
    TM_TASKS[key] = {
        title = title,
        category = category,
        reset = reset,
        priority = priority
    }

    addon:NormalizeTaskPriority()
end

function addon:UpdateStandardTask(key, completed, guid)
    if not addon:IsStandardTask(key) then return false end -- sanity check
    if not TM_TASKS[key] then return false end -- not tracked

    if not guid then guid = addon.guid end -- default to current character

    if not TM_STATUS[guid][key] then TM_STATUS[guid][key] = {} end
    local entry = TM_STATUS[guid][key]

    if completed then
        entry.expires = addon:Expires(TM_TASKS[key].reset)
        entry.completed = true
    else
        entry.expires = nil
        entry.completed = nil
    end

    return true
end

function addon:IsStandardTask(key)
    return string.sub(key, 1, 1) == "s"
end

function addon:AddQuestTask(id, title, category, reset, priority)
    if not id then return end

    if reset ~= "weekly" and reset ~= "daily" then
        -- default to never
        reset = "never"
    end

    local key = "q" .. tostring(id)
    TM_TASKS[key] = {
        questid = id,
        title = title,
        category = category,
        reset = reset,
        priority = priority
    }

    addon:NormalizeTaskPriority()
end

function addon:UpdateQuest(id)
    local key = "q" .. tostring(id)
    if not TM_TASKS[key] then return false end -- not tracked

    if not TM_STATUS[addon.guid][key] then TM_STATUS[addon.guid][key] = {} end
    local entry = TM_STATUS[addon.guid][key]
    local be, bc, bp = entry.expires, entry.completed, entry.progress

    -- update quest status
    local reset = C_TaskQuest.GetQuestTimeLeftSeconds(id)
    if reset and reset > 0 then
        entry.expires = reset + time()
    else
        entry.expires = addon:Expires(TM_TASKS[key].reset)
    end

    if C_QuestLog.IsQuestFlaggedCompleted(id) then
        entry.completed = true
        entry.progress = nil
    elseif C_QuestLog.IsOnQuest(id) then
        local progress = 0
        local required = 0

        local objectives = C_QuestLog.GetQuestObjectives(id)
        if objectives and objectives[1] and not objectives[2] then
            -- only 1 objective, so track it
            progress = objectives[1].numFulfilled
            required = objectives[1].numRequired
        end

        entry.completed = false
        if required > 0 then
            entry.progress = tostring(progress) .. "/" .. tostring(required)
        else
            entry.progress = L["ProgressOnQuest"]
        end
    else
        entry.completed = false
        entry.progress = nil
    end

    -- return true if anything changed
    return bc ~= entry.completed or be ~= entry.expires or bp ~= entry.progress
end

function addon:AddProfessionTask(id, title, category, reset, priority)
    if not id then return end

    if reset ~= "weekly" and reset ~= "daily" then
        -- default to never
        reset = "never"
    end

    local key = "p" .. tostring(id)
    TM_TASKS[key] = {
        spellid = id,
        title = title,
        category = category,
        reset = reset,
        priority = priority
    }

    addon:NormalizeTaskPriority()
end

function addon:UpdateProfession(id)
    local key = "p" .. tostring(id)
    if not TM_TASKS[key] then return false end -- not tracked

    if not TM_STATUS[addon.guid][key] then TM_STATUS[addon.guid][key] = {} end
    local entry = TM_STATUS[addon.guid][key]
    local be, bc, bp = entry.expires, entry.completed

    -- update profession status
    local info = C_Spell.GetSpellCooldown(id)
    if info.startTime > 0 then
        entry.completed = true
        entry.expires = floor(info.startTime + info.duration - GetTime() + time())
    else
        entry.completed = false
        entry.expires = nil
    end

    -- return true if anything changed
    return bc ~= entry.completed or be ~= entry.expires
end

function addon:AddBossTask(id, difficulty, boss, title, category, reset, priority)
    if not id then return end
    if not difficulty then return end
    if not boss then return end

    local key = "i" .. tostring(id) .. "d" .. tostring(difficulty) .. "b" .. tostring(boss)
    TM_TASKS[key] = {
        instanceid = id,
        difficulty = difficulty,
        boss = boss,
        title = title,
        category = category,
        reset = reset,
        priority = priority
    }

    addon:NormalizeTaskPriority()
end

function addon:UpdateBosses()
    local num = GetNumSavedInstances()
    local changed = false

    if num > 0 then
        for i = 1, num do
            local _, _, reset, difficulty, locked, _, _, _, _, _, bosses, _, _, instanceid = GetSavedInstanceInfo(i)

            for j = 1, bosses do
                local key = "i" .. tostring(instanceid) .. "d" .. tostring(difficulty) .. "b" .. tostring(j)

                if TM_TASKS[key] then
                    local defeated = false
                    if locked then
                        _, _, defeated, _ = GetSavedInstanceEncounterInfo(i, j)
                    end

                    -- update status
                    if not TM_STATUS[addon.guid][key] then TM_STATUS[addon.guid][key] = {} end
                    local entry = TM_STATUS[addon.guid][key]
                    local be, bc = entry.expires, entry.completed

                    if defeated then
                        entry.completed = true
                        entry.expires = reset + time()
                        --entry.expires = addon:Expires(TM_TASKS[key].reset)
                    else
                        entry.completed = false
                        entry.expires = nil
                    end

                    -- expiration can vary by a little until cache updates, so don't rely on it
                    changed = changed or bc ~= entry.completed -- or be ~= entry.expires
                end
            end
        end
    end

    return changed
end

function addon:RemoveTask(key)
    TM_TASKS[key] = nil
    addon:NormalizeTaskPriority()
    addon:PurgeExpired() -- removes task from characters
end

function addon:SkipTask(guid, key, skip)
    if not TM_STATUS[guid][key] then TM_STATUS[guid][key] = {} end
    local entry = TM_STATUS[guid][key]

    if skip then
        entry.skipexpires = addon:Expires(TM_TASKS[key].reset)
        entry.skip = true
    else
        entry.skipexpires = nil
        entry.skip = nil
    end
end

function addon:SkipAllTasks(key, skip)
    for guid, toon in pairs(TM_STATUS) do
        addon:SkipTask(guid, key, skip)
    end
end

function addon:IsSkipped(guid, key)
    local toon = TM_STATUS[guid]
    if not toon then return false end

    local status = toon[key]
    return status and status.skip
end

function addon:UpdateCharacter()
    if not TM_STATUS[addon.guid] then TM_STATUS[addon.guid] = {} end
    if not TM_STATUS[addon.guid].info then TM_STATUS[addon.guid].info = {} end

    local entry = TM_STATUS[addon.guid].info
    local bl = entry.level

    local name, realm = UnitFullName("player")
    local _, class = UnitClass("player")
    local level = UnitLevel("player")

    entry.name = name
    entry.realm = realm
    entry.class = class
    entry.level = level

    -- level is the only thing that should really change
    return bl ~= entry.level
end

function addon:UpdateAll()
    local changed = false

    -- character
    changed = addon:UpdateCharacter() or changed

    for key, task in pairs(TM_TASKS) do
        -- quests
        if task.questid then
            changed = addon:UpdateQuest(task.questid) or changed
        end

        -- professions
        if task.spellid then
            changed = addon:UpdateProfession(task.spellid) or changed
        end
    end

    -- instances
    changed = addon:UpdateBosses() or changed

    return changed
end

function addon:PurgeExpired()
    local now = time()

    for guid, toon in pairs(TM_STATUS) do
        for key, task in pairs(toon) do
            if key ~= "info" and not TM_TASKS[key] then
                -- task was removed
                TM_STATUS[guid][key] = nil
            else
                if task.expires and task.expires < now then
                    task.completed = nil
                    task.progress = nil
                    task.expires = nil
                end

                if task.skipexpires and task.skipexpires < now then
                    task.skip = nil
                    task.skipexpires = nil
                end
            end
        end
    end
end

function addon:DeleteCharacter(guid)
    TM_STATUS[guid] = nil
end

function addon:IgnoreAllTasks(guid, ignore)
    local toon = TM_STATUS[guid]
    if not toon then return end

    if ignore then
        toon.info.ignored = true
    else
        toon.info.ignored = nil
    end
end

function addon:IgnoreTask(guid, key, ignore)
    local toon = TM_STATUS[guid]
    if not toon then return end
    if not toon[key] then toon[key] = {} end

    if ignore then
        if toon.info and toon.info.ignored then
            -- reset
            toon[key].ignored = nil
        else
            toon[key].ignored = true
        end
    else
        if toon.info and toon.info.ignored then
            -- specifically unignore
            toon[key].ignored = false
        else
            toon[key].ignored = nil
        end
    end
end

function addon:IsIgnored(guid, key)
    local toon = TM_STATUS[guid]
    if not toon then return false end

    -- Ignore
    local status = toon[key]
    if status and status.ignored ~= nil then return status.ignored end

    -- IgnoreAll
    return toon.info and toon.info.ignored
end

function addon:TimeLeft(guid, key)
    local toon = TM_STATUS[guid]
    if toon then
        local status = toon[key]
        if status and status.expires then
            -- check for never expiring
            if status.expires == MAXINT then return nil end
            return status.expires - time()
        end
    end

    local task = TM_TASKS[key]
    if task and task.reset then
        local expires = addon:Expires(task.reset)
        if expires > 0 and expires < MAXINT then
            return expires - time()
        end
    end

    -- couldn't determine time left
    return nil
end

function addon:NormalizeTaskPriority()
    local sorted = {}
    local categories = {}

    -- gather tasks and categories
    for key, task in pairs(TM_TASKS) do
        task.category = addon:Trim(task.category) or L["MissingCategory"]
        task.priority = task.priority or MAXINT

        categories[task.category] = min(task.priority, categories[task.category] or MAXINT)
        table.insert(sorted, task)
    end

    -- sort by category and then priority
    table.sort(sorted, function(a, b)
        if a.category == b.category then
            return a.priority < b.priority
        else
            -- position category according to its lowest task
            return categories[a.category] < categories[b.category]
        end
    end)

    -- assign the normalized priority
    for i, task in ipairs(sorted) do
        task.priority = i
    end
end