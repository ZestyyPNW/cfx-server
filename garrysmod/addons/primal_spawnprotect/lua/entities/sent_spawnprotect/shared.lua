ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "Spawn Protector"
ENT.Author    = "Primal Networks"
ENT.Spawnable = false
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("Vector", 0, "BoxHalfSize")
end

-- Returns true if 'pos' falls inside this zone's AABB.
function ENT:IsPointInside(pos)
    local c = self:GetPos()
    local h = self:GetBoxHalfSize()
    return pos.x >= c.x - h.x and pos.x <= c.x + h.x
       and pos.y >= c.y - h.y and pos.y <= c.y + h.y
       and pos.z >= c.z - h.z and pos.z <= c.z + h.z
end
