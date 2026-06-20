AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetLagCompensated( true )
    
    self:PhysicsInit(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NOCLIP)
    self:SetSolid(SOLID_BBOX)
    -- Solid to the world, but the ShouldCollide rule keeps boids ghostly to players
    -- and each other while still letting projectiles strike them.
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:SetCustomCollisionCheck(true)
    
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

-- A projectile struck us (the ShouldCollide rule only lets projectiles touch boids).
-- Route it through TakeDamageInfo so each species' own damage handling applies.
function ENT:Touch( ent )
    if self:GetDead() then return end
    if not IsValid(ent) then return end
    if BoidShared.BoidClasses[ent:GetClass()] then return end
    if not BoidShared.IsProjectile(ent) then return end

    local attacker = IsValid(ent.Shooter) and ent.Shooter or nil
    if not attacker and ent.GetOwner then
        local owner = ent:GetOwner()
        if IsValid(owner) then attacker = owner end
    end

    local dmg = DamageInfo()
    dmg:SetDamage(math.Clamp(ent:GetVelocity():Length() / 25, 25, 300))
    dmg:SetAttacker(IsValid(attacker) and attacker or ent)
    dmg:SetInflictor(ent)
    dmg:SetDamageType(DMG_GENERIC)
    dmg:SetDamagePosition(self:GetPos())
    dmg:SetDamageForce(ent:GetVelocity() * 0.1)

    self:TakeDamageInfo(dmg)
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
