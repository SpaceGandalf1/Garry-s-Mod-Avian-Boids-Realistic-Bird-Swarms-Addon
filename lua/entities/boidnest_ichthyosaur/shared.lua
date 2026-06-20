ENT.Type      = "anim"
ENT.Base      = "boidnest"
ENT.PrintName = "Boid Nest (Ichthyosaur)"
ENT.Author    = "SpaceGandalf"
ENT.Spawnable = true
ENT.Category  = "Boids"

-- Inherits all spawn/top-up logic from boidnest; only the starting type differs.
ENT.StartMobClass = "boidichthyosaur"
ENT.NestColor     = Color(255, 120, 120)
