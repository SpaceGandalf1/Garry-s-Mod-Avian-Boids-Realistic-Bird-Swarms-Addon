ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Boid"
ENT.Author    = "Nayl"
ENT.Spawnable = true
ENT.Category  = "Boids"

-- The absolute animation dictionary for all 3 models
ENT.BoidAnimations = {
    ["models/crow.mdl"] = { fly = "fly01", idle = "idle01", takeoff = "Takeoff", land = "Land", soar = "Soar" },
    ["models/pigeon.mdl"] = { fly = "fly01", idle = "idle01", takeoff = "Takeoff", land = "Land", soar = "Soar" },
    
    -- Seagulls don't have takeoff/land/soar, so we map them to 'fly' to prevent T-posing
    ["models/seagull.mdl"] = { fly = "fly", idle = "idle01", takeoff = "fly", land = "fly", soar = "fly" }
}

function ENT:GetBoidAnim(animType)
    local mdl = string.lower(self:GetModel() or "")
    mdl = string.Replace(mdl, "\\", "/") -- Ensure slashes match exactly
    
    local anims = self.BoidAnimations[mdl]
    if anims and anims[animType] then
        return anims[animType]
    end
    
    -- Absolute fallback just in case of custom models
    if animType == "idle" then return "idle01" end
    return "fly01"
end

function ENT:SetupDataTables()
    self:NetworkVar("Bool", false, "Dead")
end

-- FIX: Intercept and silence Server-side animation events
function ENT:HandleAnimEvent( event, eventTime, cycle, type, options )
    return true 
end

-- FIX: Intercept and silence Client-side animation events (Stops the console spam!)
function ENT:FireAnimationEvent( pos, ang, event, options )
    return true
end