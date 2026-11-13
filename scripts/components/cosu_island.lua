-- scripts/components/cosu_island.lua : đảo nhỏ giữa biển (bờ mềm, nhiều cây cỏ, trung tâm để trống)
local TS = TUNING.COSU_ISLAND
local PI = math.pi

local function IsOpenOcean(map, tx, ty, w, h, r)
    for dx = -r, r, 2 do
        for dy = -r, r, 2 do
            if dx * dx + dy * dy <= r * r then
                local x, y = tx + dx, ty + dy
                if x < 0 or y < 0 or x >= w or y >= h then return false end
                if not IsOceanTile(map:GetTile(x, y)) then return false end
            end
        end
    end
    return true
end

---------------------------------------------------------------------------
-- Hình dạng đảo: bầu dục xoay ngẫu nhiên + gợn sóng nhiều tần số + làm mịn
---------------------------------------------------------------------------
local function MakeMask(R)
    local size = math.ceil(R * 1.5) + 2
    local rot = math.random() * PI
    local sy = 0.70 + 0.25 * math.random()
    local c, s = math.cos(rot), math.sin(rot)
    local ph, am = {}, {}
    for k = 2, 7 do
        ph[k] = math.random() * 2 * PI
        am[k] = 0.20 / (k * 0.6)
    end
    local mask = {}
    for dx = -size, size do
        mask[dx] = {}
        for dy = -size, size do
            local u = dx * c + dy * s
            local v = (-dx * s + dy * c) / sy
            local ang = math.atan2(v, u)
            local rr = R
            for k = 2, 7 do rr = rr + R * am[k] * math.sin(k * ang + ph[k]) end
            mask[dx][dy] = math.sqrt(u * u + v * v) <= rr
        end
    end
    -- làm mịn: bỏ ô lẻ loi, lấp lỗ nhỏ (2 lượt)
    for _ = 1, 2 do
        local new = {}
        for dx = -size, size do
            new[dx] = {}
            for dy = -size, size do
                local n = 0
                for ox = -1, 1 do
                    for oy = -1, 1 do
                        if (ox ~= 0 or oy ~= 0) and mask[dx + ox] ~= nil and mask[dx + ox][dy + oy] then n = n + 1 end
                    end
                end
                if mask[dx][dy] then new[dx][dy] = n >= 3 else new[dx][dy] = n >= 5 end
            end
        end
        mask = new
    end
    return mask, size
end

local CosuIsland = Class(function(self, inst)
    self.inst = inst
    self.built = false
    self.center = nil
    self.decorated = false
    self.housed = false -- đã đặt nhà chưa
    self.paved = false  -- đã lát đường sỏi chưa (tách riêng để đảo cũ cũng được lát)
    self.changed = {} -- {x, y, tile_cu, x, y, tile_cu, ...} để khôi phục khi xóa đảo
    inst:DoTaskInTime(2, function()
        if not self.built then self:Build() else self:EnsureNpc() end
        if self.built and not self.housed then self:PlaceHouse() end
        if self.built and not self.paved then self:Pave() end
        if self.built and not self.decorated then self:PlaceArt() end
    end)
end)

function CosuIsland:FindSpot()
    local map = TheWorld.Map
    local w, h = map:GetSize()
    local need = math.ceil(TS.RADIUS * 1.4) + 4 + TS.OCEAN_MARGIN
    local lo, hiX, hiY = need + TS.MAP_MARGIN, w - need - TS.MAP_MARGIN, h - need - TS.MAP_MARGIN
    local cand = {}
    for tx = lo, hiX, 4 do
        for ty = lo, hiY, 4 do
            table.insert(cand, { tx, ty })
        end
    end
    shuffleArray(cand)
    for i = 1, math.min(#cand, 400) do
        local c = cand[i]
        if IsOpenOcean(map, c[1], c[2], w, h, need) then return c[1], c[2], w, h end
    end
end

function CosuIsland:SetT(x, y, tile)
    local map = TheWorld.Map
    local old = map:GetTile(x, y)
    if old == tile then return end
    table.insert(self.changed, x); table.insert(self.changed, y); table.insert(self.changed, old)
    map:SetTile(x, y, tile)
    map:RebuildLayer(old, x, y)
    map:RebuildLayer(tile, x, y)
    local mm = TheWorld.minimap ~= nil and TheWorld.minimap.MiniMap or nil
    if mm ~= nil then mm:RebuildLayer(old, x, y); mm:RebuildLayer(tile, x, y) end
end

-- xóa đảo cũ: trả ô đất về như cũ, xóa đồ trang trí
function CosuIsland:Clear()
    local map = TheWorld.Map
    local mm = TheWorld.minimap ~= nil and TheWorld.minimap.MiniMap or nil
    for i = #self.changed - 2, 1, -3 do
        local x, y, old = self.changed[i], self.changed[i + 1], self.changed[i + 2]
        local cur = map:GetTile(x, y)
        map:SetTile(x, y, old)
        map:RebuildLayer(cur, x, y)
        map:RebuildLayer(old, x, y)
        if mm ~= nil then mm:RebuildLayer(cur, x, y); mm:RebuildLayer(old, x, y) end
    end
    self.changed = {}
    for _, v in pairs(Ents) do
        if v:IsValid() and (v:HasTag("cosu_deco") or v:HasTag("cosu_house")) then v:Remove() end
    end
    self.built, self.center, self.decorated, self.housed, self.paved = false, nil, false, false, false
end

function CosuIsland:Build(force)
    if self.built and not force then return end
    if self.built then self:Clear() end
    local tx, ty, w, h = self:FindSpot()
    if tx == nil then
        print("[cosu_island] khong tim duoc cho trong giua bien")
        return
    end

    local land = WORLD_TILES.COSU_GROUND
    local mask, size = MakeMask(TS.RADIUS)

    -- đất
    for dx = -size, size do
        for dy = -size, size do
            if mask[dx][dy] then self:SetT(tx + dx, ty + dy, land) end
        end
    end
    -- bờ biển nông bao quanh cho mềm: 1-2 ô "shore", rồi 3-4 ô "coastal"
    local SHORE, COAST = WORLD_TILES.OCEAN_COASTAL_SHORE, WORLD_TILES.OCEAN_COASTAL
    if SHORE ~= nil and COAST ~= nil then
        local map = TheWorld.Map
        for dx = -size - 4, size + 4 do
            for dy = -size - 4, size + 4 do
                if not (mask[dx] ~= nil and mask[dx][dy]) then
                    local best = 99
                    for ox = -4, 4 do
                        for oy = -4, 4 do
                            local m = mask[dx + ox]
                            if m ~= nil and m[dy + oy] then
                                local d = math.max(math.abs(ox), math.abs(oy))
                                if d < best then best = d end
                            end
                        end
                    end
                    if best <= 4 and IsOceanTile(map:GetTile(tx + dx, ty + dy)) then
                        self:SetT(tx + dx, ty + dy, best <= 2 and SHORE or COAST)
                    end
                end
            end
        end
    end

    local cx = (tx - w / 2 + 0.5) * TILE_SCALE
    local cz = (ty - h / 2 + 0.5) * TILE_SCALE
    self.center = { x = cx, z = cz }
    self.built = true

    self:EnsureNpc()
    self.housed = false
    self:PlaceHouse()
    self.decorated = false
    self:PlaceArt()
    print(string.format("[cosu_island] da tao dao tai %.1f, %.1f", cx, cz))
end

-- NPC Nguyên Hải Thần Thức đứng giữa đảo
function CosuIsland:EnsureNpc()
    if self.center == nil or Prefabs["cosu_npc"] == nil then return end
    local cx, cz = self.center.x, self.center.z
    local npc = TheSim:FindFirstEntityWithTag("cosu_awakener")
    if npc == nil then npc = SpawnPrefab("cosu_npc") end
    if npc == nil then return end
    local x, _, z = npc.Transform:GetWorldPosition()
    if (x - cx) * (x - cx) + (z - cz) * (z - cz) > 20 * 20 then
        npc.Transform:SetPosition(cx, 0, cz)
    end
end

---------------------------------------------------------------------------
-- Thạch Quán + đường sỏi bao quanh NPC và ngôi nhà
---------------------------------------------------------------------------
local HOUSE_BACK = 12   -- nhà nằm phía sau NPC (hướng lên trên màn hình) bấy nhiêu đơn vị
local PAVE_RADIUS = 3   -- bán kính lát sỏi (tính bằng ô) quanh đoạn nối NPC - nhà
local HOUSE_DIR = { x = -0.7071, z = -0.7071 } -- "lên trên màn hình" với camera mặc định

-- vị trí nhà (thế giới), tính từ tâm đảo
function CosuIsland:GetHousePos()
    if self.center == nil then return nil end
    return self.center.x + HOUSE_DIR.x * HOUSE_BACK, self.center.z + HOUSE_DIR.z * HOUSE_BACK
end

-- khoảng cách (đơn vị thế giới) từ điểm tới đoạn NPC - nhà
function CosuIsland:DistToPlaza(x, z)
    local ax, az = self.center.x, self.center.z
    local bx, bz = self:GetHousePos()
    local abx, abz = bx - ax, bz - az
    local t = ((x - ax) * abx + (z - az) * abz) / (abx * abx + abz * abz)
    t = math.max(0, math.min(1, t))
    local px, pz = ax + abx * t, az + abz * t
    return math.sqrt((x - px) * (x - px) + (z - pz) * (z - pz))
end

-- lát đường sỏi (chỉ thay ô đất của đảo, không đụng bờ biển)
function CosuIsland:Pave()
    local road, land = WORLD_TILES.COBBLEROAD, WORLD_TILES.COSU_GROUND
    if road == nil then
        print("[cosu_island] khong co WORLD_TILES.COBBLEROAD, bo qua lat duong")
        return
    end
    local map = TheWorld.Map
    local w, h = map:GetSize()
    local ctx, cty = map:GetTileCoordsAtPoint(self.center.x, 0, self.center.z)
    local n = PAVE_RADIUS + math.ceil(HOUSE_BACK / TILE_SCALE) + 1
    for dx = -n, n do
        for dy = -n, n do
            local tx, ty = ctx + dx, cty + dy
            local wx = (tx - w / 2 + 0.5) * TILE_SCALE
            local wz = (ty - h / 2 + 0.5) * TILE_SCALE
            if self:DistToPlaza(wx, wz) <= PAVE_RADIUS * TILE_SCALE and map:GetTile(tx, ty) == land then
                self:SetT(tx, ty, road)
            end
        end
    end
    self.paved = true
end

function CosuIsland:PlaceHouse()
    if self.center == nil or Prefabs["cosu_house"] == nil then return end
    self:Pave()
    if TheSim:FindFirstEntityWithTag("cosu_house") == nil then
        local house = SpawnPrefab("cosu_house")
        if house ~= nil then
            local hx, hz = self:GetHousePos()
            house.Transform:SetPosition(hx, 0, hz)
        end
    end
    self.housed = true
end

-- đặt lại nhà (xóa nhà cũ, dời về đúng chỗ); đường sỏi đã lát thì giữ nguyên
function CosuIsland:Rehouse()
    for _, v in pairs(Ents) do
        if v:IsValid() and v:HasTag("cosu_house") then v:Remove() end
    end
    self.housed = false
    self:PlaceHouse()
end

---------------------------------------------------------------------------
-- Bố cục đồ trang trí. Trung tâm (CLEAR) luôn để trống.
---------------------------------------------------------------------------
local CLEAR = 0.40 -- vùng trung tâm trống = 40% bán kính đảo

-- cảnh lớn: { tên, số lượng, rmin, rmax (tỉ lệ bán kính), bán kính chiếm chỗ }
local SCENIC = {
    { "pavilion",     1, 0.60, 0.88, 3.5 },
    { "scene_bridge", 1, 0.60, 0.88, 3.5 },
    { "scene_rock",   1, 0.60, 0.88, 3.0 },
    { "scene_fall",   1, 0.60, 0.88, 3.0 },
    { "scene_mount",  1, 0.65, 0.90, 3.5 },
    { "well",         1, 0.50, 0.80, 2.0 },
}

-- cụm cây cỏ (mỗi cụm mọc dày quanh 1 điểm):
-- { {tên...}, số cụm, số cây mỗi cụm, độ loe (đơn vị), rmin, rmax, khoảng cách tối thiểu }
local CLUSTERS = {
    { { "bamboo_a", "bamboo_b", "bamboo_c" }, 4, 6, 4.5, 0.55, 0.90, 1.3 }, -- bụi tre
    { { "grass", "bush" },                    9, 7, 4.0, 0.42, 0.93, 1.0 }, -- bụi cỏ
    { { "reeds" },                            3, 4, 3.0, 0.80, 0.97, 1.6 }, -- lau sậy ven bờ
}

-- nằm bẹt dưới đất (chỉ có khi USE_FLAT_PONDS = true trong cosu_deco.lua)
local FLAT = {
    { "pond_big", 1, 0.45, 0.80, 5 }, { "lotus_a", 1, 0.45, 0.80, 4 }, { "lotus_b", 1, 0.45, 0.80, 3 },
    { "lotus_c", 1, 0.45, 0.80, 4 },  { "inkblob", 2, 0.42, 0.90, 3 },
}

local function Far(list, x, z, r)
    for _, o in ipairs(list) do
        local dx, dz = x - o.x, z - o.z
        local m = r + o.r
        if dx * dx + dz * dz < m * m then return false end
    end
    return true
end

function CosuIsland:PlaceArt()
    if self.center == nil then return end
    local cx, cz = self.center.x, self.center.z
    local R = TS.RADIUS * TILE_SCALE
    local map = TheWorld.Map
    local solid, flatl = {}, {}
    local any = false

    local function OK(x, z)
        local dx, dz = x - cx, z - cz
        if self:DistToPlaza(x, z) <= (PAVE_RADIUS + 1) * TILE_SCALE then return false end -- chừa chỗ cho nhà + đường sỏi
        return dx * dx + dz * dz >= (CLEAR * R) * (CLEAR * R) and map:IsPassableAtPoint(x, 0, z)
    end
    local function Spawn(name, x, z, list, r)
        local inst = SpawnPrefab("cosu_deco_" .. name)
        if inst == nil then return false end
        inst.Transform:SetPosition(x, 0, z)
        table.insert(list, { x = x, z = z, r = r })
        any = true
        return true
    end
    local function Ring(rmin, rmax)
        local a = math.random() * 2 * PI
        local d = R * (math.max(rmin, CLEAR) + math.random() * (rmax - math.max(rmin, CLEAR)))
        return cx + math.cos(a) * d, cz + math.sin(a) * d
    end
    local function Singles(plan, list)
        for _, e in ipairs(plan) do
            local name, count, rmin, rmax, rad = e[1], e[2], e[3], e[4], e[5]
            if Prefabs["cosu_deco_" .. name] ~= nil then
                for _ = 1, count do
                    for _try = 1, 40 do
                        local x, z = Ring(rmin, rmax)
                        if OK(x, z) and Far(list, x, z, rad) then Spawn(name, x, z, list, rad) break end
                    end
                end
            end
        end
    end

    Singles(SCENIC, solid)
    Singles(FLAT, flatl)

    for _, c in ipairs(CLUSTERS) do
        local names = {}
        for _, n in ipairs(c[1]) do
            if Prefabs["cosu_deco_" .. n] ~= nil then table.insert(names, n) end
        end
        if #names > 0 then
            for _ = 1, c[2] do
                -- chọn tâm cụm
                local gx, gz
                for _try = 1, 30 do
                    local x, z = Ring(c[5], c[6])
                    if OK(x, z) and Far(solid, x, z, 1.5) then gx, gz = x, z break end
                end
                if gx ~= nil then
                    for _ = 1, c[3] do
                        for _try = 1, 8 do
                            local a = math.random() * 2 * PI
                            local d = c[4] * math.sqrt(math.random())
                            local x, z = gx + math.cos(a) * d, gz + math.sin(a) * d
                            if OK(x, z) and Far(solid, x, z, c[7]) then
                                Spawn(names[math.random(#names)], x, z, solid, c[7])
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    if any then self.decorated = true end
end

-- xóa hết đồ trang trí rồi rải lại (để thử chỉnh scale / bố cục)
function CosuIsland:Redecorate()
    for _, v in pairs(Ents) do
        if v:IsValid() and v:HasTag("cosu_deco") then v:Remove() end
    end
    self.decorated = false
    self:PlaceArt()
end

function CosuIsland:OnSave()
    return { built = self.built, center = self.center, decorated = self.decorated, housed = self.housed, paved = self.paved, changed = self.changed }
end

function CosuIsland:OnLoad(data)
    if data ~= nil then
        self.built = data.built or false
        self.center = data.center
        self.decorated = data.decorated or false
        self.housed = data.housed or false
        self.paved = data.paved or false
        self.changed = data.changed or {}
    end
end

return CosuIsland