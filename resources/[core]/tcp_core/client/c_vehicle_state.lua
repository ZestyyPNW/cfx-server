-- Vehicle State Preservation Script
-- Keeps the exit door open and preserves steering angle when player exits vehicle
-- Only prevents door closing if player HOLDS F key to exit (not just presses it)

local lastVehicle = nil
local lastSeat = nil
local exitDoor = nil
local steeringAngle = nil
local vehicleStates = {} -- Track state for multiple vehicles
local isHoldingExit = false -- Track if player is holding F key
local exitHoldStartTime = 0 -- When player started holding F
local wasHoldingOnExit = false -- Track if player was holding F when they exited
local EXIT_HOLD_THRESHOLD = 200 -- Minimum milliseconds to hold F to trigger door preservation

-- Function to get door number from seat index
-- -1 = Driver, 0 = Front Right, 1 = Rear Left, 2 = Rear Right
local function getDoorFromSeat(seatIndex)
    if seatIndex == -1 then
        return 0 -- Driver = Front Left
    elseif seatIndex == 0 then
        return 1 -- Front Right
    elseif seatIndex == 1 then
        return 2 -- Rear Left
    elseif seatIndex == 2 then
        return 3 -- Rear Right
    end
    return nil
end

-- Function to find closest door to player position
local function getClosestDoor(vehicle, pedCoords)
    if not DoesEntityExist(vehicle) then
        return nil
    end
    
    local minDistance = math.huge
    local closestDoor = nil
    
    -- Door bone names to try for each door
    local doorBoneNames = {
        [0] = {"door_dside_f", "seat_dside_f"}, -- Front Left
        [1] = {"door_pside_f", "seat_pside_f"}, -- Front Right
        [2] = {"door_dside_r", "seat_dside_r"}, -- Rear Left
        [3] = {"door_pside_r", "seat_pside_r"}  -- Rear Right
    }
    
    -- Check each door (0-3 for passenger doors)
    for door = 0, 3 do
        local doorCoords = nil
        
        -- Try door bone first, then seat bone as fallback
        for _, boneName in ipairs(doorBoneNames[door]) do
            local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
            if boneIndex ~= -1 then
                doorCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
                break
            end
        end
        
        if doorCoords then
            local distance = #(pedCoords - doorCoords)
            
            if distance < minDistance then
                minDistance = distance
                closestDoor = door
            end
        end
    end
    
    return closestDoor
end

-- Thread to detect F key hold
Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local currentVehicle = GetVehiclePedIsIn(ped, false)
        
        if currentVehicle ~= 0 then
            -- Check if player is holding F key (control 23 = exit vehicle)
            if IsControlPressed(0, 23) then
                if not isHoldingExit then
                    -- Just started holding
                    isHoldingExit = true
                    exitHoldStartTime = GetGameTimer()
                end
            else
                -- Not holding F anymore
                isHoldingExit = false
                exitHoldStartTime = 0
            end
        else
            -- Not in vehicle, reset
            isHoldingExit = false
            exitHoldStartTime = 0
        end
        
        Citizen.Wait(0)
    end
end)

-- Thread to monitor vehicle entry/exit
Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local currentVehicle = GetVehiclePedIsIn(ped, false)
        local currentSeat = nil
        
        if currentVehicle ~= 0 then
            -- Player is in a vehicle, get their seat
            for seat = -1, 3 do
                if GetPedInVehicleSeat(currentVehicle, seat) == ped then
                    currentSeat = seat
                    break
                end
            end
            
            -- If player just entered a vehicle (wasn't in one before)
            if not lastVehicle or lastVehicle ~= currentVehicle then
                -- Close any preserved door on this vehicle and remove from tracking
                if vehicleStates[currentVehicle] and vehicleStates[currentVehicle].door then
                    SetVehicleDoorShut(currentVehicle, vehicleStates[currentVehicle].door, false)
                    vehicleStates[currentVehicle] = nil
                end
            end
            
            -- If we have a last vehicle and it's different, player switched vehicles
            if lastVehicle and lastVehicle ~= currentVehicle and DoesEntityExist(lastVehicle) then
                -- Player switched vehicles, preserve state of old vehicle only if F was held
                if wasHoldingOnExit then
                    local finalSteering = GetVehicleSteeringAngle(lastVehicle)
                    if exitDoor then
                        SetVehicleDoorOpen(lastVehicle, exitDoor, false, false)
                    end
                    if finalSteering then
                        vehicleStates[lastVehicle] = {
                            steering = finalSteering,
                            door = exitDoor
                        }
                    end
                end
                -- Reset for new vehicle
                wasHoldingOnExit = false
            end
            
            -- Track current vehicle and seat
            lastVehicle = currentVehicle
            lastSeat = currentSeat
            
            -- Save steering angle while in vehicle (update continuously)
            if currentVehicle ~= 0 then
                steeringAngle = GetVehicleSteeringAngle(currentVehicle)
            end
            
            -- Check if player is holding F and has held it long enough
            if isHoldingExit and exitHoldStartTime > 0 then
                local heldTime = GetGameTimer() - exitHoldStartTime
                if heldTime >= EXIT_HOLD_THRESHOLD then
                    wasHoldingOnExit = true
                end
            else
                wasHoldingOnExit = false
            end
        else
            -- Player is not in a vehicle
            if lastVehicle and DoesEntityExist(lastVehicle) then
                -- Check if player was holding F key when they exited
                -- Use the stored state from when they were still in the vehicle
                local shouldPreserveDoor = wasHoldingOnExit
                
                -- Player just exited, preserve state only if F was held
                if shouldPreserveDoor then
                    local pedCoords = GetEntityCoords(ped)
                    
                    -- Get final steering angle before exit
                    local finalSteering = GetVehicleSteeringAngle(lastVehicle)
                    
                    -- Determine exit door
                    if lastSeat then
                        exitDoor = getDoorFromSeat(lastSeat)
                    end
                    
                    -- If we couldn't determine from seat, use closest door
                    if not exitDoor then
                        exitDoor = getClosestDoor(lastVehicle, pedCoords)
                    end
                    
                    -- Save state for this vehicle
                    if finalSteering then
                        vehicleStates[lastVehicle] = {
                            steering = finalSteering,
                            door = exitDoor
                        }
                    end
                    
                    -- Open the exit door immediately
                    if exitDoor then
                        SetVehicleDoorOpen(lastVehicle, exitDoor, false, false)
                    end
                end
            end
            
            lastVehicle = nil
            lastSeat = nil
            exitDoor = nil
            steeringAngle = nil
            isHoldingExit = false
            exitHoldStartTime = 0
            wasHoldingOnExit = false
        end
        
        Citizen.Wait(50)
    end
end)

-- Thread to maintain vehicle states (steering angle and door)
Citizen.CreateThread(function()
    while true do
        -- Maintain steering angles and doors for vehicles
        for vehicle, state in pairs(vehicleStates) do
            if DoesEntityExist(vehicle) then
                -- Check if vehicle is empty (no one inside)
                local isEmpty = true
                for seat = -1, 3 do
                    if GetPedInVehicleSeat(vehicle, seat) ~= 0 then
                        isEmpty = false
                        break
                    end
                end
                
                if isEmpty then
                    -- Maintain steering angle (continuously apply it)
                    if state.steering then
                        SetVehicleSteeringAngle(vehicle, state.steering)
                    end
                    
                    -- Maintain door state (keep it open)
                    if state.door then
                        local doorAngle = GetVehicleDoorAngleRatio(vehicle, state.door)
                        if doorAngle < 0.1 then
                            -- Door closed, reopen it
                            SetVehicleDoorOpen(vehicle, state.door, false, false)
                        end
                    end
                else
                    -- Someone got in, close the door and remove from tracking
                    if state.door then
                        SetVehicleDoorShut(vehicle, state.door, false)
                    end
                    vehicleStates[vehicle] = nil
                end
            else
                -- Vehicle no longer exists, remove from tracking
                vehicleStates[vehicle] = nil
            end
        end
        
        Citizen.Wait(0)
    end
end)

-- Clean up vehicle states when vehicle is deleted
AddEventHandler('entityRemoved', function(entity)
    if vehicleStates[entity] then
        vehicleStates[entity] = nil
    end
end)
