local FURN = require("cosu_furnace_tuning")

local assets = {
    Asset("ANIM", "anim/" .. FURN.BUILD .. ".zip"),
}

local function SetFlames(inst, on)
    for _, layer in ipairs(FURN.FLAME_LAYERS) do
        if on then inst.AnimState:Show(layer) else inst.AnimState:Hide(layer) end
    end
end

-- Lấy đúng số nguyên liệu cần ra khỏi các ô
local function ConsumeItem(container, prefab, count)
    for slot = 1, container:GetNumSlots() do
        local item = container:GetItemInSlot(slot)
        if item ~= nil and item.prefab == prefab then
            local stack = item.components.stackable ~= nil and item.components.stackable:StackSize() or 1
            local take = math.min(stack, count)
            if take >= stack then
                local removed = container:RemoveItemBySlot(slot)
                if removed ~= nil then removed:Remove() end
            else
                local part = item.components.stackable:Get(take)
                if part ~= nil then part:Remove() end
            end
            count = count - take
            if count <= 0 then return end
        end
    end
end

local function SpawnStack(prefab, count, x, y, z)
    while count > 0 do
        local item = SpawnPrefab(prefab)
        if item == nil then return end
        local n = 1
        if item.components.stackable ~= nil then
            n = math.min(count, item.components.stackable.maxsize)
            item.components.stackable:SetStackSize(n)
        end
        item.Transform:SetPosition(x, y, z)
        if item.components.inventoryitem ~= nil then
            item.components.inventoryitem:OnDropped(true)
        end
        count = count - n
    end
end

local function OnOpen(inst)
    inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_open")
end

local function OnClose(inst)
    inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_close")
end

local function FinishBrew(inst)
    inst._brew_task = nil
    inst._brewing = false
    inst._endtime = nil

    SetFlames(inst, not FURN.FLAME_ONLY_WHEN_BREWING)
    inst.Light:Enable(false)
    inst.SoundEmitter:KillSound("brew")
    inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_finish")

    local container = inst.components.container
    container.canbeopened = true

    -- nguyên liệu thừa trong ô rơi ra ngoài
    container:DropEverything()

    -- viên đan rơi ra ngoài
    local pill = SpawnPrefab(FURN.OutputPrefab())
    if pill ~= nil then
        if pill.components.stackable ~= nil and FURN.OUTPUT_COUNT > 1 then
            pill.components.stackable:SetStackSize(FURN.OUTPUT_COUNT)
        end
        local x, y, z = inst.Transform:GetWorldPosition()
        inst.components.lootdropper:FlingItem(pill, Vector3(x, y, z))
    end
end

local function StartBrew(inst, remaining)
    inst._brewing = true
    inst._endtime = GetTime() + remaining

    local container = inst.components.container
    container:Close()
    container.canbeopened = false

    SetFlames(inst, true)
    inst.Light:Enable(true)
    inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_rattle", "brew")

    if inst._brew_task ~= nil then inst._brew_task:Cancel() end
    inst._brew_task = inst:DoTaskInTime(remaining, FinishBrew)
end

-- Gọi từ RPC khi người chơi bấm nút "Luyện chế". Trả về true nếu bắt đầu luyện.
local function TryStartBrew(inst, doer)
    if inst._brewing then return false end
    local container = inst.components.container
    if container == nil then return false end

    if not FURN.HasAll(inst.replica.container) then
        if doer ~= nil and doer.components.talker ~= nil then
            doer.components.talker:Say("Nguyên liệu chưa đủ để luyện đan.")
        end
        return false
    end

    for _, v in ipairs(FURN.INGREDIENTS) do
        ConsumeItem(container, v.prefab, v.count)
    end
    StartBrew(inst, FURN.BREW_TIME)
    return true
end

local function OnHammered(inst)
    -- đang luyện thì nguyên liệu đã bị lấy khỏi ô, trả lại cho người chơi
    local x, y, z = inst.Transform:GetWorldPosition()
    if inst._brewing then
        for _, v in ipairs(FURN.INGREDIENTS) do
            SpawnStack(v.prefab, v.count, x, y, z)
        end
    end
    inst.components.container.canbeopened = true
    inst.components.container:DropEverything()
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_small")
    if fx ~= nil then
        fx.Transform:SetPosition(x, y, z)
        fx:SetMaterial("stone")
    end
    inst:Remove()
end

local function OnHit(inst)
    if not inst._brewing then
        inst.components.container:Close()
    end
end

local function GetStatus(inst)
    return inst._brewing and "BREWING" or nil
end

local function OnSave(inst, data)
    if inst._brewing and inst._endtime ~= nil then
        data.remaining = math.max(0, inst._endtime - GetTime())
    end
end

local function OnLoad(inst, data)
    if data ~= nil and data.remaining ~= nil then
        StartBrew(inst, data.remaining)
    end
end

local function OnBuilt(inst)
    inst.SoundEmitter:PlaySound("dontstarve/common/place_structure_stone")
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, FURN.PHYSICS_RADIUS)

    inst.AnimState:SetBank(FURN.BANK)
    inst.AnimState:SetBuild(FURN.BUILD)
    inst.AnimState:PlayAnimation(FURN.ANIM, true)
    inst.AnimState:SetScale(FURN.ANIM_SCALE, FURN.ANIM_SCALE, FURN.ANIM_SCALE)
    SetFlames(inst, not FURN.FLAME_ONLY_WHEN_BREWING)

    inst.Light:SetRadius(2)
    inst.Light:SetFalloff(0.8)
    inst.Light:SetIntensity(0.7)
    inst.Light:SetColour(255 / 255, 160 / 255, 60 / 255)
    inst.Light:Enable(false)

    inst:AddTag("structure")
    inst:AddTag("cosu_lo_luyen_dan")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("container")
    inst.components.container:WidgetSetup(FURN.PREFAB)
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose
    inst.components.container.skipclosesnd = true
    inst.components.container.skipopensnd = true

    inst:AddComponent("lootdropper")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(OnHit)

    inst._brewing = false
    inst.TryStartBrew = TryStartBrew

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst:ListenForEvent("onbuilt", OnBuilt)

    return inst
end

return Prefab(FURN.PREFAB, fn, assets),
    MakePlacer(FURN.PLACER, FURN.BANK, FURN.BUILD, FURN.ANIM, nil, nil, nil, nil, nil, nil,
        function(inst)
            inst.AnimState:SetScale(FURN.ANIM_SCALE, FURN.ANIM_SCALE, FURN.ANIM_SCALE)
            SetFlames(inst, not FURN.FLAME_ONLY_WHEN_BREWING)
        end)