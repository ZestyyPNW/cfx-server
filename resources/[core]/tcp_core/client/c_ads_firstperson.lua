local wasAiming = false
local savedViewMode = nil

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local isAiming = IsPlayerFreeAiming(PlayerId())

        if isAiming and not wasAiming then
            savedViewMode = GetFollowPedCamViewMode()
            if savedViewMode ~= 4 then
                SetFollowPedCamViewMode(4)
            end
            wasAiming = true

        elseif not isAiming and wasAiming then
            if savedViewMode and savedViewMode ~= 4 then
                SetFollowPedCamViewMode(savedViewMode)
            end
            savedViewMode = nil
            wasAiming = false
        end

        Citizen.Wait(isAiming and 0 or 200)
    end
end)
