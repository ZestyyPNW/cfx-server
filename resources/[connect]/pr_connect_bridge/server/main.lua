-- PNWS Connect Bridge (BRIDGE-001). FiveM adapter for join authorization,
-- session heartbeat and sanction sync. Talks to the Connect API over HTTPS
-- with a per-server service token; NEVER touches the central database.
--
-- Not yet installed on the production server; integration testing requires
-- Founder approval (see roadmap BRIDGE-001).

local API_BASE   = GetConvar('connect_api_base', 'https://connect.primalnetworks.co')
local TOKEN      = GetConvar('connect_service_token', '')
local CACHE_TTL  = tonumber(GetConvar('connect_cache_ttl', '300')) or 300

-- Bounded offline cache: decisions remembered only within the approved TTL;
-- known denials remembered (fail closed), unknown players get NO inherited
-- allow after the TTL expires.
local decisionCache = {}   -- identifier -> { allow=bool, restrictions={}, expires=os.time() }
local sessionMembers = {}  -- src -> { member_id, identifiers, started_at }

local function authorizedHeaders()
    return {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = ('Bearer %s'):format(TOKEN),
    }
end

local function apiRequest(method, path, body, cb, attempts)
    attempts = attempts or 0
    if attempts >= 3 then return cb(false, nil) end -- bounded retries
    PerformHttpRequest(('%s/api/v1%s'):format(API_BASE, path), function(status, _, data)
        if status == 0 then -- network failure
            Wait(500 * (2 ^ attempts))
            return apiRequest(method, path, body, cb, attempts + 1)
        end
        local ok, decoded = pcall(json.decode, data or '{}')
        cb(status >= 200 and status < 300, ok and decoded or nil, status)
    end, method, body and json.encode(body) or '', authorizedHeaders())
end

local function playerIdentifiers(src)
    local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        local kind = id:match('^(%w+):')
        if kind == 'license' then
            ids[#ids + 1] = { provider = 'fivem', subject = id }
        elseif kind == 'discord' then
            ids[#ids + 1] = { provider = 'discord', subject = id:sub(1, #('discord:') + 20) }
        end
    end
    return ids
end

-- Join authorization: fail CLOSED when the API is unreachable and no fresh
-- cached allow exists; known bans stay denied during outages.
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('Checking network authorization...')

    local ids = playerIdentifiers(src)
    local key = ids[1] and ids[1].subject or tostring(src)

    -- honor fresh cached decision
    local cached = decisionCache[key]
    if cached and cached.expires > os.time() then
        if not cached.allow then
            deferrals.done('Connect: you are banned from this network.')
        else
            deferrals.done()
        end
        return
    end
    -- expired cache: do NOT inherit allow; ask the API (deny on outage)
    decisionCache[key] = nil

    local done = false
    apiRequest('POST', '/sessions/authorize', {
        request_id = ('%s-%s'):format(GetGameTimer(), key:sub(-8)),
        identifiers = ids,
    }, function(ok, data, status)
        if done then return end
        done = true
        if not ok and status == 403 then
            decisionCache[key] = { allow = false, expires = os.time() + CACHE_TTL }
            deferrals.done('Connect: ' .. ((data and data.message) or 'you are banned from this network.'))
            return
        end
        if not ok then
            -- outage or error: fail closed for players whose last decision was a deny
            if cached and not cached.allow then
                deferrals.done('Connect: authorization unavailable (ban on file).')
            else
                deferrals.done('Connect: authorization service unreachable, try again shortly.')
            end
            return
        end
        decisionCache[key] = {
            allow = true, restrictions = data.restrictions or {},
            expires = os.time() + CACHE_TTL, memberId = data.member_id,
        }
        deferrals.done()
    end)

    -- API silent (timeout): fail closed
    SetTimeout(10000, function()
        if not done then done = true; deferrals.done('Connect: authorization timed out.') end
    end)
end)

AddEventHandler('playerJoining', function()
    local src = source
    local ids = playerIdentifiers(src)
    local key = ids[1] and ids[1].subject or tostring(src)
    local cached = decisionCache[key]
    sessionMembers[src] = {
        identifiers = ids,
        member_id = cached and cached.member_id or nil,
        started_at = os.time(),
    }
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local session = sessionMembers[src]
    if session then
        -- session end: telemetry event (Pulse consumes these in Phase 03)
        -- TODO: POST /sessions/end when the API ships it
        sessionMembers[src] = nil
    end
end)

-- heartbeat: every 60s while the resource runs
CreateThread(function()
    -- server presence heartbeat: runs whether or not players are online
    while true do
        apiRequest('POST', '/sessions/heartbeat', {}, function(ok) end)
        Wait(60000)
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if TOKEN == '' then
        print('^1[connect-bridge] connect_service_token convar is empty - authorization DISABLED (fail closed).^0')
    end
end)
