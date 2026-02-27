-- Server-side persistence for Ped Director presets
local PresetsFile = 'presets.json'

-- Helper to load presets from file
local function LoadPresets()
    local fileContent = LoadResourceFile(GetCurrentResourceName(), PresetsFile)
    if fileContent then
        return json.decode(fileContent) or {}
    else
        return {}
    end
end

-- Helper to save presets to file
local function SavePresets(presets)
    SaveResourceFile(GetCurrentResourceName(), PresetsFile, json.encode(presets, {indent = true}), -1)
end

-- Event to request presets on client join/resource start
RegisterNetEvent('ped-director:requestPresets')
AddEventHandler('ped-director:requestPresets', function()
    local src = source
    local presets = LoadPresets()
    TriggerClientEvent('ped-director:receivePresets', src, presets)
end)

-- Event to save a new preset
RegisterNetEvent('ped-director:savePreset')
AddEventHandler('ped-director:savePreset', function(name, data)
    local presets = LoadPresets()
    presets[name] = data
    SavePresets(presets)
    -- Broadcast update to all clients? Or just let them fetch next time?
    -- For now, let's just save. Clients might need to re-fetch if we wanted real-time sync.
    -- But since this is likely single-admin usage, simple save is fine.
end)
