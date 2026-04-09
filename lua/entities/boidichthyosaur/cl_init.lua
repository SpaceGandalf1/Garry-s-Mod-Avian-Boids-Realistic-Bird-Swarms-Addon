include("shared.lua")

function ENT:CustomInitialize()
    self.lerp_pos = self:GetPos()
    self.mins, self.maxs = Vector( -40, -40, -40 ), Vector( 40, 40, 40 )
end

function ENT:CustomMakeRagdoll()
    local prop = ClientsideModel(self:GetModel())
    if IsValid(prop) then
        prop:SetPos(self:GetPos())
        prop:SetAngles(self:GetAngles())
        
        local seq = prop:LookupSequence("die")
        if seq and seq > 0 then
            prop:ResetSequence(seq)
            prop:SetPlaybackRate(1)
        end
        
        local startTime = CurTime()
        local startPos = self:GetPos()
        
        hook.Add("Think", prop, function()
            if not IsValid(prop) then return end
            
            prop:FrameAdvance(FrameTime())
            
            local elapsed = CurTime() - startTime
            prop:SetPos(startPos - Vector(0, 0, elapsed * 25))
        end)
        
        timer.Simple(15, function() 
            if IsValid(prop) then prop:Remove() end 
        end)
    end

    self:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav", 85, 80)
    self.dead = true

    local blood = EffectData()
    blood:SetOrigin(self:GetPos())
    blood:SetScale(3) 
    blood:SetFlags(3)
    util.Effect("BloodImpact", blood)
end
