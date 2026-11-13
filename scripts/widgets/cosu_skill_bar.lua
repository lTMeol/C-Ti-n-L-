-- Hàng nút kỹ năng cổ trùng, nằm cạnh nút Nguyên Hải Thần Thức (là con của nút đó nên kéo nút là kéo theo).
-- Chỉ hiện nút của cổ đã trang bị và có kỹ năng chủ động.
-- Bấm nút hoặc nhấn phím tắt (cosu_gu_tuning.SKILL_KEYS) để dùng.
-- Rê chuột vào nút sẽ hiện cửa sổ mô tả kỹ năng.
--   * Kỹ năng thường (Quang Hóa, Thiên Lôi): dùng ngay.
--   * Kỹ năng chọn vị trí (Sao trời): bấm xong sẽ hiện vòng chọn như Gậy Gọi Sao,
--     chuột phải lên mặt đất để đặt.
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Text = require "widgets/text"
local GU = require "cosu_gu_tuning"
local QI = require "cosu_qi_tuning"

local SPACING = 46         -- khoảng cách giữa 2 nút (trước là 70)
local ICON_SCALE = 0.45    -- cỡ icon cổ trùng (trước là 0.7)
local BG_SCALE = 0.72      -- cỡ ô nền (trước là 1.1)
local TARGET_TIMEOUT = 15  -- giây; quá lâu không chọn thì tự hủy chế độ chọn vị trí

local TIP_WIDTH = 300      -- bề rộng cửa sổ mô tả
local TIP_Y = 70           -- cửa sổ mô tả nằm cao hơn hàng nút bấy nhiêu

-- kỹ năng cần chọn vị trí bằng chuột phải: kind -> chữ hướng dẫn
local TARGETED = {
    star = "Chuột phải lên mặt đất để gọi Sao trời (bấm nút lại để hủy)",
    giangloi = "Chuột phải lên mặt đất để Giáng Lôi (bấm nút lại để hủy)",
}

-- kỹ năng bật/tắt: bấm lần nữa để tắt (không cần nguyên khí để tắt)
local TOGGLE = { anthan = true }

-- vòng chọn vị trí của từng kỹ năng: kind -> { prefab vòng, prefab hiệu ứng khi chọn, tầm xa }
local RETICULES = {
    star = { reticule = "reticuleaoesmall", ping = "reticuleaoesmallping" },
    giangloi = { reticule = "reticuleaoe", ping = "reticuleaoeping" },
}

-- Mô tả kỹ năng (lấy số liệu từ cosu_gu_tuning nên đổi số ở đó là chữ tự đổi theo)
local function GetSkillInfo(kind)
    local V = GU.VUONG or {}
    local L = GU.TICHLICH or {}
    local U = GU.ULOI or {}
    if kind == "star" then
        return "Sao trời",
            "Gọi một ngôi sao chiếu sáng xuống vị trí chọn bằng chuột phải (xa tối đa "
            .. tostring(V.STAR_RANGE or 25) .. " đơn vị). Thả sao mới thì sao cũ biến mất.\n"
            .. "Hồi chiêu: " .. tostring(V.STAR_COOLDOWN or 40) .. " giây."
    elseif kind == "quanghoa" then
        return "Quang Hóa",
            "Trong " .. tostring(V.QUANG_DURATION or 15) .. " giây, các đòn đánh được tích lại; "
            .. "sau đó hồn ma bay tới kẻ địch xung quanh. Hồn ma đầu tiên gây "
            .. tostring(V.QUANG_DAMAGE or 20) .. " sát thương, mỗi hồn sau cộng thêm "
            .. tostring(V.QUANG_DAMAGE_STEP or 1) .. ".\n"
            .. "Hồi chiêu: " .. tostring(V.QUANG_COOLDOWN or 30) .. " giây."
    elseif kind == "thunder" then
        return "Thiên Lôi",
            "Giáng " .. tostring(L.BOLT_COUNT or 30) .. " tia sét xuống quanh bạn (bán kính "
            .. tostring(L.BOLT_RADIUS or 12) .. "), mỗi tia "
            .. tostring(L.BOLT_DAMAGE or 60) .. " sát thương.\n"
            .. "Hồi chiêu: " .. tostring(L.COOLDOWN or 45) .. " giây."
    elseif kind == "loihoa" then
        local foods = {}
        for _, f in ipairs(U.LOIHOA_FOODS or {}) do
            table.insert(foods, f.name .. " (" .. f.seconds .. " giây)")
        end
        return "Lôi Hóa",
            "Tiêu hao 1 trong: " .. table.concat(foods, ", ") .. " trong túi để vào trạng thái lôi hóa "
            .. "(ăn thêm sẽ cộng dồn, tối đa " .. tostring(U.LOIHOA_MAX or 120) .. " giây). "
            .. "Đòn đánh kèm sát thương điện, tổng gấp " .. tostring(U.LOIHOA_MULT or 1.5)
            .. " lần sát thương gốc, gấp " .. tostring(U.LOIHOA_WET_MULT or 2.5) .. " lần nếu đối phương bị ướt."
    elseif kind == "anthan" then
        local A = GU.ANTHACH or {}
        return "Ẩn Thân",
            "Bật/tắt. Khi bật, không sinh vật nào phát hiện hay nhắm tới bạn. Tiêu "
            .. tostring(A.QI_COST or 1) .. " nguyên khí mỗi " .. tostring(A.QI_INTERVAL or 2)
            .. " giây, hết nguyên khí sẽ tự tắt. Bấm lần nữa để tắt."
    elseif kind == "giangloi" then
        return "Giáng Lôi",
            "Triệu hồi một tia sét lớn xuống vị trí chọn bằng chuột phải (xa tối đa "
            .. tostring(U.GIANGLOI_RANGE or 20) .. " đơn vị), gây "
            .. tostring(U.GIANGLOI_DAMAGE or 600) .. " sát thương cho mọi kẻ địch trong vùng 3x3 ô.\n"
            .. "Hồi chiêu: " .. tostring(U.GIANGLOI_COOLDOWN or 60) .. " giây."
    end
    return tostring(kind), ""
end

local CosuSkillBar = Class(Widget, function(self, owner)
    Widget._ctor(self, "CosuSkillBar")
    self.owner = owner
    self.items = {}
    self.cd = {}        -- kind -> thời điểm hết hồi chiêu (GetTime phía máy khách)
    self.act = {}       -- kind -> thời điểm hết trạng thái đang chạy (Quang Hóa)
    self.enabled = true
    self.targeting = nil
    self.reticule = nil
    self.hover = nil    -- nút đang được rê chuột vào

    self.hint = self:AddChild(Text(UIFONT, 22, ""))
    self.hint:SetColour(1, 1, .6, 1)
    self.hint:Hide()

    -- cửa sổ mô tả kỹ năng
    self.tip = self:AddChild(Widget("skilltip"))
    self.tip_bg = self.tip:AddChild(Image("images/ui.xml", "black.tex"))
    self.tip_bg:SetTint(0, 0, 0, 0.8)
    self.tip_title = self.tip:AddChild(Text(UIFONT, 26, ""))
    self.tip_title:SetColour(1, .9, .4, 1)
    self.tip_desc = self.tip:AddChild(Text(UIFONT, 20, ""))
    self.tip_desc:SetColour(1, 1, 1, 1)
    self.tip_cost = self.tip:AddChild(Text(UIFONT, 20, ""))
    self.tip_cost:SetColour(.5, .8, 1, 1)
    self.tip:Hide()

    self.inst:ListenForEvent("cosu_gueqdirty", function() self:Rebuild() end, owner)
    self.inst:ListenForEvent("cosu_rankdirty", function() self:Rebuild() end, owner)
    self.inst:ListenForEvent("cosu_cddirty", function() self:ReadTimes("_cosu_cd", self.cd) end, owner)
    self.inst:ListenForEvent("cosu_actdirty", function() self:ReadTimes("_cosu_act", self.act) end, owner)

    -- chuột phải để chọn vị trí đặt kỹ năng
    self.mouse_handler = TheInput:AddMouseButtonHandler(function(button, down)
        self:OnMouse(button, down)
    end)
    self.inst:ListenForEvent("onremove", function()
        self:StopReticule()
        if self.mouse_handler ~= nil then self.mouse_handler:Remove() end
    end)

    self:Rebuild()
    self:StartUpdating()
end)

-- "star=42.5;quanghoa=10.0" -> đổi thành thời điểm hết (theo đồng hồ máy khách)
function CosuSkillBar:ReadTimes(netname, out)
    for k in pairs(out) do out[k] = nil end
    local nv = self.owner[netname]
    if nv == nil then return end
    for kind, left in string.gmatch(nv:value() or "", "(%w+)=([%d%.]+)") do
        out[kind] = GetTime() + (tonumber(left) or 0)
    end
end

-- bật/tắt cả hàng kỹ năng (kể cả phím tắt)
function CosuSkillBar:SetSkillsShown(shown)
    self.enabled = shown
    if shown then self:Show() else
        self:EndTargeting()
        self:HideTip()
        self:Hide()
    end
end

function CosuSkillBar:Rebuild()
    self:EndTargeting()
    self:HideTip()
    for _, it in ipairs(self.items) do
        it.root:Kill()
    end
    self.items = {}

    local eq = self.owner._cosu_gu_eq ~= nil and self.owner._cosu_gu_eq:value() or ""
    local rank = self.owner._cosu_rank ~= nil and self.owner._cosu_rank:value() or 0
    local found = {}
    local place = 0
    for n in string.gmatch(eq, "%d+") do
        local gu = GU.LIST[tonumber(n)]
        if gu ~= nil and (place == 0 and rank >= 1 or place >= 1 and rank >= place) then
            for _, kind in ipairs(GU.GetSkills(gu, place)) do
                table.insert(found, { place = place, gu = gu, kind = kind })
            end
        end
        place = place + 1
    end

    for i, f in ipairs(found) do
        local root = self:AddChild(Widget("skill" .. f.place .. f.kind))
        root:SetPosition((i - 1) * SPACING, 0, 0)

        local bg = root:AddChild(Image("images/hud.xml", "inv_slot.tex"))
        bg:SetScale(BG_SCALE)

        local btn = root:AddChild(ImageButton(f.gu.atlas, f.gu.image, f.gu.image, f.gu.image, f.gu.image))
        btn:SetScale(ICON_SCALE)

        local cdtext = root:AddChild(Text(NUMBERFONT, 20, ""))

        local keyname = GU.SKILL_KEYS ~= nil and GU.SKILL_KEYS[f.kind] or nil
        if keyname ~= nil then
            local label = root:AddChild(Text(UIFONT, 16, keyname))
            label:SetPosition(0, -28, 0)
        end

        local cost = GU.GetQiCost(f.gu, f.kind, QI)
        local title, desc = GetSkillInfo(f.kind)
        local item = {
            root = root, btn = btn, cdtext = cdtext, kind = f.kind, place = f.place, cost = cost,
            x = (i - 1) * SPACING, title = title, desc = desc,
        }
        btn:SetOnClick(function() self:Activate(item) end)
        table.insert(self.items, item)
    end

    self.hint:SetPosition((#found - 1) * SPACING / 2, -42, 0)
end

-- Cửa sổ mô tả -------------------------------------------------------------

function CosuSkillBar:ShowTip(item)
    self.tip_title:SetString(item.title)
    self.tip_desc:SetMultilineTruncatedString(item.desc, 8, TIP_WIDTH - 20, nil, false)
    if TOGGLE[item.kind] then
        local A = GU.ANTHACH or {}
        self.tip_cost:SetString("Nguyên khí: " .. tostring(item.cost) .. " mỗi " .. tostring(A.QI_INTERVAL or 2) .. " giây")
    else
        self.tip_cost:SetString("Nguyên khí: " .. tostring(item.cost))
    end

    local _, dh = self.tip_desc:GetRegionSize()
    dh = dh or 60
    local th, ch = 26, 22
    local pad = 10
    local total = pad + th + 6 + dh + 6 + ch + pad

    self.tip_bg:SetSize(TIP_WIDTH, total)
    -- tâm cửa sổ ở giữa; xếp từ trên xuống
    local top = total / 2 - pad
    self.tip_title:SetPosition(0, top - th / 2, 0)
    self.tip_desc:SetPosition(0, top - th - 6 - dh / 2, 0)
    self.tip_cost:SetPosition(0, top - th - 6 - dh - 6 - ch / 2, 0)

    -- nằm phía trên nút; tâm cao hơn hàng nút một nửa chiều cao cộng khoảng đệm
    self.tip:SetPosition(item.x, TIP_Y + total / 2, 0)
    self.tip:MoveToFront()
    self.tip:Show()
end

function CosuSkillBar:HideTip()
    self.hover = nil
    if self.tip ~= nil then self.tip:Hide() end
end

-- Kỹ năng ---------------------------------------------------------------------

function CosuSkillBar:GetQi()
    return self.owner._cosu_qi ~= nil and self.owner._cosu_qi:value() or 0
end

function CosuSkillBar:Activate(item)
    if not self.enabled then return end
    local toggled_on = TOGGLE[item.kind] and (self.act[item.kind] or 0) > GetTime()
    if not toggled_on and self:GetQi() < item.cost and (self.cd[item.kind] or 0) <= GetTime() then
        -- thiếu nguyên khí: báo ngay trên màn hình, không gửi lên server, không vào chế độ chọn vị trí
        self:EndTargeting()
        self.hint:SetString(QI.FAIL_TALK .. " (cần " .. item.cost .. ")")
        self.hint:Show()
        self.hint_hide = GetTime() + 2
        return
    end
    if TARGETED[item.kind] ~= nil then
        if self.targeting ~= nil then
            self:EndTargeting()
        elseif (self.cd[item.kind] or 0) <= GetTime() then
            self.targeting = { place = item.place, kind = item.kind, t0 = GetTime() }
            self:StartReticule(item.kind)
            self.hint:SetString(TARGETED[item.kind])
            self.hint:Show()
        end
    else
        SendModRPCToServer(MOD_RPC["cosu"]["gu_skill"], item.place, item.kind)
    end
end

-- dùng cho phím tắt
function CosuSkillBar:UseKind(kind)
    for _, it in ipairs(self.items) do
        if it.kind == kind then
            self:Activate(it)
            return
        end
    end
end

-- Vòng chọn vị trí giống Gậy Gọi Sao
function CosuSkillBar:StartReticule(kind)
    self:StopReticule()
    local info = RETICULES[kind] or RETICULES.star
    self.reticule = SpawnPrefab(info.reticule)
    if self.reticule ~= nil and kind == "giangloi" then
        local sc = (GU.ULOI or {}).GIANGLOI_RETICULE_SCALE or 1.6
        self.reticule.Transform:SetScale(sc, sc, sc)
    end
end

function CosuSkillBar:StopReticule()
    if self.reticule ~= nil then
        if self.reticule:IsValid() then self.reticule:Remove() end
        self.reticule = nil
    end
end

-- kẹp vị trí chuột trong tầm xa tối đa quanh người chơi
function CosuSkillBar:ClampPos(pos, kind)
    local px, _, pz = self.owner.Transform:GetWorldPosition()
    local dx, dz = pos.x - px, pos.z - pz
    local d = math.sqrt(dx * dx + dz * dz)
    local range = GU.VUONG.STAR_RANGE or 25
    if kind == "giangloi" then range = (GU.ULOI or {}).GIANGLOI_RANGE or 20 end
    if d > range then
        dx, dz = dx / d * range, dz / d * range
    end
    return px + dx, pz + dz
end

function CosuSkillBar:EndTargeting()
    self.targeting = nil
    self:StopReticule()
    self.hint:Hide()
end

function CosuSkillBar:OnMouse(button, down)
    if self.targeting == nil or not down or button ~= MOUSEBUTTON_RIGHT then return end
    if TheInput:GetHUDEntityUnderMouse() ~= nil then return end -- bấm lên giao diện thì bỏ qua
    local pos = TheInput:GetWorldPosition()
    if pos == nil then return end
    local kind = self.targeting.kind
    local x, z = self:ClampPos(pos, kind)
    SendModRPCToServer(MOD_RPC["cosu"]["gu_skill"], self.targeting.place, kind, x, z)
    local ping = SpawnPrefab((RETICULES[kind] or RETICULES.star).ping)
    if ping ~= nil then ping.Transform:SetPosition(x, 0, z) end
    self:EndTargeting()
end

function CosuSkillBar:OnUpdate(dt)
    local now = GetTime()
    if self.hint_hide ~= nil and now > self.hint_hide then
        self.hint_hide = nil
        if self.targeting == nil then self.hint:Hide() end
    end
    local qi = self:GetQi()

    -- vòng chọn đi theo chuột, bị kẹp trong tầm xa tối đa
    if self.targeting ~= nil and self.reticule ~= nil and self.reticule:IsValid() then
        local pos = TheInput:GetWorldPosition()
        if pos ~= nil then
            local x, z = self:ClampPos(pos, self.targeting.kind)
            self.reticule.Transform:SetPosition(x, 0, z)
        end
    end

    if self.targeting ~= nil then
        local k = self.targeting.kind
        if now - self.targeting.t0 > TARGET_TIMEOUT or (self.cd[k] or 0) > now then
            self:EndTargeting()
        end
    end

    -- cửa sổ mô tả: hiện khi chuột đang nằm trên 1 nút
    local hovered = nil
    if self.enabled then
        for _, it in ipairs(self.items) do
            if it.btn.focus then
                hovered = it
                break
            end
        end
    end
    if hovered ~= self.hover then
        self.hover = hovered
        if hovered ~= nil then self:ShowTip(hovered) else self.tip:Hide() end
    end

    for _, it in ipairs(self.items) do
        local act_left = math.max(0, (self.act[it.kind] or 0) - now)
        local cd_left = math.max(0, (self.cd[it.kind] or 0) - now)
        if TOGGLE[it.kind] and act_left > 0 then
            -- kỹ năng bật/tắt đang bật: chữ "Bật", icon sáng vàng
            it.cdtext:SetString("Bật")
            it.cdtext:SetColour(1, .9, .3, 1)
            it.btn.image:SetTint(1, 1, .6, 1)
        elseif act_left > 0 then
            -- đang trong trạng thái (Quang Hóa): hiện số giây còn lại, màu vàng
            it.cdtext:SetString(tostring(math.ceil(act_left)))
            it.cdtext:SetColour(1, .9, .3, 1)
            it.btn.image:SetTint(1, 1, .6, 1)
        elseif cd_left > 0 then
            it.cdtext:SetString(tostring(math.ceil(cd_left)))
            it.cdtext:SetColour(1, 1, 1, 1)
            it.btn.image:SetTint(.35, .35, .35, 1)
        elseif qi < it.cost then
            -- thiếu nguyên khí: icon xám xanh, hiện số nguyên khí cần
            it.cdtext:SetString(tostring(it.cost))
            it.cdtext:SetColour(.5, .8, 1, 1)
            it.btn.image:SetTint(.4, .45, .6, 1)
        else
            it.cdtext:SetString("")
            if self.targeting ~= nil and self.targeting.place == it.place and self.targeting.kind == it.kind then
                it.btn.image:SetTint(1, 1, .5, 1)
            else
                it.btn.image:SetTint(1, 1, 1, 1)
            end
        end
    end
end

return CosuSkillBar