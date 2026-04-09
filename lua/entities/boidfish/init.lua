AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local DELETE_ON_ESCAPE_REALITY = CreateConVar( "sv_boidfish_delete_on_escape_reality", "0", FCVAR_NONE, "Delete the boid when he's getting out of the world", 0, 1 )
local COLLISION_RULE = CreateConVar( "sv_boidfish_collision_avoidances", "1", FCVAR_NONE, "", 0, 1 )
local ALIGNMENT_RULE = CreateConVar( "sv_boidfish_alignment", "1", FCVAR_NONE, "", 0, 1 )
local COHESION_RULE = CreateConVar( "sv_boidfish_cohesion", "1", FCVAR_NONE, "", 0, 1 )
local NOISE_FACTOR = CreateConVar( "sv_boidfish_noise_factor", "0.5", FCVAR_NONE, "", 0, 1 )
local MIN_DIST = CreateConVar( "sv_boidfish_separation_distances", "5", FCVAR_NONE, "", 2, 50 )
local SPEED = CreateConVar( "sv_boidfish_speed", "300", {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "", 0, 1000 )
local SPAWN_NUMBER = CreateConVar( "sv_boidfish_spawn_number", "1", FCVAR_NONE, "", 1, 100 )
local TRACE_LEN = CreateConVar( "sv_boidfish_trace_lengh", "200", FCVAR_NONE, "", 10, 1000 )
local BOIDFISH_MODEL = CreateConVar("sv_boidfish_model", "models/props/cs_militia/fishriver01.mdl", {FCVAR_REPLICATED, FCVAR_ARCHIVE})
local ALIGNMENT_FACTOR = CreateConVar( "sv_boidfish_alignment_factor", "0.8", FCVAR_NONE, "", 1, 10 )
local COHESION_FACTOR = CreateConVar( "sv_boidfish_cohesion_factor", "1.0", FCVAR_NONE, "", 1, 10 )
local SEPARATION_FACTOR = CreateConVar( "sv_boidfish_separation_factor", "1.5", FCVAR_NONE, "", 1, 10 )
local ORBIT_FACTOR = CreateConVar( "sv_boidfish_orbit_factor", "1.5", FCVAR_NONE, "", 0, 10 )
local ORBIT_DISTANCE = CreateConVar( "sv_boidfish_orbit_distance", "200", FCVAR_NONE, "", 10, 2000 )
local DISTANCE_CHECK = CreateConVar( "sv_boidfish_distance_check", "1", FCVAR_NONE, "Check the distance between boids to consider them as neighbors.", 0, 1 )
local DISTANCE_CHECK_VALUE = CreateConVar( "sv_boidfish_distance_check_value", "250", FCVAR_NONE, "", 100, 2000 )
local MINSMAXS_BOUNDS = CreateConVar( "sv_boidfish_mins_maxs_bounds", "10", FCVAR_NONE, "", 5, 50 )

function ENT:CustomInitialize()
    self:SetModel(BOIDFISH_MODEL:GetString())
    self:ResetSequence(0)
    local bounds = MINSMAXS_BOUNDS:GetFloat()
    local mins = -Vector(bounds,bounds,bounds)
    local maxs = -mins
    self:SetCollisionBounds( mins, maxs )
    self.mins, self.maxs = Vector( -20, -20, -20 ), Vector( 20, 20, 20 )
    
    self.UseDistanceCheck = DISTANCE_CHECK:GetBool()
    self.DistanceCheckSqr = math.pow(DISTANCE_CHECK_VALUE:GetInt(), 2)
    self.TraceLength = TRACE_LEN:GetFloat()
    self.IsWaterBoid = true
end

function ENT:CustomThink()
    if DELETE_ON_ESCAPE_REALITY:GetBool() and not self:IsInWorld() then 
        self:Remove() 
        return true
    end 

    self.UseDistanceCheck = DISTANCE_CHECK:GetBool()
    self.DistanceCheckSqr = math.pow(DISTANCE_CHECK_VALUE:GetInt(), 2)
    self.TraceLength = TRACE_LEN:GetFloat()

    local pos = self:GetPos()
    local rawNeighbors = self:GetNearByOptimized()
    local validNeighbors = {}
    
    for _, ent in ipairs(rawNeighbors) do
        local diff = ent:GetPos() - pos
        local distSqr = diff:LengthSqr()
        local toNeighbor = diff:GetNormalized()
        local dot = self:GetForward():Dot(toNeighbor)
    
        if dot > 0 then 
            table.insert(validNeighbors, {ent = ent, dist = math.sqrt(distSqr)})
        end
    end

    local separation, alignment, cohesion = BoidMath.GetFlockingSteer(
        self, validNeighbors, 
        COLLISION_RULE:GetBool(), ALIGNMENT_RULE:GetBool(), COHESION_RULE:GetBool(), 
        MIN_DIST:GetFloat(), pos, self:GetForward()
    )
    
    local entities = BoidGrid.CachedOrbits
    local orbitForce = Vector()
    if #entities >= 1 then
        table.sort( entities, function( a, b ) return pos:Distance2DSqr(a:GetPos()) < pos:Distance2DSqr(b:GetPos()) end)
        
        local targetPos = entities[1]:GetPos()
        local distToTarget = pos:Distance(targetPos)

        if distToTarget > ORBIT_DISTANCE:GetInt() then
            local dirToTarget = (targetPos - pos):GetNormalized()
            local orbitDir = dirToTarget:Cross(Vector(0, 0, 1)):GetNormalized()
            orbitForce = (dirToTarget * 0.3) + (orbitDir * 1.0)
        end
    end
    
    local steer = (separation * SEPARATION_FACTOR:GetFloat()) + 
                  (alignment * ALIGNMENT_FACTOR:GetFloat()) + 
                  (cohesion * COHESION_FACTOR:GetFloat()) + 
                  (orbitForce * ORBIT_FACTOR:GetFloat())

    steer = steer + VectorRand() * NOISE_FACTOR:GetFloat()

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
    self:SetPos(pos + finalDir * (SPEED:GetFloat() * FrameTime()))
    self:NextThink(CurTime())

    debugoverlay.BoxAngles( self:GetPos(), self:OBBMins(), self:OBBMaxs(), self:GetAngles(), 0.05, Color( 255, 255, 0, 50 ) )

    return true
end

function ENT:SpawnFunction(ply, tr, ClassName)
    if not tr.Hit then return end
    
    local spawnPos = tr.HitPos + tr.HitNormal * 30
    
    if bit.band(util.PointContents(spawnPos), CONTENTS_WATER) != CONTENTS_WATER then
        ply:ChatPrint("Fish must be spawned in the water!")
        return
    end

    undo.Create("Fish School")
        for i = 1, SPAWN_NUMBER:GetInt() do
            local ent = ents.Create(ClassName)
            ent:SetPos(spawnPos + VectorRand() * 30)
            ent:Spawn()
            ent:Activate()
            undo.AddEntity(ent)
        end
        undo.SetPlayer(ply)
    undo.Finish()
end
