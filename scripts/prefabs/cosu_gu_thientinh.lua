local assets = {
    Asset("ANIM", "anim/cosu_gu_thientinh.zip"), -- hoạt ảnh dưới đất (build/bank: cosu_gu_thientinh, anim: idle)
    Asset("ATLAS", "images/inventoryimages/cosu_gu_thientinh.xml"),
    Asset("IMAGE", "images/inventoryimages/cosu_gu_thientinh.tex"),
}

-- Chỉnh ánh sáng ở đây
local LIGHT_RADIUS    = 2.0
local LIGHT_FALLOFF   = 0.6
local LIGHT_INTENSITY = 0.75
local LIGHT_COLOUR    = { 200 / 255, 255 / 255, 170 / 255 } -- vàng lục như đom đóm

local function TurnLightOn(inst)
    inst.Light:Enable(true)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLightOverride(0.4)
end

local function TurnLightOff(inst)
    inst.Light:Enable(false)
    inst.AnimState:ClearBloomEffectHandle()
    inst.AnimState:SetLightOverride(0)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddLight() -- phải thêm trước SetPristine

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("cosu_gu_thientinh")
    inst.AnimState:SetBuild("cosu_gu_thientinh")
    inst.AnimState:PlayAnimation("idle", true) -- lặp vô hạn

    inst.Light:SetRadius(LIGHT_RADIUS)
    inst.Light:SetFalloff(LIGHT_FALLOFF)
    inst.Light:SetIntensity(LIGHT_INTENSITY)
    inst.Light:SetColour(LIGHT_COLOUR[1], LIGHT_COLOUR[2], LIGHT_COLOUR[3])
    inst.Light:Enable(true)

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLightOverride(0.4)

    MakeInventoryFloatable(inst, "small", 0.1, 1.0)

    inst:AddTag("cosu_gu")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "cosu_gu_thientinh"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/cosu_gu_thientinh.xml"

    -- chuột phải để luyện hóa vào Nguyên Hải
    inst:AddComponent("cosu_gu")

    -- chỉ phát sáng khi nằm dưới đất, cất vào túi thì tắt
    inst:ListenForEvent("onputininventory", TurnLightOff)
    inst:ListenForEvent("ondropped", TurnLightOn)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("cosu_gu_thientinh", fn, assets)