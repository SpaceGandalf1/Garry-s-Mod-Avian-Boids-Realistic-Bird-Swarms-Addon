BoidMath = BoidMath or {}

local NUM_DIRECTIONS = 36
local GOLDEN_RATIO = (1 + math.sqrt(5)) / 2
local ANGLE_INCREMENT = math.pi * 2 * GOLDEN_RATIO

BoidMath.Directions = {}
for i = 0, NUM_DIRECTIONS - 1 do
    local t = i / NUM_DIRECTIONS
    local inclination = math.acos(1 - 2 * t)
    local azimuth = ANGLE_INCREMENT * i

    local x = 1 - 2 * t
    local radius = math.sqrt(1 - x * x)

    local y = math.sin(azimuth) * radius
    local z = math.cos(azimuth) * radius

    table.insert(BoidMath.Directions, Vector(x, y, z))
end

function BoidMath.GetFlockingSteer(ent, validNeighbors, sepRule, alignRule, cohRule, minDist, pos, forward)
    local separation = Vector(0, 0, 0)
    local alignment = Vector(0, 0, 0)
    local cohesion = Vector(0, 0, 0)
    local avgPos = Vector(0, 0, 0)
    local numNeighbors = #validNeighbors

    if numNeighbors > 0 then
        for _, n in ipairs(validNeighbors) do
            local otherPos = n.ent:GetPos()

            if sepRule then
                local flee = pos - otherPos
                flee:Normalize()
                separation = separation + (flee / (n.dist / minDist))
            end
            if alignRule then alignment = alignment + n.ent:GetForward() end
            if cohRule then avgPos = avgPos + otherPos end
        end
        if alignRule then alignment = (alignment / numNeighbors):GetNormalized() end
        if cohRule then cohesion = (((avgPos / numNeighbors) - pos)):GetNormalized() end
    end

    return separation, alignment, cohesion
end

function BoidMath.ObstacleRay(ent, traceLen, filterFunc, waterCheck)
    local pos = ent:GetPos()
    local angles = ent:GetAngles()

    for _, dir in ipairs(BoidMath.Directions) do
        local worldDir = LocalToWorld(dir, Angle(0,0,0), Vector(0,0,0), angles)
        local testPos = pos + worldDir * traceLen

        local tr = util.TraceLine({
            start = pos,
            endpos = testPos,
            mask = MASK_SOLID,
            filter = filterFunc
        })

        if waterCheck then
            local isWater = bit.band(util.PointContents(testPos), CONTENTS_WATER) == CONTENTS_WATER
            if not tr.Hit and isWater then
                return worldDir
            end
        else
            if not tr.Hit then
                return worldDir
            end
        end
    end

    return -ent:GetForward()
end
