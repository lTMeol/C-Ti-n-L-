-- Nguyên Hải: cổ trùng của người chơi (chỉ chạy trên server).
--   list  : cổ trùng đã luyện hóa nhưng chưa trang bị (hàng ô dưới cùng)
--   slots : 9 ô trang bị, slots[i] = số thứ tự cổ trùng hoặc 0 nếu trống
--   main  : ô Bản Mệnh Cổ, 0 nếu trống
-- Số thứ tự là vị trí trong cosu_gu_tuning.LIST. Đồng bộ xuống máy khách qua
-- inst._cosu_gu ("1,1,2") và inst._cosu_gu_eq ("main,s1,s2,...,s9").
local GU = require "cosu_gu_tuning"
local QI = require "cosu_qi_tuning"
local ELEM = require "cosu_element_tuning"

local CosuGuBag = Class(function(self, inst)
    self.inst = inst
    self.list = {}
    self.slots = {}
    for i = 1, GU.SLOTS do
        self.slots[i] = 0
    end
    self.main = 0
    self.hunger = {}      -- số thứ tự cổ trùng -> độ đói 0..1 (1 = no); về 0 là cổ chết
    self.hunger_sync = 0
    self.light = nil
    self.light_tier = 0
    self.cooldowns = {} -- kỹ năng chủ động: kind -> thời điểm hết hồi chiêu (GetTime)
    self.quang = nil    -- trạng thái Quang Hóa đang chạy
    self.star = nil     -- ánh sáng sao trời gần nhất đã thả
    self.loihoa = nil   -- trạng thái Lôi Hóa đang chạy
    self.stealth = nil  -- trạng thái Ẩn Thân đang chạy (Ẩn Thạch Cổ)

    inst:ListenForEvent("onremove", function() self:RemoveLight() end)
    inst:ListenForEvent("onattackother", function(_, data) self:OnAttackOther(data) end)
    inst:StartUpdatingComponent(self)
    inst:ListenForEvent("ms_becameghost", function() self:UpdateEffects() end)
    inst:ListenForEvent("ms_respawnedfromghost", function() self:UpdateEffects() end)
    -- lên / xuống bò: đặt lại hệ số tốc độ (áp cả lên con bò đang cưỡi)
    inst:ListenForEvent("mounted", function() self:UpdateUloi() self:UpdateThachBi() end)
    inst:ListenForEvent("dismounted", function() self:UpdateUloi() self:UpdateThachBi() end)
end)

function CosuGuBag:Sync()
    if self.inst._cosu_gu ~= nil then
        self.inst._cosu_gu:set(table.concat(self.list, ","))
    end
    if self.inst._cosu_gu_eq ~= nil then
        self.inst._cosu_gu_eq:set(self.main .. "," .. table.concat(self.slots, ","))
    end
    self:SyncHunger()
end

-- Mọi cổ trùng đang có (chưa trang bị + ô trang bị + Bản Mệnh Cổ)
function CosuGuBag:OwnedIds()
    local ids = {}
    if self.main ~= 0 then table.insert(ids, self.main) end
    for i = 1, GU.SLOTS do
        if self.slots[i] ~= 0 then table.insert(ids, self.slots[i]) end
    end
    for _, id in ipairs(self.list) do table.insert(ids, id) end
    return ids
end

-- Độ đói của từng cổ, dạng "id:phần trăm,..." (xem inst._cosu_gu_hunger)
function CosuGuBag:SyncHunger()
    if self.inst._cosu_gu_hunger == nil then return end
    local parts = {}
    for _, id in ipairs(self:OwnedIds()) do
        local h = self.hunger[id] or 1
        table.insert(parts, id .. ":" .. math.floor(h * 100 + 0.5))
    end
    self.inst._cosu_gu_hunger:set(table.concat(parts, ","))
end

function CosuGuBag:IsFull()
    return #self.list >= GU.MAX_GU
end

-- Loại cổ trùng này đã có trong Nguyên Hải chưa (trong danh sách, ô trang bị hoặc Bản Mệnh Cổ)?
function CosuGuBag:HasGu(id)
    if id == nil or id == 0 then return false end
    if self.main == id then return true end
    for i = 1, GU.SLOTS do
        if self.slots[i] == id then return true end
    end
    for _, v in ipairs(self.list) do
        if v == id then return true end
    end
    return false
end

local function Say(inst, text)
    if inst.components.talker ~= nil then
        inst.components.talker:Say(text)
    end
end

-- Tiêu count vật phẩm prefab trong túi; không đủ thì không tiêu gì và trả về false.
local function ConsumeItem(inst, prefab, count)
    local inv = inst.components.inventory
    if inv == nil or not inv:Has(prefab, count) then return false end
    for _ = 1, count do
        local item = inv:FindItem(function(i) return i.prefab == prefab end)
        if item == nil then return false end
        local taken = item.components.stackable ~= nil and item.components.stackable:Get() or item
        taken:Remove()
    end
    return true
end

-- Luyện hóa: lấy vật phẩm trong túi bỏ vào danh sách.
-- Mỗi loại cổ trùng chỉ luyện hóa được 1 lần (chế tạo thì không giới hạn).
function CosuGuBag:Refine(item)
    local id = item ~= nil and GU.ID[item.prefab] or nil
    if id == nil then
        return false, "INVALID"
    end
    if self:HasGu(id) then
        return false, "ALREADY"
    end
    -- cảnh giới: phải đạt chuyển của cổ trùng (rank >= gu.rank)
    local need = GU.LIST[id].rank or 1
    local rank = self.inst._cosu_rank ~= nil and self.inst._cosu_rank:value() or 0
    if rank < need then
        local names = ELEM.COMBAT.RANK_NAMES
        Say(self.inst, "Cảnh giới chưa đủ để luyện hóa cổ này (cần " .. (names[need] or (need .. " Chuyển")) .. ").")
        return false, "RANK"
    end
    if self:IsFull() then
        return false, "FULL"
    end
    table.insert(self.list, id)
    self.hunger[id] = 1 -- vừa luyện hóa: đang no
    self:Sync()
    item:Remove()
    return true
end

-- place = 0: Bản Mệnh Cổ; 1..9: các ô trang bị (ô n mở khi đạt chuyển n)
function CosuGuBag:CanUsePlace(place)
    local rank = self.inst._cosu_rank ~= nil and self.inst._cosu_rank:value() or 0
    if place == 0 then
        return rank >= 1
    end
    return place >= 1 and place <= GU.SLOTS and rank >= place
end

function CosuGuBag:GetPlace(place)
    if place == 0 then return self.main end
    return self.slots[place] or 0
end

function CosuGuBag:SetPlace(place, id)
    if place == 0 then
        self.main = id
    else
        self.slots[place] = id
    end
end

-- Trang bị cổ trùng ở vị trí idx trong danh sách vào ô place.
function CosuGuBag:Equip(place, idx)
    if not self:CanUsePlace(place) then return false end
    if self:GetPlace(place) ~= 0 then return false end
    local id = self.list[idx]
    if id == nil then return false end
    if place == 0 and GU.LIST[id] ~= nil and GU.LIST[id].no_main then
        Say(self.inst, (GU.LIST[id].name or "Cổ trùng này") .. " không thể trang bị vào ô Bản Mệnh Cổ.")
        return false
    end
    table.remove(self.list, idx)
    self:SetPlace(place, id)
    self:Sync()
    self:UpdateEffects()
    return true
end

-- Đá cần để gỡ: Bản Mệnh Cổ = thượng phẩm, các ô khác = trung phẩm (cấu hình ở GU.UNEQUIP_STONE)
function CosuGuBag:GetUnequipStone(place)
    local cfg = GU.UNEQUIP_STONE
    if cfg == nil then return nil end
    return place == 0 and cfg.main or cfg.slot
end

-- Gỡ cổ trùng ở ô place trả về danh sách. Có đủ nguyên thạch trong người thì gỡ được và tiêu đá;
-- không thì không mất gì và báo cho người chơi biết lý do.
function CosuGuBag:Unequip(place)
    if place ~= 0 and (place < 1 or place > GU.SLOTS) then return false end
    local id = self:GetPlace(place)
    if id == 0 then
        Say(self.inst, "Ô này không có cổ trùng để gỡ.")
        return false, "EMPTY"
    end
    if self:IsFull() then
        Say(self.inst, "Nguyên Hải đã đầy, không còn chỗ chứa cổ trùng gỡ xuống.")
        return false, "FULL"
    end

    local stone = self:GetUnequipStone(place)
    if stone ~= nil then
        local count = stone.count or 1
        local name = stone.name or stone.prefab
        if not ConsumeItem(self.inst, stone.prefab, count) then
            Say(self.inst, "Gỡ thất bại: cần " .. count .. " " .. name .. " trong người.")
            return false, "NO_STONE"
        end
    end
    self:SetPlace(place, 0)
    table.insert(self.list, id)
    self:Sync()
    self:UpdateEffects()
    Say(self.inst, "Đã gỡ cổ trùng xuống.")
    return true
end

----------------------------------------------------------------- Độ đói
-- Cổ chết vì đói: mất vĩnh viễn khỏi Nguyên Hải (danh sách, ô trang bị, Bản Mệnh Cổ).
function CosuGuBag:KillGu(id)
    local name = GU.LIST[id] ~= nil and GU.LIST[id].name or "Cổ trùng"
    for i = #self.list, 1, -1 do
        if self.list[i] == id then table.remove(self.list, i) end
    end
    for i = 1, GU.SLOTS do
        if self.slots[i] == id then self.slots[i] = 0 end
    end
    if self.main == id then self.main = 0 end
    self.hunger[id] = nil
    self:Sync()
    self:UpdateEffects()
    Say(self.inst, name .. " đã chết vì đói!")
end

function CosuGuBag:OnUpdate(dt)
    if self.inst:HasTag("playerghost") then return end
    local H = GU.HUNGER
    local step = dt / math.max(H.DURATION, 1)
    local dead = {}
    for _, id in ipairs(self:OwnedIds()) do
        local old = self.hunger[id] or 1
        local new = old - step
        if new <= 0 then
            table.insert(dead, id)
        else
            self.hunger[id] = new
            if old > H.WARN and new <= H.WARN then
                Say(self.inst, (GU.LIST[id] ~= nil and GU.LIST[id].name or "Cổ trùng") .. " sắp chết đói, cần cho ăn!")
            end
        end
    end
    for _, id in ipairs(dead) do
        self:KillGu(id)
    end
    self.hunger_sync = self.hunger_sync + dt
    if self.hunger_sync >= 1 then
        self.hunger_sync = 0
        self:SyncHunger()
    end
end

-- Cho cổ trùng id ăn 1 món (prefab) trong túi / balo. Server kiểm tra lại mọi thứ.
function CosuGuBag:Feed(id, prefab)
    local gu = GU.LIST[id]
    if gu == nil or not self:HasGu(id) then
        Say(self.inst, "Không có cổ trùng này để cho ăn.")
        return false, "NO_GU"
    end
    local H = GU.HUNGER
    if (self.hunger[id] or 1) >= 0.99 then
        Say(self.inst, gu.name .. " đang no, chưa cần ăn.")
        return false, "FULL"
    end
    local inv = self.inst.components.inventory
    local item = inv ~= nil and inv:FindItem(function(i) return i.prefab == prefab end) or nil
    if item == nil then
        Say(self.inst, "Trong người không còn món này.")
        return false, "NO_FOOD"
    end
    local edible = item.components.edible
    if edible == nil or not (H.FEED_SET[edible.foodtype] or H.FEED_SET[edible.secondaryfoodtype]) then
        Say(self.inst, gu.name .. " không ăn thứ này.")
        return false, "BAD_FOOD"
    end

    local value = edible.GetHunger ~= nil and edible:GetHunger(self.inst) or edible.hungervalue or 0
    local add = math.max(value, H.MIN_FOOD_VALUE) / H.FULL_VALUE
    local taken = item.components.stackable ~= nil and item.components.stackable:Get() or item
    taken:Remove()

    self.hunger[id] = math.min(1, (self.hunger[id] or 1) + add)
    self:SyncHunger()
    Say(self.inst, gu.name .. " đã ăn, độ đói còn " .. math.floor(self.hunger[id] * 100 + 0.5) .. "%.")
    return true
end

----------------------------------------------------------------- Hiệu ứng
-- 0: không sáng, 1: sáng yếu, 2: sáng mạnh (light = true được tính là 1)
local function LightLevel(id)
    local gu = GU.LIST[id]
    if gu == nil or not gu.light then return 0 end
    return gu.light == true and 1 or gu.light
end

function CosuGuBag:RemoveLight()
    if self.light ~= nil then
        if self.light:IsValid() then
            self.light:Remove()
        end
        self.light = nil
    end
    self.light_tier = 0
end

-- Lấy cấp sáng cao nhất trong Bản Mệnh Cổ + 9 ô trang bị
function CosuGuBag:UpdateEffects()
    self:UpdateUloi()
    self:UpdateStealth()
    self:UpdateThachBi()
    local tier = 0
    if not self.inst:HasTag("playerghost") then
        tier = LightLevel(self.main)
        for i = 1, GU.SLOTS do
            tier = math.max(tier, LightLevel(self.slots[i]))
        end
    end

    if tier == self.light_tier and (tier == 0 or (self.light ~= nil and self.light:IsValid())) then
        return
    end

    self:RemoveLight()
    if tier > 0 then
        local light = SpawnPrefab(tier == 2 and "cosu_gu_light_main" or "cosu_gu_light")
        if light ~= nil then
            light.entity:SetParent(self.inst.entity)
            self.light = light
            self.light_tier = tier
        end
    end
end

----------------------------------------------------------------- Kỹ năng chủ động
-- Bảng Nguyên Hải gửi RPC "gu_skill" (place) khi chuột phải vào cổ trùng đã trang bị.
-- Mỗi con cổ khai báo skill_slot / skill_main trong cosu_gu_tuning.lua.
local V = GU.VUONG
local U = GU.ULOI
local A = GU.ANTHACH

local function IsAlive(inst)
    return inst ~= nil and inst:IsValid() and not inst:HasTag("playerghost")
        and not (inst.components.health ~= nil and inst.components.health:IsDead())
end

local function IsEnemy(player, target)
    if target == nil or not target:IsValid() or target == player then return false end
    if target:HasTag("player") or target:HasTag("INLIMBO") then return false end
    if target.components.health == nil or target.components.health:IsDead() then return false end
    local combat = player.components.combat
    if combat ~= nil then
        if combat.CanTarget ~= nil and not combat:CanTarget(target) then return false end
        if combat.IsAlly ~= nil and combat:IsAlly(target) then return false end
    end
    return true
end

local COMBAT_MUST = { "_combat" }
local COMBAT_CANT = { "INLIMBO", "player", "playerghost", "FX", "NOCLICK", "wall", "companion" }

-- kẻ địch gần nhất: quái (monster/hostile/epic) hoặc con đang nhắm vào người chơi
local function FindNearestEnemy(player)
    local x, y, z = player.Transform:GetWorldPosition()
    local best, bestd
    for _, e in ipairs(TheSim:FindEntities(x, y, z, V.QUANG_RADIUS, COMBAT_MUST, COMBAT_CANT)) do
        if IsEnemy(player, e)
            and (e:HasTag("monster") or e:HasTag("hostile") or e:HasTag("epic")
                or (e.components.combat ~= nil and e.components.combat.target == player)) then
            local d = player:GetDistanceSqToInst(e)
            if bestd == nil or d < bestd then best, bestd = e, d end
        end
    end
    return best
end

-- Gửi số giây hồi chiêu còn lại xuống máy khách để nút kỹ năng hiện đếm ngược.
function CosuGuBag:SyncCooldowns()
    if self.inst._cosu_cd == nil then return end
    local parts = {}
    for kind in pairs(self.cooldowns) do
        local left = self:GetCooldownLeft(kind)
        if left > 0 then
            table.insert(parts, kind .. "=" .. string.format("%.1f", left))
        end
    end
    self.inst._cosu_cd:set(table.concat(parts, ";"))
end

-- Gửi thời gian còn lại của trạng thái đang chạy (Quang Hóa) để nút hiện đếm ngược.
function CosuGuBag:SyncActive()
    if self.inst._cosu_act == nil then return end
    local parts = {}
    if self.quang ~= nil and self.quang.endtime ~= nil then
        local left = math.max(0, self.quang.endtime - GetTime())
        table.insert(parts, "quanghoa=" .. string.format("%.1f", left))
    end
    if self.loihoa ~= nil and self.loihoa.endtime ~= nil then
        local left = math.max(0, self.loihoa.endtime - GetTime())
        table.insert(parts, "loihoa=" .. string.format("%.1f", left))
    end
    if self.stealth ~= nil then
        table.insert(parts, "anthan=99999") -- kỹ năng bật/tắt: không đếm ngược, số lớn = đang bật (nút hiện "Bật")
    end
    self.inst._cosu_act:set(table.concat(parts, ";"))
end

function CosuGuBag:GetCooldownLeft(kind)
    local t = self.cooldowns[kind]
    if t == nil then return 0 end
    return math.max(0, t - GetTime())
end

-- Sao trời: làm như Gậy Gọi Sao (hoạt ảnh vung gậy + ánh sáng "stafflight" của game).
-- Vị trí xa hơn V.STAR_RANGE so với người chơi sẽ bị kéo về mép phạm vi.
function CosuGuBag:CastStar(tx, tz)
    local player = self.inst
    local px, _, pz = player.Transform:GetWorldPosition()
    local x, z = px, pz
    if type(tx) == "number" and type(tz) == "number"
        and math.abs(tx) < 1e6 and math.abs(tz) < 1e6 then
        local dx, dz = tx - px, tz - pz
        local d = math.sqrt(dx * dx + dz * dz)
        local range = V.STAR_RANGE or 25
        if d > range then
            dx, dz = dx / d * range, dz / d * range
        end
        x, z = px + dx, pz + dz
    end

    -- hoạt ảnh vung gậy
    player:ForceFacePoint(x, 0, z)
    if player.sg ~= nil and player.sg.sg ~= nil and player.sg.sg.states["cosu_cast"] ~= nil then
        player.sg:GoToState("cosu_cast")
    end

    -- hết hoạt ảnh thì ánh sáng xuất hiện
    player:DoTaskInTime(V.STAR_CAST_DELAY or 0.9, function()
        if not player:IsValid() then return end
        if self.star ~= nil and self.star:IsValid() then
            self.star:Remove()
        end
        local star = SpawnPrefab("stafflight")
        if star ~= nil then
            star.Transform:SetPosition(x, 0, z)
            self.star = star
        end
    end)
    Say(player, "Ngôi sao này sẽ soi sáng cho ta.")
    return true
end

-- Quang Hóa: V.QUANG_DURATION giây đếm số đòn đánh trúng kẻ địch, hết giờ tung ra bấy nhiêu hồn ma.
function CosuGuBag:StartQuang()
    if self.quang ~= nil then return false end
    local player = self.inst
    local q = { count = 0, targets = {} }
    q.onattack = function(_, data)
        local target = data ~= nil and data.target or nil
        if target == nil or target.components.combat == nil or target:HasTag("player") then return end
        q.count = q.count + 1
        local known = false
        for _, t in ipairs(q.targets) do
            if t == target then known = true break end
        end
        if not known then table.insert(q.targets, target) end
    end
    player:ListenForEvent("onattackother", q.onattack)
    q.task = player:DoTaskInTime(V.QUANG_DURATION, function() self:FinishQuang() end)
    q.endtime = GetTime() + V.QUANG_DURATION
    self.quang = q
    self:SyncActive()
    Say(player, "Quang Hóa!")
    return true
end

-- Hồn ma của Enlightened Crown lao vào kẻ địch; sát thương do mình tự tính.
local function SpawnGestalt(player, target, damage)
    local g = SpawnPrefab(V.QUANG_PROJECTILE or "alterguardianhat_projectile")
    if g == nil then return false end

    -- phóng to hồn ma
    local s = V.QUANG_SCALE or 1.5
    g.Transform:SetScale(s, s, s)

    -- xuất hiện ở một điểm ngẫu nhiên quanh mục tiêu rồi quay mặt lao vào nó
    local tx, ty, tz = target.Transform:GetWorldPosition()
    local ang = math.random() * 2 * PI
    local r = GetRandomMinMax(2.5, 4)
    g.Transform:SetPosition(tx + r * math.cos(ang), 0, tz - r * math.sin(ang))
    g:ForceFacePoint(tx, ty, tz)
    if g.components.follower ~= nil then g.components.follower:SetLeader(player) end
    if g.components.combat ~= nil then
        g.components.combat:SetDefaultDamage(0) -- sát thương do mình tự tính bên dưới
        g.components.combat:SetTarget(target)
    end
    g:DoTaskInTime(1.5, function() if g:IsValid() then g:Remove() end end)

    -- gây sát thương khi hồn ma lao tới
    g:DoTaskInTime(0.4, function()
        if IsEnemy(player, target) and target.components.combat ~= nil then
            target.components.combat:GetAttacked(player, damage)
        end
    end)
    return true
end

function CosuGuBag:FinishQuang()
    local q = self.quang
    if q == nil then return end
    self.quang = nil
    self:SyncActive()
    if q.task ~= nil then q.task:Cancel() end
    self.inst:RemoveEventCallback("onattackother", q.onattack)

    local player = self.inst
    if q.count <= 0 or not IsAlive(player) then return end
    Say(player, "Quang Hóa: " .. q.count .. " hồn quang!")

    local left, idx, fired = q.count, 0, 0
    local list = q.targets
    local task
    task = player:DoPeriodicTask(V.QUANG_INTERVAL, function()
        if left <= 0 or not IsAlive(player) then
            task:Cancel()
            return
        end
        left = left - 1

        -- ưu tiên kẻ địch đã bị đánh (lần lượt từng con), không còn thì tìm con gần nhất
        local target
        for _ = 1, #list do
            idx = idx % #list + 1
            local t = list[idx]
            if IsEnemy(player, t) and player:GetDistanceSqToInst(t) <= V.QUANG_RADIUS * V.QUANG_RADIUS then
                target = t
                break
            end
        end
        if target == nil then target = FindNearestEnemy(player) end
        if target == nil then return end

        -- đòn thứ n: sát thương = cơ bản + (n-1) * bước
        local damage = V.QUANG_DAMAGE + fired * (V.QUANG_DAMAGE_STEP or 1)
        fired = fired + 1
        SpawnGestalt(player, target, damage)
    end)
end

----------------------------------------------------------------- Tích Lịch Cổ
local TL = GU.TICHLICH

-- Có cổ trùng mang nội tại `passive` đang trang bị ở ô đã mở không?
function CosuGuBag:HasPassive(passive)
    local function check(place)
        local gu = GU.LIST[self:GetPlace(place)]
        return gu ~= nil and gu.passive == passive and self:CanUsePlace(place)
    end
    if TL.PASSIVE_IN_MAIN and check(0) then return true end
    for i = 1, GU.SLOTS do
        if check(i) then return true end
    end
    return false
end

-- Giáng 1 tia sét (hiệu ứng sét của game) xuống thẳng mục tiêu, tự tính sát thương
local function StrikeTarget(player, target, damage)
    if target == nil or not target:IsValid() then return end
    local x, y, z = target.Transform:GetWorldPosition()
    local fx = SpawnPrefab("lightning")
    if fx ~= nil then fx.Transform:SetPosition(x, 0, z) end
    if target.components.health ~= nil and not target.components.health:IsDead()
        and target.components.combat ~= nil then
        target.components.combat:GetAttacked(player, damage, nil, "electric")
    end
end

-- Nội tại: đánh thường có xác suất gọi sét xuống mục tiêu; Lôi Hóa cộng thêm sát thương điện
function CosuGuBag:OnAttackOther(data)
    local target = data ~= nil and data.target or nil
    if target == nil or not target:IsValid() or target:HasTag("player") then return end
    if target.components.health == nil or target.components.health:IsDead() then return end
    if not IsAlive(self.inst) then return end
    if self.loihoa ~= nil then
        self:LoihoaHit(target, data)
        if not target:IsValid() or target.components.health == nil or target.components.health:IsDead() then return end
    end
    if not self:HasPassive("thunder") then return end
    if math.random() < TL.PASSIVE_CHANCE then
        StrikeTarget(self.inst, target, TL.PASSIVE_DAMAGE)
    end
end

-- Thiên Lôi: BOLT_COUNT tia sét giáng xuống sinh vật quanh người (bất kể thù hay không)
local THUNDER_MUST = { "_combat", "_health" }
local THUNDER_CANT = { "INLIMBO", "player", "playerghost", "FX", "NOCLICK", "wall", "companion", "structure" }

local function FindThunderTargets(player)
    local x, y, z = player.Transform:GetWorldPosition()
    local list = {}
    for _, e in ipairs(TheSim:FindEntities(x, y, z, TL.BOLT_RADIUS, THUNDER_MUST, THUNDER_CANT)) do
        local leader = e.components.follower ~= nil and e.components.follower:GetLeader() or nil
        if e ~= player and leader ~= player
            and e.components.health ~= nil and not e.components.health:IsDead() then
            table.insert(list, e)
        end
    end
    return list
end

function CosuGuBag:CastThunder()
    local player = self.inst
    if #FindThunderTargets(player) == 0 then
        Say(player, "Quanh đây không có mục tiêu nào để giáng sét.")
        return false
    end
    Say(player, "Thiên Lôi giáng thế!")
    local left = TL.BOLT_COUNT
    local task
    task = player:DoPeriodicTask(TL.BOLT_INTERVAL, function()
        if left <= 0 or not IsAlive(player) then
            task:Cancel()
            return
        end
        local list = FindThunderTargets(player) -- tìm lại mỗi tia: mục tiêu chết thì chuyển sang con khác
        if #list == 0 then
            task:Cancel()
            return
        end
        left = left - 1
        StrikeTarget(player, list[math.random(#list)], TL.BOLT_DAMAGE)
    end, 0)
    return true
end

-- place = 0: Bản Mệnh Cổ; 1..9: các ô trang bị
-- kind: tên kỹ năng (nil = kỹ năng đầu tiên của cổ); x, z: vị trí chọn bằng chuột phải (Sao trời, Giáng Lôi)
function CosuGuBag:UseSkill(place, kind, x, z)
    if type(place) ~= "number" or not IsAlive(self.inst) then return false end
    if not self:CanUsePlace(place) then return false end
    local gu = GU.LIST[self:GetPlace(place)]
    if gu == nil then return false end

    local skills = GU.GetSkills(gu, place)
    if kind == nil then kind = skills[1] end
    local valid = false
    for _, k in ipairs(skills) do
        if k == kind then valid = true break end
    end
    if not valid then return false end

    -- Ẩn Thân là kỹ năng bật/tắt: đang bật thì bấm lại để tắt (miễn phí, không hồi chiêu)
    if kind == "anthan" and self.stealth ~= nil then
        self:EndStealth()
        Say(self.inst, "Ta lộ diện.")
        return true
    end

    local left = self:GetCooldownLeft(kind)
    if left > 0 then
        Say(self.inst, "Cổ trùng còn đang hồi sức (" .. math.ceil(left) .. " giây).")
        return false
    end

    -- Nguyên khí: kiểm tra sau hồi chiêu, chỉ trừ khi kỹ năng dùng thành công
    local qi = self.inst.components.cosu_nguyenkhi
    local cost = GU.GetQiCost(gu, kind, QI)
    if qi ~= nil and not qi:CanAfford(cost) then
        Say(self.inst, QI.FAIL_TALK .. " (cần " .. cost .. ")")
        return false
    end

    local ok = false
    local cooldown = 0
    if kind == "star" then
        ok = self:CastStar(x, z)
        cooldown = V.STAR_COOLDOWN
    elseif kind == "quanghoa" then
        ok = self:StartQuang()
        cooldown = V.QUANG_DURATION + V.QUANG_COOLDOWN
    elseif kind == "thunder" then
        ok = self:CastThunder()
        cooldown = TL.COOLDOWN
    elseif kind == "loihoa" then
        ok = self:StartLoihoa()
        cooldown = U.LOIHOA_COOLDOWN
    elseif kind == "giangloi" then
        ok = self:CastGiangLoi(x, z)
        cooldown = U.GIANGLOI_COOLDOWN
    elseif kind == "anthan" then
        ok = self:StartStealth()
        cooldown = A.COOLDOWN
    end
    if ok then
        if qi ~= nil then qi:Spend(cost) end
        self.cooldowns[kind] = GetTime() + cooldown
        self:SyncCooldowns()
    end
    return ok
end

----------------------------------------------------------------- U Lôi Huyễn Điệp Cổ
-- Cổ đang trang bị ở đâu: "main" (Bản Mệnh Cổ), "slot" (9 ô) hoặc nil
function CosuGuBag:GetUloiPlace()
    local id = GU.ID["cosu_gu_uloi"]
    if id == nil or self.inst:HasTag("playerghost") then return nil end
    if self.main == id and self:CanUsePlace(0) then return "main" end
    for i = 1, GU.SLOTS do
        if self.slots[i] == id and self:CanUsePlace(i) then return "slot" end
    end
    return nil
end

-- Game kiểm tra inventory:IsInsulated() để quyết định có bị giật điện / sét đánh hay không (như đồ cách điện).
-- Bọc lại hàm này để cổ trùng cũng tính là cách điện.
local function HookInsulated(player)
    local inv = player.components.inventory
    if inv == nil or inv._cosu_insulated_hooked then return end
    inv._cosu_insulated_hooked = true
    local old = inv.IsInsulated
    inv.IsInsulated = function(self, ...)
        if player._cosu_elec_immune then return true end
        return old(self, ...)
    end
end

-- Đặt (mult) hoặc gỡ (mult = nil) hệ số tốc độ ngoài cho người chơi VÀ con vật đang cưỡi.
-- Khi cưỡi, tốc độ chạy do locomotor của con vật quyết định nên hệ số chỉ đặt lên người thì không có tác dụng.
function CosuGuBag:ApplySpeed(key, mult)
    local player = self.inst
    local function set(ent)
        local loco = ent.components.locomotor
        if loco == nil then return end
        if mult ~= nil then
            loco:SetExternalSpeedMultiplier(player, key, mult)
        else
            loco:RemoveExternalSpeedMultiplier(player, key)
        end
    end
    set(player)

    self.speed_mounts = self.speed_mounts or {}
    local old = self.speed_mounts[key]
    local rider = player.components.rider
    local mount = (rider ~= nil and rider:IsRiding()) and rider:GetMount() or nil
    if old ~= nil and old ~= mount and old:IsValid() and old.components.locomotor ~= nil then
        old.components.locomotor:RemoveExternalSpeedMultiplier(player, key) -- đã xuống khỏi con bò cũ
    end
    if mount ~= nil and mount.components.locomotor ~= nil then
        set(mount)
        self.speed_mounts[key] = mult ~= nil and mount or nil
    else
        self.speed_mounts[key] = nil
    end
end

-- Gọi mỗi khi trang bị thay đổi: miễn nhiễm điện + tăng tốc theo ô đang đặt U Lôi Huyễn Điệp Cổ
function CosuGuBag:UpdateUloi()
    local player = self.inst
    local where = self:GetUloiPlace()

    HookInsulated(player)
    player._cosu_elec_immune = where ~= nil
    if where ~= nil then
        if not player:HasTag("electricdamageimmune") then
            player:AddTag("electricdamageimmune")
            self.uloi_tag = true
        end
    elseif self.uloi_tag then
        player:RemoveTag("electricdamageimmune")
        self.uloi_tag = nil
    end

    self:ApplySpeed("cosu_uloi", where ~= nil and (where == "main" and U.SPEED_MAIN or U.SPEED_SLOT) or nil)

    -- gỡ cổ ra thì hết lôi hóa
    if where == nil and self.loihoa ~= nil then
        self:EndLoihoa()
    end
end

local function FoodPrefab(food)
    if food.prefab ~= nil then return food.prefab end
    for _, e in ipairs(ELEM.LIST) do
        if e.id == food.elem then return e[food.part] end
    end
    return nil
end

local function IsWet(target)
    if target.components.moisture ~= nil and target.components.moisture:IsWet() then
        return true
    end
    return target.GetIsWet ~= nil and target:GetIsWet() or false
end

-- Tìm mục trong U.LOIHOA_FOODS ứng với prefab này (nil nếu không phải vật phẩm lôi hóa)
function CosuGuBag:GetLoihoaFood(prefab)
    if prefab == nil then return nil end
    for _, food in ipairs(U.LOIHOA_FOODS) do
        if FoodPrefab(food) == prefab then return food end
    end
    return nil
end

-- Hấp thu 1 vật phẩm lôi hóa (chuột phải vào vật phẩm): chỉ cần đang trang bị U Lôi Huyễn Điệp Cổ.
-- Không tốn Nguyên Khí và không dính hồi chiêu; thời gian cộng dồn tối đa U.LOIHOA_MAX.
function CosuGuBag:AbsorbLoihoa(item)
    local player = self.inst
    if item == nil or not item:IsValid() or not IsAlive(player) then return false, "INVALID" end
    local food = self:GetLoihoaFood(item.prefab)
    if food == nil then return false, "INVALID" end
    if self:GetUloiPlace() == nil then return false, "NO_GU" end

    local now = GetTime()
    if self.loihoa ~= nil and self.loihoa.endtime ~= nil and self.loihoa.endtime - now >= U.LOIHOA_MAX - 0.5 then
        return false, "FULL"
    end

    -- lấy đúng 1 cái ra khỏi chồng rồi hủy
    local taken = item.components.stackable ~= nil and item.components.stackable:Get() or item
    if taken == nil then return false, "INVALID" end
    taken:Remove()

    local base = (self.loihoa ~= nil and self.loihoa.endtime or now)
    local endtime = math.min(base + food.seconds, now + U.LOIHOA_MAX)

    if self.loihoa ~= nil and self.loihoa.task ~= nil then self.loihoa.task:Cancel() end
    local fx = self.loihoa ~= nil and self.loihoa.fx or nil
    self.loihoa = { endtime = endtime, fx = fx }
    self.loihoa.task = player:DoTaskInTime(endtime - now, function() self:EndLoihoa() end)
    self:SyncActive()

    if fx == nil then
        fx = player:SpawnChild("electricchargedfx")
        if fx ~= nil then self.loihoa.fx = fx end
    end
    Say(player, "Lôi Hóa!")
    return true
end

-- Nút kỹ năng Lôi Hóa trong bảng Nguyên Hải: tự tìm 1 vật phẩm lôi hóa trong túi rồi hấp thu
function CosuGuBag:StartLoihoa()
    local player = self.inst
    local inv = player.components.inventory
    if inv == nil then return false end

    for _, food in ipairs(U.LOIHOA_FOODS) do
        local prefab = FoodPrefab(food)
        local item = prefab ~= nil and inv:FindItem(function(i) return i.prefab == prefab end) or nil
        if item ~= nil then
            return self:AbsorbLoihoa(item) == true
        end
    end
    Say(player, "Ta cần Sừng Dê, Mảnh Vỡ Lôi hoặc Lôi Linh Căn để lôi hóa.")
    return false
end

function CosuGuBag:EndLoihoa()
    local l = self.loihoa
    if l == nil then return end
    self.loihoa = nil
    if l.task ~= nil then l.task:Cancel() end
    if l.fx ~= nil and l.fx:IsValid() then l.fx:Remove() end
    self:SyncActive()
end

-- Đòn đánh thường khi lôi hóa: cộng thêm sát thương điện để tổng = hệ số x sát thương gốc
function CosuGuBag:LoihoaHit(target, data)
    local combat = self.inst.components.combat
    if combat == nil or target.components.combat == nil then return end
    local base = combat:CalcDamage(target, data ~= nil and data.weapon or nil)
    local mult = IsWet(target) and U.LOIHOA_WET_MULT or U.LOIHOA_MULT
    local extra = base * (mult - 1)
    if extra <= 0 then return end

    local fx = SpawnPrefab("electrichitsparks")
    if fx ~= nil and fx.AlignToTarget ~= nil then
        fx:AlignToTarget(target, self.inst, true)
    end
    target.components.combat:GetAttacked(self.inst, extra, nil, "electric")
end

-- Giáng Lôi: sét giáng xuống vị trí (x, z) chọn bằng chuột phải, trúng mọi kẻ địch trong ô vuông 2x2 ô.
--   * Phạm vi lấy từ U.GIANGLOI_HALF (nửa cạnh, 2x2 ô = 8 đơn vị -> HALF = 4). Vòng chỉ báo phạm vi khi chọn
--     chuột và lúc cast dùng chung giá trị này nên luôn giống nhau.
--   * Animation sét được gọi 2 lần nối tiếp: hết lần 1 mới đến lần 2.
--   * Tổng sát thương U.GIANGLOI_DAMAGE (600) chia đều cho 2 đợt (mỗi đợt 300), mỗi đợt trúng lúc tia sét chạm đất.
--   * Trong lúc animation chạy, tiếng sét được phát liên tục cho tới khi animation hết.
local GIANG_CANT = { "INLIMBO", "player", "playerghost", "FX", "NOCLICK", "wall", "companion", "structure" }

local GIANGLOI_WAVES = 2
local GIANGLOI_SOUND = "dontstarve/rain/thunder_close"
local GIANGLOI_SOUND_INTERVAL = 0.4 -- giây giữa 2 lần phát tiếng sét khi animation đang chạy
local GIANGLOI_FX_MAXTIME = 2       -- phòng hờ: quá số giây này mà fx chưa tự biến mất thì vẫn chuyển sang đợt sau

-- Gây sát thương lên mọi kẻ địch trong ô vuông (x, z) +- U.GIANGLOI_HALF
local function GiangLoiDamage(player, x, z, damage)
    local half = U.GIANGLOI_HALF
    for _, e in ipairs(TheSim:FindEntities(x, 0, z, half * 1.5, COMBAT_MUST, GIANG_CANT)) do
        local ex, _, ez = e.Transform:GetWorldPosition()
        if math.abs(ex - x) <= half and math.abs(ez - z) <= half and IsEnemy(player, e) then
            e.components.combat:GetAttacked(player, damage, nil, "electric")
        end
    end
end

-- 1 đợt sét: gọi animation, phát tiếng sét cho tới khi animation hết, gây sát thương, rồi nối sang đợt kế tiếp.
function CosuGuBag:GiangLoiWave(x, z, wave, damage)
    local player = self.inst
    if not player:IsValid() then return end

    local finished = false
    local function NextWave()
        if finished then return end
        finished = true
        if wave < GIANGLOI_WAVES then
            self:GiangLoiWave(x, z, wave + 1, damage)
        end
    end

    local fx = SpawnPrefab(U.GIANGLOI_FX)
    if fx == nil then
        GiangLoiDamage(player, x, z, damage)
        NextWave()
        return
    end

    fx.Transform:SetPosition(x, 0, z)
    local sc = U.GIANGLOI_FX_SCALE
    fx.Transform:SetScale(sc, sc, sc)

    -- tiếng sét: phát ngay khi animation bắt đầu rồi lặp lại cho tới khi animation hết (task của fx tự dừng khi fx bị xóa)
    local function Thunder()
        local emitter = fx.SoundEmitter or player.SoundEmitter
        if emitter ~= nil then
            emitter:PlaySound(GIANGLOI_SOUND)
        end
    end
    Thunder()
    fx:DoPeriodicTask(GIANGLOI_SOUND_INTERVAL, Thunder)

    -- sát thương trúng đúng lúc tia sét chạm đất trong animation
    player:DoTaskInTime(U.GIANGLOI_HIT_DELAY or 0, function()
        if not player:IsValid() then return end
        GiangLoiDamage(player, x, z, damage)
    end)

    -- animation này hết rồi mới gọi animation sau
    fx:ListenForEvent("onremove", NextWave)
    player:DoTaskInTime(GIANGLOI_FX_MAXTIME, NextWave)
end

function CosuGuBag:CastGiangLoi(tx, tz)
    local player = self.inst
    local px, _, pz = player.Transform:GetWorldPosition()
    local x, z = px, pz
    if type(tx) == "number" and type(tz) == "number"
        and math.abs(tx) < 1e6 and math.abs(tz) < 1e6 then
        local dx, dz = tx - px, tz - pz
        local d = math.sqrt(dx * dx + dz * dz)
        local range = U.GIANGLOI_RANGE
        if d > range then
            dx, dz = dx / d * range, dz / d * range
        end
        x, z = px + dx, pz + dz
    end

    player:ForceFacePoint(x, 0, z)
    if player.sg ~= nil and player.sg.sg ~= nil and player.sg.sg.states["cosu_cast"] ~= nil then
        player.sg:GoToState("cosu_cast")
    end

    -- hết hoạt ảnh cast thì mới gọi sét xuống; tổng sát thương chia đều cho các đợt
    local per_wave = U.GIANGLOI_DAMAGE / GIANGLOI_WAVES
    player:DoTaskInTime(U.GIANGLOI_CAST_DELAY, function()
        if not player:IsValid() then return end
        self:GiangLoiWave(x, z, 1, per_wave)
    end)
    Say(player, "Giáng Lôi!")
    return true
end

----------------------------------------------------------------- Thạch Bì Cổ
-- Ô trang bị (1..9) đang đặt Thạch Bì Cổ và đã mở; nil nếu không có. Bản Mệnh Cổ không tính.
function CosuGuBag:GetThachBiPlace()
    local id = GU.ID["cosu_gu_thachbi"]
    if id == nil or self.inst:HasTag("playerghost") then return nil end
    for i = 1, GU.SLOTS do
        if self.slots[i] == id and self:CanUsePlace(i) then return i end
    end
    return nil
end

-- Hệ số sát thương linh căn nhận vào (cosu_element_combat gọi): 1 = bình thường
function CosuGuBag:GetRootTakenMult()
    if self:GetThachBiPlace() ~= nil then
        return GU.THACHBI.ROOT_TAKEN_MULT
    end
    return 1
end

-- Gọi mỗi khi trang bị thay đổi: giảm di tốc khi đang mang Thạch Bì Cổ
function CosuGuBag:UpdateThachBi()
    self:ApplySpeed("cosu_thachbi", self:GetThachBiPlace() ~= nil and GU.THACHBI.SPEED_MULT or nil)
end

----------------------------------------------------------------- Ẩn Thạch Cổ
-- Ô trang bị (1..9) đang đặt Ẩn Thạch Cổ và đã mở; nil nếu không có. Bản Mệnh Cổ không tính.
function CosuGuBag:GetStealthPlace()
    local id = GU.ID["cosu_gu_anthach"]
    if id == nil or self.inst:HasTag("playerghost") then return nil end
    for i = 1, GU.SLOTS do
        if self.slots[i] == id and self:CanUsePlace(i) then return i end
    end
    return nil
end

-- Bắt mọi sinh vật đang nhắm vào người chơi bỏ mục tiêu
local function DropAggro(player)
    local x, y, z = player.Transform:GetWorldPosition()
    for _, e in ipairs(TheSim:FindEntities(x, y, z, A.DROP_RADIUS, { "_combat" }, { "INLIMBO", "player" })) do
        local c = e.components.combat
        if c ~= nil and c.target == player then
            c:DropTarget()
        end
    end
end

function CosuGuBag:StartStealth()
    local player = self.inst
    if self.stealth ~= nil then return false end
    if self:GetStealthPlace() == nil then return false end

    local s = { added_notarget = not player:HasTag("notarget") }
    -- tag "notarget": quái không chọn người chơi làm mục tiêu mới
    player:AddTag("notarget")
    player:AddTag("cosu_stealth")
    player.AnimState:SetMultColour(1, 1, 1, A.ALPHA)
    DropAggro(player)

    s.drop_task = player:DoPeriodicTask(A.DROP_INTERVAL, function() DropAggro(player) end)
    -- lần trừ nguyên khí đầu tiên đã làm ở UseSkill; từ đó cứ QI_INTERVAL giây trừ tiếp
    s.qi_task = player:DoPeriodicTask(A.QI_INTERVAL, function()
        if not IsAlive(player) or self:GetStealthPlace() == nil then
            self:EndStealth()
            return
        end
        local qi = player.components.cosu_nguyenkhi
        if qi ~= nil then
            if not qi:CanAfford(A.QI_COST) then
                Say(player, "Hết nguyên khí, không giữ được ẩn thân nữa.")
                self:EndStealth()
                return
            end
            qi:Spend(A.QI_COST)
        end
    end, A.QI_INTERVAL)

    self.stealth = s
    self:SyncActive()
    Say(player, "Ẩn thân.")
    return true
end

function CosuGuBag:EndStealth()
    local s = self.stealth
    if s == nil then return end
    self.stealth = nil
    if s.drop_task ~= nil then s.drop_task:Cancel() end
    if s.qi_task ~= nil then s.qi_task:Cancel() end
    local player = self.inst
    if player:IsValid() then
        player:RemoveTag("cosu_stealth")
        if s.added_notarget then player:RemoveTag("notarget") end
        player.AnimState:SetMultColour(1, 1, 1, 1)
    end
    self:SyncActive()
end

-- Gọi mỗi khi trang bị đổi: gỡ Ẩn Thạch Cổ ra (hoặc chết hóa ma) thì hết ẩn thân
function CosuGuBag:UpdateStealth()
    if self.stealth ~= nil and self:GetStealthPlace() == nil then
        self:EndStealth()
    end
end

----------------------------------------------------------------- Lệnh test
-- Hồi đầy nguyên khí và xóa hồi chiêu kỹ năng cổ trùng.
function CosuGuBag:RefillForTest()
    local qi = self.inst.components.cosu_nguyenkhi
    if qi ~= nil then
        qi:DoDelta(qi:GetMax())
    end
    self.cooldowns = {}
    self:SyncCooldowns()
end

-- Gõ trong console (bấm ~): c_cosu_qi()
function c_cosu_qi()
    local p = ConsoleCommandPlayer ~= nil and ConsoleCommandPlayer() or ThePlayer
    if p == nil then
        print("[cosu] không tìm thấy người chơi")
        return
    end
    -- hồi đầy nguyên khí (luôn làm được)
    if p.components.cosu_nguyenkhi ~= nil then
        p.components.cosu_nguyenkhi:DoDelta(p.components.cosu_nguyenkhi:GetMax())
    end
    -- xóa hồi chiêu: tìm component túi cổ trùng bất kể tên đăng ký
    for _, cmp in pairs(p.components) do
        if getmetatable(cmp) == CosuGuBag then
            cmp:RefillForTest()
            break
        end
    end
    print("[cosu] đã hồi đầy nguyên khí, xóa hồi chiêu")
end

----------------------------------------------------------------- Lưu / nạp
function CosuGuBag:OnSave()
    local hunger = {}
    for id, v in pairs(self.hunger) do
        table.insert(hunger, { id, v })
    end
    return { list = self.list, slots = self.slots, main = self.main, hunger = hunger }
end

function CosuGuBag:OnLoad(data)
    self.list = {}
    for i = 1, GU.SLOTS do
        self.slots[i] = 0
    end
    self.main = 0
    self.hunger = {}

    if data ~= nil then
        for _, id in ipairs(data.list or {}) do
            if GU.LIST[id] ~= nil and #self.list < GU.MAX_GU then
                table.insert(self.list, id)
            end
        end
        for i = 1, GU.SLOTS do
            local id = data.slots ~= nil and data.slots[i] or 0
            self.slots[i] = GU.LIST[id] ~= nil and id or 0
        end
        if GU.LIST[data.main] ~= nil then
            self.main = data.main
        end
        for _, pair in ipairs(data.hunger or {}) do
            if GU.LIST[pair[1]] ~= nil and type(pair[2]) == "number" then
                self.hunger[pair[1]] = math.max(0.01, math.min(1, pair[2]))
            end
        end
    end
    -- cổ chưa có số liệu (save cũ): coi như đang no
    self.hunger_sync = 0
    for _, id in ipairs(self:OwnedIds()) do
        if self.hunger[id] == nil then self.hunger[id] = 1 end
    end

    self:Sync()
    self.inst:DoTaskInTime(0, function() self:UpdateEffects() end)
end

return CosuGuBag