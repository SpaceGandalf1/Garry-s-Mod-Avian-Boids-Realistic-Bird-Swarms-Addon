include("shared.lua")

function ENT:CustomInitialize()
    self.GhostAmount = function() local cv = GetConVar("cl_boids_ghost_amount"); return cv and cv:GetInt() or 0 end
    self.GhostDist = function() local cv = GetConVar("cl_boids_ghost_distances"); return cv and cv:GetInt() or 50 end
    self.GhostDistUniform = function() local cv = GetConVar("cl_boids_ghost_distances_uniform"); return cv and cv:GetBool() or true end
    self.BaseSpeed = function() local cv = GetConVar("sv_boids_speed"); return cv and cv:GetFloat() or 600 end
end
