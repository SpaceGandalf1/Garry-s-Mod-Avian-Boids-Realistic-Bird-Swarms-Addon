ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Boid Base"
ENT.Author    = "Nayl & SpaceGandalf"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Bool", false, "Dead")
end

-- Intercept and silence Server-side animation events
function ENT:HandleAnimEvent( event, eventTime, cycle, type, options )
    return true 
end

-- Intercept and silence Client-side animation events
function ENT:FireAnimationEvent( pos, ang, event, options )
    return true
end
