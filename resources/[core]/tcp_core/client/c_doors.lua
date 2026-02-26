-- Door Control Script
-- Allows players to open/close vehicle doors using /door <number>
-- Door numbers: 1 = Front Left, 2 = Front Right, 3 = Rear Left, 4 = Rear Right, 5 = Hood, 6 = Trunk

RegisterCommand("door", function(source, args)
    local ped = PlayerPedId()
    
    -- Check if player is in a vehicle
    if not IsPedInAnyVehicle(ped, false) then
        TriggerEvent("tcp_notify:show", "Door: You must be in a vehicle.", 3000)
        return
    end
    
    -- Get the vehicle
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if not DoesEntityExist(vehicle) then
        return
    end
    
    -- Check if door number was provided
    if not args[1] then
        TriggerEvent("tcp_notify:show", "Door: Usage: /door <1-6>", 4000)
        return
    end
    
    -- Parse door number
    local userDoorNum = tonumber(args[1])
    
    -- Validate door number (1-6)
    if userDoorNum == nil or userDoorNum < 1 or userDoorNum > 6 then
        TriggerEvent("tcp_notify:show", "Door: Invalid door number. Use 1-6.", 4000)
        return
    end
    
    -- Map user door number to GTA door number (subtract 1)
    -- 1 -> 0 (Front Left), 2 -> 1 (Front Right), 3 -> 2 (Rear Left), 4 -> 3 (Rear Right), 5 -> 4 (Hood), 6 -> 5 (Trunk)
    local doorNum = userDoorNum - 1
    
    -- Check door state using angle ratio (0.0 = closed, > 0.0 = open)
    local doorAngle = GetVehicleDoorAngleRatio(vehicle, doorNum)
    
    if doorAngle < 0.1 then
        -- Door is closed, open it
        SetVehicleDoorOpen(vehicle, doorNum, false, false)
        TriggerEvent("tcp_notify:show", "Door " .. userDoorNum .. " opened.", 2000)
    else
        -- Door is open, close it
        SetVehicleDoorShut(vehicle, doorNum, false)
        TriggerEvent("tcp_notify:show", "Door " .. userDoorNum .. " closed.", 2000)
    end
end, false)
