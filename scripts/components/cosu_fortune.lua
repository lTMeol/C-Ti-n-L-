-- Tiên Thiên Khí Vận (chỉ chạy trên máy chủ).
-- Người chơi mới vào thế giới -> server tạo danh sách khí vận để chọn -> người chơi roll / chọn / xác nhận.
-- Dữ liệu lưu theo nhân vật. Hiển thị cho máy khách qua inst._cosu_fortune (đã chọn) và inst._cosu_fortune_offer (đang chọn).
--
-- Tác dụng:
--   hp (máu tối đa), speed (% tốc độ chạy), qimax (nguyên khí tối đa)  -> áp dụng ngay trong Apply()
--   attack, defense, linh căn (hoa/moc/thuy/tho/loi...)                  -> cosu_element_combat.lua đọc qua GetBonus
--   startitem (vd linhchau_random)                                      -> GiveStartItems() tặng vật phẩm lúc xác nhận, 1 lần
--   charm, luck, demon, righteous, alchemy                              -> chưa có hệ thống dùng, chỉ lưu + hiển thị
-- Lấy giá trị:  player.components.cosu_fortune:GetBonus("attack")
-- Mỗi lần khí vận đổi, player nhận event "cosu_fortune_changed" (data = { bonus = {...} }).
local FT = require "cosu_fortune_tuning"
local ELEM = require "cosu_element_tuning"

local KEY = "cosu_fortune"

-- Vật phẩm tặng lúc bắt đầu: khóa startitem của khí vận (cosu_fortune_tuning.lua) -> hàm tặng cho người chơi
local START_GIVERS = {
    -- 1 viên linh căn ngẫu nhiên trong các hệ hiện có ở ELEM.LIST (thêm hệ mới vào đó thì tự có trong số này)
    linhchau_random = function(player)
        local list = ELEM.LIST
        if list == nil or #list == 0 or player.components.inventory == nil then return end
        local e = list[math.random(#list)]
        local item = SpawnPrefab(e.root)
        if item ~= nil then player.components.inventory:GiveItem(item, nil, player:GetPosition()) end
    end,
}

local function Draw(pool, count, exclude)
    local cand, out = {}, {}
    for _, d in ipairs(pool) do
        if not exclude[d.id] then table.insert(cand, d) end
    end
    for _ = 1, count do
        if #cand == 0 then break end
        local total = 0
        for _, d in ipairs(cand) do total = total + FT.RARITY[d.rarity].weight end
        local r = math.random() * total
        local pick = #cand
        for i, d in ipairs(cand) do
            r = r - FT.RARITY[d.rarity].weight
            if r <= 0 then
                pick = i
                break
            end
        end
        table.insert(out, table.remove(cand, pick).id)
    end
    return out
end

local Fortune = Class(function(self, inst)
    self.inst = inst
    self.chosen = {}
    self.offer = {}
    self.rolls = 0
    self.bonus = {}
    self.given = {} -- id khí vận đã tặng vật phẩm khởi đầu (có lưu, để vào lại game không tặng thêm)
    self.hp_applied = 0 -- máu tối đa đã cộng vào health (nhân vật nạp lại thì máu gốc được đặt lại, nên không lưu)

    -- lên / xuống bò: áp lại tốc độ (tốc độ khi cưỡi do con bò quyết định)
    inst:ListenForEvent("mounted", function() self:ApplySpeed() end)
    inst:ListenForEvent("dismounted", function() self:ApplySpeed() end)

    -- OnLoad chạy trước mốc 1 giây này; nhân vật chưa chọn thì mở danh sách
    inst:DoTaskInTime(1, function()
        if #self.chosen == 0 and #self.offer == 0 then self:StartPick() end
    end)
end)

function Fortune:Sync()
    local inst = self.inst
    if inst._cosu_fortune ~= nil then inst._cosu_fortune:set(table.concat(self.chosen, ",")) end
    if inst._cosu_fortune_offer ~= nil then inst._cosu_fortune_offer:set(table.concat(self.offer, ",")) end
end

function Fortune:GetBonus(key)
    return self.bonus[key] or 0
end

function Fortune:Has(id)
    for _, v in ipairs(self.chosen) do
        if v == id then return true end
    end
    return false
end

----------------------------------------------------------------- Danh sách để chọn
function Fortune:MakeOffer(locked)
    local pool = FT.Pool()
    local exclude, result = {}, {}
    for _, id in ipairs(locked or {}) do
        exclude[id] = true
        table.insert(result, id)
    end
    local need = FT.OFFER_COUNT - #result

    -- tránh hiện lại đúng những cái vừa hiện nếu kho đủ lớn
    local prev, avail = {}, 0
    for _, id in ipairs(self.offer) do
        if not exclude[id] then prev[id] = true end
    end
    for _, d in ipairs(pool) do
        if not exclude[d.id] and not prev[d.id] then avail = avail + 1 end
    end
    local ex2 = {}
    for k in pairs(exclude) do ex2[k] = true end
    if avail >= need then
        for k in pairs(prev) do ex2[k] = true end
    end

    for _, id in ipairs(Draw(pool, need, ex2)) do table.insert(result, id) end
    self.offer = result
    self:Sync()
end

function Fortune:StartPick()
    self.rolls = 0
    self.offer = {}
    self:MakeOffer({})
end

-- locked: chuỗi "id1,id2" các khí vận người chơi đang giữ lại (phải nằm trong danh sách hiện tại)
function Fortune:Roll(locked)
    if #self.offer == 0 then return end
    if FT.MAX_ROLLS ~= nil and self.rolls >= FT.MAX_ROLLS then return end
    local current = {}
    for _, id in ipairs(self.offer) do current[id] = true end
    local keep, seen = {}, {}
    for id in string.gmatch(locked or "", "[%w_]+") do
        if current[id] and not seen[id] and #keep < FT.PICK then
            seen[id] = true
            table.insert(keep, id)
        end
    end
    self.rolls = self.rolls + 1
    self:MakeOffer(keep)
end

function Fortune:Confirm(idstr)
    if #self.offer == 0 then return end
    local current = {}
    for _, id in ipairs(self.offer) do current[id] = true end
    local ids, seen = {}, {}
    for id in string.gmatch(idstr or "", "[%w_]+") do
        if current[id] and not seen[id] then
            seen[id] = true
            table.insert(ids, id)
        end
    end
    if #ids ~= math.min(FT.PICK, #self.offer) then return end
    self.chosen = ids
    self.offer = {}
    self:Sync()
    self:Apply(true)
    self:GiveStartItems()
end

-- tặng vật phẩm khởi đầu của các khí vận vừa chọn (mỗi khí vận chỉ một lần)
function Fortune:GiveStartItems()
    for _, id in ipairs(self.chosen) do
        local d = FT.BY_ID[id]
        local give = d ~= nil and d.startitem ~= nil and START_GIVERS[d.startitem] or nil
        if give ~= nil and not self.given[id] then
            self.given[id] = true
            give(self.inst)
        end
    end
end

-- gỡ khí vận để chọn lại (lệnh thử: c_cosu_fortune())
function Fortune:Reset()
    self.chosen = {}
    self.given = {}
    self:Apply()
    self:StartPick()
end

----------------------------------------------------------------- Tác dụng
function Fortune:ApplyHealth(fresh)
    local h = self.inst.components.health
    if h == nil then return end
    local delta = (self.bonus.hp or 0) - self.hp_applied
    if delta == 0 then return end
    local cur = h.currenthealth
    h:SetMaxHealth(h.maxhealth + delta) -- SetMaxHealth đặt máu đầy, nên đặt lại máu hiện tại ngay sau đó
    local newcur = cur + ((fresh and delta > 0) and delta or 0)
    h:SetCurrentHealth(math.max(1, math.min(newcur, h.maxhealth)))
    h:DoDelta(0, true, KEY, true)
    self.hp_applied = self.hp_applied + delta
end

-- Tốc độ chạy (% từ khí vận): đặt lên người chơi VÀ con vật đang cưỡi, xuống bò thì gỡ khỏi con bò
function Fortune:ApplySpeed()
    local inst = self.inst
    local pct = self.bonus.speed or 0
    local mult = pct ~= 0 and math.max(0.1, 1 + pct / 100) or nil
    local function set(ent)
        local loco = ent.components.locomotor
        if loco == nil then return end
        if mult ~= nil then
            loco:SetExternalSpeedMultiplier(inst, KEY, mult)
        else
            loco:RemoveExternalSpeedMultiplier(inst, KEY)
        end
    end
    set(inst)

    local rider = inst.components.rider
    local mount = (rider ~= nil and rider:IsRiding()) and rider:GetMount() or nil
    local old = self.speed_mount
    if old ~= nil and old ~= mount and old:IsValid() and old.components.locomotor ~= nil then
        old.components.locomotor:RemoveExternalSpeedMultiplier(inst, KEY)
    end
    if mount ~= nil and mount.components.locomotor ~= nil then
        set(mount)
        self.speed_mount = mult ~= nil and mount or nil
    else
        self.speed_mount = nil
    end
end

-- fresh = true khi vừa chọn xong (tặng luôn phần máu cộng thêm)
function Fortune:Apply(fresh)
    local inst = self.inst
    local b = FT.Sum(table.concat(self.chosen, ","))
    self.bonus = b

    self:ApplyHealth(fresh)

    local qi = inst.components.cosu_nguyenkhi
    if qi ~= nil and qi.SetBonusMax ~= nil then qi:SetBonusMax(b.qimax or 0, fresh) end

    self:ApplySpeed()

    inst:PushEvent("cosu_fortune_changed", { bonus = b })
end

----------------------------------------------------------------- Lưu / nạp
function Fortune:OnSave()
    return { chosen = self.chosen, given = self.given }
end

function Fortune:OnLoad(data)
    if data == nil then return end
    local list = {}
    for _, id in ipairs(data.chosen or {}) do
        if FT.BY_ID[id] ~= nil and #list < FT.PICK then table.insert(list, id) end
    end
    if #list ~= FT.PICK then list = {} end -- dữ liệu cũ không đủ / sai id -> chọn lại
    self.chosen = list
    self.given = {}
    for id, v in pairs(data.given or {}) do
        if v and FT.BY_ID[id] ~= nil then self.given[id] = true end
    end
    self:Sync()
    self.inst:DoTaskInTime(0, function() self:Apply() end)
end

return Fortune