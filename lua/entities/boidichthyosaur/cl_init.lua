include("shared.lua")

function ENT:Initialize()
    self.lerp_pos = self:GetPos()
    self.mins, self.maxs = Vector( -40, -40, -40 ), Vector( 40, 40, 40 )
    self.dead = false
end

function ENT:Draw()
    self:DrawModel()
end

function ENT:MakeBoidRagdoll()
    -- Create an animated client-side model instead of a physics prop
    local prop = ClientsideModel(self:GetModel())
    if IsValid(prop) then
        prop:SetPos(self:GetPos())
        prop:SetAngles(self:GetAngles())
        
        -- Try to play the death animation!
        local seq = prop:LookupSequence("die")
        if seq and seq > 0 then
            prop:ResetSequence(seq)
            prop:SetPlaybackRate(1)
        end
        
        local startTime = CurTime()
        local startPos = self:GetPos()
        
        -- Bind a Think hook directly to this corpse to animate it and make it sink
        hook.Add("Think", prop, function()
            if not IsValid(prop) then return end
            
            -- Progress the death animation
            prop:FrameAdvance(FrameTime())
            
            -- Make it slowly sink at 25 units per second
            local elapsed = CurTime() - startTime
            prop:SetPos(startPos - Vector(0, 0, elapsed * 25))
        end)
        
        -- Clean up after 15 seconds
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

function ENT:Think()
    self.lerp_pos = LerpVector(FrameTime() * 100, self.lerp_pos, self:GetNetworkOrigin())

    if self:GetDead() and not self.dead then
        self:MakeBoidRagdoll()
        return
    end
end