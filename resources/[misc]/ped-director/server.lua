--[[
    Ped Director v2.0 - Server
    Preset persistence via JSON file.
]]

local PRESETS_FILE = 'presets.json'

local function LoadPresets()
    local raw = LoadResourceFile(GetCurrentResourceName(), PRESETS_FILE)
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then return data end
    end
    return {}
end

local function SavePresets(presets)
    local ok, encoded = pcall(json.encode, presets, { indent = true })
    if ok then
        SaveResourceFile(GetCurrentResourceName(), PRESETS_FILE, encoded, -1)
    end
end

RegisterNetEvent('ped-director:requestPresets', function()
    local src = source
    if not src or src <= 0 then return end
    TriggerClientEvent('ped-director:receivePresets', src, LoadPresets())
end)

RegisterNetEvent('ped-director:savePreset', function(name, data)
    if type(name) ~= 'string' or name == '' then return end
    if type(data) ~= 'table' then return end
    local presets = LoadPresets()
    presets[name] = data
    SavePresets(presets)
end)
