local function HasAce(source, ace)
	if not source or source == 0 then
		return true
	end
	return IsPlayerAceAllowed(source, ace)
end

lib.callback.register('hud:server:hasAce', function(source, ace)
	return HasAce(source, ace)
end)

local function isAdmin(source)
	-- if not source or source == 0 then
	-- 	return true
	-- end
	-- return HasAce(source, "group.owner") or HasAce(source, "group.administration")
	return true
end

local currentPT = false
local currentAOP = "None Set"
local peacetimeActive = false
local priorityActive = false
local priorityName = nil
local prioritySetter = nil
local priorityStartTime = nil
local lastSyncTime = 0

local function LoadAOPState()
	local data = LoadResourceFile(GetCurrentResourceName(), 'aop_state.json')
	if data then
		local state = json.decode(data)
		if state then
			currentAOP = state.aop or "None Set"
			currentPT = state.peacetime or false
			priorityName = state.priority or nil
			priorityActive = state.priorityActive or false
			prioritySetter = state.prioritySetter or nil
			priorityStartTime = state.priorityStartTime or nil
		end
	end
end

local function SaveAOPState()
	local prioToSave = priorityName
	if not priorityActive or not prioToSave or prioToSave == "" then
		prioToSave = "Normal"
	end
	local state = {
		aop = currentAOP,
		peacetime = currentPT,
		priority = prioToSave,
		priorityActive = priorityActive,
		prioritySetter = prioritySetter,
		priorityStartTime = priorityStartTime
	}
	SaveResourceFile(GetCurrentResourceName(), 'aop_state.json', json.encode(state), #json.encode(state))
end

RegisterNetEvent('hud:server:fetchEnvironment', function()
	local src = source
	if lastSyncTime and (os.time() - lastSyncTime) < 2 then
		return
	end

	local data = LoadResourceFile(GetCurrentResourceName(), 'aop_state.json')
	if data then
		local state = json.decode(data)
		if state then
			currentAOP = state.aop or "None Set"
			currentPT = state.peacetime or false
			priorityName = state.priority or nil
		end
	end
	local prioObj = {
		enabled = priorityName and priorityName ~= "Normal",
		name = priorityName or "Normal"
	}
	TriggerClientEvent('hud:client:env:update', src, currentAOP, currentPT, priorityName)
	TriggerClientEvent('hud:client:aop:update', src,
		{ aop = currentAOP, peacetime = currentPT, priority = prioObj })
end)

LoadAOPState()

local function Notify(source, ...)
	TriggerClientEvent('ox_lib:notify', source, ...)
end

RegisterServerEvent('AOP:Startup')
AddEventHandler('AOP:Startup', function()
	Wait(3000)
	SetMapName("RP : " .. currentAOP)
end)

TriggerEvent("AOP:Startup")

lib.addCommand('aop', {
	help = 'Change the Area of Patrol',
	restricted = false,
}, function(source, args, raw)
	if not isAdmin(source) then
		Notify(source,
			{ description = 'You do not have the required role to use this command.', type = 'error' })
		return
	end

	currentAOP = table.concat(args, " ")
	SaveAOPState()
	TriggerEvent("AOP:Sync")
	SetMapName("RP : " .. currentAOP)
	TriggerClientEvent('hud:client:sound', source)
	Notify(-1, {
		description = "AOP set to " .. currentAOP,
		type = "inform"
	})
end)

RegisterServerEvent('AOP:Sync')
AddEventHandler('AOP:Sync', function()
	local data = LoadResourceFile(GetCurrentResourceName(), 'aop_state.json')
	if data then
		local state = json.decode(data)
		if state then
			currentAOP = state.aop or "None Set"
			currentPT = state.peacetime or false
			priorityName = state.priority or nil
		end
	end
	local prioObj = {
		enabled = priorityName and priorityName ~= "Normal",
		name = priorityName or "Normal"
	}
	TriggerClientEvent('hud:client:env:update', -1, currentAOP, currentPT, priorityName)
	TriggerClientEvent('hud:client:aop:update', -1,
		{ aop = currentAOP, peacetime = currentPT, priority = prioObj })

	lastSyncTime = os.time()
end)

RegisterCommand("pt", function(source, args, rawCommand)
	local hasPermission = isAdmin(source)
	if hasPermission then
		if not currentPT then
			Notify(-1, {
				description = "Peace Time is now in effect!",
				type = "success"
			})
			currentPT = true
			SaveAOPState()
			TriggerClientEvent('hud:client:sound', source)
			TriggerEvent('AOP:Sync')
		else
			Notify(-1, {
				description = "Peace Time is now off.",
				type = "warning"
			})
			currentPT = false
			SaveAOPState()
			TriggerClientEvent('hud:client:sound', source)
			TriggerEvent('AOP:Sync')
		end
	else
		Notify(source, {
			description = "You do not have the required role to use this command.",
			type = "error"
		})
	end
end, false)

RegisterCommand('prio', function(source, args, rawCommand)
	local hasPermission = isAdmin(source)
	if priorityActive then
		if source == prioritySetter or hasPermission then
			priorityActive = false
			local setterName = GetPlayerName(source)
			Notify(-1, {
				description = "Priority disabled by " .. setterName,
				type = "warning"
			})
			priorityName = "Normal"
			prioritySetter = nil
			priorityStartTime = nil
			SaveAOPState()
			TriggerEvent('AOP:Sync')
			TriggerClientEvent('hud:client:sound', source)
		else
			Notify(source, {
				description = "You do not have permission to cancel priority.",
				type = "error"
			})
		end
	else
		priorityName = GetPlayerName(source)
		prioritySetter = source
		priorityStartTime = os.time()
		priorityActive = true
		local setterName = GetPlayerName(source)
		Notify(-1, {
			description = "Priority set by " .. setterName,
			type = "success"
		})
		TriggerClientEvent('hud:client:sound', source)
		SaveAOPState()
		TriggerEvent('AOP:Sync')
	end
end, false)

local priorityTimeout = 900

CreateThread(function()
	while true do
		Wait(60000)
		if priorityActive and priorityStartTime and (os.time() - priorityStartTime) >= priorityTimeout then
			priorityActive = false
			Notify(-1, {
				description = "Priority has timed out and is now open.",
				type = "warning"
			})
			priorityName = "Normal"
			prioritySetter = nil
			priorityStartTime = nil
			SaveAOPState()
			TriggerEvent('AOP:Sync')
		end
	end
end)

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
	local src = source
	LoadAOPState()
	local prioObj = {
		enabled = priorityName and priorityName ~= "Normal",
		name = priorityName or "Normal"
	}
	TriggerClientEvent('hud:client:env:update', src, currentAOP, currentPT, priorityName)
	TriggerClientEvent('hud:client:aop:update', src,
		{ aop = currentAOP, peacetime = currentPT, priority = prioObj })
end)

AddEventHandler('onResourceStart', function(resourceName)
	if GetCurrentResourceName() == resourceName then
		LoadAOPState()
		TriggerEvent('AOP:Sync')

		lastSyncTime = os.time()
	end
end)
