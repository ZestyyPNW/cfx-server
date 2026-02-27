-- Local emote data loaded from ped-director/client/rpemotes

Emotes = Emotes or {}

local function mergeEmotes(target, source)
    if not source then
        return
    end

    for key, emote in pairs(source) do
        if type(emote) == 'table' and emote[1] and emote[2] then
            target[key] = emote
        end
    end
end

local function RefreshEmotes()
    if not RP then
        return false
    end

    local merged = {}
    mergeEmotes(merged, RP.Emotes)
    mergeEmotes(merged, RP.Dances)
    mergeEmotes(merged, RP.PropEmotes)
    mergeEmotes(merged, RP.AnimalEmotes)
    if next(merged) ~= nil then
        Emotes = merged
        return true
    end

    return false
end

-- Wait for rpemotes to load, then use their emote data
CreateThread(function()
    local attempts = 0
    while attempts < 20 and not RefreshEmotes() do
        Wait(500)
        attempts = attempts + 1
    end

    local loaded = RefreshEmotes()
    if not loaded then
        TriggerEvent('ped-director:reloadEmotes')
        loaded = RefreshEmotes()
    end

    if loaded then
        local count = 0
        for _ in pairs(Emotes) do
            count = count + 1
        end
        print('^2[ped-director]^7 Successfully loaded ' .. count .. ' emotes')
    else
        print('^1[ped-director]^7 WARNING: emotes not found!')
    end
end)

function GetEmote(emoteName)
    local searchName = string.lower(emoteName)
    
    -- Use rpemotes CustomDP.Emotes if available
    local emoteSource = Emotes or {}
    
    -- First check exact match
    if emoteSource[searchName] then
        local emote = emoteSource[searchName]
        return { 
            dict = emote[1], 
            anim = emote[2], 
            name = emote[3] or emoteName,
            options = emote.AnimationOptions or emote[4]
        }
    end
    
    -- Then search through all emotes
    for key, emote in pairs(emoteSource) do
        local emoteName_lower = string.lower(emote[3] or "")
        if string.find(string.lower(key), searchName) or string.find(emoteName_lower, searchName) then
            return { 
                dict = emote[1], 
                anim = emote[2], 
                name = emote[3] or key,
                options = emote.AnimationOptions or emote[4]
            }
        end
    end
    
    return nil
end

-- Helper to count available emotes
function CountEmotes()
    local count = 0
    for _ in pairs(Emotes or {}) do
        count = count + 1
    end
    return count
end
