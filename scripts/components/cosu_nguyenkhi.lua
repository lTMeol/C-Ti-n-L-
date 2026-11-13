-- Nguyên Khí (chỉ chạy trên server). Số hiển thị cho máy khách nằm ở netvar
-- inst._cosu_qi / inst._cosu_qimax (tạo trong modmain.lua, AddPlayerPostInit).
local QI = require("cosu_qi_tuning")

local NguyenKhi = Class(function(self, inst)
    self.inst = inst
    self.max = QI.MAX     -- mức tối đa hiện tại = gốc + bonus
    self.bonus = 0        -- phần cộng thêm (Tiên Thiên Khí Vận), lưu riêng để không lẫn vào mức gốc
    self.current = QI.MAX -- người mới bắt đầu với nguyên khí đầy
    self.task = nil
    self:Sync()
    self:Start()
end)

function NguyenKhi:Sync()
    local inst = self.inst
    -- netvar là net_ushortint: tối đa 65535
    if inst._cosu_qimax ~= nil then inst._cosu_qimax:set(math.min(65535, math.max(0, math.floor(self.max)))) end
    if inst._cosu_qi ~= nil then inst._cosu_qi:set(math.min(65535, math.max(0, math.floor(self.current)))) end
end

function NguyenKhi:Start()
    if self.task ~= nil then self.task:Cancel() end
    self.task = self.inst:DoPeriodicTask(QI.TICK, function() self:OnTick() end)
end

function NguyenKhi:OnTick()
    if self.current >= self.max then return end
    -- ma / người đã chết thì không hồi
    if self.inst:HasTag("playerghost") or (self.inst.components.health ~= nil and self.inst.components.health:IsDead()) then
        return
    end
    local per_sec = self.max / (TUNING.TOTAL_DAY_TIME * QI.REGEN_DAYS)
    self:DoDelta(per_sec * QI.TICK)
end

function NguyenKhi:GetCurrent() return self.current end
function NguyenKhi:GetMax() return self.max end
function NguyenKhi:CanAfford(cost) return self.current >= (cost or 0) end

function NguyenKhi:DoDelta(amount)
    self.current = math.clamp(self.current + amount, 0, self.max)
    self:Sync()
end

-- Trừ nguyên khí. Trả về true nếu đủ và đã trừ.
function NguyenKhi:Spend(cost)
    cost = cost or 0
    if self.current < cost then return false end
    self:DoDelta(-cost)
    return true
end

-- m = mức tối đa GỐC (phần bonus từ khí vận được cộng lên trên)
function NguyenKhi:SetMax(m, keep_percent)
    local pct = self.current / self.max
    self.max = math.max(1, m + self.bonus)
    self.current = keep_percent and self.max * pct or math.min(self.current, self.max)
    self:Sync()
end

-- Cộng thêm nguyên khí tối đa (Tiên Thiên Khí Vận). b = tổng bonus hiện tại (không phải phần tăng thêm), có thể âm.
-- fill = true: phần tăng thêm được tặng luôn vào nguyên khí hiện tại. Mức tối đa không xuống dưới 1.
function NguyenKhi:SetBonusMax(b, fill)
    b = b or 0
    if b == self.bonus then return end
    local newmax = math.max(1, (self.max - self.bonus) + b)
    local delta = newmax - self.max
    self.bonus = b
    self.max = newmax
    if fill and delta > 0 then self.current = self.current + delta end
    self.current = math.clamp(self.current, 0, self.max)
    self:Sync()
end

function NguyenKhi:OnSave()
    return { current = self.current, max = self.max - self.bonus, bonus = self.bonus }
end

function NguyenKhi:OnLoad(data)
    if data == nil then return end
    self.bonus = data.bonus or 0
    self.max = math.max(1, (data.max or QI.MAX) + self.bonus)
    self.current = math.clamp(data.current or self.max, 0, self.max)
    self:Sync()
end

function NguyenKhi:GetDebugString()
    return string.format("%.1f / %d", self.current, self.max)
end

return NguyenKhi