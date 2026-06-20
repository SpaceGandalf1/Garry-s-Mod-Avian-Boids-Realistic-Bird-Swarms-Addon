AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local CV = BoidShared.CreateConVars("boidfish", {
    SPEED = "300",
    TRACE_LEN = "200",
    MODEL = "models/props/cs_militia/fishriver01.mdl",
    MINSMAXS_BOUNDS = "10",
})

function ENT:CustomInitialize()
    self:SetModel(CV.MODEL:GetString())
    self:ResetSequence(0)

    local bounds = CV.MINSMAXS_BOUNDS:GetFloat()
    self:SetCollisionBounds( -Vector(bounds,bounds,bounds), Vector(bounds,bounds,bounds) )
    self.mins, self.maxs = Vector( -20, -20, -20 ), Vector( 20, 20, 20 )

    self.UseDistanceCheck = CV.DISTANCE_CHECK:GetBool()
    self.DistanceCheckSqr = math.pow(CV.DISTANCE_CHECK_VALUE:GetInt(), 2)
    self.TraceLength = CV.TRACE_LEN:GetFloat()
    self.IsWaterBoid = true
end

function ENT:CustomThink()
    if BoidShared.PreThink(self, CV) then return true end

    local pos = self:GetPos()
    local validNeighbors = BoidShared.GatherForwardNeighbors(self, pos)

    local separation, alignment, cohesion = BoidMath.GetFlockingSteer(
        self, validNeighbors,
        CV.COLLISION_RULE:GetBool(), CV.ALIGNMENT_RULE:GetBool(), CV.COHESION_RULE:GetBool(),
        CV.MIN_DIST:GetFloat(), pos, self:GetForward()
    )

    local orbitForce = BoidShared.GetOrbitForce(pos, CV.ORBIT_DISTANCE:GetInt())

    local steer = (separation * CV.SEPARATION_FACTOR:GetFloat()) +
                  (alignment * CV.ALIGNMENT_FACTOR:GetFloat()) +
                  (cohesion * CV.COHESION_FACTOR:GetFloat()) +
                  (orbitForce * CV.ORBIT_FACTOR:GetFloat())

    steer = steer + VectorRand() * CV.NOISE_FACTOR:GetFloat()

    if steer:Length() > 1 then steer:Normalize() end

    local forwardPos = pos + self:GetForward() * self.TraceLength

    local forwardRay = util.TraceLine({
        start = pos,
        endpos = forwardPos,
        mask = MASK_SOLID,
        filter = function(ent) return self:NotMyNeighbors(ent) end
    })

    local isForwardWater = bit.band(util.PointContents(forwardPos), CONTENTS_WATER) == CONTENTS_WATER

    if forwardRay.Hit or not isForwardWater then
        debugoverlay.Line( pos, forwardPos, 0.05, Color( 255, 0, 0, 1), false )
    else
        debugoverlay.Line( pos, forwardPos, 0.05, Color( 0, 255, 255, 1), false )
    end

    if forwardRay.Hit or not isForwardWater then
        local escapeDir = self:ObstacleRay()
        local sub = forwardRay.Hit and (1 - forwardRay.Fraction) or 0.8
        local repulsion = forwardRay.Hit and (forwardRay.HitNormal * (sub * 2)) or (Vector(0, 0, -1) * 2)
        local finalEscape = (escapeDir + repulsion):GetNormalized()

        local intensity = sub > 0 and sub or 0.8
        steer = LerpVector(intensity, steer, finalEscape * 10)
    end

    if not self:IsInWorld() then
        local centerDir = (Vector(0,0,0) - pos):GetNormalized()
        steer = centerDir * 20
    end

    if steer:Length() > 1 then steer:Normalize() end

    local finalDir = (self:GetForward() + steer * 0.1):GetNormalized()

    self:SetAngles(finalDir:Angle())
    self:SetPos(pos + finalDir * (CV.SPEED:GetFloat() * FrameTime()))
    self:NextThink(CurTime())

    debugoverlay.BoxAngles( self:GetPos(), self:OBBMins(), self:OBBMaxs(), self:GetAngles(), 0.05, Color( 255, 255, 0, 50 ) )

    return true
end

function ENT:SpawnFunction(ply, tr, ClassName)
    BoidShared.SpawnSchool(ply, tr, ClassName, {
        undoName = "Fish School",
        requireWater = true,
        waterMessage = "Fish must be spawned in the water!",
        count = CV.SPAWN_NUMBER:GetInt(),
        position = function(spawnPos) return spawnPos + VectorRand() * 30 end,
    })
end
