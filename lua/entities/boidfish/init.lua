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

local NUM_DIRECTIONS = 36
local GOLDEN_RATIO = (1 + math.sqrt(5)) / 2
local ANGLE_INCREMENT = math.pi * 2 * GOLDEN_RATIO
local CELL_SIZE = CreateConVar( "sv_boidfish_cell_size", "1000", FCVAR_NONE, "", 50, 2000 )
local BoidDirections = {}

for i = 0, NUM_DIRECTIONS - 1 do
    local t = i / NUM_DIRECTIONS
    local inclination = math.acos(1 - 2 * t)
    local azimuth = ANGLE_INCREMENT * i

    local x = 1 - 2 * t
    local radius = math.sqrt(1 - x * x)
    
    local y = math.sin(azimuth) * radius
    local z = math.cos(azimuth) * radius
    
    table.insert(BoidDirections, Vector(x, y, z))
end

local Vector = Vector
local Color = Color
local Angle = Angle
local IsValid = IsValid
local CurTime = CurTime
local FrameTime = FrameTime
local LerpVector = LerpVector
local LocalToWorld = LocalToWorld
local ipairs = ipairs
local table_insert = table.insert
local table_sort = table.sort
local math_sqrt = math.sqrt
local math_random = math.random
local math_floor = math.floor
local util_TraceLine = util.TraceLine
local util_PointContents = util.PointContents
local bit_band = bit.band
local ents_FindByClass = ents.FindByClass
local debugoverlay_Line = debugoverlay.Line

local ent_meta = FindMetaTable("Entity")
local vec_meta = FindMetaTable("Vector")
local ang_meta = FindMetaTable("Angle")

local GetPos = ent_meta.GetPos
local SetPos = ent_meta.SetPos
local GetForward = ent_meta.GetForward
local GetAngles = ent_meta.GetAngles
local SetAngles = ent_meta.SetAngles
local GetClass = ent_meta.GetClass
local NextThink = ent_meta.NextThink
local IsInWorld = ent_meta.IsInWorld
local Remove = ent_meta.Remove

local Length = vec_meta.Length
local LengthSqr = vec_meta.LengthSqr
local GetNormalized = vec_meta.GetNormalized
local Dot = vec_meta.Dot
local Cross = vec_meta.Cross
local Distance = vec_meta.Distance
local DistToSqr = vec_meta.DistToSqr
local Distance2DSqr = vec_meta.Distance2DSqr
local Normalize = vec_meta.Normalize

local ToAngle = ang_meta.Angle

local BOIDFISH_GRID = {}
local CACHED_ORBITS_FISH = {}
local NextGridUpdateFish = 0

hook.Add("Tick", "UpdateBoidFishGrid", function()
    if CurTime() < NextGridUpdateFish then return end
    NextGridUpdateFish = CurTime() + 0.1 
    
    CACHED_ORBITS_FISH = ents_FindByClass("orbit")
    table.Empty(BOIDFISH_GRID)
    
    local cell_size = CELL_SIZE:GetFloat()
    for _, ent in ipairs(ents_FindByClass("boidfish")) do 
        if not IsValid(ent) then continue end

        local pos = ent:GetPos()
        local gx = math_floor(pos.x / cell_size)
        local gy = math_floor(pos.y / cell_size)
        local gz = math_floor(pos.z / cell_size)
        
        local key = gx .. "|" .. gy .. "|" .. gz
        
        BOIDFISH_GRID[key] = BOIDFISH_GRID[key] or {}
        table_insert(BOIDFISH_GRID[key], ent)
        
        ent.GridX = gx
        ent.GridY = gy
        ent.GridZ = gz
    end
end)

function ENT:NotMyNeighbors( ent )
    if ent == self or GetClass(ent) == "boidfish" then return false end
    return true
end

function ENT:Initialize()
    self:SetLagCompensated( true )
    self:SetModel(BOIDFISH_MODEL:GetString())
    
    -- PHYSICS FIX: Gives the fish a real hitbox!
    self:PhysicsInit(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NOCLIP)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    
    self:SetAngles(Angle(math.random(-180, 180), math.random(-180, 180), 0))

    self:ResetSequence(0)
    self:SetCycle( math.Rand(0,1) )
    self:SetAutomaticFrameAdvance( true )

    local bounds = MINSMAXS_BOUNDS:GetFloat()
    local mins = -Vector(bounds,bounds,bounds)
    local maxs = -mins
    self:SetCollisionBounds( mins, maxs )

    self.dead = false
    self.lerp_pos = self:GetPos()
    self.mins, self.maxs = Vector( -20, -20, -20 ), Vector( 20, 20, 20 )
end

-- NEW: Trigger death properly when hit natively by weapons
function ENT:OnTakeDamage(dmginfo)
    if self:GetDead() then return end
    
    local attacker = dmginfo:GetAttacker()
    self:Die(attacker)
end

function ENT:Die(attacker)
    if self:GetDead() then return end
    
    self:SetDead(true)
    self.Killer = attacker
    
    SafeRemoveEntityDelayed(self, 0.1)
end

function ENT:GetNearByOptimized()
    local neighbors = {}
    if not self.GridX then return neighbors end
    
    for dx = -1, 1 do
        for dy = -1, 1 do
            for dz = -1, 1 do
                local key = (self.GridX + dx) .. "|" .. (self.GridY + dy) .. "|" .. (self.GridZ + dz)
                local cell = BOIDFISH_GRID[key]
                
                if cell then
                    for _, b in ipairs(cell) do
                        if IsValid(b) and b != self then
                            if not DISTANCE_CHECK:GetBool() then table_insert(neighbors, b) continue end

                            local distSqr = DistToSqr( GetPos(b), GetPos(self) )
                            if distSqr < (DISTANCE_CHECK_VALUE:GetInt() * DISTANCE_CHECK_VALUE:GetInt()) then
                                table_insert(neighbors, b)
                            end
                        end
                    end
                end
            end
        end
    end
    return neighbors
end

function ENT:ObstacleRay()
    local pos = GetPos( self )
    local angles = GetAngles( self )
    
    for _, dir in ipairs(BoidDirections) do
        local worldDir = LocalToWorld(dir, Angle(0,0,0), Vector(0,0,0), angles)
        local testPos = pos + worldDir * TRACE_LEN:GetFloat()
        
        local tr = util_TraceLine({
            start = pos,
            endpos = testPos,
            mask = MASK_SOLID, 
            filter = function( ent ) return self:NotMyNeighbors( ent ) end
        })
        
        local isWater = bit_band(util_PointContents(testPos), CONTENTS_WATER) == CONTENTS_WATER
        
        if not tr.Hit and isWater then
            debugoverlay_Line( tr.StartPos, tr.HitPos, 0.05, Color( 0, 255, 0, 1), false )
            return worldDir
        end
        debugoverlay_Line( tr.StartPos, tr.HitPos, 0.05, Color( 255, 0, 0, 1), false )
    end
    
    return -GetForward( self ) 
end

function ENT:Think()
    if DELETE_ON_ESCAPE_REALITY:GetBool() and not IsInWorld( self ) then 
        Remove( self ) 
        return 
    end 

    local pos = GetPos( self )
    local rawNeighbors = self:GetNearByOptimized()
    local validNeighbors = {}
    
    local FOV_THRESHOLD = 0 

    for _, ent in ipairs(rawNeighbors) do
        if not IsValid(ent) or ent == self then continue end
        
        local diff = GetPos( ent ) - pos
        local distSqr = LengthSqr( diff )
        
        local toNeighbor = GetNormalized( diff )
        local dot = Dot( GetForward( self ), toNeighbor)
    
        if dot > -FOV_THRESHOLD then 
            table_insert(validNeighbors, {ent = ent, dist = math_sqrt(distSqr)})
        end
    end

    local separation = Vector(0, 0, 0)
    local alignment = Vector(0, 0, 0)
    local cohesion = Vector(0, 0, 0)
    local avgPos = Vector(0, 0, 0)
    
    local numNeighbors = #validNeighbors
    
    if numNeighbors > 0 then
        for _, n in ipairs(validNeighbors) do
            local otherPos = GetPos( n.ent )
            
            if COLLISION_RULE:GetBool() then
                local flee = pos - otherPos
                Normalize( flee )
                separation = separation + (flee / (n.dist / MIN_DIST:GetFloat())) 
            end
            
            if ALIGNMENT_RULE:GetBool() then alignment = alignment + GetForward( n.ent ) end
            if COHESION_RULE:GetBool() then avgPos = avgPos + otherPos end
        end
        
        if ALIGNMENT_RULE:GetBool() then alignment = GetNormalized( (alignment / numNeighbors) ) end
        if COHESION_RULE:GetBool() then cohesion = GetNormalized( ((avgPos / numNeighbors) - pos) ) end
    end
    
    local entities = CACHED_ORBITS_FISH
    local orbitForce = Vector()
    if #entities >= 1 then
        table_sort( entities, function( a, b ) return Distance2DSqr( pos, GetPos( a ) ) < Distance2DSqr( pos, GetPos( b ) ) end)
        
        local targetPos = GetPos( entities[1] )
        local distToTarget = Distance( pos, targetPos)

        if distToTarget > ORBIT_DISTANCE:GetInt() then
            local dirToTarget = GetNormalized( targetPos - pos )
            local orbitDir = GetNormalized(Cross( dirToTarget, Vector(0, 0, 1)))
            orbitForce = (dirToTarget * 0.3) + (orbitDir * 1.0)
        end
    end
    
    local steer = (separation * SEPARATION_FACTOR:GetFloat()) + 
                  (alignment * ALIGNMENT_FACTOR:GetFloat()) + 
                  (cohesion * COHESION_FACTOR:GetFloat()) + 
                  (orbitForce * ORBIT_FACTOR:GetFloat())

    steer = steer + VectorRand() * NOISE_FACTOR:GetFloat()

    if Length( steer ) > 1 then Normalize( steer ) end
    
    local traceDist = TRACE_LEN:GetFloat()
    local forwardPos = pos + GetForward( self ) * traceDist
    
    local forwardRay = util_TraceLine({
        start = pos,
        endpos = forwardPos,
        mask = MASK_SOLID, 
        filter = function(ent) return self:NotMyNeighbors(ent) end
    })
    
    local isForwardWater = bit_band(util_PointContents(forwardPos), CONTENTS_WATER) == CONTENTS_WATER
    
    if forwardRay.Hit or not isForwardWater then
        debugoverlay_Line( pos, forwardPos, 0.05, Color( 255, 0, 0, 1), false )
    else
        debugoverlay_Line( pos, forwardPos, 0.05, Color( 0, 255, 255, 1), false )
    end

    if forwardRay.Hit or not isForwardWater then
        local escapeDir = self:ObstacleRay()
        
        local sub = forwardRay.Hit and (1 - forwardRay.Fraction) or 0.8
        local repelPower = sub * 2 
        local repulsion = forwardRay.Hit and (forwardRay.HitNormal * repelPower) or (Vector(0, 0, -1) * 2)
        
        local finalEscape = GetNormalized( escapeDir + repulsion )

        local intensity = sub > 0 and sub or 0.8
        steer = LerpVector(intensity, steer, finalEscape * 10)
    end

    if not IsInWorld( self ) then
        local centerDir = GetNormalized( Vector(0,0,0) - pos )
        steer = centerDir * 20
    end

    if Length( steer ) > 1 then Normalize( steer ) end
    
    local currentDir = GetForward( self )
    local finalDir = GetNormalized( currentDir + steer * 0.1 )
    
    SetAngles( self, finalDir:Angle())
    SetPos( self, pos + finalDir * (SPEED:GetFloat() * FrameTime()) )
    NextThink( self, CurTime())

    debugoverlay.BoxAngles( self:GetPos(), self:OBBMins(), self:OBBMaxs(), self:GetAngles(), 0.05, Color( 255, 255, 0, 50 ) )

    return true
end

function ENT:SpawnFunction(ply, tr, ClassName)
    if not tr.Hit then return end
    
    local spawnPos = tr.HitPos + tr.HitNormal * 30
    
    if bit_band(util_PointContents(spawnPos), CONTENTS_WATER) != CONTENTS_WATER then
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