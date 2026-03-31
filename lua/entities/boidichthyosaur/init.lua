AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local SPEED_BASE = 300
local SPEED_HUNT_MIN = 500
local SPEED_HUNT_MAX = 1000
local TRACE_LEN = 400 
local HIT_RADIUS = 250 -- Super generous bite radius
local VISION_RADIUS = 1500
local NOISE_FACTOR = 0.2 

local NUM_DIRECTIONS = 36
local GOLDEN_RATIO = (1 + math.sqrt(5)) / 2
local ANGLE_INCREMENT = math.pi * 2 * GOLDEN_RATIO
local BoidDirections = {}

local MONSTER_SOUNDS = {
    idle = { "npc/ichthyosaur/water_breath.wav" },
    alert = { "npc/ichthyosaur/attack_growl1.wav", "npc/ichthyosaur/attack_growl2.wav" },
    bite = { "npc/ichthyosaur/snap.wav", "npc/ichthyosaur/snap_miss.wav" },
    die = { "npc/ichthyosaur/ichy_die1.wav", "npc/ichthyosaur/ichy_die2.wav", "npc/ichthyosaur/ichy_die4.wav" }
}

for i = 0, NUM_DIRECTIONS - 1 do
    local t = i / NUM_DIRECTIONS
    local inclination = math.acos(1 - 2 * t)
    local azimuth = ANGLE_INCREMENT * i
    local x = 1 - 2 * t
    local radius = math.sqrt(1 - x * x)
    table.insert(BoidDirections, Vector(x, math.sin(azimuth) * radius, math.cos(azimuth) * radius))
end

local Vector, Color, Angle, IsValid, CurTime, FrameTime, LerpVector, LocalToWorld = Vector, Color, Angle, IsValid, CurTime, FrameTime, LerpVector, LocalToWorld
local math_sqrt, math_random, math_floor = math.sqrt, math.random, math.floor
local util_TraceLine, util_TraceHull, util_PointContents, bit_band, ents_FindByClass = util.TraceLine, util.TraceHull, util.PointContents, bit.band, ents.FindByClass
local debugoverlay_Line = debugoverlay.Line
local ent_meta, vec_meta = FindMetaTable("Entity"), FindMetaTable("Vector")
local GetPos, SetPos, GetForward, GetAngles, SetAngles, NextThink, Remove = ent_meta.GetPos, ent_meta.SetPos, ent_meta.GetForward, ent_meta.GetAngles, ent_meta.SetAngles, ent_meta.NextThink, ent_meta.Remove
local Length, GetNormalized, Dot, Normalize = vec_meta.Length, vec_meta.GetNormalized, vec_meta.Dot, vec_meta.Normalize

function ENT:Initialize()
    self:SetLagCompensated( true )
    self:SetModel("models/ichthyosaur.mdl")

    self:PhysicsInit(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NOCLIP)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds( Vector(-40, -40, -40), Vector(40, 40, 40) )
    
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS) 

    self:SetAngles(Angle(math.random(-180, 180), math.random(-180, 180), 0))
    self:ResetSequence(self:LookupSequence("swim") or 0)
    self:SetCycle( math.Rand(0,1) )
    self:SetAutomaticFrameAdvance( true )

    self:SetMaxHealth(300)
    self:SetHealth(300)

    self.IdleLoop = CreateSound(self, MONSTER_SOUNDS.idle[1])
    if self.IdleLoop then
        self.IdleLoop:Play()
        self.IdleLoop:ChangeVolume(0.6, 0)
    end

    self.dead = false
end

function ENT:OnRemove()
    if self.IdleLoop then self.IdleLoop:Stop() end
end

function ENT:OnTakeDamage(dmginfo)
    if self:GetDead() then return end

    self:SetHealth(self:Health() - dmginfo:GetDamage())
    self:EmitSound("physics/flesh/flesh_impact_bullet" .. math.random(1, 5) .. ".wav", 75, math.random(90, 110))

    local attacker = dmginfo:GetAttacker()
    if IsValid(attacker) and (attacker:IsPlayer() or attacker:IsNPC() or attacker:IsNextBot()) then
        self.HuntingTarget = attacker
        self.NextVisionTick = CurTime() + 10 
        
        if math.random(1, 3) == 1 then
            self:EmitSound(MONSTER_SOUNDS.alert[math.random(1, #MONSTER_SOUNDS.alert)], 85, math.random(95, 105))
        end
    end

    if self:Health() <= 0 then
        self:Die(attacker)
    end
end

function ENT:Die(attacker)
    if self:GetDead() then return end
    
    self:SetDead(true)
    self.Killer = attacker
    
    if self.IdleLoop then self.IdleLoop:Stop() end
    
    self:EmitSound(MONSTER_SOUNDS.die[math.random(1, #MONSTER_SOUNDS.die)], 85, math.random(95, 105))
    
    -- MECHANIC 3: RESOURCE DROPS (Drops 3 health vials when killed)
    for i = 1, 3 do
        local meat = ents.Create("item_healthvial") -- You can change "item_healthvial" to your server's raw meat entity!
        if IsValid(meat) then
            meat:SetPos(self:GetPos() + Vector(math.random(-20, 20), math.random(-20, 20), 20))
            meat:Spawn()
            
            local phys = meat:GetPhysicsObject()
            if IsValid(phys) then
                phys:Wake()
                phys:SetVelocity(VectorRand() * 150 + Vector(0, 0, 200))
            end
        end
    end

    SafeRemoveEntityDelayed(self, 0.1)
end

function ENT:NotMyNeighbors( ent )
    if ent == self or ent:GetClass() == "boidichthyosaur" or ent:GetClass() == "boidfish" then return false end
    return true
end

function ENT:ObstacleRay()
    local pos = GetPos( self )
    local angles = GetAngles( self )
    
    for _, dir in ipairs(BoidDirections) do
        local worldDir = LocalToWorld(dir, Angle(0,0,0), Vector(0,0,0), angles)
        local testPos = pos + worldDir * TRACE_LEN
        
        local tr = util_TraceLine({
            start = pos, endpos = testPos, mask = MASK_SOLID, 
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
    if not self:IsInWorld() then Remove( self ) return end 

    local pos = GetPos( self )
    local steer = Vector(0,0,0)

    local otherMonsters = ents.FindInSphere(pos, 800)
    for _, other in ipairs(otherMonsters) do
        if IsValid(other) and other != self and other:GetClass() == "boidichthyosaur" then
            local flee = pos - other:GetPos()
            Normalize(flee)
            steer = steer + (flee * 5.0)
        end
    end

    if not self.NextMeleeTick or CurTime() > self.NextMeleeTick then
        self.NextMeleeTick = CurTime() + 0.5 
        local nearbyEnts = ents.FindInSphere(pos, HIT_RADIUS)
        
        for _, hitEnt in ipairs(nearbyEnts) do
            if IsValid(hitEnt) and hitEnt != self then
                if hitEnt:GetClass() == "boidfish" then
                    if hitEnt.Die then hitEnt:Die(self) else hitEnt:Remove() end
                    self:EmitSound(MONSTER_SOUNDS.bite[math.random(1, #MONSTER_SOUNDS.bite)], 80, 100)
                    self.HuntingTarget = nil 
                elseif hitEnt:IsPlayer() or hitEnt:IsNPC() or hitEnt:IsNextBot() then
                    
                    local hpBefore = hitEnt:Health()
                    
                    local dmg = DamageInfo()
                    dmg:SetDamage(25) 
                    dmg:SetAttacker(self)
                    dmg:SetInflictor(self)
                    dmg:SetDamageType(bit.bor(DMG_SLASH, DMG_CRUSH)) 
                    dmg:SetDamagePosition(self:GetPos())
                    
                    hitEnt:TakeDamageInfo(dmg)
                    self:EmitSound(MONSTER_SOUNDS.bite[math.random(1, #MONSTER_SOUNDS.bite)], 85, math.random(95, 105))

                    -- The Brute Force Fallback (Guarantees damage in Stranded)
                    if hitEnt:IsPlayer() and hitEnt:Alive() and hitEnt:Health() >= hpBefore then
                        local newHP = hitEnt:Health() - 25
                        if newHP <= 0 then
                            hitEnt:Kill() 
                        else
                            hitEnt:SetHealth(newHP) 
                        end
                    end

                    -- Depth Drag Mechanic
                    hitEnt:SetVelocity(Vector(0, 0, -350))
                    
                elseif hitEnt:GetClass() == "prop_physics" then
                    local phys = hitEnt:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:ApplyForceOffset(Vector(0, 0, phys:GetMass() * 500), self:GetPos())
                        self:EmitSound("physics/wood/wood_box_impact_hard3.wav", 85, 80)
                    end
                end
            end
        end
    end

    if not self.NextVisionTick or CurTime() > self.NextVisionTick then
        self.NextVisionTick = CurTime() + 2.0 
        
        local closestDist = math.huge
        local bestTarget = nil

        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                -- Hunts players in the water OR standing on rafts just above it!
                local pPos = ply:GetPos()
                local inWater = ply:WaterLevel() >= 1
                local hoveringOverWater = bit_band(util_PointContents(pPos - Vector(0,0,80)), CONTENTS_WATER) == CONTENTS_WATER
                
                if inWater or hoveringOverWater then
                    local distToPlayer = pos:DistToSqr(pPos)
                    
                    local amIClosest = true
                    for _, otherMonster in ipairs(ents.FindByClass("boidichthyosaur")) do
                        if IsValid(otherMonster) and otherMonster ~= self then
                            if otherMonster:GetPos():DistToSqr(pPos) < distToPlayer then
                                amIClosest = false
                                break
                            end
                        end
                    end

                    if amIClosest and distToPlayer < closestDist then
                        closestDist = distToPlayer
                        bestTarget = ply
                    end
                end
            end
        end

        if not bestTarget then
            local seenEnts = ents.FindInSphere(pos, VISION_RADIUS)
            for _, ent in ipairs(seenEnts) do
                if IsValid(ent) and (ent:GetClass() == "boidfish" or (ent:IsPlayer() and ent:Alive())) then
                    local dirToTarget = (ent:GetPos() - pos):GetNormalized()
                    
                    if Dot(GetForward(self), dirToTarget) > 0.3 then 
                        local dist = pos:DistToSqr(ent:GetPos())
                        if dist < closestDist then
                            closestDist = dist
                            bestTarget = ent
                        end
                    end
                end
            end
        end
        
        if bestTarget and self.HuntingTarget ~= bestTarget then
            self:EmitSound(MONSTER_SOUNDS.alert[math.random(1, #MONSTER_SOUNDS.alert)], 85, 100)
        end
        
        self.HuntingTarget = bestTarget
    end

    if not self.NextIdleSound or CurTime() > self.NextIdleSound then
        self.NextIdleSound = CurTime() + math.Rand(4, 10) 
        if not IsValid(self.HuntingTarget) and math.random(1, 3) == 1 then 
            self:EmitSound(MONSTER_SOUNDS.idle[1], 75, math.random(95, 105))
        end
    end

    if IsValid(self.HuntingTarget) then
        local dirToTarget = GetNormalized(self.HuntingTarget:GetPos() - pos)
        steer = steer + (dirToTarget * 10)
    else
        -- THE SERPENTINE + NOISE PATROL
        -- 1. Create the base sweeping "S" curve using time
       local sweepX = math.sin(CurTime() * 0.8) 
        local sweepY = math.cos(CurTime() * 0.5)
        local sweepZ = math.cos(CurTime() * 0.25) 
        local serpentine = Vector(sweepX, sweepY, sweepZ) * 2.0
        
        -- 2. Combine the sweeping curve with the organic random jitter
        steer = steer + serpentine + (VectorRand() * NOISE_FACTOR)
    end

    if Length( steer ) > 1 then Normalize( steer ) end
    
    local forwardPos = pos + GetForward( self ) * TRACE_LEN
    
    local forwardRay = util_TraceHull({
        start = pos, 
        endpos = forwardPos, 
        mins = Vector(-30, -30, -30),
        maxs = Vector(30, 30, 30),
        mask = MASK_SOLID, 
        filter = function(ent) return self:NotMyNeighbors(ent) end
    })
    
    local isForwardWater = bit_band(util_PointContents(forwardPos), CONTENTS_WATER) == CONTENTS_WATER
    
    local surfaceCheckPos = pos + Vector(0, 0, 40)
    local isSurfaceClose = bit_band(util_PointContents(surfaceCheckPos), CONTENTS_WATER) != CONTENTS_WATER
    
    if isSurfaceClose then
        -- ONLY push the monster down if it is NOT hunting a player!
        if not IsValid(self.HuntingTarget) or not self.HuntingTarget:IsPlayer() then
            steer = steer + Vector(0, 0, -15) 
            if IsValid(self.HuntingTarget) and self.HuntingTarget:GetClass() == "boidfish" then
                self.HuntingTarget = nil 
            end
        end
    end

    if forwardRay.Hit or not isForwardWater then
        debugoverlay_Line( pos, forwardRay.HitPos, 0.05, Color( 255, 0, 0, 1), false )
    else
        debugoverlay_Line( pos, forwardPos, 0.05, Color( 0, 255, 255, 1), false )
    end

    local turnRate = 0.05 

    if forwardRay.Hit or not isForwardWater then
        local escapeDir = self:ObstacleRay()
        local sub = forwardRay.Hit and (1 - forwardRay.Fraction) or 0.8
        
        local repulsion = forwardRay.Hit and (forwardRay.HitNormal * (sub * 5)) or (Vector(0, 0, -2) * 5)
        local finalEscape = GetNormalized( escapeDir + repulsion )
        
        steer = LerpVector(sub > 0 and sub or 0.8, steer, finalEscape * 40)
        
        turnRate = 0.15
        
        if not isForwardWater then self.HuntingTarget = nil end
    end

    if not self:IsInWorld() then
        steer = GetNormalized( Vector(0,0,0) - pos ) * 20
    end

    if Length( steer ) > 1 then Normalize( steer ) end
    
    local currentSpeed = SPEED_BASE
    
    if IsValid(self.HuntingTarget) then
        local distToTarget = pos:Distance(self.HuntingTarget:GetPos())
        local speedScale = math.Clamp(distToTarget / 4000, 0, 1)
        currentSpeed = Lerp(speedScale, SPEED_HUNT_MIN, SPEED_HUNT_MAX)
        self:SetPlaybackRate(currentSpeed / 250) 
    else
        self:SetPlaybackRate(1.0)
    end
    
    local currentDir = GetForward( self )
    local finalDir = GetNormalized( currentDir + steer * turnRate )
    
    SetAngles( self, finalDir:Angle())
    SetPos( self, pos + finalDir * (currentSpeed * FrameTime()) )
    NextThink( self, CurTime())

    debugoverlay.BoxAngles( self:GetPos(), self:OBBMins(), self:OBBMaxs(), self:GetAngles(), 0.05, Color( 255, 255, 0, 50 ) )

    return true
end

function ENT:SpawnFunction(ply, tr, ClassName)
    if not tr.Hit then return end
    local spawnPos = tr.HitPos + tr.HitNormal * 30
    
    if bit_band(util_PointContents(spawnPos), CONTENTS_WATER) != CONTENTS_WATER then
        ply:ChatPrint("The Ichthyosaur must be spawned in deep water!")
        return
    end

    undo.Create("Ichthyosaur")
        local ent = ents.Create(ClassName)
        ent:SetPos(spawnPos + Vector(0,0,50))
        ent:Spawn()
        ent:Activate()
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
    undo.Finish()
end