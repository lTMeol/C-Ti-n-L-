local PILL = require "cosu_pill_tuning"

-- độ lớn viên đan dưới đất (hình gốc 239x247): tăng/giảm tùy ý
local PILL_SCALE = 0.9

-- Khung hình (từ 0) trong anim ứng với từng chuyển 1..8, khớp với icon trong túi:
--   chuyển: 1 đỏ, 2 tím, 3 xanh tím, 4 hồng, 5 lam, 6 cam, 7 lục, 8 vàng
--   khung trong file build: 0 lục, 1 lam, 2 xanh tím, 3 hồng, 4 vàng, 5 cam, 6 đỏ, 7 tím
local GROUND_FRAME = { 6, 7, 2, 3, 1, 5, 0, 4 }

local assets = { Asset("ANIM", "anim/cosu_pills.zip") }

local function MakePill(n)
    local name = PILL.PrefabName(n)

    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("cosu_pills")
        inst.AnimState:SetBuild("cosu_pills")
        inst.AnimState:SetScale(PILL_SCALE, PILL_SCALE)

        -- Làm y hệt cosu_linhcan.lua (đã chạy đúng): PlayAnimation rồi SetPercent.
        -- Game đổi % thành khung theo độ dài (N-1) nên dùng frame/(N-1), không phải (k+0.5)/N.
        inst.AnimState:PlayAnimation("idle")
        local frame = GROUND_FRAME[n]
        local pct = math.min(1, (frame + 0.01) / (PILL.MAX_PILL - 1))
        inst.AnimState:SetPercent("idle", pct)

        MakeInventoryFloatable(inst, "small", 0.1, 1.0)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = name
        inst.components.inventoryitem.atlasname = "images/inventoryimages/cosu_pills.xml"

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

        inst:AddComponent("cosu_pill")
        inst.components.cosu_pill.rank = n

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(name, fn, assets)
end

local prefabs = {}
for n = 1, PILL.MAX_PILL do
    table.insert(prefabs, MakePill(n))
end
return unpack(prefabs)