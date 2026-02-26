-- Footstep Sounds Client Script
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsPedOnFoot(PlayerPedId()) and not IsPedDeadOrDying(PlayerPedId()) then
            local speed = GetEntitySpeed(PlayerPedId())
            if speed > 0.1 then
                -- Play footstep sound
                PlaySoundFromEntity(-1, "footstep", PlayerPedId(), "feet_materials", 0, 0)
                Citizen.Wait(300) -- Adjust delay based on speed
            end
        end
    end
end)