-- ─── Tool definition ──────────────────────────────────────────────────────────
TOOL.Category   = "Primal Networks"
TOOL.Name       = "#tool.spawnprotect.name"
TOOL.Command    = "spawnprotect"
TOOL.ConfigName = "spawnprotect"

if CLIENT then
    language.Add("tool.spawnprotect.name", "Spawn Protector")
    language.Add("tool.spawnprotect.desc",
        "Select 4 corner points to define a damage-free zone with a physical display.")
    language.Add("tool.spawnprotect.0",
        "LMB: place point (4 needed to create zone) | RMB: remove zone / clear | Reload: clear selection")
end

-- ─── Server-side net strings & point storage ─────────────────────────────────
if SERVER then
    util.AddNetworkString("SpawnProtect_SyncPoints")
    -- Per-player point lists indexed by SteamID64
    SPAWNPROTECT_POINTS = SPAWNPROTECT_POINTS or {}
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function SendPoints(ply, pts)
    net.Start("SpawnProtect_SyncPoints")
        net.WriteUInt(#pts, 4)
        for _, p in ipairs(pts) do net.WriteVector(p) end
    net.Send(ply)
end

local function ClearPoints(ply)
    local sid = ply:SteamID64()
    SPAWNPROTECT_POINTS[sid] = {}
    SendPoints(ply, {})
end

local function CreateZone(ply, pts)
    -- Compute AABB from all 4 points
    local minX, minY, minZ =  math.huge,  math.huge,  math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    for _, p in ipairs(pts) do
        minX = math.min(minX, p.x); maxX = math.max(maxX, p.x)
        minY = math.min(minY, p.y); maxY = math.max(maxY, p.y)
        minZ = math.min(minZ, p.z); maxZ = math.max(maxZ, p.z)
    end

    -- Extend height: at least 320 units tall from the lowest point
    maxZ = minZ + math.max(maxZ - minZ + 80, 320)

    local center = Vector(
        (minX + maxX) * 0.5,
        (minY + maxY) * 0.5,
        (minZ + maxZ) * 0.5
    )
    local half = Vector(
        (maxX - minX) * 0.5,
        (maxY - minY) * 0.5,
        (maxZ - minZ) * 0.5
    )

    -- Display faces the placing player
    local yaw = ply:GetAngles().y

    local ent = ents.Create("sent_spawnprotect")
    if not IsValid(ent) then return end
    ent:SetPos(center)
    ent:SetAngles(Angle(0, yaw, 0))
    ent:Spawn()
    ent:SetBoxHalfSize(half)
    ent:Activate()

    -- Freeze it in place (still moveable with physgun)
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    ply:ChatPrint("[SpawnProtect] Zone created! Grab the invisible plate at the center to reposition it.")

    if SPAWNPROTECT_SaveZones then SPAWNPROTECT_SaveZones() end
end

-- ─── Left Click: place point ──────────────────────────────────────────────────
function TOOL:LeftClick(trace)
    if not trace.Hit then return false end

    local ply = self:GetOwner()
    if CLIENT then return true end

    if not ply:IsAdmin() then
        ply:ChatPrint("[SpawnProtect] Admins only.")
        return false
    end

    local sid = ply:SteamID64()
    SPAWNPROTECT_POINTS[sid] = SPAWNPROTECT_POINTS[sid] or {}
    local pts = SPAWNPROTECT_POINTS[sid]

    -- Already have 4 → reset and start fresh
    if #pts >= 4 then
        SPAWNPROTECT_POINTS[sid] = {}
        pts = SPAWNPROTECT_POINTS[sid]
    end

    table.insert(pts, trace.HitPos)
    ply:ChatPrint("[SpawnProtect] Point " .. #pts .. " / 4 placed.")
    SendPoints(ply, pts)

    if #pts == 4 then
        CreateZone(ply, pts)
        SPAWNPROTECT_POINTS[sid] = {}
        SendPoints(ply, {})
    end

    return true
end

-- ─── Right Click: remove zone or clear selection ──────────────────────────────
function TOOL:RightClick(trace)
    local ply = self:GetOwner()
    if CLIENT then return true end
    if not ply:IsAdmin() then return false end

    if IsValid(trace.Entity) and trace.Entity:GetClass() == "sent_spawnprotect" then
        trace.Entity:Remove()
        ply:ChatPrint("[SpawnProtect] Zone removed.")
        return true
    end

    ClearPoints(ply)
    ply:ChatPrint("[SpawnProtect] Selection cleared.")
    return true
end

-- ─── Reload: clear selection ──────────────────────────────────────────────────
function TOOL:Reload(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not ply:IsAdmin() then return false end
    ClearPoints(ply)
    ply:ChatPrint("[SpawnProtect] Selection cleared.")
    return true
end

-- ─── Client-side: receive points and draw markers ─────────────────────────────
if CLIENT then
    local _pts = {}

    net.Receive("SpawnProtect_SyncPoints", function()
        _pts = {}
        local n = net.ReadUInt(4)
        for i = 1, n do
            _pts[i] = net.ReadVector()
        end
    end)

    -- 3D point & line markers while tool is active
    hook.Add("PostDrawTranslucentRenderables", "SpawnProtect_DrawMarkers", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" then return end
        if wep:GetMode() ~= "spawnprotect" then return end
        if #_pts == 0 then return end

        render.SetColorMaterial()

        for i, pos in ipairs(_pts) do
            -- Glowing cross marker at each point
            local r = 10
            render.DrawLine(pos + Vector(r, 0, 0), pos - Vector(r, 0, 0), Color(60, 220, 100), true)
            render.DrawLine(pos + Vector(0, r, 0), pos - Vector(0, r, 0), Color(60, 220, 100), true)
            render.DrawLine(pos + Vector(0, 0, r), pos - Vector(0, 0, r), Color(60, 220, 100), true)

            -- Lines connecting points in order
            if i > 1 then
                render.DrawLine(_pts[i - 1], pos, Color(60, 220, 100, 180), true)
            end
        end

        -- Close the outline once we have 3+ points
        if #_pts >= 3 then
            render.DrawLine(_pts[#_pts], _pts[1], Color(60, 220, 100, 80), true)
        end
    end)

    -- Heads-up prompt while the tool is active
    function TOOL:DrawHUD()
        if #_pts == 0 then
            draw.SimpleText(
                "Left click to place corner points (0 / 4)",
                "DermaLarge",
                ScrW() * 0.5, ScrH() - 110,
                Color(200, 200, 200, 200),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
            )
            return
        end

        local txt = "Points placed: " .. #_pts .. " / 4"
        if #_pts == 4 then txt = "Creating zone…" end

        draw.SimpleText(txt, "DermaLarge",
            ScrW() * 0.5, ScrH() - 110,
            Color(60, 220, 100),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.SimpleText("Right click or Reload to clear selection", "DermaDefault",
            ScrW() * 0.5, ScrH() - 86,
            Color(170, 170, 170, 180),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end
