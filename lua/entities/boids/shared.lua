ENT.Type = "anim"
ENT.Base = "ent_boid_base"
ENT.PrintName = "Boid"
ENT.Author    = "Nayl"
ENT.Spawnable = true
ENT.Category  = "Boids"

ENT.BoidAnimations = {
    ["models/crow.mdl"] = { fly = "fly01", idle = "idle01", takeoff = "Takeoff", land = "Land", soar = "Soar" },
    ["models/pigeon.mdl"] = { fly = "fly01", idle = "idle01", takeoff = "Takeoff", land = "Land", soar = "Soar" },
    ["models/seagull.mdl"] = { fly = "fly", idle = "idle01", takeoff = "fly", land = "fly", soar = "fly" }
}

function ENT:GetBoidAnim(animType)
    local mdl = string.lower(self:GetModel() or "")
    mdl = string.Replace(mdl, "\\", "/")
    
    local anims = self.BoidAnimations[mdl]
    if anims and anims[animType] then
        return anims[animType]
    end
    
    if animType == "idle" then return "idle01" end
    return "fly01"
end
