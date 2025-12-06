PlayerData = {}
local cache = {}

local function defaultData(ident)
    return {
        identifier = ident,
        money = 0,
        bank = 0,
        job = 'unemployed',
        job_grade = 0,
        created_at = os.date('%Y-%m-%d %H:%M:%S')
    }
end

function PlayerData.load(src)
    local ident = Identifier.get(src)
    if not ident then return nil end

    local row = MySQL.single.await('SELECT * FROM ' .. Config.Database.PlayersTable .. ' WHERE identifier = ?', { ident })
    if not row then
        row = defaultData(ident)
        local inserted = MySQL.insert.await('INSERT INTO ' .. Config.Database.PlayersTable .. ' (identifier, money, bank, job, job_grade, created_at) VALUES (?, ?, ?, ?, ?, ?)', {
            row.identifier, row.money, row.bank, row.job, row.job_grade, row.created_at
        })
        if not inserted then
            Utils.error('Failed to insert default player row for ' .. ident)
            return nil
        end
        row.id = inserted
    end

    cache[src] = row
    TriggerEvent('tcp_core:playerLoaded', src, row)
    return row
end

function PlayerData.save(src)
    local data = cache[src]
    if not data then return end
    MySQL.update.await('UPDATE ' .. Config.Database.PlayersTable .. ' SET money = ?, bank = ?, job = ?, job_grade = ? WHERE identifier = ?', {
        data.money, data.bank, data.job, data.job_grade, data.identifier
    })
end

function PlayerData.get(src)
    return cache[src]
end

function PlayerData.set(src, key, value)
    cache[src] = cache[src] or {}
    cache[src][key] = value
end

AddEventHandler('playerDropped', function()
    local src = source
    PlayerData.save(src)
    cache[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, _ in pairs(cache) do
        PlayerData.save(src)
    end
end)


