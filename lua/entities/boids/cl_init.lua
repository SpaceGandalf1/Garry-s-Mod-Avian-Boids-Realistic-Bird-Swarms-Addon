include("shared.lua")

function ENT:CustomInitialize()
    BoidShared.SetupGhostConVars(self, "boids", 600)
end
