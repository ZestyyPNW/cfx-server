-- ============================================================
-- tcp_drugs — client.lua
-- ============================================================

local spawnedPeds = {}
local spawnedBlips = {}

-- ============================================================
-- NUI Dialogue system
-- ============================================================
local pendingDialogueOptions  = nil
local pendingDialogueCallback = nil
local dialogueOpen            = false   -- tracks NUI focus state

local function openDialogue(npcName, text, options, callback)
    pendingDialogueOptions  = options
    pendingDialogueCallback = callback

    local nuiOpts = {}
    for i, opt in ipairs(options) do
        nuiOpts[i] = { label = opt.label }
    end

    SendNUIMessage({ action = 'openDialogue', npcName = npcName, text = text, options = nuiOpts })

    -- Only grab focus once; multi-step dialogues reuse the existing focus
    if not dialogueOpen then
        SetNuiFocus(true, true)
        dialogueOpen = true
    end
end

local function closeDialogueNUI()
    if dialogueOpen then
        SetNuiFocus(false, false)
        dialogueOpen = false
    end
end

RegisterNUICallback('dialogueSelect', function(data, cb)
    local idx      = tonumber(data.index)   -- 1-indexed from JS
    local callback = pendingDialogueCallback
    local options  = pendingDialogueOptions
    pendingDialogueCallback = nil
    pendingDialogueOptions  = nil

    -- Mark closed BEFORE invoking the callback — the callback may reopen
    dialogueOpen = false

    if callback and idx and options and options[idx] then
        callback(options[idx])
    end

    -- If callback didn't reopen a dialogue, release NUI focus now
    if not dialogueOpen then
        SetNuiFocus(false, false)
    end

    cb({})
end)

RegisterNUICallback('dialogueCancel', function(data, cb)
    pendingDialogueCallback = nil
    pendingDialogueOptions  = nil
    dialogueOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

-- Peds that should never be sold to (cops, animals, etc.)
local BLACKLIST_MODELS = {
    's_m_y_cop_01', 's_m_y_hwaycop_01', 's_f_y_cop_01',
    's_m_y_sheriff_01', 's_f_y_sheriff_01',
    's_m_y_swat_01', 's_m_y_uscg_01',
    's_m_y_fireman_01', 's_m_y_paramedic_01',
    'a_c_cat_01', 'a_c_dog', 'a_c_retriever', 'a_c_shepherd',
    'a_c_chickenhawk', 'a_c_crow', 'a_c_seagull',
}

-- ============================================================
-- Helpers
-- ============================================================
local function notify(msg, type)
    lib.notify({ title = 'Drug Operation', description = msg, type = type or 'inform' })
end

local function hasItem(itemName)
    return exports.ox_inventory:Search('count', itemName) > 0
end

local function hasAnyItemFromList(items)
    for _, item in ipairs(items or {}) do
        if hasItem(item) then return true end
    end
    return false
end

local function getOwnedStrainRecipe()
    local cfg = Config.WeedSmokeables
    for _, recipe in ipairs((cfg and cfg.strainJoints) or {}) do
        if hasItem(recipe.inputWeed) then
            return recipe
        end
    end
    return nil
end

local function playAnim(dict, anim, duration)
    local ped = PlayerPedId()
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 3000 do
        Wait(100); t = t + 100
    end
    if not HasAnimDictLoaded(dict) then return end
    TaskPlayAnim(ped, dict, anim, 3.0, -4.0, duration, 49, 0, false, false, false)
end

local function stopAnim(dict, anim)
    local ped = PlayerPedId()
    StopAnimTask(ped, dict, anim, 1.0)
    ClearPedTasks(ped)
end

local function spawnPed(model, coords, heading)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 5000 do
        Wait(100); t = t + 100
    end
    if not HasModelLoaded(hash) then return nil end

    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, heading, false, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(hash)
    spawnedPeds[#spawnedPeds + 1] = ped
    return ped
end

local function createMapBlip(coords, sprite, color, scale, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 140)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, scale or 0.85)
    SetBlipColour(blip, color or 2)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Drug Spot')
    EndTextCommandSetBlipName(blip)
    spawnedBlips[#spawnedBlips + 1] = blip
end

-- Weed-only blips requested: grow + process locations on full map
local function setupWeedBlips()
    local weedZones = Config.Zones and Config.Zones.weed
    if not weedZones then return end

    for _, zone in ipairs(weedZones.grow or {}) do
        createMapBlip(zone.coords, 140, 2, 0.85, 'Weed Grow')
    end

    for _, zone in ipairs(weedZones.process or {}) do
        createMapBlip(zone.coords, 499, 2, 0.85, 'Weed Process')
    end
end

-- ============================================================
-- Progress bar wrapper
-- ============================================================
local function runProgressBar(label, duration, animDict, animName, onComplete)
    playAnim(animDict, animName, duration + 500)

    local success = lib.progressBar({
        duration     = duration * 1000,
        label        = label,
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
    })

    stopAnim(animDict, animName)

    if success then
        onComplete()
    else
        notify('Action cancelled.', 'error')
    end
end

-- ============================================================
-- DRUG EFFECTS
-- Fired by ox_inventory when a product item is used (consume = 1).
-- Event args: (metadata, itemData)  — itemData.name tells us the drug.
-- ============================================================
local activeEffects = {}  -- tracks running effect threads

local ITEM_TO_EFFECT = {
    baggy_weed    = 'weed',
    baggy_meth    = 'meth',
    baggy_cocaine = 'cocaine',
    ['1gheroin']  = 'heroin',
}

local function resolveEffectType(itemName)
    if not itemName then return nil end
    if ITEM_TO_EFFECT[itemName] then
        return ITEM_TO_EFFECT[itemName]
    end

    local lower = string.lower(itemName)
    if lower == 'blunt' or string.find(lower, 'joint', 1, true) then
        return 'weed'
    end

    return nil
end

-- PostFX names (looped)
local EFFECT_FX = {
    weed    = 'DrugsMichaelFightOut',
    meth    = nil,   -- handled via camera shake instead
    cocaine = 'DrugsMichaelAliensFight',
    heroin  = 'DrugsDeathArrest',
}

local function stopDrugEffect(effectType)
    if activeEffects[effectType] then
        activeEffects[effectType] = nil  -- signals thread to stop
    end
end

local function applyDrugEffect(effectType)
    local cfg = Config.DrugEffects[effectType]
    if not cfg then return end

    stopDrugEffect(effectType)  -- cancel any previous instance

    activeEffects[effectType] = true
    local fxName = EFFECT_FX[effectType]

    Citizen.CreateThread(function()
        local ped    = PlayerPedId()
        local expiry = GetGameTimer() + cfg.duration * 1000

        -- Start PostFX if defined
        if fxName then
            AnimpostfxPlay(fxName, 0, true)
        end

        -- Movement speed override
        if cfg.speedMult ~= 1.0 then
            SetRunSprintMultiplierForPlayer(PlayerId(), math.min(cfg.speedMult, 1.5))
            SetPedMoveRateOverride(ped, cfg.speedMult)
        end

        while GetGameTimer() < expiry and activeEffects[effectType] do
            -- Meth / cocaine: periodic camera shake
            if cfg.shake then
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', cfg.shakeAmt)
            end
            Wait(effectType == 'meth' and 2000 or 3000)
        end

        -- Clean up
        if fxName then
            AnimpostfxStop(fxName)
        end
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
        SetPedMoveRateOverride(ped, 1.0)
        StopGameplayCamShaking(true)
        activeEffects[effectType] = nil
    end)
end

AddEventHandler('tcp_drugs:useItem', function(metadata, data)
    local itemName   = data and data.name
    local effectType = resolveEffectType(itemName)
    if not effectType then return end

    local cfg = Config.DrugEffects[effectType]
    if not cfg then return end

    applyDrugEffect(effectType)
    notify(('You used %s. Effects last ~%ds.'):format(data.label or itemName, cfg.duration), 'inform')
end)

-- ============================================================
-- GROW / SOURCE
-- Weed: checks all quality tier seeds; others use rawItem.
-- ============================================================
local function setupGrowZone(drugKey, zone)
    local drug = Config.Drugs[drugKey]

    local function hasAnySeed()
        if drug.qualities then
            for _, q in ipairs(drug.qualities) do
                if hasItem(q.item) then return true end
            end
            return false
        end
        return hasItem(drug.rawItem)
    end

    local function seedDescription()
        if drug.qualities then
            local found = {}
            for _, q in ipairs(drug.qualities) do
                if hasItem(q.item) then
                    found[#found + 1] = q.label
                end
            end
            return #found > 0 and table.concat(found, ', ') or 'none'
        end
        return drug.rawItem
    end

    exports.ox_target:addSphereZone({
        coords  = zone.coords,
        radius  = zone.radius,
        debug   = false,
        options = {
            {
                name    = ('tcp_drugs_grow_%s_%s'):format(drugKey, tostring(zone.coords)),
                icon    = 'fas fa-seedling',
                label   = zone.label,
                onSelect = function()
                    if not hasAnySeed() then
                        local msg = drug.qualities
                            and 'You need seeds to grow here (Schwag / Mid / Loud).'
                            or  ('You need %s to do this.'):format(drug.rawItem)
                        notify(msg, 'error')
                        return
                    end

                    local desc = seedDescription()
                    runProgressBar(
                        ('Growing %s (%s)...'):format(drug.label, desc),
                        drug.growTime,
                        'amb@world_human_gardener_plant@male@idle_a', 'idle_a',
                        function()
                            TriggerServerEvent('tcp_drugs:harvest', drugKey)
                        end
                    )
                end
            }
        }
    })
end

-- ============================================================
-- PROCESS
-- ============================================================
local function setupProcessZone(drugKey, zone)
    local drug = Config.Drugs[drugKey]

    exports.ox_target:addSphereZone({
        coords  = zone.coords,
        radius  = zone.radius,
        debug   = false,
        options = {
            {
                name    = ('tcp_drugs_process_%s_%s'):format(drugKey, tostring(zone.coords)),
                icon    = 'fas fa-flask',
                label   = zone.label,
                onSelect = function()
                    if not hasItem(drug.harvestItem) then
                        notify(('You need %s to process.'):format(drug.harvestItem), 'error')
                        return
                    end

                    runProgressBar(
                        ('Processing %s...'):format(drug.label),
                        drug.processTime,
                        'mini@repair', 'fixing_a_ped',
                        function()
                            TriggerServerEvent('tcp_drugs:process', drugKey)
                        end
                    )
                end
            }
        }
    })
end

-- ============================================================
-- PACKAGE (processItem → productItem)
-- Shows supply requirements in the label if any are configured.
-- ============================================================
local function setupPackageZone(drugKey, zone)
    local drug = Config.Drugs[drugKey]
    local smokeCfg = Config.WeedSmokeables or {}

    local options = {
        {
            name    = ('tcp_drugs_package_%s_%s'):format(drugKey, tostring(zone.coords)),
            icon    = 'fas fa-box',
            label   = ('Bag %s'):format(drug.label),
            onSelect = function()
                if not hasItem(drug.processItem) then
                    notify(('You need processed %s to bag.'):format(drug.label), 'error')
                    return
                end

                -- Client-side supply hint
                local supplies = drug.packageSupplies or {}
                for _, s in ipairs(supplies) do
                    if not hasItem(s.item) then
                        notify(('You need %s x%d to package %s.'):format(s.item, s.count, drug.label), 'error')
                        return
                    end
                end

                runProgressBar(
                    ('Bagging %s...'):format(drug.label),
                    drug.packageTime,
                    'anim@mp_player_intdrink@beer', 'loop_player',
                    function()
                        TriggerServerEvent('tcp_drugs:package', drugKey)
                    end
                )
            end
        }
    }

    if drugKey == 'weed' then
        options[#options + 1] = {
            name  = ('tcp_drugs_roll_joint_%s'):format(tostring(zone.coords)),
            icon  = 'fas fa-smoking',
            label = 'Roll Joint',
            onSelect = function()
                local joint = smokeCfg.joint or {}
                if not hasItem(joint.inputItem or 'ground_weed') then
                    notify('You need ground weed.', 'error')
                    return
                end
                if not hasAnyItemFromList(smokeCfg.paperItems) then
                    notify('You need rolling papers.', 'error')
                    return
                end

                runProgressBar(
                    'Rolling Joint...',
                    joint.craftTime or 12,
                    'anim@mp_player_intdrink@beer', 'loop_player',
                    function()
                        TriggerServerEvent('tcp_drugs:craftSmoke', 'joint')
                    end
                )
            end
        }

        options[#options + 1] = {
            name  = ('tcp_drugs_roll_blunt_%s'):format(tostring(zone.coords)),
            icon  = 'fas fa-cannabis',
            label = 'Roll Blunt',
            onSelect = function()
                local blunt = smokeCfg.blunt or {}
                if exports.ox_inventory:Search('count', blunt.inputItem or 'ground_weed') < (blunt.inputCount or 2) then
                    notify(('You need %s x%d.'):format(blunt.inputItem or 'ground_weed', blunt.inputCount or 2), 'error')
                    return
                end
                if exports.ox_inventory:Search('count', blunt.wrapItem or 'bluntwrap') < (blunt.wrapCount or 1) then
                    notify(('You need %s x%d.'):format(blunt.wrapItem or 'bluntwrap', blunt.wrapCount or 1), 'error')
                    return
                end

                runProgressBar(
                    'Rolling Blunt...',
                    blunt.craftTime or 16,
                    'anim@mp_player_intdrink@beer', 'loop_player',
                    function()
                        TriggerServerEvent('tcp_drugs:craftSmoke', 'blunt')
                    end
                )
            end
        }

        options[#options + 1] = {
            name  = ('tcp_drugs_roll_strain_joint_%s'):format(tostring(zone.coords)),
            icon  = 'fas fa-leaf',
            label = 'Roll Strain Joint',
            onSelect = function()
                local owned = getOwnedStrainRecipe()
                if not owned then
                    notify('You need strain weed (Banana/Blue Dream/OG/Purple Haze).', 'error')
                    return
                end
                if not hasAnyItemFromList(smokeCfg.paperItems) then
                    notify('You need rolling papers.', 'error')
                    return
                end

                runProgressBar(
                    ('Rolling %s Joint...'):format(owned.label or 'Strain'),
                    smokeCfg.joint and smokeCfg.joint.craftTime or 12,
                    'anim@mp_player_intdrink@beer', 'loop_player',
                    function()
                        TriggerServerEvent('tcp_drugs:craftSmoke', 'strain_joint')
                    end
                )
            end
        }
    end

    exports.ox_target:addSphereZone({
        coords  = zone.coords,
        radius  = zone.radius,
        debug   = false,
        options = options
    })
end

-- ============================================================
-- SELL — global ped targeting
-- ============================================================
local function setupGlobalSell()
    local blacklist = {}
    for _, model in ipairs(BLACKLIST_MODELS) do
        blacklist[GetHashKey(model)] = true
    end

    exports.ox_target:addGlobalPed({
        {
            name     = 'tcp_drugs_sell_global',
            icon     = 'fas fa-hand-holding-usd',
            label    = 'Offer Drugs',
            distance = 2.0,
            canInteract = function(entity)
                if not entity or entity == 0 then return false end
                if not IsPedHuman(entity) then return false end
                if IsEntityDead(entity) then return false end
                if IsPedAPlayer(entity) then return false end
                if blacklist[GetEntityModel(entity)] then return false end
                return true
            end,
            onSelect = function(data)
                local available = {}
                for drugKey, drug in pairs(Config.Drugs) do
                    local count = exports.ox_inventory:Search('count', drug.productItem)
                    if count and count > 0 then
                        available[#available + 1] = { key = drugKey, label = drug.label, count = count }
                    end
                end

                if #available == 0 then
                    notify("You don't have anything to sell.", 'error')
                    return
                end

                local pedNetId = NetworkGetNetworkIdFromEntity(data.entity)

                local function offerAmount(drugKey, drug, count)
                    -- Build amount options: 1, 3, 5, all (deduplicated)
                    local presets = {}
                    local seen    = {}
                    for _, n in ipairs({ 1, 3, 5, count }) do
                        if n <= count and not seen[n] then
                            seen[n] = true
                            presets[#presets + 1] = {
                                label = n == count
                                    and ('Sell all  (x%d)'):format(n)
                                    or  ('x%d'):format(n),
                                data  = n,
                            }
                        end
                    end
                    presets[#presets + 1] = { label = 'Forget it.', data = nil }

                    openDialogue('You', ('How much %s you offering?'):format(drug.label), presets, function(sel)
                        if not sel.data then return end
                        TriggerServerEvent('tcp_drugs:sell', drugKey, sel.data, pedNetId)
                    end)
                end

                if #available == 1 then
                    offerAmount(available[1].key, Config.Drugs[available[1].key], available[1].count)
                else
                    local drugOpts = {}
                    for _, d in ipairs(available) do
                        drugOpts[#drugOpts + 1] = { label = ('%s  (x%d)'):format(d.label, d.count), data = d }
                    end
                    drugOpts[#drugOpts + 1] = { label = 'Nothing.', data = nil }

                    openDialogue('You', "What are you trying to move?", drugOpts, function(sel)
                        if not sel.data then return end
                        local d = sel.data
                        offerAmount(d.key, Config.Drugs[d.key], d.count)
                    end)
                end
            end
        }
    })
end

-- Dealer greetings (cycles randomly)
local DEALER_GREETINGS = {
    "Aye, make it quick. What you need?",
    "I don't know you. But I know what you want.",
    "Cash only. No receipts. What'll it be?",
    "Don't just stand there staring. You buying or what?",
}

-- ============================================================
-- SUPPLY DEALER NPC
-- ============================================================
local function setupSupplyDealer()
    local cfg = Config.SupplyDealer
    local ped = spawnPed(cfg.ped, cfg.coords, cfg.heading)
    if not ped then return end

    local function openShop()
        local options = {}
        for _, entry in ipairs(cfg.items) do
            local e = entry
            options[#options + 1] = {
                label = ('%s  —  $%d'):format(e.label, e.price),
                data  = e,
            }
        end
        options[#options + 1] = { label = "Nothing. My bad.", data = nil }

        local greeting = DEALER_GREETINGS[math.random(#DEALER_GREETINGS)]
        openDialogue(cfg.label, greeting, options, function(selected)
            if not selected.data then return end
            local e = selected.data
            TriggerServerEvent('tcp_drugs:buySupply', e.item, e.count, e.price)
        end)
    end

    exports.ox_target:addLocalEntity(ped, {
        {
            name     = 'tcp_drugs_supply_dealer',
            icon     = 'fas fa-boxes',
            label    = cfg.label,
            distance = 4.0,
            onSelect = openShop,
        }
    })

    -- Fallback zone interaction in case map props (desk/counter) make ped targeting awkward.
    exports.ox_target:addSphereZone({
        coords  = cfg.coords,
        radius  = 2.2,
        debug   = false,
        options = {
            {
                name     = 'tcp_drugs_supply_dealer_zone',
                icon     = 'fas fa-cannabis',
                label    = cfg.label,
                distance = 4.0,
                onSelect = openShop,
            }
        }
    })
end

-- ============================================================
-- LAUNDERER NPC
-- ============================================================
local function setupLaunderer()
    local cfg = Config.LaunderDealer
    local ped = spawnPed(cfg.ped, cfg.coords, cfg.heading)
    if not ped then return end

    exports.ox_target:addLocalEntity(ped, {
        {
            name     = 'tcp_drugs_launderer',
            icon     = 'fas fa-money-bill-wave',
            label    = cfg.label,
            distance = 2.5,
            onSelect = function()
                local dirty = exports.ox_inventory:Search('count', 'dirty_money')

                if not dirty or dirty < Config.DirtyMoney.minAmount then
                    -- Dialogue rejection if not enough dirty money
                    local msg = dirty and dirty > 0
                        and ("$%d? That's not even worth my time. Come back with more."):format(dirty)
                        or  "You don't have anything for me to work with."
                    openDialogue(cfg.label, msg, { { label = 'My bad.', data = nil } }, function() end)
                    return
                end

                local pct   = math.floor(Config.DirtyMoney.launderRate * 100)
                local clean = math.floor(dirty * Config.DirtyMoney.launderRate)
                local half  = math.floor(dirty * 0.5)
                local cleanHalf = math.floor(half * Config.DirtyMoney.launderRate)

                local greeting = ("I move money. You got $%d dirty — I'll clean it for %d cents on the dollar."):format(dirty, pct)

                local options = {
                    {
                        label = ('Launder all  $%d dirty  →  $%d clean'):format(dirty, clean),
                        data  = { amount = dirty },
                    },
                }
                if half >= Config.DirtyMoney.minAmount then
                    options[#options + 1] = {
                        label = ('Launder half  $%d dirty  →  $%d clean'):format(half, cleanHalf),
                        data  = { amount = half },
                    }
                end
                options[#options + 1] = { label = "Not today.", data = nil }

                openDialogue(cfg.label, greeting, options, function(selected)
                    if not selected.data then return end
                    TriggerServerEvent('tcp_drugs:launder', selected.data.amount)
                end)
            end,
        }
    })
end

-- ============================================================
-- INIT
-- ============================================================
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    setupWeedBlips()

    for drugKey, zones in pairs(Config.Zones) do
        for _, zone in ipairs(zones.grow or {}) do
            setupGrowZone(drugKey, zone)
        end
        for _, zone in ipairs(zones.process or {}) do
            setupProcessZone(drugKey, zone)
            setupPackageZone(drugKey, zone)
        end
    end

    setupGlobalSell()
    setupSupplyDealer()
    setupLaunderer()
end)

AddEventHandler('onClientResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end

    -- Close dialogue if open
    SendNUIMessage({ action = 'closeDialogue' })
    closeDialogueNUI()
    pendingDialogueCallback = nil
    pendingDialogueOptions  = nil

    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    for _, blip in ipairs(spawnedBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    spawnedBlips = {}
    -- Clear any active drug effects
    for effectType in pairs(activeEffects) do
        activeEffects[effectType] = nil
    end
    for _, fxName in pairs(EFFECT_FX) do
        if fxName then AnimpostfxStop(fxName) end
    end
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    StopGameplayCamShaking(true)
end)

-- ============================================================
-- Network events from server
-- ============================================================
RegisterNetEvent('tcp_drugs:notify')
AddEventHandler('tcp_drugs:notify', function(msg, type)
    notify(msg, type)
end)

-- NPC bought — hand-off exchange animation
RegisterNetEvent('tcp_drugs:pedAccept')
AddEventHandler('tcp_drugs:pedAccept', function(pedNetId)
    local npc    = NetworkGetEntityFromNetworkId(pedNetId)
    local player = PlayerPedId()
    if not npc or npc == 0 or not DoesEntityExist(npc) then return end

    local dict = 'mp_common'
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 3000 do Wait(100); t = t + 100 end
    if not HasAnimDictLoaded(dict) then return end

    TaskTurnPedToFaceEntity(player, npc, -1)
    TaskTurnPedToFaceEntity(npc, player, -1)
    Wait(400)

    TaskPlayAnim(player, dict, 'givetake1_a', 4.0, -4.0, 2500, 48, 0, false, false, false)
    TaskPlayAnim(npc,    dict, 'givetake1_b', 4.0, -4.0, 2500, 48, 0, false, false, false)

    Wait(2800)
    ClearPedTasks(player)
    ClearPedTasks(npc)
end)

-- NPC refused — flees
RegisterNetEvent('tcp_drugs:pedReject')
AddEventHandler('tcp_drugs:pedReject', function(pedNetId)
    local ped = NetworkGetEntityFromNetworkId(pedNetId)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    TaskReactAndFleePed(ped, PlayerPedId())
    Wait(3000)
    if DoesEntityExist(ped) then ClearPedTasks(ped) end
end)
