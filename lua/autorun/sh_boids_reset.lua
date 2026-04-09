if SERVER then
    concommand.Add("boids_reset_server", function(ply, cmd, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then
            local msg = "You must be a superadmin to reset server-wide boid settings."
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end

        local server_convars = {
            -- Original Boids + New Settings
            "sv_boids_delete_on_escape_reality", "sv_boids_collision_avoidances", "sv_boids_alignment",
            "sv_boids_cohesion", "sv_boids_noise_factor", "sv_boids_separation_distances", "sv_boids_speed",
            "sv_boids_spawn_number", "sv_boids_trace_lengh", "sv_boids_model", "sv_boids_alignment_factor",
            "sv_boids_cohesion_factor", "sv_boids_separation_factor", "sv_boids_orbit_factor",
            "sv_boids_orbit_distance", "sv_boids_distance_check", "sv_boids_distance_check_value",
            "sv_boids_mins_maxs_bounds", "sv_boids_cell_size", "sv_boids_attacking",
            "sv_boids_hunt_fish", "sv_boids_hurt_players", "sv_boids_max_height",

            -- BoidFish
            "sv_boidfish_delete_on_escape_reality", "sv_boidfish_collision_avoidances", "sv_boidfish_alignment",
            "sv_boidfish_cohesion", "sv_boidfish_noise_factor", "sv_boidfish_separation_distances", "sv_boidfish_speed",
            "sv_boidfish_spawn_number", "sv_boidfish_trace_lengh", "sv_boidfish_model", "sv_boidfish_alignment_factor",
            "sv_boidfish_cohesion_factor", "sv_boidfish_separation_factor", "sv_boidfish_orbit_factor",
            "sv_boidfish_orbit_distance", "sv_boidfish_distance_check", "sv_boidfish_distance_check_value",
            "sv_boidfish_mins_maxs_bounds", "sv_boidfish_cell_size"
        }

        for _, name in ipairs(server_convars) do
            local cv = GetConVar(name)
            if cv then
                cv:Revert()
            end
        end

        local msg = "All server-side boid and fish settings have been reset to defaults."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end)
end

if CLIENT then
    concommand.Add("boids_reset_client", function(ply, cmd, args)
        local client_convars = {
            "cl_boids_ghost_amount", "cl_boids_ghost_distances", "cl_boids_ghost_distances_uniform",
            "cl_boidfish_ghost_amount", "cl_boidfish_ghost_distances", "cl_boidfish_ghost_distances_uniform"
        }

        for _, name in ipairs(client_convars) do
            local cv = GetConVar(name)
            if cv then
                cv:Revert()
            end
        end

        local msg = "All client-side boid and fish settings have been reset to defaults."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end)
end