-- scripts/prefabs/cosu_deco.lua : đồ trang trí đảo (mỗi ảnh = 1 frame trong anim/cosu_deco.zip)
local ZIP   = "cosu_deco"   -- anim/cosu_deco.zip
local BANK  = "cosu_deco"
local BUILD = "cosu_deco"
local ANIM  = "Texture2D"   -- TÊN ANIMATION trong Animation Tool (Bank > cosu_deco > animation). Nếu bạn đã đổi tên thì sửa ở đây
local SCALE_ALL = 3.0       -- nhân chung cho mọi thứ (chỉnh nhanh to/nhỏ). Ảnh gốc nhỏ nên cần phóng ~3 lần
local USE_FLAT_PONDS = false -- ao sen/loang mực nằm bẹt: tạm tắt vì ảnh có viền chữ nhật cứng; làm mềm viền xong thì đổi thành true

-- frame = số frame; flat = nằm bẹt dưới đất; scale = to/nhỏ riêng
-- (frame 3 và 9 chưa dùng vì chưa biết là ảnh gì)
local DECOR = {
    bamboo_a    = { frame = 0,  flat = false, scale = 1.0 },
    inkblob     = { frame = (USE_FLAT_PONDS and 1 or nil),  flat = true,  scale = 1.0 },
    scene_bridge= { frame = 2,  flat = false, scale = 1.2 },
    scene_mount = { frame = 4,  flat = false, scale = 1.2 },
    lotus_a     = { frame = (USE_FLAT_PONDS and 5 or nil),  flat = true,  scale = 1.0 },
    lotus_b     = { frame = (USE_FLAT_PONDS and 6 or nil),  flat = true,  scale = 1.0 },
    reeds       = { frame = 7,  flat = false, scale = 1.0 },
    pond_big    = { frame = (USE_FLAT_PONDS and 8 or nil),  flat = true,  scale = 1.2 },
    pavilion    = { frame = 10, flat = false, scale = 1.2 },
    bamboo_b    = { frame = 11, flat = false, scale = 1.0 },
    scene_rock  = { frame = 12, flat = false, scale = 1.2 },
    bamboo_c    = { frame = 13, flat = false, scale = 1.0 },
    grass       = { frame = 14, flat = false, scale = 1.0 },
    bush        = { frame = 15, flat = false, scale = 1.0 },
    well        = { frame = 16, flat = false, scale = 1.0 },
    lotus_c     = { frame = (USE_FLAT_PONDS and 17 or nil), flat = true,  scale = 1.0 },
    scene_fall  = { frame = 18, flat = false, scale = 1.2 },
}

local assets = { Asset("ANIM", "anim/" .. ZIP .. ".zip") }

local function MakeDeco(key, cfg)
    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        inst:AddTag("NOCLICK")
        inst:AddTag("cosu_deco")

        inst.AnimState:SetBank(BANK)
        inst.AnimState:SetBuild(BUILD)
        inst.AnimState:PlayAnimation(ANIM)
        inst.AnimState:SetFrame(cfg.frame)
        inst.AnimState:Pause() -- giữ nguyên 1 frame (nếu game báo thiếu hàm Pause thì dùng SetDeltaTimeMultiplier(0))

        if cfg.flat then
            inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
            inst.AnimState:SetLayer(LAYER_BACKGROUND)
            inst.AnimState:SetSortOrder(2)
        end
        local sc = cfg.scale * SCALE_ALL
        inst.Transform:SetScale(sc, sc, sc)

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then return inst end
        return inst
    end
    return Prefab("cosu_deco_" .. key, fn, assets)
end

local out = {}
for key, cfg in pairs(DECOR) do
    if cfg.frame ~= nil then table.insert(out, MakeDeco(key, cfg)) end
end
return unpack(out)