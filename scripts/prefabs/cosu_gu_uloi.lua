-- U Lôi Huyễn Điệp Cổ. Nội tại + kỹ năng nằm trong components/cosu_gu_bag.lua, số liệu trong cosu_gu_tuning.lua (T.ULOI).
local assets = {
    Asset("ANIM", "anim/cosu_stones.zip"), -- tạm mượn hình dưới đất của nguyên thạch
    Asset("ATLAS", "images/inventoryimages/cosu_gu_uloi.xml"),
    Asset("IMAGE", "images/inventoryimages/cosu_gu_uloi.tex"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("cosu_stone_mid")
    inst.AnimState:SetBuild("cosu_stones")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetScale(1.3, 1.3)
    inst.AnimState:SetMultColour(0.75, 0.55, 1, 1) -- ngả tím cho khác Thiên Tinh Huỳnh Cổ

    MakeInventoryFloatable(inst, "small", 0.1, 1.0)

    inst:AddTag("cosu_gu")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "cosu_gu_uloi"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/cosu_gu_uloi.xml"

    -- chuột phải để luyện hóa vào Nguyên Hải
    inst:AddComponent("cosu_gu")

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("cosu_gu_uloi", fn, assets)