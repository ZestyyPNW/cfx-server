local wasAiming = false
local savedViewMode = nil

Citizen.CreateThread(function()
    while true do
        local isAiming = IsPlayerFreeAiming(PlayerId())

        if isAiming and not wasAiming then
            savedViewMode = GetFollowPedCamViewMode()
            SetFollowPedCamViewMode(4)
            wasAiming = true

        elseif not isAiming and wasAiming then
            SetFollowPedCamViewMode(savedViewMode or 1)
            savedViewMode = nil
            wasAiming = false
        end

        Citizen.Wait(0)
    end
end)
