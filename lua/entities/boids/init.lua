AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local CV = BoidShared.CreateConVars("boids")

local ATTACKING = CreateConVar("sv_boids_attacking", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Toggle boids hunting and attacking", 0, 1)
local HUNT_FISH = CreateConVar("sv_boids_hunt_fish", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Toggle boids hunting boidfish", 0, 1)
local HURT_PLAYERS = CreateConVar("sv_boids_hurt_players", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Toggle boids hurting players", 0, 1)
local MAX_HEIGHT = CreateConVar("sv_boids_max_height", "1500", {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Maximum height above ground", 100, 10000)

local BOID_SOUNDS = {
    ["models/crow.mdl"] = {
        idle = { "npc/crow/idle1.wav", "npc/crow/idle2.wav", "npc/crow/idle3.wav", "npc/crow/idle4.wav", "npc/crow/alert1.wav", "npc/crow/alert2.wav", "npc/crow/alert3.wav", "npc/crow/crow2.wav", "npc/crow/crow3.wav" },
        die = { "npc/crow/die1.wav", "npc/crow/die2.wav", "npc/crow/pain1.wav", "npc/crow/pain2.wav" }
    },
    ["models/seagull.mdl"] = {
        idle = { "ambient/creatures/seagull_idle1.wav", "ambient/creatures/seagull_idle2.wav", "ambient/creatures/seagull_idle3.wav" },
        die = { "ambient/creatures/seagull_pain1.wav", "ambient/creatures/seagull_pain2.wav", "ambient/creatures/seagull_pain3.wav" }
    },
    ["models/pigeon.mdl"] = {
        idle = { "npc/crow/idle1.wav" },
        die = { "npc/crow/die1.wav" }
    }
}

function ENT:SetBoidState(newState)
    if self.CurrentAnimState == newState then return end
    self.CurrentAnimState = newState

    local seqName = self:GetBoidAnim(newState)

    if self:LookupSequence(seqName) == -1 then
        seqName = self:GetBoidAnim("fly")
    end

    self:ResetSequence(seqName)

    if newState == "soar" then
        self:SetPlaybackRate(0.1)
    else
        self:SetPlaybackRate(1.0)
    end
end

function ENT:CustomInitialize()
    self:SetModel(CV.MODEL:GetString())
    self.CurrentAnimState = ""
    self:SetBoidState("fly")

    local bounds = CV.MINSMAXS_BOUNDS:GetFloat()
    local mins = -Vector(bounds,bounds,bounds)
    local maxs = -mins
    self:SetCollisionBounds( mins, maxs )

    self.mins, self.maxs = Vector( -20, -20, -20 ), Vector( 20, 20, 20 )

    self.UseDistanceCheck = CV.DISTANCE_CHECK:GetBool()
    self.DistanceCheckSqr = math.pow(CV.DISTANCE_CHECK_VALUE:GetInt(), 2)
    self.TraceLength = CV.TRACE_LEN:GetFloat()
    self.IsWaterBoid = false
end

function ENT:CustomDie(attacker, dmginfo)
    local sounds = BOID_SOUNDS[string.lower(self:GetModel() or "")]
    if sounds and sounds.die then
        self:EmitSound(sounds.die[math.random(1, #sounds.die)], 75, math.random(90, 110))
    end
end

function ENT:CustomThink()
    if BoidShared.PreThink(self, CV) then return true end

    local pos = self:GetPos()

    if self.LandedUntil then
        if CurTime() < self.LandedUntil then
            self:SetBoidState("idle")
            self:NextThink(CurTime() + 0.1)
            return true
        else
            self.LandedUntil = nil
            self.TakeoffUntil = CurTime() + 0.5

            self:SetBoidState("takeoff")
            self:SetPos(pos + Vector(0, 0, 20))
            local takeoffDir = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 1):GetNormalized()
            self:SetAngles(takeoffDir:Angle())

            self:NextThink(CurTime())
            return true
        end
    end

    if not self.NextIdleSound or CurTime() > self.NextIdleSound then
        self.NextIdleSound = CurTime() + math.Rand(2, 6)
        if math.random(1, 4) == 1 then
            local sounds = BOID_SOUNDS[string.lower(self:GetModel() or "")]
            if sounds and sounds.idle then
                self:EmitSound(sounds.idle[math.random(1, #sounds.idle)], 65, math.random(95, 105))
            end
        end
    end

    if ATTACKING:GetBool() then
        if not self.NextMeleeTick or CurTime() > self.NextMeleeTick then
            self.NextMeleeTick = CurTime() + 0.5

            local hitRadius = 175
            local nearbyEnts = ents.FindInSphere(pos, hitRadius)

            for _, hitEnt in ipairs(nearbyEnts) do
                if IsValid(hitEnt) and hitEnt != self and hitEnt:GetClass() != self:GetClass() then
                    if hitEnt:GetClass() == "boidfish" and HUNT_FISH:GetBool() then
                        if hitEnt.Die then hitEnt:Die(self, DamageInfo()) else hitEnt:Remove() end
                        self:EmitSound("npc/crow/alert2.wav", 75, 100)
                        self.HuntingTarget = nil
                    elseif (hitEnt:IsPlayer() or hitEnt:IsNPC() or hitEnt:IsNextBot()) and HURT_PLAYERS:GetBool() then
                        local dmg = DamageInfo()
                        dmg:SetDamage(5)
                        dmg:SetAttacker(self)
                        dmg:SetInflictor(self)
                        dmg:SetDamageType(DMG_SLASH)

                        hitEnt:TakeDamageInfo(dmg)
                        self:EmitSound("physics/flesh/flesh_impact_bullet" .. math.random(1, 3) .. ".wav", 65, math.random(95, 105))
                    end
                end
            end
        end

        if HUNT_FISH:GetBool() then
            if not self.NextVisionTick or CurTime() > self.NextVisionTick then
                self.NextVisionTick = CurTime() + 60.0

                if not IsValid(self.HuntingTarget) or self.HuntingTarget:GetDead() then
                    self.HuntingTarget = nil

                    local sightRadius = 500
                    local seenEnts = ents.FindInSphere(pos, sightRadius)
                    local closestDist = math.huge
                    local bestTarget = nil

                    for _, ent in ipairs(seenEnts) do
                        if IsValid(ent) and ent:GetClass() == "boidfish" and not ent:GetDead() then
                            local dirToTarget = (ent:GetPos() - pos):GetNormalized()

                            if self:GetForward():Dot(dirToTarget) > 0 then
                                local dist = pos:DistToSqr(ent:GetPos())
                                if dist < closestDist then
                                    closestDist = dist
                                    bestTarget = ent
                                end
                            end
                        end
                    end

                    if bestTarget then
                        self.HuntingTarget = bestTarget
                    end
                end
            end
        else
            self.HuntingTarget = nil
        end
    else
        self.HuntingTarget = nil
    end

    if self.TakeoffUntil then
        if CurTime() < self.TakeoffUntil then
            self:SetBoidState("takeoff")
        else
            self.TakeoffUntil = nil
            self.NextFlightAnimSwap = CurTime() + math.Rand(2, 5)
            self:SetBoidState("fly")
        end
    end

    if self.LandingTarget then
        if CurTime() > self.LandingTimeout then
            self.LandingTarget = nil
            self:SetBoidState("fly")
        elseif pos:DistToSqr(self.LandingTarget) < (45 * 45) then
            self.LandedUntil = CurTime() + math.Rand(3, 7)
            self.NextLandAllowed = self.LandedUntil + math.Rand(15, 30)
            self.LandingTarget = nil

            local snapTr = util.TraceLine({
                start = pos, endpos = pos - Vector(0,0,50), mask = MASK_SOLID, filter = self
            })
            if snapTr.Hit then self:SetPos(snapTr.HitPos) else self:SetPos(pos) end

            self:SetAngles(Angle(0, self:GetAngles().y, 0))
            self:SetBoidState("idle")

            self:NextThink(CurTime() + 0.1)
            return true
        else
            if pos:DistToSqr(self.LandingTarget) < (200 * 200) then
                self:SetBoidState("land")
            else
                self:SetBoidState("fly")
            end
        end
    else
        if IsValid(self.HuntingTarget) then
            if pos:DistToSqr(self.HuntingTarget:GetPos()) < (400 * 400) then
                self:SetBoidState("land")
            else
                self:SetBoidState("fly")
            end
        elseif not self.TakeoffUntil and not self.LandedUntil then
            if not self.NextFlightAnimSwap or CurTime() > self.NextFlightAnimSwap then
                self.NextFlightAnimSwap = CurTime() + math.Rand(3, 8)
                self:SetBoidState(math.random(1, 2) == 1 and "soar" or "fly")
            end
        end

        if not self.NextLandAllowed or CurTime() > self.NextLandAllowed then
            local landDist = CV.TRACE_LEN:GetFloat() * 1.2
            local downRay = util.TraceLine({
                start = pos,
                endpos = pos - Vector(0, 0, landDist),
                mask = MASK_SOLID,
                filter = function(ent) return self:NotMyNeighbors(ent) end
            })

            if downRay.Hit and downRay.HitNormal.z > 0.7 then
                if bit.band(util.PointContents(downRay.HitPos), CONTENTS_WATER) != CONTENTS_WATER then
                    self.LandingTarget = downRay.HitPos
                    self.LandingTimeout = CurTime() + 4
                end
            end
        end
    end

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

    if self.LandingTarget then
        local dirToTarget = (self.LandingTarget - pos):GetNormalized()
        steer = dirToTarget * 10
    elseif IsValid(self.HuntingTarget) then
        local dirToTarget = (self.HuntingTarget:GetPos() - pos):GetNormalized()
        steer = steer + (dirToTarget * 15)
    else
        steer = steer + VectorRand() * CV.NOISE_FACTOR:GetFloat()
    end

    local lookAheadDist = IsValid(self.HuntingTarget) and 50 or 150
    local lookAheadPos = pos + self:GetForward() * lookAheadDist

    if bit.band(util.PointContents(lookAheadPos), CONTENTS_WATER) == CONTENTS_WATER then
        if self.LandingTarget then
            self.LandingTarget = nil
            self:SetBoidState("fly")
        end
        if IsValid(self.HuntingTarget) then
            self.HuntingTarget = nil
            self:SetBoidState("fly")
        end
        steer = steer + Vector(0, 0, 20)
    end

    local heightTr = util.TraceLine({
        start = pos,
        endpos = pos - Vector(0, 0, MAX_HEIGHT:GetFloat()),
        mask = MASK_SOLID,
        filter = function(ent) return self:NotMyNeighbors(ent) end
    })

    if not heightTr.Hit then
        steer = steer + Vector(0, 0, -15)
    end

    if not self.LandingTarget then
        local floorTr = util.TraceHull({
            start = pos,
            endpos = pos - Vector(0, 0, 60),
            mins = Vector(-15, -15, -15),
            maxs = Vector(15, 15, 15),
            mask = MASK_SOLID_BRUSHONLY,
            filter = self
        })

        if floorTr.Hit then
            local pushForce = (1 - floorTr.Fraction) * 40
            steer = steer + Vector(0, 0, pushForce)

            if self:GetForward().z < -0.3 then
                steer = steer + Vector(0, 0, 20)
            end
        end
    end

    if steer:Length() > 1 then steer:Normalize() end

    local traceDist = self.LandingTarget and 30 or CV.TRACE_LEN:GetFloat()

    local forwardRay = util.TraceLine({
        start = pos,
        endpos = pos + self:GetForward() * traceDist,
        mask = MASK_ALL,
        filter = function(ent) return self:NotMyNeighbors(ent) end
    })

    if forwardRay.Hit then
        debugoverlay.Line( pos, forwardRay.HitPos, 0.05, Color( 255, 0, 0, 1), false )
    else
        debugoverlay.Line( pos, pos + self:GetForward() * traceDist, 0.05, Color( 0, 255, 255, 1), false )
    end

    if forwardRay.Hit then
        local escapeDir = self:ObstacleRay()
        local sub = (1 - forwardRay.Fraction)
        local repelPower = sub * 2
        local repulsion = forwardRay.HitNormal * repelPower
        local finalEscape = (escapeDir + repulsion):GetNormalized()

        steer = LerpVector(sub, steer, finalEscape * 10)
    end

    if not self:IsInWorld() then
        local centerDir = (Vector(0,0,0) - pos):GetNormalized()
        steer = centerDir * 20
    end

    if steer:Length() > 1 then steer:Normalize() end

    local currentSpeed = self.LandingTarget and (CV.SPEED:GetFloat() * 0.6) or CV.SPEED:GetFloat()
    if IsValid(self.HuntingTarget) then currentSpeed = CV.SPEED:GetFloat() * 1.5 end

    local finalDir = (self:GetForward() + steer * 0.1):GetNormalized()

    self:SetAngles(finalDir:Angle())
    self:SetPos(pos + finalDir * (currentSpeed * FrameTime()))
    self:NextThink(CurTime())

    debugoverlay.BoxAngles( self:GetPos(), self:OBBMins(), self:OBBMaxs(), self:GetAngles(), 0.05, Color( 255, 255, 0, 50 ) )

    return true
end

function ENT:SpawnFunction(ply, tr, ClassName)
    BoidShared.SpawnSchool(ply, tr, ClassName, {
        undoName = "Boids",
        normalOffset = 1000,
        count = CV.SPAWN_NUMBER:GetInt(),
        position = function(spawnPos) return spawnPos + VectorRand() * 30 end,
    })
end
