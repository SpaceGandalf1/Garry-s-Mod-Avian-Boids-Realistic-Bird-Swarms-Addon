AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local POPULATION = CreateConVar("sv_boidnest_population", "10", FCVAR_ARCHIVE, "Target number of mobs each nest keeps alive", 0, 200)
local RADIUS     = CreateConVar("sv_boidnest_radius", "600", FCVAR_ARCHIVE, "Spawn radius around the nest", 50, 5000)
local INTERVAL   = CreateConVar("sv_boidnest_interval", "2", FCVAR_ARCHIVE, "Seconds between population checks", 0.5, 30)
local MAX_PER_TICK = CreateConVar("sv_boidnest_max_per_tick", "5", FCVAR_ARCHIVE, "Cap spawns per check to avoid hitches", 1, 50)
local DEFAULT_CLASS = CreateConVar("sv_boidnest_mob_class", "boids", FCVAR_ARCHIVE, "Mob class new nests start with")
local NEST_MODEL = CreateConVar("sv_boidnest_model", "models/props_junk/wood_crate001a.mdl", FCVAR_ARCHIVE, "Model used by the nest entity")

util.AddNetworkString("boidnest_set")

local function NestPhysics(self)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end

function ENT:Initialize()
    self:SetModel(self.NestModel or NEST_MODEL:GetString())
    NestPhysics(self)

    if self.NestColor then self:SetColor(self.NestColor) end

    self.Brood = {}

    -- The convars are the defaults for new nests; each nest then keeps its own values.
    self:SetPopulation(POPULATION:GetInt())
    self:SetRadius(RADIUS:GetFloat())
    self:SetInterval(INTERVAL:GetFloat())
    self:SetMaxPerTick(MAX_PER_TICK:GetInt())

    -- Variants set StartMobClass; the base nest falls back to the convar default.
    self:SetMobClass(self.StartMobClass or DEFAULT_CLASS:GetString())
    if not self:GetMobInfo() then
        self:SetMobClass(self.MobTypes[1].class)
    end
end

-- Apply settings sent from the context-menu panel (already validated/clamped here).
function ENT:ApplySettings(pop, radius, interval, maxtick, class, model)
    self:SetPopulation(math.Clamp(pop, 0, 200))
    self:SetRadius(math.Clamp(radius, 50, 5000))
    self:SetInterval(math.Clamp(interval, 0.5, 30))
    self:SetMaxPerTick(math.Clamp(maxtick, 1, 50))

    if class ~= self:GetMobClass() and self:IsManagedClass(class) then
        self:ClearBrood()
        self:SetMobClass(class)
    end

    if model ~= "" and model ~= self:GetModel() and util.IsValidModel(model) then
        self:SetModel(model)
        NestPhysics(self)
        if self.NestColor then self:SetColor(self.NestColor) end
    end
end

function ENT:ClearBrood()
    for _, ent in ipairs(self.Brood) do
        if IsValid(ent) then ent:Remove() end
    end
    self.Brood = {}
end

-- Prune dead/removed mobs and return the ones still counting toward the target.
function ENT:GetLivingBrood()
    local living = {}
    for _, ent in ipairs(self.Brood) do
        if IsValid(ent) and not (ent.GetDead and ent:GetDead()) then
            living[#living + 1] = ent
        end
    end
    self.Brood = living
    return living
end

-- Find a valid spawn point in the radius: above-ground for fliers, in water for swimmers.
function ENT:FindSpawnPos(info)
    local origin = self:GetPos()
    local radius = self:GetRadius()

    for _ = 1, 12 do
        local dir = VectorRand()
        if not info.water then dir.z = math.abs(dir.z) + 0.3 end
        local pos = origin + dir:GetNormalized() * radius * math.Rand(0.3, 1)

        if info.water then
            if bit.band(util.PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER then
                return pos
            end
        elseif util.IsInWorld(pos) then
            return pos
        end
    end

    return nil
end

function ENT:SpawnOne(info)
    local pos = self:FindSpawnPos(info)
    if not pos then return nil end

    local ent = ents.Create(info.class)
    if not IsValid(ent) then return nil end

    ent:SetPos(pos)
    ent:Spawn()
    ent:Activate()
    return ent
end

function ENT:Think()
    local info = self:GetMobInfo()
    if info then
        local living = self:GetLivingBrood()
        local deficit = self:GetPopulation() - #living
        local budget = math.min(deficit, self:GetMaxPerTick())

        for _ = 1, budget do
            local ent = self:SpawnOne(info)
            if IsValid(ent) then self.Brood[#self.Brood + 1] = ent end
        end
    end

    self:NextThink(CurTime() + self:GetInterval())
    return true
end

function ENT:OnRemove()
    self:ClearBrood()
end

local NEST_CLASSES = {
    boidnest = true,
    boidnest_fish = true,
    boidnest_ichthyosaur = true,
}

net.Receive("boidnest_set", function(len, ply)
    local ent = net.ReadEntity()
    if not IsValid(ent) or not NEST_CLASSES[ent:GetClass()] then return end
    -- Only let admins (or the singleplayer host) reconfigure nests.
    if not (IsValid(ply) and (ply:IsAdmin() or game.SinglePlayer())) then return end

    local pop      = net.ReadUInt(16)
    local radius   = net.ReadFloat()
    local interval = net.ReadFloat()
    local maxtick  = net.ReadUInt(8)
    local class    = net.ReadString()
    local model    = net.ReadString()

    ent:ApplySettings(pop, radius, interval, maxtick, class, model)
end)
