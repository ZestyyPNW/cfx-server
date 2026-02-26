local injuryConfig = (config and config.injuryEffects) or {}
if injuryConfig.enabled == false then
    return
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function toNumber(value, fallback)
    local parsed = tonumber(value)
    if parsed == nil then return fallback end
    return parsed
end

local MIN_IMPACT_DAMAGE = math.max(1, toNumber(injuryConfig.minImpactDamage, 3))
local MAX_SEVERITY = math.max(10, toNumber(injuryConfig.maxSeverity, 100))
local DECAY_INTERVAL_MS = math.max(250, toNumber(injuryConfig.decayIntervalMs, 1000))
local DECAY_PER_TICK = math.max(0, toNumber(injuryConfig.decayPerTick, 1.5))
local MIN_REGEN_MULTIPLIER = clamp(toNumber(injuryConfig.minHealthRegenMultiplier, 0.2), 0.0, 1.0)

local LEG_LIMP_THRESHOLD = clamp(toNumber(injuryConfig.legLimpThreshold, 24), 1, MAX_SEVERITY)
local LEG_NO_SPRINT_THRESHOLD = clamp(toNumber(injuryConfig.legNoSprintThreshold, 58), LEG_LIMP_THRESHOLD, MAX_SEVERITY)
local ARM_RECOIL_THRESHOLD = clamp(toNumber(injuryConfig.armRecoilThreshold, 20), 1, MAX_SEVERITY)
local CHEST_SHAKE_THRESHOLD = clamp(toNumber(injuryConfig.chestShakeThreshold, 32), 1, MAX_SEVERITY)
local HEAD_BLUR_THRESHOLD = clamp(toNumber(injuryConfig.headBlurThreshold, 38), 1, MAX_SEVERITY)

local locationWeight = type(injuryConfig.locationWeight) == "table" and injuryConfig.locationWeight or {}
local categoryMultiplier = type(injuryConfig.categoryMultiplier) == "table" and injuryConfig.categoryMultiplier or {}

local injuryState = {
    head = 0.0,
    chest = 0.0,
    arm = 0.0,
    leg = 0.0,
    total = 0.0
}

local INJURED_CLIPSET = "move_m@injured"
local clipsetApplied = false
local blurActive = false
local lastChestShakeAt = 0

local function recalcTotal()
    injuryState.total = clamp(injuryState.head + injuryState.chest + injuryState.arm + injuryState.leg, 0.0, MAX_SEVERITY)
end

local function resetInjuryState()
    injuryState.head = 0.0
    injuryState.chest = 0.0
    injuryState.arm = 0.0
    injuryState.leg = 0.0
    injuryState.total = 0.0
end

local function cleanupVisualEffects()
    local ped = PlayerPedId()
    if clipsetApplied and ped ~= 0 and DoesEntityExist(ped) then
        ResetPedMovementClipset(ped, 0.25)
        clipsetApplied = false
    end

    if blurActive then
        ClearTimecycleModifier()
        blurActive = false
    end

    StopGameplayCamShaking(true)
    SetPlayerHealthRechargeMultiplier(PlayerId(), 1.0)
end

local function resolveBucket(location)
    local normalized = string.lower(tostring(location or "body"))
    if normalized:find("head", 1, true) or normalized:find("neck", 1, true) then
        return "head"
    end
    if normalized:find("arm", 1, true) or normalized:find("hand", 1, true) or normalized:find("finger", 1, true) or normalized:find("forearm", 1, true) then
        return "arm"
    end
    if normalized:find("leg", 1, true) or normalized:find("foot", 1, true) then
        return "leg"
    end
    return "chest"
end

local function resolveLocationWeight(location)
    local exact = tonumber(locationWeight[location or ""])
    if exact then return exact end
    return 1.0
end

local function resolveCategoryMultiplier(category)
    local exact = tonumber(categoryMultiplier[category or "unknown"])
    if exact then return exact end
    return 1.0
end

local function addInjury(bucket, amount)
    injuryState[bucket] = clamp(injuryState[bucket] + amount, 0.0, MAX_SEVERITY)
    recalcTotal()
end

local function ensureInjuredClipset()
    if HasAnimSetLoaded(INJURED_CLIPSET) then return true end
    RequestAnimSet(INJURED_CLIPSET)
    local timeout = GetGameTimer() + 1500
    while not HasAnimSetLoaded(INJURED_CLIPSET) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimSetLoaded(INJURED_CLIPSET)
end

RegisterNetEvent("tcp_core:client:damageImpact", function(payload)
    if type(payload) ~= "table" then return end

    local damage = toNumber(payload.damage, 0)
    if damage < MIN_IMPACT_DAMAGE then return end

    local location = tostring(payload.location or "Body")
    local category = tostring(payload.category or "unknown")
    local bucket = resolveBucket(location)

    local severityGain = damage * resolveLocationWeight(location) * resolveCategoryMultiplier(category)
    if severityGain <= 0 then return end

    addInjury(bucket, severityGain)
end)

RegisterNetEvent("tcp_core:client:clearInjuries", function()
    resetInjuryState()
    cleanupVisualEffects()
end)

CreateThread(function()
    while true do
        Wait(DECAY_INTERVAL_MS)
        if injuryState.total <= 0.0 then goto continue end

        injuryState.head = math.max(0.0, injuryState.head - DECAY_PER_TICK)
        injuryState.chest = math.max(0.0, injuryState.chest - DECAY_PER_TICK)
        injuryState.arm = math.max(0.0, injuryState.arm - DECAY_PER_TICK)
        injuryState.leg = math.max(0.0, injuryState.leg - DECAY_PER_TICK)
        recalcTotal()

        ::continue::
    end
end)

CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()
        if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
            cleanupVisualEffects()
            goto continue
        end

        local severityRatio = clamp(injuryState.total / MAX_SEVERITY, 0.0, 1.0)
        local regenMultiplier = 1.0 - (severityRatio * (1.0 - MIN_REGEN_MULTIPLIER))
        SetPlayerHealthRechargeMultiplier(PlayerId(), regenMultiplier)

        if injuryState.leg >= LEG_LIMP_THRESHOLD and ensureInjuredClipset() then
            SetPedMovementClipset(ped, INJURED_CLIPSET, 0.25)
            clipsetApplied = true
        elseif clipsetApplied then
            ResetPedMovementClipset(ped, 0.25)
            clipsetApplied = false
        end

        if injuryState.leg >= LEG_NO_SPRINT_THRESHOLD then
            DisableControlAction(0, 21, true)
        end

        if injuryState.arm >= ARM_RECOIL_THRESHOLD and IsPedArmed(ped, 4) and IsPedShooting(ped) then
            local scale = clamp((injuryState.arm - ARM_RECOIL_THRESHOLD) / math.max(1.0, (MAX_SEVERITY - ARM_RECOIL_THRESHOLD)), 0.1, 1.0)
            local pitchKick = 0.15 + (0.20 * scale)
            local headingKick = ((math.random() * 2.0) - 1.0) * (0.20 * scale)
            SetGameplayCamRelativePitch(GetGameplayCamRelativePitch() + pitchKick, 0.8)
            SetGameplayCamRelativeHeading(GetGameplayCamRelativeHeading() + headingKick)
        end

        local nowMs = GetGameTimer()
        if injuryState.chest >= CHEST_SHAKE_THRESHOLD and (nowMs - lastChestShakeAt) >= 1100 then
            local shakeScale = clamp((injuryState.chest - CHEST_SHAKE_THRESHOLD) / math.max(1.0, (MAX_SEVERITY - CHEST_SHAKE_THRESHOLD)), 0.0, 1.0)
            local intensity = 0.06 + (0.30 * shakeScale)
            ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", intensity)
            lastChestShakeAt = nowMs
        end

        if injuryState.head >= HEAD_BLUR_THRESHOLD then
            local blurScale = clamp((injuryState.head - HEAD_BLUR_THRESHOLD) / math.max(1.0, (MAX_SEVERITY - HEAD_BLUR_THRESHOLD)), 0.0, 1.0)
            if not blurActive then
                SetTimecycleModifier("damage")
                blurActive = true
            end
            SetTimecycleModifierStrength(0.12 + (0.45 * blurScale))
        elseif blurActive then
            ClearTimecycleModifier()
            blurActive = false
        end

        ::continue::
    end
end)

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    cleanupVisualEffects()
end)
