BoidShared = BoidShared or {}

local REPLICATED = { FCVAR_REPLICATED, FCVAR_ARCHIVE }

-- Standard ConVar set shared by the flocking boid species (birds, fish, ...).
-- Each entry: { field, name suffix, default, flags, help, min, max }.
-- A species passes `overrides` keyed by field to change defaults (speed, model, ...).
local CONVAR_SPEC = {
    { "DELETE_ON_ESCAPE_REALITY", "delete_on_escape_reality", "0",   FCVAR_NONE, "Delete the boid when he's getting out of the world", 0, 1 },
    { "COLLISION_RULE",           "collision_avoidances",     "1",   FCVAR_NONE, "", 0, 1 },
    { "ALIGNMENT_RULE",           "alignment",                "1",   FCVAR_NONE, "", 0, 1 },
    { "COHESION_RULE",            "cohesion",                 "1",   FCVAR_NONE, "", 0, 1 },
    { "NOISE_FACTOR",             "noise_factor",             "0.5", FCVAR_NONE, "", 0, 1 },
    { "MIN_DIST",                 "separation_distances",     "5",   FCVAR_NONE, "", 2, 50 },
    { "SPEED",                    "speed",                    "600", REPLICATED, "", 0, 1000 },
    { "SPAWN_NUMBER",             "spawn_number",             "1",   FCVAR_NONE, "", 1, 100 },
    { "TRACE_LEN",                "trace_lengh",              "500", FCVAR_NONE, "", 10, 1000 },
    { "MODEL",                    "model",                    "models/crow.mdl", REPLICATED, "" },
    { "ALIGNMENT_FACTOR",         "alignment_factor",         "0.8", FCVAR_NONE, "", 1, 10 },
    { "COHESION_FACTOR",          "cohesion_factor",          "1.0", FCVAR_NONE, "", 1, 10 },
    { "SEPARATION_FACTOR",        "separation_factor",        "1.5", FCVAR_NONE, "", 1, 10 },
    { "ORBIT_FACTOR",             "orbit_factor",             "1.5", FCVAR_NONE, "", 0, 10 },
    { "ORBIT_DISTANCE",           "orbit_distance",           "200", FCVAR_NONE, "", 10, 2000 },
    { "DISTANCE_CHECK",           "distance_check",           "1",   FCVAR_NONE, "Check the distance between boids to consider them as neighbors.", 0, 1 },
    { "DISTANCE_CHECK_VALUE",     "distance_check_value",     "250", FCVAR_NONE, "", 100, 2000 },
    { "MINSMAXS_BOUNDS",          "mins_maxs_bounds",         "20",  FCVAR_NONE, "", 5, 50 },
}

-- Build the shared ConVar table for a species, e.g. CreateConVars("boidfish", { SPEED = "300" }).
function BoidShared.CreateConVars(prefix, overrides)
    overrides = overrides or {}

    local cv = {}
    for _, e in ipairs(CONVAR_SPEC) do
        local field, suffix, default, flags, help, min, max = e[1], e[2], e[3], e[4], e[5], e[6], e[7]
        if overrides[field] ~= nil then default = overrides[field] end
        cv[field] = CreateConVar("sv_" .. prefix .. "_" .. suffix, default, flags, help, min, max)
    end
    return cv
end

-- Client-side: wire up the ghost-flock ConVar accessors used by ent_boid_base.
function BoidShared.SetupGhostConVars(self, prefix, defaultSpeed)
    self.GhostAmount       = function() local cv = GetConVar("cl_" .. prefix .. "_ghost_amount");            return cv and cv:GetInt() or 0 end
    self.GhostDist         = function() local cv = GetConVar("cl_" .. prefix .. "_ghost_distances");         return cv and cv:GetInt() or 50 end
    self.GhostDistUniform  = function() local cv = GetConVar("cl_" .. prefix .. "_ghost_distances_uniform"); return cv and cv:GetBool() or true end
    self.BaseSpeed         = function() local cv = GetConVar("sv_" .. prefix .. "_speed");                   return cv and cv:GetFloat() or defaultSpeed end
end

-- Shared think helpers ------------------------------------------------------

-- Per-tick housekeeping: bail if the boid escaped the world, then refresh the
-- runtime tuning pulled from ConVars. Returns true if the entity was removed.
function BoidShared.PreThink(self, cv)
    if cv.DELETE_ON_ESCAPE_REALITY:GetBool() and not self:IsInWorld() then
        self:Remove()
        return true
    end

    self.UseDistanceCheck = cv.DISTANCE_CHECK:GetBool()
    self.DistanceCheckSqr = math.pow(cv.DISTANCE_CHECK_VALUE:GetInt(), 2)
    self.TraceLength = cv.TRACE_LEN:GetFloat()
    return false
end

-- Gather grid neighbors that are ahead of us (dot > 0), tagged with distance.
function BoidShared.GatherForwardNeighbors(self, pos)
    local forward = self:GetForward()
    local valid = {}

    for _, ent in ipairs(self:GetNearByOptimized()) do
        local diff = ent:GetPos() - pos
        local toNeighbor = diff:GetNormalized()

        if forward:Dot(toNeighbor) > 0 then
            valid[#valid + 1] = { ent = ent, dist = math.sqrt(diff:LengthSqr()) }
        end
    end

    return valid
end

-- Steering toward/around the nearest "orbit" entity, if one is far enough away.
function BoidShared.GetOrbitForce(pos, orbitDistance)
    local entities = BoidGrid.CachedOrbits
    if #entities < 1 then return Vector() end

    table.sort(entities, function(a, b) return pos:Distance2DSqr(a:GetPos()) < pos:Distance2DSqr(b:GetPos()) end)

    local targetPos = entities[1]:GetPos()
    if pos:Distance(targetPos) > orbitDistance then
        local dirToTarget = (targetPos - pos):GetNormalized()
        local orbitDir = dirToTarget:Cross(Vector(0, 0, 1)):GetNormalized()
        return (dirToTarget * 0.3) + (orbitDir * 1.0)
    end

    return Vector()
end

-- Shared SpawnFunction body. opts:
--   undoName     - undo label
--   requireWater - if true, refuse to spawn outside water (prints waterMessage)
--   waterMessage - chat message when the water check fails
--   normalOffset - distance along the surface normal for the base spawn point (default 30)
--   count        - how many to spawn (default 1)
--   position     - function(spawnPos, i) -> Vector for each entity (default: spawnPos)
function BoidShared.SpawnSchool(ply, tr, className, opts)
    if not tr.Hit then return end

    local spawnPos = tr.HitPos + tr.HitNormal * (opts.normalOffset or 30)

    if opts.requireWater and bit.band(util.PointContents(spawnPos), CONTENTS_WATER) != CONTENTS_WATER then
        if opts.waterMessage then ply:ChatPrint(opts.waterMessage) end
        return
    end

    undo.Create(opts.undoName)
        for i = 1, (opts.count or 1) do
            local ent = ents.Create(className)
            ent:SetPos(opts.position and opts.position(spawnPos, i) or spawnPos)
            ent:Spawn()
            ent:Activate()
            undo.AddEntity(ent)
        end
        undo.SetPlayer(ply)
    undo.Finish()
end
