-- scripts/screens/cosu_shop_screen.lua : bảng Thạch Quán (đổ thạch) + đèn lồng
local Screen      = require "widgets/screen"
local Widget      = require "widgets/widget"
local Image       = require "widgets/image"
local Text        = require "widgets/text"
local ImageButton = require "widgets/imagebutton"
local T           = require "cosu_shop_tuning"
local okT, TEMPLATES = pcall(require, "widgets/redux/templates")
if not okT then TEMPLATES = nil end

local ATLAS = "images/cosu_shop.xml"
local COIN_ATLAS, COIN_TEX = "images/inventoryimages/cosu_linhthach.xml", "cosu_linhthach.tex"

-- Bố cục (không gian 1280x720). Chỉnh các số này nếu muốn dời/đổi cỡ.
local BOARD_POS,   BOARD_SCALE   = { -70, -10 }, 0.86
local LANTERN_POS, LANTERN_SCALE = { 420, 175 }, 0.95
local UI_SCALE = 0.62  -- thu/phóng cả bảng + đèn lồng + nội dung (0.5 nhỏ hơn, 0.7 lớn hơn)
local CLOSE_BTN_POS, CLOSE_BTN_SIZE = { 330, 312 }, 56 -- nút X tắt cửa sổ shop (góc trên bên phải bảng)
local CLOSE_DIST = 9   -- đi xa nhà hơn khoảng này thì tự đóng

-- NPC bên trái bảng (tính theo đơn vị của self.panel, gốc = giữa màn hình; mép trái màn hình ~ -1030)
local NPC_POS, NPC_H = { -720, -60 }, 400     -- vị trí tâm + chiều cao ảnh NPC
local TALK_BTN_POS = { -720, -320 }           -- nút "Trò chuyện"
local BUBBLE_POS, BUBBLE_W, BUBBLE_H = { -720, 310 }, 540, 280 -- khung thoại phía trên đầu NPC

-- Vùng giấy xám giữa bảng và dải trắng phía dưới (đo từ ảnh chụp, tính theo đơn vị của panel, gốc = tâm ảnh bảng)
local PAPER = { x = 10, y = 3, w = 833, h = 488 }
local STRIP = { x = 10, y = -281, w = 861 }
local COLS = 3
local CELL_W, CELL_H = PAPER.w / COLS, PAPER.h / 3
local STONE_BOX_W, STONE_BOX_H, STONE_MAX_SCALE = 210, 100, 2.0 -- mọi viên vừa khung như nhau

-- trạng thái chỉ số của lần chào gần nhất (giữ suốt phiên chơi, không mất khi đóng/mở lại quán)
local last_greet_sig = nil

local WHITE = { 1, 1, 1, 1 }
local GOLD  = { 1.0, 0.85, 0.4, 1 }
local INK   = { 0.13, 0.11, 0.09, 1 }
local GREEN  = { 0.6, 1.0, 0.6, 1 }   -- giá đang được giảm
local ORANGE = { 1.0, 0.7, 0.35, 1 }  -- giá đang bị tăng

local function MakeText(parent, str, size, colour, x, y, w, align)
    local t = parent:AddChild(Text(UIFONT, size, str or ""))
    t:SetColour(unpack(colour or WHITE))
    if w ~= nil then
        t:SetRegionSize(w, size + 8)
        t:SetHAlign(align or ANCHOR_MIDDLE)
    end
    t:SetPosition(x or 0, y or 0, 0)
    return t
end

-- đoạn chữ nhiều dòng tự xuống dòng, căn trái, bắt đầu từ trên
local function MakeWrap(parent, str, size, colour, x, y, w, h)
    local t = parent:AddChild(Text(UIFONT, size, str or ""))
    t:SetColour(unpack(colour or WHITE))
    t:SetRegionSize(w, h)
    t:SetHAlign(ANCHOR_LEFT)
    t:SetVAlign(ANCHOR_TOP)
    t:EnableWordWrap(true)
    t:SetPosition(x, y, 0)
    return t
end

local function MakeRect(parent, w, h, tint, x, y)
    local r = parent:AddChild(Image("images/global.xml", "square.tex"))
    r:SetSize(w, h)
    r:SetTint(unpack(tint))
    r:SetPosition(x or 0, y or 0, 0)
    return r
end

local function MakeButton(parent, text, w, h, fn)
    local btn
    if TEMPLATES ~= nil and TEMPLATES.StandardButton ~= nil then
        btn = parent:AddChild(TEMPLATES.StandardButton(fn, text, { w, h }))
    else
        btn = parent:AddChild(ImageButton())
        btn:SetText(text)
        btn:SetOnClick(fn)
    end
    return btn
end

local function Tex(name)
    if name ~= nil and not name:find("%.tex$") then name = name .. ".tex" end
    return name
end

local function Commas(n)
    return (tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function ParseStock(str)
    local list = {}
    for part in string.gmatch(str or "", "[^;]+") do
        local si, pr = string.match(part, "^(%d+):(%d+)$")
        if si ~= nil then
            table.insert(list, { stone = tonumber(si), price = tonumber(pr) })
        else
            table.insert(list, { empty = true }) -- "-" = ô đã bán, đang chờ hàng mới
        end
    end
    return list
end

local CosuShopScreen = Class(Screen, function(self, owner, house)
    Screen._ctor(self, "CosuShopScreen")
    self.owner = owner
    self.house = house
    self.busy = false
    self.result = nil

    self.black = self:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetVRegPoint(ANCHOR_MIDDLE)
    self.black:SetHRegPoint(ANCHOR_MIDDLE)
    self.black:SetVAnchor(ANCHOR_MIDDLE)
    self.black:SetHAnchor(ANCHOR_MIDDLE)
    self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
    self.black:SetTint(0, 0, 0, .55)

    self.root = self:AddChild(Widget("ROOT"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- widget cha: thu/phóng cả bảng + đèn lồng + nội dung cùng lúc
    self.panel = self.root:AddChild(Widget("panel"))
    self.panel:SetScale(UI_SCALE)

    self.board = self.panel:AddChild(Image(ATLAS, "board.tex"))
    self.board:SetPosition(BOARD_POS[1], BOARD_POS[2])
    self.board:SetScale(BOARD_SCALE)

    -- mọi thứ trong bảng đặt theo tâm ảnh bảng
    self.content = self.panel:AddChild(Widget("content"))
    self.content:SetPosition(BOARD_POS[1], BOARD_POS[2])

    self.lantern = self.panel:AddChild(Image(ATLAS, "lantern.tex"))
    self.lantern:SetPosition(LANTERN_POS[1], LANTERN_POS[2])
    self.lantern:SetScale(LANTERN_SCALE)

    self:BuildSlots()
    self:BuildWallet()
    self:BuildNpc()

    if house ~= nil then
        self.inst:ListenForEvent("cosu_stockdirty", function() self:RefreshStock() end, house)
    end
    local closebtn = MakeButton(self.panel, "X", CLOSE_BTN_SIZE, CLOSE_BTN_SIZE, function() self:Close() end)
    closebtn:SetPosition(CLOSE_BTN_POS[1], CLOSE_BTN_POS[2], 0)

    self.inst:ListenForEvent("cosu_linhthachdirty", function() self:RefreshWallet() end, owner)
    self.inst:ListenForEvent("cosu_fortunedirty", function() self:RefreshStock() end, owner) -- chỉ số đổi -> giá đổi

    self:RefreshStock()
    self:RefreshWallet()

    self.default_focus = self.root
    self.inst:DoPeriodicTask(0.5, function() self:CheckDist() end)
end)

---------------------------------------------------------------------------
-- Lưới 9 viên đá
---------------------------------------------------------------------------
function CosuShopScreen:BuildSlots()
    self.slots = {}
    for i = 1, T.SLOTS do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        local cell = self.content:AddChild(Widget("slot" .. i))
        cell:SetPosition(PAPER.x + (col - 1) * CELL_W, PAPER.y + (1 - row) * CELL_H, 0)

        MakeRect(cell, CELL_W - 14, CELL_H - 10, { 0, 0, 0, 0.16 }, 0, 0)
        cell.holder = cell:AddChild(Widget("holder"))
        cell.holder:SetPosition(0, 30, 0)

        cell.coin = cell:AddChild(Image(COIN_ATLAS, COIN_TEX))
        cell.coin:SetSize(22, 22)
        cell.coin:SetPosition(-36, -28, 0)
        cell.price = MakeText(cell, "", 22, WHITE, 22, -28, 100, ANCHOR_LEFT)

        cell.btn = MakeButton(cell, "Đổ thạch", 130, 34, function() self:Gamble(i) end)
        cell.btn:SetPosition(0, -58, 0)

        self.slots[i] = cell
    end
end

function CosuShopScreen:RefreshStock()
    local list = ParseStock(self.house ~= nil and self.house._stock ~= nil and self.house._stock:value() or "")
    for i, cell in ipairs(self.slots) do
        local e = list[i]
        cell.holder:KillAllChildren()
        cell.price_value = nil
        cell.price_tint = WHITE
        if e ~= nil and not e.empty then
            local def = T.STONES[e.stone] or T.STONES[1]
            local img = cell.holder:AddChild(Image(T.ATLAS, Tex(def)))
            local w, h = img:GetSize()
            if w ~= nil and w > 0 and h > 0 then
                img:SetScale(math.min(STONE_BOX_W / w, STONE_BOX_H / h, STONE_MAX_SCALE))
            end
            local price = T.AdjustPrice(e.price, self.owner) -- mị lực giảm giá / ma đạo > chính đạo tăng giá
            cell.price_value = price
            cell.price_tint = price < e.price and GREEN or (price > e.price and ORANGE or WHITE)
            cell.price:SetString(Commas(price))
            cell.coin:Show(); cell.price:Show(); cell.btn:Show()
        else
            cell.coin:Hide(); cell.price:Hide(); cell.btn:Hide()
            if e ~= nil then MakeText(cell.holder, "Đã bán", 30, { 0.75, 0.75, 0.75, 0.9 }, 0, 0, 200) end
        end
    end
    self:RefreshWallet()

    -- hết sạch đá: NPC báo hết hàng (list rỗng nghĩa là chưa đồng bộ xong, không tính)
    local sold = #list > 0
    for _, e in ipairs(list) do if not e.empty then sold = false end end
    if sold then
        if not self.soldout_said and self.bubble ~= nil then
            self.soldout_said = true
            self.talk_index = 0
            self.bubble:Show()
            self.talk_text:SetString(T.SoldOutLine())
            self.talk_page_text:SetString("")
        end
    else
        self.soldout_said = false
    end
end

---------------------------------------------------------------------------
-- NPC + khung thoại + nút Trò chuyện
---------------------------------------------------------------------------
function CosuShopScreen:BuildNpc()
    local npc = self.panel:AddChild(Image(T.NPC_ATLAS, T.NPC_TEX))
    npc:SetPosition(NPC_POS[1], NPC_POS[2], 0)
    local w, h = npc:GetSize()
    if w ~= nil and h ~= nil and h > 0 then npc:SetScale(NPC_H / h) end
    self.npc = npc

    local bub = self.panel:AddChild(Widget("bubble"))
    self.bubble = bub
    bub:SetPosition(BUBBLE_POS[1], BUBBLE_POS[2], 0)
    MakeRect(bub, BUBBLE_W + 8, BUBBLE_H + 8, { 0.85, 0.7, 0.35, 0.9 }, 0, 0) -- viền vàng
    MakeRect(bub, BUBBLE_W, BUBBLE_H, { 0.07, 0.06, 0.05, 0.92 }, 0, 0)
    MakeText(bub, T.NPC_NAME, 30, GOLD, 0, BUBBLE_H / 2 - 24, BUBBLE_W - 40, ANCHOR_LEFT)
    self.talk_text = MakeWrap(bub, "", 26, WHITE, 0, -16, BUBBLE_W - 40, BUBBLE_H - 70)
    self.talk_page_text = MakeText(bub, "", 22, { 0.6, 0.6, 0.6, 1 }, 0, -BUBBLE_H / 2 + 18, BUBBLE_W - 40, ANCHOR_RIGHT)

    local btn = MakeButton(self.panel, "Trò chuyện", 200, 50, function() self:Talk() end)
    btn:SetPosition(TALK_BTN_POS[1], TALK_BTN_POS[2], 0)
    self.talk_btn = btn

    self.talk_index = 0
    -- lời chào tùy chỉ số: chỉ chào khi trạng thái chỉ số khác lần chào trước, còn không thì khung thoại ẩn cho tới khi bấm Trò chuyện
    local sig = T.GreetSignature(self.owner)
    if sig ~= last_greet_sig then
        last_greet_sig = sig
        self.talk_text:SetString(T.GreetLine(self.owner))
    else
        bub:Hide()
    end
end

function CosuShopScreen:Talk()
    local pages = T.TalkPages(self.owner)
    self.bubble:Show()
    self.talk_index = self.talk_index % #pages + 1
    self.talk_text:SetString(pages[self.talk_index])
    self.talk_page_text:SetString(self.talk_index .. "/" .. #pages)
end

---------------------------------------------------------------------------
-- Thanh Linh Thạch (giống tab Trạng thái của bảng nhân vật)
---------------------------------------------------------------------------
function CosuShopScreen:BuildWallet()
    local bar = self.content:AddChild(Widget("wallet"))
    bar:SetPosition(STRIP.x, STRIP.y, 0)
    MakeRect(bar, 500, 36, { 0, 0, 0, 0.8 }, 0, 0)
    local icon = bar:AddChild(Image(COIN_ATLAS, COIN_TEX))
    icon:SetSize(30, 30)
    icon:SetPosition(-110, 0, 0)
    MakeText(bar, "Linh Thạch", 26, WHITE, -10, 0, 150, ANCHOR_LEFT)
    self.wallet_text = MakeText(bar, "0", 26, GOLD, 175, 0, 240, ANCHOR_LEFT)
end

function CosuShopScreen:GetWallet()
    local p = self.owner
    return (p ~= nil and p._cosu_linhthach ~= nil) and p._cosu_linhthach:value() or 0
end

function CosuShopScreen:RefreshWallet()
    local have = self:GetWallet()
    self.wallet_text:SetString(Commas(have))
    for _, cell in ipairs(self.slots) do
        local can = cell.price_value ~= nil and have >= cell.price_value and not self.busy and self.result == nil
        if can then cell.btn:Enable() else cell.btn:Disable() end
        cell.price:SetColour(unpack((cell.price_value ~= nil and have < cell.price_value) and { 1, 0.45, 0.4, 1 } or (cell.price_tint or WHITE)))
    end
end

---------------------------------------------------------------------------
-- Đổ thạch
---------------------------------------------------------------------------
function CosuShopScreen:Gamble(slot)
    if self.busy or self.result ~= nil then return end
    self.busy = true
    SendModRPCToServer(GetModRPC("cosu", "gamble"), slot)
    self:RefreshWallet()
    self.inst:DoTaskInTime(3, function() -- phòng khi server từ chối, không nhận được kết quả
        if self.busy then self.busy = false; self:RefreshWallet() end
    end)
end

-- server gửi kết quả về (xem modmain.lua: AddClientModRPCHandler "shopresult")
function CosuShopScreen:ShowResult(prefab, count)
    self.busy = false
    self:ClearResult()

    local res = self:AddChild(Widget("result"))
    self.result = res

    local dim = res:AddChild(Image("images/global.xml", "square.tex"))
    dim:SetVRegPoint(ANCHOR_MIDDLE)
    dim:SetHRegPoint(ANCHOR_MIDDLE)
    dim:SetVAnchor(ANCHOR_MIDDLE)
    dim:SetHAnchor(ANCHOR_MIDDLE)
    dim:SetScaleMode(SCALEMODE_FILLSCREEN)
    dim:SetTint(0, 0, 0, .6)

    local rc = res:AddChild(Widget("rc"))
    rc:SetVAnchor(ANCHOR_MIDDLE)
    rc:SetHAnchor(ANCHOR_MIDDLE)
    rc:SetScaleMode(SCALEMODE_PROPORTIONAL)
    rc:SetScale(0.9)

    local txtcol = WHITE
    if T.GLOW ~= nil then
        local glow = rc:AddChild(Image(T.ATLAS, Tex(T.GLOW)))
        glow:SetScale(1.5)
        txtcol = INK
    else
        MakeRect(rc, 520, 320, { 0.05, 0.05, 0.05, 0.9 }, 0, 0)
    end

    MakeText(rc, "Bạn nhận được", 34, txtcol, 0, 100, 480)

    local imagename = prefab .. ".tex"
    local icon = rc:AddChild(Image(GetInventoryItemAtlas(imagename), imagename))
    icon:SetPosition(0, 25, 0)
    icon:SetScale(0.2)
    icon:ScaleTo(0.2, 1.8, 0.3)

    local name = STRINGS.NAMES[string.upper(prefab)] or prefab
    MakeText(rc, name .. (count > 1 and (" x" .. count) or ""), 34, txtcol == INK and INK or GOLD, 0, -55, 480)

    local btn = MakeButton(rc, "Nhận", 140, 40, function() self:ClearResult() end)
    btn:SetPosition(0, -110, 0)

    self:RefreshWallet()
end

function CosuShopScreen:ClearResult()
    if self.result ~= nil then
        self.result:Kill()
        self.result = nil
        self:RefreshWallet()
    end
end

---------------------------------------------------------------------------
function CosuShopScreen:CheckDist()
    local p, h = self.owner, self.house
    if p == nil or not p:IsValid() or h == nil or not h:IsValid() or p:GetDistanceSqToInst(h) > CLOSE_DIST * CLOSE_DIST then
        self:Close()
    end
end

function CosuShopScreen:Close()
    if self.closed then return end
    self.closed = true
    TheFrontEnd:PopScreen(self)
end

function CosuShopScreen:OnControl(control, down)
    if CosuShopScreen._base.OnControl(self, control, down) then return true end
    if not down then
        if self.result ~= nil and (control == CONTROL_ACCEPT or control == CONTROL_CANCEL or control == CONTROL_PAUSE) then
            self:ClearResult() -- đang hiện bảng nhận đồ: bấm đâu cũng đóng bảng đó trước
            return true
        end
        if control == CONTROL_PAUSE or control == CONTROL_CANCEL then -- ESC / chuột phải
            self:Close()
            return true
        end
    end
    return false
end

return CosuShopScreen