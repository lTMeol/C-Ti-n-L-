local assets = {
    Asset("ANIM", "anim/dong_co_trung.zip"),
}

-- Mỗi frame gốc 707x877 px nên rất lớn. Chỉnh số này đến khi vừa mắt (nhỏ hơn = bé hơn).
local SCALE = 0.3
local ANIM_NAME = "dong_co_trung_frames"

local function onturnoff(inst)
    inst.SoundEmitter:KillSound("loop")
end

local function onturnon(inst)
    if not inst.SoundEmitter:PlayingSound("loop") then
        inst.SoundEmitter:PlaySound("dontstarve/common/together/critter_lab/idle", "loop")
    end
end

local function OnHammered(inst, worker)
    if inst.components.lootdropper ~= nil then
        inst.components.lootdropper:DropLoot()
    end
    local fx = SpawnPrefab("collapse_big")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("stone")
    inst:Remove()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 1.2)

    inst.AnimState:SetBank("dong_co_trung")
    inst.AnimState:SetBuild("dong_co_trung")
    inst.AnimState:PlayAnimation(ANIM_NAME, true) -- true = lặp liên tục
    inst.AnimState:SetScale(SCALE, SCALE, SCALE)

    inst:AddTag("structure")
    inst:AddTag("cosu_cave")
    inst:AddTag("prototyper")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")

    inst:AddComponent("prototyper")
    inst.components.prototyper.onturnon = onturnon
    inst.components.prototyper.onturnoff = onturnoff
    inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.COSU_CAVE

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(OnHammered)

    return inst
end

-- MakePlacer(name, bank, build, anim, onground, snap, metersnap, scale)
return Prefab("cosu_cave", fn, assets),
    MakePlacer("cosu_cave_placer", "dong_co_trung", "dong_co_trung", ANIM_NAME, nil, nil, nil, SCALE)