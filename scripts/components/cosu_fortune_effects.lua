-- Áp tác dụng thật của Tiên Thiên Khí Vận lên đói / ngộ tính (chỉ chạy trên server).
--   hunger     : cộng vào mức đói TỐI ĐA thật (Tinh lực)
--   sanity     : cộng vào mức ngộ tính TỐI ĐA thật (Ngộ tính)
--   moodmax    : Tâm tình tối đa, cộng thêm vào mức ngộ tính TỐI ĐA thật (mod chỉ có một thanh ngộ tính/tâm tình)
--   sanitylock : nâng ngộ tính TỐI ĐA lên đúng giá trị này (vd 500). Chỉ nâng mức tối đa, ngộ tính vẫn tụt bình thường
--                bởi các hiệu ứng giảm ngộ tính, không bị giữ đầy
--   hungerrate (%) : đói nhanh/chậm hơn. -30 = đói chậm 30%, +30 = đói nhanh 30%
--   sanityrate (%) : tụt ngộ tính nhanh/chậm hơn (chỉ tính lúc đang tụt). -30 = tụt chậm 30%
--   moodregen  (%) : hồi ngộ tính. +50 = nhân thêm 50% tốc độ đang hồi, và tự hồi nền
--                    FT.MOOD_BASE_REGEN * 50% điểm mỗi giây (kể cả khi không có nguồn hồi nào)
-- Đọc từ netvar _cosu_fortune (do component cosu_fortune ghi) nên không phụ thuộc cách chọn / lưu khí vận.
local FT = require "cosu_fortune_tuning"

local SRC = "cosu_fortune"
local TICK = 1 -- giây

-- đổi mức tối đa (SetMax của DST luôn đặt lại thành đầy nên phải tự đặt lại lượng hiện có); trả về mức tối đa thực đã đổi
--   tăng tối đa -> lượng hiện có tăng theo cùng số (200/200 +20 -> 220/220, 150/200 +20 -> 170/220)
--   giảm tối đa -> lượng hiện có bị cắt xuống nếu vượt mức mới
--   saved_cur: lượng hiện có đã lưu từ lần chơi trước (khi tải game, DST đã cắt về mức tối đa gốc nên phải khôi phục lại)
local function AddMax(comp, delta, saved_cur)
    if comp == nil or comp.max == nil or delta == 0 then return 0 end
    local old_max, cur = comp.max, comp.current
    local new_max = math.max(1, old_max + delta)
    if new_max == old_max then return 0 end
    if saved_cur ~= nil then
        cur = saved_cur
    elseif new_max > old_max then
        cur = cur + (new_max - old_max)
    end
    comp:SetMax(new_max)
    comp.current = math.min(cur, new_max)
    comp:DoDelta(0)
    return new_max - old_max
end

local Effects = Class(function(self, inst)
    self.inst = inst
    self.key = nil
    self.sum = {}
    self.applied = { sanity = 0, hunger = 0 } -- phần mức tối đa khí vận đã cộng vào
    self.saved = nil -- lượng hiện có đã lưu (chỉ dùng ở nhịp đầu sau khi tải game)
    self.task = inst:DoPeriodicTask(TICK, function() self:OnTick() end)
end)

-- lưu lượng ngộ tính / đói hiện có, để lần tải sau khôi phục đúng (DST cắt về mức tối đa gốc lúc tải)
function Effects:OnSave()
    local s, h = self.inst.components.sanity, self.inst.components.hunger
    return { sanity = s ~= nil and s.current or nil, hunger = h ~= nil and h.current or nil }
end

function Effects:OnLoad(data)
    self.saved = data
end

function Effects:OnRemoveFromEntity()
    if self.task ~= nil then self.task:Cancel() self.task = nil end
    self.sum = {}
    self:ApplyHunger(0)
    self:ApplyMax()
end

-- đói: nhân hệ số tốc độ đói của nhân vật
function Effects:ApplyHunger(pct)
    local h = self.inst.components.hunger
    if h == nil then return end
    if h.burnratemodifiers == nil then
        if not self.warned then
            self.warned = true
            print("[cosu] hunger.burnratemodifiers khong ton tai, hungerrate cua khi van khong co tac dung")
        end
        return
    end
    if pct == 0 then
        h.burnratemodifiers:RemoveModifier(self.inst, SRC)
    else
        h.burnratemodifiers:SetModifier(self.inst, math.max(0, 1 + pct / 100), SRC)
    end
end

-- cộng / trừ mức tối đa của ngộ tính và đói theo khí vận (chỉ đổi phần chênh lệch)
function Effects:ApplyMax(saved)
    local inst = self.inst
    if inst:HasTag("playerghost") then return end
    for key, comp in pairs({ sanity = inst.components.sanity, hunger = inst.components.hunger }) do
        local want = self.sum[key] or 0
        if key == "sanity" then
            want = want + (self.sum.moodmax or 0)
            if comp ~= nil and comp.max ~= nil and (self.sum.sanitylock or 0) > 0 then
                -- nâng mức tối đa lên đúng giá trị này: mức tối đa gốc (đã trừ phần khí vận đã cộng) + phần cộng = sanitylock
                -- (chỉ nâng, không bao giờ làm mức tối đa thấp hơn so với khi không có khóa)
                want = math.max(want, self.sum.sanitylock - (comp.max - self.applied.sanity))
            end
        end
        local diff = want - self.applied[key]
        if diff ~= 0 and comp ~= nil then
            self.applied[key] = self.applied[key] + AddMax(comp, diff, saved ~= nil and saved[key] or nil)
        end
    end
end

function Effects:Refresh()
    local nv = self.inst._cosu_fortune
    local str = nv ~= nil and nv:value() or ""
    local first = self.key == nil
    if str ~= self.key then
        self.key = str
        self.sum = FT.Sum(str)
        self:ApplyHunger(self.sum.hungerrate or 0)
    end
    -- nhịp đầu sau khi tải game: khôi phục đúng lượng hiện có đã lưu; các nhịp sau (vd vừa chọn khí vận) thì tăng theo mức tối đa
    -- ApplyMax chạy mỗi nhịp để tự áp lại nếu lần trước chưa áp được (vd đang là ma)
    self:ApplyMax(first and self.saved or nil)
    if first then self.saved = nil end
end

-- ngộ tính: mỗi giây bù thêm / bớt theo tốc độ hồi hoặc tụt hiện tại (sanity.rate)
function Effects:OnTick()
    self:Refresh()
    local inst = self.inst
    if inst:HasTag("playerghost") or (inst.components.health ~= nil and inst.components.health:IsDead()) then return end
    local s = inst.components.sanity
    if s == nil then return end
    local r = s.rate or 0
    local mood = (self.sum.moodregen or 0) / 100
    local extra = 0
    if r > 0 then
        extra = r * mood
    elseif r < 0 then
        extra = r * (self.sum.sanityrate or 0) / 100 -- r < 0, sanityrate < 0 -> extra > 0 (tụt chậm lại)
    end
    if mood > 0 then
        extra = extra + (FT.MOOD_BASE_REGEN or 0) * mood -- tự hồi nền
    end
    if extra ~= 0 then s:DoDelta(extra * TICK, true) end
end

return Effects