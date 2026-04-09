AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetLagCompensated( true )
    
    self:PhysicsInit(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NOCLIP)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    
    self:SetAngles(Angle(math.random(-180, 180), math.random(-180, 180), 0))
    self:SetCycle( math.Rand(0,1) )
    self:SetAutomaticFrameAdvance( true )

    self.dead = false
    self.lerp_pos = self:GetPos()
    
    if self.CustomInitialize then
        self:CustomInitialize()
    end
end

function ENT:OnTakeDamage(dmginfo)
    if self:GetDead() then return end
    
    local attacker = dmginfo:GetAttacker()
    self:Die(attacker, dmginfo)
end

function ENT:Die(attacker, dmginfo)
    if self:GetDead() then return end
    
    self:SetDead(true)
    self.Killer = attacker
    
    if self.CustomDie then
        self:CustomDie(attacker, dmginfo)
    end
    
    SafeRemoveEntityDelayed(self, 0.1)
end

function ENT:NotMyNeighbors( ent )
    if ent == self or ent:GetClass() == self:GetClass() then return false end
    return true
end

function ENT:GetNearByOptimized()
    if self.UseDistanceCheck == nil then return {} end
    return BoidGrid.GetNearByOptimized(self, self.UseDistanceCheck, self.DistanceCheckSqr)
end

function ENT:ObstacleRay()
    return BoidMath.ObstacleRay(self, self.TraceLength, function(ent) return self:NotMyNeighbors(ent) end, self.IsWaterBoid)
end

function ENT:Think()
    if self.CustomThink then
        return self:CustomThink()
    end
    return true
end
