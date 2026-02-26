CreateThread(function()
while true do
Wait(0)
local vehicles = GetGamePool("CVehicle")
for _, v in pairs(vehicles) do
    if GetVehicleClass(v) == 18 and IsVehicleSirenOn(v) then
    local speed = GetEntitySpeed(v) * 2.236936
    local x, y, z = table.unpack(GetEntityCoords(v))

                if GetVehicleMod(v, 42) == 2 then
                    speedZone = AddSpeedZoneForCoord(x, y, z, 75.0, 0.000000000001, false)
                    speedZone2 = AddSpeedZoneForCoord(x, y, z, 100.0, 3.0, false)
                    Citizen.Wait(0)
                    RemoveSpeedZone(speedZone)
                    RemoveSpeedZone(speedZone2)
                elseif GetVehicleMod(v, 42) == 1 then
                    speedZone = AddSpeedZoneForCoord(x, y, z, 75.0, 3.0, false)
                    Citizen.Wait(0)
                    RemoveSpeedZone(speedZone)
                elseif speed > 20 then
                    speedZone = AddSpeedZoneForCoord(x, y, z, 75.0, 0.000000000001, false)
                    speedZone2 = AddSpeedZoneForCoord(x, y, z, 100.0, 3.0, false)
                    Citizen.Wait(0)
                    RemoveSpeedZone(speedZone)
                    RemoveSpeedZone(speedZone2)
                else
                    speedZone = AddSpeedZoneForCoord(x, y, z, 75.0, 3.0, false)
                    Citizen.Wait(0)
                    RemoveSpeedZone(speedZone)
                end
            end
        end
    end
end)
