walkingBackwards = 0

function ClearPossibleActiveEmotes(playerPed)
    StopAnimTask(playerPed, "move_strafe@first_person@generic", "walk_bwd_135_loop", 2.0)
    StopAnimTask(playerPed, "move_strafe@first_person@generic", "walk_bwd_-135_loop", 2.0)
    StopAnimTask(playerPed, "move_strafe@first_person@generic", "walk_bwd_180_loop", 2.0)
    StopAnimTask(playerPed, "move_strafe@first_person@generic", "walk_bwd_-90_loop", 2.0)
    StopAnimTask(playerPed, "move_strafe@first_person@generic", "walk_fwd_90_loop", 2.0)
end
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped, false) == false then

    if IsControlPressed(0, 33) and IsControlPressed(0, 32) then

        if IsControlPressed(0, 35) and walkingBackwards ~= 2 then
            TaskPlayAnim(ped, "move_strafe@first_person@generic", "walk_bwd_135_loop", 5.0, 1.0, -1, 1, 0.1)
            walkingBackwards = 2

        elseif IsControlPressed(0, 34) and walkingBackwards ~= 3 then
            TaskPlayAnim(ped, "move_strafe@first_person@generic", "walk_bwd_-135_loop", 5.0, 1.0, -1, 1, 0.1)
            walkingBackwards = 3

        elseif not (IsControlPressed(0, 34) or IsControlPressed(0, 35)) and walkingBackwards ~= 1 then
            TaskPlayAnim(ped, "move_strafe@first_person@generic", "walk_bwd_180_loop", 5.0, 1.0, -1, 1, 0.1)
            walkingBackwards = 1
        end
        

    elseif not IsControlPressed(0, 33) or not IsControlPressed(0, 32) then
        if walkingBackwards > 0 then
            ClearPossibleActiveEmotes(ped)
            walkingBackwards = 0
        end
    end
end
end
end)
