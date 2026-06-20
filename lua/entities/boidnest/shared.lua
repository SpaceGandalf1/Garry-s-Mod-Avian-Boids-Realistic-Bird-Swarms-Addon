ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Boid Nest"
ENT.Author    = "SpaceGandalf"
ENT.Spawnable = true
ENT.Category  = "Boids"

-- Variants (boidnest_fish / boidnest_ichthyosaur) override these via ENT.Base.
ENT.StartMobClass = nil   -- class to begin on; nil = use sv_boidnest_mob_class
ENT.NestModel     = nil   -- per-variant model override; nil = use sv_boidnest_model
ENT.NestColor     = nil   -- per-variant tint so nests are distinguishable in-world

-- Mob types a nest can manage (class + whether it must spawn in water).
ENT.MobTypes = {
    { class = "boids",           water = false },
    { class = "boidfish",        water = true  },
    { class = "boidichthyosaur", water = true  },
}

function ENT:SetupDataTables()
    -- Per-nest settings, networked so the context-menu panel can read them live.
    self:NetworkVar("String", 0, "MobClass")
    self:NetworkVar("Int", 0, "Population")
    self:NetworkVar("Int", 1, "MaxPerTick")
    self:NetworkVar("Float", 0, "Radius")
    self:NetworkVar("Float", 1, "Interval")
end

function ENT:GetMobInfo()
    local class = self:GetMobClass()
    for _, t in ipairs(self.MobTypes) do
        if t.class == class then return t end
    end
    return nil
end

function ENT:IsManagedClass(class)
    for _, t in ipairs(self.MobTypes) do
        if t.class == class then return true end
    end
    return false
end
