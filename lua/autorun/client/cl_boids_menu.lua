hook.Add( "AddToolMenuCategories", "CustomCategory", function()
    spawnmenu.AddToolCategory( "Utilities", "Boids_Category", "Boids" )
end )

local GHOST_NUMBER = CreateClientConVar("cl_boids_ghost_amount", "0", true, false, "", 0, 10)
local GHOST_DIST = CreateClientConVar("cl_boids_ghost_distances", "50", true, false, "", 10, 100)
local GHOST_DIST_UNIFORM = CreateClientConVar("cl_boids_ghost_distances_uniform", "1", true, false, "", 0, 1)

local FISH_GHOST_NUMBER = CreateClientConVar("cl_boidfish_ghost_amount", "0", true, false, "", 0, 10)
local FISH_GHOST_DIST = CreateClientConVar("cl_boidfish_ghost_distances", "50", true, false, "", 10, 100)
local FISH_GHOST_DIST_UNIFORM = CreateClientConVar("cl_boidfish_ghost_distances_uniform", "1", true, false, "", 0, 1)

hook.Add( "PopulateToolMenu", "CustomMenuSettingsBoidsAndFish", function()
    spawnmenu.AddToolMenuOption( "Utilities", "Boids_Category", "Boids_Menu", "Birds Settings", "", "", function( panel )
        panel:Help("Configure the behavior and performance of the bird swarms.")

        panel:AddControl("ComboBox", {
            MenuButton = 1,
            Folder = "boids_settings",
            Options = {
                ["Default (Ambient Flock)"] = {
                    sv_boids_attacking = "1",
                    sv_boids_hunt_fish = "1",
                    sv_boids_hurt_players = "1",
                    sv_boids_collision_avoidances = "1",
                    sv_boids_alignment = "1",
                    sv_boids_cohesion = "1",
                    sv_boids_noise_factor = "0.5",
                    sv_boids_separation_factor = "1.5",
                    sv_boids_alignment_factor = "0.8",
                    sv_boids_cohesion_factor = "1.0",
                    sv_boids_orbit_factor = "1.5",
                    sv_boids_speed = "600",
                    sv_boids_trace_lengh = "500",
                    sv_boids_separation_distances = "5",
                    sv_boids_orbit_distance = "200",
                    sv_boids_spawn_number = "1",
                    sv_boids_max_height = "1500"
                },
                ["Tight V-Formation"] = {
                    sv_boids_attacking = "0", 
                    sv_boids_hunt_fish = "0",
                    sv_boids_hurt_players = "0",
                    sv_boids_collision_avoidances = "1",
                    sv_boids_alignment = "1",
                    sv_boids_cohesion = "1",
                    sv_boids_noise_factor = "0.1",
                    sv_boids_separation_factor = "0.8",
                    sv_boids_alignment_factor = "2.5",
                    sv_boids_cohesion_factor = "2.0",
                    sv_boids_orbit_factor = "1.0",
                    sv_boids_speed = "450",
                    sv_boids_trace_lengh = "500",
                    sv_boids_separation_distances = "4",
                    sv_boids_orbit_distance = "300",
                    sv_boids_spawn_number = "5",
                    sv_boids_max_height = "2000"
                },
                ["Chaotic Swarm"] = {
                    sv_boids_attacking = "1",
                    sv_boids_hunt_fish = "1",
                    sv_boids_hurt_players = "1",
                    sv_boids_collision_avoidances = "1",
                    sv_boids_alignment = "0", 
                    sv_boids_cohesion = "0",  
                    sv_boids_noise_factor = "2.0",
                    sv_boids_separation_factor = "2.0",
                    sv_boids_alignment_factor = "0.1",
                    sv_boids_cohesion_factor = "0.1",
                    sv_boids_orbit_factor = "0.5",
                    sv_boids_speed = "800",
                    sv_boids_trace_lengh = "300",
                    sv_boids_separation_distances = "15",
                    sv_boids_orbit_distance = "500",
                    sv_boids_spawn_number = "3",
                    sv_boids_max_height = "3000"
                }
            },
            CVars = {
                "sv_boids_attacking", "sv_boids_hunt_fish", "sv_boids_hurt_players", 
                "sv_boids_collision_avoidances", "sv_boids_alignment", "sv_boids_cohesion",
                "sv_boids_noise_factor", "sv_boids_separation_factor", "sv_boids_alignment_factor",
                "sv_boids_cohesion_factor", "sv_boids_orbit_factor", "sv_boids_speed",
                "sv_boids_trace_lengh", "sv_boids_separation_distances", "sv_boids_orbit_distance",
                "sv_boids_spawn_number", "sv_boids_max_height"
            }
        })

        panel:CheckBox("Master Switch: Enable Attacking", "sv_boids_attacking")
        panel:CheckBox("Hunt BoidFish", "sv_boids_hunt_fish")
        panel:CheckBox("Hurt Players & NPCs", "sv_boids_hurt_players")
        panel:NumSlider("Maximum Flight Height", "sv_boids_max_height", 100, 10000, 0)
        panel:ControlHelp("Prevents birds from flying endlessly up into the skybox.")

        panel:CheckBox("Enable Separation (Rule 1)", "sv_boids_collision_avoidances")
        panel:CheckBox("Enable Alignment (Rule 2)", "sv_boids_alignment")
        panel:CheckBox("Enable Cohesion (Rule 3)", "sv_boids_cohesion")
        panel:NumSlider("Random Noise (Wander)", "sv_boids_noise_factor", 0, 1, 2)
        panel:ControlHelp("Noise adds natural variation to the flight path.")

        panel:NumSlider("Separation Weight", "sv_boids_separation_factor", 0.2, 10, 1)
        panel:NumSlider("Alignment Weight", "sv_boids_alignment_factor", 0.2, 10, 1)
        panel:NumSlider("Cohesion Weight", "sv_boids_cohesion_factor", 0.2, 10, 1)
        panel:NumSlider("Orbit Weight", "sv_boids_orbit_factor", 0.2, 10, 1)

        panel:NumSlider("Flight Speed", "sv_boids_speed", 100, 1000, 0)
        panel:NumSlider("Wall Detection Distance", "sv_boids_trace_lengh", 10, 1000, 0)
        panel:NumSlider("Minimum Separation Dist", "sv_boids_separation_distances", 3, 50, 0)
        panel:NumSlider("Orbit Target Distance", "sv_boids_orbit_distance", 10, 2000, 0)

        local combobox = panel:ComboBox("Boid Model", "sv_boids_model")
        combobox:AddChoice("models/crow.mdl")
        combobox:AddChoice("models/pigeon.mdl")
        combobox:AddChoice("models/seagull.mdl")

        panel:NumSlider("Birds per Spawn", "sv_boids_spawn_number", 1, 50, 0)

        panel:CheckBox("Enable Fine Distance Check", "sv_boids_distance_check")
        panel:ControlHelp("If off, boids see everyone in the grid cell (faster).")

        panel:NumSlider("Detection Radius", "sv_boids_distance_check_value", 100, 2000, 0)

        panel:Help("\nGhost boids are entities that fly around the boid without taking much performance from the server.")

        panel:NumSlider("Ghost Amount", "cl_boids_ghost_amount", 0, 10, 0)
        panel:CheckBox("Enable Uniform distances between boids", "cl_boids_ghost_distances_uniform")
        panel:NumSlider("Ghost Minimum Separation Dist", "cl_boids_ghost_distances", 10, 100, 0)
        
        panel:NumSlider("Global Grid Cell Size", "sv_boids_master_cell_size", 50, 2000, 0)
    end )
    
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

        panel:Help("\nGhost fish are entities that swim around the main fish without taking much performance from the server.")

        panel:NumSlider("Ghost Amount", "cl_boidfish_ghost_amount", 0, 10, 0)
        panel:CheckBox("Enable Uniform distances between fish", "cl_boidfish_ghost_distances_uniform")
        panel:NumSlider("Ghost Minimum Separation Dist", "cl_boidfish_ghost_distances", 10, 100, 0)
        
        panel:NumSlider("Global Grid Cell Size", "sv_boids_master_cell_size", 50, 2000, 0)
    end )
end )

local callback_convar = {
    "cl_boids_ghost_amount",
    "cl_boids_ghost_distances_uniform"
}

for _,v in ipairs(callback_convar) do
    cvars.AddChangeCallback(v, function(convar_name, value_old, value_new)
        for _, ent in ipairs(ents.FindByClass("boids")) do
            if ent.GenerateGhosts then ent:GenerateGhosts() end
        end
    end)
end

local callback_convar_fish = {
    "cl_boidfish_ghost_amount",
    "cl_boidfish_ghost_distances_uniform"
}

for _,v in ipairs(callback_convar_fish) do
    cvars.AddChangeCallback(v, function(convar_name, value_old, value_new)
        for _, ent in ipairs(ents.FindByClass("boidfish")) do
            if ent.GenerateGhosts then ent:GenerateGhosts() end
        end
    end)
end
