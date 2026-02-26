local damageFeedConfig = (config and config.damageFeed) or {}
if damageFeedConfig.enabled == false then
    return
end

local MIN_DAMAGE = math.max(1, tonumber(damageFeedConfig.minDamage) or 1)
local THROTTLE_MS = math.max(0, tonumber(damageFeedConfig.throttleMs) or 250)
local DEDUPE_WINDOW_MS = math.max(0, tonumber(damageFeedConfig.dedupeWindowMs) or 500)
local CONTEXT_WINDOW_MS = math.max(100, tonumber(damageFeedConfig.contextWindowMs) or 600)
local SHOW_HEALTH = damageFeedConfig.showHealth ~= false

local function getChatColor()
    local color = damageFeedConfig.chatColor
    if type(color) ~= "table" then return { 255, 150, 150 } end
    return {
        tonumber(color[1]) or 255,
        tonumber(color[2]) or 150,
        tonumber(color[3]) or 150
    }
end

local CHAT_COLOR = getChatColor()

local GROUP_PISTOL = GetHashKey("GROUP_PISTOL")
local GROUP_SMG = GetHashKey("GROUP_SMG")
local GROUP_RIFLE = GetHashKey("GROUP_RIFLE")
local GROUP_MG = GetHashKey("GROUP_MG")
local GROUP_SHOTGUN = GetHashKey("GROUP_SHOTGUN")
local GROUP_SNIPER = GetHashKey("GROUP_SNIPER")
local GROUP_HEAVY = GetHashKey("GROUP_HEAVY")
local GROUP_MELEE = GetHashKey("GROUP_MELEE")

local FIREARM_GROUPS = {
    [GROUP_PISTOL] = true,
    [GROUP_SMG] = true,
    [GROUP_RIFLE] = true,
    [GROUP_MG] = true,
    [GROUP_SHOTGUN] = true,
    [GROUP_SNIPER] = true
}

local FIREARM_LABELS = {
    [`WEAPON_PISTOL`] = "9mm - Semi",
    [`WEAPON_COMBATPISTOL`] = "9mm - Semi",
    [`WEAPON_PISTOL_MK2`] = "9mm - Semi",
    [`WEAPON_FN509`] = "9mm - Semi",
    [`WEAPON_GLOCK19`] = "9mm - Semi",
    [`WEAPON_P99`] = "9mm - Semi",
    [`WEAPON_M9A3`] = "9mm - Semi",
    [`WEAPON_P226R`] = "9mm - Semi",
    [`WEAPON_SAFETYPISTOL`] = "9mm - Semi",
    [`WEAPON_P320C`] = "9mm - Semi",
    [`WEAPON_MODEL659`] = "9mm - Semi",
    [`WEAPON_MICROSMG`] = "9mm - Auto",
    [`WEAPON_SMG`] = "9mm - Auto",
    [`WEAPON_CARBINERIFLE`] = "5.56 - Semi/Auto",
    [`WEAPON_ASSAULTRIFLE`] = "7.62 - Auto",
    [`WEAPON_PUMPSHOTGUN`] = "12 Gauge - Pump"
}

local BLUNT_MELEE_WEAPONS = {
    [`WEAPON_UNARMED`] = true,
    [`WEAPON_NIGHTSTICK`] = true,
    [`WEAPON_HAMMER`] = true,
    [`WEAPON_BAT`] = true,
    [`WEAPON_CROWBAR`] = true,
    [`WEAPON_GOLFCLUB`] = true,
    [`WEAPON_FLASHLIGHT`] = true,
    [`WEAPON_WRENCH`] = true,
    [`WEAPON_POOLCUE`] = true,
    [`WEAPON_KNUCKLE`] = true
}

local BLADED_MELEE_WEAPONS = {
    [`WEAPON_KNIFE`] = true,
    [`WEAPON_SWITCHBLADE`] = true,
    [`WEAPON_MACHETE`] = true,
    [`WEAPON_DAGGER`] = true,
    [`WEAPON_BOTTLE`] = true
}

local VEHICLE_WEAPONS = {
    [`WEAPON_RUN_OVER_BY_CAR`] = true,
    [`WEAPON_RAMMED_BY_CAR`] = true
}

local FALL_WEAPONS = {
    [`WEAPON_FALL`] = true
}

local EXPLOSION_WEAPONS = {
    [`WEAPON_EXPLOSION`] = true,
    [`WEAPON_GRENADE`] = true,
    [`WEAPON_STICKYBOMB`] = true,
    [`WEAPON_PROXMINE`] = true,
    [`WEAPON_PIPEBOMB`] = true,
    [`WEAPON_RPG`] = true,
    [`WEAPON_HOMINGLAUNCHER`] = true,
    [`WEAPON_GRENADELAUNCHER`] = true,
    [`WEAPON_COMPACTLAUNCHER`] = true
}

local FIRE_WEAPONS = {
    [`WEAPON_FIRE`] = true,
    [`WEAPON_BURNING`] = true,
    [`WEAPON_MOLOTOV`] = true,
    [`WEAPON_FLARE`] = true
}

local DROWNING_WEAPONS = {
    [`WEAPON_DROWNING`] = true,
    [`WEAPON_DROWNING_IN_VEHICLE`] = true
}

local BONE_LABELS = {
    [31086] = "Head",
    [39317] = "Neck",
    [57597] = "Spine",
    [24816] = "Chest",
    [24817] = "Chest",
    [24818] = "Chest",
    [10706] = "Upper Back",
    [64729] = "Upper Back",
    [11816] = "Lower Back",
    [23553] = "Chest",
    [24806] = "Stomach",
    [58271] = "Left Leg",
    [63931] = "Left Leg",
    [14201] = "Left Foot",
    [2108] = "Left Foot",
    [65245] = "Right Leg",
    [36864] = "Right Leg",
    [52301] = "Right Foot",
    [20781] = "Right Foot",
    [45509] = "Left Arm",
    [61163] = "Left Forearm",
    [18905] = "Left Hand",
    [26610] = "Left Finger",
    [40269] = "Right Arm",
    [28252] = "Right Forearm",
    [57005] = "Right Hand",
    [58866] = "Right Finger"
}

local recentDamageEvents = {}
local lastKnownHealth = nil
local lastMessageAt = 0
local lastMessageSignature = nil
local lastMessageSignatureAt = 0

local function getBoneLabel(ped)
    local hit, bone = GetPedLastDamageBone(ped)
    if not hit then return "Body" end
    return BONE_LABELS[bone] or "Body"
end

local function getFirearmLabel(weaponHash)
    local exact = FIREARM_LABELS[weaponHash]
    if exact then return exact end

    local weaponGroup = GetWeapontypeGroup(weaponHash)
    if weaponGroup == GROUP_PISTOL then return "a pistol round" end
    if weaponGroup == GROUP_SHOTGUN then return "a shotgun blast" end
    if weaponGroup == GROUP_SMG then return "an SMG burst" end
    if weaponGroup == GROUP_RIFLE then return "a rifle round" end
    if weaponGroup == GROUP_SNIPER then return "a sniper round" end
    if weaponGroup == GROUP_MG then return "a machine gun burst" end
    return "a firearm round"
end

local function inferFallbackCategory(victimPed)
    if IsEntityInWater(victimPed) and IsPedSwimmingUnderWater(victimPed) then
        return "drowning", nil
    end

    if IsEntityOnFire(victimPed) then
        return "fire", nil
    end

    return "unknown", nil
end

local function classifyDamage(weaponHash, attackerEntity, victimPed)
    if weaponHash and weaponHash ~= 0 then
        if DROWNING_WEAPONS[weaponHash] then
            return "drowning", nil
        end

        if FIRE_WEAPONS[weaponHash] then
            return "fire", nil
        end

        if EXPLOSION_WEAPONS[weaponHash] then
            return "explosion", nil
        end

        if FALL_WEAPONS[weaponHash] then
            return "fall", nil
        end

        if VEHICLE_WEAPONS[weaponHash] then
            return "vehicle", nil
        end

        if BLADED_MELEE_WEAPONS[weaponHash] then
            return "melee", "bladed"
        end

        if BLUNT_MELEE_WEAPONS[weaponHash] then
            return "melee", "blunt"
        end

        local weaponGroup = GetWeapontypeGroup(weaponHash)
        if weaponGroup == GROUP_MELEE then
            return "melee", "blunt"
        end

        if FIREARM_GROUPS[weaponGroup] then
            return "firearm", getFirearmLabel(weaponHash)
        end

        if weaponGroup == GROUP_HEAVY then
            return "explosion", nil
        end
    end

    if attackerEntity and attackerEntity ~= 0 and DoesEntityExist(attackerEntity) and IsEntityAVehicle(attackerEntity) then
        return "vehicle", nil
    end

    return inferFallbackCategory(victimPed)
end

local function pruneOldContexts(nowMs)
    for i = #recentDamageEvents, 1, -1 do
        if nowMs - recentDamageEvents[i].at > CONTEXT_WINDOW_MS then
            table.remove(recentDamageEvents, i)
        end
    end
end

local function pushDamageContext(context)
    recentDamageEvents[#recentDamageEvents + 1] = context
    pruneOldContexts(GetGameTimer())
end

local function popLatestContext(nowMs)
    for i = #recentDamageEvents, 1, -1 do
        local context = recentDamageEvents[i]
        if nowMs - context.at <= CONTEXT_WINDOW_MS then
            table.remove(recentDamageEvents, i)
            return context
        end
    end
    return nil
end

local function formatDamageMessage(context, damage, currentHealth)
    local location = context.location or "Body"
    local suffix = ""
    if SHOW_HEALTH then
        suffix = (" ((Health: %d))"):format(math.max(0, currentHealth))
    end

    if context.category == "firearm" then
        return ("You've been shot in the %s with %s for %d damage.%s"):format(location, context.detail or "a firearm round", damage, suffix)
    end

    if context.category == "melee" then
        local meleeType = context.detail or "blunt"
        return ("You've been struck in the %s with a %s melee attack for %d damage.%s"):format(location, meleeType, damage, suffix)
    end

    if context.category == "vehicle" then
        return ("You've been hit in the %s by a vehicle impact for %d damage.%s"):format(location, damage, suffix)
    end

    if context.category == "fall" then
        return ("You've been injured in the %s from a fall for %d damage.%s"):format(location, damage, suffix)
    end

    if context.category == "explosion" then
        return ("You've been blasted in the %s by an explosion for %d damage.%s"):format(location, damage, suffix)
    end

    if context.category == "fire" then
        return ("You've been burned in the %s for %d damage.%s"):format(location, damage, suffix)
    end

    if context.category == "drowning" then
        return ("You're drowning and taking %d damage.%s"):format(damage, suffix)
    end

    return ("You've taken %d damage in the %s from an unknown source.%s"):format(damage, location, suffix)
end

local function sendVictimMessage(context, damage, health)
    local nowMs = GetGameTimer()
    if nowMs - lastMessageAt < THROTTLE_MS then
        return
    end

    local message = formatDamageMessage(context, damage, health)
    local signature = ("%s|%s|%s|%d|%d"):format(
        context.category or "unknown",
        context.detail or "",
        context.location or "Body",
        damage,
        health
    )

    if signature == lastMessageSignature and (nowMs - lastMessageSignatureAt) < DEDUPE_WINDOW_MS then
        return
    end

    TriggerEvent("chat:addMessage", {
        color = CHAT_COLOR,
        multiline = false,
        args = { message }
    })

    lastMessageAt = nowMs
    lastMessageSignature = signature
    lastMessageSignatureAt = nowMs
end

local function emitDamageImpact(context, damage, health)
    TriggerEvent("tcp_core:client:damageImpact", {
        category = context.category or "unknown",
        detail = context.detail,
        location = context.location or "Body",
        damage = damage,
        health = health
    })
end

AddEventHandler("gameEventTriggered", function(name, args)
    if name ~= "CEventNetworkEntityDamage" then return end

    local victim = args[1]
    local playerPed = PlayerPedId()
    if victim ~= playerPed then return end

    local attacker = args[2]
    local weaponHash = tonumber(args[7]) or 0
    local category, detail = classifyDamage(weaponHash, attacker, playerPed)

    pushDamageContext({
        at = GetGameTimer(),
        category = category,
        detail = detail,
        location = getBoneLabel(playerPed)
    })
end)

CreateThread(function()
    while true do
        Wait(75)

        local ped = PlayerPedId()
        if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
            lastKnownHealth = nil
            recentDamageEvents = {}
        else
            local health = GetEntityHealth(ped)
            if health <= 0 then
                lastKnownHealth = nil
                recentDamageEvents = {}
            elseif not lastKnownHealth then
                lastKnownHealth = health
            elseif health > lastKnownHealth then
                lastKnownHealth = health
            elseif health < lastKnownHealth then
                local damage = lastKnownHealth - health
                lastKnownHealth = health

                if damage > 0 then
                    local nowMs = GetGameTimer()
                    pruneOldContexts(nowMs)

                    local context = popLatestContext(nowMs)
                    if not context then
                        local fallbackCategory, fallbackDetail = inferFallbackCategory(ped)
                        context = {
                            at = nowMs,
                            category = fallbackCategory,
                            detail = fallbackDetail,
                            location = getBoneLabel(ped)
                        }
                    end

                    emitDamageImpact(context, damage, health)

                    if damage >= MIN_DAMAGE then
                        sendVictimMessage(context, damage, health)
                    end
                end
            end
        end
    end
end)
