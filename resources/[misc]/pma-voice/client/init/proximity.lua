-- used when muted
local disableUpdates = false
local isListenerEnabled = false
local plyCoords = GetEntityCoords(PlayerPedId())
proximity = MumbleGetTalkerProximity()
currentTargets = {}

-- a list of all the players the current client us listening to
-- the value will be set to false if we didn't actually start listening to them (in situations where their channel didn't exist)
-- TODO: PR a native to let us get if we're listening to a certain channel.
local listeners = {}

function orig_addProximityCheck(ply)
	local tgtPed = GetPlayerPed(ply)
	local voiceRange = GetConvar('voice_useNativeAudio', 'false') == 'true' and proximity * 3 or proximity
	local distance = #(plyCoords - GetEntityCoords(tgtPed))
	return distance < voiceRange, distance
end

local addProximityCheck = orig_addProximityCheck

exports("overrideProximityCheck", function(fn)
	addProximityCheck = fn
end)

exports("resetProximityCheck", function()
	addProximityCheck = orig_addProximityCheck
end)

function addNearbyPlayers()
	if disableUpdates then return end
	-- update here so we don't have to update every call of addProximityCheck
	plyCoords = GetEntityCoords(PlayerPedId())
	proximity = MumbleGetTalkerProximity()
	currentTargets = {}
	MumbleClearVoiceTargetChannels(voiceTarget)
	if LocalPlayer.state.disableProximity then return end

	if LocalPlayer.state.assignedChannel and LocalPlayer.state.assignedChannel ~= 0 then
		MumbleAddVoiceChannelListen(LocalPlayer.state.assignedChannel)
		MumbleAddVoiceTargetChannel(voiceTarget, LocalPlayer.state.assignedChannel)
	end

	local players = GetActivePlayers()
	for i = 1, #players do
		local ply = players[i]
		local serverId = GetPlayerServerId(ply)
		local shouldAdd, distance = addProximityCheck(ply)
		if shouldAdd then
			local channel = MumbleGetVoiceChannelFromServerId(serverId)
			if channel ~= -1 then
				MumbleAddVoiceTargetChannel(voiceTarget, channel)
			end
		end
	end
end

function addChannelListener(serverId)
	-- not in the documentation, but this will return -1 whenever the client isn't in a channel
	local channel = MumbleGetVoiceChannelFromServerId(serverId)
	if channel ~= -1 then
		MumbleAddVoiceChannelListen(channel)
		logger.verbose("Adding %s to listen table", serverId)
	end
	listeners[serverId] = channel ~= -1
end

function removeChannelListener(serverId)
	if listeners[serverId] then
		local channel = MumbleGetVoiceChannelFromServerId(serverId)
		if channel ~= -1 then
			MumbleRemoveVoiceChannelListen(channel)
		end
		logger.verbose("Removing %s from listen table", serverId)
	end
	-- remove the listener if they exist
	listeners[serverId] = nil
end

function setSpectatorMode(enabled)
	logger.info('Setting spectate mode to %s', enabled)
	isListenerEnabled = enabled
	local players = GetActivePlayers()
	if isListenerEnabled then
		for i = 1, #players do
			local ply = players[i]
			local serverId = GetPlayerServerId(ply)
			if serverId == playerServerId then goto skip_loop end
			addChannelListener(serverId)
			::skip_loop::
		end
	else
		for i = 1, #players do
			local ply = players[i]
			local serverId = GetPlayerServerId(ply)
			if serverId == playerServerId then goto skip_loop end
			removeChannelListener(serverId)
			::skip_loop::
		end

		-- cleanup table if we stop listening
		listeners = {}
	end
end

function tryListeningToFailedListeners()
	for src, isListening in pairs(listeners) do
		-- if we failed to listen before we'll be set to false
		if not isListening then
			addChannelListener(src)
		end
	end
end

RegisterNetEvent('onPlayerJoining', function(serverId)
	if isListenerEnabled then
		addChannelListener(serverId)
	end
end)

RegisterNetEvent('onPlayerDropped', function(serverId)
	if isListenerEnabled then
		removeChannelListener(serverId)
	end
end)
