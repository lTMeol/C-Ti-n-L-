-- Mọi con số cân bằng của hệ thống nguyên thạch và cảnh giới nằm ở đây.
local T = {}

T.GRADES = { "low", "mid", "high", "extreme", "supreme" }

T.PREFAB = {
    low = "cosu_stone_low", mid = "cosu_stone_mid", high = "cosu_stone_high",
    extreme = "cosu_stone_extreme", supreme = "cosu_stone_supreme",
}

T.NAME = {
    low = "Nguyên Thạch Hạ Phẩm", mid = "Nguyên Thạch Trung Phẩm",
    high = "Nguyên Thạch Thượng Phẩm", extreme = "Nguyên Thạch Cực Phẩm",
    supreme = "Nguyên Thạch Tuyệt Phẩm",
}

-- Hình dưới đất: mượn nguyên bản đá quý của game (màu khớp biểu tượng).
-- Muốn hình riêng thì làm build Spriter rồi thay ở scripts/prefabs/cosu_stones.lua
T.BASE_PREFAB = {
    low = "bluegem", mid = "purplegem", high = "redgem",
    extreme = "orangegem", supreme = "yellowgem",
}

-- Điểm tu vi mỗi viên cho khi tiêu hao
T.POINTS = { low = 1, mid = 10, high = 50, extreme = 200, supreme = 1000 }

-- Điểm cần để đi hết MỘT chuyển (từ Sơ Giai đến Đỉnh Phong) ở từng chuyển 1..9.
-- Sau Đỉnh Phong, nguyên thạch không cộng thêm được nữa: phải dùng đan dược để lên chuyển kế.
T.REALM_COST = { 400, 1200, 3500, 9000, 22000, 55000, 130000, 300000, 700000 }

-- Nhân chung toàn bộ chi phí: 1 = bản khó như thiết kế, 0.5 = dễ gấp đôi, 2 = khó gấp đôi
T.COST_MULT = 1

-- Mốc vào từng giai, tính theo tỷ lệ chi phí của chuyển: Sơ 0%, Trung 15%, Cao 45%, Đỉnh Phong 100%
T.STAGE_AT = { 0, 0.15, 0.45, 1.0 }

-- Tỷ lệ rơi nguyên thạch
T.NORMAL = { mid = 0.05, high = 0.01 }
T.ELITE = { mid = 0.15, high = 0.05 }
T.BOSS = { mid_count = 5, high_count = 2, extreme_chance = 0.10, extreme_count = 1 }

T.ELITE_PREFABS = {
    knight = true, bishop = true, rook = true,
    knight_nightmare = true, bishop_nightmare = true, rook_nightmare = true,
    shadow_knight = true, shadow_bishop = true, shadow_rook = true,
}
T.BLACKLIST = { bee = true, killerbee = true, mosquito = true }
T.REQUIRE_PLAYER_KILL = true
T.COMBINE_COUNT = 10

return T
