local assets = {
    Asset("ANIM", "anim/cosu_gu_anthach.zip"), -- hoạt ảnh dưới đất (build/bank: cosu_gu_anthach, anim: idle)
    Asset("ATLAS", "images/inventoryimages/cosu_gu_anthach.xml"),
    Asset("IMAGE", "images/inventoryimages/cosu_gu_anthach.tex"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("cosu_gu_anthach")
    inst.AnimState:SetBuild("cosu_gu_anthach")
    inst.AnimState:PlayAnimation("idle", true)

    MakeInventoryFloatable(inst, "small", 0.1, 1.0)

    inst:AddTag("cosu_gu")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "cosu_gu_anthach"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/cosu_gu_anthach.xml"

    -- chuột phải để luyện hóa vào Nguyên Hải
    inst:AddComponent("cosu_gu")

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("cosu_gu_anthach", fn, assets)