-- Màn chọn Tiên Thiên Khí Vận: hiện 9 thanh (3 cột x 3 hàng) do server đưa (netvar _cosu_fortune_offer),
-- tên khí vận nằm trong thanh (màu thanh theo độ hiếm). Di chuột vào thanh mới hiện cửa sổ nhỏ ghi chỉ số cộng thêm.
-- Bấm thanh để chọn / bỏ chọn, xúc xắc để Roll đổi các thanh chưa chọn, nút Xác nhận gửi lên server.
local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local TextButton = require "widgets/textbutton"
local FT = require "cosu_fortune_tuning"

local SQUARE = { "images/global.xml", "square.tex" }
local GOLD = { 1.0, 0.85, 0.4, 1 }
local WHITE = { 1, 1, 1, 1 }
local GREY = { 0.7, 0.7, 0.7, 1 }

local ATLAS = "images/cosu_fortune.xml" -- 1 atlas chung cho 5 thanh + xúc xắc

-- 5 loại thanh (ảnh 110x34, phóng 2.09 lần). col = màu trung bình của thanh, dùng để tự chọn thanh gần màu độ hiếm nhất
local BARS = {
    la = { atlas = ATLAS, tex = "thanh_xanhla.tex", col = { 0.24, 0.57, 0.28 } },
    duong = { atlas = ATLAS, tex = "thanh_xanhduong.tex", col = { 0.24, 0.42, 0.62 } },
    tim = { atlas = ATLAS, tex = "07_thanh_tim.tex", col = { 0.49, 0.24, 0.59 } },
    cam = { atlas = ATLAS, tex = "38_thanh_cam.tex", col = { 0.91, 0.51, 0.26 } },
    ["do"] = { atlas = ATLAS, tex = "43_thanh_do.tex", col = { 0.60, 0.20, 0.20 } },
}
-- Độ hiếm (khóa trong cosu_fortune_tuning.RARITY) -> thanh. Thấp -> cao: lá < dương < tím < cam < đỏ
local BAR_OVERRIDE = { pham = "la", linh = "duong", hiem = "tim", cuc = "cam", tien = "do" }

local DICE_ATLAS, DICE_TEX = ATLAS, "icon_049.tex"

local COLS = 3
local BAR_W = 230
local BAR_H = math.floor(BAR_W * 34 / 110 + 0.5) -- 71, giữ đúng tỉ lệ ảnh
local GAP = 24
local PANEL_W = COLS * BAR_W + (COLS + 1) * 14 + 20
local PANEL_H = 480
local ROW_STEP = BAR_H + GAP
local ROW0_Y = 95
local BTN_Y = -PANEL_H / 2 + 45

local TIP_W = 300
local TIP_SIZE = 18

local function MakeRect(parent, w, h, colour, x, y)
    local r = parent:AddChild(Image(SQUARE[1], SQUARE[2]))
    r:SetTint(unpack(colour))
    r:SetSize(w, h)
    r:SetPosition(x or 0, y or 0, 0)
    return r
end

local function MakeText(parent, str, size, colour, x, y)
    local t = parent:AddChild(Text(UIFONT, size, str or ""))
    t:SetColour(unpack(colour or WHITE))
    t:SetPosition(x or 0, y or 0, 0)
    return t
end

local function Split(str)
    local ids = {}
    for id in string.gmatch(str or "", "[%w_]+") do table.insert(ids, id) end
    return ids
end

-- đếm số ký tự UTF-8 (tiếng Việt có dấu chiếm nhiều byte)
local function CharCount(s)
    local n = 0
    for i = 1, #s do
        local b = s:byte(i)
        if b < 128 or b >= 192 then n = n + 1 end
    end
    return n
end

local function PickBar(rkey, rar)
    local o = BAR_OVERRIDE[rkey]
    if o ~= nil and BARS[o] ~= nil then return BARS[o] end
    local c = rar ~= nil and rar.colour or WHITE
    local best, bd
    for _, b in pairs(BARS) do
        local d = (b.col[1] - c[1]) ^ 2 + (b.col[2] - c[2]) ^ 2 + (b.col[3] - c[3]) ^ 2
        if bd == nil or d < bd then best, bd = b, d end
    end
    return best
end

local CosuFortuneScreen = Class(Screen, function(self, owner)
    Screen._ctor(self, "CosuFortuneScreen")
    self.owner = owner
    self.sel = {}          -- id đang chọn, theo thứ tự bấm
    self.offer = {}
    self.offer_key = nil
    self.rebuild = true
    self.next_send = 0
    self.hovers = {}       -- thanh đang có thể hiện tooltip
    self.tip_key = nil

    self.black = self:AddChild(Image(SQUARE[1], SQUARE[2]))
    self.black:SetVRegPoint(ANCHOR_MIDDLE)
    self.black:SetHRegPoint(ANCHOR_MIDDLE)
    self.black:SetVAnchor(ANCHOR_MIDDLE)
    self.black:SetHAnchor(ANCHOR_MIDDLE)
    self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
    self.black:SetTint(0, 0, 0, 0.75)

    self.proot = self:AddChild(Widget("proot"))
    self.proot:SetVAnchor(ANCHOR_MIDDLE)
    self.proot:SetHAnchor(ANCHOR_MIDDLE)
    self.proot:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- ảnh nền bảng (atlas fabaobg_1 đã khai báo trong modmain)
    local bg = self.proot:AddChild(Image("images/fabaobg_1.xml", "fabaobg_1.tex"))
    bg:SetSize(PANEL_W, PANEL_H)
    bg:SetPosition(0, 0, 0)
    MakeText(self.proot, FT.TEXT.TITLE, 36, GOLD, 0, PANEL_H / 2 - 40)
    self.sub = MakeText(self.proot, "", 22, GREY, 0, PANEL_H / 2 - 78)

    self.cards = self.proot:AddChild(Widget("cards"))

    -- nút Roll: xúc xắc nhỏ
    self.roll_btn = self.proot:AddChild(ImageButton(DICE_ATLAS, DICE_TEX, DICE_TEX, DICE_TEX, DICE_TEX, DICE_TEX))
    self.roll_btn:ForceImageSize(52, 56)
    self.roll_btn:SetNormalScale(1, 1, 1)
    self.roll_btn:SetFocusScale(1.15, 1.15, 1)
    self.roll_btn:SetPosition(-120, BTN_Y, 0)
    self.roll_btn:SetOnClick(function() self:DoRoll() end)

    MakeRect(self.proot, 170, 40, { 0, 0, 0, 0.8 }, 120, BTN_Y)
    self.ok_btn = self.proot:AddChild(TextButton())
    self.ok_btn:SetFont(UIFONT)
    self.ok_btn:SetTextSize(26)
    self.ok_btn:SetText(FT.TEXT.CONFIRM)
    self.ok_btn:SetTextFocusColour(unpack(GOLD))
    self.ok_btn:SetPosition(120, BTN_Y, 0)
    self.ok_btn:SetOnClick(function() self:DoConfirm() end)

    -- cửa sổ nhỏ (tooltip): tạo sau cùng để luôn nằm trên các thanh
    self.tip = self.proot:AddChild(Widget("tip"))
    self.tip_border = MakeRect(self.tip, TIP_W + 4, 40, { 0.75, 0.6, 0.3, 1 }, 0, 0)
    self.tip_bg = MakeRect(self.tip, TIP_W, 36, { 0.05, 0.05, 0.07, 1 }, 0, 0)
    self.tip_text = self.tip:AddChild(Text(UIFONT, TIP_SIZE, ""))
    self.tip_text:SetColour(unpack(WHITE))
    self.tip_text:EnableWordWrap(true)
    self.tip_text:SetHAlign(ANCHOR_MIDDLE)
    self.tip_text:SetVAlign(ANCHOR_MIDDLE)
    self.tip:Hide()

    self:StartUpdating()
end)

-- mở màn chọn nếu server đang chờ người chơi này chọn (gọi an toàn nhiều lần)
function CosuFortuneScreen.TryOpen(p)
    if p == nil or p ~= ThePlayer or p.HUD == nil then return end
    if p._cosu_fortune_offer == nil or p._cosu_fortune_offer:value() == "" then return end
    local top = TheFrontEnd:GetActiveScreen()
    if top ~= nil and top.name == "CosuFortuneScreen" then return end
    TheFrontEnd:PushScreen(CosuFortuneScreen(p))
end

function CosuFortuneScreen:NeedCount()
    return math.min(FT.PICK, #self.offer)
end

function CosuFortuneScreen:Toggle(id)
    for i, v in ipairs(self.sel) do
        if v == id then
            table.remove(self.sel, i)
            self.rebuild = true -- dựng lại ở lượt Update kế (không xóa nút ngay trong lúc nó xử lý cú bấm)
            return
        end
    end
    if #self.sel >= self:NeedCount() then table.remove(self.sel, 1) end
    table.insert(self.sel, id)
    self.rebuild = true
end

function CosuFortuneScreen:CanSend()
    local t = GetTime()
    if t < self.next_send then return false end
    self.next_send = t + 0.3
    return true
end

function CosuFortuneScreen:DoRoll()
    if not self:CanSend() then return end
    SendModRPCToServer(MOD_RPC["cosu"]["fortune_roll"], table.concat(self.sel, ","))
end

function CosuFortuneScreen:DoConfirm()
    if #self.sel ~= self:NeedCount() or #self.sel == 0 then return end
    if not self:CanSend() then return end
    SendModRPCToServer(MOD_RPC["cosu"]["fortune_pick"], table.concat(self.sel, ","))
end

function CosuFortuneScreen:Build()
    self.cards:KillAllChildren()
    self.hovers = {}
    self.tip_key = nil
    self.tip:Hide()
    local selected = {}
    for _, id in ipairs(self.sel) do selected[id] = true end

    for i, id in ipairs(self.offer) do
        local d = FT.BY_ID[id]
        if d ~= nil then
            local rar = FT.RARITY[d.rarity]
            local bar = PickBar(d.rarity, rar)
            local col = (i - 1) % COLS
            local row = math.floor((i - 1) / COLS)
            local x = (col - (COLS - 1) / 2) * (BAR_W + 14)
            local y = ROW0_Y - row * ROW_STEP
            local on = selected[id]

            if on then -- viền vàng phía sau thanh đang chọn
                MakeRect(self.cards, BAR_W + 12, BAR_H + 12, GOLD, x, y)
            end

            local btn = self.cards:AddChild(ImageButton(bar.atlas, bar.tex, bar.tex, bar.tex, bar.tex, bar.tex))
            btn:ForceImageSize(BAR_W, BAR_H)
            local n = on and { 1, 1, 1, 1 } or { 0.72, 0.72, 0.72, 1 }
            btn:SetImageNormalColour(unpack(n))
            btn:SetImageFocusColour(1, 1, 1, 1)
            btn:SetImageSelectedColour(unpack(n))
            btn:SetNormalScale(1, 1, 1)
            btn:SetFocusScale(1.04, 1.04, 1)
            btn:SetPosition(x, y, 0)
            btn:SetOnClick(function() self:Toggle(id) end)

            -- tên nằm trong thanh; tên dài thì hạ cỡ chữ cho vừa
            local len = CharCount(d.name or "")
            local size = len <= 13 and 24 or (len <= 17 and 20 or 17)
            MakeText(btn, d.name, size, on and GOLD or WHITE, 0, 0)

            table.insert(self.hovers, {
                btn = btn, text = d.desc or "", x = x, y = y, above = row >= 2, h = BAR_H,
            })
        end
    end

    local need = self:NeedCount()
    self.sub:SetString(string.format(FT.TEXT.SUB, need, #self.sel, need))
    local ready = need > 0 and #self.sel == need
    local c = ready and GOLD or GREY
    self.ok_btn:SetTextColour(unpack(c))
end

-- hiện cửa sổ chỉ số ngay dưới thanh (hàng cuối thì hiện phía trên để khỏi tràn khỏi bảng)
function CosuFortuneScreen:ShowTip(h)
    local key = h.text .. "|" .. h.x .. "|" .. h.y
    if key == self.tip_key then return end
    self.tip_key = key

    local text = h.text
    local inner = TIP_W - 24
    local cpl = math.max(1, math.floor(inner / (TIP_SIZE * 0.5)))
    local lines = 0
    for seg in string.gmatch(text .. "\n", "(.-)\n") do
        lines = lines + math.max(1, math.ceil(CharCount(seg) / cpl))
    end
    local th = lines * (TIP_SIZE + 4) + 20

    self.tip_text:SetRegionSize(inner, th - 10)
    self.tip_text:SetString(text)
    self.tip_bg:SetSize(TIP_W, th)
    self.tip_border:SetSize(TIP_W + 4, th + 4)

    local x = math.max(-PANEL_W / 2 + TIP_W / 2 + 6, math.min(PANEL_W / 2 - TIP_W / 2 - 6, h.x))
    local half = (h.h or BAR_H) / 2 + 6 + th / 2
    local y = h.above and (h.y + half) or (h.y - half)
    self.tip:SetPosition(x, y, 0)
    self.tip:MoveToFront()
    self.tip:Show()
end

function CosuFortuneScreen:UpdateTip()
    local hv = nil
    for _, h in ipairs(self.hovers) do
        if h.btn.focus then hv = h break end
    end
    if hv ~= nil and hv.text ~= "" then
        self:ShowTip(hv)
    elseif self.tip_key ~= nil then
        self.tip_key = nil
        self.tip:Hide()
    end
end

function CosuFortuneScreen:Close()
    if self.closing then return end
    self.closing = true
    TheFrontEnd:PopScreen(self)
end

function CosuFortuneScreen:OnUpdate(dt)
    local p = self.owner
    if p == nil or not p:IsValid() or p._cosu_fortune_offer == nil then
        self:Close()
        return
    end
    local str = p._cosu_fortune_offer:value()
    if str == "" then -- server đã nhận xác nhận
        self:Close()
        return
    end
    if str ~= self.offer_key then
        self.offer_key = str
        self.offer = Split(str)
        local inoffer = {}
        for _, id in ipairs(self.offer) do inoffer[id] = true end
        local keep = {}
        for _, id in ipairs(self.sel) do
            if inoffer[id] then table.insert(keep, id) end
        end
        self.sel = keep
        self.rebuild = true
    end
    if self.rebuild then
        self.rebuild = false
        self:Build()
    end
    self:UpdateTip()
end

-- Không cho Esc đóng màn (phải chọn xong); nếu lỡ đóng, mở lại từ nút trong bảng B
function CosuFortuneScreen:OnControl(control, down)
    if CosuFortuneScreen._base.OnControl(self, control, down) then return true end
    if control == CONTROL_CANCEL or control == CONTROL_PAUSE then return true end
    return false
end

return CosuFortuneScreen