local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local PopupDialogScreen = require "screens/popupdialog"
local GU = require "cosu_gu_tuning"

-- Ảnh dùng tạm. Muốn đổi sang ảnh riêng thì sửa các dòng này.
local SQ_ATLAS, SQ_TEX = "images/global.xml", "square.tex"           -- khung, nút đóng, icon tạm
local SLOT_ATLAS, SLOT_TEX = "images/cosu_ovuong.xml", "cosu_ovuong.tex" -- ô vuông (9 ô trang bị + lưới cổ trùng)
local CIRCLE_ATLAS, CIRCLE_TEX = "images/cosu_otron.xml", "cosu_otron.tex" -- ô tròn Bản Mệnh Cổ
local FOCUS_GROW = 1.05   -- ô phóng to bao nhiêu lần khi rê chuột vào (1 = không phóng)
local MAIN_SIZE = 150      -- cỡ ô tròn
local SLOT_SIZE = 62       -- cỡ 9 ô trang bị (to quá/nhỏ quá thì chỉnh, nhớ chỉnh khoảng cách 80 bên dưới)
local FONT = UIFONT -- nếu chữ có dấu bị lỗi ô vuông, đổi sang font đang dùng trong cosu_awaken_screen

-- cửa sổ giải thích khi rê chuột
local TIP_NAME_SIZE = 30    -- cỡ chữ tên cổ trùng
local TIP_DESC_SIZE = 24    -- cỡ chữ mô tả
local TIP_MAX_W = 380       -- độ rộng tối đa của dòng mô tả (quá thì xuống dòng)
local TIP_MAX_LINES = 4     -- số dòng mô tả tối đa
local TIP_ALPHA = .8        -- độ đậm của nền đen (0 = trong suốt, 1 = đặc)
local TIP_PAD = 14          -- khoảng đệm giữa chữ và mép nền

-- nền động thủy mặc (build/bank cosu_ink, anim idle; khung gốc 504x240)
local PANEL_W, PANEL_H = 900, 560
local BG_NATIVE_W, BG_NATIVE_H = 504, 240 -- nếu nền hiện quá to/bé so với khung thì chỉnh 2 số này

local COLS = 12
local CELL, GAP = 56, 66

local function MakeSlotButton(parent, atlas, tex, size, icon_size, x, y, onclick)
    local b = parent:AddChild(ImageButton(atlas, tex))
    b:SetPosition(x, y)
    b:ForceImageSize(size, size)
    -- ImageButton đặt lại scale của ảnh khi rê chuột vào/ra (mặc định 1.2 / 1), làm ảnh to ra đúng cỡ gốc.
    -- Nên phải tự đặt scale đúng theo cỡ gốc của ảnh.
    local nw = b.image:GetSize()
    if nw ~= nil and nw > 0 then
        local sc = size / nw
        b.normal_scale = { sc, sc, 1 }
        b.focus_scale = { sc * FOCUS_GROW, sc * FOCUS_GROW, 1 }
        b.image:SetScale(sc, sc, 1)
    end
    b:SetOnClick(onclick)
    b.icon = b:AddChild(Image(SQ_ATLAS, SQ_TEX))
    b.icon:Hide()
    b.icon_size = icon_size
    b.label = b:AddChild(Text(FONT, 26, ""))
    return b
end

local function SetIcon(b, gu)
    if gu ~= nil then
        b.icon:SetTexture(gu.atlas, gu.image)
        b.icon:ScaleToSize(b.icon_size, b.icon_size)
        b.icon:Show()
    else
        b.icon:Hide()
    end
end

-- gắn thêm việc làm khi con trỏ chuột đi vào / rời khỏi nút
local function HookFocus(b, on_gain, on_lose)
    local base_gain, base_lose = b.OnGainFocus, b.OnLoseFocus
    b.OnGainFocus = function(w)
        base_gain(w)
        on_gain()
    end
    b.OnLoseFocus = function(w)
        base_lose(w)
        on_lose()
    end
end

-- hiệu ứng nhẹ cho các ô (khung gốc 128px, build/bank trùng tên anim, animation idle)
local FX_NATIVE = 128
local FX_ORBIT_PAD = 1.25   -- đốm sáng chạy quanh viền: phóng to hơn ô một chút để đường chạy sát mép ô
local FX_RISE_PAD = 1.0     -- đốm sáng bay lên: vừa khít ô
local RISE_ONLY_UNLOCKED = true -- true: 9 ô trang bị chỉ có hiệu ứng khi đã mở khóa; false: hiện ở cả ô còn khóa

local function AddFx(parent, build, size)
    local fx = parent:AddChild(UIAnim())
    fx:GetAnimState():SetBank(build)
    fx:GetAnimState():SetBuild(build)
    fx:GetAnimState():PlayAnimation("idle", true)
    local sc = size / FX_NATIVE
    fx:SetScale(sc, sc, 1)
    if fx.SetClickable ~= nil then fx:SetClickable(false) end -- không chắn chuột của nút bên dưới
    return fx
end

local CosuSeaScreen = Class(Screen, function(self, owner)
    Screen._ctor(self, "CosuSeaScreen")
    self.owner = owner
    self.ids = {}          -- cổ trùng chưa trang bị
    self.main = 0          -- id ở ô Bản Mệnh Cổ
    self.eq_slots = {}     -- id ở 9 ô trang bị
    self.selected = nil    -- vị trí đang chọn trong danh sách
    self.last_list = nil
    self.tip_kind, self.tip_idx = nil, nil -- ô đang được rê chuột vào ("main" / "slot" / "cell" + số thứ tự)

    -- nền tối phủ toàn màn hình
    self.black = self:AddChild(Image(SQ_ATLAS, SQ_TEX))
    self.black:SetVRegPoint(ANCHOR_MIDDLE)
    self.black:SetHRegPoint(ANCHOR_MIDDLE)
    self.black:SetVAnchor(ANCHOR_MIDDLE)
    self.black:SetHAnchor(ANCHOR_MIDDLE)
    self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
    self.black:SetTint(0, 0, 0, .6)

    self.root = self:AddChild(Widget("root"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- khung chính
    local panel = self.root:AddChild(Image(SQ_ATLAS, SQ_TEX))
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetTint(.55, .57, .72, .92)

    -- nền động nằm đè lên khung, dưới mọi ô và chữ
    self.bg = self.root:AddChild(UIAnim())
    self.bg:GetAnimState():SetBank("cosu_ink")
    self.bg:GetAnimState():SetBuild("cosu_ink")
    self.bg:GetAnimState():PlayAnimation("idle", true)
    self.bg:SetScale(PANEL_W / BG_NATIVE_W, PANEL_H / BG_NATIVE_H, 1)

    -- ô tròn Bản Mệnh Cổ (cũng là một ô trống)
    self.main_slot = MakeSlotButton(self.root, CIRCLE_ATLAS, CIRCLE_TEX, MAIN_SIZE, 100, 0, 170,
        function() self:OnClickPlace(0) end)
    HookFocus(self.main_slot,
        function() self:SetTip("main", 0) end,
        function() self:ClearTip("main", 0) end)

    local title = self.root:AddChild(Text(FONT, 30, "Bản Mệnh Cổ"))
    title:SetPosition(0, 75)
    title:SetColour(.95, .95, 1, 1)

    -- 9 ô vuông trang bị, mở lần lượt theo chuyển
    self.slots = {}
    for i = 1, GU.SLOTS do
        self.slots[i] = MakeSlotButton(self.root, SLOT_ATLAS, SLOT_TEX, SLOT_SIZE, 50,
            (i - (GU.SLOTS + 1) / 2) * 80, 15,
            function() self:OnClickPlace(i) end)
        HookFocus(self.slots[i],
            function() self:SetTip("slot", i) end,
            function() self:ClearTip("slot", i) end)
        self.slots[i].fx = AddFx(self.slots[i], "cosu_slot_rise", SLOT_SIZE * FX_RISE_PAD)
    end

    -- lưới ô chứa cổ trùng chưa trang bị
    self.cells = {}
    for i = 1, GU.MAX_GU do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        self.cells[i] = MakeSlotButton(self.root, SLOT_ATLAS, SLOT_TEX, CELL, 44,
            (col - (COLS - 1) / 2) * GAP, -95 - row * GAP,
            function() self:Select(i) end)
        HookFocus(self.cells[i],
            function() self:SetTip("cell", i) end,
            function() self:ClearTip("cell", i) end)
    end

    self.hint = self.root:AddChild(Text(FONT, 26, ""))
    self.hint:SetPosition(0, -240)
    self.hint:SetColour(.95, .95, 1, 1)

    -- nút đóng
    local close = self.root:AddChild(ImageButton(SQ_ATLAS, SQ_TEX))
    close:SetPosition(415, 255)
    close:ForceImageSize(40, 40)
    close.image:SetTint(.3, .3, .45, 1)
    close:SetOnClick(function() TheFrontEnd:PopScreen() end)
    AddFx(close, "cosu_slot_orbit", 40 * FX_ORBIT_PAD)
    local x = close:AddChild(Text(FONT, 26, "X"))
    x:SetColour(1, 1, 1, 1)

    -- cửa sổ giải thích khi rê chuột (đặt cuối cùng để nằm trên mọi thứ)
    self.tipbox = self.root:AddChild(Widget("tipbox"))
    self.tipbox.bg = self.tipbox:AddChild(Image(SQ_ATLAS, SQ_TEX))
    self.tipbox.bg:SetTint(0, 0, 0, TIP_ALPHA)
    self.tipbox.bg:SetClickable(false)
    self.tipbox.name = self.tipbox:AddChild(Text(FONT, TIP_NAME_SIZE, ""))
    self.tipbox.name:SetColour(1, 1, 1, 1)
    self.tipbox.desc = self.tipbox:AddChild(Text(FONT, TIP_DESC_SIZE, ""))
    self.tipbox.desc:SetColour(1, 1, 1, 1)
    self.tipbox:Hide()

    -- tự cập nhật khi dữ liệu từ server thay đổi
    self.inst:ListenForEvent("cosu_gudirty", function() self:Refresh() end, owner)
    self.inst:ListenForEvent("cosu_gueqdirty", function() self:Refresh() end, owner)
    self.inst:ListenForEvent("cosu_rankdirty", function() self:Refresh() end, owner)

    self:Refresh()
end)

function CosuSeaScreen:SetTip(kind, idx)
    self.tip_kind, self.tip_idx = kind, idx
    self:UpdateTip()
end

function CosuSeaScreen:ClearTip(kind, idx)
    if self.tip_kind == kind and self.tip_idx == idx then
        self.tip_kind, self.tip_idx = nil, nil
        self:UpdateTip()
    end
end

-- Cửa sổ giải thích: tên (to) + mô tả (nhỏ) trên nền đen mờ, tự co theo độ dài chữ.
-- Ô lưới -> hiện phía trên ô; ô trang bị -> phía dưới ô; ô tròn -> bên phải ô.
function CosuSeaScreen:UpdateTip()
    local kind, idx = self.tip_kind, self.tip_idx
    local id, w, size = 0, nil, 0
    if kind == "main" then
        id, w, size = self.main, self.main_slot, MAIN_SIZE
    elseif kind == "slot" then
        id, w, size = self.eq_slots[idx] or 0, self.slots[idx], SLOT_SIZE
    elseif kind == "cell" then
        id, w, size = self.ids[idx] or 0, self.cells[idx], CELL
    end

    local gu = GU.LIST[id]
    if gu == nil or w == nil then
        self.tipbox:Hide()
        return
    end

    -- thứ tự lấy mô tả: gu.desc -> tip_slot / tip_main
    local desc = gu.desc or (kind == "main" and gu.tip_main) or gu.tip_slot or gu.tip_main or ""

    local box = self.tipbox
    box.name:SetString(gu.name)
    box.desc:SetMultilineTruncatedString(desc, TIP_MAX_LINES, TIP_MAX_W, nil, false)

    local nw, nh = box.name:GetRegionSize()
    local dw, dh = box.desc:GetRegionSize()
    local bw = math.max(nw, dw) + TIP_PAD * 2
    local bh = nh + dh + TIP_PAD * 2 + 4
    box.bg:SetSize(bw, bh)
    box.name:SetPosition(0, bh / 2 - TIP_PAD - nh / 2)
    box.desc:SetPosition(0, -bh / 2 + TIP_PAD + dh / 2)

    local p = w:GetPosition()
    local x, y
    if kind == "cell" then
        x, y = p.x, p.y + size / 2 + bh / 2 + 8
    elseif kind == "slot" then
        x, y = p.x, p.y - size / 2 - bh / 2 - 8
    else
        x, y = p.x + size / 2 + bw / 2 + 10, p.y
    end
    -- không cho tràn ra ngoài khung
    local lim = PANEL_W / 2 - bw / 2 - 5
    x = math.max(-lim, math.min(lim, x))

    box:SetPosition(x, y)
    box:Show()
    box:MoveToFront()
end

function CosuSeaScreen:SetHint(str)
    self.hint:SetString(str)
end

function CosuSeaScreen:Select(i)
    if self.ids[i] == nil then return end
    self.selected = i
    self:Refresh()
end

function CosuSeaScreen:UpdateHint()
    local id = self.selected ~= nil and self.ids[self.selected] or nil
    local gu = id ~= nil and GU.LIST[id] or nil
    if gu ~= nil then
        self:SetHint(gu.name .. " - bấm ô Bản Mệnh Cổ hoặc một ô trang bị")
    else
        self:SetHint("Chọn một Cổ Trùng ở bên dưới")
    end
end

function CosuSeaScreen:Confirm(title, text, onyes)
    TheFrontEnd:PushScreen(PopupDialogScreen(title, text, {
        { text = "Đồng ý", cb = function() TheFrontEnd:PopScreen() onyes() end },
        { text = "Hủy", cb = function() TheFrontEnd:PopScreen() end },
    }))
end

-- Cửa sổ thông báo chỉ có nút Đóng
function CosuSeaScreen:Notice(title, text)
    TheFrontEnd:PushScreen(PopupDialogScreen(title, text, {
        { text = "Đóng", cb = function() TheFrontEnd:PopScreen() end },
    }))
end

-- place = 0: ô tròn Bản Mệnh Cổ; 1..9: các ô trang bị
function CosuSeaScreen:OnClickPlace(place)
    local rank = self.owner._cosu_rank ~= nil and self.owner._cosu_rank:value() or 0
    if place >= 1 and place > rank then
        self:SetHint("Ô này chưa mở, cần đạt Chuyển " .. place)
        return
    end

    local placed = place == 0 and self.main or (self.eq_slots[place] or 0)
    if placed ~= 0 then
        if self.selected ~= nil then
            self:SetHint("Ô này đã có cổ trùng, hãy gỡ trước")
            return
        end
        local gu = GU.LIST[placed]
        if gu ~= nil then
            local stone = GU.UNEQUIP_STONE ~= nil and (place == 0 and GU.UNEQUIP_STONE.main or GU.UNEQUIP_STONE.slot) or nil
            if stone == nil then
                self:Confirm(gu.name, "Bạn muốn gỡ cổ trùng này xuống?", function()
                    SendModRPCToServer(MOD_RPC["cosu"]["gu_unequip"], place)
                end)
                return
            end
            local count = stone.count or 1
            local sname = stone.name or stone.prefab
            local inv = self.owner.replica ~= nil and self.owner.replica.inventory or nil
            local has = inv ~= nil and inv:Has(stone.prefab, count)
            if has then
                self:Confirm(gu.name, "Gỡ cổ trùng này cần tiêu " .. count .. " " .. sname .. ".\nBạn có muốn gỡ không?", function()
                    SendModRPCToServer(MOD_RPC["cosu"]["gu_unequip"], place)
                end)
            else
                self:Notice(gu.name, "Không thể gỡ: bạn cần có " .. count .. " " .. sname .. " trong người.")
            end
        end
        return
    end

    local idx = self.selected
    local id = idx ~= nil and self.ids[idx] or nil
    local gu = id ~= nil and GU.LIST[id] or nil
    if gu == nil then
        self:SetHint("Hãy chọn một Cổ Trùng ở bên dưới trước")
        return
    end

    local text
    if place == 0 then
        text = "Bạn muốn chọn " .. gu.name .. " làm bản mệnh cổ?"
    else
        text = "Bạn muốn trang bị cổ trùng này?"
    end
    self:Confirm(gu.name, text, function()
        SendModRPCToServer(MOD_RPC["cosu"]["gu_equip"], place, idx)
        self.selected = nil
    end)
end

function CosuSeaScreen:Refresh()
    if self.owner == nil or not self.owner:IsValid() then return end

    -- danh sách chưa trang bị
    self.ids = {}
    local list_str = self.owner._cosu_gu ~= nil and self.owner._cosu_gu:value() or ""
    for n in string.gmatch(list_str, "%d+") do
        table.insert(self.ids, tonumber(n))
    end
    if list_str ~= self.last_list then
        -- danh sách đổi thì vị trí đang chọn không còn đúng nữa
        self.last_list = list_str
        self.selected = nil
    end

    -- ô trang bị: "main,s1,...,s9"
    local eq = {}
    local eq_str = self.owner._cosu_gu_eq ~= nil and self.owner._cosu_gu_eq:value() or ""
    for n in string.gmatch(eq_str, "%d+") do
        table.insert(eq, tonumber(n))
    end
    self.main = eq[1] or 0
    self.eq_slots = {}
    for i = 1, GU.SLOTS do
        self.eq_slots[i] = eq[i + 1] or 0
    end

    -- ô tròn
    SetIcon(self.main_slot, GU.LIST[self.main])

    -- 9 ô vuông
    local rank = self.owner._cosu_rank ~= nil and self.owner._cosu_rank:value() or 0
    for i, s in ipairs(self.slots) do
        local gu = GU.LIST[self.eq_slots[i]]
        SetIcon(s, gu)
        if s.fx ~= nil then
            if i <= rank or not RISE_ONLY_UNLOCKED then s.fx:Show() else s.fx:Hide() end
        end
        if i <= rank then
            s.image:SetTint(1, 1, 1, 1)
            s.label:SetString(gu == nil and tostring(i) or "")
        else
            s.image:SetTint(.4, .4, .4, 1)
            s.label:SetString("-")
        end
    end

    -- lưới cổ trùng
    for i, cell in ipairs(self.cells) do
        local gu = self.ids[i] ~= nil and GU.LIST[self.ids[i]] or nil
        SetIcon(cell, gu)
        if i == self.selected then
            cell.image:SetTint(1, 1, .6, 1)
        else
            cell.image:SetTint(1, 1, 1, 1)
        end
    end

    self:UpdateHint()
    self:UpdateTip()
end

function CosuSeaScreen:OnControl(control, down)
    if Screen.OnControl(self, control, down) then return true end
    if not down and (control == CONTROL_PAUSE or control == CONTROL_CANCEL) then
        TheFrontEnd:PopScreen()
        return true
    end
end

return CosuSeaScreen