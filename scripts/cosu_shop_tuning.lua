-- scripts/cosu_shop_tuning.lua : số liệu Thạch Quán (đổ thạch). Chỉnh giá, tỷ lệ, danh sách đá, lời thoại ở đây.
-- File này được cả server (components/cosu_shop.lua) lẫn máy khách (screens/cosu_shop_screen.lua) dùng,
-- nên mọi công thức giá / tỷ lệ cổ trùng nằm ở đây để hai bên luôn tính giống nhau.
local T = {}

T.SLOTS = 9                       -- số viên đá bày ra (lưới 3x3)
T.PRICE_MIN, T.PRICE_MAX = 200, 2000
T.REFILL_DAYS = 10               -- viên nào đã bán thì ô đó trống, sau số ngày này mới có viên mới
T.GU_CHANCE = 0.01                -- tỷ lệ ra cổ trùng cơ bản 1% (chưa làm: hàm RollGu trong components/cosu_shop.lua đang trả về nil)

-- atlas ảnh đá (xuất từ Atlas Packing, đổi tên thành cosu_stones_ui.xml / .tex, để trong images/)
T.ATLAS = "images/cosu_stones_ui.xml"
-- tên vùng ảnh của vầng sáng màu kem (hiện sau viên đá khi mở ra đồ). nil = dùng nền tối đơn giản
T.GLOW = "3958.tex"

-- Danh sách đá: chỉ khác hình dạng. Mọi viên có cùng tỷ lệ ra đồ, giá chỉ là ngẫu nhiên PRICE_MIN..PRICE_MAX.
T.STONES = {
    "5551.tex", "5562_0.tex", "5561_0.tex", "5544_0.tex", "5549_0.tex", "5563_0.tex",
    "5559_0.tex", "5539.tex", "5548_0.tex", "5552_0.tex", "5550_0.tex", "5547.tex",
    "5554.tex", "5556_0.tex", "5537.tex", "5555_0.tex", "5538.tex",
}

-- NPC đứng cạnh cửa hàng (images/cosu_npc.xml / .tex)
T.NPC_ATLAS, T.NPC_TEX = "images/cosu_npc.xml", "cosu_npc.tex"
T.NPC_NAME = "Chưởng quầy"

-- Phần thưởng (như nhau cho mọi viên đá): { prefab, số lượng nhỏ nhất, lớn nhất, trọng số }
T.REWARDS = {
    { "rocks",           4, 8, 30 },
    { "flint",           3, 6, 22 },
    { "goldnugget",      1, 3, 16 },
    { "marble",          2, 4, 12 },
    { "redgem",          1, 2, 6 },
    { "bluegem",         1, 2, 6 },
    { "purplegem",       1, 2, 4 },
    { "orangegem",       1, 1, 2 },
    { "yellowgem",       1, 1, 2 },
    { "greengem",        1, 1, 2 },
    { "opalpreciousgem", 1, 1, 0.5 },
}

-- Cổ trùng có thể ra khi đổ thạch (ra cổ thì chọn theo trọng số): { prefab, số lượng nhỏ nhất, lớn nhất, trọng số }
T.GU_REWARDS = {
    { "cosu_gu_anthach", 1, 1, 1 },
    { "cosu_gu_thachbi", 1, 1, 1 },
}

---------------------------------------------------------------------------
-- ẢNH HƯỞNG CỦA CHỈ SỐ
---------------------------------------------------------------------------
T.CHARM_STEP, T.CHARM_DISCOUNT = 200, 0.10   -- cứ 200 mị lực giảm 10% giá (tính theo bậc, 199 mị lực = chưa giảm)
T.CHARM_MAX_DISCOUNT = 0.9                   -- giảm tối đa 90% để không bao giờ miễn phí
T.LUCK_STEP, T.LUCK_BONUS = 10, 0.01         -- cứ 10 may mắn cộng thêm 1% tỷ lệ ra cổ trùng (tính theo bậc)
T.GU_CHANCE_MAX = 1.0
T.DEMON_SURCHARGE = 0.20                     -- ma đạo > chính đạo: giá +20% (bằng nhau hoặc chính đạo lớn hơn: không đổi)

local okFT, FT = pcall(require, "cosu_fortune_tuning")
if not okFT then FT = nil end

-- Đọc 4 chỉ số của người chơi. Hiện chúng chỉ đến từ Tiên Thiên Khí Vận (giống bảng nhân vật: FT.Sum(player._cosu_fortune)).
-- Sau này nếu có thêm nguồn cộng khác (netvar riêng...) thì chỉ cần sửa đúng hàm này.
function T.GetStats(player)
    local s = { luck = 0, charm = 0, demon = 0, righteous = 0 }
    if FT ~= nil and player ~= nil and player._cosu_fortune ~= nil then
        local ok, fs = pcall(FT.Sum, player._cosu_fortune:value() or "")
        if ok and type(fs) == "table" then
            for k in pairs(s) do s[k] = tonumber(fs[k]) or 0 end
        end
    end
    return s
end

function T.PriceInfo(stats)
    local discount = math.min(T.CHARM_MAX_DISCOUNT, math.floor(math.max(stats.charm, 0) / T.CHARM_STEP) * T.CHARM_DISCOUNT)
    local surcharge = stats.demon > stats.righteous and T.DEMON_SURCHARGE or 0
    return discount, surcharge
end

-- giá thực phải trả từ giá gốc của viên đá
function T.AdjustPrice(base, player)
    local discount, surcharge = T.PriceInfo(T.GetStats(player))
    return math.max(1, math.floor(base * (1 - discount) * (1 + surcharge) + 0.5))
end

function T.GuChance(player)
    local stats = T.GetStats(player)
    local bonus = math.floor(math.max(stats.luck, 0) / T.LUCK_STEP) * T.LUCK_BONUS
    return math.min(T.GU_CHANCE_MAX, T.GU_CHANCE + bonus)
end

---------------------------------------------------------------------------
-- LỜI THOẠI
---------------------------------------------------------------------------
local function Pick(list) return list[math.random(#list)] end

-- Lời chào khi mở cửa hàng: 1 câu theo đạo (ma / chính / cân bằng) + 1 câu theo mị lực hoặc may mắn (nếu có)
T.GREET_PATH = {
    demon = {
        "Ma khí trên người ngươi nồng quá... Quán nhỏ làm ăn khó, giá phải nhỉnh hơn chút, mong ngươi thông cảm.",
        "Hừ, mùi sát khí. Ta không dám đắc tội, nhưng người như ngươi thì giá phải cao hơn.",
    },
    righteous = {
        "Chính khí hiển hiện, nhìn là biết người đàng hoàng. Mời vào, mời vào!",
        "Ồ, một vị đạo hữu chính trực. Quán nhỏ lúc nào cũng hoan nghênh.",
    },
    neutral = {
        "Khách quan đến rồi à? Cứ thong thả xem đá.",
        "Mời vào Thạch Quán. Đá nào cũng còn nguyên, chưa ai mở.",
    },
}
T.GREET_CHARM = {
    high = {
        "Phong thái của ngươi khiến ta không nỡ nói giá cao. Ta bớt cho ngươi một chút.",
        "Người có mị lực như ngươi, ta nhìn đã thấy quý, giá cả dễ nói thôi.",
    },
    mid = {
        "Ngươi cũng có chút duyên, ta bớt cho ít nhiều.",
    },
}
T.GREET_LUCK = {
    high = {
        "Vận khí ngươi tốt thật đấy. Biết đâu hôm nay lại mở ra được cổ trùng.",
        "Trên người ngươi có hồng vận. Thử vài viên xem sao?",
    },
}

function T.GreetLine(player)
    local s = T.GetStats(player)
    local path = s.demon > s.righteous and "demon" or (s.righteous > s.demon and "righteous" or "neutral")
    local line = Pick(T.GREET_PATH[path])
    local discount = T.PriceInfo(s)
    if discount >= 0.3 then
        line = line .. " " .. Pick(T.GREET_CHARM.high)
    elseif discount > 0 then
        line = line .. " " .. Pick(T.GREET_CHARM.mid)
    elseif s.luck >= T.LUCK_STEP then
        line = line .. " " .. Pick(T.GREET_LUCK.high)
    end
    return line
end

-- Lời thoại khi hết sạch đá (mở quán thấy trống, hoặc vừa bán viên cuối)
T.SOLDOUT = {
    "Kho đã cạn, chẳng còn viên nào để ngươi mở. Hãy để ta ra núi tìm thêm, ít bữa nữa quay lại.",
    "Ngươi đến muộn rồi, đá trong quán đã được mang đi hết. Quán này giờ chỉ còn lại mấy cái kệ trống.",
    "Hết rồi, khách quan ạ. Muốn đá thì đợi ta đi tìm thêm, núi cao đường xa, chẳng gấp được đâu.",
}
function T.SoldOutLine() return Pick(T.SOLDOUT) end

-- "Dấu vân" của trạng thái chỉ số hiện tại: chỉ đổi khi lời chào thực sự đổi (đổi đạo, đổi bậc giảm giá, đổi bậc may mắn).
-- Màn hình dùng nó để chỉ chào 1 lần cho mỗi trạng thái, mở quán lần sau mà chỉ số chưa đổi thì NPC im lặng.
function T.GreetSignature(player)
    local s = T.GetStats(player)
    local path = s.demon > s.righteous and "demon" or (s.righteous > s.demon and "righteous" or "neutral")
    local discount = T.PriceInfo(s)
    local lucky = s.luck >= T.LUCK_STEP and 1 or 0
    return path .. "|" .. discount .. "|" .. lucky
end

-- Các trang thoại khi bấm "Trò chuyện" (bấm tiếp để sang trang kế, hết thì quay lại trang đầu).
-- Viết theo giọng văn chương, không nhắc thẳng tên chỉ số hay con số nào.
function T.TalkPages(player)
    return {
        "Thạch Quán này đứng đây từ rất lâu, lâu hơn cả cái ngày ngươi biết đến hai chữ tu hành. Đá nằm lặng lẽ như lòng người chưa động; bên trong có gì, chỉ khi vỡ ra mới rõ.",
        "Ta bán đá, không bán lời hứa. Ngọc quý hay sỏi vụn, hình dáng bên ngoài chẳng nói lên điều gì, viên nào cũng khoác một lớp áo như nhau. Thứ ngươi bỏ ra chẳng qua là một phần cơ duyên.",
        "Người xưa bảo trong lòng đá có linh khí ủ qua ngàn năm. Hiếm lắm, hiếm đến mức cả đời mới gặp một lần, có viên ôm trong mình một con cổ trùng đang ngủ say. Kẻ phúc duyên dày thì cánh cửa ấy hé rộng hơn một chút.",
        "Viên nào đã có người mang đi thì chỗ ấy để trống. Đá đâu phải thứ mọc lên sau một đêm, ta phải lên núi tìm, phải đợi qua nhiều ngày mới đem được viên mới về bày vào.",
        "Còn chuyện giá cả... ta nhìn người mà định giá. Kẻ phong thái khiến người nể phục thì ta nhường đôi phần; kẻ mang sát khí nặng nề thì ta phải dè chừng, giá cũng nặng theo. Còn người lòng ngay thẳng, ta cứ đối đãi như khách quen.",
    }
end

return T