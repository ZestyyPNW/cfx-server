--[[
    Ped Director v2.0 - Emote Loader
    Loads rpemotes animation data into the global Emotes table.
    Exposes GetEmote() and CountEmotes() for client.lua and menu.lua.
]]

Emotes = {}

local function MergeEmotes(target, source)
    if not source then return end
    for key, emote in pairs(source) do
        if type(emote) == 'table' and emote[1] and emote[2] then
            target[key] = emote
        end
    end
end

local function RefreshEmotes()
    if not RP then return false end
    local merged = {}
    MergeEmotes(merged, RP.Emotes)
    MergeEmotes(merged, RP.Dances)
    MergeEmotes(merged, RP.PropEmotes)
    MergeEmotes(merged, RP.AnimalEmotes)
    if next(merged) then
        Emotes = merged
        return true
    end
    return false
end

CreateThread(function()
    local attempts = 0
    while attempts < 20 and not RefreshEmotes() do
        Wait(500)
        attempts = attempts + 1
    end
    if not RefreshEmotes() then
        TriggerEvent('ped-director:reloadEmotes')
        RefreshEmotes()
    end
    local count = 0
    for _ in pairs(Emotes) do count = count + 1 end
    if count > 0 then
        print('^2[ped-director]^7 Loaded ' .. count .. ' emotes')
    else
        print('^1[ped-director]^7 WARNING: no emotes loaded')
    end
end)

function GetEmote(emoteName)
    local search = string.lower(emoteName)
    if Emotes[search] then
        local e = Emotes[search]
        return { dict = e[1], anim = e[2], name = e[3] or emoteName, options = e.AnimationOptions or e[4] }
    end
    for key, e in pairs(Emotes) do
        local name = string.lower(e[3] or '')
        if string.find(string.lower(key), search) or string.find(name, search) then
            return { dict = e[1], anim = e[2], name = e[3] or key, options = e.AnimationOptions or e[4] }
        end
    end
    return nil
end

function CountEmotes()
    local c = 0
    for _ in pairs(Emotes) do c = c + 1 end
    return c
end
