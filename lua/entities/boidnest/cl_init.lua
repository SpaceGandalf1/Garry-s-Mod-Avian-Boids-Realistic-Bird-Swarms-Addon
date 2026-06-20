include("shared.lua")

local developer = GetConVar("developer")

function ENT:Draw()
    self:DrawModel()

    -- Only show the debug label when "developer 1" is set, like the debugoverlay boxes.
    if not developer or developer:GetInt() < 1 then return end

    local class = self:GetMobClass()
    if not class or class == "" then return end

    -- Billboard label above the nest showing which mob it manages.
    local pos = self:GetPos() + Vector(0, 0, 30)
    local ang = (pos - EyePos()):Angle()
    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, 0.15)
        draw.SimpleText(class, "DermaLarge", 1, 1, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(class, "DermaLarge", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
