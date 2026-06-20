ENT.Type      = "anim"
ENT.Base      = "boidnest"
ENT.PrintName = "Boid Nest (Fish)"
ENT.Author    = "SpaceGandalf"
ENT.Spawnable = true
ENT.Category  = "Boids"

-- Inherits all spawn/top-up logic from boidnest; only the starting type differs.
ENT.StartMobClass = "boidfish"
ENT.NestColor     = Color(120, 180, 255)
