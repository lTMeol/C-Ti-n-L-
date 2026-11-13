local GU = require "cosu_gu_tuning"

-- Ánh sáng gắn lên người chơi. Light không đồng bộ được từ server xuống máy khách
-- nên mỗi mức sáng là một prefab riêng (thiết lập Light trước SetPristine).
local function MakeLight(name, radius)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddLight()
        inst.entity:AddNetwork()

        inst:AddTag("FX")

        inst.Light:SetIntensity(GU.LIGHT.intensity)
        inst.Light:SetColour(GU.LIGHT.colour[1], GU.LIGHT.colour[2], GU.LIGHT.colour[3])
        inst.Light:SetFalloff(GU.LIGHT.falloff)
        inst.Light:SetRadius(radius)
        inst.Light:Enable(true)

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists = false

        return inst
    end

    return Prefab(name, fn)
end

return MakeLight("cosu_gu_light", GU.LIGHT.radius),
    MakeLight("cosu_gu_light_main", GU.LIGHT.radius * GU.MAIN_LIGHT_MULT)