-- Local copy of rpemotes animation lists for ped-director
-- Provides RP tables and merges CustomDP lists.

RP = RP or {}
_G.RP = RP -- Ensure global access for menu.lua

-- Mock Translate function for rpemotes compatibility
function Translate(key)
    return key
end

local function loadLua(path)
    local resource = GetCurrentResourceName()
    local content = LoadResourceFile(resource, path)
    if not content then
        print(('^1[ped-director]^7 Failed to load %s'):format(path))
        return false
    end

    local chunk, err = load(content, ('@@%s/%s'):format(resource, path))
    if not chunk then
        print(('^1[ped-director]^7 Failed to compile %s: %s'):format(path, err))
        return false
    end

    chunk()
    return true
end

if not loadLua('client/rpemotes/AnimationList.lua') then return end
if not loadLua('client/rpemotes/AnimationListCustom.lua') then return end

if LoadAddonEmotes then
    LoadAddonEmotes()
end

RegisterNetEvent('ped-director:reloadEmotes', function()
    if LoadAddonEmotes then
        LoadAddonEmotes()
    end
end)
