-- Ví Linh Thạch của người chơi (chỉ server). Số dư đồng bộ xuống máy khách qua netvar inst._cosu_linhthach.
local function onamount(self)
    if self.inst._cosu_linhthach ~= nil then
        self.inst._cosu_linhthach:set(math.min(self.amount, 4000000000))
    end
end

local CosuLinhThach = Class(function(self, inst)
    self.inst = inst
    self.amount = 0
end, nil, { amount = onamount })

function CosuLinhThach:Get() return self.amount end
function CosuLinhThach:CanSpend(n) return self.amount >= n end

function CosuLinhThach:DoDelta(n)
    self.amount = math.max(0, self.amount + math.floor(n or 0))
    self.inst:PushEvent("cosu_linhthach_delta", { amount = self.amount })
end

-- Dùng khi mua / chế tạo bằng linh thạch: trả về true nếu đủ và đã trừ
function CosuLinhThach:Spend(n)
    if not self:CanSpend(n) then return false end
    self:DoDelta(-n)
    return true
end

function CosuLinhThach:OnSave() return { amount = self.amount } end
function CosuLinhThach:OnLoad(data) if data ~= nil then self.amount = data.amount or 0 end end

return CosuLinhThach