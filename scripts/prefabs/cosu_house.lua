-- scripts/prefabs/cosu_house.lua : Thạch Quán (ngôi nhà trên đảo). Bấm vào nhà -> mở bảng (screens/cosu_shop_screen.lua)
local BANK  = "cosu_house"   -- anim/cosu_house.zip (1 ảnh: art/cosu_house_facade.png)
local BUILD = "cosu_house"
local ANIM  = "cosu_house"   -- tên animation trong Animation Tool (Bank > cosu_house > animation)
local HOUSE_SCALE = 1.3      -- to/nhỏ của nhà: chỉnh số này nếu thấy quá to/nhỏ
local HOUSE_RADIUS = 4.5     -- vòng chặn không cho đi xuyên qua nhà (đơn vị thế giới)

local assets = { Asset("ANIM", "anim/cosu_house.zip") }

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, HOUSE_RADIUS)

    inst:AddTag("structure")
    inst:AddTag("cosu_house")
    inst:AddTag("cosu_shop")

    inst.AnimState:SetBank(BANK)
    inst.AnimState:SetBuild(BUILD)
    inst.AnimState:PlayAnimation(ANIM)
    inst.AnimState:SetFrame(0)
    inst.AnimState:Pause()
    inst.Transform:SetScale(HOUSE_SCALE, HOUSE_SCALE, HOUSE_SCALE)

    -- kho đá (server ghi, máy khách đọc): "chỉ_số_đá:giá;..." xem components/cosu_shop.lua
    inst._stock = net_string(inst.GUID, "cosu_house_stock", "cosu_stockdirty")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("inspectable")
    inst:AddComponent("cosu_shop") -- chỉ để gắn hành động "Vào Thạch Quán" (xem modmain.lua)

    return inst
end

return Prefab("cosu_house", fn, assets)