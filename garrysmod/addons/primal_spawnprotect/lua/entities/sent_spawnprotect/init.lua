AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/hunter/plates/plate075x075.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(50000) -- Very heavy so it doesn't fly around
    end

    self:SetBoxHalfSize(Vector(100, 100, 160))
end

function ENT:OnRemove()
    -- Signal the save system to write the updated zone list
    if SPAWNPROTECT_SaveZones then
        SPAWNPROTECT_SaveZones()
    end
end
