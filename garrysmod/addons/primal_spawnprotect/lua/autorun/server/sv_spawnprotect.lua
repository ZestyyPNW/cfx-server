-- ─── Damage protection ────────────────────────────────────────────────────────
-- Cancel all damage (including fall damage) while a player is inside a zone.
hook.Add("EntityTakeDamage", "PrimalSpawnProtect_Block", function(ent, dmginfo)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    for _, zone in ipairs(ents.FindByClass("sent_spawnprotect")) do
        if IsValid(zone) and zone:IsPointInside(ent:GetPos()) then
            dmginfo:SetDamage(0)
            return true
        end
    end
end)

-- ─── Persistence ─────────────────────────────────────────────────────────────
local SAVE_FILE = "spawnprotect_zones.json"

local function VecToT(v) return { x = v.x, y = v.y, z = v.z } end
local function AngToT(a) return { p = a.p, y = a.y, r = a.r } end

function SPAWNPROTECT_SaveZones()
    local data = {}
    for _, ent in ipairs(ents.FindByClass("sent_spawnprotect")) do
        if IsValid(ent) then
            data[#data + 1] = {
                pos  = VecToT(ent:GetPos()),
                ang  = AngToT(ent:GetAngles()),
                half = VecToT(ent:GetBoxHalfSize()),
            }
        end
    end
    file.Write(SAVE_FILE, util.TableToJSON(data, true))
end

local function LoadZones()
    if not file.Exists(SAVE_FILE, "DATA") then return end
    local raw  = file.Read(SAVE_FILE, "DATA")
    if not raw then return end
    local data = util.JSONToTable(raw)
    if not data then return end

    for _, d in ipairs(data) do
        local ent = ents.Create("sent_spawnprotect")
        if not IsValid(ent) then continue end
        ent:SetPos(Vector(d.pos.x, d.pos.y, d.pos.z))
        ent:SetAngles(Angle(d.ang.p, d.ang.y, d.ang.r))
        ent:Spawn()
        ent:SetBoxHalfSize(Vector(d.half.x, d.half.y, d.half.z))
        ent:Activate()

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
    end

    print("[SpawnProtect] Loaded " .. #data .. " zone(s) from disk.")
end

-- Load zones after everything has initialized
hook.Add("InitPostEntity", "SpawnProtect_Load", LoadZones)

-- Save on clean shutdown and every 5 minutes
hook.Add("ShutDown", "SpawnProtect_Save", SPAWNPROTECT_SaveZones)
timer.Create("SpawnProtect_AutoSave", 300, 0, SPAWNPROTECT_SaveZones)

-- Re-freeze any zone that was moved with physgun when the player lets go
hook.Add("PhysgunDrop", "SpawnProtect_Refreeze", function(ply, ent)
    if not IsValid(ent) or ent:GetClass() ~= "sent_spawnprotect" then return end
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
    SPAWNPROTECT_SaveZones()
end)
