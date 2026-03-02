local wasAiming = false
local transitionCam = nil
local LERP_SPEED = 8.0

local function destroyCam()
    if transitionCam then
        RenderScriptCams(false, true, 200, true, false)
        DestroyCam(transitionCam, false)
        transitionCam = nil
    end
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpVec(a, b, t)
    return vector3(lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t))
end

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local isAiming = IsPlayerFreeAiming(PlayerId())

        if isAiming and not wasAiming then
            wasAiming = true

            destroyCam()

            local gameplayCam = GetGameplayCamCoord()
            local gameplayRot = GetGameplayCamRot(2)

            transitionCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
            SetCamCoord(transitionCam, gameplayCam.x, gameplayCam.y, gameplayCam.z)
            SetCamRot(transitionCam, gameplayRot.x, gameplayRot.y, gameplayRot.z, 2)
            SetCamFov(transitionCam, GetGameplayCamFov())
            SetCamActive(transitionCam, true)
            RenderScriptCams(true, false, 0, true, false)

            local t = 0.0
            while isAiming and t < 1.0 do
                local dt = GetFrameTime()
                t = t + dt * LERP_SPEED
                if t > 1.0 then t = 1.0 end

                local headPos = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
                local camRot = GetGameplayCamRot(2)
                local currentPos = GetCamCoord(transitionCam)

                local newPos = lerpVec(currentPos, headPos, t)
                SetCamCoord(transitionCam, newPos.x, newPos.y, newPos.z)
                SetCamRot(transitionCam, camRot.x, camRot.y, camRot.z, 2)
                SetCamFov(transitionCam, GetGameplayCamFov())

                Citizen.Wait(0)
                isAiming = IsPlayerFreeAiming(PlayerId())
            end

            if isAiming then
                destroyCam()
                SetFollowPedCamViewMode(4)

                while IsPlayerFreeAiming(PlayerId()) do
                    Citizen.Wait(0)
                end
            end

            SetFollowPedCamViewMode(1)
            wasAiming = false
            destroyCam()

        end

        Citizen.Wait(isAiming and 0 or 200)
    end
end)
