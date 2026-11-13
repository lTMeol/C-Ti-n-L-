-- Hệ thống sát thương nguyên tố (chỉ chạy trên server). Số liệu: cosu_element_tuning.COMBAT.
--   * Quái có CẢNH GIỚI (Nhất Chuyển trở lên) mới có linh căn: số linh căn = số chuyển, mỗi linh căn mang 1 con số.
--     Quái cảnh giới 0 không có linh căn, không kháng gì.
--   * Quái có cảnh giới: kháng PHYS_RESIST sát thương thường; giảm (10% x số chuyển) sát thương nguyên tố
--     cùng hệ với linh căn của nó.
--   * Mỗi đòn quái trúng người chơi: mỗi linh căn bộc phát (xác suất MOB_PROC_CHANCE) gây thêm đúng con số
--     của linh căn đó, sát thương hệ đó (bỏ qua giáp, chỉ giảm bởi cổ trùng cùng hệ và đồ đúng hệ).
--   * Người chơi: mỗi cổ trùng đang trang bị cộng trực tiếp 1 linh căn (GU_ROOT_VALUE); mỗi đòn đánh gây thêm
--     TẤT CẢ hệ đang có, mỗi hệ đúng bằng con số linh căn (đã giảm theo cảnh giới quái nếu quái cũng có hệ đó).
local ELEM = require "cosu_element_tuning"
local GU = require "cosu_gu_tuning"
local C = ELEM.COMBAT
local FT = require "cosu_fortune_tuning"
local STATS = require "cosu_stats" -- chỉ số chiến đấu mới (Kháng linh căn dùng ở OnMobHitOther)

local STIM = "cosu_elem" -- stimuli đánh dấu đòn nguyên tố của người chơi (không bị kháng 50%)

local M = {}
M.STIM = STIM

-- Cộng thêm từ Tiên Thiên Khí Vận (component cosu_fortune, chỉ có trên người chơi); key: attack, defense, hoa, loi...
-- Ưu tiên tính từ chuỗi khí vận đã chọn (netvar _cosu_fortune) bằng FT.Sum, để các khóa đặc biệt như otherroot
-- (linh căn hệ khác -10) được trải ra đúng; chưa có chuỗi thì hỏi component.
local function FortuneBonus(player, key)
    if player == nil then return 0 end
    local nv = player._cosu_fortune
    local str = nv ~= nil and nv:value() or ""
    if str ~= "" then
        if player._cosu_fb_key ~= str then
            player._cosu_fb_key = str
            player._cosu_fb_sum = FT.Sum(str)
        end
        return player._cosu_fb_sum[key] or 0
    end
    local f = player.components.cosu_fortune
    return f ~= nil and f:GetBonus(key) or 0
end
M.FortuneBonus = FortuneBonus

local BY_ID = {}
for _, e in ipairs(ELEM.LIST) do
    BY_ID[e.id] = e
end

----------------------------------------------------------------- Tiện ích
-- Đòn đánh của người chơi hoặc đồng minh (Abigail, thú nuôi...)
local function IsPlayerSide(attacker)
    if attacker == nil or not attacker:IsValid() then return false end
    if attacker:HasTag("player") then return true end
    local f = attacker.components.follower
    local leader = f ~= nil and f:GetLeader() or nil
    return leader ~= nil and leader:HasTag("player")
end

-- số thứ tự cổ trùng -> tên prefab (đảo ngược GU.ID)
local ID_TO_PREFAB
-- trả về: hệ của cổ trùng (hoặc nil), tên prefab của cổ trùng
local function GuElem(id)
    if id == nil or id == 0 then return nil end
    local gu = GU.LIST[id]
    if gu == nil then return nil end
    if ID_TO_PREFAB == nil then
        ID_TO_PREFAB = {}
        for prefab, gid in pairs(GU.ID) do
            ID_TO_PREFAB[gid] = prefab
        end
    end
    local prefab = ID_TO_PREFAB[id]
    return gu.elem or C.GU_ELEM[prefab], prefab
end

-- Đếm cổ trùng đang trang bị (Bản Mệnh Cổ + các ô đã mở) theo hệ: { loi = 2, hoa = 1, ... }
function M.GetPlayerElems(player)
    local res = {}
    local bag = player.components.cosu_gu_bag
    if bag == nil or player:HasTag("playerghost") then return res end
    local function add(place)
        if not bag:CanUsePlace(place) then return end
        local e = GuElem(bag:GetPlace(place))
        if e ~= nil then res[e] = (res[e] or 0) + 1 end
    end
    add(0)
    for i = 1, GU.SLOTS do
        add(i)
    end
    return res
end

-- Linh căn của người chơi: { loi = 50, quang = 20 } = tổng con số các cổ trùng đang trang bị theo hệ
-- + khí vận. Bản Raw có thể ÂM (khí vận trừ linh căn, vd -10), dùng để hiện lên bảng nhân vật.
function M.GetPlayerRootsRaw(player)
    local res = {}
    local bag = player.components.cosu_gu_bag
    if bag == nil or player:HasTag("playerghost") then return res end
    local function add(place)
        if not bag:CanUsePlace(place) then return end
        local e, prefab = GuElem(bag:GetPlace(place))
        if e ~= nil then
            res[e] = (res[e] or 0) + (C.GU_ROOT_VALUE[prefab] or C.GU_ROOT_DEFAULT)
        end
    end
    add(0)
    for i = 1, GU.SLOTS do
        add(i)
    end
    -- linh căn cộng từ Tiên Thiên Khí Vận (khóa khí vận trùng id hệ: hoa, moc, thuy, tho, loi...)
    for _, e in ipairs(ELEM.LIST) do
        local v = FortuneBonus(player, e.id)
        if v ~= 0 then res[e.id] = (res[e.id] or 0) + v end
    end
    return res
end

-- Chỉ các linh căn dương: dùng để tính sát thương nguyên tố (linh căn âm / bằng 0 thì không gây sát thương hệ đó)
function M.GetPlayerRoots(player)
    local res = {}
    for id, v in pairs(M.GetPlayerRootsRaw(player)) do
        if v > 0 then res[id] = v end
    end
    return res
end

-- Sát thương nguyên tố hệ `id` được giảm bao nhiêu khi trúng người chơi
function M.GetPlayerReduction(player, id)
    local reduce = math.min(M.GetPlayerElems(player)[id] or 0, C.RESIST_GU_CAP) * C.RESIST_PER_GU
    if FT.DEFENSE_VS_ELEMENT then reduce = reduce + FortuneBonus(player, "defense") end -- phòng ngự lực khí vận cũng giảm sát thương nguyên tố
    local items = C.ARMOR_ELEM[id]
    local inv = player.components.inventory
    if items ~= nil and inv ~= nil then
        for _, slot in ipairs({ EQUIPSLOTS.HEAD, EQUIPSLOTS.BODY }) do
            local item = inv:GetEquippedItem(slot)
            if item ~= nil and items[item.prefab] then
                reduce = reduce + C.RESIST_PER_ARMOR
            end
        end
    end
    return reduce
end

----------------------------------------------------------------- Báo sát thương để hiện số nổi
-- Server gom các số trong cùng 1 khung hình rồi gửi 1 lần cho người chơi ở gần (client RPC "cosu"/"dmg").
-- Mỗi mục: "loại,x,z,độ cao,số" (loại: p = thường lên quái, pp = thường lên người chơi, hoặc id hệ; số -1 = kháng).
local DN = ELEM.DMGNUM
local queue = nil

local function Flush()
    local q = queue
    queue = nil
    if q == nil then return end
    for userid, list in pairs(q) do
        SendModRPCToClient(GetClientModRPC("cosu", "dmg"), userid, table.concat(list, ";"))
    end
end

function M.ReportDamage(target, amount, kind)
    if target == nil or not target:IsValid() or target.Transform == nil then return end
    local shown = amount < 0 and -1 or math.floor(amount + 0.5)
    if shown == 0 then return end
    local x, _, z = target.Transform:GetWorldPosition()
    local scale = target.Transform:GetScale() or 1
    local h = (target:HasTag("epic") and DN.EPIC_HEIGHT or DN.HEIGHT) * scale
    local entry = string.format("%s,%.1f,%.1f,%.1f,%d", kind, x, z, h, shown)
    for _, p in ipairs(TheSim:FindEntities(x, 0, z, DN.RADIUS, { "player" })) do
        local uid = p.userid
        if uid ~= nil and uid ~= "" then
            if queue == nil then
                queue = {}
                TheWorld:DoTaskInTime(0, Flush)
            end
            local list = queue[uid]
            if list == nil then
                list = {}
                queue[uid] = list
            end
            if #list < DN.MAX_PER_FLUSH then table.insert(list, entry) end
        end
    end
end

-- Sát thương thường (mọi lần mất máu tức thời trừ sát thương nguyên tố do mod tự báo)
function M.AttachDamageNumbers(inst)
    inst:ListenForEvent("healthdelta", function(i, data)
        if data == nil or data.overtime or i._cosu_elem_suppress then return end
        local amount = -(data.amount or 0)
        if amount < 0.5 then return end
        M.ReportDamage(i, amount, i:HasTag("player") and "pp" or "p")
    end)
end

----------------------------------------------------------------- Cảnh giới và linh căn của quái
-- Mỗi quái lưu: _cosu_mob_rank (số chuyển, 0 = Không), _cosu_root_list (danh sách id hệ),
-- _cosu_root_val ({ id = con số }), _cosu_roots ({ id = true }).
local function SetRoots(inst, rank, list, vals)
    inst._cosu_mob_rank = rank
    inst._cosu_root_list = list
    inst._cosu_root_val = vals
    if #list > 0 then
        inst._cosu_roots = {}
        for _, id in ipairs(list) do
            inst._cosu_roots[id] = true
        end
    else
        inst._cosu_roots = nil
    end
    if rank > 0 then
        inst:AddTag("cosu_has_root")
    else
        inst:RemoveTag("cosu_has_root")
    end
end

-- bốc ngẫu nhiên n hệ chưa có
local function PickRandom(list, taken, n)
    local pool = {}
    for _, e in ipairs(ELEM.LIST) do
        if not taken[e.id] then table.insert(pool, e.id) end
    end
    while n > 0 and #pool > 0 do
        local i = math.random(#pool)
        table.insert(list, pool[i])
        taken[pool[i]] = true
        table.remove(pool, i)
        n = n - 1
    end
end

-- con số của mỗi linh căn: ngẫu nhiên trong [MIN x số chuyển, MAX x số chuyển]
local function RollValues(list, rank)
    local vals = {}
    local lo = math.floor(C.ROOT_VALUE_PER_RANK_MIN * rank)
    local hi = math.max(lo, math.floor(C.ROOT_VALUE_PER_RANK_MAX * rank))
    for _, id in ipairs(list) do
        vals[id] = math.random(lo, hi)
    end
    return vals
end

-- Giảm sát thương nguyên tố của quái (0..ELEM_RESIST_MAX) khi hệ `id` trúng quái có linh căn hệ đó
function M.GetMobElemResist(mob, id)
    local rank = mob._cosu_mob_rank or 0
    if rank <= 0 or mob._cosu_roots == nil or not mob._cosu_roots[id] then return 0 end
    return math.min(C.ELEM_RESIST_PER_RANK * rank, C.ELEM_RESIST_MAX or 1)
end

-- Hệ số giảm sát thương linh căn nhận vào từ cổ trùng (Thạch Bì Cổ...)
local function GuRootTakenMult(player)
    local bag = player.components.cosu_gu_bag
    return bag ~= nil and bag:GetRootTakenMult() or 1
end

-- Quái đánh trúng người chơi: mỗi linh căn bộc phát thì gây thêm đúng con số của nó (bỏ qua giáp, chịu Kháng linh căn)
local function OnMobHitOther(mob, data)
    local target = data ~= nil and data.target or nil
    if target == nil or not target:IsValid() or not target:HasTag("player") then return end
    if target:HasTag("playerghost") then return end
    local health = target.components.health
    if health == nil or health:IsDead() then return end
    local list = mob._cosu_root_list
    local vals = mob._cosu_root_val
    if list == nil or #list == 0 or vals == nil then return end

    local chance = C.MOB_PROC_CHANCE or 1
    for _, id in ipairs(list) do
        if math.random() < chance then
            if health:IsDead() then break end -- đã chết thì không bộc phát tiếp
            -- giảm theo cổ trùng / đồ cùng hệ, rồi nhân hệ số Kháng linh căn của người chơi
            local dmg = ((vals[id] or 0) - M.GetPlayerReduction(target, id)) * STATS.RootTakenMult(target) * GuRootTakenMult(target)
            if dmg > 0 then
                -- DoDelta(lượng, overtime, cause, ignore_invincible, afflicter, ignore_absorb): không đi qua giáp
                target._cosu_elem_suppress = true -- số nổi do mod tự báo theo hệ, không để sự kiện máu báo thêm lần nữa
                health:DoDelta(-dmg, false, mob.prefab, false, mob, true)
                target._cosu_elem_suppress = nil
                M.ReportDamage(target, dmg, id)
            else
                M.ReportDamage(target, -1, id) -- giảm hết: hiện "0"
            end
        end
    end
end

-- Gọi khi quái xuất hiện. kind = "boss" | "normal". Cảnh giới + linh căn lưu theo quái nên không đổi khi tải lại thế giới.
function M.InitMob(inst, kind)
    local list, taken = {}, {}
    local rank = 0
    local maxroots = #ELEM.LIST - (C.BOSS_MIN_OPEN or 3)

    if kind == "boss" then
        rank = C.BOSS_RANK[inst.prefab] or C.BOSS_DEFAULT_RANK
        local want = math.min(rank, maxroots)
        for _, id in ipairs(C.BOSS_FIXED[inst.prefab] or {}) do
            if #list < want and BY_ID[id] ~= nil and not taken[id] then
                table.insert(list, id)
                taken[id] = true
            end
        end
        PickRandom(list, taken, want - #list)
    else
        local natural = C.NATURAL[inst.prefab]
        if natural ~= nil and BY_ID[natural] ~= nil then
            -- quái có hệ tự nhiên (chó lửa, chó băng...): luôn có cảnh giới
            rank = C.NATURAL_RANK or 1
            table.insert(list, natural)
            taken[natural] = true
        elseif math.random() < C.NORMAL_CHANCE then
            rank = 1
        end
        PickRandom(list, taken, math.min(rank, maxroots) - #list)
    end

    SetRoots(inst, rank, list, RollValues(list, rank))
    inst._cosu_root_kind = kind
    inst:ListenForEvent("onhitother", OnMobHitOther)

    -- lưu / nạp (kể cả quái không có cảnh giới, để lần sau không bốc lại)
    local old_save = inst.OnSave
    inst.OnSave = function(i, data, ...)
        local refs = old_save ~= nil and old_save(i, data, ...) or nil
        data.cosu_roots = i._cosu_root_list or {}
        data.cosu_root_vals = i._cosu_root_val or {}
        data.cosu_mob_rank = i._cosu_mob_rank or 0
        return refs
    end
    local old_load = inst.OnLoad
    inst.OnLoad = function(i, data, ...)
        if old_load ~= nil then old_load(i, data, ...) end
        if data ~= nil and data.cosu_roots ~= nil then
            local saved = {}
            for _, id in ipairs(data.cosu_roots) do
                if BY_ID[id] ~= nil then table.insert(saved, id) end
            end
            -- file lưu cũ (chưa có cảnh giới): lấy số linh căn làm số chuyển và bốc con số mới
            local srank = data.cosu_mob_rank or #saved
            local svals = {}
            local fresh = RollValues(saved, srank)
            for _, id in ipairs(saved) do
                svals[id] = (data.cosu_root_vals ~= nil and data.cosu_root_vals[id]) or fresh[id]
            end
            SetRoots(i, srank, saved, svals)
        end
    end
end

-- Mảnh vỡ rơi theo linh căn: { [tên prefab mảnh] = số lượng }, nil nếu quái không có linh căn
function M.GetShardDrops(inst)
    local list = inst._cosu_root_list
    if list == nil or #list == 0 then return nil end
    local n = inst._cosu_root_kind == "boss" and C.SHARDS_BOSS or C.SHARDS_NORMAL
    local per = {}
    for _, id in ipairs(list) do
        per[BY_ID[id].shard] = n
    end
    return per
end

----------------------------------------------------------------- Thông tin quái cho cửa sổ rê chuột
-- Máy khách hỏi qua RPC "cosu"/"mobinfo"; server trả lời bằng netvar player._cosu_mobinfo
-- dạng "số thứ tự|mã mạng của quái|id linh căn cách nhau dấu phẩy|loại|con số từng linh căn (cùng thứ tự, cách nhau dấu phẩy)|số chuyển"
-- (loại: boss / quai / pham; số chuyển 0 = Không).
local MI = ELEM.MOBINFO

local function KindOf(target)
    if target:HasTag("epic") then return "boss" end
    if target:HasTag("hostile") or target:HasTag("monster") then return "quai" end
    local combat = target.components.combat
    if combat ~= nil and combat.target ~= nil and combat.target:IsValid() and combat.target:HasTag("player") then
        return "quai"
    end
    return "pham"
end

local function BuildValueString(target)
    local out = {}
    for _, id in ipairs(target._cosu_root_list or {}) do
        table.insert(out, (target._cosu_root_val ~= nil and target._cosu_root_val[id]) or 0)
    end
    return table.concat(out, ",")
end

function M.SendMobInfo(player, target)
    if player == nil or player._cosu_mobinfo == nil then return end
    if target == nil or not target:IsValid() or target.Network == nil or target:HasTag("player") then return end
    if target.components.health == nil or target.components.combat == nil then return end
    if player:GetDistanceSqToInst(target) > MI.MAX_DIST * MI.MAX_DIST then return end

    -- chống gửi dồn dập; máy khách sẽ hỏi lại nếu chưa nhận được
    local now = GetTime()
    if player._cosu_mobinfo_t ~= nil and now - player._cosu_mobinfo_t < 0.05 then return end
    player._cosu_mobinfo_t = now

    player._cosu_mobinfo_seq = (player._cosu_mobinfo_seq or 0) + 1
    player._cosu_mobinfo:set(table.concat({
        player._cosu_mobinfo_seq,
        target.Network:GetNetworkID(),
        table.concat(target._cosu_root_list or {}, ","),
        KindOf(target),
        BuildValueString(target),
        target._cosu_mob_rank or 0,
    }, "|"))
end

----------------------------------------------------------------- Phía người chơi tấn công
function M.OnPlayerAttack(player, data)
    local target = data ~= nil and data.target or nil
    if target == nil or not target:IsValid() or target:HasTag("player") then return end
    if player._cosu_in_elem or (data ~= nil and data.stimuli == STIM) then return end
    if target.components.health == nil or target.components.health:IsDead() then return end
    if target.components.combat == nil or player:HasTag("playerghost") then return end
    local pc = player.components.combat
    if pc ~= nil and pc:IsAlly(target) then return end

    -- đánh ra tất cả hệ đang có, mỗi hệ đúng bằng con số linh căn
    local roots = M.GetPlayerRoots(player)
    local parts, total = {}, 0
    for _, e in ipairs(ELEM.LIST) do
        local v = roots[e.id]
        if v ~= nil and v > 0 then
            -- quái có cảnh giới + linh căn hệ này: giảm 10% x số chuyển
            local d = v * (1 - M.GetMobElemResist(target, e.id))
            if d >= 0.5 then
                d = math.floor(d + 0.5)
                total = total + d
                table.insert(parts, { e.id, d })
            else
                table.insert(parts, { e.id, -1 })
            end
        end
    end
    -- công kích lực (khí vận): mỗi đòn gây thêm sát thương thường cố định
    local flat = FortuneBonus(player, "attack")
    if flat > 0 and FT.ATTACK_USE_PHYS_RESIST and (target._cosu_mob_rank or 0) > 0 then
        flat = flat * (1 - C.PHYS_RESIST) -- quái có cảnh giới kháng sát thương thường
    end
    flat = flat > 0 and math.max(1, math.floor(flat + 0.5)) or 0
    if #parts == 0 and flat <= 0 then return end
    total = total + flat

    if total > 0 then
        player._cosu_in_elem = true
        target._cosu_elem_suppress = true
        target.components.combat:GetAttacked(player, total, nil, STIM)
        target._cosu_elem_suppress = nil
        player._cosu_in_elem = false
    end
    for _, part in ipairs(parts) do
        M.ReportDamage(target, part[2], part[1])
    end
    if flat > 0 then M.ReportDamage(target, flat, "p") end
end

-- Chuỗi linh căn của người chơi gửi cho máy khách (netvar _cosu_plroots), dạng "hoa:20,loi:50" (linh căn âm thì "hoa:-10")
local function RootsString(player)
    local roots = M.GetPlayerRootsRaw(player)
    local out = {}
    for _, e in ipairs(ELEM.LIST) do
        if roots[e.id] ~= nil and roots[e.id] ~= 0 then
            table.insert(out, e.id .. ":" .. roots[e.id])
        end
    end
    return table.concat(out, ",")
end

function M.AttachPlayer(player)
    player:ListenForEvent("onattackother", function(p, data) M.OnPlayerAttack(p, data) end)
    -- đồng bộ linh căn xuống máy khách cho bảng thông tin nhân vật
    player:DoPeriodicTask(0.5, function(p)
        if p._cosu_plroots ~= nil then
            local str = RootsString(p)
            if p._cosu_plroots:value() ~= str then p._cosu_plroots:set(str) end
        end
    end)
    M.AttachDamageNumbers(player)
end

----------------------------------------------------------------- Kháng sát thương thường
-- Gắn vào component combat: đòn của người chơi lên quái CÓ CẢNH GIỚI
--   * đòn nguyên tố (STIM): giữ nguyên (đã giảm theo chuyển trong OnPlayerAttack)
--   * kỹ năng điện ("electric": Giáng Lôi, Tích Lịch, Lôi Hóa...) tính là hệ Lôi: quái có Lôi linh căn giảm 10% x số chuyển
--   * còn lại: giảm PHYS_RESIST
function M.HookCombat(self)
    local old = self.GetAttacked
    self.GetAttacked = function(combat, attacker, damage, weapon, stimuli, ...)
        local mob = combat.inst
        -- phòng ngự lực (khí vận): người chơi nhận đòn thì mỗi đòn giảm một lượng sát thương cố định
        if damage ~= nil and damage > 0 and mob.components.cosu_fortune ~= nil then
            local def = mob.components.cosu_fortune:GetBonus("defense")
            if def > 0 then damage = math.max(0, damage - def) end
        end
        if (mob._cosu_mob_rank or 0) > 0 and damage ~= nil and damage > 0 and stimuli ~= STIM and IsPlayerSide(attacker) then
            if stimuli == "electric" then
                damage = damage * (1 - M.GetMobElemResist(mob, "loi"))
            else
                damage = damage * (1 - C.PHYS_RESIST)
            end
        end
        return old(combat, attacker, damage, weapon, stimuli, ...)
    end
end

return M