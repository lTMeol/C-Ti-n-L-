-- Huy hiệu Nguyên Khí cạnh 3 chỉ số của game. Chỉ dùng Image + Text nên không phụ thuộc vào Badge của game.
-- Rê chuột lên huy hiệu, giữ chuột phải rồi kéo để dời chỗ; vị trí được lưu lại cho lần sau.
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")

local ATLAS = "images/cosu_nguyenkhi.xml"
local TEX = "cosu_nguyenkhi.tex"
local POS_FILE = "cosu_nguyenkhi_pos"

local Badge = Class(Widget, function(self, owner)
    Widget._ctor(self, "CosuNguyenKhiBadge")
    self.owner = owner

    self.icon = self:AddChild(Image(ATLAS, TEX))
    self.icon:SetScale(0.62) -- ảnh gốc 128px -> ~80px, đúng cỡ huy hiệu của game

    self.num = self:AddChild(Text(NUMBERFONT, 28))
    self.num:SetPosition(3, -40)
    self.num:SetColour(0.55, 1, 0.95, 1)

    self.hover = self:AddChild(Text(UIFONT, 28))
    self.hover:SetPosition(0, -62)
    self.hover:Hide()

    self.pct = 1
    self.dragging = false
    self:Refresh()

    self.inst:ListenForEvent("cosu_qidirty", function() self:Refresh() end, owner)
    self.inst:ListenForEvent("cosu_qimaxdirty", function() self:Refresh() end, owner)
end)

-- Gọi từ modmain: đặt vị trí mặc định, rồi nạp vị trí đã lưu (nếu có)
function Badge:SetDefaultPos(x, y)
    self:SetPosition(x, y)
    TheSim:GetPersistentString(POS_FILE, function(ok, str)
        if not ok or str == nil or not self.inst:IsValid() then return end
        local sx, sy = str:match("^(%-?[%d%.]+),(%-?[%d%.]+)$")
        sx, sy = tonumber(sx), tonumber(sy)
        if sx ~= nil and sy ~= nil then
            self:SetPosition(sx, sy)
        end
    end)
end

function Badge:StartDrag()
    local m = TheInput:GetScreenPosition()
    local pos = self:GetPosition()
    self.mx, self.my = m.x, m.y
    self.sx, self.sy = pos.x, pos.y
    self.dragging = true
    self:StartUpdating()
end

function Badge:StopDrag()
    if not self.dragging then return end
    self.dragging = false
    self:StopUpdating()
    local pos = self:GetPosition()
    TheSim:SetPersistentString(POS_FILE, string.format("%.1f,%.1f", pos.x, pos.y), false)
end

-- Widget đang được rê chuột lên thì nhận được chuột phải ở đây
function Badge:OnControl(control, down)
    if control == CONTROL_SECONDARY then
        if down then
            if not self.dragging then self:StartDrag() end
            return true -- nuốt cú bấm, khỏi bị tính là hành động ngoài thế giới
        elseif self.dragging then
            self:StopDrag()
            return true
        end
    end
    return Badge._base.OnControl(self, control, down)
end

function Badge:OnUpdate(dt)
    if not self.dragging then return end
    -- thả chuột phải (kể cả khi con trỏ đã trượt ra khỏi huy hiệu) thì dừng kéo
    if not TheInput:IsMouseDown(MOUSEBUTTON_RIGHT) then
        self:StopDrag()
        return
    end
    local m = TheInput:GetScreenPosition()
    local ps = self:GetParentPixelScale()
    self:SetPosition(self.sx + (m.x - self.mx) / ps, self.sy + (m.y - self.my) / ps)
end

-- Số pixel màn hình ứng với 1 đơn vị toạ độ của widget cha.
-- Không dùng Widget:GetWorldScale() vì bản game này gọi UITransform:GetWorldScale() bị nil -> crash.
-- Tự tính: tỉ lệ khung hình UI (SCALEMODE_PROPORTIONAL, quy chiếu 1280x720) x tích các scale từ cha lên gốc.
function Badge:GetParentPixelScale()
    local w, h = TheSim:GetScreenSize()
    local ps = math.min(w / 1280, h / 720)
    local p = self.parent
    while p ~= nil do
        if p.GetScale ~= nil then
            local sc = p:GetScale()
            if sc ~= nil and sc.x ~= nil and sc.x ~= 0 then
                ps = ps * sc.x
            end
        end
        p = p.parent
    end
    if ps == 0 then ps = 1 end
    return ps
end

function Badge:Refresh()
    local o = self.owner
    if o == nil or o._cosu_qi == nil then return end
    local cur, max = o._cosu_qi:value(), math.max(1, o._cosu_qimax:value())
    self.pct = cur / max
    self.num:SetString(tostring(cur))
    -- càng cạn thì icon càng mờ
    self.icon:SetTint(1, 1, 1, 0.35 + 0.65 * math.min(1, self.pct))
    self.hover:SetString("Nguyên khí")
end

function Badge:OnGainFocus()
    Badge._base.OnGainFocus(self)
    self.hover:Show()
end

function Badge:OnLoseFocus()
    Badge._base.OnLoseFocus(self)
    self.hover:Hide()
end

return Badge