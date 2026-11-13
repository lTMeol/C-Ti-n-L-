-- Linh Thạch: vật phẩm rơi dưới đất, nhặt lên thì cộng thẳng vào ví (không vào túi đồ).
-- Số lượng nằm trong inst._amount (gộp sẵn thành 1 cục khi rơi).
local assets = {
    Asset("ANIM", "anim/cosu_linhthach.zip"), -- ĐỔI tên zip cho khớp file anim của bạn
    Asset("ATLAS", "images/inventoryimages/cosu_linhthach.xml"),
    Asset("IMAGE", "images/inventoryimages/cosu_linhthach.tex"),
}

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("lingshi_01")
    inst.AnimState:SetBuild("cosu_linhthach")
    inst.AnimState:PlayAnimation("lingshi_01", true)

    inst:AddTag("cosu_linhthach")

    inst._amount = net_uint(inst.GUID, "cosu_linhthach_amount")
    inst._amount:set(1)
    inst.displaynamefn = function(i)
        local n = i._amount:value()
        return STRINGS.NAMES.COSU_LINHTHACH .. (n > 1 and (" x" .. n) or "")
    end

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "cosu_linhthach"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/cosu_linhthach.xml"

    inst.SetAmount = function(i, n) i._amount:set(math.max(1, math.floor(n or 1))) end
    inst.GetAmount = function(i) return i._amount:value() end
    inst.OnSave = function(i, data) data.amount = i._amount:value() end
    inst.OnLoad = function(i, data) if data ~= nil and data.amount ~= nil then i:SetAmount(data.amount) end end

    return inst
end

return Prefab("cosu_linhthach", fn, assets)