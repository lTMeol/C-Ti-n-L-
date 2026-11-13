local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local RANK_NAMES = { "Nhất", "Nhị", "Tam", "Tứ", "Ngũ", "Lục", "Thất", "Bát", "Cửu" }
local STAGE_NAMES = { "Sơ Giai", "Trung Giai", "Cao Giai", "Đỉnh Phong" }

-- Màu chân nguyên theo chuyển (1-5 theo truyện: đồng thanh, thiết hồng, bạch ngân,
-- hoàng kim, tử tinh; 6-9 là màu tự chọn, bạn có thể đổi)
local COLORS = {
    { 0.29, 0.64, 0.51 }, { 0.71, 0.27, 0.18 }, { 0.87, 0.90, 0.93 },
    { 0.91, 0.73, 0.14 }, { 0.61, 0.36, 0.90 }, { 0.25, 0.65, 1.00 },
    { 1.00, 0.45, 0.65 }, { 1.00, 0.55, 0.15 }, { 1.00, 1.00, 1.00 },
}

local SIZE = 68           -- kích thước huy hiệu (điểm ảnh, ở màn hình cao 720); cỡ gần bằng huy hiệu máu
local ORB_OFFSET_Y = -7 * SIZE / 112   -- vị trí viên cầu chân nguyên so với tâm huy hiệu
local PIP_RADIUS = 54 * SIZE / 112
local PIP_SIZE = 14 * SIZE / 112
local TEXT_HALF_W = 90    -- nửa bề rộng chữ bên dưới, dùng để không bị cắt ở mép màn hình
local BOTTOM_MARGIN = 50  -- chừa chỗ cho 3 dòng chữ bên dưới huy hiệu
local SAVE_FILE = "cosu_badge_pos"

local LOCKED_TALK = "Cần khai mở Nguyên Hải Thần Thức để bắt đầu hành trình cổ sư."

---------------------------------------------------------------- Xích + ổ khóa (vẽ bằng khối vuông có sẵn)
local function MakeRect(parent, x, y, w, h, r, g, b, rot)
    local img = parent:AddChild(Image("images/global.xml", "square.tex"))
    img:SetSize(w, h)
    img:SetPosition(x, y)
    if rot ~= nil then img:SetRotation(rot) end
    img:SetTint(r, g, b, 1)
    img:SetClickable(false)
    return img
end

-- Một mắt xích: viền sáng + lỗ tối ở giữa
local function MakeLink(parent, x, y, rot, w, h)
    MakeRect(parent, x, y, w, h, 0.62, 0.64, 0.68, rot)
    MakeRect(parent, x, y, w - 4, h - 4, 0.08, 0.08, 0.1, rot)
end

-- Hai sợi xích bắt chéo qua huy hiệu + ổ khóa ở giữa
local function BuildChains(parent)
    local chains = parent:AddChild(Widget("chains"))
    for _, ang in ipairs({ 45, -45 }) do
        local a = math.rad(ang)
        for k = -4, 4 do
            local d = k * 10
            MakeLink(chains, math.cos(a) * d, math.sin(a) * d,
                ang + (k % 2 == 0 and 0 or 90), 12, 7)
        end
    end
    -- ổ khóa
    MakeRect(chains, -4.5, 9, 3, 10, 0.45, 0.36, 0.1)   -- quai trái
    MakeRect(chains, 4.5, 9, 3, 10, 0.45, 0.36, 0.1)    -- quai phải
    MakeRect(chains, 0, 14, 12, 3, 0.45, 0.36, 0.1)     -- quai trên
    MakeRect(chains, 0, -2, 20, 15, 0.85, 0.68, 0.22)   -- thân khóa
    MakeRect(chains, 0, -2, 4, 6, 0.15, 0.1, 0.02)      -- lỗ khóa
    return chains
end

local CosuBadge = Class(Widget, function(self, owner)
    Widget._ctor(self, "CosuBadge")
    self.owner = owner

    -- gốc neo ở góc trái-dưới màn hình, toạ độ = điểm ảnh thật
    self.root = self:AddChild(Widget("CosuBadgeRoot"))
    self.root:SetHAnchor(ANCHOR_LEFT)
    self.root:SetVAnchor(ANCHOR_BOTTOM)
    self.root:SetScaleMode(SCALEMODE_NONE)

    self.body = self.root:AddChild(Widget("body"))

    self.badge = self.body:AddChild(Image("images/cosu_badge.xml", "cosu_badge.tex"))
    self.badge:SetSize(SIZE, SIZE)

    self.orb = self.body:AddChild(Image("images/cosu_glow.xml", "cosu_glow.tex"))
    self.orb:SetSize(SIZE * 0.34, SIZE * 0.34)
    self.orb:SetPosition(0, ORB_OFFSET_Y)
    self.orb:SetClickable(false)

    -- 9 hạt nhỏ quanh viền: sáng lên theo số chuyển
    self.pips = {}
    for i = 1, 9 do
        local a = math.rad(90 - (i - 1) * 40)
        local pip = self.body:AddChild(Image("images/cosu_glow.xml", "cosu_glow.tex"))
        pip:SetSize(PIP_SIZE, PIP_SIZE)
        pip:SetPosition(math.cos(a) * PIP_RADIUS, math.sin(a) * PIP_RADIUS)
        pip:SetClickable(false)
        self.pips[i] = pip
    end

    -- xích khóa (chỉ hiện khi còn là Phàm Nhân)
    self.chains = BuildChains(self.body)
    self.chains:Hide()
    self.locked = false
    self.last_say = -10

    self.rank_text = self.body:AddChild(Text(UIFONT, 20, ""))
    self.rank_text:SetPosition(0, -SIZE * 0.5 - 11)
    self.stage_text = self.body:AddChild(Text(UIFONT, 16, ""))
    self.stage_text:SetPosition(0, -SIZE * 0.5 - 28)
    self.point_text = self.body:AddChild(Text(UIFONT, 14, ""))
    self.point_text:SetPosition(0, -SIZE * 0.5 - 43)

    self.dragging = false
    self.shown_rank, self.shown_stage, self.shown_h = -1, -1, -1
    self.shown_points, self.shown_need = -1, -1

    -- vị trí mặc định (tỉ lệ so với màn hình), rồi đọc vị trí đã lưu
    self.fx, self.fy = 0.07, 0.55
    TheSim:GetPersistentString(SAVE_FILE, function(ok, data)
        if ok and data ~= nil then
            local fx, fy = data:match("([%d%.%-]+),([%d%.%-]+)")
            fx, fy = tonumber(fx), tonumber(fy)
            if fx ~= nil and fy ~= nil then
                self.fx, self.fy = fx, fy
            end
        end
        self:ApplyPosition()
    end)

    self.handler = TheInput:AddMouseButtonHandler(function(button, down)
        local ent = down and TheInput:GetHUDEntityUnderMouse() or nil
        local on_badge = ent ~= nil and ent == self.badge.inst

        -- chuột trái vào huy hiệu khi còn bị khóa: nhân vật lên tiếng
        if button == MOUSEBUTTON_LEFT then
            if down and on_badge and self.locked then
                self:SayLocked()
            end
            return
        end

        -- chuột phải: giữ để kéo
        if button ~= MOUSEBUTTON_RIGHT then return end
        if down then
            if on_badge then self:StartDrag() end
        elseif self.dragging then
            self:StopDrag()
        end
    end)

    self:ApplyPosition()
    self:StartUpdating()
end)

function CosuBadge:SayLocked()
    local t = GetTime()
    if t - self.last_say < 2 then return end
    self.last_say = t
    local o = self.owner
    if o ~= nil and o.components.talker ~= nil then
        o.components.talker:Say(LOCKED_TALK)
    end
end

function CosuBadge:ApplyPosition()
    local w, h = TheSim:GetScreenSize()
    local s = h / 720
    self.root:SetScale(s, s, 1)
    local half = SIZE * 0.5 * s
    local mx = math.max(half, TEXT_HALF_W * s)
    local x = math.max(mx, math.min(w - mx, self.fx * w))
    local y = math.max(half + BOTTOM_MARGIN * s, math.min(h - half, self.fy * h))
    self.root:SetPosition(x, y, 0)
end

function CosuBadge:StartDrag()
    local mp = TheInput:GetScreenPosition()
    local rp = self.root:GetPosition()
    self.drag_dx, self.drag_dy = rp.x - mp.x, rp.y - mp.y
    self.dragging = true
end

function CosuBadge:StopDrag()
    self.dragging = false
    local w, h = TheSim:GetScreenSize()
    local rp = self.root:GetPosition()
    self.fx, self.fy = rp.x / w, rp.y / h
    TheSim:SetPersistentString(SAVE_FILE, string.format("%.5f,%.5f", self.fx, self.fy), false)
end

function CosuBadge:Refresh(rank, stage, points, need)
    local col = COLORS[rank]
    if rank < 1 or rank > 9 or col == nil then
        -- Phàm Nhân: huy hiệu bị phong ấn bằng xích
        self.locked = true
        self.chains:Show()
        self.badge:SetTint(0.35, 0.35, 0.4, 1)
        self.orb:Hide()
        for i = 1, 9 do self.pips[i]:Hide() end
        self.rank_text:SetString("Phàm Nhân")
        self.rank_text:SetColour(0.7, 0.7, 0.7, 1)
        self.stage_text:SetString("Cần khai mở")
        self.stage_text:SetColour(0.85, 0.35, 0.3, 1)
        self.point_text:SetString("Nguyên Hải Thần Thức")
        self.point_text:SetColour(0.85, 0.35, 0.3, 1)
        return
    end

    -- đã khai mở: gỡ khóa
    self.locked = false
    self.chains:Hide()
    self.badge:SetTint(1, 1, 1, 1)
    self.orb:Show()
    for i = 1, 9 do self.pips[i]:Show() end

    self.rank_text:SetString("Cổ Sư " .. RANK_NAMES[rank] .. " Chuyển")
    self.rank_text:SetColour(col[1], col[2], col[3], 1)
    self.stage_text:SetString(STAGE_NAMES[stage] or "")
    self.stage_text:SetColour(0.9, 0.85, 0.7, 1)
    if (stage or 1) >= 4 then
        -- Cửu Chuyển là tận cùng: không còn đan để đột phá nên bỏ dòng này
        self.point_text:SetString(rank >= 9 and "" or "Cần đan dược để đột phá")
    else
        self.point_text:SetString((points or 0) .. " / " .. (need or 0))
    end
    self.point_text:SetColour(0.75, 0.75, 0.75, 1)
    -- viên cầu sáng dần theo giai (sơ 55% -> đỉnh phong 100%)
    self.orb:SetTint(col[1], col[2], col[3], 0.45 + 0.55 * ((stage or 1) / 4))
    for i = 1, 9 do
        if i <= rank then
            self.pips[i]:SetTint(col[1], col[2], col[3], 1)
        else
            self.pips[i]:SetTint(0.4, 0.4, 0.4, 0.25)
        end
    end
end

function CosuBadge:OnUpdate(dt)
    if self.dragging then
        local mp = TheInput:GetScreenPosition()
        local w, h = TheSim:GetScreenSize()
        local s = h / 720
        local half = SIZE * 0.5 * s
        local mx = math.max(half, TEXT_HALF_W * s)
        local x = math.max(mx, math.min(w - mx, mp.x + self.drag_dx))
        local y = math.max(half + BOTTOM_MARGIN * s, math.min(h - half, mp.y + self.drag_dy))
        self.root:SetPosition(x, y, 0)
    end

    local _, h = TheSim:GetScreenSize()
    if h ~= self.shown_h then
        self.shown_h = h
        self:ApplyPosition()
    end

    local o = self.owner
    if o ~= nil and o._cosu_rank ~= nil then
        local rank, stage = o._cosu_rank:value(), o._cosu_stage:value()
        local points, need = o._cosu_points:value(), o._cosu_need:value()
        if rank ~= self.shown_rank or stage ~= self.shown_stage
            or points ~= self.shown_points or need ~= self.shown_need then
            self.shown_rank, self.shown_stage = rank, stage
            self.shown_points, self.shown_need = points, need
            self:Refresh(rank, stage, points, need)
        end
    end
end

function CosuBadge:Kill()
    if self.handler ~= nil then
        self.handler:Remove()
        self.handler = nil
    end
    CosuBadge._base.Kill(self)
end

return CosuBadge