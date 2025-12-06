-- NUI-based HUD overlay: shows street and cross street near the minimap

CreateThread(function()
    local lastStreet = ''
    local lastCity = ''
    local lastNeighborhood = ''
    local lastCompass = ''
    local lastAhead = ''
    local displayText = ''
    local showApproaching = false
    local alpha = 0
    local fadeSpeed = 10
    local showFrames = 120
    local holdCounter = 0

    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local streetName = GetStreetNameFromHashKey(streetHash)
        local crossName = crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or ''

        local label = streetName or ''
        if crossName and crossName ~= '' then
            label = string.format('%s x %s', label, crossName)
        end

        -- Zone info
        local zoneCode = GetNameOfZone(coords.x, coords.y, coords.z)
        local zoneLabel = zoneCode and GetLabelText(zoneCode) or ''
        if zoneLabel == nil or zoneLabel == '' or zoneLabel == zoneCode then
            zoneLabel = zoneCode or 'Unknown'
        end
        local cityText = 'City: N/A'
        local neighborhoodText = string.format('Neighborhood: %s', zoneLabel)

        -- Compass
        local heading = GetEntityHeading(ped)
        local directions = { 'N', 'E', 'S', 'W' }
        local index = math.floor((heading + 45.0) / 90.0) % 4 + 1
        local dirText = directions[index] or 'N'

        -- Only update NUI if something changed
        if label ~= lastStreet or cityText ~= lastCity or neighborhoodText ~= lastNeighborhood or dirText ~= lastCompass then
            SendNUIMessage({
                type = 'updateHud',
                compass = dirText,
                street = label,
                city = cityText,
                neighborhood = neighborhoodText
            })
            lastStreet = label
            lastCity = cityText
            lastNeighborhood = neighborhoodText
            lastCompass = dirText
        end

        -- Approaching street logic
        local aheadPos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 120.0, 0.0)
        local aheadStreetHash, _ = GetStreetNameAtCoord(aheadPos.x, aheadPos.y, aheadPos.z)
        local aheadStreet = aheadStreetHash ~= 0 and GetStreetNameFromHashKey(aheadStreetHash) or ''

        local shouldShowBox = IsPedInAnyVehicle(ped, false) and aheadStreet ~= '' and aheadStreet ~= streetName

        if shouldShowBox then
            if aheadStreet ~= lastAhead then
                lastAhead = aheadStreet
                displayText = string.format('Approaching: %s', aheadStreet)
                alpha = 0
                holdCounter = showFrames
            else
                holdCounter = showFrames
            end
            if alpha < 200 then
                alpha = math.min(200, alpha + fadeSpeed)
            end
        else
            if holdCounter > 0 then
                holdCounter = holdCounter - 1
            else
                alpha = math.max(0, alpha - fadeSpeed)
            end
        end

        local shouldShow = alpha > 0 and displayText ~= ''
        if shouldShow ~= showApproaching then
            SendNUIMessage({
                type = 'updateApproaching',
                show = shouldShow,
                text = displayText
            })
            showApproaching = shouldShow
        end

        Wait(100)
    end
end)
