local G = GLOBAL
local COSU = G.require("cosu_tuning")
local PILL = G.require("cosu_pill_tuning")
local AWAKEN = G.require("cosu_awaken_tuning")
local GU = G.require("cosu_gu_tuning")
local ELEM = G.require("cosu_element_tuning")
local ELEMC = G.require("cosu_element_combat")
local STATS = G.require("cosu_stats")
local DMGFX = G.require("cosu_damage_fx")
local AwakenScreen = G.require("screens/cosu_awaken_screen")
local FortuneScreen = G.require("screens/cosu_fortune_screen")
local ShopScreen = G.require("screens/cosu_shop_screen")
local FURN = G.require("cosu_furnace_tuning")

PrefabFiles = { "cosu_stones", "cosu_pills", "cosu_npc", "cosu_cave", "cosu_gu_thientinh", "cosu_gu_light", "cosu_linhcan", "cosu_gu_thientinh_vuong", "cosu_gu_star", "cosu_gu_tichlich", "cosu_gu_uloi", "cosu_gu_anthach", "cosu_gu_thachbi", "cosu_giangloi_fx", "cosu_lo_luyen_dan", "cosu_deco", "cosu_linhthach", "cosu_house" }

Assets = {
    Asset("ATLAS", "images/cosu_ovuong.xml"),
    Asset("IMAGE", "images/cosu_ovuong.tex"),
    Asset("ATLAS", "images/cosu_otron.xml"),
    Asset("IMAGE", "images/cosu_otron.tex"),
    Asset("ATLAS", "images/cosu_badge.xml"),
    Asset("IMAGE", "images/cosu_badge.tex"),
    Asset("ATLAS", "images/cosu_nguyenkhi.xml"), 
    Asset("IMAGE", "images/cosu_nguyenkhi.tex"),
    Asset("ATLAS", "images/cosu_glow.xml"),
    Asset("IMAGE", "images/cosu_glow.tex"),
    Asset("ANIM", "anim/cosu_sea.zip"),
    Asset("ANIM", "anim/cosu_house.zip"),        -- Thạch Quán (ngôi nhà trên đảo)
    Asset("ATLAS", "images/cosu_shop.xml"),      -- bảng + đèn lồng Thạch Quán
    Asset("IMAGE", "images/cosu_shop.tex"),
    Asset("ANIM", "anim/cosu_ink.zip"),
    Asset("ANIM", "anim/cosu_slot_orbit.zip"), 
    Asset("ANIM", "anim/cosu_slot_rise.zip"), 
    Asset("ATLAS", "images/cosu_fortune.xml"),
    Asset("IMAGE", "images/cosu_fortune.tex"),
    Asset("ANIM", "anim/cosu_linhthach.zip"),
    Asset("ATLAS", "images/inventoryimages/cosu_linhthach.xml"),
    Asset("IMAGE", "images/inventoryimages/cosu_linhthach.tex"),
    Asset("ATLAS", "images/cosu_stones_ui.xml"), -- ảnh đá đổ thạch trong Thạch Quán
    Asset("IMAGE", "images/cosu_stones_ui.tex"),
    Asset("ATLAS", "images/cosu_npc.xml"),
    Asset("IMAGE", "images/cosu_npc.tex"),
}
-- giao diện bảng nhân vật (cosu_charinfo): nền, 2 icon tab, icon tư chất
for _, n in ipairs({ "fabaobg_1", "PlayInfo_shuxing", "PlayInfo_gerenjingli", "cosu_trait_icons" }) do
    table.insert(Assets, Asset("ATLAS", "images/" .. n .. ".xml"))
    table.insert(Assets, Asset("IMAGE", "images/" .. n .. ".tex"))
end

-- ảnh nền màn hình loading: phải PRELOAD vì màn hình loading hiện trước khi Assets thường được nạp
PreloadAssets = {
    Asset("ATLAS", "images/cosu_loading.xml"),
    Asset("IMAGE", "images/cosu_loading.tex"),
}
ReloadPreloadAssets()

-- Màn hình loading của game (bản mới) dùng self.active_image (Image nằm trong root_classic) làm ảnh nền.
-- Cách chắc nhất là ĐỔI TEXTURE của chính ảnh đó (không đụng thứ tự lớp, vẫn mờ dần theo game).
-- Game chọn lại ảnh mỗi lần SetEnabled nên phải đổi lại sau mỗi lần gọi SetEnabled.
local COSU_LOAD_ATLAS = "images/cosu_loading.xml"
local COSU_LOAD_TEX = "login7.0.tex" -- tên element trong cosu_loading.xml

local function CosuApplyLoadingImage(self)
    local ok, err = pcall(function()
        local img = self.active_image
        if img ~= nil then
            img:SetTexture(COSU_LOAD_ATLAS, COSU_LOAD_TEX)
            img:SetSize(G.RESOLUTION_X, G.RESOLUTION_Y)
            if not self._cosu_logged then
                self._cosu_logged = true
                print("[cosu] da doi texture active_image")
            end
        elseif self._cosu_overlay == nil then
            -- không có active_image: phủ thêm 1 ảnh lên trên (không đụng root_classic)
            print("[cosu] khong co active_image, dung anh phu")
            local Widget = G.require("widgets/widget")
            local Image = G.require("widgets/image")
            local root = self:AddChild(Widget("cosu_loading_bg"))
            root:SetVAnchor(G.ANCHOR_MIDDLE)
            root:SetHAnchor(G.ANCHOR_MIDDLE)
            root:SetScaleMode(G.SCALEMODE_FILLSCREEN)
            local ov = root:AddChild(Image(COSU_LOAD_ATLAS, COSU_LOAD_TEX))
            ov:SetSize(G.RESOLUTION_X, G.RESOLUTION_Y)
            self._cosu_overlay = root
            if self.loading_widget ~= nil then self.loading_widget:MoveToFront() end
        end
    end)
    if not ok then print("[cosu] LOI loading bg:", err) end
end

local function HookCosuLoading(self, from)
    if self == nil or self._cosu_hooked then return end
    self._cosu_hooked = true
    print("[cosu] hook loadingwidget, nguon:", from,
        "| active_image:", tostring(self.active_image),
        "| root_classic:", tostring(self.root_classic),
        "| bg:", tostring(self.bg))
    local old_set = self.SetEnabled
    if old_set ~= nil then
        self.SetEnabled = function(s, ...)
            local r = old_set(s, ...)
            CosuApplyLoadingImage(s)
            return r
        end
    else
        print("[cosu] khong tim thay SetEnabled")
    end
    CosuApplyLoadingImage(self)
end

-- Cách 1: widget được tạo SAU khi mod nạp
AddClassPostConstruct("widgets/loadingwidget", function(self)
    HookCosuLoading(self, "postconstruct")
end)

-- Cách 2: widget đã được tạo TRƯỚC khi mod nạp -> móc thẳng vào widget có sẵn
if G.TheFrontEnd ~= nil then
    print("[cosu] TheFrontEnd có sẵn lúc nạp mod")
    for k, v in pairs(G.TheFrontEnd) do
        if type(k) == "string" and string.find(string.lower(k), "load") then
            print("[cosu] TheFrontEnd." .. k .. " =", tostring(v))
        end
    end
    HookCosuLoading(G.TheFrontEnd.loadingwidget, "frontend co san")
else
    print("[cosu] TheFrontEnd chưa có lúc nạp mod")
end
for _, grade in ipairs(COSU.GRADES) do
    local n = COSU.PREFAB[grade]
    table.insert(Assets, Asset("ATLAS", "images/inventoryimages/" .. n .. ".xml"))
    table.insert(Assets, Asset("IMAGE", "images/inventoryimages/" .. n .. ".tex"))
    if G.RegisterInventoryItemAtlas ~= nil then
        G.RegisterInventoryItemAtlas("images/inventoryimages/" .. n .. ".xml", n .. ".tex")
    end
end

-- icon túi đồ của đan đột phá (chung 1 atlas)
local PILL_ATLAS = "images/inventoryimages/cosu_pills.xml"
table.insert(Assets, Asset("ATLAS", PILL_ATLAS))
table.insert(Assets, Asset("IMAGE", "images/inventoryimages/cosu_pills.tex"))
if G.RegisterInventoryItemAtlas ~= nil then
    for n = 1, PILL.MAX_PILL do
        G.RegisterInventoryItemAtlas(PILL_ATLAS, PILL.PrefabName(n) .. ".tex")
    end
end

-- icon cổ trùng (bảng Nguyên Hải cần nạp sẵn atlas)
for _, gu in ipairs(GU.LIST) do
    table.insert(Assets, Asset("ATLAS", gu.atlas))
    table.insert(Assets, Asset("IMAGE", (gu.atlas:gsub("%.xml$", ".tex")))) -- tex theo atlas (Thạch Bì Cổ dùng chung với Ẩn Thạch Cổ)
    if G.RegisterInventoryItemAtlas ~= nil then
        G.RegisterInventoryItemAtlas(gu.atlas, gu.image)
    end
end

-- icon Linh Căn và Mảnh Vỡ Nguyên Tố (chung 1 atlas)
table.insert(Assets, Asset("ATLAS", ELEM.ATLAS))
table.insert(Assets, Asset("IMAGE", ELEM.TEX))
if G.RegisterInventoryItemAtlas ~= nil then
    for _, e in ipairs(ELEM.LIST) do
        G.RegisterInventoryItemAtlas(ELEM.ATLAS, e.root_image)
        G.RegisterInventoryItemAtlas(ELEM.ATLAS, e.shard_image)
    end
end

-- icon công trình Cổ Động (hiện trong tab chế tạo)
table.insert(Assets, Asset("ATLAS", "images/inventoryimages/cosu_cave.xml"))
table.insert(Assets, Asset("IMAGE", "images/inventoryimages/cosu_cave.tex"))
if G.RegisterInventoryItemAtlas ~= nil then
    G.RegisterInventoryItemAtlas("images/inventoryimages/cosu_cave.xml", "cosu_cave.tex")
end

-- icon công trình Lò Luyện Đan (hiện trong tab Luyện Chế)
table.insert(Assets, Asset("ATLAS", "images/inventoryimages/cosu_lo_luyen_dan.xml"))
table.insert(Assets, Asset("IMAGE", "images/inventoryimages/cosu_lo_luyen_dan.tex"))
if G.RegisterInventoryItemAtlas ~= nil then
    G.RegisterInventoryItemAtlas("images/inventoryimages/cosu_lo_luyen_dan.xml", "cosu_lo_luyen_dan.tex")
end

----------------------------------------------------------------- State vung gậy riêng cho kỹ năng cổ trùng
-- State "castspell" của game bắt buộc phải có gậy phép (staff) lấy từ BufferedAction, mà kỹ năng cổ trùng
-- kích hoạt qua RPC nên không có gậy -> crash "attempt to index local 'staff'".
-- State này chỉ phát hoạt ảnh vung gậy, không cần gậy.
AddStategraphState("wilson", G.State{
    name = "cosu_cast",
    tags = { "doing", "busy", "canrotate" },
    onenter = function(inst)
        if inst.components.locomotor ~= nil then inst.components.locomotor:Stop() end
        inst.AnimState:PlayAnimation("staff_pre")
        inst.AnimState:PushAnimation("staff", false)
        inst.sg:SetTimeout(3) -- phòng hờ: không bao giờ kẹt trong state này
    end,
    events = {
        G.EventHandler("animqueueover", function(inst)
            if inst.AnimState:AnimDone() then inst.sg:GoToState("idle") end
        end),
    },
    ontimeout = function(inst) inst.sg:GoToState("idle") end,
})

----------------------------------------------------------------- Tên & mô tả
local descs = {
    low = "Viên đá chứa chút chân nguyên ít ỏi.",
    mid = "Chân nguyên trong viên đá này đã đậm hơn.",
    high = "Một viên nguyên thạch đáng giá.",
    extreme = "Chân nguyên cô đặc, hiếm thấy.",
    supreme = "Báu vật mà cổ sư nào cũng thèm khát.",
}
for _, grade in ipairs(COSU.GRADES) do
    local up = string.upper(COSU.PREFAB[grade])
    G.STRINGS.NAMES[up] = COSU.NAME[grade]
    G.STRINGS.CHARACTERS.GENERIC.DESCRIBE[up] = descs[grade]
end
G.STRINGS.RECIPE_DESC.COSU_STONE_SUPREME = "Ghép " .. COSU.COMBINE_COUNT .. " Nguyên Thạch Cực Phẩm."

----------------------------------------------------------------- Tech tree của Cổ Động
local TechTree = G.require("techtree")
table.insert(TechTree.AVAILABLE_TECH, "COSU_CAVE")
TechTree.Create = function(t)
    t = t or {}
    for _, v in ipairs(TechTree.AVAILABLE_TECH) do
        t[v] = t[v] or 0
    end
    return t
end
for _, v in pairs(G.TECH) do
    v.COSU_CAVE = 0
end
-- Máy chế tạo có sẵn của game (Máy Khoa Học, Máy Giả Kim...) cũng phải có khóa COSU_CAVE = 0.
-- Thiếu bước này game thấy "máy này không có cấp COSU_CAVE" và coi như chưa đủ cấp,
-- nên công thức của mod không hiện ra khi đứng gần Máy Khoa Học cấp 2.
for _, trees in pairs(G.TUNING.PROTOTYPER_TREES) do
    trees.COSU_CAVE = 0
end
G.TECH.COSU_CAVE_ONE = { COSU_CAVE = 1 }
G.TUNING.PROTOTYPER_TREES.COSU_CAVE = TechTree.Create({ COSU_CAVE = 1 })
for _, recipe in pairs(G.AllRecipes) do
    if recipe.level.COSU_CAVE == nil then
        recipe.level.COSU_CAVE = 0
    end
end
G.STRINGS.UI.CRAFTING.NEEDSCOSU_CAVE_ONE = "Cần đứng gần Cổ Động để chế tạo!"

----------------------------------------------------------------- Tab chế tạo "Luyện Chế" và "Cổ Trùng"
-- "Luyện Chế": nguyên liệu (Linh Căn, Nguyên Thạch tuyệt phẩm...), icon là Cổ Động.
-- "Cổ Trùng": chỉ chứa công thức chế các loại cổ trùng, icon tạm dùng Thiên Tinh Huỳnh Cổ.
-- Công thức nào muốn nằm trong tab nào thì thêm tên filter đó vào danh sách filter của nó.
AddRecipeFilter({
    name = "COSU_LUYENCHE",
    atlas = "images/inventoryimages/cosu_cave.xml",
    image = "cosu_cave.tex",
})
G.STRINGS.UI.CRAFTING_FILTERS.COSU_LUYENCHE = "Luyện Chế"

AddRecipeFilter({
    name = "COSU_COTRUNG",
    atlas = "images/inventoryimages/cosu_gu_thientinh.xml",
    image = "cosu_gu_thientinh.tex",
})
G.STRINGS.UI.CRAFTING_FILTERS.COSU_COTRUNG = "Cổ Trùng"

----------------------------------------------------------------- Thiên Tinh Huỳnh Cổ
G.STRINGS.NAMES.COSU_GU_THIENTINH = "Thiên Tinh Huỳnh Cổ"
G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.COSU_GU_THIENTINH = "Con cổ phát sáng như sao trời."
G.STRINGS.RECIPE_DESC.COSU_GU_THIENTINH = "Luyện đom đóm và sâu phát sáng thành một con cổ."

AddRecipe2("cosu_gu_thientinh",
    {
        G.Ingredient("fireflies", 10),
        G.Ingredient("wormlight", 3),
        G.Ingredient(COSU.PREFAB.mid, 1),
    },
    G.TECH.COSU_CAVE_ONE,
    {
        atlas = "images/inventoryimages/cosu_gu_thientinh.xml",
        image = "cosu_gu_thientinh.tex",
    },
    { "COSU_COTRUNG" })

----------------------------------------------------------------- Thiên Tinh Huỳnh Vương Cổ
-- Chế từ Thiên Tinh Huỳnh Cổ + Quang Linh Căn + Nguyên Thạch Thượng Phẩm.
-- Kỹ năng chủ động (chuột phải khi đã trang bị) nằm trong cosu_gu_bag.lua, số liệu trong cosu_gu_tuning.lua.
G.STRINGS.NAMES.COSU_GU_THIENTINH_VUONG = "Thiên Tinh Huỳnh Vương Cổ"
G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.COSU_GU_THIENTINH_VUONG = "Vua của các loài cổ phát sáng."
G.STRINGS.RECIPE_DESC.COSU_GU_THIENTINH_VUONG = "Dung hợp Quang Linh Căn vào Thiên Tinh Huỳnh Cổ."
G.STRINGS.NAMES.COSU_GU_STAR = "Ngôi Sao"

do
    local quang
    for _, e in ipairs(ELEM.LIST) do
        if e.id == "quang" then quang = e end
    end
    local high = COSU.PREFAB.high
    AddRecipe2("cosu_gu_thientinh_vuong",
        {
            G.Ingredient("cosu_gu_thientinh", 1, "images/inventoryimages/cosu_gu_thientinh.xml"),
            G.Ingredient(quang.root, 1, quang.root_atlas),
            G.Ingredient(high, 1, "images/inventoryimages/" .. high .. ".xml"),
        },
        G.TECH.COSU_CAVE_ONE,
        {
            atlas = "images/inventoryimages/cosu_gu_thientinh_vuong.xml",
            image = "cosu_gu_thientinh_vuong.tex",
        },
        { "COSU_COTRUNG" })
end

----------------------------------------------------------------- Tích Lịch Cổ
-- Nội tại + kỹ năng Thiên Lôi nằm trong cosu_gu_bag.lua, số liệu trong cosu_gu_tuning.lua (GU.TICHLICH).
G.STRINGS.NAMES.COSU_GU_TICHLICH = "Tích Lịch Cổ"
G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.COSU_GU_TICHLICH = "Con cổ mang sấm sét trong người."
G.STRINGS.RECIPE_DESC.COSU_GU_TICHLICH = "Luyện mảnh vỡ nguyên tố Lôi cùng sừng và sữa dê điện thành một con cổ."

do
    local loi
    for _, e in ipairs(ELEM.LIST) do
        if e.id == "loi" then loi = e end
    end
    local mid = COSU.PREFAB.mid
    AddRecipe2("cosu_gu_tichlich",
        {
            G.Ingredient(loi.shard, 10, loi.shard_atlas),
            G.Ingredient("lightninggoathorn", 2),
            G.Ingredient("goatmilk", 1),
            G.Ingredient(mid, 1, "images/inventoryimages/" .. mid .. ".xml"),
        },
        G.TECH.COSU_CAVE_ONE,
        {
            atlas = "images/inventoryimages/cosu_gu_tichlich.xml",
            image = "cosu_gu_tichlich.tex",
        },
        { "COSU_COTRUNG" })
end

----------------------------------------------------------------- U Lôi Huyễn Điệp Cổ
-- Nội tại (miễn nhiễm điện, tăng tốc) + kỹ năng Lôi Hóa / Giáng Lôi nằm trong cosu_gu_bag.lua, số liệu trong GU.ULOI.
G.STRINGS.NAMES.COSU_GU_ULOI = "U Lôi Huyễn Điệp Cổ"
G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.COSU_GU_ULOI = "Con bướm tím mang theo sấm sét."
G.STRINGS.RECIPE_DESC.COSU_GU_ULOI = "Luyện sừng dê, sừng cá voi và Lôi Linh Căn thành một con bướm lôi."

do
    local loi
    for _, e in ipairs(ELEM.LIST) do
        if e.id == "loi" then loi = e end
    end
    local high, extreme = COSU.PREFAB.high, COSU.PREFAB.extreme
    AddRecipe2("cosu_gu_uloi",
        {
            G.Ingredient("lightninggoathorn", 10),
            G.Ingredient(loi.root, 2, loi.root_atlas),
            G.Ingredient("gnarwail_horn", 2),
            G.Ingredient(high, 5, "images/inventoryimages/" .. high .. ".xml"),
            G.Ingredient(extreme, 1, "images/inventoryimages/" .. extreme .. ".xml"),
        },
        G.TECH.COSU_CAVE_ONE,
        {
            atlas = "images/inventoryimages/cosu_gu_uloi.xml",
            image = "cosu_gu_uloi.tex",
        },
        { "COSU_COTRUNG" })
end

----------------------------------------------------------------- Ẩn Thạch Cổ
-- Chỉ ra từ Thạch Quán (đổ thạch), không có công thức. Kỹ năng Ẩn Thân nằm trong cosu_gu_bag.lua, số liệu GU.ANTHACH.
G.STRINGS.NAMES.COSU_GU_ANTHACH = "Ẩn Thạch Cổ"
G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.COSU_GU_ANTHACH = "Con cổ giả làm hòn đá."
-- để màn hình Thạch Quán (GetInventoryItemAtlas) tìm đúng ảnh khi hiện kết quả
G.RegisterInventoryItemAtlas("images/inventoryimages/cosu_gu_anthach.xml", "cosu_gu_anthach.tex")

----------------------------------------------------------------- Thạch Bì Cổ
-- Chỉ ra từ Thạch Quán, không có công thức. Số liệu GU.THACHBI (cosu_gu_tuning.lua). Icon dùng chung atlas với Ẩn Thạch Cổ.
G.STRINGS.NAMES.COSU_GU_THACHBI = "Thạch Bì Cổ"
G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.COSU_GU_THACHBI = "Con cổ khoác lớp da đá dày nặng."

----------------------------------------------------------------- Công thức ghép tuyệt phẩm
-- Chuỗi ghép nguyên thạch (tất cả phải đứng gần Cổ Động):
-- 15 hạ -> 1 trung, 10 trung -> 1 thượng, 5 thượng -> 1 cực, (COMBINE_COUNT) cực -> 1 tuyệt.
do
    local CHAIN = {
        { from = "low",  to = "mid",     count = 15 },
        { from = "mid",  to = "high",    count = 10 },
        { from = "high", to = "extreme", count = 5  },
    }
    for _, c in ipairs(CHAIN) do
        local src, dst = COSU.PREFAB[c.from], COSU.PREFAB[c.to]
        G.STRINGS.RECIPE_DESC[string.upper(dst)] = "Ghép " .. c.count .. " " .. COSU.NAME[c.from] .. " thành 1 " .. COSU.NAME[c.to] .. "."
        AddRecipe2(dst,
            { G.Ingredient(src, c.count, "images/inventoryimages/" .. src .. ".xml") },
            G.TECH.COSU_CAVE_ONE, -- phải đứng gần Cổ Động
            { atlas = "images/inventoryimages/" .. dst .. ".xml", image = dst .. ".tex" },
            { "COSU_LUYENCHE" })
    end
end

AddRecipe2("cosu_stone_supreme",
    { G.Ingredient(COSU.PREFAB.extreme, COSU.COMBINE_COUNT) },
    G.TECH.COSU_CAVE_ONE, -- phải đứng gần Cổ Động
    { atlas = "images/inventoryimages/cosu_stone_supreme.xml", image = "cosu_stone_supreme.tex" },
    { "COSU_LUYENCHE" })

----------------------------------------------------------------- Linh Căn (8 hệ) + Mảnh Vỡ Nguyên Tố
-- Chế trong tab Luyện Chế: SHARDS_PER_ROOT mảnh vỡ cùng hệ -> 1 linh căn.
for _, e in ipairs(ELEM.LIST) do
    local rup, sup = string.upper(e.root), string.upper(e.shard)
    G.STRINGS.NAMES[rup] = e.root_name
    G.STRINGS.NAMES[sup] = e.shard_name
    G.STRINGS.CHARACTERS.GENERIC.DESCRIBE[rup] = "Căn cốt thuộc tính " .. e.label .. ", cổ sư nào cũng cần."
    G.STRINGS.CHARACTERS.GENERIC.DESCRIBE[sup] = "Một mảnh vỡ chứa lực nguyên tố " .. e.label .. "."
    G.STRINGS.RECIPE_DESC[rup] = "Ghép " .. ELEM.SHARDS_PER_ROOT .. " " .. e.shard_name .. " thành " .. e.root_name .. "."

    AddRecipe2(e.root,
        { G.Ingredient(e.shard, ELEM.SHARDS_PER_ROOT, e.shard_atlas) },
        G.TECH.COSU_CAVE_ONE, -- phải đứng gần Cổ Động
        { atlas = e.root_atlas, image = e.root_image },
        { "COSU_LUYENCHE" })
end

----------------------------------------------------------------- Cổ Động (công trình)
G.STRINGS.NAMES.COSU_CAVE = "Cổ Động"
G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.COSU_CAVE = "Một hang động ẩn chứa linh khí của cổ sư."
G.STRINGS.RECIPE_DESC.COSU_CAVE = "Một hang động tu luyện cho cổ sư."

AddRecipe2("cosu_cave",
    {
        G.Ingredient("boards", 10),
        G.Ingredient("goldnugget", 10),
        G.Ingredient("cutstone", 10),
        G.Ingredient("rope", 10),
        G.Ingredient(COSU.PREFAB.low, 50),
    },
    G.TECH.SCIENCE_TWO,
    {
        placer = "cosu_cave_placer",
        min_spacing = 3,
        atlas = "images/inventoryimages/cosu_cave.xml",
        image = "cosu_cave.tex",
    },
    { "STRUCTURES" })

----------------------------------------------------------------- Lò Luyện Đan
-- Số liệu (nguyên liệu, thời gian, đan ra...) nằm trong scripts/cosu_furnace_tuning.lua,
-- hành vi nằm trong scripts/prefabs/cosu_lo_luyen_dan.lua.
G.STRINGS.NAMES.COSU_LO_LUYEN_DAN = "Lò Luyện Đan"
G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.COSU_LO_LUYEN_DAN = {
    GENERIC = "Cái lò này luyện được đan dược.",
    BREWING = "Lửa đang cháy, đan sắp thành.",
}
G.STRINGS.RECIPE_DESC.COSU_LO_LUYEN_DAN = "Lò dùng để luyện đan đột phá."

-- Giao diện 4 ô dọc như nồi nấu ăn + nút "Luyện chế"
do
    local containers = G.require("containers")
    local V = G.Vector3
    local P = {
        widget = {
            slotpos = {
                V(0, 64 + 32 + 8 + 4, 0),
                V(0, 32 + 4, 0),
                V(0, -(32 + 4), 0),
                V(0, -(64 + 32 + 8 + 4), 0),
            },
            animbank = "ui_cookpot_1x4",
            animbuild = "ui_cookpot_1x4",
            pos = V(200, 0, 0),
            side_align_tip = 100,
            buttoninfo = {
                text = "Luyện chế",
                position = V(0, -165, 0),
            },
        },
        acceptsstacks = true,
        type = "cooker",
    }
    P.itemtestfn = function(container, item, slot)
        return FURN.ACCEPT[item.prefab] == true
    end
    -- nút chỉ sáng khi đủ nguyên liệu
    P.widget.buttoninfo.validfn = function(inst)
        return inst.replica.container ~= nil and FURN.HasAll(inst.replica.container)
    end
    P.widget.buttoninfo.fn = function(inst, doer)
        if inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
            SendModRPCToServer(GetModRPC("cosu", "luyen_dan"), inst)
        end
    end
    containers.params[FURN.PREFAB] = P
end

AddModRPCHandler("cosu", "luyen_dan", function(player, furnace)
    if player == nil or not player:IsValid() then return end
    if furnace == nil or not furnace:IsValid() or furnace.prefab ~= FURN.PREFAB then return end
    if furnace.TryStartBrew == nil then return end
    if player:GetDistanceSqToInst(furnace) > 8 * 8 then return end
    furnace:TryStartBrew(player)
end)

do
    local ing = {}
    for _, v in ipairs(FURN.BUILD_COST) do
        local atlas = nil
        if string.sub(v.prefab, 1, 5) == "cosu_" then
            atlas = "images/inventoryimages/" .. v.prefab .. ".xml"
        end
        table.insert(ing, G.Ingredient(v.prefab, v.count, atlas))
    end
    AddRecipe2(FURN.PREFAB, ing, G.TECH.COSU_CAVE_ONE, -- phải đứng gần Cổ Động
        {
            placer = FURN.PLACER,
            min_spacing = 3,
            atlas = "images/inventoryimages/cosu_lo_luyen_dan.xml",
            image = "cosu_lo_luyen_dan.tex",
        },
        { "COSU_LUYENCHE" })
end

----------------------------------------------------------------- Rơi nguyên thạch
local function SpawnStones(inst, grade, count)
    for i = 1, count do
        if inst.components.lootdropper ~= nil then
            inst.components.lootdropper:SpawnLootPrefab(COSU.PREFAB[grade])
        else
            local x, y, z = inst.Transform:GetWorldPosition()
            local loot = G.SpawnPrefab(COSU.PREFAB[grade])
            if loot ~= nil then loot.Transform:SetPosition(x, y, z) end
        end
    end
end

local function KilledByPlayer(killer)
    if killer == nil or not killer:IsValid() then return false end
    if killer:HasTag("player") then return true end
    local leader = killer.components.follower ~= nil and killer.components.follower:GetLeader() or nil
    return leader ~= nil and leader:HasTag("player")
end

----------------------------------------------------------------- Bảng rơi nguyên thạch
-- Mỗi loại mob: base = số viên cố định, bonus = { {phẩm, tỷ lệ, số viên}, ... }
local DROP = {
    small  = { base = { low = 1 }, bonus = {} },
    normal = { base = { low = 3 }, bonus = { { "mid", 0.30, 1 } } },
    rare   = { base = { low = 5 }, bonus = { { "mid", 0.50, 1 }, { "high", 0.10, 1 } } },
    boss   = { base = { mid = 3, high = 1 },
               bonus = { { "high", 0.30, 1 }, { "extreme", 0.05, 1 } },
               shards = 30 },
}

-- Mob nhỏ: chỉ chim, thỏ, ong, bướm (liệt kê tay). Nhện, ếch, chó... tính là mob thường.
local SMALL_PREFABS = {
    -- chim
    robin = true, robin_winter = true, crow = true, canary = true,
    canary_poisoned = true, puffin = true,
    -- thỏ
    rabbit = true,
    -- ong
    bee = true, killerbee = true,
    -- bướm
    butterfly = true, moonbutterfly = true,
}

local function IsSmallMob(inst)
    return SMALL_PREFABS[inst.prefab] == true
end

-- Mob hiếm: tính như quái cao cấp (cùng tỷ lệ với ELITE). Tự thêm bớt tùy ý.
local RARE_PREFABS = {
    krampus = true,
    leif = true,
    leif_sparse = true,
    walrus = true,          -- hải cẩu (MacTusk)
    little_walrus = true,   -- hải cẩu con (Wee MacTusk)
    tallbird = true,        -- chim cao
    warg = true,
    claywarg = true,
    spat = true,
    lightninggoat = true,
    koalefant_summer = true,
    koalefant_winter = true,
}

local function IsEliteMob(inst)
    return inst:HasTag("chess")
        or COSU.ELITE_PREFABS[inst.prefab]
        or RARE_PREFABS[inst.prefab]
end

local GRADE_ORDER = { "low", "mid", "high", "extreme" }

-- Rơi mảnh vỡ theo bảng { [tên prefab mảnh] = số lượng }, mảnh cùng hệ gộp thành chồng
local function SpawnShardStacks(inst, per)
    for prefab, n in pairs(per) do
        while n > 0 do
            local item = G.SpawnPrefab(prefab)
            if item == nil then break end
            local stack = 1
            if item.components.stackable ~= nil then
                stack = math.min(n, item.components.stackable.maxsize)
                item.components.stackable:SetStackSize(stack)
            end
            n = n - stack
            if inst.components.lootdropper ~= nil then
                inst.components.lootdropper:FlingItem(item)
            else
                local x, y, z = inst.Transform:GetWorldPosition()
                item.Transform:SetPosition(x, y, z)
            end
        end
    end
end

-- Dự phòng: mỗi mảnh random hệ riêng
local function SpawnRandomShards(inst, total)
    local list = ELEM.LIST
    if list == nil or #list == 0 then return end
    local per = {}
    for i = 1, total do
        local prefab = list[math.random(#list)].shard
        per[prefab] = (per[prefab] or 0) + 1
    end
    SpawnShardStacks(inst, per)
end

----------------------------------------------------------------- Linh Thạch
-- [3] Chữ (đặt gần các G.STRINGS khác)
G.STRINGS.NAMES.COSU_LINHTHACH = "Linh Thạch"
G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.COSU_LINHTHACH = "Tinh túy linh khí ngưng tụ, dùng như tiền tệ của cổ sư."

-- [4] Bảng số lượng theo chuyển của quái { min, max }. Chuyển 3-9 là số TÔI TỰ ĐẶT, bạn sửa lại cho đúng ý.
local LINHTHACH_DROP = {
    [1] = { 1, 50 },
    [2] = { 100, 200 },
    [3] = { 300, 500 },
    [4] = { 600, 1000 },
    [5] = { 1200, 2000 },
    [6] = { 2500, 4000 },
    [7] = { 5000, 8000 },
    [8] = { 10000, 16000 },
    [9] = { 20000, 40000 },
}

-- Rơi 1 cục duy nhất, đã gộp sẵn số lượng. Chuyển của quái = inst._cosu_mob_rank (0 = không có linh căn -> không rơi).
local function SpawnLinhThach(inst)
    local rank = inst._cosu_mob_rank or 0
    if rank <= 0 then return end
    local range = LINHTHACH_DROP[math.min(rank, 9)]
    if range == nil then return end
    local item = G.SpawnPrefab("cosu_linhthach")
    if item == nil then return end
    item:SetAmount(math.random(range[1], range[2]))
    if inst.components.lootdropper ~= nil then
        inst.components.lootdropper:FlingItem(item)
    else
        local x, y, z = inst.Transform:GetWorldPosition()
        item.Transform:SetPosition(x, y, z)
    end
end

-- [6] Nhặt linh thạch -> cộng vào ví, không vào túi đồ (mọi cách nhặt đều đi qua GiveItem)
AddComponentPostInit("inventory", function(self)
    local old_GiveItem = self.GiveItem
    self.GiveItem = function(self, item, ...)
        local wallet = self.inst.components.cosu_linhthach
        if wallet ~= nil and item ~= nil and item:IsValid() and item.prefab == "cosu_linhthach" then
            wallet:DoDelta(item.GetAmount ~= nil and item:GetAmount() or 1)
            if self.inst.SoundEmitter ~= nil then
                self.inst.SoundEmitter:PlaySound("dontstarve/HUD/collect_resource")
            end
            item:Remove()
            return true
        end
        return old_GiveItem(self, item, ...)
    end
end)

local function DropByTable(inst, t)
    local count = {}
    for grade, n in pairs(t.base) do
        count[grade] = (count[grade] or 0) + n
    end
    for _, b in ipairs(t.bonus) do
        if math.random() < b[2] then
            count[b[1]] = (count[b[1]] or 0) + b[3]
        end
    end
    for _, grade in ipairs(GRADE_ORDER) do
        if count[grade] ~= nil and count[grade] > 0 then
            SpawnStones(inst, grade, count[grade])
        end
    end
    -- quái có linh căn: rơi mảnh vỡ đúng hệ của nó; boss lỡ không có linh căn thì rơi ngẫu nhiên như cũ
    local per = ELEMC.GetShardDrops(inst)
    if per ~= nil then
        SpawnShardStacks(inst, per)
    elseif t.shards ~= nil then
        SpawnRandomShards(inst, t.shards)
    end
    SpawnLinhThach(inst) -- quái có cảnh giới (chuyển > 0) rơi linh thạch
end

local function OnMobDeath(inst, data)
    if inst._cosu_dropped then return end
    -- nhân vật chết: không rơi nguyên thạch
    if inst:HasTag("player") or inst:HasTag("playerghost") then return end
    if COSU.REQUIRE_PLAYER_KILL and not KilledByPlayer(data ~= nil and data.afflicter or nil) then return end
    if COSU.BLACKLIST[inst.prefab] then return end

    inst._cosu_dropped = true
    if inst:HasTag("epic") then
        DropByTable(inst, DROP.boss)
    elseif IsEliteMob(inst) then
        DropByTable(inst, DROP.rare)
    elseif IsSmallMob(inst) then
        DropByTable(inst, DROP.small)
    else
        DropByTable(inst, DROP.normal)
    end
end

AddPrefabPostInitAny(function(inst)
    if not G.TheWorld.ismastersim then return end
    if inst:HasTag("player") or inst:HasTag("structure") or inst:HasTag("wall") then return end
    if inst.components.health == nil then return end
    -- chỉ sinh vật: có combat hoặc có khả năng di chuyển (thỏ, bướm... không có combat)
    if inst.components.combat == nil and inst.components.locomotor == nil then return end
    inst:ListenForEvent("death", OnMobDeath)
    ELEMC.AttachDamageNumbers(inst) -- số sát thương nổi khi nhận đòn

    -- linh căn nguyên tố (bỏ qua mob nhỏ, đồng minh người chơi và mob trong BLACKLIST)
    if inst.components.combat ~= nil and not COSU.BLACKLIST[inst.prefab]
        and not inst:HasTag("companion") and not inst:HasTag("abigail") and not inst:HasTag("shadowminion") then
        if inst:HasTag("epic") then
            ELEMC.InitMob(inst, "boss")
        elseif not IsSmallMob(inst) then
            ELEMC.InitMob(inst, "normal")
        end
    end
end)

-- quái có linh căn kháng sát thương thường
AddComponentPostInit("combat", ELEMC.HookCombat)
-- chí mạng (Hội tâm / Bạo kích / Hộ tâm / Kháng bạo) và Kháng công pháp
AddComponentPostInit("combat", STATS.HookCombat)

----------------------------------------------------------------- Hành động: chuột phải nguyên thạch để tiêu hao
AddAction("COSU_ABSORB", "Tiêu hao để lên cảnh giới", function(act)
    local stone, doer = act.invobject, act.doer
    if stone ~= nil and doer ~= nil and doer.components.cosu_cultivation ~= nil then
        return doer.components.cosu_cultivation:AbsorbStone(stone)
    end
    return false
end)
G.ACTIONS.COSU_ABSORB.strfn = function(act)
    return act.invobject ~= nil and string.upper(act.invobject.prefab) or nil
end
do
    local tbl = { GENERIC = "Tiêu hao để lên cảnh giới" }
    for _, grade in ipairs(COSU.GRADES) do
        tbl[string.upper(COSU.PREFAB[grade])] =
            "Tiêu hao để lên cảnh giới (+" .. COSU.POINTS[grade] .. " điểm)"
    end
    G.STRINGS.ACTIONS.COSU_ABSORB = tbl
end

AddComponentAction("INVENTORY", "cosu_stone", function(inst, doer, actions)
    if doer ~= nil and doer:HasTag("player") then
        table.insert(actions, G.ACTIONS.COSU_ABSORB)
    end
end)

AddStategraphActionHandler("wilson", G.ActionHandler(G.ACTIONS.COSU_ABSORB, "doshortaction"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(G.ACTIONS.COSU_ABSORB, "doshortaction"))

----------------------------------------------------------------- Đan đột phá (lên chuyển kế tiếp)
for n = 1, PILL.MAX_PILL do
    local pname = PILL.PrefabName(n)
    local up = string.upper(pname)
    G.STRINGS.NAMES[up] = PILL.DisplayName(n)
    G.STRINGS.CHARACTERS.GENERIC.DESCRIBE[up] =
        "Dùng khi đã tới Đỉnh Phong " .. PILL.RANK_NAMES[n] .. " Chuyển để đột phá."
end

-- Câu thoại khi hành động thất bại (khớp với lý do Breakthrough / AbsorbStone trả về)
G.STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.COSU_BREAKTHROUGH = {
    NOT_PEAK = "Chưa tới Đỉnh Phong, chưa thể đột phá.",
    WRONG_RANK = "Viên đan này không hợp với chuyển hiện tại của ta.",
    MAX_RANK = "Ta đã là Cửu Chuyển, không còn chuyển nào để đột phá.",
    LOCKED = "Cần khai mở Nguyên Hải Thần Thức để bắt đầu hành trình cổ sư.",
}
G.STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.COSU_ABSORB = {
    AT_PEAK = "Đã tới Đỉnh Phong, cần đan dược để đột phá.",
    MAX_PEAK = "Ta đã đạt Cửu Chuyển Đỉnh Phong, không cần tu thêm.",
    LOCKED = "Cần khai mở Nguyên Hải Thần Thức để bắt đầu hành trình cổ sư.",
}

AddAction("COSU_BREAKTHROUGH", "Đột phá", function(act)
    local pill, doer = act.invobject, act.doer
    if pill ~= nil and doer ~= nil and doer.components.cosu_cultivation ~= nil then
        return doer.components.cosu_cultivation:Breakthrough(pill)
    end
    return false
end)

AddComponentAction("INVENTORY", "cosu_pill", function(inst, doer, actions)
    if doer ~= nil and doer:HasTag("player") then
        table.insert(actions, G.ACTIONS.COSU_BREAKTHROUGH)
    end
end)

AddStategraphActionHandler("wilson", G.ActionHandler(G.ACTIONS.COSU_BREAKTHROUGH, "doshortaction"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(G.ACTIONS.COSU_BREAKTHROUGH, "doshortaction"))

----------------------------------------------------------------- Cấp bậc cổ sư (huy hiệu)
AddPlayerPostInit(function(inst)
    inst._cosu_rank = G.net_smallbyte(inst.GUID, "cosu_rank", "cosu_rankdirty")
    inst._cosu_stage = G.net_smallbyte(inst.GUID, "cosu_stage", "cosu_stagedirty")
    inst._cosu_points = G.net_uint(inst.GUID, "cosu_points", "cosu_pointsdirty")
    inst._cosu_need = G.net_uint(inst.GUID, "cosu_need", "cosu_needdirty")
    -- danh sách cổ trùng đã luyện hóa, dạng "1,1,2" (số thứ tự trong cosu_gu_tuning.LIST)
    inst._cosu_gu = G.net_string(inst.GUID, "cosu_gu", "cosu_gudirty")
    -- cổ trùng đã trang bị, dạng "main,s1,...,s9" (0 = ô trống)
    inst._cosu_gu_eq = G.net_string(inst.GUID, "cosu_gu_eq", "cosu_gueqdirty")
    -- độ đói từng cổ trùng, dạng "id:phần trăm,..." (ví dụ "1:100,3:42")
    inst._cosu_gu_hunger = G.net_string(inst.GUID, "cosu_gu_hunger", "cosu_guhungerdirty")
    -- hồi chiêu kỹ năng chủ động, dạng "star=42.5;quanghoa=10.0" (số giây còn lại)
    inst._cosu_cd = G.net_string(inst.GUID, "cosu_cd", "cosu_cddirty")
    -- trạng thái kỹ năng đang chạy (Quang Hóa), dạng "quanghoa=12.3" (số giây còn lại)
    inst._cosu_act = G.net_string(inst.GUID, "cosu_act", "cosu_actdirty")
    -- Nguyên Khí: số hiện tại và tối đa (server cập nhật từ component cosu_nguyenkhi)
    inst._cosu_linhthach = G.net_uint(inst.GUID, "cosu_linhthach", "cosu_linhthachdirty") -- ví Linh Thạch
    inst._cosu_qi = G.net_ushortint(inst.GUID, "cosu_qi", "cosu_qidirty")
    inst._cosu_qimax = G.net_ushortint(inst.GUID, "cosu_qimax", "cosu_qimaxdirty")
    -- thông tin quái đang rê chuột (linh căn, chủng loại), server trả lời yêu cầu RPC "mobinfo"
    inst._cosu_mobinfo = G.net_string(inst.GUID, "cosu_mobinfo", "cosu_mobinfodirty")
    -- linh căn người chơi đang có (từ cổ trùng đã trang bị), dạng "hoa:20,loi:50"; server cập nhật trong ELEMC.AttachPlayer
    inst._cosu_plroots = G.net_string(inst.GUID, "cosu_plroots", "cosu_plrootsdirty")
    -- tiên thiên khí vận đã chọn, dạng "tam_hoa,hoa_the" (server ghi từ component cosu_fortune)
    inst._cosu_fortune = G.net_string(inst.GUID, "cosu_fortune", "cosu_fortunedirty")
    -- danh sách khí vận đang chờ chọn, dạng "id1,...,id9"; rỗng = không cần chọn (màn chọn tự mở khi khác rỗng)
    inst._cosu_fortune_offer = G.net_string(inst.GUID, "cosu_fortune_offer", "cosu_fortune_offerdirty")
    -- chỉ số chiến đấu (phần trăm), server ghi từ component cosu_stats; bảng thông tin nhân vật đọc các netvar này
    inst._cosu_crit = G.net_ushortint(inst.GUID, "cosu_crit", "cosu_critdirty")       -- Hội tâm
    inst._cosu_critdmg = G.net_ushortint(inst.GUID, "cosu_critdmg", "cosu_critdmgdirty") -- Bạo kích
    inst._cosu_guard = G.net_ushortint(inst.GUID, "cosu_guard", "cosu_guarddirty")     -- Hộ tâm
    inst._cosu_critres = G.net_ushortint(inst.GUID, "cosu_critres", "cosu_critresdirty") -- Kháng bạo
    inst._cosu_artres = G.net_ushortint(inst.GUID, "cosu_artres", "cosu_artresdirty")   -- Kháng công pháp
    inst._cosu_rootres = G.net_ushortint(inst.GUID, "cosu_rootres", "cosu_rootresdirty") -- Kháng linh căn
    -- server gọi :push() để máy khách mở bảng khai mở
    inst._cosu_open_awaken = G.net_event(inst.GUID, "cosu_open_awaken")
    -- server gọi :push() để máy khách mở bảng Thạch Quán
    inst._cosu_open_shop = G.net_event(inst.GUID, "cosu_open_shop")
    if not G.TheNet:IsDedicated() then
        inst:ListenForEvent("cosu_open_shop", function(p)
            if p ~= G.ThePlayer or p.HUD == nil then return end
            local top = G.TheFrontEnd:GetActiveScreen()
            if top ~= nil and top.name == "CosuShopScreen" then return end
            local house = G.FindEntity(p, 15, nil, { "cosu_house" })
            G.TheFrontEnd:PushScreen(ShopScreen(p, house))
        end)
    end
    if not G.TheNet:IsDedicated() then
        inst:ListenForEvent("cosu_open_awaken", function(p)
            if p ~= G.ThePlayer or p.HUD == nil then return end
            local top = G.TheFrontEnd:GetActiveScreen()
            if top ~= nil and top.name == "CosuAwakenScreen" then return end
            G.TheFrontEnd:PushScreen(AwakenScreen(p))
        end)
    end
    if not G.TheNet:IsDedicated() then
        -- máy khách: server đưa danh sách khí vận -> mở màn chọn (kể cả khi vào lại giữa chừng)
        inst:ListenForEvent("cosu_fortune_offerdirty", function(p) FortuneScreen.TryOpen(p) end)
        inst:ListenForEvent("playeractivated", function(p) p:DoTaskInTime(1.5, FortuneScreen.TryOpen) end)
    end
    if G.TheWorld.ismastersim then
        inst:AddComponent("cosu_cultivation")
        inst:AddComponent("cosu_fortune")
        inst:AddComponent("cosu_fortune_effects") -- tốc độ đói / ngộ tính từ khí vận
        inst:AddComponent("cosu_gu_bag")
        inst:AddComponent("cosu_nguyenkhi")
        inst:AddComponent("cosu_linhthach")
        inst:AddComponent("cosu_stats")
        ELEMC.AttachPlayer(inst)
    end
end)

local CosuBadge = G.require("widgets/cosu_badge")
AddClassPostConstruct("widgets/controls", function(self)
    if self.owner ~= nil then
        self.cosu_badge = self:AddChild(CosuBadge(self.owner))
    end
end)

----------------------------------------------------------------- Cửa sổ linh căn / chủng loại khi rê chuột vào quái
local CosuMobInfo = G.require("widgets/cosu_mobinfo")
AddClassPostConstruct("widgets/controls", function(self)
    if self.owner ~= nil then
        self.cosu_mobinfo = self:AddChild(CosuMobInfo(self.owner))
    end
end)

----------------------------------------------------------------- Bảng thông tin nhân vật (phím B)
local CosuCharInfo = G.require("widgets/cosu_charinfo")
AddClassPostConstruct("widgets/controls", function(self)
    if self.owner ~= nil then
        self.cosu_charinfo = self:AddChild(CosuCharInfo(self.owner))
    end
end)

do
    local key = G["KEY_" .. (ELEM.CHARINFO.KEY or "B")]
    if key ~= nil then
        G.TheInput:AddKeyDownHandler(key, function()
            local p = G.ThePlayer
            if p == nil or p.HUD == nil or p.HUD:HasInputFocus() then return end
            local w = p.HUD.controls ~= nil and p.HUD.controls.cosu_charinfo or nil
            if w ~= nil then w:Toggle() end
        end)
    end
end

AddModRPCHandler("cosu", "mobinfo", function(player, target)
    ELEMC.SendMobInfo(player, target)
end)

-- Tiên Thiên Khí Vận: roll lại các thẻ chưa chọn / xác nhận lựa chọn (server kiểm tra lại hết)
AddModRPCHandler("cosu", "fortune_roll", function(player, locked)
    local f = player ~= nil and player:IsValid() and player.components.cosu_fortune or nil
    if f ~= nil and type(locked) == "string" then f:Roll(locked) end
end)
AddModRPCHandler("cosu", "fortune_pick", function(player, ids)
    local f = player ~= nil and player:IsValid() and player.components.cosu_fortune or nil
    if f ~= nil and type(ids) == "string" then f:Confirm(ids) end
end)

-- Thử: bỏ khí vận hiện có và chọn lại:  c_cosu_fortune()
G.c_cosu_fortune = function()
    local p = G.ConsoleCommandPlayer()
    if p ~= nil and p.components.cosu_fortune ~= nil then p.components.cosu_fortune:Reset() end
end

-- server -> máy khách: số sát thương nổi (xem ReportDamage trong cosu_element_combat.lua)
AddClientModRPCHandler("cosu", "dmg", function(data)
    DMGFX.Show(data)
end)

----------------------------------------------------------------- Nguyên Hải Thần Thức (nút + bảng)
local CosuSeaButton = G.require("widgets/cosu_sea_button")
AddClassPostConstruct("widgets/controls", function(self)
    if self.owner ~= nil then
        self.cosu_sea_button = self:AddChild(CosuSeaButton(self.owner))
    end
end)

----------------------------------------------------------------- Nguyên Khí (chỉ số thứ 4, cạnh Máu / Đói / Tỉnh táo)
local CosuQiBadge = G.require("widgets/cosu_nguyenkhi_badge")
AddClassPostConstruct("widgets/statusdisplays", function(self)
    if self.owner == nil then return end
    self.cosu_qi = self:AddChild(CosuQiBadge(self.owner))
    self.cosu_qi:SetDefaultPos(-80, -9) -- vị trí mặc định; người chơi kéo bằng chuột phải sẽ được nhớ lại
end)

-- Thử trong console (chỉ chủ phòng):  c_cosu_qi(-50) -> trừ 50;  c_cosu_qi(100) -> cộng 100
G.c_cosu_qi = function(delta)
    local p = G.ConsoleCommandPlayer()
    if p ~= nil and p.components.cosu_nguyenkhi ~= nil then
        p.components.cosu_nguyenkhi:DoDelta(delta or 0)
    end
end

----------------------------------------------------------------- Phím tắt kỹ năng cổ trùng
-- Nút kỹ năng nằm cạnh nút Nguyên Hải (widgets/cosu_skill_bar.lua). Phím tắt gọi lại đúng nút đó.
for kind, keyname in pairs(GU.SKILL_KEYS or {}) do
    local key = G["KEY_" .. keyname]
    if key ~= nil then
        G.TheInput:AddKeyDownHandler(key, function()
            local p = G.ThePlayer
            if p == nil or p.HUD == nil or p.HUD:HasInputFocus() then return end
            local btn = p.HUD.controls ~= nil and p.HUD.controls.cosu_sea_button or nil
            if btn ~= nil and btn.skill_bar ~= nil then
                btn.skill_bar:UseKind(kind)
            end
        end)
    end
end

----------------------------------------------------------------- Luyện hóa cổ trùng vào Nguyên Hải
G.STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.COSU_REFINE_GU = {
    LOCKED = "Cần khai mở Nguyên Hải Thần Thức trước.",
    FULL = "Nguyên Hải đã chật, không chứa thêm Cổ Trùng được.",
    INVALID = "Thứ này không luyện hóa được.",
    ALREADY = "Nguyên Hải đã có loại Cổ Trùng này rồi, không luyện hóa thêm được.",
}

-- Kiểm tra loại cổ trùng này đã nằm trong Nguyên Hải chưa. Chạy được ở cả máy khách lẫn server.
-- Tính cả cổ chưa trang bị (_cosu_gu: "1,1,2") lẫn cổ đã trang bị (_cosu_gu_eq: "main,s1,...,s9").
local function GuAlreadyRefined(doer, item)
    if doer == nil or item == nil then return false end
    local id = GU.ID[item.prefab]
    if id == nil then return false end
    for _, nv in pairs({ doer._cosu_gu, doer._cosu_gu_eq }) do
        if nv ~= nil then
            for n in string.gmatch(nv:value() or "", "%d+") do
                if G.tonumber(n) == id then return true end
            end
        end
    end
    return false
end

AddAction("COSU_REFINE_GU", "Luyện hóa", function(act)
    local item, doer = act.invobject, act.doer
    local bag = doer ~= nil and doer.components.cosu_gu_bag or nil
    if item == nil or bag == nil then return false end
    if doer._cosu_rank == nil or doer._cosu_rank:value() < 1 then
        return false, "LOCKED"
    end
    if GuAlreadyRefined(doer, item) then
        return false, "ALREADY"
    end
    return bag:Refine(item)
end)

AddComponentAction("INVENTORY", "cosu_gu", function(inst, doer, actions)
    -- loại cổ trùng đã có trong Nguyên Hải thì ẩn nút "Luyện hóa" (vẫn chế tạo bình thường)
    if doer ~= nil and doer:HasTag("player") and not GuAlreadyRefined(doer, inst) then
        table.insert(actions, G.ACTIONS.COSU_REFINE_GU)
    end
end)

AddStategraphActionHandler("wilson", G.ActionHandler(G.ACTIONS.COSU_REFINE_GU, "doshortaction"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(G.ACTIONS.COSU_REFINE_GU, "doshortaction"))

----------------------------------------------------------------- Hấp thu vật phẩm Lôi Hóa (chuột phải)
-- Sừng dê / Mảnh Vỡ Lôi / Lôi Linh Căn hiện nút "Hấp thu" khi đang trang bị U Lôi Huyễn Điệp Cổ.
local LOIHOA_ITEMS = {}
for _, food in ipairs(GU.ULOI.LOIHOA_FOODS) do
    local prefab = food.prefab
    if prefab == nil then
        for _, e in ipairs(ELEM.LIST) do
            if e.id == food.elem then prefab = e[food.part] end
        end
    end
    if prefab ~= nil then LOIHOA_ITEMS[prefab] = true end
end

-- Có U Lôi Huyễn Điệp Cổ trong ô trang bị / Bản Mệnh Cổ không (_cosu_gu_eq: "main,s1,...,s9"). Chạy được cả máy khách.
local function HasUloiEquipped(doer)
    local id = GU.ID["cosu_gu_uloi"]
    if doer == nil or id == nil or doer._cosu_gu_eq == nil then return false end
    for n in string.gmatch(doer._cosu_gu_eq:value() or "", "%d+") do
        if G.tonumber(n) == id then return true end
    end
    return false
end

AddAction("COSU_LOIHOA_ABSORB", "Hấp thu", function(act)
    local item, doer = act.invobject, act.doer
    local bag = doer ~= nil and doer.components.cosu_gu_bag or nil
    if item == nil or bag == nil then return false end
    return bag:AbsorbLoihoa(item)
end)
G.STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.COSU_LOIHOA_ABSORB = {
    NO_GU = "Cần trang bị U Lôi Huyễn Điệp Cổ để hấp thu.",
    FULL = "Lôi lực đã đầy, không hấp thu thêm được.",
    INVALID = "Thứ này không hấp thu được.",
}

AddComponentAction("INVENTORY", "inventoryitem", function(inst, doer, actions)
    if LOIHOA_ITEMS[inst.prefab] and doer ~= nil and doer:HasTag("player") and HasUloiEquipped(doer) then
        table.insert(actions, G.ACTIONS.COSU_LOIHOA_ABSORB)
    end
end)

AddStategraphActionHandler("wilson", G.ActionHandler(G.ACTIONS.COSU_LOIHOA_ABSORB, "doshortaction"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(G.ACTIONS.COSU_LOIHOA_ABSORB, "doshortaction"))

-- Bảng Nguyên Hải gửi lên: trang bị / gỡ cổ trùng. Server kiểm tra lại mọi thứ.
AddModRPCHandler("cosu", "gu_equip", function(player, place, idx)
    if player == nil or not player:IsValid() then return end
    local bag = player.components.cosu_gu_bag
    if bag == nil or type(place) ~= "number" or type(idx) ~= "number" then return end
    bag:Equip(math.floor(place), math.floor(idx))
end)

AddModRPCHandler("cosu", "gu_unequip", function(player, place)
    if player == nil or not player:IsValid() then return end
    local bag = player.components.cosu_gu_bag
    if bag == nil or type(place) ~= "number" then return end
    bag:Unequip(math.floor(place))
end)

-- Cho cổ trùng ăn (bảng trạng thái, tab Cổ trùng): id = số thứ tự cổ, prefab = món ăn trong túi.
AddModRPCHandler("cosu", "gu_feed", function(player, id, prefab)
    if player == nil or not player:IsValid() then return end
    local bag = player.components.cosu_gu_bag
    if bag == nil or type(id) ~= "number" or type(prefab) ~= "string" then return end
    bag:Feed(math.floor(id), prefab)
end)

-- Dùng kỹ năng chủ động của cổ trùng đã trang bị (chuột phải vào cổ trong bảng Nguyên Hải).
-- place: 0 = Bản Mệnh Cổ, 1..9 = các ô trang bị. Server kiểm tra lại mọi thứ.
-- kind: tên kỹ năng (một cổ có thể có nhiều kỹ năng). Sao trời / Giáng Lôi gửi thêm x, z là vị trí
-- người chơi chọn bằng chuột phải (server tự giới hạn tầm).
AddModRPCHandler("cosu", "gu_skill", function(player, place, kind, x, z)
    if player == nil or not player:IsValid() then return end
    local bag = player.components.cosu_gu_bag
    if bag == nil or type(place) ~= "number" then return end
    if kind ~= nil and type(kind) ~= "string" then return end
    bag:UseSkill(math.floor(place), kind, x, z)
end)

-- Thử chỉ số chiến đấu (chỉ chủ phòng):  c_cosu_stat("crit", 30)  -> cộng 30% Hội tâm;  c_cosu_stat("crit", 0) -> bỏ
-- key: crit, critdmg, guard, critres, artres, rootres
G.c_cosu_stat = function(key, value)
    local p = G.ConsoleCommandPlayer()
    if p ~= nil and p.components.cosu_stats ~= nil then
        p.components.cosu_stats:SetBonus(key, "console", value or 0)
    end
end

-- Thử kỹ năng ngay trong console (chỉ chủ phòng):  c_cosu_skill(0) -> ô Bản Mệnh Cổ,  c_cosu_skill(1) -> ô 1
G.c_cosu_skill = function(place)
    local p = G.ConsoleCommandPlayer()
    if p ~= nil and p.components.cosu_gu_bag ~= nil then
        print("c_cosu_skill:", p.components.cosu_gu_bag:UseSkill(place or 0))
    end
end

-- Thử trong console: c_cosu_linhthach(500)
G.c_cosu_linhthach = function(n)
    local p = G.ConsoleCommandPlayer()
    if p ~= nil and p.components.cosu_linhthach ~= nil then p.components.cosu_linhthach:DoDelta(n or 100) end
end

-- Lệnh thử trong console (chỉ chủ phòng):  c_cosu(3, 2)  -> Tam Chuyển, Trung Giai
G.c_cosu = function(rank, stage)
    local p = G.ConsoleCommandPlayer()
    if p ~= nil and p.components.cosu_cultivation ~= nil then
        p.components.cosu_cultivation:SetRank(rank or 1, stage or 1)
    end
end

-- Cộng thẳng điểm tu vi để thử:  c_cosu_diem(100)
G.c_cosu_diem = function(n)
    local p = G.ConsoleCommandPlayer()
    if p ~= nil and p.components.cosu_cultivation ~= nil then
        p.components.cosu_cultivation:AddPoints(n or 0)
    end
end

-- Lấy đan để thử (chỉ chủ phòng):  c_cosu_dan()  -> đủ 8 viên
--                                  c_cosu_dan(3)  -> 1 viên đan số 3
--                                  c_cosu_dan(3, 5) -> 5 viên đan số 3
G.c_cosu_dan = function(n, count)
    local p = G.ConsoleCommandPlayer()
    if p == nil or p.components.inventory == nil then return end
    local from, to = 1, PILL.MAX_PILL
    if n ~= nil then from, to = n, n end
    for i = from, to do
        for _ = 1, (count or 1) do
            local item = G.SpawnPrefab(PILL.PrefabName(i))
            if item ~= nil then p.components.inventory:GiveItem(item) end
        end
    end
end

-- Lấy mảnh vỡ nguyên tố để thử (chỉ chủ phòng):  c_cosu_manh()        -> 10 mảnh mỗi hệ
--                                                c_cosu_manh(1)       -> 10 mảnh hệ số 1 (Hỏa)
--                                                c_cosu_manh(1, 25)   -> 25 mảnh hệ số 1
-- Thứ tự hệ: 1 Hỏa, 2 Mộc, 3 Thủy, 4 Thổ, 5 Lôi, 6 Ám, 7 Quang, 8 Phong
G.c_cosu_manh = function(n, count)
    local p = G.ConsoleCommandPlayer()
    if p == nil or p.components.inventory == nil then return end
    for i, e in ipairs(ELEM.LIST) do
        if n == nil or n == i then
            local item = G.SpawnPrefab(e.shard)
            if item ~= nil then
                if item.components.stackable ~= nil then
                    item.components.stackable:SetStackSize(math.min(count or ELEM.SHARDS_PER_ROOT, item.components.stackable.maxsize))
                end
                p.components.inventory:GiveItem(item)
            end
        end
    end
end

----------------------------------------------------------------- NPC khai mở Nguyên Hải Thần Thức
G.STRINGS.NAMES.COSU_NPC = "Cổ Sư Dẫn Đường"
G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.COSU_NPC = "Người này có thể giúp ta khai mở Nguyên Hải Thần Thức."

AddAction("COSU_OPENAWAKEN", "Mở khóa Nguyên Hải Thần Thức", function(act)
    local doer = act.doer
    if doer ~= nil and doer._cosu_open_awaken ~= nil then
        doer._cosu_open_awaken:push()
        return true
    end
    return false
end)
G.STRINGS.ACTIONS.COSU_OPENAWAKEN = "Mở khóa Nguyên Hải Thần Thức"
G.ACTIONS.COSU_OPENAWAKEN.rmb = true
G.ACTIONS.COSU_OPENAWAKEN.distance = 3

-- chuột phải vào NPC (chỉ hiện khi còn là Phàm Nhân)
AddComponentAction("SCENE", "cosu_awakener", function(inst, doer, actions, right)
    if right and doer ~= nil and doer:HasTag("player")
        and doer._cosu_rank ~= nil and doer._cosu_rank:value() < 1 then
        table.insert(actions, G.ACTIONS.COSU_OPENAWAKEN)
    end
end)
AddStategraphActionHandler("wilson", G.ActionHandler(G.ACTIONS.COSU_OPENAWAKEN, "doshortaction"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(G.ACTIONS.COSU_OPENAWAKEN, "doshortaction"))

-- nút "Khai mở" trong bảng gửi lên đây; server kiểm tra lại khoảng cách và vật phẩm
AddModRPCHandler("cosu", "awaken", function(player)
    if player == nil or not player:IsValid() then return end
    local cult = player.components.cosu_cultivation
    if cult == nil then return end
    if G.FindEntity(player, AWAKEN.NEAR_DIST, nil, { "cosu_awakener" }) == nil then return end
    cult:TryAwaken()
end)

----------------------------------------------------------------- Thạch Quán (ngôi nhà trên đảo): bấm chuột trái để mở bảng
G.STRINGS.NAMES.COSU_HOUSE = "Thạch Quán"
G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.COSU_HOUSE = "Một quán trà nhỏ giữa biển, đèn lồng vẫn sáng."

AddAction("COSU_OPENSHOP", "Vào Thạch Quán", function(act)
    local doer = act.doer
    if doer ~= nil and doer._cosu_open_shop ~= nil then
        doer._cosu_open_shop:push()
        return true
    end
    return false
end)
G.STRINGS.ACTIONS.COSU_OPENSHOP = "Vào Thạch Quán"
G.ACTIONS.COSU_OPENSHOP.distance = 6
G.ACTIONS.COSU_OPENSHOP.priority = 1

AddComponentAction("SCENE", "cosu_shop", function(inst, doer, actions, right)
    if not right and doer ~= nil and doer:HasTag("player") then
        table.insert(actions, G.ACTIONS.COSU_OPENSHOP)
    end
end)
AddStategraphActionHandler("wilson", G.ActionHandler(G.ACTIONS.COSU_OPENSHOP, "doshortaction"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(G.ACTIONS.COSU_OPENSHOP, "doshortaction"))

-- Đổ thạch: máy khách gửi số ô (1-9); server kiểm tra khoảng cách + tiền rồi trả kết quả về qua RPC "shopresult"
AddModRPCHandler("cosu", "gamble", function(player, slot)
    if player == nil or not player:IsValid() then return end
    local house = G.FindEntity(player, 15, nil, { "cosu_house" })
    if house ~= nil and house.components.cosu_shop ~= nil then
        house.components.cosu_shop:Gamble(player, slot)
    end
end)
AddClientModRPCHandler("cosu", "shopresult", function(prefab, count)
    local top = G.TheFrontEnd ~= nil and G.TheFrontEnd:GetActiveScreen() or nil
    if top ~= nil and top.name == "CosuShopScreen" and top.ShowResult ~= nil then
        top:ShowResult(prefab, count)
    end
end)

-- Thử trong console (chỉ chủ phòng): c_cosu_house() -> đặt lại nhà + đường sỏi (dùng sau khi chỉnh vị trí/cỡ)
G.c_cosu_house = function()
    if G.TheWorld ~= nil and G.TheWorld.components.cosu_island ~= nil then
        G.TheWorld.components.cosu_island:Rehouse()
    end
end

-- Xuất hiện ngẫu nhiên quanh cổng hoa (chỉ sinh 1 lần cho mỗi thế giới)
local function SpawnNpcNearPortal(portal)
    if not portal:IsValid() then return end
    if G.TheSim:FindFirstEntityWithTag("cosu_awakener") ~= nil then return end
    local pos = portal:GetPosition()
    local radii = { 8, 10, 12, 7, 14 }
    for _, r in ipairs(radii) do
        local off = G.FindWalkableOffset(pos, math.random() * 2 * math.pi, r, 16, true, true)
        if off ~= nil then
            local npc = G.SpawnPrefab("cosu_npc")
            if npc ~= nil then
                npc.Transform:SetPosition(pos.x + off.x, 0, pos.z + off.z)
            end
            return
        end
    end
end

local function HookPortal(inst)
    if not G.TheWorld.ismastersim then return end
    inst:DoTaskInTime(1, SpawnNpcNearPortal)
end
-- AddPrefabPostInit("multiplayer_portal", HookPortal)
-- AddPrefabPostInit("multiplayer_portal_moonrock", HookPortal)

-- Thử: sinh NPC cạnh mình:  c_cosu_npc()
G.c_cosu_npc = function()
    local p = G.ConsoleCommandPlayer()
    if p == nil then return end
    local x, y, z = p.Transform:GetWorldPosition()
    local npc = G.SpawnPrefab("cosu_npc")
    if npc ~= nil then npc.Transform:SetPosition(x + 3, 0, z) end
end

modimport("cosu_island.lua")