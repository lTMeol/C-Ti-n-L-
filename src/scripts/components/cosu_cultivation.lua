-- Cấp bậc cổ sư của người chơi (chạy trên server)
local COSU = require "cosu_tuning"
local PILL = require "cosu_pill_tuning"
local AWAKEN = require "cosu_awaken_tuning"

local Cultivation = Class(function(self, inst)
    self.inst = inst
    self.rank = 0     -- 0 = Phàm Nhân (chưa khai mở Nguyên Hải Thần Thức), 1..9 = Nhất Chuyển .. Cửu Chuyển
    self.stage = 0    -- 0 khi còn là Phàm Nhân; 1..4 = Sơ, Trung, Cao, Đỉnh Phong
    self.points = 0   -- điểm đã tích trong chuyển hiện tại
    self.bonus = { health = 0, sanity = 0, hunger = 0 }   -- chỉ số tối đa đã cộng thêm
    self:Sync()
end)

local STAGE_NAMES = { "Sơ Giai", "Trung Giai", "Cao Giai", "Đỉnh Phong" }

function Cultivation:GetRealmCost()
    if self.rank < 1 then return 0 end
    return math.max(1, math.floor(COSU.REALM_COST[self.rank] * COSU.COST_MULT + 0.5))
end

function Cultivation:StageFromPoints()
    if self.rank < 1 then return 0 end
    local cost = self:GetRealmCost()
    local stage = 1
    for s = 2, 4 do
        if self.points >= math.floor(cost * COSU.STAGE_AT[s] + 0.5) then
            stage = s
        end
    end
    return stage
end

-- điểm cần để lên giai kế tiếp (ở Đỉnh Phong thì là chi phí của cả chuyển)
function Cultivation:GetNeed()
    if self.rank < 1 then return 0 end
    local cost = self:GetRealmCost()
    if self.stage >= 4 then return cost end
    return math.floor(cost * COSU.STAGE_AT[self.stage + 1] + 0.5)
end

function Cultivation:Sync()
    self.inst._cosu_rank:set(self.rank)
    self.inst._cosu_stage:set(self.stage)
    self.inst._cosu_points:set(math.floor(self.points))
    self.inst._cosu_need:set(self:GetNeed())
end

local function Say(inst, str)
    if inst.components.talker ~= nil then
        inst.components.talker:Say(str)
    end
end

-- Nói trễ một nhịp để không bị câu báo lỗi mặc định của nhân vật (khi hành động thất bại) đè lên.
local function SayLater(inst, str)
    inst:DoTaskInTime(0, function(i)
        if i:IsValid() then Say(i, str) end
    end)
end

-- Cộng thêm chỉ số tối đa, giữ nguyên phần trăm hiện tại (không hồi đầy).
local function AddMaxStat(inst, stat, amount)
    local c = inst.components[stat]
    if c == nil then return end
    if stat == "health" then
        if c:IsDead() then return end
        local pct = c:GetPercent()
        c:SetMaxHealth(c.maxhealth + amount)
        c:SetPercent(pct, true)
    else
        local pct = c:GetPercent()
        c:SetMax(c.max + amount)
        c:SetPercent(pct, true)
    end
end

function Cultivation:GrantStat(stat)
    local amount = PILL.STAT_BONUS
    self.bonus[stat] = self.bonus[stat] + amount
    AddMaxStat(self.inst, stat, amount)
    return "+" .. amount .. " " .. PILL.STAT_NAMES[stat]
end

-- rank = 0 đưa nhân vật về Phàm Nhân (bị khóa)
function Cultivation:SetRank(rank, stage)
    self.rank = math.max(0, math.min(9, math.floor(rank or 0)))
    if self.rank == 0 then
        self.points = 0
        self.stage = 0
        self:Sync()
        self.inst:PushEvent("cosu_rankchanged", { rank = 0, stage = 0 })
        return
    end
    stage = math.max(1, math.min(4, math.floor(stage or 1)))
    local cost = self:GetRealmCost()
    self.points = math.floor(cost * COSU.STAGE_AT[stage] + 0.5)
    self.stage = self:StageFromPoints()
    self:Sync()
    self.inst:PushEvent("cosu_rankchanged", { rank = self.rank, stage = self.stage })
end

-- Khai mở Nguyên Hải Thần Thức: Phàm Nhân -> Nhất Chuyển Sơ Giai.
-- (Chưa gắn vào vật phẩm/sự kiện nào; để thử dùng c_cosu(1, 1) trong console.)
function Cultivation:Awaken()
    if self.rank >= 1 then return false end
    self:SetRank(1, 1)
    Say(self.inst, "Nguyên Hải Thần Thức đã khai mở! Ta là Cổ Sư Nhất Chuyển.")
    return true
end

-- Khai mở bằng vật phẩm (gọi từ NPC): kiểm tra đủ nguyên thạch, trừ đồ rồi Awaken().
function Cultivation:TryAwaken()
    if self.rank >= 1 then return false, "ALREADY" end
    local inv = self.inst.components.inventory
    if inv == nil then return false end
    for _, req in ipairs(AWAKEN.REQUIRE) do
        if not inv:Has(COSU.PREFAB[req.grade], req.count) then
            Say(self.inst, "Chưa đủ nguyên thạch để khai mở Nguyên Hải Thần Thức.")
            return false, "NOT_ENOUGH"
        end
    end
    for _, req in ipairs(AWAKEN.REQUIRE) do
        inv:ConsumeByName(COSU.PREFAB[req.grade], req.count)
    end
    return self:Awaken()
end

-- Cộng điểm, tối đa đến Đỉnh Phong.
-- Trả về: số điểm thực sự nhận được, danh sách chỉ số vừa được cộng (mỗi giai mới 1 chỉ số ngẫu nhiên).
function Cultivation:AddPoints(n, silent)
    if self.rank < 1 then return 0, {} end
    local cost = self:GetRealmCost()
    local before = self.stage
    local newpts = math.min(cost, self.points + n)
    local gained = newpts - self.points
    self.points = newpts
    self.stage = self:StageFromPoints()
    self:Sync()

    local rewards = {}
    if self.stage > before then
        for _ = before + 1, self.stage do
            table.insert(rewards, self:GrantStat(PILL.STATS[math.random(#PILL.STATS)]))
        end
        if not silent then
            Say(self.inst, "Đột phá! " .. STAGE_NAMES[self.stage] .. " (" .. table.concat(rewards, ", ") .. ")")
        end
        self.inst:PushEvent("cosu_rankchanged", { rank = self.rank, stage = self.stage })
    end
    return gained, rewards
end

-- Ăn nguyên thạch: ăn liền cả chồng, dừng khi chạm Đỉnh Phong (không ăn dư).
function Cultivation:AbsorbStone(stone)
    local sc = stone ~= nil and stone.components.cosu_stone or nil
    if sc == nil then return false end

    if self.rank < 1 then
        SayLater(self.inst, "Cần khai mở Nguyên Hải Thần Thức để bắt đầu hành trình cổ sư.")
        return false, "LOCKED"
    end

    if self.stage >= 4 then
        if self.rank >= 9 then
            SayLater(self.inst, "Ta đã đạt Cửu Chuyển Đỉnh Phong, không cần tu thêm.")
            return false, "MAX_PEAK"
        end
        SayLater(self.inst, "Đã tới Đỉnh Phong, cần đan dược để đột phá.")
        return false, "AT_PEAK"
    end

    local pts = COSU.POINTS[sc.grade] or 0
    local stackable = stone.components.stackable
    local available = stackable ~= nil and stackable:StackSize() or 1
    local stage_before = self.stage

    local used, total, rewards = 0, 0, {}
    while used < available and self.stage < 4 do
        local gained, got = self:AddPoints(pts, true)
        total = total + gained
        for _, r in ipairs(got) do table.insert(rewards, r) end
        used = used + 1
    end

    if stackable ~= nil then
        stackable:Get(used):Remove()
    else
        stone:Remove()
    end

    local suffix = used > 1 and (" (" .. used .. " viên)") or ""
    if self.stage > stage_before then
        Say(self.inst, "Đột phá! " .. STAGE_NAMES[self.stage] .. suffix
            .. " (" .. table.concat(rewards, ", ") .. ")")
    else
        Say(self.inst, "+" .. total .. " điểm tu vi" .. suffix)
    end
    return true
end

-- Dùng đan đột phá: phải đúng chuyển của viên đan và đang ở Đỉnh Phong.
function Cultivation:Breakthrough(pill)
    local pc = pill ~= nil and pill.components.cosu_pill or nil
    if pc == nil then return false end

    local names = PILL.RANK_NAMES

    if self.rank < 1 then
        SayLater(self.inst, "Cần khai mở Nguyên Hải Thần Thức để bắt đầu hành trình cổ sư.")
        return false, "LOCKED"
    end
    -- thất bại: trả về lý do, câu thoại nằm ở STRINGS...ACTIONFAIL (đăng ký trong modmain)
    if self.rank >= 9 then
        SayLater(self.inst, "Ta đã là Cửu Chuyển, không còn chuyển nào để đột phá.")
        return false, "MAX_RANK"
    end
    if pc.rank ~= self.rank then
        SayLater(self.inst, "Đan này dành cho " .. names[pc.rank] .. " Chuyển, ta đang ở "
            .. names[self.rank] .. " Chuyển.")
        return false, "WRONG_RANK"
    end
    if self.stage < 4 then
        SayLater(self.inst, "Chưa tới Đỉnh Phong " .. names[self.rank] .. " Chuyển, chưa thể đột phá.")
        return false, "NOT_PEAK"
    end

    -- tiêu hao đúng 1 viên
    if pill.components.stackable ~= nil then
        pill.components.stackable:Get(1):Remove()
    else
        pill:Remove()
    end

    self.rank = self.rank + 1
    self.stage = 1
    self.points = 0
    self:Sync()
    local rewards = {}
    for _, stat in ipairs(PILL.STATS) do
        table.insert(rewards, self:GrantStat(stat))
    end
    Say(self.inst, "Đột phá " .. names[self.rank] .. " Chuyển! (" .. table.concat(rewards, ", ") .. ")")
    self.inst:PushEvent("cosu_rankchanged", { rank = self.rank, stage = self.stage })
    return true
end

function Cultivation:OnSave()
    return { rank = self.rank, points = self.points, bonus = self.bonus }
end

function Cultivation:OnLoad(data)
    if data ~= nil then
        self.rank = math.max(0, math.min(9, math.floor(data.rank or 0)))
        self.points = math.max(0, data.points or 0)
        self.stage = self:StageFromPoints()
        self:Sync()

        if data.bonus ~= nil then
            for _, stat in ipairs(PILL.STATS) do
                self.bonus[stat] = math.max(0, data.bonus[stat] or 0)
            end
            -- áp lại sau khi mọi thành phần khác đã nạp xong (nhân vật tự đặt lại chỉ số gốc khi nạp)
            self.inst:DoTaskInTime(0, function(inst)
                if not inst:IsValid() then return end
                for _, stat in ipairs(PILL.STATS) do
                    if self.bonus[stat] > 0 then
                        AddMaxStat(inst, stat, self.bonus[stat])
                    end
                end
            end)
        end
    end
end

return Cultivation