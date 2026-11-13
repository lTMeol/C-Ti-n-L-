-- Chỉ số chiến đấu của người chơi = giá trị gốc (cosu_stats_tuning.DEF) + các nguồn cộng thêm.
-- Nguồn khác (cổ trùng, khí vận, trang bị...) cộng chỉ số bằng:
--   player.components.cosu_stats:SetBonus("crit", "ten_nguon", 10)   -- đặt 0 để bỏ
local ST = require "cosu_stats_tuning"

local CosuStats = Class(function(self, inst)
    self.inst = inst
    self.bonus = {} -- bonus[key][nguồn] = số
    self:Sync()
end)

function CosuStats:Get(key)
    local d = ST.DEF[key]
    if d == nil then return 0 end
    local v = d.base
    for _, x in pairs(self.bonus[key] or {}) do v = v + x end
    if d.max ~= nil then v = math.min(v, d.max) end
    return math.max(0, v)
end

function CosuStats:SetBonus(key, source, value)
    if ST.DEF[key] == nil then return end
    self.bonus[key] = self.bonus[key] or {}
    self.bonus[key][source] = (value ~= nil and value ~= 0) and value or nil
    self:Sync()
end

-- gửi xuống máy khách (bảng thông tin nhân vật đọc các netvar này)
function CosuStats:Sync()
    for key, d in pairs(ST.DEF) do
        local nv = self.inst[d.netvar]
        if nv ~= nil then nv:set(math.floor(self:Get(key) + 0.5)) end
    end
end

return CosuStats