-- cosu_island.lua  (nạp bằng modimport("cosu_island.lua") trong modmain.lua)
-- Đảo nhỏ giữa biển, nền đất tím đen "Cổ Địa". Tạo lúc chạy game, không cần tạo thế giới mới.
local G = GLOBAL

---------------------------------------------------------------------------
-- 1) Ô đất riêng (dùng ảnh nền của bạn)
---------------------------------------------------------------------------
Assets = Assets or {}
table.insert(Assets, Asset("IMAGE", "levels/textures/cosu_ground_noise.tex"))
table.insert(Assets, Asset("IMAGE", "levels/textures/mini_cosu.tex"))
table.insert(Assets, Asset("IMAGE", "levels/tiles/cosu_ground.tex"))
table.insert(Assets, Asset("FILE",  "levels/tiles/cosu_ground.xml"))

AddTile("COSU_GROUND", "LAND",
    { ground_name = "Cosu Ground" },
    {
        name = "cosu_ground",
        noise_texture = "levels/textures/cosu_ground_noise.tex",
        runsound = "dontstarve/movement/run_dirt",
        walksound = "dontstarve/movement/walk_dirt",
        snowsound = "dontstarve/movement/run_snow",
        mudsound = "dontstarve/movement/run_mud",
    },
    {
        name = "map_edge",
        noise_texture = "levels/textures/mini_cosu.tex",
    })

-- bờ đảo vẽ đè lên biển cho đẹp
ChangeTileRenderOrder(G.WORLD_TILES.COSU_GROUND, G.WORLD_TILES.OCEAN_COASTAL, true)

---------------------------------------------------------------------------
-- 2) Cấu hình đảo
---------------------------------------------------------------------------
G.TUNING.COSU_ISLAND = {
    RADIUS = 8,          -- bán kính (ô, mỗi ô 4 đơn vị) -> đảo nhỏ; đảo mặt trăng thật ~ 40+
    OCEAN_MARGIN = 10,   -- phải có chừng này ô biển trống bao quanh
    MAP_MARGIN = 12,     -- cách mép bản đồ
}

AddPrefabPostInit("world", function(inst)
    if not G.TheWorld.ismastersim then return end
    if inst:HasTag("cave") then return end -- chỉ thế giới mặt đất
    inst:AddComponent("cosu_island")
end)

-- Lệnh thử:  c_cosu_island()  = dịch chuyển tới đảo,  c_cosu_island(true) = xây lại ở chỗ khác
G.c_cosu_island = function(rebuild)
    local comp = G.TheWorld.components.cosu_island
    if comp == nil then print("khong co component (dang o hang?)") return end
    if rebuild then comp:Build(true) end
    local p = G.ConsoleCommandPlayer()
    if p ~= nil and comp.center ~= nil then
        p.Transform:SetPosition(comp.center.x, 0, comp.center.z)
    end
end

-- Rải lại đồ trang trí (sau khi chỉnh scale/bố cục):  c_cosu_redeco()
G.c_cosu_redeco = function()
    local comp = G.TheWorld.components.cosu_island
    if comp ~= nil then comp:Redecorate() end
end