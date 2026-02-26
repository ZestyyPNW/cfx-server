-- ============================================================
-- tcp_drugs — dev.lua  (remove from fxmanifest when done)
--
-- /drugzone <drug> <type>   start a new zone (grow|process|sell)
-- /drugpoint                mark your current position as a point
-- /drugzonecancel           cancel current recording
-- ============================================================

local active = false
local points = {}
local target = {}

local function msg(text, color)
    TriggerEvent('chat:addMessage', {
        color = color or { 255, 255, 100 },
        args  = { '^3[DrugZone]', text }
    })
end

local function calcCenter(pts)
    local sx, sy, sz = 0, 0, 0
    for _, p in ipairs(pts) do sx=sx+p.x; sy=sy+p.y; sz=sz+p.z end
    return vector3(sx/#pts, sy/#pts, sz/#pts)
end

local function calcRadius(center, pts)
    local max = 0
    for _, p in ipairs(pts) do
        local d = math.sqrt((p.x-center.x)^2 + (p.y-center.y)^2)
        if d > max then max = d end
    end
    return math.ceil((max + 0.5) * 10) / 10
end

local function outputResult()
    local isSingle = (target.zoneType == 'sell' or target.zoneType == 'process')
    local center = isSingle and points[1] or calcCenter(points)
    local radius = isSingle and 3.0 or calcRadius(center, points)
    local cx = math.floor(center.x * 10) / 10
    local cy = math.floor(center.y * 10) / 10
    local cz = math.floor(center.z * 10) / 10
    local dk  = (target.drugKey or 'drug'):gsub("^%l", string.upper)
    local zt  = (target.zoneType or 'zone'):gsub("^%l", string.upper)
    local lbl = dk .. ' ' .. zt

    local pedLine = ''
    if target.zoneType == 'sell' then
        pedLine = " ped = 'a_m_m_og_boss_01',"
    end
    local line = ("{ coords = vector3(%s, %s, %s), radius = %.1f, label = '%s',%s },"):format(cx, cy, cz, radius, lbl, pedLine)

    msg('--- COPY INTO config.lua ---', { 100, 255, 100 })
    msg(line, { 200, 255, 200 })
    msg('----------------------------', { 100, 255, 100 })
    print('[tcp_drugs DEV] ' .. line)

    active = false
    points = {}
    target = {}
end

-- ============================================================
RegisterCommand('drugzone', function(_, args)
    local drug = args[1]
    local zone = args[2]
    if not drug or not zone then
        msg('Usage: /drugzone <weed|meth|cocaine|heroin> <grow|process|sell>', { 255, 100, 100 })
        return
    end
    if not Config.Drugs[drug] then
        msg('Unknown drug: ' .. tostring(drug), { 255, 100, 100 })
        return
    end
    active = true
    points = {}
    target = { drugKey = drug, zoneType = zone }
    msg(('Started [%s > %s]. Walk to each corner and type /drugpoint (0/4)'):format(drug, zone), { 100, 200, 255 })
end, false)

RegisterCommand('drugpoint', function()
    if not active then
        msg('Start a zone first with /drugzone', { 255, 100, 100 })
        return
    end
    local coords = GetEntityCoords(PlayerPedId())
    local needed = (target.zoneType == 'sell' or target.zoneType == 'process') and 1 or 4
    table.insert(points, coords)
    local remaining = needed - #points
    msg(('Point %d marked: %.1f, %.1f, %.1f — %d to go'):format(#points, coords.x, coords.y, coords.z, math.max(0, remaining)), { 100, 220, 255 })
    if #points >= needed then
        outputResult()
    end
end, false)

RegisterCommand('drugzonecancel', function()
    active = false; points = {}; target = {}
    msg('Cancelled.', { 255, 150, 100 })
end, false)

-- Draw markers on recorded points
CreateThread(function()
    while true do
        Wait(active and 0 or 300)
        if active then
            for _, p in ipairs(points) do
                DrawMarker(1, p.x, p.y, p.z + 0.05, 0,0,0, 0,0,0, 0.5,0.5,0.5, 100,255,100,180, false,false,2,false,nil,nil,false)
            end
        end
    end
end)
