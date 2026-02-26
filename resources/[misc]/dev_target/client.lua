local devEnabled = false

local function drawText(x, y, text)
  SetTextFont(4)
  SetTextScale(0.35, 0.35)
  SetTextColour(255, 255, 255, 220)
  SetTextOutline()
  SetTextEntry("STRING")
  AddTextComponentString(text)
  DrawText(x, y)
end

local function notify(message)
  TriggerEvent('chat:addMessage', {
    color = {0, 200, 255},
    args = {'DEV', message}
  })
end

local function vecToString(coords)
  if not coords then return 'n/a' end
  return ('%.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z)
end

local function vec3String(coords)
  if not coords then return 'n/a' end
  return ('vec3(%.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z)
end

local function vec4String(coords, heading)
  if not coords then return 'n/a' end
  heading = heading or 0.0
  return ('vec4(%.2f, %.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z, heading)
end

local function rotationToDirection(rotation)
  local rotZ = math.rad(rotation.z)
  local rotX = math.rad(rotation.x)
  local cosX = math.abs(math.cos(rotX))
  return {
    x = -math.sin(rotZ) * cosX,
    y = math.cos(rotZ) * cosX,
    z = math.sin(rotX)
  }
end

local function getAimCoords(distance)
  local camCoords = GetGameplayCamCoord()
  local camRot = GetGameplayCamRot(2)
  local direction = rotationToDirection(camRot)
  local dest = vector3(
    camCoords.x + direction.x * distance,
    camCoords.y + direction.y * distance,
    camCoords.z + direction.z * distance
  )
  local ray = StartShapeTestRay(
    camCoords.x, camCoords.y, camCoords.z,
    dest.x, dest.y, dest.z,
    -1,
    PlayerPedId(),
    0
  )
  local _, hit, endCoords = GetShapeTestResult(ray)
  if hit == 1 and endCoords then
    return endCoords
  end
  return dest
end

local function copyText(label, text)
  local ok
  if lib and lib.setClipboard then
    ok = lib.setClipboard(text)
  end
  if ok == false then
    notify(label .. ' copy failed. Check F8 log for JSON.')
  else
    notify(label .. ' copied.')
  end
end

local function safeCall(fn, ...)
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

local function safeSelect(fn)
  return function(data)
    local ok, err = pcall(fn, data)
    if not ok then
      print(('[dev_target] onSelect error: %s'):format(err))
      notify('Dev target error. Check F8 log.')
    end
  end
end

local function buildCopyText(info, coords)
  local lines = {}
  local typeName = info.type == 1 and 'ped' or info.type == 2 and 'vehicle' or info.type == 3 and 'object' or 'unknown'
  lines[#lines + 1] = ('type: %s'):format(typeName)
  lines[#lines + 1] = ('coords: %s'):format(vecToString(coords or info.coords))
  lines[#lines + 1] = ('model: %s'):format(info.model or 'n/a')
  if info.netId then
    lines[#lines + 1] = ('netId: %s'):format(info.netId)
  end
  if info.heading then
    lines[#lines + 1] = ('heading: %.2f'):format(info.heading)
  end
  if info.vehicle then
    lines[#lines + 1] = ('vehicle: %s'):format(info.displayName or 'n/a')
    lines[#lines + 1] = ('plate: %s'):format(info.plate or 'n/a')
  end
  if info.isPlayer then
    lines[#lines + 1] = ('player: %s (%s)'):format(info.playerName or 'n/a', info.serverId or 'n/a')
  end
  return table.concat(lines, '\n')
end

local function getEntityInfo(entity)
  if type(entity) ~= 'number' or entity <= 0 or not DoesEntityExist(entity) then
    return { type = 'none' }
  end

  local entityType = safeCall(GetEntityType, entity) or 0
  local model = safeCall(GetEntityModel, entity)
  local coords = safeCall(GetEntityCoords, entity)
  local heading = safeCall(GetEntityHeading, entity)
  local netId = safeCall(NetworkGetEntityIsNetworked, entity) and safeCall(NetworkGetNetworkIdFromEntity, entity) or nil
  local info = {
    model = model,
    coords = coords,
    heading = heading,
    netId = netId,
  }

  if entityType == 1 then
    info.ped = true
    info.isPlayer = safeCall(IsPedAPlayer, entity)
    if info.isPlayer then
      local player = safeCall(NetworkGetPlayerIndexFromPed, entity)
      info.playerId = player
      info.serverId = player and safeCall(GetPlayerServerId, player) or nil
      info.playerName = player and safeCall(GetPlayerName, player) or nil
    end
  elseif entityType == 2 then
    info.vehicle = true
    info.displayName = model and safeCall(GetDisplayNameFromVehicleModel, model) or nil
    info.plate = safeCall(GetVehicleNumberPlateText, entity)
  elseif entityType == 3 then
    info.object = true
  end

  return info
end

local function inspectTarget(data)
  local coords = data and data.coords or nil
  local entity = data and data.entity or 0
  local info = getEntityInfo(entity)
  local copyText = buildCopyText(info, coords)
  local logCoords = coords or info.coords
  local logCoordsTable = logCoords and { x = logCoords.x, y = logCoords.y, z = logCoords.z } or nil

  local lines = {}
  lines[#lines + 1] = ('Coords: %s'):format(vecToString(coords or info.coords))

  if info.type == 'none' then
    lines[#lines + 1] = 'Type: none'
  else
    local typeName = info.type == 1 and 'ped' or info.type == 2 and 'vehicle' or info.type == 3 and 'object' or 'unknown'
    lines[#lines + 1] = ('Type: %s'):format(typeName)
    lines[#lines + 1] = ('Model: %s'):format(info.model or 'n/a')
    if info.netId then
      lines[#lines + 1] = ('Net ID: %s'):format(info.netId)
    end
    if info.heading then
      lines[#lines + 1] = ('Heading: %.2f'):format(info.heading)
    end
    if info.vehicle then
      lines[#lines + 1] = ('Vehicle: %s'):format(info.displayName or 'n/a')
      lines[#lines + 1] = ('Plate: %s'):format(info.plate or 'n/a')
    end
    if info.isPlayer then
      lines[#lines + 1] = ('Player: %s (%s)'):format(info.playerName or 'n/a', info.serverId or 'n/a')
    end
  end

  for i = 1, #lines do
    notify(lines[i])
  end

  local ok
  if lib and lib.setClipboard then
    ok = lib.setClipboard(copyText)
  end

  print(json.encode({
    coords = logCoordsTable,
    entity = entity,
    info = {
      type = info.type,
      model = info.model,
      netId = info.netId,
      heading = info.heading,
      isPlayer = info.isPlayer,
      serverId = info.serverId,
      playerName = info.playerName,
      vehicle = info.vehicle,
      displayName = info.displayName,
      plate = info.plate
    }
  }, { indent = true }))

  if ok == false then
    notify('Copy failed. Check F8 log for JSON.')
  else
    notify('Copied target info to clipboard.')
  end
end

local function removeTargets()
  local ox = exports.ox_target
  local names = {
    'dev_target_inspect',
    'dev_target_copy_coords',
    'dev_target_copy_vec3',
    'dev_target_copy_vec4',
    'dev_target_copy_aim',
    'dev_target_copy_heading',
    'dev_target_copy_model',
  }
  for i = 1, #names do
    local name = names[i]
    ox:removeGlobalPed(name)
    ox:removeGlobalVehicle(name)
    ox:removeGlobalObject(name)
    ox:removeGlobalPlayer(name)
    ox:removeGlobalOption(name)
  end
end

local function addTargets()
  removeTargets()
  local option = {
    {
      name = 'dev_target_inspect',
      icon = 'fa-solid fa-terminal',
      label = 'Dev Inspect',
      onSelect = safeSelect(inspectTarget)
    },
    {
      name = 'dev_target_copy_coords',
      icon = 'fa-solid fa-location-crosshairs',
      label = 'Copy Coords',
      onSelect = safeSelect(function(data)
        local coords = data and data.coords or nil
        local useCoords = coords
        if not useCoords then
          local entity = data and data.entity or 0
          local info = getEntityInfo(entity)
          useCoords = info.coords
        end
        if not useCoords then
          notify('No coords found.')
          return
        end
        copyText('Coords', vecToString(useCoords))
      end)
    },
    {
      name = 'dev_target_copy_vec3',
      icon = 'fa-solid fa-location-crosshairs',
      label = 'Copy Vec3',
      onSelect = safeSelect(function(data)
        local coords = data and data.coords or nil
        local useCoords = coords
        if not useCoords then
          local entity = data and data.entity or 0
          local info = getEntityInfo(entity)
          useCoords = info.coords
        end
        if not useCoords then
          notify('No coords found.')
          return
        end
        copyText('Vec3', vec3String(useCoords))
      end)
    },
    {
      name = 'dev_target_copy_vec4',
      icon = 'fa-solid fa-location-dot',
      label = 'Copy Vec4',
      onSelect = safeSelect(function(data)
        local coords = data and data.coords or nil
        local entity = data and data.entity or 0
        local useCoords = coords
        local heading = 0.0
        if entity and entity > 0 and DoesEntityExist(entity) then
          local info = getEntityInfo(entity)
          useCoords = useCoords or info.coords
          heading = info.heading or heading
        end
        if not useCoords then
          notify('No coords found.')
          return
        end
        copyText('Vec4', vec4String(useCoords, heading))
      end)
    },
    {
      name = 'dev_target_copy_aim',
      icon = 'fa-solid fa-location-crosshairs',
      label = 'Copy Aim Coords',
      onSelect = safeSelect(function()
        local coords = getAimCoords(200.0)
        copyText('Aim', vec3String(coords))
      end)
    },
    {
      name = 'dev_target_copy_heading',
      icon = 'fa-solid fa-compass',
      label = 'Copy Heading',
      onSelect = safeSelect(function(data)
        local entity = data and data.entity or 0
        local heading = 0.0
        if entity and entity > 0 and DoesEntityExist(entity) then
          local info = getEntityInfo(entity)
          heading = info.heading or heading
        end
        copyText('Heading', ('%.2f'):format(heading))
      end)
    },
    {
      name = 'dev_target_copy_model',
      icon = 'fa-solid fa-cube',
      label = 'Copy Model Hash',
      onSelect = safeSelect(function(data)
        local entity = data and data.entity or 0
        local info = getEntityInfo(entity)
        if not info.model then
          notify('No model found.')
          return
        end
        copyText('Model', tostring(info.model))
      end)
    },
  }

  local ox = exports.ox_target
  ox:addGlobalPed(option)
  ox:addGlobalVehicle(option)
  ox:addGlobalObject(option)
  ox:addGlobalPlayer(option)
  ox:addGlobalOption(option)
end

RegisterCommand('dev', function()
  devEnabled = not devEnabled
  if devEnabled then
    addTargets()
    notify('Dev target enabled.')
  else
    removeTargets()
    notify('Dev target disabled.')
  end
end, false)

RegisterCommand('copycoords', function()
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local heading = GetEntityHeading(ped)
  copyText('Coords+Heading', ('%.2f, %.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z, heading))
end, false)

CreateThread(function()
  while true do
    if devEnabled then
      local ped = PlayerPedId()
      local coords = GetEntityCoords(ped)
      local heading = GetEntityHeading(ped)
      drawText(0.015, 0.55, ('Coords: %.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z))
      drawText(0.015, 0.575, ('Heading: %.2f'):format(heading))
      Wait(0)
    else
      Wait(500)
    end
  end
end)

AddEventHandler('onClientResourceStop', function(resource)
  if resource == GetCurrentResourceName() and devEnabled then
    removeTargets()
  end
end)
