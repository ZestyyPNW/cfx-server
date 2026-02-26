-- ============================================================
-- tcp_drugs — server.lua
-- ============================================================

-- ============================================================
-- Cooldowns
-- ============================================================
local cooldowns = {}

local function getCooldownKey(src, action, drugKey)
    return ('%d_%s_%s'):format(src, action, drugKey)
end

local function isOnCooldown(src, action, drugKey)
    if Config.ZoneCooldown == 0 then return false end
    local key  = getCooldownKey(src, action, drugKey)
    local last = cooldowns[key]
    if not last then return false end
    return (os.time() - last) < Config.ZoneCooldown
end

local function setCooldown(src, action, drugKey)
    if Config.ZoneCooldown == 0 then return end
    cooldowns[getCooldownKey(src, action, drugKey)] = os.time()
end

-- ============================================================
-- Heat system  (per-player, persists in memory until resource restart)
-- ============================================================
local playerHeat = {}  -- [src] = { points = N, lastDecay = timestamp }

local function getHeat(src)
    if not playerHeat[src] then
        playerHeat[src] = { points = 0, lastDecay = os.time() }
    end
    local now     = os.time()
    local elapsed = now - playerHeat[src].lastDecay
    local decay   = math.floor(elapsed / 60) * Config.Heat.decayPerMinute
    if decay > 0 then
        playerHeat[src].points    = math.max(0, playerHeat[src].points - decay)
        playerHeat[src].lastDecay = now
    end
    return playerHeat[src].points
end

local function addHeat(src, amount)
    getHeat(src)  -- run decay first
    playerHeat[src].points = playerHeat[src].points + amount
    return playerHeat[src].points
end

local function sendHeatAlert(src, drugKey, amount, heat)
    local drug    = Config.Drugs[drugKey] or {}
    local players = GetPlayers()
    local detail  = heat >= Config.Heat.bustedThreshold
        and ('High-frequency activity — %s x%d (multiple sightings)'):format(drug.label or drugKey, amount)
        or  ('Possible drug activity — %s x%d'):format(drug.label or drugKey, amount)

    for _, pid in ipairs(players) do
        local pidNum = tonumber(pid)
        if Player(pidNum).state and Player(pidNum).state.onduty then
            TriggerClientEvent('chat:addMessage', pidNum, {
                color     = { 255, 100, 0 },
                multiline = false,
                args      = { '^3NARCOTICS', detail }
            })
        end
    end
end

-- ============================================================
-- Helpers
-- ============================================================
local function getPlayer(src)
    if GetResourceState('ND_Core') ~= 'started' then return nil end
    return exports['ND_Core']:getPlayer(src)
end

local function notify(src, msg, type)
    TriggerClientEvent('tcp_drugs:notify', src, msg, type or 'inform')
end

local function hasItem(src, item, count)
    count = count or 1
    return exports.ox_inventory:Search(src, 'count', item) >= count
end

local function removeItem(src, item, count)
    return exports.ox_inventory:RemoveItem(src, item, count or 1)
end

local function giveItem(src, item, count, metadata)
    return exports.ox_inventory:AddItem(src, item, count or 1, metadata)
end

local function findFirstOwnedItem(src, items)
    for _, item in ipairs(items or {}) do
        if hasItem(src, item, 1) then
            return item
        end
    end
    return nil
end

local function randomFromPool(pool)
    if type(pool) ~= 'table' or #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

-- ============================================================
-- HARVEST — consume seed/raw item, grant harvestItem
-- Weed supports quality tiers (weed_seed1 / weed_seed / weed_seed3)
-- ============================================================
RegisterNetEvent('tcp_drugs:harvest')
AddEventHandler('tcp_drugs:harvest', function(drugKey)
    local src  = source
    local drug = Config.Drugs[drugKey]
    if not drug then return end

    if isOnCooldown(src, 'harvest', drugKey) then
        notify(src, 'This spot is being watched. Try again later.', 'error')
        return
    end

    -- Quality tier detection (weed only)
    local yieldMin, yieldMax, qualityLabel
    if drug.qualities then
        local usedItem = nil
        for _, q in ipairs(drug.qualities) do
            if hasItem(src, q.item) then
                usedItem     = q.item
                yieldMin     = q.yieldMin
                yieldMax     = q.yieldMax
                qualityLabel = q.label
                break
            end
        end
        if not usedItem then
            notify(src, 'You need seeds to grow here.', 'error')
            return
        end
        if not removeItem(src, usedItem, 1) then
            notify(src, 'Failed to consume seed.', 'error')
            return
        end
    else
        -- Non-weed drugs: consume rawItem
        if not hasItem(src, drug.rawItem) then
            notify(src, ('You need %s to do this.'):format(drug.rawItem), 'error')
            return
        end
        if not removeItem(src, drug.rawItem, 1) then
            notify(src, 'Failed to use item.', 'error')
            return
        end
        yieldMin     = drug.yieldMin or 2
        yieldMax     = drug.yieldMax or 5
        qualityLabel = nil
    end

    local yield = math.random(yieldMin, yieldMax)
    giveItem(src, drug.harvestItem, yield)
    setCooldown(src, 'harvest', drugKey)

    local label = qualityLabel and ('%s (%s)'):format(drug.label, qualityLabel) or drug.label
    notify(src, ('Harvested x%d %s.'):format(yield, label), 'success')
end)

-- ============================================================
-- PROCESS — consume harvestItem, grant processItem
-- (skipped if harvestItem == processItem)
-- ============================================================
RegisterNetEvent('tcp_drugs:process')
AddEventHandler('tcp_drugs:process', function(drugKey)
    local src  = source
    local drug = Config.Drugs[drugKey]
    if not drug then return end

    if isOnCooldown(src, 'process', drugKey) then
        notify(src, 'This spot is busy. Try again later.', 'error')
        return
    end

    if not hasItem(src, drug.harvestItem) then
        notify(src, ('You need %s to process.'):format(drug.harvestItem), 'error')
        return
    end

    -- Same item means process zone is cosmetic only (meth_tray, etc.)
    if drug.harvestItem == drug.processItem then
        setCooldown(src, 'process', drugKey)
        notify(src, (drug.label .. ' is ready to bag.'), 'success')
        return
    end

    local count = exports.ox_inventory:Search(src, 'count', drug.harvestItem)
    if not removeItem(src, drug.harvestItem, count) then
        notify(src, 'Failed to use item.', 'error')
        return
    end

    local yield = math.max(1, math.floor(count * math.random(70, 90) / 100))
    giveItem(src, drug.processItem, yield)
    setCooldown(src, 'process', drugKey)

    notify(src, ('Processed x%d %s.'):format(yield, drug.label), 'success')
end)

-- ============================================================
-- PACKAGE — consume processItem (+ optional supplies), grant productItem
-- ============================================================
RegisterNetEvent('tcp_drugs:package')
AddEventHandler('tcp_drugs:package', function(drugKey)
    local src  = source
    local drug = Config.Drugs[drugKey]
    if not drug then return end

    if isOnCooldown(src, 'package', drugKey) then
        notify(src, 'This spot is busy. Try again later.', 'error')
        return
    end

    if not hasItem(src, drug.processItem) then
        notify(src, ('You need processed %s to bag.'):format(drug.label), 'error')
        return
    end

    -- Check and consume packaging supplies (cutting agent, chemicals, etc.)
    local supplies = drug.packageSupplies or {}
    for _, s in ipairs(supplies) do
        if not hasItem(src, s.item, s.count) then
            notify(src, ('You need %s x%d to package %s.'):format(s.item, s.count, drug.label), 'error')
            return
        end
    end
    for _, s in ipairs(supplies) do
        removeItem(src, s.item, s.count)
    end

    local count = exports.ox_inventory:Search(src, 'count', drug.processItem)
    if not removeItem(src, drug.processItem, count) then
        -- Refund supplies if processing fails
        for _, s in ipairs(supplies) do giveItem(src, s.item, s.count) end
        notify(src, 'Failed to use item.', 'error')
        return
    end

    giveItem(src, drug.productItem, count)
    setCooldown(src, 'package', drugKey)

    notify(src, ('Bagged x%d %s.'):format(count, drug.label), 'success')
end)

-- ============================================================
-- CRAFT SMOKEABLES — weed-only joints/blunts/strain joints
-- ============================================================
RegisterNetEvent('tcp_drugs:craftSmoke')
AddEventHandler('tcp_drugs:craftSmoke', function(craftType)
    local src = source
    local cfg = Config.WeedSmokeables
    if not cfg then return end

    if craftType == 'joint' then
        local recipe = cfg.joint or {}
        local paper  = findFirstOwnedItem(src, cfg.paperItems)
        if not hasItem(src, recipe.inputItem, recipe.inputCount or 1) then
            notify(src, ('You need %s x%d.'):format(recipe.inputItem or 'ground_weed', recipe.inputCount or 1), 'error')
            return
        end
        if not paper then
            notify(src, 'You need rolling papers.', 'error')
            return
        end

        if not removeItem(src, recipe.inputItem, recipe.inputCount or 1) then
            notify(src, 'Failed to use weed.', 'error')
            return
        end
        if not removeItem(src, paper, 1) then
            giveItem(src, recipe.inputItem, recipe.inputCount or 1)
            notify(src, 'Failed to use papers.', 'error')
            return
        end

        local output = randomFromPool(recipe.outputPool) or 'joint'
        if not giveItem(src, output, 1) then
            giveItem(src, recipe.inputItem, recipe.inputCount or 1)
            giveItem(src, paper, 1)
            notify(src, 'Not enough inventory space.', 'error')
            return
        end

        notify(src, ('Rolled 1x %s.'):format(output), 'success')
        return
    end

    if craftType == 'blunt' then
        local recipe = cfg.blunt or {}
        if not hasItem(src, recipe.inputItem, recipe.inputCount or 2) then
            notify(src, ('You need %s x%d.'):format(recipe.inputItem or 'ground_weed', recipe.inputCount or 2), 'error')
            return
        end
        if not hasItem(src, recipe.wrapItem, recipe.wrapCount or 1) then
            notify(src, ('You need %s x%d.'):format(recipe.wrapItem or 'bluntwrap', recipe.wrapCount or 1), 'error')
            return
        end

        if not removeItem(src, recipe.inputItem, recipe.inputCount or 2) then
            notify(src, 'Failed to use weed.', 'error')
            return
        end
        if not removeItem(src, recipe.wrapItem, recipe.wrapCount or 1) then
            giveItem(src, recipe.inputItem, recipe.inputCount or 2)
            notify(src, 'Failed to use blunt wrap.', 'error')
            return
        end

        local output = recipe.outputItem or 'blunt'
        if not giveItem(src, output, 1) then
            giveItem(src, recipe.inputItem, recipe.inputCount or 2)
            giveItem(src, recipe.wrapItem, recipe.wrapCount or 1)
            notify(src, 'Not enough inventory space.', 'error')
            return
        end

        notify(src, ('Rolled 1x %s.'):format(output), 'success')
        return
    end

    if craftType == 'strain_joint' then
        local paper = findFirstOwnedItem(src, cfg.paperItems)
        if not paper then
            notify(src, 'You need rolling papers.', 'error')
            return
        end

        local selected = nil
        for _, recipe in ipairs(cfg.strainJoints or {}) do
            if hasItem(src, recipe.inputWeed, 1) then
                selected = recipe
                break
            end
        end

        if not selected then
            notify(src, 'You need strain weed (Banana/Blue Dream/OG/Purple Haze).', 'error')
            return
        end

        if not removeItem(src, selected.inputWeed, 1) then
            notify(src, 'Failed to use strain weed.', 'error')
            return
        end
        if not removeItem(src, paper, 1) then
            giveItem(src, selected.inputWeed, 1)
            notify(src, 'Failed to use papers.', 'error')
            return
        end

        if not giveItem(src, selected.outputJoint, 1) then
            giveItem(src, selected.inputWeed, 1)
            giveItem(src, paper, 1)
            notify(src, 'Not enough inventory space.', 'error')
            return
        end

        notify(src, ('Rolled 1x %s Joint.'):format(selected.label or 'Strain'), 'success')
        return
    end

    notify(src, 'Unknown recipe.', 'error')
end)

-- ============================================================
-- SELL — 50/50 NPC buy; pays dirty_money (or cash if disabled)
-- ============================================================
RegisterNetEvent('tcp_drugs:sell')
AddEventHandler('tcp_drugs:sell', function(drugKey, amount, pedNetId)
    local src  = source
    local drug = Config.Drugs[drugKey]
    if not drug then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return end

    local available = exports.ox_inventory:Search(src, 'count', drug.productItem)
    if available < amount then
        notify(src, ('You only have %d %s.'):format(available, drug.label), 'error')
        return
    end

    if isOnCooldown(src, 'sell', drugKey) then
        notify(src, 'Not right now. Try someone else.', 'error')
        return
    end

    -- 50/50 chance
    if math.random(2) == 1 then
        setCooldown(src, 'sell', drugKey)
        notify(src, "They're not interested.", 'error')
        TriggerClientEvent('tcp_drugs:pedReject', src, pedNetId)
        return
    end

    if not removeItem(src, drug.productItem, amount) then
        notify(src, 'Failed to hand over items.', 'error')
        return
    end

    local variance   = drug.sellVariance or 0.15
    local multiplier = 1.0 + (math.random() * variance * 2 - variance)
    local total      = math.floor(drug.sellPriceBase * multiplier) * amount

    -- Dirty money or clean cash
    if Config.DirtyMoney.enabled then
        giveItem(src, 'dirty_money', total)
        notify(src, ('Sold x%d %s for $%d dirty.'):format(amount, drug.label, total), 'success')
    else
        local player = getPlayer(src)
        if not player then
            notify(src, 'Could not process payment.', 'error')
            giveItem(src, drug.productItem, amount)
            return
        end
        player.addMoney('cash', total, 'Drug sale')
        notify(src, ('Sold x%d %s for $%d.'):format(amount, drug.label, total), 'success')
    end

    setCooldown(src, 'sell', drugKey)
    TriggerClientEvent('tcp_drugs:pedAccept', src, pedNetId)

    -- Heat
    local heat = addHeat(src, Config.Heat.perSale)
    if heat >= Config.Heat.alertThreshold then
        sendHeatAlert(src, drugKey, amount, heat)
    end
end)

-- ============================================================
-- LAUNDER — exchange dirty_money items for clean cash
-- ============================================================
RegisterNetEvent('tcp_drugs:launder')
AddEventHandler('tcp_drugs:launder', function(amount)
    local src = source
    amount = math.floor(tonumber(amount) or 0)

    if amount < Config.DirtyMoney.minAmount then
        notify(src, ('Minimum launder amount is $%d.'):format(Config.DirtyMoney.minAmount), 'error')
        return
    end

    local have = exports.ox_inventory:Search(src, 'count', 'dirty_money')
    if have < amount then
        notify(src, ('You only have $%d dirty.'):format(have), 'error')
        return
    end

    if not removeItem(src, 'dirty_money', amount) then
        notify(src, 'Failed to process dirty money.', 'error')
        return
    end

    local clean  = math.floor(amount * Config.DirtyMoney.launderRate)
    local player = getPlayer(src)
    if not player then
        giveItem(src, 'dirty_money', amount)
        notify(src, 'Could not process payment.', 'error')
        return
    end

    player.addMoney('cash', clean, 'Laundered funds')
    notify(src, ('Laundered $%d dirty → $%d clean.'):format(amount, clean), 'success')
end)

-- ============================================================
-- BUY SUPPLY — purchase items from the black market dealer
-- ============================================================
RegisterNetEvent('tcp_drugs:buySupply')
AddEventHandler('tcp_drugs:buySupply', function(itemName, count, price)
    local src = source
    local reqCount = math.floor(tonumber(count) or 0)
    local reqPrice = math.floor(tonumber(price) or 0)

    if type(itemName) ~= 'string' or reqCount < 1 or reqPrice < 1 then
        notify(src, 'Invalid purchase.', 'error')
        return
    end

    -- Validate against config to prevent manipulation
    local valid = false
    for _, entry in ipairs(Config.SupplyDealer.items) do
        if entry.item == itemName and tonumber(entry.count) == reqCount and tonumber(entry.price) == reqPrice then
            valid = true
            break
        end
    end
    if not valid then
        notify(src, 'Invalid purchase.', 'error')
        return
    end

    local player = getPlayer(src)
    if not player then
        notify(src, 'Could not process payment.', 'error')
        return
    end

    -- ND_Core cash check (supports multiple API shapes)
    local cash = tonumber(player.cash) or 0
    if cash <= 0 and player.getData then
        cash = tonumber(player.getData('cash')) or 0
    end
    if cash <= 0 and player.getMoney then
        cash = tonumber(player.getMoney('cash')) or 0
    end

    if cash < reqPrice then
        notify(src, ('You need $%d cash.'):format(reqPrice), 'error')
        return
    end

    -- Deduct cash with ND_Core-compatible method
    local paid = false
    if player.deductMoney then
        paid = player.deductMoney('cash', reqPrice, 'Supply purchase') == true
    elseif player.removeMoney then
        paid = player.removeMoney('cash', reqPrice, 'Supply purchase') == true
    end

    if not paid then
        notify(src, 'Payment failed.', 'error')
        return
    end

    local added = giveItem(src, itemName, reqCount)
    if not added then
        -- Refund on inventory failure
        if player.addMoney then
            player.addMoney('cash', reqPrice, 'Supply purchase refund')
        end
        notify(src, 'Not enough inventory space.', 'error')
        return
    end

    notify(src, ('Purchased x%d for $%d.'):format(reqCount, reqPrice), 'success')
end)
