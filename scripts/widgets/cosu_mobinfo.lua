-- Cửa sổ nhỏ trên đầu quái khi rê chuột vào: "Cảnh giới", "Chủng loại", rồi danh sách linh căn
-- (icon - tên - con số) ở cuối (chỉ chạy trên máy khách).
-- Widget này nằm trong Controls chỉ làm nhiệm vụ theo dõi chuột và hỏi server; cửa sổ thật được gắn
-- trực tiếp vào HUD để vị trí tính bằng tọa độ màn hình (TheSim:GetScreenPos) như HoverText của game.
-- Số liệu và chữ ở cosu_element_tuning.MOBINFO.
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ELEM = require "cosu_element_tuning"

local MI = ELEM.MOBINFO

local BY_ID = {}
for _, e in ipairs(ELEM.LIST) do
    BY_ID[e.id] = e
end

local ICON = 30          -- cỡ icon linh căn
local BOX_W = 50         -- bề rộng ô con số
local GAP = 8
local PAD = 14
local RANK_COLOUR = { 1.0, 0.85, 0.4, 1 }
local GREY = { 0.7, 0.7, 0.7, 1 }

local HIDE_TAGS = { "structure", "wall", "FX", "INLIMBO", "NOCLICK", "companion", "player", "playerghost" }

-- Có phải thứ đáng hiện thông tin không (sinh vật có máu và có thể chiến đấu)?
local function IsCandidate(ent)
    if ent == nil or not ent:IsValid() or ent == ThePlayer or ent.Network == nil then return false end
    for _, tag in ipairs(HIDE_TAGS) do
        if ent:HasTag(tag) then return false end
    end
    local r = ent.replica
    if r == nil or r.health == nil or r.combat == nil then return false end
    return not r.health:IsDead()
end

local function HudScale()
    local s = (TheFrontEnd ~= nil and TheFrontEnd.GetHUDScale ~= nil) and TheFrontEnd:GetHUDScale() or 1
    return s * MI.SCALE
end

local CosuMobInfo = Class(Widget, function(self, owner)
    Widget._ctor(self, "CosuMobInfo")
    self.owner = owner
    self.cache = {}   -- mã mạng -> { roots = {id...}, kind = "boss", t = thời điểm nhận, key = số thứ tự }
    self.pending = {} -- mã mạng -> thời điểm đã hỏi server
    self.target = nil
    self.panel = nil
    self.shown_key = nil

    -- server trả lời qua netvar của người chơi
    owner:ListenForEvent("cosu_mobinfodirty", function() self:OnInfo() end)
    self:StartUpdating()
end)

function CosuMobInfo:Kill()
    if self.panel ~= nil then
        self.panel:Kill()
        self.panel = nil
    end
    Widget.Kill(self)
end

----------------------------------------------------------------- Hỏi / nhận thông tin
function CosuMobInfo:Request(ent)
    local netid = ent.Network:GetNetworkID()
    local now = GetTime()
    local info = self.cache[netid]
    if info ~= nil and now - info.t < MI.REFRESH then return end
    local asked = self.pending[netid]
    if asked ~= nil and now - asked < 1 then return end
    self.pending[netid] = now
    SendModRPCToServer(GetModRPC("cosu", "mobinfo"), ent)
end

function CosuMobInfo:OnInfo()
    local nv = self.owner._cosu_mobinfo
    local str = nv ~= nil and nv:value() or ""
    -- "số thứ tự|mã mạng|id linh căn|loại|con số từng linh căn|số chuyển"
    local seq, netid, roots, kind, vals, rank = string.match(str, "^(%d+)|(%d+)|([%w_,]*)|(%w+)|([%d,]*)|(%d+)$")
    if netid == nil then return end
    netid = tonumber(netid)
    local list, values = {}, {}
    local nums = {}
    for v in string.gmatch(vals, "[^,]+") do table.insert(nums, v) end
    local i = 0
    for id in string.gmatch(roots, "[^,]+") do
        i = i + 1
        if BY_ID[id] ~= nil then
            table.insert(list, id)
            table.insert(values, nums[i] or "0")
        end
    end
    self.cache[netid] = { roots = list, vals = values, kind = kind, rank = tonumber(rank) or 0, t = GetTime(), key = seq }
    self.pending[netid] = nil
end

----------------------------------------------------------------- Cửa sổ
-- xếp các đoạn chữ nằm ngang, căn giữa quanh x = 0; trả về bề rộng
local function LayoutRow(items, y)
    local total = 0
    local widths = {}
    for i, item in ipairs(items) do
        local w = item:GetRegionSize()
        widths[i] = w
        total = total + w
    end
    local x = -total / 2
    for i, item in ipairs(items) do
        item:SetPosition(x + widths[i] / 2, y, 0)
        x = x + widths[i]
    end
    return total
end

function CosuMobInfo:EnsurePanel()
    if self.panel ~= nil then return true end
    local hud = self.owner.HUD
    if hud == nil then return false end
    self.panel = hud:AddChild(Widget("CosuMobInfoPanel"))
    self.panel:SetClickable(false) -- không chặn chuột, nếu không rê vào cửa sổ là mất mục tiêu
    self.bg = self.panel:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetTint(0, 0, 0, MI.BG_ALPHA)
    self.rows = self.panel:AddChild(Widget("rows"))
    self.panel:Hide()
    return true
end

local function AddText(parent, items, str, colour)
    local t = parent:AddChild(Text(UIFONT, MI.FONT_SIZE, str))
    t:SetColour(unpack(colour or { 1, 1, 1, 1 }))
    table.insert(items, t)
    return t
end

-- dựng lại nội dung khi thông tin mới
function CosuMobInfo:Rebuild(info)
    self.rows:KillAllChildren()
    local size = MI.FONT_SIZE
    local line_h = size * 1.25
    local row_h = math.max(line_h, ICON + 4)
    local rank_names = ELEM.COMBAT.RANK_NAMES

    -- hai dòng đầu: cảnh giới, chủng loại
    local row1 = {}
    AddText(self.rows, row1, MI.LABEL_RANK)
    if info.rank > 0 then
        AddText(self.rows, row1, rank_names[info.rank] or (info.rank .. " Chuyển"), RANK_COLOUR)
    else
        AddText(self.rows, row1, MI.NO_RANK_TEXT, GREY)
    end
    local row2 = {}
    AddText(self.rows, row2, MI.LABEL_KIND)
    AddText(self.rows, row2, MI.KIND_NAMES[info.kind] or "?", MI.KIND_COLOURS[info.kind])

    -- linh căn: mỗi hệ 1 dòng (icon - tên - ô con số)
    local entries = {}
    for i, id in ipairs(info.roots) do
        local e = BY_ID[id]
        if e ~= nil then table.insert(entries, { e = e, v = info.vals[i] or "0" }) end
    end

    local row3 = nil
    local roots_h
    if #entries == 0 then
        row3 = {}
        AddText(self.rows, row3, MI.LABEL_ROOT)
        AddText(self.rows, row3, MI.NO_ROOT_TEXT, GREY)
        roots_h = line_h
    else
        roots_h = #entries * row_h
    end

    -- đo bề rộng tên dài nhất để chia cột
    local names, name_w = {}, 0
    for i, en in ipairs(entries) do
        local t = AddText(self.rows, {}, en.e.label .. " linh căn")
        names[i] = t
        name_w = math.max(name_w, (t:GetRegionSize()))
    end

    local sep_h = 8
    local content_h = line_h * 2 + sep_h + roots_h
    local top = content_h / 2

    local w1 = LayoutRow(row1, top - line_h / 2)
    local w2 = LayoutRow(row2, top - line_h * 1.5)
    local w3 = 0
    local y = top - line_h * 2 - sep_h / 2
    if row3 ~= nil then
        w3 = LayoutRow(row3, y - sep_h / 2 - line_h / 2)
    end
    local list_w = #entries > 0 and (ICON + GAP + name_w + GAP * 2 + BOX_W) or 0
    local W = math.max(w1, w2, w3, list_w)

    -- đường kẻ ngăn giữa phần đầu và danh sách linh căn
    local sep = self.rows:AddChild(Image("images/global.xml", "square.tex"))
    sep:SetTint(1, 1, 1, 0.25)
    sep:SetSize(W, 1)
    sep:SetPosition(0, y, 0)

    local ry = y - sep_h / 2 - row_h / 2
    for i, en in ipairs(entries) do
        local icon = self.rows:AddChild(Image(en.e.root_atlas, en.e.root_image))
        icon:SetSize(ICON, ICON)
        icon:SetPosition(-W / 2 + ICON / 2, ry, 0)

        names[i]:SetPosition(-W / 2 + ICON + GAP + name_w / 2, ry, 0)

        local box = self.rows:AddChild(Image("images/global.xml", "square.tex"))
        box:SetTint(0, 0, 0, 0.9)
        box:SetSize(BOX_W, row_h - 6)
        box:SetPosition(W / 2 - BOX_W / 2, ry, 0)
        local v = self.rows:AddChild(Text(UIFONT, size, tostring(en.v)))
        v:SetColour(1, 1, 1, 1)
        v:SetPosition(W / 2 - BOX_W / 2, ry, 0)

        ry = ry - row_h
    end

    self.panel_w = W + PAD * 2
    self.panel_h = content_h + PAD
    self.bg:SetSize(self.panel_w, self.panel_h)
end

function CosuMobInfo:HidePanel()
    if self.panel ~= nil then self.panel:Hide() end
end

function CosuMobInfo:UpdatePanel()
    local t = self.target
    if t == nil or not t:IsValid() or t:HasTag("INLIMBO") then
        self:HidePanel()
        return
    end
    local info = self.cache[t.Network:GetNetworkID()]
    if info == nil or not self:EnsurePanel() then
        self:HidePanel()
        return
    end

    local key = t.Network:GetNetworkID() .. ":" .. tostring(info.key)
    if self.shown_key ~= key then
        self:Rebuild(info)
        self.shown_key = key
    end

    -- vị trí: phía trên đầu quái, theo tọa độ màn hình
    local x, y, z = t.Transform:GetWorldPosition()
    local sx_scale = t.Transform:GetScale() or 1
    local off = (t:HasTag("epic") and MI.EPIC_OFFSET or MI.OFFSET) * sx_scale
    local px, py = TheSim:GetScreenPos(x, y + off, z)
    local scale = HudScale()
    local sw, sh = TheSim:GetScreenSize()
    local half_w = self.panel_w * scale / 2
    local half_h = self.panel_h * scale / 2
    px = math.max(half_w, math.min(sw - half_w, px))
    py = math.max(half_h, math.min(sh - half_h, py + half_h))

    self.panel:SetScale(scale, scale, 1)
    self.panel:SetPosition(px, py, 0)
    self.panel:Show()
end

----------------------------------------------------------------- Mỗi khung hình
function CosuMobInfo:OnUpdate(dt)
    local ent = nil
    local hud = self.owner.HUD
    if hud ~= nil and not hud:HasInputFocus() then
        ent = TheInput:GetWorldEntityUnderMouse()
        if not IsCandidate(ent) then ent = nil end
    end

    self.target = ent
    if ent ~= nil then
        self:Request(ent)
    end
    self:UpdatePanel()
end

return CosuMobInfo