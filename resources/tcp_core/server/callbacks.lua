
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

RegisterNetEvent('tcp_core:server:callback', function(name, requestId, ...)
    local src = source
    local fn = Callbacks[name]
    if not fn then
        Utils.error(('No callback %s'):format(name))
        return
    end

    local ok, result = pcall(fn, src, ...)
    if not ok then
        Utils.error(('Callback %s failed: %s'):format(name, result))
        result = nil
    end
    TriggerClientEvent('tcp_core:client:callbackResponse', src, requestId, result)
end)

-- server -> client RPC
function Callbacks.triggerClient(src, name, ...)
    local id = nextId()
    local p = promise.new()
    awaiting[id] = p
    TriggerClientEvent('tcp_core:client:callback', src, name, id, ...)
    return Citizen.Await(p)
end

RegisterNetEvent('tcp_core:server:callbackResponse', function(requestId, result)
    local p = awaiting[requestId]
    awaiting[requestId] = nil
    if p then
        p:resolve(result)
    end
end)


