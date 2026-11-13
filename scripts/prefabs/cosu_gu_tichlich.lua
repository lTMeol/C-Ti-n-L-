local assets = {
    Asset("ANIM", "anim/gu_tichlich.zip"), -- hoạt ảnh dưới đất (build/bank: gu_tichlich, anim: idle)
    Asset("ATLAS", "images/inventoryimages/cosu_gu_tichlich.xml"),
    Asset("IMAGE", "images/inventoryimages/cosu_gu_tichlich.tex"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("gu_tichlich")
    inst.AnimState:SetBuild("gu_tichlich")
    inst.AnimState:PlayAnimation("idle", true) -- lặp vô hạn

    MakeInventoryFloatable(inst, "small", 0.1, 1.0)

    inst:AddTag("cosu_gu")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "cosu_gu_tichlich"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/cosu_gu_tichlich.xml"

    -- chuột phải để luyện hóa vào Nguyên Hải
    inst:AddComponent("cosu_gu")

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("cosu_gu_tichlich", fn, assets)