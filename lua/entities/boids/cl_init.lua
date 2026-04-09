include("shared.lua")

function ENT:CustomInitialize()
    self.GhostAmount = function() return GetConVar("cl_boids_ghost_amount"):GetInt() end
    self.GhostDist = function() return GetConVar("cl_boids_ghost_distances"):GetInt() end
    self.GhostDistUniform = function() return GetConVar("cl_boids_ghost_distances_uniform"):GetBool() end
    self.BaseSpeed = function() return GetConVar("sv_boids_speed"):GetFloat() end
end
