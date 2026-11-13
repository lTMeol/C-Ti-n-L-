-- Linh Căn (8 hệ) và Mảnh Vỡ Nguyên Tố: vật phẩm trong túi, xếp chồng được.
local ELEM = require "cosu_element_tuning"

local function MakeItem(name, atlas, image, tint)
    local assets = {
        Asset("ATLAS", atlas),
        Asset("IMAGE", ELEM.TEX),
    }
    if ELEM.USE_CUSTOM_ANIM then
        table.insert(assets, Asset("ANIM", ELEM.ANIM_ZIP))
    end

    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        if ELEM.USE_CUSTOM_ANIM then
            -- 1 anim chung cho cả 16 vật phẩm, mỗi vật phẩm dừng ở khung hình của mình
            -- (ảnh đã có màu và bóng sẵn, không nhuộm thêm)
            inst.AnimState:SetBank(ELEM.ANIM_BANK)
            inst.AnimState:SetBuild(ELEM.ANIM_BUILD)
            inst.AnimState:PlayAnimation(ELEM.ANIM_NAME)
            -- Game đổi % thành khung hình theo độ dài (N-1) khung chứ không phải N, nên công thức cũ
            -- (k+0.5)/N bị lệch 1 khung từ khung thứ 8 trở đi. Công thức này đúng cho cả hai cách tính.
            local frame = ELEM.ANIM_FRAME[name] or 0
            local pct = math.min(1, (frame + 0.01) / (ELEM.ANIM_FRAME_COUNT - 1))
            inst.AnimState:SetPercent(ELEM.ANIM_NAME, pct)
            inst.AnimState:SetScale(ELEM.ANIM_SCALE, ELEM.ANIM_SCALE, ELEM.ANIM_SCALE)
        else
            inst.AnimState:SetBank(ELEM.GROUND_BANK)
            inst.AnimState:SetBuild(ELEM.GROUND_BUILD)
            inst.AnimState:PlayAnimation(ELEM.GROUND_ANIM)
            inst.AnimState:SetMultColour(tint[1], tint[2], tint[3], 1)
        end

        MakeInventoryFloatable(inst, "small", 0.1, 0.8)

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = name
        inst.components.inventoryitem.atlasname = atlas

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

        MakeHauntableLaunch(inst)
        return inst
    end

    return Prefab(name, fn, assets)
end

local prefabs = {}
for _, e in ipairs(ELEM.LIST) do
    table.insert(prefabs, MakeItem(e.root, e.root_atlas, e.root_image, e.tint))
    table.insert(prefabs, MakeItem(e.shard, e.shard_atlas, e.shard_image, e.tint))
end
return unpack(prefabs)