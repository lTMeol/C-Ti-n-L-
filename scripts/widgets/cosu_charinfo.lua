-- Bảng thông tin nhân vật (nhấn B để mở / đóng; chỉ chạy trên máy khách).
-- Hai tab: Trạng thái và Cổ trùng (danh sách cổ đã luyện hóa, bấm vào xem từng con).
-- Tab Trạng thái: hàng trên = Cảnh giới (chuyển, giai, tu vi) | Tiên Thiên Khí Vận; hàng dưới = 5 cột Thuộc tính | Chiến đấu | Công pháp | Linh Căn | Kỹ nghệ.
-- Chỉ số mới đọc từ netvar của player (tên ghi trong COMBAT_ROWS / ART_ROWS / SKILL_ROWS / ATTR_ROWS bên dưới); netvar chưa có thì hiện 0.
-- Linh căn (trong cột Tư Chất, đã cộng phần từ khí vận) lấy từ netvar player._cosu_plroots ("hoa:20,loi:50"), server tính từ cổ trùng đang trang bị.
-- Chữ và số liệu: cosu_element_tuning.CHARINFO / COMBAT.RANK_NAMES.
-- Giao diện: nền = fabaobg_1 (tranh thủy mặc), hai tab = icon PlayInfo_shuxing / PlayInfo_gerenjingli trên thanh khung,
-- icon tư chất = atlas cosu_trait_icons (gộp từ icons.zip). Cần khai báo Asset trong modmain.lua (xem README).
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ELEM = require "cosu_element_tuning"
local GU = require "cosu_gu_tuning"
local ImageButton = require "widgets/imagebutton"
local TextButton = require "widgets/textbutton"
local FT = require "cosu_fortune_tuning"
local FortuneScreen = require "screens/cosu_fortune_screen"
local ST = require "cosu_stats_tuning"
local SHOP = require "cosu_shop_tuning"

local CI = ELEM.CHARINFO
local BY_ID = {}
for _, e in ipairs(ELEM.LIST) do BY_ID[e.id] = e end

-- Ảnh giao diện (đường dẫn trong mod; tạo bằng tools/build_assets.py)
local UI_DIR = "images/" -- cùng thư mục với cosu_badge.xml, cosu_glow.xml... (đổi nếu bạn để chỗ khác, nhớ đổi cả modmain)
local UI = {
    bg = { UI_DIR .. "fabaobg_1.xml", "fabaobg_1.tex" },
    tab_status = { UI_DIR .. "PlayInfo_shuxing.xml", "PlayInfo_shuxing.tex" },
    tab_gu = { UI_DIR .. "PlayInfo_gerenjingli.xml", "PlayInfo_gerenjingli.tex" },
}
local TRAIT_ATLAS = UI_DIR .. "cosu_trait_icons.xml"
-- icon cho các chỉ số tư chất (sửa số để đổi icon, xem icons/icon_xxx.png)
local TRAIT_ICON = {
    alchemy = "icon_072.tex", -- luyện đan
    charm = "icon_025.tex", -- mị lực
    luck = "icon_049.tex", -- may mắn
    demon = "icon_034.tex", -- ma đạo
    righteous = "icon_083.tex", -- chính đạo
}
-- icon linh căn: tra theo e.id, không có thì tra theo tên (e.label)
local ROOT_ICON = {}
local ROOT_ICON_BY_LABEL = {
    ["Hỏa"] = "icon_078.tex",
    ["Mộc"] = "icon_041.tex",
    ["Thủy"] = "icon_012.tex",
    ["Thổ"] = "icon_069.tex",
    ["Lôi"] = "icon_070.tex",
    ["Ám"] = "icon_005.tex",
    ["Quang"] = "icon_011.tex",
    ["Phong"] = "icon_080.tex", -- tạm dùng icon cũ của Kim; đổi số icon nếu có icon gió
}
-- icon cột Thuộc tính (bốn thanh + các chỉ số cộng từ khí vận)
local STAT_ICON = {
    hp = "icon_025.tex", hunger = "icon_043.tex", sanity = "icon_020.tex", qi = "icon_071.tex",
    f_hp = "icon_051.tex", f_qimax = "icon_077.tex", f_attack = "icon_047.tex",
    f_defense = "icon_053.tex", f_speed = "icon_019.tex",
}

-- Các hàng chỉ số (nv = tên netvar trên player, server gửi xuống; fkey = khóa chỉ số cộng từ Tiên Thiên Khí Vận trong cosu_fortune_tuning)
-- Giá trị hiển thị = netvar + phần khí vận. Chưa có netvar thì hiện 0 (thêm netvar ở phía server là tự lên số).
local ATTR_ROWS = {
    { key = "luck", label = "May mắn", icon = "icon_049.tex", fkey = "luck" },
    { key = "charm", label = "Mị lực", icon = "icon_025.tex", fkey = "charm" },
    { key = "fame", label = "Danh vọng", icon = "icon_036.tex", nv = "_cosu_fame", fkey = "fame" },
    { key = "demon", label = "Ma đạo", icon = "icon_034.tex", fkey = "demon" },
    { key = "righteous", label = "Chính đạo", icon = "icon_083.tex", fkey = "righteous" },
}
local COMBAT_ROWS = { -- đã bỏ Cước lực
    { key = "attack", label = "Tấn công", icon = "icon_047.tex", nv = "_cosu_attack", fkey = "attack" },
    { key = "defense", label = "Phòng ngự", icon = "icon_061.tex", nv = "_cosu_defense", fkey = "defense" },
    { key = "crit", label = "Hội tâm", icon = "icon_064.tex", nv = "_cosu_crit", suffix = "%", fkey = "crit" },
    { key = "guard", label = "Hộ tâm", icon = "icon_076.tex", nv = "_cosu_guard", suffix = "%", fkey = "protect" },
    { key = "speed", label = "Di tốc", icon = "icon_044.tex", nv = "_cosu_speed", suffix = "%", fkey = "speed", gukind = "speed" }, -- gukind: cộng thêm di tốc từ cổ trùng đang trang bị (GuSpeedPct)
    { key = "critdmg", label = "Bạo kích", icon = "icon_065.tex", nv = "_cosu_critdmg", suffix = "%" },
    { key = "critres", label = "Kháng bạo", icon = "icon_079.tex", nv = "_cosu_critres", suffix = "%" },
    { key = "artres", label = "Kháng công pháp", icon = "icon_037.tex", nv = "_cosu_artres", suffix = "%" },
    { key = "rootres", label = "Kháng linh căn", icon = "icon_046.tex", nv = "_cosu_rootres", suffix = "%" },
}
local ART_ROWS = {
    { key = "dao", label = "Đao pháp", icon = "icon_060.tex", nv = "_cosu_art_dao", fkey = "blade", fall = "gongfa" },
    { key = "thuong", label = "Thương pháp", icon = "icon_021.tex", nv = "_cosu_art_thuong", fkey = "spear", fall = "gongfa" },
    { key = "kiem", label = "Kiếm pháp", icon = "icon_080.tex", nv = "_cosu_art_kiem", fkey = "sword", fall = "gongfa" },
    { key = "quyen", label = "Quyền pháp", icon = "icon_022.tex", nv = "_cosu_art_quyen", fkey = "fist", fall = "gongfa" },
    { key = "chuong", label = "Chưởng pháp", icon = "icon_035.tex", nv = "_cosu_art_chuong", fkey = "palm", fall = "gongfa" },
    { key = "chi", label = "Chỉ pháp", icon = "icon_026.tex", nv = "_cosu_art_chi", fkey = "finger", fall = "gongfa" },
}
local SKILL_ROWS = {
    { key = "alchemy", label = "Luyện đan", icon = "icon_072.tex", nv = "_cosu_alchemy", fkey = "alchemy" },
    { key = "refine", label = "Luyện khí", icon = "icon_045.tex", nv = "_cosu_refine" },
    { key = "fengshui", label = "Phong thủy", icon = "icon_048.tex", nv = "_cosu_fengshui", fkey = "fengshui" },
    { key = "talisman", label = "Họa phù", icon = "icon_052.tex", nv = "_cosu_talisman", fkey = "huafu" },
    { key = "herb", label = "Dược liệu", icon = "icon_043.tex", nv = "_cosu_herb" },
    { key = "ore", label = "Khoáng tài", icon = "icon_028.tex", nv = "_cosu_ore" },
}

-- các khóa khí vận đã có hàng riêng (những khóa còn lại hiện thành dòng chữ dưới cột Thuộc tính)
local ROW_FKEY = {}
for _, list in ipairs({ ATTR_ROWS, COMBAT_ROWS, ART_ROWS, SKILL_ROWS }) do
    for _, r in ipairs(list) do
        if r.fkey ~= nil then ROW_FKEY[r.fkey] = true end
        if r.fall ~= nil then ROW_FKEY[r.fall] = true end
    end
end

-- Giải thích chỉ số: rê chuột vào dòng chỉ số (tab Trạng thái) thì hiện cửa sổ nhỏ.
-- Khóa = r.key của hàng (ATTR_ROWS / COMBAT_ROWS) hoặc hp / hunger / sanity / qi cho bốn thanh.
-- Giá trị là chuỗi hoặc hàm trả về chuỗi (hàm để lấy số liệu thật từ file tuning, đổi số ở đó là chữ tự theo).
-- Chỉ số chưa có tác dụng (Danh vọng, công pháp, kỹ nghệ...) cố ý KHÔNG có ở đây -> không hiện gì. Có tác dụng rồi thì thêm 1 dòng.
local function Pct(x) return math.floor(x * 100 + 0.5) end
local CB = ELEM.COMBAT
local TIPS = {
    hp = "Sinh Lực: máu hiện có / tối đa. Tiên Thiên Khí Vận có thể cộng thêm vào mức tối đa.",
    hunger = "Đói (Tinh lực): độ no hiện có / tối đa. Tiên Thiên Khí Vận có thể cộng thêm mức tối đa, và làm đói nhanh hoặc chậm hơn.",
    sanity = "Tỉnh Táo (Ngộ tính): mức hiện có / tối đa. Tiên Thiên Khí Vận có thể cộng thêm mức tối đa, làm tụt chậm hơn hoặc hồi nhanh hơn.",
    qi = "Nguyên Khí: dùng để thi triển kỹ năng chủ động của cổ trùng (mỗi kỹ năng tiêu hao khác nhau). Tiên Thiên Khí Vận có thể cộng thêm mức tối đa.",

    luck = function()
        return string.format("May mắn: vận khí càng tốt, cơ duyên càng dày. Cứ %d điểm sẽ tăng thêm %d%% tỷ lệ mở ra cổ trùng khi đổ thạch ở Thạch Quán (tính theo bậc; tỷ lệ gốc %d%%, tối đa %d%%).",
            SHOP.LUCK_STEP, Pct(SHOP.LUCK_BONUS), Pct(SHOP.GU_CHANCE), Pct(SHOP.GU_CHANCE_MAX))
    end,
    charm = function()
        return string.format("Mị lực: phong thái càng khiến người nể phục, NPC càng có hảo cảm với bạn. Chưởng quầy Thạch Quán sẽ bớt giá: cứ %d điểm giảm %d%% giá đá (tính theo bậc; giảm tối đa %d%%).",
            SHOP.CHARM_STEP, Pct(SHOP.CHARM_DISCOUNT), Pct(SHOP.CHARM_MAX_DISCOUNT))
    end,
    demon = function()
        return string.format("Ma đạo: sát khí nặng nề khiến người đời dè chừng. Nếu Ma đạo lớn hơn Chính đạo, chưởng quầy Thạch Quán sẽ tăng giá đá %d%% với bạn, lời chào cũng thay đổi theo.",
            Pct(SHOP.DEMON_SURCHARGE))
    end,
    righteous = function()
        return string.format("Chính đạo: lòng ngay thẳng được người đời quý trọng. Chính đạo bằng hoặc lớn hơn Ma đạo thì chưởng quầy Thạch Quán giữ nguyên giá, ngược lại thì giá đá bị tăng %d%%.",
            Pct(SHOP.DEMON_SURCHARGE))
    end,

    attack = function()
        local t = "Tấn công: mỗi đòn đánh gây thêm đúng bấy nhiêu sát thương thường, cộng vào sát thương của vũ khí."
        if FT.ATTACK_USE_PHYS_RESIST then
            t = t .. string.format(" Quái có cảnh giới kháng %d%% phần này.", Pct(CB.PHYS_RESIST))
        end
        return t
    end,
    defense = "Phòng ngự: mỗi đòn nhận vào được giảm đi đúng bấy nhiêu sát thương (sát thương không xuống dưới 0).",
    crit = function()
        return string.format("Hội tâm: tỷ lệ gây chí mạng của đòn đánh. Tỷ lệ thực = Hội tâm của bạn - Hộ tâm của đối phương (gốc %d%%). Quái có cảnh giới cũng có Hội tâm, mỗi chuyển +%d%%.",
            ST.DEF.crit.base, ST.MOB.CRIT_PER_RANK)
    end,
    guard = "Hộ tâm: trừ thẳng vào tỷ lệ chí mạng của kẻ đánh bạn.",
    speed = function()
        return string.format("Di tốc: tốc độ chạy cộng thêm (cưỡi bò vẫn có tác dụng). Nguồn: Tiên Thiên Khí Vận, U Lôi Huyễn Điệp Cổ (+%d%%, ở Bản Mệnh Cổ +%d%%). Thạch Bì Cổ giảm %d%%.",
            Pct(GU.ULOI.SPEED_SLOT - 1), Pct(GU.ULOI.SPEED_MAIN - 1), Pct(1 - GU.THACHBI.SPEED_MULT))
    end,
    critdmg = function()
        return string.format("Bạo kích: sát thương của đòn chí mạng, 100%% là không tăng (gốc %d%% = nhân %s). Kháng bạo của đối phương giảm phần tăng thêm này.",
            ST.DEF.critdmg.base, (string.format("%.1f", ST.DEF.critdmg.base / 100):gsub("%.", ",")))
    end,
    critres = function()
        return string.format("Kháng bạo: giảm phần sát thương cộng thêm của đòn chí mạng đánh vào bạn (tối đa %d%%).", ST.RES_CAP)
    end,
    artres = function()
        return string.format("Kháng công pháp: giảm sát thương của đòn đánh thường quái gây lên bạn (tối đa %d%%).", ST.RES_CAP)
    end,
    rootres = function()
        return string.format("Kháng linh căn: giảm sát thương nguyên tố (linh căn) của quái bộc phát lên bạn (tối đa %d%%).", ST.RES_CAP)
    end,
}
-- linh căn: mỗi hệ một câu, dựng từ tên hệ
local function RootTip(e)
    return string.format("%s linh căn: mỗi đòn đánh gây thêm sát thương %s đúng bằng con số này (từ cổ trùng đang trang bị và khí vận; bằng 0 hoặc âm thì không gây). Quái có cảnh giới cùng hệ giảm %d%% x số chuyển. Mỗi cổ trùng hệ %s đang trang bị giảm %d sát thương %s nhận vào (tối đa %d con).",
        e.label, e.label, Pct(CB.ELEM_RESIST_PER_RANK), e.label, CB.RESIST_PER_GU, e.label, CB.RESIST_GU_CAP)
end
local function TipText(t)
    if type(t) == "function" then
        local ok, r = pcall(t)
        return ok and r or ""
    end
    return t or ""
end

-- Khung nền: ảnh gốc 1868x1052, vùng giấy nằm trong y = 96..950, thanh tiêu đề y = 26..94
local BG_W = 1340 -- chiều rộng hiển thị của khung (5 cột nên rộng hơn trước; chỉnh to/nhỏ ở đây, tỉ lệ giữ nguyên)
local IMG_W, IMG_H = 1868, 1052
local BG_K = BG_W / IMG_W
local BG_H = IMG_H * BG_K
local FIT = math.min(1, 700 / BG_H) -- màn hình ảo 1280x720: thu nhỏ nếu khung cao hơn
local CONTENT_K = 0.91 -- thu nhỏ riêng phần nội dung bên trong khung (<1 = lùi vào xa viền hơn, 1 = cỡ cũ)
local UI_SCALE = 0.72 -- thu nhỏ cả bảng (chữ, icon, khung) để còn thấy màn hình game; 1 = cỡ cũ, chỉnh 0.6 ~ 0.85 tùy thích
local function BgY(py) return (IMG_H / 2 - py) * BG_K end
local PAPER_TOP = BgY(96)
local BAR_Y = BgY(60)

-- Vùng Tiên Thiên Khí Vận: khoảng cách giữa các hàng tên + khoảng trống thêm bên dưới (để về sau chọn được nhiều khí vận hơn).
-- Vùng chứa vừa 3 hàng x 3 tên = 9 khí vận. Muốn thêm chỗ nữa: tăng FORT_EXTRA (các cột bên dưới tự lùi xuống, nhưng đáy bảng có hạn).
local FORT_ROW_H = 42 -- bước giữa 2 hàng tên
local FORT_TILE_H = 34 -- chiều cao mỗi thanh tên
local FORT_EXTRA = 30 -- chỗ trống thêm so với bản cũ (đơn vị bảng)
local ATTR_ROW_H = 26 -- bước hàng May mắn / Mị lực / ... (cột 1)
local FBONUS_SIZE = 19 -- cỡ chữ vàng "Khí vận: ..." dưới cột Thuộc tính
local FTIP_W, FTIP_SIZE = 420, 24 -- cửa sổ chỉ số khi rê chuột vào tên khí vận

local COL_W = 232
local COL_PITCH = 246
local COL_X = {} -- 5 cột, cột 3 ở giữa
for i = 1, 5 do COL_X[i] = (i - 3) * COL_PITCH end
local FONT = 24
local GOLD = { 1.0, 0.85, 0.4, 1 }
local WHITE = { 1, 1, 1, 1 }
local GREY = { 0.7, 0.7, 0.7, 1 }
-- màu chữ đặt trực tiếp lên nền giấy sáng (GOLD/WHITE/GREY ở trên chỉ dùng trên thanh tối)
local INK = { 0.13, 0.11, 0.09, 1 }
local INK_GREY = { 0.45, 0.42, 0.38, 1 }
local INK_GOLD = { 0.62, 0.38, 0.02, 1 }
local INK_FOCUS = { 0.05, 0.03, 0.0, 1 }
local INK_RED = { 0.68, 0.12, 0.1, 1 }
local INK_LORE = { 0.27, 0.23, 0.16, 1 }
local STAT_COLOURS = {
    hp = { 0.85, 0.2, 0.2, 1 },
    hunger = { 0.95, 0.6, 0.2, 1 },
    sanity = { 0.7, 0.45, 0.9, 1 },
    qi = { 0.3, 0.65, 1.0, 1 },
    xp = { 1.0, 0.85, 0.4, 1 },
}

local SQUARE = { "images/global.xml", "square.tex" }

local function MakeText(parent, str, size, colour, x, y, w, align)
    local t = parent:AddChild(Text(UIFONT, size or FONT, str or ""))
    t:SetColour(unpack(colour or WHITE))
    if w ~= nil then
        t:SetRegionSize(w, (size or FONT) + 8)
        t:SetHAlign(align or ANCHOR_MIDDLE)
        -- text căn trái/phải: tâm vùng chữ đặt đúng giữa vùng
    end
    t:SetPosition(x or 0, y or 0, 0)
    return t
end

local function MakeRect(parent, w, h, colour, x, y)
    local r = parent:AddChild(Image(SQUARE[1], SQUARE[2]))
    r:SetTint(unpack(colour))
    r:SetSize(w, h)
    r:SetPosition(x or 0, y or 0, 0)
    return r
end

-- icon vừa khung box x box, giữ tỉ lệ (icon nhỏ được phóng tối đa 2.5 lần)
local function MakeIcon(parent, atlas, tex, box, x, y)
    local img = parent:AddChild(Image(atlas, tex))
    local w, h = img:GetSize()
    if w ~= nil and h ~= nil and w > 0 and h > 0 then
        local s = math.min(box / w, box / h, 2.5)
        img:SetSize(w * s, h * s)
    else
        img:SetSize(box, box)
    end
    img:SetPosition(x, y, 0)
    return img
end

-- thanh có chữ "cur/max": trả về { SetValue = function(cur, max) }
local function MakeStat(parent, label, colour, cx, y, icon)
    local left = cx - COL_W / 2
    local lx = left + 70
    if icon ~= nil then
        MakeIcon(parent, TRAIT_ATLAS, icon, 24, left + 12, y)
        lx = left + 32 + 70
    end
    MakeText(parent, label, FONT, INK, lx, y, 140, ANCHOR_LEFT)
    local val = MakeText(parent, "0/0", FONT, INK, cx + COL_W / 2 - 60, y, 120, ANCHOR_RIGHT)
    MakeRect(parent, COL_W, 10, { 0, 0, 0, 0.8 }, cx, y - 20)
    local fill = MakeRect(parent, COL_W, 6, colour, cx, y - 20)
    return {
        SetValue = function(cur, max)
            max = math.max(max or 1, 1)
            cur = math.max(0, math.min(cur or 0, max))
            val:SetString(string.format("%d/%d", math.floor(cur + 0.5), math.floor(max + 0.5)))
            local w = math.max(1, (COL_W - 4) * cur / max)
            fill:SetSize(w, 6)
            fill:SetPosition(cx - (COL_W - 4) / 2 + w / 2, y - 20, 0)
        end,
    }
end

-- đọc netvar số của player, không có thì 0
local function NV(p, name)
    local nv = name ~= nil and p[name] or nil
    return nv ~= nil and tonumber(nv:value()) or 0
end

-- Di tốc (%) do cổ trùng đang trang bị, tính lại giống server (cosu_gu_bag: UpdateUloi / UpdateThachBi):
-- đọc netvar _cosu_gu_eq ("main,s1,...,s9"; 0 = ô trống), chỉ tính ô đã mở (ô n cần cảnh giới >= n, Bản Mệnh Cổ cần >= 1), người chơi chưa thành hồn ma.
--   U Lôi Huyễn Điệp Cổ: Bản Mệnh Cổ x1.3 (ưu tiên), không thì ô thường x1.2
--   Thạch Bì Cổ (chỉ 9 ô): x0.9
-- Hai hệ số nhân với nhau như SetExternalSpeedMultiplier của game (1.2 x 0.9 = +8%).
local function GuSpeedPct(p)
    if p:HasTag("playerghost") then return 0 end
    local rank = p._cosu_rank ~= nil and p._cosu_rank:value() or 0
    local str = p._cosu_gu_eq ~= nil and p._cosu_gu_eq:value() or ""
    local uloi_main, uloi_slot, thachbi = false, false, false
    local i = 0
    for n in string.gmatch(str, "%d+") do
        i = i + 1
        local gu = GU.LIST[tonumber(n)]
        local usable = i == 1 and rank >= 1 or (i > 1 and rank >= i - 1)
        if gu ~= nil and usable then
            if gu.passive_elec then
                if i == 1 then uloi_main = true else uloi_slot = true end
            end
            if gu.passive_thachbi and i > 1 then thachbi = true end
        end
    end
    local mult = 1
    if uloi_main then mult = mult * GU.ULOI.SPEED_MAIN elseif uloi_slot then mult = mult * GU.ULOI.SPEED_SLOT end
    if thachbi then mult = mult * GU.THACHBI.SPEED_MULT end
    return math.floor((mult - 1) * 100 + 0.5)
end

local ROW_ICON, ROW_FONT, ROW_BOX = 24, 19, 52

-- cột các hàng "icon + tên + ô số"; trả về danh sách để UpdateRows cập nhật số
local function MakeRows(parent, cx, top, rows, row_h)
    local list = {}
    local left = cx - COL_W / 2
    local lw = COL_W - ROW_ICON - 8 - ROW_BOX - 8
    for i, r in ipairs(rows) do
        local y = top - (i - 0.5) * row_h
        local icon = MakeIcon(parent, TRAIT_ATLAS, r.icon, ROW_ICON, left + ROW_ICON / 2, y)
        local label = MakeText(parent, r.label, ROW_FONT, INK_GREY, left + ROW_ICON + 8 + lw / 2, y, lw, ANCHOR_LEFT)
        MakeRect(parent, ROW_BOX, row_h - 6, { 0, 0, 0, 0.9 }, cx + COL_W / 2 - ROW_BOX / 2, y)
        local val = MakeText(parent, "0", ROW_FONT, GREY, cx + COL_W / 2 - ROW_BOX / 2, y)
        table.insert(list, { row = r, icon = icon, label = label, val = val })
    end
    return list
end

local function UpdateRows(p, list, fs)
    for _, e in ipairs(list) do
        local r = e.row
        local add = r.fkey ~= nil and (fs[r.fkey] or 0) or 0
        if r.fall ~= nil then add = add + (fs[r.fall] or 0) end -- fall: chỉ số cộng chung cho cả nhóm (Công pháp -> 6 hàng công pháp)
        local gadd = r.gukind == "speed" and GuSpeedPct(p) or 0 -- phần cộng từ cổ trùng
        local net = add + gadd
        local v = NV(p, r.nv) + net
        local sfx = r.suffix
        if sfx == nil and r.fkey ~= nil and FT.STAT_BY_KEY[r.fkey] ~= nil then sfx = FT.STAT_BY_KEY[r.fkey].suffix end
        e.val:SetString(v .. (sfx or ""))
        local c
        if net < 0 or v < 0 then
            c = { 1, 0.45, 0.4, 1 } -- khí vận / cổ trùng làm giảm chỉ số này
        elseif v > 0 then
            c = net > 0 and GOLD or WHITE
        else
            c = GREY
        end
        e.val:SetColour(unpack(c))
        e.label:SetColour(unpack(v ~= 0 and INK or INK_GREY))
        local t = v ~= 0 and 1 or 0.5
        e.icon:SetTint(t, t, t, 1)
    end
end

-- đoạn chữ nhiều dòng, tự xuống dòng trong vùng w x h (căn trái, bắt đầu từ trên)
local function MakeWrap(parent, str, size, colour, x, y, w, h)
    local t = parent:AddChild(Text(UIFONT, size, str or ""))
    t:SetColour(unpack(colour or WHITE))
    t:SetRegionSize(w, h)
    t:EnableWordWrap(true)
    t:SetHAlign(ANCHOR_LEFT)
    t:SetVAlign(ANCHOR_TOP)
    t:SetPosition(x, y, 0)
    return t
end

local ID_TO_PREFAB
local function GuPrefab(id)
    if ID_TO_PREFAB == nil then
        ID_TO_PREFAB = {}
        for prefab, gid in pairs(GU.ID) do ID_TO_PREFAB[gid] = prefab end
    end
    return ID_TO_PREFAB[id]
end

-- danh sách số thứ tự cổ trùng đã luyện hóa (cả chưa trang bị lẫn đã trang bị), không trùng
local function CollectGu(p)
    local ids, seen, key = {}, {}, ""
    for _, nv in ipairs({ p._cosu_gu, p._cosu_gu_eq }) do
        local str = nv ~= nil and nv:value() or ""
        key = key .. "|" .. str
        for n in string.gmatch(str, "%d+") do
            n = tonumber(n)
            if n > 0 and not seen[n] and GU.LIST[n] ~= nil and GuPrefab(n) ~= nil then
                seen[n] = true
                table.insert(ids, n)
            end
        end
    end
    table.sort(ids)
    return ids, key
end

local function GuMeta(id)
    local prefab = GuPrefab(id)
    local gu = GU.LIST[id]
    local C = ELEM.COMBAT
    local info = CI.GU_INFO[prefab] or {}
    return {
        prefab = prefab,
        name = STRINGS.NAMES[string.upper(prefab)] or prefab,
        atlas = gu.atlas or ("images/inventoryimages/" .. prefab .. ".xml"),
        image = gu.image or (prefab .. ".tex"),
        elem = gu.elem or C.GU_ELEM[prefab],
        value = C.GU_ROOT_VALUE[prefab] or C.GU_ROOT_DEFAULT,
        rank = gu.rank or info.rank or 1, -- ưu tiên rank khai báo trong cosu_gu_tuning.LIST
        skills = info.skills or "Chưa có mô tả kỹ năng.",
        lore = info.lore or "Chưa có mô tả.",
    }
end

local function GetStat(comp)
    if comp == nil then return 0, 1 end
    local max = comp.Max ~= nil and comp:Max() or (comp.GetMax ~= nil and comp:GetMax()) or 1
    local cur
    if comp.GetCurrent ~= nil then
        cur = comp:GetCurrent()
    elseif comp.GetPercent ~= nil then
        cur = comp:GetPercent() * max
    else
        cur = 0
    end
    return cur, max
end

-- độ đói (phần trăm) của cổ trùng id, từ netvar "id:phần trăm,..."
local function GuHungerPct(p, id)
    local str = p._cosu_gu_hunger ~= nil and p._cosu_gu_hunger:value() or ""
    for i, v in string.gmatch(str, "(%d+):(%d+)") do
        if tonumber(i) == id then return tonumber(v) end
    end
    return nil
end

-- đồ ăn cho cổ trong túi + balo, gộp theo prefab, sắp theo tên
local function CollectFoods(p)
    local list, index = {}, {}
    local function add(item)
        if item == nil or not item:IsValid() or not item:HasOneOfTags(GU.HUNGER.FEED_TAGS) then return end
        local ir = item.replica.inventoryitem
        if ir == nil then return end
        local n = item.replica.stackable ~= nil and item.replica.stackable:StackSize() or 1
        local e = index[item.prefab]
        if e == nil then
            e = { prefab = item.prefab, name = item:GetDisplayName(), atlas = ir:GetAtlas(), image = ir:GetImage(), count = 0 }
            index[item.prefab] = e
            table.insert(list, e)
        end
        e.count = e.count + n
    end
    local inv = p.replica.inventory
    if inv ~= nil then
        for _, item in pairs(inv:GetItems() or {}) do add(item) end
        local oc = inv:GetOverflowContainer()
        if oc ~= nil then
            for _, item in pairs(oc:GetItems() or {}) do add(item) end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local HB_X, HB_W, HB_Y = -420, 250, PAPER_TOP - 322 -- thanh đói (cột trái trang chi tiết cổ trùng)
local FEED_COLS, FEED_PAGE = 6, 18

local CosuCharInfo = Class(Widget, function(self, owner)
    Widget._ctor(self, "CosuCharInfo")
    self.owner = owner
    self:SetHAnchor(ANCHOR_MIDDLE)
    self:SetVAnchor(ANCHOR_MIDDLE)
    self:SetScaleMode(SCALEMODE_PROPORTIONAL)

    self.root = self:AddChild(Widget("root"))
    self.root:SetScale((CI.SCALE or 1) * FIT * UI_SCALE)

    -- nền: ảnh khung tranh thủy mặc (CI.BG_ALPHA không còn dùng); tiêu đề + gợi ý nằm trên thanh khung
    local bg = self.root:AddChild(Image(UI.bg[1], UI.bg[2]))
    bg:SetSize(BG_W, BG_H)
    bg:SetPosition(0, 0, 0)
    MakeText(self.root, CI.TITLE, 28, GOLD, 0, BAR_Y)
    MakeText(self.root, "Nhấn " .. (CI.KEY or "B") .. " để đóng", 18, GREY, BG_W / 2 - 297 * BG_K - 120, BAR_Y, 240, ANCHOR_RIGHT)

    self.status = self.root:AddChild(Widget("status"))
    local function Header(cx, w, name, y)
        MakeRect(self.status, w, 34, { 0, 0, 0, 0.8 }, cx, y)
        MakeText(self.status, name, 26, WHITE, cx, y)
    end

    -- hàng trên: Cảnh giới (cột 1-2) | Tiên Thiên Khí Vận (cột 3-5)
    local head_y = PAPER_TOP - 38
    local rank_cx = (COL_X[1] + COL_X[2]) / 2
    local rank_w = COL_X[2] - COL_X[1] + COL_W
    local fort_cx = COL_X[4]
    local fort_w = COL_X[5] - COL_X[3] + COL_W
    Header(rank_cx, rank_w, "Cảnh giới", head_y)
    Header(fort_cx, fort_w, FT.TEXT.SECTION, head_y)

    self.rank_text = MakeText(self.status, "", 34, INK_GOLD, rank_cx - 110, head_y - 46)
    self.stage_text = MakeText(self.status, "", 26, INK, rank_cx + 140, head_y - 46)
    MakeText(self.status, "Tu vi", FONT, INK, rank_cx - rank_w / 2 + 70, head_y - 88, 140, ANCHOR_LEFT)
    self.xp_text = MakeText(self.status, "", FONT, INK, rank_cx + rank_w / 2 - 80, head_y - 88, 160, ANCHOR_RIGHT)
    local xp_y = head_y - 108
    MakeRect(self.status, rank_w, 10, { 0, 0, 0, 0.8 }, rank_cx, xp_y)
    self.xp_fill = MakeRect(self.status, rank_w - 4, 6, STAT_COLOURS.xp, rank_cx, xp_y)
    self.xp_cx, self.xp_w, self.xp_y = rank_cx, rank_w, xp_y

    -- Tiên Thiên Khí Vận: tên khí vận (dựng lại khi đổi)
    self.fortune_box = self.status:AddChild(Widget("fortune_box"))
    self.fortune_box:SetPosition(fort_cx, head_y, 0)
    self.fortune_key = nil
    self.fort_cx, self.head_y = fort_cx, head_y

    -- hàng dưới: 5 cột
    local sec_y = head_y - 140 - FORT_EXTRA
    local top = sec_y - 34
    for i, name in ipairs({ "Thuộc tính", "Chiến đấu", "Công pháp", "Linh Căn", "Kỹ nghệ" }) do
        Header(COL_X[i], COL_W, name, sec_y)
    end

    -- cột 1: thuộc tính (bốn thanh + may mắn, mị lực, danh vọng, ma đạo, chính đạo)
    local y = sec_y - 52
    self.stats = {
        hp = MakeStat(self.status, "Sinh Lực", STAT_COLOURS.hp, COL_X[1], y, STAT_ICON.hp),
        hunger = MakeStat(self.status, "Đói", STAT_COLOURS.hunger, COL_X[1], y - 46, STAT_ICON.hunger),
        sanity = MakeStat(self.status, "Tỉnh Táo", STAT_COLOURS.sanity, COL_X[1], y - 92, STAT_ICON.sanity),
        qi = MakeStat(self.status, "Nguyên Khí", STAT_COLOURS.qi, COL_X[1], y - 138, STAT_ICON.qi),
    }
    local attr_top = y - 138 - 30
    self.attr_rows = MakeRows(self.status, COL_X[1], attr_top, ATTR_ROWS, ATTR_ROW_H)
    -- chỉ số khí vận chưa có hàng riêng (sinh lực / nguyên khí tối đa, ngộ tính, tinh lực...), chỉ hiện khi có
    self.fbonus = MakeWrap(self.status, "", FBONUS_SIZE, INK_GOLD, COL_X[1], attr_top - #ATTR_ROWS * ATTR_ROW_H - 37, COL_W, 66)

    -- cột 2: chiến đấu | cột 3: công pháp | cột 5: kỹ nghệ
    self.combat_rows = MakeRows(self.status, COL_X[2], top, COMBAT_ROWS, 38)
    self.art_rows = MakeRows(self.status, COL_X[3], top, ART_ROWS, 40)
    self.skill_rows = MakeRows(self.status, COL_X[5], top, SKILL_ROWS, 40)

    -- rê chuột vào chỉ số -> giải thích (chỉ các chỉ số có trong TIPS)
    for i, key in ipairs({ "hp", "hunger", "sanity", "qi" }) do
        local hy = y - (i - 1) * 46 - 8
        self:AddHover(self.status, COL_W, 44, COL_X[1], hy, COL_X[1], hy, "tip_" .. key, function() return TipText(TIPS[key]) end)
    end
    self:AddRowHovers(self.attr_rows, COL_X[1], attr_top, ATTR_ROW_H)
    self:AddRowHovers(self.combat_rows, COL_X[2], top, 38)
    self.roots_top = top

    -- cột 4: linh căn (dựng lại khi đổi)
    self.roots_box = self.status:AddChild(Widget("roots_box"))
    self.roots_box:SetPosition(COL_X[4], top, 0)
    self.roots_str = nil

    -- thanh Linh Thạch ở đáy tab Trạng thái (tiền tệ; không nằm trong túi đồ)
    do
        local LT_Y = (BgY(950) - PAPER_TOP * (1 - CONTENT_K)) / CONTENT_K + 26 -- sát đáy giấy; chỉnh số 26 để nâng/hạ
        local LT_W = COL_X[5] - COL_X[1] + COL_W
        MakeRect(self.status, LT_W, 34, { 0, 0, 0, 0.8 }, 0, LT_Y)
        MakeIcon(self.status, "images/inventoryimages/cosu_linhthach.xml", "cosu_linhthach.tex", 30, -80, LT_Y)
        MakeText(self.status, "Linh Thạch", 26, WHITE, -20, LT_Y, 140, ANCHOR_LEFT)
        self.linhthach_text = MakeText(self.status, "0", 26, GOLD, 150, LT_Y, 240, ANCHOR_LEFT)
    end

    self:BuildFortuneTip() -- tạo sau cùng để luôn nằm trên mọi thứ trong tab Trạng thái
    self:BuildGuPage()
    -- thu nội dung vào trong viền khung, giữ mép trên thẳng hàng với giấy
    for _, w in ipairs({ self.status, self.gu_page }) do
        w:SetScale(CONTENT_K, CONTENT_K, 1)
        w:SetPosition(0, PAPER_TOP * (1 - CONTENT_K), 0)
    end
    self:BuildTabs()
    self:BuildFeedPanel()
    self.tab = "status"
    self:SetTab("status")

    self.next_update = 0
    self:Hide()
end)

----------------------------------------------------------------- Tab
-- Tab dọc bên trái khung (giống bảng nhân vật gốc): icon tròn, tên tab đè ở đáy icon.
-- Tab đặt nằm ngang trên thanh tiêu đề (trước đây nằm dọc, đè lên cột Thuộc tính / Cảnh giới).
local TAB_X0, TAB_Y, TAB_STEP, TAB_SIZE = -BG_W / 2 + 190 * BG_K, BAR_Y, 56, 46

function CosuCharInfo:BuildTabs()
    local s = TAB_SIZE / 74 -- ảnh gốc 74px
    self.tab_labels = {}
    local function tab(img, label, index, name)
        local x, y = TAB_X0 + (index - 1) * TAB_STEP, TAB_Y
        local b = self.root:AddChild(ImageButton(img[1], img[2], img[2], img[2], img[2]))
        b:SetNormalScale(s, s, 1)
        b:SetFocusScale(s * 1.1, s * 1.1, 1)
        b:SetPosition(x, y, 0)
        b:SetOnClick(function() self:SetTab(name) end)
        -- rê chuột vào thì sáng lên; rời ra thì trả về theo tab đang chọn
        local gain, lose = b.OnGainFocus, b.OnLoseFocus
        b.OnGainFocus = function(btn)
            gain(btn)
            btn.image:SetTint(1, 1, 1, 1)
        end
        b.OnLoseFocus = function(btn)
            lose(btn)
            self:ApplyTabTint()
        end
        local t = self.root:AddChild(Text(NEWFONT_OUTLINE or UIFONT, 14, label or ""))
        t:SetPosition(x, y - TAB_SIZE / 2 + 7, 0)
        t:SetClickable(false)
        self.tab_labels[name] = t
        return b
    end
    self.tab_status = tab(UI.tab_status, CI.TAB_STATUS, 1, "status")
    self.tab_gu = tab(UI.tab_gu, CI.TAB_GU, 2, "gu")
end

-- tab đang chọn sáng đủ + chữ vàng, tab kia mờ đi
function CosuCharInfo:ApplyTabTint()
    local function tint(b, name, on)
        if b == nil or b.image == nil then return end
        local c = on and 1 or 0.55
        b.image:SetTint(c, c, c, 1)
        local t = self.tab_labels ~= nil and self.tab_labels[name] or nil
        if t ~= nil then
            local k = on and GOLD or WHITE
            t:SetColour(k[1], k[2], k[3], k[4])
        end
    end
    tint(self.tab_status, "status", self.tab ~= "gu")
    tint(self.tab_gu, "gu", self.tab == "gu")
end

function CosuCharInfo:SetTab(name)
    self.tab = name
    if name == "gu" then
        self.status:Hide()
        self.gu_page:Show()
        self.gu_key = nil
        self:ShowGuList()
    else
        self:CloseFeed()
        self:HideFortuneTip()
        self.gu_page:Hide()
        self.status:Show()
        self.roots_str = nil
        self.fortune_key = nil
    end
    self:ApplyTabTint()
    self:Refresh()
end

----------------------------------------------------------------- Trang cổ trùng
function CosuCharInfo:BuildGuPage()
    self.gu_page = self.root:AddChild(Widget("gu_page"))
    self.gu_list = self.gu_page:AddChild(Widget("gu_list"))
    self.gu_detail = self.gu_page:AddChild(Widget("gu_detail"))
    self.gu_detail:Hide()
    self.gu_page:Hide()
end

function CosuCharInfo:ShowGuList()
    self:CloseFeed()
    self.hg_fill = nil
    self.gu_detail:Hide()
    self.gu_list:Show()
    self.detail_id = nil
end

local function NC(w) w:SetClickable(false) return w end
local function RankName(m) return ELEM.COMBAT.RANK_NAMES[m.rank] or (m.rank .. " Chuyển") end
local function Bright(t) return { math.min(1, t[1] * 1.15 + 0.2), math.min(1, t[2] * 1.15 + 0.2), math.min(1, t[3] * 1.15 + 0.2), 1 } end
local GOLD_EDGE = { 0.75, 0.6, 0.3, 0.9 }
local CARD_W, CARD_H, CARD_GAP, CARD_COLS, CARD_ROWS = 280, 112, 14, 4, 4
local CARD_PAGE = CARD_COLS * CARD_ROWS
local LIST_W = CARD_COLS * CARD_W + (CARD_COLS - 1) * CARD_GAP

-- thanh độ đói: fill căn trái tại `left`, rộng tối đa w
local function SetBar(fill, left, y, w, pct)
    local fw = math.max(1, w * pct / 100)
    fill:SetSize(fw, 6)
    fill:SetPosition(left + fw / 2, y, 0)
    local c = pct <= GU.HUNGER.WARN * 100 and STAT_COLOURS.hp or STAT_COLOURS.hunger
    fill:SetTint(c[1], c[2], c[3], c[4])
end

-- nút nền chữ nhật tối (hover sáng lên), chữ/icon vẽ đè lên phải SetClickable(false)
local function MakePanelButton(parent, w, h, x, y, onclick)
    MakeRect(parent, w + 4, h + 4, GOLD_EDGE, x, y)
    local b = parent:AddChild(ImageButton(SQUARE[1], SQUARE[2], SQUARE[2], SQUARE[2], SQUARE[2]))
    b:SetImageNormalColour(0.08, 0.08, 0.1, 0.88)
    b:SetImageFocusColour(0.22, 0.17, 0.08, 0.95)
    -- phóng ảnh nút cho vừa w x h bằng scale (ForceImageSize không ăn nên ảnh gốc nhỏ hiện thành ô vuông đen)
    local bw, bh = b.image:GetSize()
    if bw == nil or bw <= 0 then bw = 1 end
    if bh == nil or bh <= 0 then bh = 1 end
    local sx, sy = w / bw, h / bh
    b:SetNormalScale(sx, sy, 1)
    b:SetFocusScale(sx * 1.02, sy * 1.04, 1)
    b:SetPosition(x, y, 0)
    b:SetOnClick(onclick)
    return b
end

function CosuCharInfo:BuildGuList(ids)
    local L = self.gu_list
    L:KillAllChildren()
    self.card_hunger = {}
    self.gu_ids = ids
    local bar_y = PAPER_TOP - 26
    MakeRect(L, LIST_W, 34, { 0, 0, 0, 0.8 }, 0, bar_y)
    MakeText(L, "Cổ trùng đã luyện hóa" .. (#ids > 0 and (" (" .. #ids .. ")") or ""), 26, WHITE, 0, bar_y)
    if #ids == 0 then
        MakeText(L, CI.NO_GU_TEXT, FONT, INK_GREY, 0, 20)
        return
    end

    local pages = math.max(1, math.ceil(#ids / CARD_PAGE))
    self.gu_pageno = math.max(1, math.min(self.gu_pageno or 1, pages))
    local first = (self.gu_pageno - 1) * CARD_PAGE
    for n = 1, CARD_PAGE do
        local id = ids[first + n]
        if id == nil then break end
        local m = GuMeta(id)
        local col = (n - 1) % CARD_COLS
        local row = math.floor((n - 1) / CARD_COLS)
        local x = -LIST_W / 2 + CARD_W / 2 + col * (CARD_W + CARD_GAP)
        local y = PAPER_TOP - 64 - CARD_H / 2 - row * (CARD_H + CARD_GAP)
        MakePanelButton(L, CARD_W, CARD_H, x, y, function() self:OpenGuDetail(id) end)

        -- icon cổ trùng
        local ix = x - CARD_W / 2 + 56
        NC(MakeRect(L, 92, 92, { 0, 0, 0, 0.6 }, ix, y))
        local img = NC(L:AddChild(Image(m.atlas, m.image)))
        img:SetSize(78, 78)
        img:SetPosition(ix, y, 0)

        -- chữ bên phải icon: tên / cảnh giới / linh căn / thanh đói
        local tx, tw = x - CARD_W / 2 + 112 + 84, 168
        NC(MakeWrap(L, m.name, 21, GOLD, tx, y + 6, tw, 60))
        local bl, by = tx - tw / 2, y - 38
        NC(MakeRect(L, tw, 8, { 0, 0, 0, 0.9 }, tx, by))
        local fill = NC(MakeRect(L, tw - 4, 4, STAT_COLOURS.hunger, tx, by))
        self.card_hunger[id] = { fill = fill, left = bl + 2, y = by, w = tw - 4 }
        SetBar(fill, bl + 2, by, tw - 4, GuHungerPct(self.owner, id) or 100)
    end

    if pages > 1 then
        local py = PAPER_TOP - 64 - CARD_ROWS * (CARD_H + CARD_GAP) - 22
        local function pbtn(label, x, delta)
            local b = L:AddChild(TextButton())
            b:SetFont(UIFONT)
            b:SetTextSize(30)
            b:SetText(label)
            b:SetTextColour(unpack(INK))
            b:SetTextFocusColour(unpack(INK_GOLD))
            b:SetPosition(x, py, 0)
            b:SetOnClick(function()
                self.gu_pageno = math.max(1, math.min(pages, (self.gu_pageno or 1) + delta))
                self.gu_key = nil -- dựng lại ở lượt Refresh kế tiếp
            end)
        end
        pbtn("<", -70, -1)
        MakeText(L, self.gu_pageno .. " / " .. pages, 24, INK, 0, py)
        pbtn(">", 70, 1)
    end
end

function CosuCharInfo:OpenGuDetail(id)
    local m = GuMeta(id)
    self.detail_id = id
    local d = self.gu_detail
    d:KillAllChildren()
    self.gu_list:Hide()
    d:Show()
    local top = PAPER_TOP
    local rank_name = RankName(m)

    -- thanh tiêu đề + nút quay lại
    MakeRect(d, LIST_W, 34, { 0, 0, 0, 0.8 }, 0, top - 26)
    MakeText(d, "Chi tiết cổ trùng", 26, WHITE, 0, top - 26)
    local back = d:AddChild(TextButton())
    back:SetFont(UIFONT)
    back:SetTextSize(22)
    back:SetText("< Quay lại")
    back:SetTextColour(0.85, 0.85, 0.85, 1)
    back:SetTextFocusColour(unpack(GOLD))
    back:SetPosition(-LIST_W / 2 + 70, top - 26, 0)
    back:SetOnClick(function() self:ShowGuList() end)

    -- cột trái: ảnh lớn, độ đói, nút cho ăn
    local LX = HB_X
    MakeRect(d, 212, 212, GOLD_EDGE, LX, top - 170)
    MakeRect(d, 204, 204, { 0.06, 0.06, 0.08, 0.9 }, LX, top - 170)
    local img = d:AddChild(Image(m.atlas, m.image))
    img:SetSize(176, 176)
    img:SetPosition(LX, top - 170, 0)

    local hleft = HB_X - HB_W / 2
    MakeText(d, "Độ đói", 22, INK, hleft + 45, HB_Y + 22, 90, ANCHOR_LEFT)
    self.hg_text = MakeText(d, "100%", 22, INK, HB_X + HB_W / 2 - 40, HB_Y + 22, 80, ANCHOR_RIGHT)
    MakeRect(d, HB_W, 10, { 0, 0, 0, 0.8 }, HB_X, HB_Y)
    self.hg_fill = MakeRect(d, HB_W - 4, 6, STAT_COLOURS.hunger, HB_X, HB_Y)
    local fy = HB_Y - 50
    MakePanelButton(d, 200, 42, LX, fy, function() self:OpenFeed(id) end)
    NC(MakeText(d, "Cho ăn", 26, GOLD, LX, fy))
    MakeText(d, "Đói về 0 là cổ chết vĩnh viễn", 17, INK_RED, LX, fy - 38, 280, ANCHOR_MIDDLE)
    self:UpdateGuHunger()

    -- đường kẻ ngăn hai cột
    MakeRect(d, 2, 560, { 0, 0, 0, 0.22 }, -272, top - 330)

    -- cột phải: tên, chip cảnh giới + linh căn, điều kiện, kỹ năng, mô tả
    local RX, RW = 170, 820
    local rl = RX - RW / 2
    MakeText(d, m.name, 40, INK_GOLD, RX, top - 86, RW, ANCHOR_LEFT)

    MakeRect(d, 174, 36, GOLD_EDGE, rl + 87, top - 142)
    MakeRect(d, 170, 32, { 0.06, 0.06, 0.08, 0.92 }, rl + 87, top - 142)
    MakeText(d, rank_name, 22, GOLD, rl + 87, top - 142)
    local e = m.elem ~= nil and BY_ID[m.elem] or nil
    if e ~= nil then
        local cw = 330
        local cx = rl + 174 + 14 + cw / 2
        MakeRect(d, cw + 4, 36, { e.tint[1], e.tint[2], e.tint[3], 1 }, cx, top - 142)
        MakeRect(d, cw, 32, { 0.06, 0.06, 0.08, 0.92 }, cx, top - 142)
        MakeText(d, "Cộng " .. e.label .. " linh căn: " .. m.value, 22, Bright(e.tint), cx, top - 142)
    end

    local US = GU.UNEQUIP_STONE
    MakeText(d, "Luyện hóa: cần cảnh giới " .. rank_name, 20, INK_GREY, RX, top - 192, RW, ANCHOR_LEFT)
    MakeText(d, "Gỡ cổ: " .. US.main.name .. " (Bản Mệnh Cổ), " .. US.slot.name .. " (ô khác)", 20, INK_GREY, RX, top - 218, RW, ANCHOR_LEFT)

    MakeRect(d, RW, 30, { 0, 0, 0, 0.8 }, RX, top - 262)
    MakeText(d, "Kỹ năng", 24, WHITE, RX, top - 262)
    MakeWrap(d, m.skills, 22, INK, RX, top - 278 - 65, RW - 12, 130)

    MakeRect(d, RW, 30, { 0, 0, 0, 0.8 }, RX, top - 430)
    MakeText(d, "Mô tả", 24, WHITE, RX, top - 430)
    MakeWrap(d, m.lore, 22, INK_LORE, RX, top - 446 - 80, RW - 12, 160)
end

function CosuCharInfo:UpdateGuHunger()
    if self.card_hunger ~= nil and self.gu_list.shown then
        for id, c in pairs(self.card_hunger) do
            SetBar(c.fill, c.left, c.y, c.w, GuHungerPct(self.owner, id) or 100)
        end
    end
    if self.detail_id == nil or self.hg_fill == nil then return end
    local pct = GuHungerPct(self.owner, self.detail_id) or 100
    SetBar(self.hg_fill, HB_X - (HB_W - 4) / 2, HB_Y, HB_W - 4, pct)
    self.hg_text:SetString(pct .. "%")
end

----------------------------------------------------------------- Cho ăn
function CosuCharInfo:BuildFeedPanel()
    self.feed_panel = self.root:AddChild(Widget("feed_panel"))
    self.feed_panel:Hide()
end

function CosuCharInfo:OpenFeed(id)
    self.feed_id = id
    self.feed_page = 1
    self.feed_key = nil
    self.feed_panel:Show()
    self:RefreshFeed()
end

function CosuCharInfo:CloseFeed()
    if self.feed_panel ~= nil then self.feed_panel:Hide() end
    self.feed_id = nil
    self.feed_key = nil
end

function CosuCharInfo:RefreshFeed()
    if self.feed_id == nil or not self.feed_panel.shown then return end
    local foods = CollectFoods(self.owner)
    local parts = { self.feed_page, GuHungerPct(self.owner, self.feed_id) or 100 }
    for _, f in ipairs(foods) do table.insert(parts, f.prefab .. "=" .. f.count) end
    local key = table.concat(parts, "|")
    if key == self.feed_key then return end
    self.feed_key = key
    self:BuildFeed(foods)
end

-- Lưu ý: bấm nút trang chỉ đổi số trang rồi xóa feed_key; bảng được dựng lại ở lượt Refresh kế tiếp
-- (không xóa nút ngay trong lúc nó đang xử lý cú bấm).
function CosuCharInfo:BuildFeed(foods)
    local p = self.feed_panel
    p:KillAllChildren()
    MakeRect(p, 646, 386, { 0.75, 0.6, 0.3, 0.9 }, 0, 0)
    MakeRect(p, 640, 380, { 0.05, 0.05, 0.07, 0.97 }, 0, 0)

    local m = GuMeta(self.feed_id)
    local pct = GuHungerPct(self.owner, self.feed_id) or 100
    MakeText(p, "Cho " .. m.name .. " ăn", 28, GOLD, 0, 165)
    MakeText(p, "Độ đói: " .. pct .. "%  -  chọn món trong túi / balo", 20, GREY, 0, 135)

    local pages = math.max(1, math.ceil(#foods / FEED_PAGE))
    if self.feed_page > pages then self.feed_page = pages end
    if #foods == 0 then
        MakeText(p, "Trong người không có đồ ăn nào cổ trùng ăn được.", FONT, GREY, 0, 10)
    end
    local first = (self.feed_page - 1) * FEED_PAGE
    for n = 1, FEED_PAGE do
        local f = foods[first + n]
        if f == nil then break end
        local col = (n - 1) % FEED_COLS
        local row = math.floor((n - 1) / FEED_COLS)
        local x = (col - (FEED_COLS - 1) / 2) * 100
        local y = 85 - row * 100
        local btn = p:AddChild(ImageButton(f.atlas, f.image, f.image, f.image, f.image))
        btn:SetNormalScale(0.9, 0.9, 1)
        btn:SetFocusScale(1.05, 1.05, 1)
        btn:SetPosition(x, y, 0)
        local prefab = f.prefab
        btn:SetOnClick(function()
            SendModRPCToServer(MOD_RPC["cosu"]["gu_feed"], self.feed_id, prefab)
        end)
        MakeText(p, "x" .. f.count, 18, WHITE, x + 22, y - 22)
        local t = MakeWrap(p, f.name, 14, WHITE, x, y - 50, 92, 32)
        t:SetHAlign(ANCHOR_MIDDLE)
    end

    local function btn(label, x, onclick)
        local b = p:AddChild(TextButton())
        b:SetFont(UIFONT)
        b:SetTextSize(24)
        b:SetText(label)
        b:SetTextColour(0.9, 0.9, 0.9, 1)
        b:SetTextFocusColour(1, 1, 1, 1)
        b:SetPosition(x, -168, 0)
        b:SetOnClick(onclick)
    end
    if pages > 1 then
        btn("<", -150, function()
            if self.feed_page > 1 then self.feed_page = self.feed_page - 1 self.feed_key = nil end
        end)
        MakeText(p, self.feed_page .. "/" .. pages, 22, WHITE, -100, -168)
        btn(">", -50, function()
            if self.feed_page < pages then self.feed_page = self.feed_page + 1 self.feed_key = nil end
        end)
    end
    btn("Đóng", 250, function() self:CloseFeed() end)
end

function CosuCharInfo:RefreshGu()
    self:UpdateGuHunger()
    self:RefreshFeed()
    local ids, key = CollectGu(self.owner)
    if key == self.gu_key then return end
    self.gu_key = key
    self:BuildGuList(ids)
    -- cổ đang xem mà không còn trong danh sách thì quay về danh sách
    if self.detail_id ~= nil then
        local still = false
        for _, id in ipairs(ids) do if id == self.detail_id then still = true end end
        if still then
            self.gu_list:Hide()
        else
            self:ShowGuList()
        end
    end
end

function CosuCharInfo:Toggle()
    if self.shown then
        self:Hide()
        self:StopUpdating()
    else
        self:Show()
        self.next_update = 0
        self.roots_str = nil
        self.gu_key = nil
        self:StartUpdating()
        self:SetTab(self.tab or "status")
    end
end

-- fs: cộng dồn khí vận { hoa = 20, ... }. Con số linh căn server gửi (netvar) ĐÃ gồm phần khí vận,
-- nên fs chỉ dùng để tô vàng ô có khí vận cộng vào.
local function ParseRoots(str, fs)
    local map = {}
    for id, v in string.gmatch(str or "", "(%w+):(%-?%d+)") do map[id] = tonumber(v) end -- chấp nhận số âm ("hoa:-10")
    local list = {}
    for _, e in ipairs(ELEM.LIST) do
        local key = FT.RootKeyOf(e)
        local add = key ~= nil and fs[key] or 0
        table.insert(list, { e = e, v = map[e.id] or 0, add = add }) -- hiện đủ mọi linh căn, chưa có thì 0
    end
    return list
end

function CosuCharInfo:BuildRoots(list, extras)
    self.roots_box:KillAllChildren()
    -- nhiều dòng quá thì thu hẹp khoảng cách dòng cho vừa khung
    local n = #list + #extras
    local ICON, BOX_W = 28, 60
    local row_h = math.min(38, 375 / (n + 0.5))
    local fs = 20
    local icon_x = -COL_W / 2 + ICON / 2
    local label_x = -COL_W / 2 + ICON + 8 + 70
    local function value(y, v, add, size)
        local c
        if v < 0 or add < 0 then
            c = { 1, 0.45, 0.4, 1 } -- âm, hoặc khí vận đang trừ linh căn này
        elseif v > 0 then
            c = add > 0 and GOLD or WHITE
        else
            c = GREY
        end
        MakeRect(self.roots_box, BOX_W, row_h - 6, { 0, 0, 0, 0.9 }, COL_W / 2 - BOX_W / 2, y)
        MakeText(self.roots_box, tostring(v), size, c, COL_W / 2 - BOX_W / 2, y)
        return c
    end
    for i, en in ipairs(list) do
        local y = -(i - 0.5) * row_h
        local custom = ROOT_ICON[en.e.id] or ROOT_ICON_BY_LABEL[en.e.label]
        local icon
        if custom ~= nil then
            icon = MakeIcon(self.roots_box, TRAIT_ATLAS, custom, ICON, icon_x, y)
        else
            icon = self.roots_box:AddChild(Image(en.e.root_atlas, en.e.root_image))
            icon:SetSize(ICON, ICON)
            icon:SetPosition(icon_x, y, 0)
        end
        if en.v <= 0 then icon:SetTint(0.5, 0.5, 0.5, 1) end
        local c = value(y, en.v, en.add, fs)
        local e = en.e
        self:AddHover(self.roots_box, COL_W, row_h - 2, 0, y, COL_X[4], self.roots_top + y, "tip_root_" .. e.id, function() return RootTip(e) end)
        MakeText(self.roots_box, en.e.label .. " linh căn", fs, en.v > 0 and INK or (en.v < 0 and INK_RED or INK_GREY), label_x, y, 140, ANCHOR_LEFT)
    end
    -- tư chất khác (luyện đan, mị lực, may mắn, ma đạo, chính đạo), nằm dưới các linh căn
    for j, ex in ipairs(extras) do
        local y = -(#list + j - 0.5) * row_h
        value(y, ex.v, ex.add, fs)
        local tex = TRAIT_ICON[ex.key]
        local lx, lw = -COL_W / 2 + 85, 170
        if tex ~= nil then
            local icon = MakeIcon(self.roots_box, TRAIT_ATLAS, tex, ICON, icon_x, y)
            if ex.v <= 0 then icon:SetTint(0.5, 0.5, 0.5, 1) end
            lx, lw = label_x, 140
        end
        MakeText(self.roots_box, ex.label, 20, ex.v > 0 and INK or INK_GREY, lx, y, lw, ANCHOR_LEFT)
    end
end

-- đếm số ký tự UTF-8 (tiếng Việt có dấu chiếm nhiều byte)
local function CharCount(str)
    local n = 0
    for i = 1, #str do
        local b = str:byte(i)
        if b < 128 or b >= 192 then n = n + 1 end
    end
    return n
end

-- Cửa sổ chỉ số khi rê chuột vào tên khí vận (giống bảng roll): viền vàng, nền tối, chữ trắng
function CosuCharInfo:BuildFortuneTip()
    self.ftip = self.status:AddChild(Widget("ftip"))
    self.ftip_border = NC(MakeRect(self.ftip, FTIP_W + 4, 40, { 0.75, 0.6, 0.3, 1 }, 0, 0))
    self.ftip_bg = NC(MakeRect(self.ftip, FTIP_W, 36, { 0.05, 0.05, 0.07, 1 }, 0, 0))
    self.ftip_text = self.ftip:AddChild(Text(UIFONT, FTIP_SIZE, ""))
    self.ftip_text:SetColour(unpack(WHITE))
    self.ftip_text:EnableWordWrap(true)
    self.ftip_text:SetHAlign(ANCHOR_MIDDLE)
    self.ftip_text:SetVAlign(ANCHOR_MIDDLE)
    self.ftip_text:SetClickable(false)
    self.ftip:Hide()
    self.ftip_id = nil
end

function CosuCharInfo:HideFortuneTip(id)
    if self.ftip == nil then return end
    if id ~= nil and self.ftip_id ~= id then return end -- tên khác đã giành hover rồi
    self.ftip_id = nil
    self.ftip:Hide()
end

-- Vùng bắt rê chuột trong suốt, kích thước w x h tại (px, py) trong parent; (ax, ay) = vị trí tương ứng trong tab Trạng thái
-- (dùng đặt cửa sổ giải thích). textfn trả về chữ giải thích, rỗng thì không hiện.
function CosuCharInfo:AddHover(parent, w, h, px, py, ax, ay, id, textfn)
    local b = parent:AddChild(ImageButton(SQUARE[1], SQUARE[2], SQUARE[2], SQUARE[2], SQUARE[2]))
    b:SetImageNormalColour(1, 1, 1, 0.01)
    b:SetImageFocusColour(1, 0.85, 0.4, 0.14)
    local bw, bh = b.image:GetSize()
    if bw == nil or bw <= 0 then bw = 1 end
    if bh == nil or bh <= 0 then bh = 1 end
    local sx, sy = w / bw, h / bh
    b:SetNormalScale(sx, sy, 1)
    b:SetFocusScale(sx, sy, 1)
    b:SetPosition(px, py, 0)
    b:SetOnClick(function() end)
    local gain, lose = b.OnGainFocus, b.OnLoseFocus
    b.OnGainFocus = function(wd)
        gain(wd)
        self:ShowTipAt(id, textfn(), ax, ay, h, ay < -100) -- gần đáy bảng thì hiện phía trên
    end
    b.OnLoseFocus = function(wd)
        lose(wd)
        self:HideFortuneTip(id)
    end
    return b
end

-- các hàng "icon + tên + số" (MakeRows): hàng nào có trong TIPS thì cho rê chuột
function CosuCharInfo:AddRowHovers(list, cx, top, row_h)
    for i, e in ipairs(list) do
        local key = e.row.key
        if TIPS[key] ~= nil then
            local y = top - (i - 0.5) * row_h
            self:AddHover(self.status, COL_W, row_h - 2, cx, y, cx, y, "tip_" .. key, function() return TipText(TIPS[key]) end)
        end
    end
end

function CosuCharInfo:ShowFortuneTip(d, x, y, above)
    self:ShowTipAt(d.id, d.desc or "", self.fort_cx + x, self.head_y + y, FORT_TILE_H, above)
end

-- (ax, ay) = tâm vùng được rê chuột trong hệ tọa độ tab Trạng thái, h = chiều cao vùng đó
function CosuCharInfo:ShowTipAt(id, text, ax, ay, h, above)
    if text == nil or text == "" then return end
    self.ftip_id = id
    local inner = FTIP_W - 28
    local cpl = math.max(1, math.floor(inner / (FTIP_SIZE * 0.5)))
    local lines = 0
    for seg in string.gmatch(text .. "\n", "(.-)\n") do
        lines = lines + math.max(1, math.ceil(CharCount(seg) / cpl))
    end
    local th = lines * (FTIP_SIZE + 4) + 22
    self.ftip_text:SetRegionSize(inner, th - 10)
    self.ftip_text:SetString(text)
    self.ftip_bg:SetSize(FTIP_W, th)
    self.ftip_border:SetSize(FTIP_W + 4, th + 4)

    local lo = COL_X[1] - COL_W / 2 + FTIP_W / 2
    local hi = COL_X[5] + COL_W / 2 - FTIP_W / 2
    local tx = math.max(lo, math.min(hi, ax))
    local half = h / 2 + 6 + th / 2
    local ty = above and (ay + half) or (ay - half)
    self.ftip:SetPosition(tx, ty, 0)
    self.ftip:MoveToFront()
    self.ftip:Show()
end

-- Tiên Thiên Khí Vận đã chọn (tên theo màu độ hiếm; rê chuột vào thì hiện chỉ số cộng thêm)
function CosuCharInfo:BuildFortune(ids, pending)
    local b = self.fortune_box
    self:HideFortuneTip()
    b:KillAllChildren()
    local items = {}
    for _, id in ipairs(ids) do
        local d = FT.BY_ID[id]
        if d ~= nil and #items < FT.PICK then table.insert(items, d) end
    end
    -- xếp tối đa 3 tên một hàng, căn giữa vùng Tiên Thiên Khí Vận
    -- chia đều các hàng (4 tên -> 2 + 2, 5 -> 3 + 2, 7 -> 3 + 2 + 2...)
    local per = math.max(1, math.ceil(#items / math.ceil(#items / 3)))
    for i, d in ipairs(items) do
        local row = math.floor((i - 1) / per)
        local in_row = math.min(per, #items - row * per)
        local x = (((i - 1) % per) - (in_row - 1) / 2) * COL_PITCH
        local y = -38 - row * FORT_ROW_H
        local rc = FT.RARITY[d.rarity].colour
        NC(MakeRect(b, COL_W + 4, FORT_TILE_H + 4, { rc[1], rc[2], rc[3], 0.9 }, x, y)) -- viền theo độ hiếm

        -- nút nền tối (hover sáng lên) để bắt rê chuột
        local btn = b:AddChild(ImageButton(SQUARE[1], SQUARE[2], SQUARE[2], SQUARE[2], SQUARE[2]))
        btn:SetImageNormalColour(0.08, 0.07, 0.06, 0.85)
        btn:SetImageFocusColour(0.22, 0.17, 0.08, 0.95)
        local bw, bh = btn.image:GetSize()
        if bw == nil or bw <= 0 then bw = 1 end
        if bh == nil or bh <= 0 then bh = 1 end
        local sx, sy = COL_W / bw, FORT_TILE_H / bh
        btn:SetNormalScale(sx, sy, 1)
        btn:SetFocusScale(sx * 1.02, sy * 1.06, 1)
        btn:SetPosition(x, y, 0)
        btn:SetOnClick(function() end)
        local above = row >= 2
        local gain, lose = btn.OnGainFocus, btn.OnLoseFocus
        btn.OnGainFocus = function(w)
            gain(w)
            self:ShowFortuneTip(d, x, y, above)
        end
        btn.OnLoseFocus = function(w)
            lose(w)
            self:HideFortuneTip(d.id)
        end
        NC(MakeText(b, d.name, 22, rc, x, y, COL_W, ANCHOR_MIDDLE))
    end
    if #items == 0 then
        if pending then
            local btn = b:AddChild(TextButton())
            btn:SetFont(UIFONT)
            btn:SetTextSize(24)
            btn:SetText(FT.TEXT.OPEN)
            btn:SetTextColour(unpack(INK_GOLD))
            btn:SetTextFocusColour(unpack(INK_FOCUS))
            btn:SetPosition(0, -40, 0)
            btn:SetOnClick(function() FortuneScreen.TryOpen(self.owner) end)
        else
            MakeText(b, FT.TEXT.NONE, FONT, INK_GREY, 0, -40)
        end
    end
end

function CosuCharInfo:RefreshFortune()
    local p = self.owner
    local chosen = p._cosu_fortune ~= nil and p._cosu_fortune:value() or ""
    local offer = p._cosu_fortune_offer ~= nil and p._cosu_fortune_offer:value() or ""
    local key = chosen .. "|" .. offer
    if key == self.fortune_key then return end
    self.fortune_key = key
    local ids = {}
    for id in string.gmatch(chosen, "[%w_]+") do table.insert(ids, id) end
    self:BuildFortune(ids, offer ~= "")
    -- chỉ số cộng thêm chưa có hàng riêng (dưới cột Thuộc tính); mọi khóa khác đã cộng thẳng vào hàng của nó
    local fs = FT.Sum(chosen)
    local parts = {}
    for _, st in ipairs(FT.STAT) do
        local v = fs[st.key] or 0
        if v ~= 0 and not st.root and not ROW_FKEY[st.key] then
            table.insert(parts, string.format("%s %+d%s", st.label, v, st.suffix or ""))
        end
    end
    self.fbonus:SetString(#parts > 0 and ("Khí vận: " .. table.concat(parts, ", ")) or "")
end

function CosuCharInfo:Refresh()
    local p = self.owner
    if p == nil or not p:IsValid() then return end
    if self.tab == "gu" then
        self:RefreshGu()
        return
    end
    local r = p.replica

    local chosen = p._cosu_fortune ~= nil and p._cosu_fortune:value() or ""
    if chosen ~= self.fs_key or self.fs == nil then
        self.fs_key = chosen
        self.fs = FT.Sum(chosen)
    end
    local fs = self.fs

    local cur, max = GetStat(r.health)
    self.stats.hp.SetValue(cur, max)
    cur, max = GetStat(r.hunger)
    self.stats.hunger.SetValue(cur, max) -- mức tối đa đã gồm Tinh lực từ khí vận (server cộng thật, xem cosu_fortune_effects)
    cur, max = GetStat(r.sanity)
    self.stats.sanity.SetValue(cur, max) -- mức tối đa đã gồm Ngộ tính từ khí vận (server cộng thật)
    local qi = p._cosu_qi ~= nil and p._cosu_qi:value() or 0
    local qimax = p._cosu_qimax ~= nil and p._cosu_qimax:value() or 0
    self.stats.qi.SetValue(qi, qimax)

    -- cảnh giới
    local rank = p._cosu_rank ~= nil and p._cosu_rank:value() or 0
    local names = ELEM.COMBAT.RANK_NAMES
    if rank < 1 then
        self.rank_text:SetString(CI.LOCKED_TEXT)
        self.rank_text:SetColour(unpack(INK_GREY))
        self.stage_text:SetString("")
    else
        self.rank_text:SetString(names[rank] or (rank .. " Chuyển"))
        self.rank_text:SetColour(unpack(INK_GOLD))
        local stage = p._cosu_stage ~= nil and p._cosu_stage:value() or 0
        local idx = stage - (CI.STAGE_FIRST or 1) + 1
        self.stage_text:SetString(CI.STAGE_NAMES[idx] or "")
    end
    local pts = p._cosu_points ~= nil and p._cosu_points:value() or 0
    local need = p._cosu_need ~= nil and p._cosu_need:value() or 0
    self.xp_text:SetString(need > 0 and (pts .. "/" .. need) or tostring(pts))
    local frac = need > 0 and math.max(0, math.min(1, pts / need)) or 0
    local w = math.max(1, (self.xp_w - 4) * frac)
    self.xp_fill:SetSize(w, 6)
    self.xp_fill:SetPosition(self.xp_cx - (self.xp_w - 4) / 2 + w / 2, self.xp_y, 0)

    -- linh căn (cổ trùng + khí vận) + các cột chỉ số
    local str = p._cosu_plroots ~= nil and p._cosu_plroots:value() or ""
    local key = str .. "|" .. chosen
    if key ~= self.roots_str then
        self.roots_str = key
        self:BuildRoots(ParseRoots(str, fs), {})
    end
    UpdateRows(p, self.attr_rows, fs)
    UpdateRows(p, self.combat_rows, fs)
    UpdateRows(p, self.art_rows, fs)
    UpdateRows(p, self.skill_rows, fs)

    self:RefreshFortune()

    local lt = p._cosu_linhthach ~= nil and p._cosu_linhthach:value() or 0
    self.linhthach_text:SetString((tostring(lt):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")))
end

function CosuCharInfo:OnUpdate(dt)
    self.next_update = self.next_update - dt
    if self.next_update > 0 then return end
    self.next_update = 0.2
    self:Refresh()
end

return CosuCharInfo