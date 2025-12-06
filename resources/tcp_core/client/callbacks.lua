
Callbacks = {}
local awaiting = {}
local counter = 0

local function nextId()
    counter = counter + 1
    return counter
end

function Callbacks.register(name, cb)
    Callbacks[name] = cb
end

RegisterNetEvent('tcp_core:client:callback', function(name, requestId, ...)
    local fn = Callbacks[name]
    if not fn then
        Utils.error(('No client callback %s'):format(name))
        TriggerServerEvent('tcp_core:server:callbackResponse', requestId, nil)
        return
    end

    local ok, result = pcall(fn, ...)
    if not ok then
        Utils.error(('Client callback %s failed: %s'):format(name, result))
        result = nil
    end
    TriggerServerEvent('tcp_core:server:callbackResponse', requestId, result)
end)

-- client -> server RPC
function Callbacks.triggerServer(name, ...)
    local id = nextId()
    local p = promise.new()
    awaiting[id] = p
    TriggerServerEvent('tcp_core:server:callback', name, id, ...)
    return Citizen.Await(p)
end

RegisterNetEvent('tcp_core:client:callbackResponse', function(requestId, result)
    local p = awaiting[requestId]
    awaiting[requestId] = nil
    if p then
        p:resolve(result)
    end
end)


