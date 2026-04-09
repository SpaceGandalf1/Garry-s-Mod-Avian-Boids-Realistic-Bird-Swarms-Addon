include("shared.lua")

function ENT:Initialize()
    self.lerp_pos = self:GetPos()
    self.dead = false

    if self.CustomInitialize then
        self:CustomInitialize()
    end

    self:GenerateGhosts()
end

function ENT:GenerateGhosts()
    if self.GhostBoids then
        for _,v in ipairs(self.GhostBoids) do
            if not IsValid(v) then continue end
            v:Remove()
        end
    end

    if not self.GhostAmount or self.GhostAmount() <= 0 then return end

    self.GhostBoids = {}
    for i = 1, self.GhostAmount() do
        local rand_vec = VectorRand()
        local cboid = ClientsideModel( self:GetModel() )
        self.GhostBoids[i] = cboid
        if not IsValid(cboid) then continue end
        cboid:SetNoDraw( true )
        
        cboid.FireAnimationEvent = function() return true end
        
        local defaultAnim = 0
        if self.GetBoidAnim then
            defaultAnim = self:GetBoidAnim("fly")
        end
        cboid:ResetSequence(defaultAnim)
        
        cboid:SetCycle( math.Rand(0,1) )
        if self.GhostDistUniform and self.GhostDistUniform() then
            cboid.dir = rand_vec:GetNormalized()
        else
            cboid.dir = rand_vec * math.Rand(0,1) + rand_vec
        end
        cboid.pos = self:GetPos() + cboid.dir * (self.GhostDist and self.GhostDist() or 50)
    end
end

function ENT:Draw()
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
    if self.CustomMakeRagdoll then
        self:CustomMakeRagdoll()
    else
        local ragdoll = self:BecomeRagdollOnClient()
        if IsValid(ragdoll) then
            local phys = ragdoll:GetPhysicsObject()
            if IsValid(phys) then
                local bspeed = 300
                if self.BaseSpeed then bspeed = self.BaseSpeed() end
                phys:ApplyForceCenter( self:GetForward() * bspeed * phys:GetMass() )
            end
        end
        self:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav")
        self.dead = true

        local blood = EffectData()
        blood:SetOrigin(self:GetPos())
        blood:SetScale(1)
        blood:SetFlags(3)
        util.Effect("BloodImpact", blood)
    end
end

function ENT:Think()
    self.lerp_pos = LerpVector(FrameTime() * 10, self.lerp_pos or self:GetPos(), self:GetNetworkOrigin())

    if self:GetDead() and not self.dead then
        self:MakeBoidRagdoll()
        return
    end

    if not self.GhostBoids then return end
    
    local parentSeq = self:GetSequence()
    local parentRate = self:GetPlaybackRate()

    for _,cboid in ipairs(self.GhostBoids) do
        if not IsValid(cboid) then continue end

        if cboid:GetSequence() != parentSeq then
            cboid:ResetSequence(parentSeq)
        end
        
        cboid:SetPlaybackRate(parentRate)

        local targetPos = self:GetPos() + cboid.dir * (self.GhostDist and self.GhostDist() or 50)
        cboid.pos = LerpVector(FrameTime() * 3, cboid.pos, targetPos)

        cboid:SetPos( cboid.pos )
        cboid:SetAngles( self:GetAngles() )
        cboid:FrameAdvance()
    end
end

function ENT:OnRemove( bool )
    if self.CustomOnRemove then
        self:CustomOnRemove()
    end

    if not self.GhostBoids then return end
    for i = 1, #self.GhostBoids do
        local cboid = self.GhostBoids[i]
        if not IsValid( cboid ) then continue end
        cboid:Remove()
    end
end
