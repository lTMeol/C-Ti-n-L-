-- NPC khai mở Nguyên Hải Thần Thức.
local BUILD = "cs_dan_duong"    -- tên build (file anim/cs_dan_duong.zip)
local BANK = "cs_dan_duong"
local IDLE_ANIM = "idle"
-- Frame gốc 403x1216 px nên rất cao. Chỉnh số này đến khi cao vừa bằng nhân vật (nhỏ hơn = bé hơn).
local SCALE = 1.0

local assets = {
    Asset("ANIM", "anim/" .. BUILD .. ".zip"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 0.5)
    inst.DynamicShadow:SetSize(1.3, 0.6)

    inst.AnimState:SetBank(BANK)
    inst.AnimState:SetBuild(BUILD)
    inst.AnimState:PlayAnimation(IDLE_ANIM, true) -- true = lặp liên tục
    inst.AnimState:SetScale(SCALE, SCALE, SCALE)

    inst:AddTag("cosu_awakener")
    inst:AddTag("character")
    inst:AddTag("notraptrigger")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("cosu_awakener")

    -- Anim chỉ có 1 hướng nên không cần quay mặt về phía người chơi
    -- (bỏ SetFourFaced và FacePoint của bản cũ).

    return inst
end

return Prefab("cosu_npc", fn, assets)