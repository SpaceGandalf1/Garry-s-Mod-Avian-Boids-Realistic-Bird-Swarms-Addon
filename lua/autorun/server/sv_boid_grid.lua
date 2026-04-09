BoidGrid = BoidGrid or {}
BoidGrid.Cells = {}
BoidGrid.CachedOrbits = {}
BoidGrid.NextUpdate = 0

local CELL_SIZE = CreateConVar("sv_boids_master_cell_size", "1000", FCVAR_NONE, "Grid size for all boids", 50, 2000)

hook.Add("Tick", "UpdateMasterBoidGrid", function()
    if CurTime() < BoidGrid.NextUpdate then return end
    BoidGrid.NextUpdate = CurTime() + 0.1

    BoidGrid.CachedOrbits = ents.FindByClass("orbit")
    table.Empty(BoidGrid.Cells)

    local cell_size = CELL_SIZE:GetFloat()

    local function AddToGrid(class)
        for _, ent in ipairs(ents.FindByClass(class)) do
            if not IsValid(ent) then continue end

            local pos = ent:GetPos()
            local gx = math.floor(pos.x / cell_size)
            local gy = math.floor(pos.y / cell_size)
            local gz = math.floor(pos.z / cell_size)

            local key = gx .. "|" .. gy .. "|" .. gz

            BoidGrid.Cells[key] = BoidGrid.Cells[key] or {}
            table.insert(BoidGrid.Cells[key], ent)

            ent.GridX = gx
            ent.GridY = gy
            ent.GridZ = gz
        end
    end

    AddToGrid("boids")
    AddToGrid("boidfish")
end)

function BoidGrid.GetNearByOptimized(ent, distanceCheck, maxDistanceSqr)
    local neighbors = {}
    if not ent.GridX then return neighbors end

    for dx = -1, 1 do
        for dy = -1, 1 do
            for dz = -1, 1 do
                local key = (ent.GridX + dx) .. "|" .. (ent.GridY + dy) .. "|" .. (ent.GridZ + dz)
                local cell = BoidGrid.Cells[key]

                if cell then
                    for _, b in ipairs(cell) do
                        if IsValid(b) and b != ent and b:GetClass() == ent:GetClass() then
                            if not distanceCheck then
                                table.insert(neighbors, b)
                                continue
                            end

                            local distSqr = ent:GetPos():DistToSqr(b:GetPos())
                            if distSqr < maxDistanceSqr then
                                table.insert(neighbors, b)
                            end
                        end
                    end
                end
            end
        end
    end
    return neighbors
end
