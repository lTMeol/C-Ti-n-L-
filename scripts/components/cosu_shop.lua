-- scripts/components/cosu_shop.lua : gắn vào Thạch Quán. Giữ kho 9 viên đá + xử lý đổ thạch (chỉ chạy trên server).
-- Kho gửi xuống máy khách qua inst._stock (net_string khai báo trong prefab cosu_house), dạng "chỉ_số_đá:giá;..."
local T = require "cosu_shop_tuning"

local USE_DIST = 15

local function RoundPrice(p)
    p = math.floor(p / 50 + 0.5) * 50
    return math.max(T.PRICE_MIN, math.min(T.PRICE_MAX, p))
end

local function GiveStack(player, prefab, count)
    local pos = player:GetPosition()
    while count > 0 do
        local item = SpawnPrefab(prefab)
        if item == nil then return end
        local n = 1
        if item.components.stackable ~= nil then
            n = math.min(count, item.components.stackable.maxsize)
            item.components.stackable:SetStackSize(n)
        end
        player.components.inventory:GiveItem(item, nil, pos) -- đầy túi thì tự rơi ra đất
        count = count - n
    end
end

local CosuShop = Class(function(self, inst)
    self.inst = inst
    -- mỗi ô là {stone = chỉ số trong T.STONES, price = giá gốc} hoặc {refill = ngày thế giới mà ô trống này có hàng lại}
    self.stock = {}
    inst:DoTaskInTime(0, function()
        if #self.stock ~= T.SLOTS then self:Restock() else self:CheckRefill() end
    end)
    inst:WatchWorldState("cycles", function() self:CheckRefill() end) -- sang ngày mới: ô trống nào đến hạn thì có đá mới
end)

-- chọn hình đá chưa có trong kho (hết hình thì cho trùng); giá ngẫu nhiên, không liên quan hình dạng
function CosuShop:RollSlot()
    local used = {}
    for _, e in ipairs(self.stock) do
        if e.stone ~= nil then used[e.stone] = true end
    end
    local free = {}
    for i = 1, #T.STONES do
        if not used[i] then table.insert(free, i) end
    end
    local i = #free > 0 and free[math.random(#free)] or math.random(#T.STONES)
    return { stone = i, price = RoundPrice(math.random(T.PRICE_MIN, T.PRICE_MAX)) }
end

function CosuShop:Restock()
    self.stock = {}
    for i = 1, T.SLOTS do self.stock[i] = self:RollSlot() end
    self:Sync()
end

-- ô trống nào đã đến hạn thì thế viên mới vào
function CosuShop:CheckRefill()
    local today = TheWorld.state.cycles or 0
    for i, e in ipairs(self.stock) do
        if e.stone == nil and (e.refill or 0) <= today then
            self.stock[i] = self:RollSlot()
        end
    end
    self:Sync()
end

-- gửi xuống máy khách: "chỉ_số_đá:giá;..." ; ô trống ghi là "-" (vẫn đủ T.SLOTS phần tử để giữ đúng vị trí)
function CosuShop:Sync()
    local parts = {}
    for _, e in ipairs(self.stock) do
        table.insert(parts, e.stone ~= nil and (e.stone .. ":" .. e.price) or "-")
    end
    if self.inst._stock ~= nil then self.inst._stock:set(table.concat(parts, ";")) end
end

-- MỐC SAU NÀY: trả về { prefab = "...", count = 1 } khi đã có cổ trùng; trả nil thì quay lại bảng thưởng thường
function CosuShop:RollGu(player)
    local list, total = {}, 0
    for _, r in ipairs(T.GU_REWARDS or {}) do
        if Prefabs[r[1]] ~= nil and r[4] > 0 then
            total = total + r[4]
            table.insert(list, r)
        end
    end
    if #list == 0 then return nil end
    local x = math.random() * total
    for _, r in ipairs(list) do
        x = x - r[4]
        if x <= 0 then return { prefab = r[1], count = math.random(r[2], r[3]) } end
    end
    local r = list[#list]
    return { prefab = r[1], count = r[2] }
end

function CosuShop:Roll(player)
    local guchance = T.GuChance(player) -- 1% cơ bản + 1% mỗi 10 may mắn
    if guchance > 0 and math.random() < guchance then
        local gu = self:RollGu(player)
        if gu ~= nil then return gu.prefab, gu.count or 1 end
    end
    local list, total = {}, 0
    for _, r in ipairs(T.REWARDS) do
        if Prefabs[r[1]] ~= nil and r[4] > 0 then
            total = total + r[4]
            table.insert(list, r)
        end
    end
    local x = math.random() * total
    for _, r in ipairs(list) do
        x = x - r[4]
        if x <= 0 then return r[1], math.random(r[2], r[3]) end
    end
    local r = list[#list]
    return r[1], r[2]
end

function CosuShop:Gamble(player, slot)
    slot = tonumber(slot)
    if slot == nil then return end
    slot = math.floor(slot)
    local e = self.stock[slot]
    if e == nil or e.stone == nil or player == nil or not player:IsValid() or player.components.inventory == nil then return end -- ô trống thì không bán
    if player:GetDistanceSqToInst(self.inst) > USE_DIST * USE_DIST then return end

    local wallet = player.components.cosu_linhthach
    local price = T.AdjustPrice(e.price, player) -- mị lực giảm giá, ma đạo > chính đạo tăng giá (client tính y hệt để hiển thị)
    if wallet == nil or not wallet:Spend(price) then return end -- không đủ tiền thì không trừ, không giao dịch

    local prefab, count = self:Roll(player)
    GiveStack(player, prefab, count)

    self.stock[slot] = { refill = (TheWorld.state.cycles or 0) + T.REFILL_DAYS } -- viên vừa mở: ô trống cho đến khi hết hạn
    self:Sync()
    SendModRPCToClient(GetClientModRPC("cosu", "shopresult"), player.userid, prefab, count)
end

function CosuShop:OnSave()
    return { stock = self.stock }
end

function CosuShop:OnLoad(data)
    if data ~= nil and data.stock ~= nil and #data.stock == T.SLOTS then
        local ok = true
        for _, e in ipairs(data.stock) do
            if e.stone ~= nil then
                if T.STONES[e.stone] == nil or type(e.price) ~= "number" then ok = false end
            elseif type(e.refill) ~= "number" then
                ok = false
            end
        end
        if ok then self.stock = data.stock end
    end
end

return CosuShop