include("shared.lua")

hook.Add( "AddToolMenuCategories", "CustomCategoryFish", function()
    -- Merges with the birds category
    spawnmenu.AddToolCategory( "Utilities", "Boids_Category", "Boids" )
end )

local BOIDFISH_SPEED = GetConVar("sv_boidfish_speed")
local GHOST_NUMBER = CreateClientConVar("cl_boidfish_ghost_amount", "0", true, false, "", 0, 10)
local GHOST_DIST = CreateClientConVar("cl_boidfish_ghost_distances", "50", true, false, "", 10, 100)
local GHOST_DIST_UNIFORM = CreateClientConVar("cl_boidfish_ghost_distances_uniform", "1", true, false, "", 0, 1)
local GHOST_MODEL = GetConVar("sv_boidfish_model")

hook.Add( "PopulateToolMenu", "CustomMenuSettingsFish", function()
    spawnmenu.AddToolMenuOption( "Utilities", "Boids_Category", "BoidFish_Menu", "Fish Settings", "", "", function( panel )
        panel:Help("Configure the behavior and performance of the fish schools.")

        panel:AddControl("ComboBox", {
            MenuButton = 1,
            Folder = "boidfish_settings",
            Options = {
                ["Default (Ambient School)"] = {
                    sv_boidfish_collision_avoidances = "1",
                    sv_boidfish_alignment = "1",
                    sv_boidfish_cohesion = "1",
                    sv_boidfish_noise_factor = "0.5",
                    sv_boidfish_separation_factor = "1.5",
                    sv_boidfish_alignment_factor = "0.8",
                    sv_boidfish_cohesion_factor = "1.0",
                    sv_boidfish_orbit_factor = "1.5",
                    sv_boidfish_speed = "300",
                    sv_boidfish_trace_lengh = "200",
                    sv_boidfish_separation_distances = "5",
                    sv_boidfish_orbit_distance = "200",
                    sv_boidfish_spawn_number = "1"
                },
                ["Tight Swarm"] = {
                    sv_boidfish_collision_avoidances = "1",
                    sv_boidfish_alignment = "1",
                    sv_boidfish_cohesion = "1",
                    sv_boidfish_noise_factor = "0.2",
                    sv_boidfish_separation_factor = "1.0",
                    sv_boidfish_alignment_factor = "2.0",
                    sv_boidfish_cohesion_factor = "2.0",
                    sv_boidfish_orbit_factor = "1.0",
                    sv_boidfish_speed = "200",
                    sv_boidfish_trace_lengh = "200",
                    sv_boidfish_separation_distances = "3",
                    sv_boidfish_orbit_distance = "150",
                    sv_boidfish_spawn_number = "5"
                },
                ["Chaotic Frenzy"] = {
                    sv_boidfish_collision_avoidances = "1",
                    sv_boidfish_alignment = "0",
                    sv_boidfish_cohesion = "0",
                    sv_boidfish_noise_factor = "2.0",
                    sv_boidfish_separation_factor = "2.5",
                    sv_boidfish_alignment_factor = "0.1",
                    sv_boidfish_cohesion_factor = "0.1",
                    sv_boidfish_orbit_factor = "0.5",
                    sv_boidfish_speed = "500",
                    sv_boidfish_trace_lengh = "150",
                    sv_boidfish_separation_distances = "10",
                    sv_boidfish_orbit_distance = "300",
                    sv_boidfish_spawn_number = "3"
                }
            },
            CVars = {
                "sv_boidfish_collision_avoidances", "sv_boidfish_alignment", "sv_boidfish_cohesion",
                "sv_boidfish_noise_factor", "sv_boidfish_separation_factor", "sv_boidfish_alignment_factor",
                "sv_boidfish_cohesion_factor", "sv_boidfish_orbit_factor", "sv_boidfish_speed",
                "sv_boidfish_trace_lengh", "sv_boidfish_separation_distances", "sv_boidfish_orbit_distance",
                "sv_boidfish_spawn_number"
            }
        })

        panel:CheckBox("Enable Separation (Rule 1)", "sv_boidfish_collision_avoidances")
        panel:CheckBox("Enable Alignment (Rule 2)", "sv_boidfish_alignment")
        panel:CheckBox("Enable Cohesion (Rule 3)", "sv_boidfish_cohesion")
        panel:NumSlider("Random Noise (Wander)", "sv_boidfish_noise_factor", 0, 1, 2)
        panel:ControlHelp("Noise adds natural variation to the swim path.")

        panel:NumSlider("Separation Weight", "sv_boidfish_separation_factor", 0.2, 10, 1)
        panel:NumSlider("Alignment Weight", "sv_boidfish_alignment_factor", 0.2, 10, 1)
        panel:NumSlider("Cohesion Weight", "sv_boidfish_cohesion_factor", 0.2, 10, 1)
        panel:NumSlider("Orbit Weight", "sv_boidfish_orbit_factor", 0.2, 10, 1)

        panel:NumSlider("Swim Speed", "sv_boidfish_speed", 100, 1000, 0)
        panel:NumSlider("Wall Detection Distance", "sv_boidfish_trace_lengh", 10, 1000, 0)
        panel:NumSlider("Minimum Separation Dist", "sv_boidfish_separation_distances", 3, 50, 0)
        panel:NumSlider("Orbit Target Distance", "sv_boidfish_orbit_distance", 10, 2000, 0)

        local combobox = panel:ComboBox("Fish Model", "sv_boidfish_model")
        combobox:AddChoice("models/props/cs_militia/fish01.mdl")
        combobox:AddChoice("models/props/cs_militia/fishriver01.mdl")
        combobox:AddChoice("models/props/de_inferno/goldfish.mdl")

        panel:NumSlider("Fish per Spawn", "sv_boidfish_spawn_number", 1, 50, 0)

        panel:CheckBox("Enable Fine Distance Check", "sv_boidfish_distance_check")
        panel:ControlHelp("If off, fish see everyone in the grid cell (faster).")

        panel:NumSlider("Detection Radius", "sv_boidfish_distance_check_value", 100, 2000, 0)
        panel:NumSlider("Grid Cell Size", "sv_boidfish_cell_size", 50, 2000, 0)
        panel:ControlHelp("Warning: Cell size should be larger than Detection Radius.")

        panel:Help("\nGhost fish are entities that swim around the main fish without taking much performance from the server.")

        panel:NumSlider("Ghost Amount", "cl_boidfish_ghost_amount", 0, 10, 0)
        panel:CheckBox("Enable Uniform distances between fish", "cl_boidfish_ghost_distances_uniform")
        panel:NumSlider("Ghost Minimum Separation Dist", "cl_boidfish_ghost_distances", 10, 100, 0)
    end )
end )

function ENT:GenerateGhosts()
    if self.GhostBoids then
        for _,v in ipairs(self.GhostBoids) do
            if not IsValid(v) then continue end
            v:Remove()
        end
    end

    if GHOST_NUMBER:GetInt() <= 0 then return end

    self.GhostBoids = {}
    for i = 1, GHOST_NUMBER:GetInt() do
        local rand_vec = VectorRand()
        local cboid = ClientsideModel( self:GetModel() )
        self.GhostBoids[i] = cboid
        if not IsValid(cboid) then continue end
        cboid:SetNoDraw( true )
        cboid:ResetSequence(0)
        cboid:SetCycle( math.Rand(0,1) )
        cboid.dir = GHOST_DIST_UNIFORM:GetBool() and rand_vec:GetNormalized() or rand_vec * math.Rand(0,1) + rand_vec
        cboid.pos = self:GetPos() + cboid.dir * GHOST_DIST:GetInt()
    end
end

local callback_convar = {
    "cl_boidfish_ghost_amount",
    "cl_boidfish_ghost_distances_uniform"
}

for _,v in ipairs(callback_convar) do
    cvars.AddChangeCallback(v, function(convar_name, value_old, value_new)
        for _, ent in ipairs(ents.FindByClass("boidfish")) do
            ent:GenerateGhosts()
        end
    end)
end

function ENT:Initialize()
    self.lerp_pos = self:GetNetworkOrigin()
    self.mins, self.maxs = Vector( -20, -20, -20 ), Vector( 20, 20, 20 )
    self.dead = false

    self:GenerateGhosts()
end

function ENT:Draw()
    -- Smoothly render at the interpolated position
    if self.lerp_pos then
        self:SetRenderOrigin(self.lerp_pos)
    end

    self:DrawModel()

    if not self.GhostBoids then return end
    for _,v in ipairs(self.GhostBoids) do
        if not IsValid(v) then continue end
        v:DrawModel()
    end
end

function ENT:MakeBoidRagdoll()
    -- We use ClientsideModel instead of a physics prop so we can manually control its position
    local prop = ClientsideModel(self:GetModel())
    if IsValid(prop) then
        prop:SetPos(self:GetPos())
        prop:SetAngles(self:GetAngles())
        
        -- Start with some of the fish's forward speed
        local velocity = self:GetForward() * (GetConVar("sv_boidfish_speed"):GetFloat() * 0.5)
        
        -- The final resting angle (180 roll = belly up, with random pitch/yaw)
        local targetAng = Angle(math.random(-30, 30), math.random(-180, 180), 180)
        
        hook.Add("Think", prop, function()
            if not IsValid(prop) then return end
            
            -- 1. Water Friction: Smoothly slow down their horizontal forward movement
            velocity.x = Lerp(FrameTime() * 2, velocity.x, 0)
            velocity.y = Lerp(FrameTime() * 2, velocity.y, 0)
            
            -- Only apply gravity/sinking if it hasn't hit the floor yet
            if velocity.z ~= 0 then
                velocity.z = Lerp(FrameTime() * 1, velocity.z, -20)
            end
            
            local currentPos = prop:GetPos()
            local nextPos = currentPos + (velocity * FrameTime())
            
            -- 2. Floor Collision: Cast a ray slightly ahead and below to detect the seabed
            local tr = util.TraceLine({
                start = currentPos,
                endpos = nextPos - Vector(0, 0, 4), -- Look a bit down to account for the model's belly radius
                mask = MASK_SOLID_BRUSHONLY -- Only check against the map geometry for performance
            })
            
            if tr.Hit then
                -- Hit the floor! Stop all movement
                velocity = Vector(0, 0, 0)
                -- Rest exactly on the hit position, bumped up slightly so it doesn't z-fight with the dirt
                prop:SetPos(tr.HitPos + Vector(0, 0, 2)) 
            else
                -- Safe to keep sinking
                prop:SetPos(nextPos)
                
                -- 3. The Death Roll: Slowly roll belly-up while falling
                prop:SetAngles(LerpAngle(FrameTime() * 1.5, prop:GetAngles(), targetAng))
            end
        end)
        
        -- Clean up after 15 seconds
        timer.Simple(15, function() 
            if IsValid(prop) then prop:Remove() end 
        end)
    end

    self:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav")
    self.dead = true

    local blood = EffectData()
    blood:SetOrigin(self:GetPos())
    blood:SetScale(1)
    blood:SetFlags(3)
    util.Effect("BloodImpact", blood)
end

function ENT:Think()
    -- THE FIX: Safe Lerp multiplier and targeting the actual Network Origin
    self.lerp_pos = LerpVector(FrameTime() * 10, self.lerp_pos or self:GetNetworkOrigin(), self:GetNetworkOrigin())

    if self:GetDead() and not self.dead then
        self:MakeBoidRagdoll()
        return
    end

    if not self.GhostBoids then return end

    local parentSeq = self:GetSequence()

    for _,cboid in ipairs(self.GhostBoids) do
        if not IsValid(cboid) then continue end

        if cboid:GetSequence() != parentSeq then
            cboid:ResetSequence(parentSeq)
        end

        local targetPos = self:GetPos() + cboid.dir * GHOST_DIST:GetInt()
        cboid.pos = LerpVector(FrameTime() * 3, cboid.pos, targetPos)

        cboid:SetPos( cboid.pos )
        cboid:SetAngles( self:GetAngles() )
        cboid:FrameAdvance()
    end
end

function ENT:OnRemove( bool )
    if not self.GhostBoids then return end
    for i = 1, #self.GhostBoids do
        local cboid = self.GhostBoids[i]
        if not IsValid( cboid ) then continue end
        cboid:Remove()
    end
end