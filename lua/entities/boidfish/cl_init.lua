include("shared.lua")

function ENT:CustomInitialize()
    self.GhostAmount = function() local cv = GetConVar("cl_boidfish_ghost_amount"); return cv and cv:GetInt() or 0 end
    self.GhostDist = function() local cv = GetConVar("cl_boidfish_ghost_distances"); return cv and cv:GetInt() or 50 end
    self.GhostDistUniform = function() local cv = GetConVar("cl_boidfish_ghost_distances_uniform"); return cv and cv:GetBool() or true end
    self.BaseSpeed = function() local cv = GetConVar("sv_boidfish_speed"); return cv and cv:GetFloat() or 300 end
end

function ENT:CustomMakeRagdoll()
    local prop = ClientsideModel(self:GetModel())
    if IsValid(prop) then
        prop:SetPos(self:GetPos())
        prop:SetAngles(self:GetAngles())
        
        local spd = GetConVar("sv_boidfish_speed")
        local velocity = self:GetForward() * (spd and spd:GetFloat() * 0.5 or 150)
        local targetAng = Angle(math.random(-30, 30), math.random(-180, 180), 180)
        
        hook.Add("Think", prop, function()
            if not IsValid(prop) then return end
            
            velocity.x = Lerp(FrameTime() * 2, velocity.x, 0)
            velocity.y = Lerp(FrameTime() * 2, velocity.y, 0)
            
            if velocity.z ~= 0 then
                velocity.z = Lerp(FrameTime() * 1, velocity.z, -20)
            end
            
            local currentPos = prop:GetPos()
            local nextPos = currentPos + (velocity * FrameTime())
            
            local tr = util.TraceLine({
                start = currentPos,
                endpos = nextPos - Vector(0, 0, 4),
                mask = MASK_SOLID_BRUSHONLY
            })
            
            if tr.Hit then
                velocity = Vector(0, 0, 0)
                prop:SetPos(tr.HitPos + Vector(0, 0, 2)) 
            else
                prop:SetPos(nextPos)
                prop:SetAngles(LerpAngle(FrameTime() * 1.5, prop:GetAngles(), targetAng))
            end
        end)
        
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
