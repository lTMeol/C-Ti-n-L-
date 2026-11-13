-- Hiệu ứng tia sét của kỹ năng Giáng Lôi (U Lôi Huyễn Điệp Cổ).
-- Animation: anim/cosu_giangloi.zip (bank/build cosu_giangloi, anim spawn_medium / spawn_small).
local assets = {
    Asset("ANIM", "anim/cosu_giangloi.zip"),
}

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.AnimState:SetBank("cosu_giangloi")
    inst.AnimState:SetBuild("cosu_giangloi")
    inst.AnimState:PlayAnimation("spawn_medium")
    inst.AnimState:SetLightOverride(1)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.SoundEmitter:PlaySound("dontstarve/rain/thunder_close") -- bỏ nếu animation đã có tiếng
    inst.persists = false
    inst:ListenForEvent("animover", inst.Remove)

    return inst
end

return Prefab("cosu_giangloi_fx", fn, assets)