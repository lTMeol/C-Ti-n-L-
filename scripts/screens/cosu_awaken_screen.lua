local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Text = require "widgets/text"
local COSU = require "cosu_tuning"
local AWAKEN = require "cosu_awaken_tuning"

local GREEN = { 0.45, 1, 0.45, 1 }
local RED = { 1, 0.4, 0.4, 1 }

local AwakenScreen = Class(Screen, function(self, owner)
    Screen._ctor(self, "CosuAwakenScreen")
    self.owner = owner
    self.t = 0

    -- nền tối phủ toàn màn hình
    self.black = self:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetVRegPoint(ANCHOR_MIDDLE)
    self.black:SetHRegPoint(ANCHOR_MIDDLE)
    self.black:SetVAnchor(ANCHOR_MIDDLE)
    self.black:SetHAnchor(ANCHOR_MIDDLE)
    self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
    self.black:SetTint(0, 0, 0, 0.6)

    self.proot = self:AddChild(Widget("ROOT"))
    self.proot:SetVAnchor(ANCHOR_MIDDLE)
    self.proot:SetHAnchor(ANCHOR_MIDDLE)
    self.proot:SetScaleMode(SCALEMODE_PROPORTIONAL)

    local border = self.proot:AddChild(Image("images/global.xml", "square.tex"))
    border:SetSize(508, 368)
    border:SetTint(0.75, 0.6, 0.2, 1)
    local panel = self.proot:AddChild(Image("images/global.xml", "square.tex"))
    panel:SetSize(500, 360)
    panel:SetTint(0.08, 0.07, 0.1, 0.97)

    local title = self.proot:AddChild(Text(UIFONT, 34, "Khai Mở Nguyên Hải Thần Thức"))
    title:SetPosition(0, 140)
    title:SetColour(0.95, 0.8, 0.35, 1)
    local hint = self.proot:AddChild(Text(UIFONT, 24, "Cần đủ các nguyên thạch sau:"))
    hint:SetPosition(0, 98)
    hint:SetColour(0.8, 0.8, 0.8, 1)

    self.rows = {}
    for i, req in ipairs(AWAKEN.REQUIRE) do
        local prefab = COSU.PREFAB[req.grade]
        local y = 45 - (i - 1) * 60
        local row = { prefab = prefab, need = req.count }

        row.icon = self.proot:AddChild(Image("images/inventoryimages/" .. prefab .. ".xml", prefab .. ".tex"))
        row.icon:SetSize(48, 48)
        row.icon:SetPosition(-180, y)

        row.name = self.proot:AddChild(Text(UIFONT, 26, COSU.NAME[req.grade] or prefab))
        row.name:SetRegionSize(230, 30)
        row.name:SetHAlign(ANCHOR_LEFT)
        row.name:SetPosition(-30, y)

        row.count = self.proot:AddChild(Text(UIFONT, 28, ""))
        row.count:SetRegionSize(120, 30)
        row.count:SetHAlign(ANCHOR_RIGHT)
        row.count:SetPosition(170, y)

        self.rows[i] = row
    end

    self.confirm = self.proot:AddChild(ImageButton())
    self.confirm:SetPosition(-100, -135)
    self.confirm:SetScale(0.75)
    self.confirm:SetText("Khai mở")
    self.confirm:SetFont(BUTTONFONT)
    self.confirm:SetTextSize(34)
    self.confirm:SetOnClick(function() self:OnConfirm() end)

    self.cancel = self.proot:AddChild(ImageButton())
    self.cancel:SetPosition(100, -135)
    self.cancel:SetScale(0.75)
    self.cancel:SetText("Đóng")
    self.cancel:SetFont(BUTTONFONT)
    self.cancel:SetTextSize(34)
    self.cancel:SetOnClick(function() self:Close() end)

    self:RefreshCounts()
    self:StartUpdating()
end)

function AwakenScreen:Close()
    TheFrontEnd:PopScreen(self)
end

function AwakenScreen:OnConfirm()
    if self.enough then
        SendModRPCToServer(GetModRPC("cosu", "awaken"))
    end
    self:Close()
end

function AwakenScreen:RefreshCounts()
    local inv = self.owner ~= nil and self.owner.replica.inventory or nil
    local all = true
    for _, row in ipairs(self.rows) do
        local have = 0
        if inv ~= nil then
            local _, found = inv:Has(row.prefab, row.need)
            have = found or 0
        end
        local ok = have >= row.need
        if not ok then all = false end
        row.count:SetString(have .. " / " .. row.need)
        local c = ok and GREEN or RED
        row.count:SetColour(c[1], c[2], c[3], c[4])
    end
    self.enough = all
    if all then self.confirm:Enable() else self.confirm:Disable() end
end

function AwakenScreen:OnUpdate(dt)
    self.t = self.t + dt
    if self.t < 0.2 then return end
    self.t = 0

    local p = self.owner
    if p == nil or not p:IsValid() then
        self:Close()
        return
    end
    -- đi xa NPC thì tự đóng
    local npc = FindEntity(p, AWAKEN.NEAR_DIST, nil, { "cosu_awakener" })
    if npc == nil then
        self:Close()
        return
    end
    self:RefreshCounts()
end

function AwakenScreen:OnControl(control, down)
    if AwakenScreen._base.OnControl(self, control, down) then return true end
    if not down and (control == CONTROL_PAUSE or control == CONTROL_CANCEL) then
        self:Close()
        return true
    end
end

return AwakenScreen