-- Số sát thương nổi (chỉ chạy trên máy khách). Server gửi các mục dạng "loại,x,z,độ cao,số" cách nhau dấu ";"
-- (xem ReportDamage trong cosu_element_combat.lua). Mỗi số là 1 thực thể phía máy khách dùng Label trong thế giới,
-- bay lên rồi biến mất. Màu, cỡ chữ, thời gian: cosu_element_tuning.DMGNUM.
local ELEM = require "cosu_element_tuning"

local D = ELEM.DMGNUM

local M = {}
local active = 0

local function SpawnNumber(kind, x, z, h, amount, order, count)
    if active >= D.MAX_ACTIVE then return end

    local resist = amount < 0
    local colour = D.COLOURS[kind] or D.COLOURS.p
    local text = resist and D.RESIST_TEXT or tostring(amount)
    local size = kind == "pp" and D.SIZE_PLAYER or D.SIZE

    -- các số cùng lúc tách ra: xen kẽ trái / phải, mỗi hàng 2 số, hàng sau cao hơn hàng trước
    local ox, oy
    if count == 1 then
        ox, oy = (math.random() - 0.5) * 0.6, 0
    else
        ox = (order % 2 == 1 and -0.5 or 0.5) * D.STACK_X + (math.random() - 0.5) * 0.3
        oy = math.floor((order - 1) / 2) * D.STACK_Y
    end

    local inst = CreateEntity()
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists = false
    inst.entity:AddTransform()
    inst.entity:AddLabel()
    inst.entity:SetCanSleep(false)
    inst.Transform:SetPosition(x, 0, z)

    local label = inst.Label
    label:SetFont(UIFONT)
    label:SetFontSize(size)
    label:SetColour(colour[1], colour[2], colour[3])
    label:SetText(text)
    label:SetWorldOffset(ox, h + oy, 0)
    label:Enable(true)

    active = active + 1
    inst:ListenForEvent("onremove", function() active = active - 1 end)

    local start = GetTime()
    inst:DoPeriodicTask(0, function()
        local p = (GetTime() - start) / D.LIFE
        if p >= 1 then
            inst:Remove()
            return
        end
        -- bay lên chậm dần
        local rise = D.RISE * (1 - (1 - p) * (1 - p))
        label:SetWorldOffset(ox, h + oy + rise, 0)
        -- nảy to lúc đầu, nhỏ dần lúc cuối
        local k = 1
        if p < 0.15 then
            k = 1.35 - 0.35 * (p / 0.15)
        elseif p > 0.7 then
            k = 1 - 0.5 * ((p - 0.7) / 0.3)
        end
        label:SetFontSize(size * k)
    end)
end

function M.Show(data)
    if type(data) ~= "string" then return end
    local list = {}
    for entry in string.gmatch(data, "[^;]+") do
        local kind, x, z, h, amount = string.match(entry, "^(%w+),(-?[%d%.]+),(-?[%d%.]+),([%d%.]+),(-?%d+)$")
        if kind ~= nil then
            table.insert(list, { kind, tonumber(x), tonumber(z), tonumber(h), tonumber(amount) })
        end
    end
    -- các số của cùng 1 mục tiêu trong cùng 1 lần gửi được xếp tách nhau; mục tiêu khác thì xếp riêng
    local groups, order = {}, {}
    for _, e in ipairs(list) do
        local key = string.format("%.0f:%.0f", e[2], e[3])
        if groups[key] == nil then
            groups[key] = {}
            table.insert(order, key)
        end
        table.insert(groups[key], e)
    end
    for _, key in ipairs(order) do
        local g = groups[key]
        for i, e in ipairs(g) do
            SpawnNumber(e[1], e[2], e[3], e[4], e[5], i, #g)
        end
    end
end

return M