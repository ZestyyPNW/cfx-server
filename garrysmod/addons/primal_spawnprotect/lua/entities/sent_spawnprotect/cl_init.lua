include("shared.lua")

-- ─── Fonts ────────────────────────────────────────────────────────────────────
surface.CreateFont("SpawnProtect_Title", {
    font      = "Roboto",
    size      = 38,
    weight    = 800,
    antialias = true,
})
surface.CreateFont("SpawnProtect_Sub", {
    font      = "Roboto",
    size      = 20,
    weight    = 500,
    antialias = true,
})
surface.CreateFont("SpawnProtect_Label", {
    font      = "Roboto",
    size      = 14,
    weight    = 600,
    antialias = true,
    uppercase = true,
})

-- ─── Display constants ────────────────────────────────────────────────────────
local PW    = 520      -- canvas width  (pixels)
local PH    = 210      -- canvas height (pixels)
local SCALE = 0.4      -- world units per pixel (panel = 208 x 84 world units)
local ACCENT_H = 10    -- height of the top/bottom accent bars
local COL_GREEN = Color(60, 220, 100)
local COL_RED   = Color(220, 55,  55)
local COL_BG    = Color(6,   6,   6, 175)

-- ─── Entity setup ─────────────────────────────────────────────────────────────
function ENT:Initialize()
    -- Inflate render bounds so the panel is never culled when off-center.
    self:SetRenderBounds(Vector(-600, -600, -400), Vector(600, 600, 400))
end

-- ─── Draw (called every frame by the engine) ──────────────────────────────────
function ENT:Draw()
    -- Intentionally do NOT call self:DrawModel() → plate is invisible.

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local inside    = self:IsPointInside(ply:GetPos())
    local accentCol = inside and COL_GREEN or COL_RED

    -- Panel sits vertically, oriented by the entity's yaw so you can spin it
    -- with the physgun to face any direction you like.
    local pos     = self:GetPos()
    local dispAng = Angle(0, self:GetAngles().y, 0)

    cam.Start3D2D(pos, dispAng, SCALE)
        local hw = PW * 0.5
        local hh = PH * 0.5

        -- ── Background ──────────────────────────────────────────────────────
        surface.SetDrawColor(COL_BG.r, COL_BG.g, COL_BG.b, COL_BG.a)
        surface.DrawRect(-hw, -hh, PW, PH)

        -- ── Top accent bar ──────────────────────────────────────────────────
        surface.SetDrawColor(accentCol.r, accentCol.g, accentCol.b, 255)
        surface.DrawRect(-hw, -hh, PW, ACCENT_H)

        -- ── Bottom accent bar ───────────────────────────────────────────────
        surface.SetDrawColor(accentCol.r, accentCol.g, accentCol.b, 255)
        surface.DrawRect(-hw, hh - ACCENT_H, PW, ACCENT_H)

        -- ── Thin inner border ───────────────────────────────────────────────
        surface.SetDrawColor(accentCol.r, accentCol.g, accentCol.b, 45)
        surface.DrawOutlinedRect(-hw + 4, -hh + ACCENT_H + 4, PW - 8, PH - ACCENT_H * 2 - 8, 1)

        -- ── Server label ────────────────────────────────────────────────────
        draw.SimpleText("PRIMAL NETWORKS", "SpawnProtect_Label",
            0, -hh + ACCENT_H + 14,
            Color(160, 160, 160, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        -- ── Main status text ────────────────────────────────────────────────
        local statusTxt = inside and "SAFE ZONE" or "NOT PROTECTED"
        draw.SimpleText(statusTxt, "SpawnProtect_Title",
            0, -10,
            accentCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- ── Sub-status text ─────────────────────────────────────────────────
        local subTxt = inside
            and "You are protected from all damage"
            or  "You are outside the safe zone"
        draw.SimpleText(subTxt, "SpawnProtect_Sub",
            0, 28,
            Color(195, 195, 195, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- ── Status dot ──────────────────────────────────────────────────────
        surface.SetDrawColor(accentCol.r, accentCol.g, accentCol.b, 220)
        surface.DrawRect(-hw + 12, -8, 4, 16)

    cam.End3D2D()
end
