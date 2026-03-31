ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Ichthyosaur (Hunter)"
ENT.Author    = "SpaceGandalf"
ENT.Spawnable = true
ENT.Category  = "Boids"

function ENT:SetupDataTables()
    self:NetworkVar("Bool", false, "Dead")
end