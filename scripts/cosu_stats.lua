-- Logic chỉ số chiến đấu mới (chạy trên server). Số liệu: cosu_stats_tuning.lua.
--   Hội tâm   : tỉ lệ chí mạng = Hội tâm của kẻ đánh - Hộ tâm của người bị đánh
--   Bạo kích  : đòn chí mạng nhân (Bạo kích / 100); phần cộng thêm bị Kháng bạo của người bị đánh giảm
--   Kháng công: người chơi bị quái đánh thì sát thương giảm theo Kháng công pháp
--   Kháng linh: M.RootTakenMult(player) = hệ số nhân sát thương nguyên tố (linh căn) quái gây lên người chơi
local ST = require "cosu_stats_tuning"

local M = {}

-- cảnh giới quái do cosu_element_combat gán lúc quái xuất hiện (0 = Không)
local function MobRank(inst)
    return inst._cosu_mob_rank or 0
end

-- giá trị chỉ số key của một thực thể (người chơi: từ component; quái: theo cảnh giới)
function M.Get(inst, key)
    if inst == nil or not inst:IsValid() then return 0 end
    if inst:HasTag("player") then
        local c = inst.components.cosu_stats
        local v = c ~= nil and c:Get(key) or ST.DEF[key].base
        -- Tiên Thiên Khí Vận: crit -> Hội tâm, protect -> Hộ tâm (bảng B cũng cộng phần này lên netvar)
        local f = inst.components.cosu_fortune
        if f ~= nil then
            if key == "crit" then v = v + f:GetBonus("crit")
            elseif key == "guard" then v = v + f:GetBonus("protect") end
        end
        return v
    end
    local rank = MobRank(inst)
    local m = ST.MOB
    if key == "crit" then return m.CRIT_PER_RANK * rank end
    if key == "critdmg" then return m.CRITDMG_BASE + m.CRITDMG_PER_RANK * rank end
    if key == "guard" then return m.GUARD_PER_RANK * rank end
    if key == "critres" then return m.CRITRES_PER_RANK * rank end
    return 0
end

-- hệ số nhân sát thương nguyên tố mà người chơi phải nhận (dùng trong cosu_element_combat khi quái gây sát thương linh căn)
function M.RootTakenMult(player)
    return 1 - math.min(M.Get(player, "rootres"), ST.RES_CAP) / 100
end

-- tung xúc xắc chí mạng: trả về hệ số nhân (> 1) hoặc nil nếu không chí mạng
function M.RollCrit(attacker, target)
    local chance = M.Get(attacker, "crit") - M.Get(target, "guard")
    if chance <= 0 or math.random() * 100 >= chance then return nil end
    local extra = math.max(0, M.Get(attacker, "critdmg") / 100 - 1)
    extra = extra * (1 - math.min(M.Get(target, "critres"), ST.RES_CAP) / 100)
    return 1 + extra
end

local function Modify(target, attacker, damage)
    local mult = 1
    local crit = M.RollCrit(attacker, target)
    if crit ~= nil then
        mult = mult * crit
        attacker:PushEvent("cosu_crit", { target = target, mult = crit })
    end
    if target:HasTag("player") then
        mult = mult * (1 - math.min(M.Get(target, "artres"), ST.RES_CAP) / 100)
    end
    return damage * mult
end

-- AddComponentPostInit("combat", ...): bọc GetAttacked của mọi sinh vật
function M.HookCombat(self)
    local old = self.GetAttacked
    self.GetAttacked = function(comb, attacker, damage, weapon, stimuli, ...)
        if type(damage) == "number" and damage > 0 and attacker ~= nil and attacker ~= comb.inst
            and attacker:IsValid() and comb.inst:IsValid()
            and not (type(stimuli) == "string" and string.find(stimuli, "cosu", 1, true)) then
            local ok, new = pcall(Modify, comb.inst, attacker, damage)
            if ok and type(new) == "number" then damage = new end -- lỗi gì thì giữ nguyên sát thương gốc
        end
        return old(comb, attacker, damage, weapon, stimuli, ...)
    end
end

return M