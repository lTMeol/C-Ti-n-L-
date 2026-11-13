-- Cấu hình đan đột phá. Viên số N dùng để lên từ chuyển N sang chuyển N+1.
local P = {}

P.RANK_NAMES = { "Nhất", "Nhị", "Tam", "Tứ", "Ngũ", "Lục", "Thất", "Bát", "Cửu" }

-- số nguyên thạch Tuyệt Phẩm cần để chế mỗi viên (chỉnh theo ý bạn)
P.COST = { 1, 2, 3, 4, 5, 6, 8, 10 }

-- màu nhuộm viên đan dưới đất (r, g, b) để phân biệt từng chuyển
P.TINT = {
    { 0.8, 1.0, 0.8 }, { 0.7, 0.9, 1.0 }, { 0.9, 0.8, 1.0 }, { 1.0, 0.8, 0.9 },
    { 1.0, 0.9, 0.6 }, { 1.0, 0.7, 0.5 }, { 1.0, 0.5, 0.5 }, { 0.8, 0.5, 1.0 },
}

-- Phần thưởng chỉ số tối đa: mỗi lần lên 1 giai cộng STAT_BONUS cho 1 trong 3 chỉ số ngẫu nhiên,
-- mỗi lần lên chuyển mới cộng STAT_BONUS cho cả 3.
P.STAT_BONUS = 50
P.STATS = { "health", "sanity", "hunger" }
P.STAT_NAMES = { health = "Máu", sanity = "Não", hunger = "Độ No" }

P.MAX_PILL = 8
function P.PrefabName(n) return "cosu_pill_" .. n end
function P.DisplayName(n) return "Đan Đột Phá " .. P.RANK_NAMES[n] .. " Chuyển" end

return P
