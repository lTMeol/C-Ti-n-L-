-- Ngôi Sao do Thiên Tinh Huỳnh Vương Cổ tạo ra: lơ lửng, phát sáng, tồn tại V.STAR_DAYS ngày.
local ELEM = require "cosu_element_tuning"
local GU = require "cosu_gu_tuning"
local V = GU.VUONG

local assets = {}
if ELEM.USE_CUSTOM_ANIM then
    table.insert(assets, Asset("ANIM", ELEM.ANIM_ZIP))
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")
    inst:AddTag("cosu_gu_star")

    -- Hình tạm: mượn khung "Mảnh Vỡ Quang" trong anim nguyên tố, phóng to và cho phát sáng.
    -- Khi có hình ngôi sao riêng thì đổi tại đây.
    if ELEM.USE_CUSTOM_ANIM then
        inst.AnimState:SetBank(ELEM.ANIM_BANK)
        inst.AnimState:SetBuild(ELEM.ANIM_BUILD)
        inst.AnimState:PlayAnimation(ELEM.ANIM_NAME)
        local frame = ELEM.ANIM_FRAME["cosu_manh_quang"] or 0
        inst.AnimState:SetPercent(ELEM.ANIM_NAME, math.min(1, (frame + 0.01) / (ELEM.ANIM_FRAME_COUNT - 1)))
        inst.AnimState:SetScale(V.STAR_SCALE, V.STAR_SCALE, V.STAR_SCALE)
    else
        inst.AnimState:SetBank(ELEM.GROUND_BANK)
        inst.AnimState:SetBuild(ELEM.GROUND_BUILD)
        inst.AnimState:PlayAnimation(ELEM.GROUND_ANIM)
        inst.AnimState:SetMultColour(1.0, 0.95, 0.6, 1)
        inst.AnimState:SetScale(V.STAR_SCALE, V.STAR_SCALE, V.STAR_SCALE)
    end
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLightOverride(1)

    inst.Light:SetRadius(V.STAR_LIGHT.radius)
    inst.Light:SetIntensity(V.STAR_LIGHT.intensity)
    inst.Light:SetFalloff(V.STAR_LIGHT.falloff)
    inst.Light:SetColour(V.STAR_LIGHT.colour[1], V.STAR_LIGHT.colour[2], V.STAR_LIGHT.colour[3])
    inst.Light:Enable(true)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- hết hạn thì biến mất; timer tự lưu/nạp theo save game
    inst:AddComponent("timer")
    inst.components.timer:StartTimer("expire", V.STAR_DAYS * TUNING.TOTAL_DAY_TIME)
    inst:ListenForEvent("timerdone", function(inst, data)
        if data ~= nil and data.name == "expire" then
            inst:Remove()
        end
    end)

    return inst
end

return Prefab("cosu_gu_star", fn, assets)
