local COSU = require "cosu_tuning"

-- Một file anim chung cho cả 5 phẩm. Build gộp tên "cosu_stones",
-- mỗi phẩm có bank riêng: cosu_stone_low, cosu_stone_mid, ...
local assets = { Asset("ANIM", "anim/cosu_stones.zip") }

local function MakeStone(grade)
    local name = COSU.PREFAB[grade]
    local bank = "cosu_stone_" .. grade

    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild("cosu_stones")
        inst.AnimState:PlayAnimation("idle")
        inst.AnimState:SetScale(1.3, 1.3) 

        MakeInventoryFloatable(inst, "small", 0.1, 1.0)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = name
        inst.components.inventoryitem.atlasname = "images/inventoryimages/" .. name .. ".xml"

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

        inst:AddComponent("cosu_stone")
        inst.components.cosu_stone.grade = grade

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(name, fn, assets)
end

local prefabs = {}
for _, grade in ipairs(COSU.GRADES) do
    table.insert(prefabs, MakeStone(grade))
end
return unpack(prefabs)