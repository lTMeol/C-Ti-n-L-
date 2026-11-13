local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local CosuSeaScreen = require "screens/cosu_sea_screen"
local CosuSkillBar = require "widgets/cosu_skill_bar"

local SAVE_KEY = "cosu_sea_button_pos"
local SHOW_KEY = "cosu_skill_visible"
local SKILL_OFFSET_X = 100 -- khoảng cách từ tâm nút Nguyên Hải tới nút kỹ năng đầu tiên (tăng nếu bị đè lên icon)
local DRAG_THRESHOLD = 8   -- pixel: giữ chuột phải và di chuyển quá mức này mới tính là kéo

local ICON_SIZE = 100 -- cỡ icon (720p, tự phóng theo độ phân giải). Ảnh cosu_badge có viền trong suốt nên phần nhìn thấy nhỏ hơn số này; muốn to nữa thì tăng, bé lại thì giảm
local ANIM_SIZE = 100 -- cỡ hiệu ứng (khung anim gốc 256px); muốn to/bé thì chỉnh số này
local LABEL = "Nguyên Hải Thần Thức"

-- Hệ số theo độ phân giải, giống cách các huy hiệu của game co giãn.
local function GetUIScale()
    local w, h = TheSim:GetScreenSize()
    return math.min(w / 1280, h / 720)
end

-- Nút mở Nguyên Hải Thần Thức: chỉ hiện khi đã mở khóa nguyên hải (chuyển >= 1).
-- Bấm chuột trái để mở bảng. Chuột phải (bấm nhanh) để ẩn/hiện hàng kỹ năng bên cạnh.
-- Giữ chuột phải và kéo để đi chỗ khác (nhớ vị trí).
local CosuSeaButton = Class(Widget, function(self, owner)
    Widget._ctor(self, "CosuSeaButton")
    self.owner = owner
    self.dragging = false

    -- góc dưới trái màn hình; vị trí tính bằng pixel để kéo bằng chuột cho dễ
    self:SetVAnchor(ANCHOR_BOTTOM)
    self:SetHAnchor(ANCHOR_LEFT)
    self:SetScaleMode(SCALEMODE_NONE)
    self:SetPosition(120, 220)

    -- phần hiển thị, co giãn theo độ phân giải
    self.content = self:AddChild(Widget("content"))
    self.content:SetScale(GetUIScale())

    -- hiệu ứng động (bank/build cosu_sea, anim idle) nằm dưới, chỉ để nhìn
    self.anim = self.content:AddChild(UIAnim())
    self.anim:GetAnimState():SetBank("cosu_sea")
    self.anim:GetAnimState():SetBuild("cosu_sea")
    self.anim:GetAnimState():PlayAnimation("idle", true)
    local as = ANIM_SIZE / 256
    self.anim:SetScale(as, as, as)

    -- nút bấm nằm đè lên, ảnh của nó được làm trong suốt (chỉ dùng làm vùng bấm)
    self.btn = self.content:AddChild(ImageButton("images/cosu_badge.xml", "cosu_badge.tex"))
    self.btn:SetOnClick(function() self:Open() end)
    self.btn.image:SetTint(1, 1, 1, 0)
    self.btn.image.SetTint = function() end -- chặn ImageButton đổi màu lại khi rê chuột

    -- Ảnh gốc rất lớn nên ForceImageSize không ăn: thu nhỏ bằng hệ số phóng
    -- (ICON_SIZE / cỡ ảnh gốc), đồng thời giữ nguyên cỡ đó khi rê chuột vào.
    local native = 256
    if self.btn.image ~= nil and self.btn.image.GetSize ~= nil then
        local w = self.btn.image:GetSize()
        if w ~= nil and w > 0 then native = w end
    end
    local s = ICON_SIZE / native
    self.btn:SetScale(s, s, s)
    if self.btn.SetNormalScale ~= nil then self.btn:SetNormalScale(s, s, s) end
    if self.btn.SetFocusScale ~= nil then self.btn:SetFocusScale(s, s, s) end

    -- chữ cố định ngay dưới icon, chỉ hiện khi rê chuột vào
    self.label = self.content:AddChild(Text(UIFONT, 20, LABEL))
    self.label:SetPosition(0, -(ICON_SIZE * 0.25 + 14)) -- ảnh có viền trong suốt nên chữ đặt sát phần nhìn thấy; chữ còn xa thì giảm 0.25 hoặc 14
    self.label:SetColour(1, 1, 1, 1)
    self.label:Hide()

    local base_gain, base_lose = self.btn.OnGainFocus, self.btn.OnLoseFocus
    self.btn.OnGainFocus = function(btn)
        base_gain(btn)
        self.label:Show()
    end
    self.btn.OnLoseFocus = function(btn)
        base_lose(btn)
        if not self.dragging then self.label:Hide() end
    end

    -- giữ chuột phải để kéo
    local base_control = self.btn.OnControl
    self.btn.OnControl = function(btn, control, down)
        if control == CONTROL_SECONDARY then
            if down then
                self.rdown = true
                self.moved = false
                self.rstart = TheInput:GetScreenPosition()
            end
            return true
        end
        return base_control(btn, control, down)
    end

    -- nạp vị trí đã lưu
    TheSim:GetPersistentString(SAVE_KEY, function(ok, str)
        if ok and str ~= nil then
            local x, y = string.match(str, "^(-?%d+),(-?%d+)$")
            if x ~= nil then self:SetPosition(tonumber(x), tonumber(y)) end
        end
    end)

    -- hàng nút kỹ năng cổ trùng, nằm bên phải nút
    self.skill_bar = self.content:AddChild(CosuSkillBar(owner))
    self.skill_bar:SetPosition(SKILL_OFFSET_X, 0, 0)
    self.skills_shown = true
    TheSim:GetPersistentString(SHOW_KEY, function(ok, str)
        if ok and str == "0" then
            self.skills_shown = false
            self.skill_bar:SetSkillsShown(false)
        end
    end)

    self.inst:ListenForEvent("cosu_rankdirty", function() self:Refresh() end, owner)
    self:Refresh()
    self:StartUpdating()
end)

function CosuSeaButton:Refresh()
    local rank = self.owner._cosu_rank ~= nil and self.owner._cosu_rank:value() or 0
    if rank >= 1 then self:Show() else self:Hide() end
end

function CosuSeaButton:Open()
    if self.owner == nil or not self.owner:IsValid() then return end
    local top = TheFrontEnd:GetActiveScreen()
    if top ~= nil and top.name == "CosuSeaScreen" then return end
    TheFrontEnd:PushScreen(CosuSeaScreen(self.owner))
end

function CosuSeaButton:OnUpdate(dt)
    self.content:SetScale(GetUIScale())

    if not self.rdown then return end

    if not TheInput:IsControlPressed(CONTROL_SECONDARY) then
        -- thả chuột phải (kể cả khi con trỏ đã rời nút)
        self.rdown = false
        self.dragging = false
        if not self.btn.focus then self.label:Hide() end
        if self.moved then
            -- vừa kéo: lưu vị trí
            local pos = self:GetPosition()
            TheSim:SetPersistentString(SAVE_KEY,
                string.format("%d,%d", math.floor(pos.x), math.floor(pos.y)), false)
        else
            -- chỉ bấm: ẩn/hiện hàng kỹ năng
            self.skills_shown = not self.skills_shown
            self.skill_bar:SetSkillsShown(self.skills_shown)
            TheSim:SetPersistentString(SHOW_KEY, self.skills_shown and "1" or "0", false)
        end
        return
    end

    local mouse = TheInput:GetScreenPosition()
    if not self.moved and self.rstart ~= nil then
        local dx, dy = mouse.x - self.rstart.x, mouse.y - self.rstart.y
        if dx * dx + dy * dy >= DRAG_THRESHOLD * DRAG_THRESHOLD then
            self.moved = true
            self.dragging = true
        end
    end
    if self.moved then
        self:SetPosition(mouse.x, mouse.y)
    end
end

return CosuSeaButton