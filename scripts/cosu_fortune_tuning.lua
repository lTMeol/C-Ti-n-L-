-- Tiên Thiên Khí Vận: dữ liệu + số liệu chỉnh tay.
-- Thêm khí vận mới: thêm một dòng vào LIST (id viết thường không dấu, không trùng).
-- bonus dùng các khóa trong STAT bên dưới. otherroot = cộng cho mọi linh căn KHÁC các linh căn đã ghi riêng trong bonus (vd Cửu Thiên Lôi Kiếp Thể: loi = 20, otherroot = -10).
local ELEM = require "cosu_element_tuning"
local M = {}

M.PICK = 4          -- số khí vận được chọn
M.OFFER_COUNT = 9   -- mỗi lần hiện bao nhiêu khí vận (3 cột x 3 hàng)
M.MAX_ROLLS = nil   -- nil = roll không giới hạn; đặt số để giới hạn

-- Hồi tâm tình (moodregen): ngoài việc nhân tốc độ đang hồi, còn tự hồi nền = MOOD_BASE_REGEN * (moodregen/100) điểm ngộ tính mỗi giây
-- (0.1 -> +50% = 0.05 điểm/giây, khoảng 24 điểm mỗi ngày game). Đặt 0 để tắt hồi nền.
M.MOOD_BASE_REGEN = 0.1

-- Công kích lực: true = quái có cảnh giới vẫn kháng PHYS_RESIST (50%) phần sát thương cộng thêm này
M.ATTACK_USE_PHYS_RESIST = true
-- Phòng ngự lực: false = chỉ giảm sát thương thường nhận vào; true = giảm luôn mỗi đòn sát thương nguyên tố của quái
M.DEFENSE_VS_ELEMENT = false

M.TEXT = {
    SECTION = "Tiên Thiên Khí Vận",
    TITLE = "Tiên Thiên Khí Vận",
    SUB = "Chọn %d khí vận (đã chọn %d/%d). Khí vận chọn xong không thể đổi.",
    ROLL = "[ Roll ]",
    CONFIRM = "[ Xác nhận ]",
    PICKED = "Đã chọn",
    NONE = "Chưa có",
    OPEN = "[ Chọn khí vận ]",
    EXTRA = "Cộng thêm từ khí vận",
}

-- Thứ tự độ hiếm (thấp -> cao): pham (xanh lá) < linh (xanh dương) < hiem (tím) < cuc (cam) < tien (đỏ)
M.RARITY = {
    pham = { label = "Phàm Phẩm", weight = 10, colour = { 0.45, 0.85, 0.45, 1 } },
    linh = { label = "Linh Phẩm", weight = 7, colour = { 0.4, 0.7, 1.0, 1 } },
    hiem = { label = "Hiếm", weight = 5, colour = { 0.75, 0.5, 0.95, 1 } },
    cuc = { label = "Cực Phẩm", weight = 2, colour = { 1.0, 0.65, 0.2, 1 } },
    tien = { label = "Tiên Phẩm", weight = 1, colour = { 1.0, 0.3, 0.3, 1 } },
}

-- Danh sách chỉ số (thứ tự = thứ tự hiện trong mô tả)
--   short: tên gọn trong mô tả | label: tên đầy đủ trong bảng | suffix: đơn vị | root = true nếu là linh căn
M.STAT = {
    { key = "hoa", short = "Hỏa", label = "Hỏa linh căn", root = true },
    { key = "tho", short = "Thổ", label = "Thổ linh căn", root = true },
    { key = "loi", short = "Lôi", label = "Lôi linh căn", root = true },
    { key = "moc", short = "Mộc", label = "Mộc linh căn", root = true },
    { key = "thuy", short = "Thủy", label = "Thủy linh căn", root = true },
    { key = "phong", short = "Phong", label = "Phong linh căn", root = true },
    { key = "otherroot", short = "Linh căn hệ khác", label = "Tư chất linh căn hệ khác" }, -- ghi chú: Sum() tự trải ra các linh căn không ghi riêng
    { key = "allroot", short = "Linh căn các hệ", label = "Tư chất linh căn các hệ" }, -- ghi chú: Sum() tự trải ra mọi linh căn đang có trong ELEM.LIST
    { key = "attack", short = "Công kích", label = "Công kích lực" },
    { key = "defense", short = "Phòng ngự", label = "Phòng ngự lực" },
    { key = "hp", short = "Máu", label = "Sinh lực tối đa" },
    { key = "qimax", short = "Nguyên khí tối đa", label = "Nguyên khí tối đa" },
    { key = "speed", short = "Tốc độ", label = "Tốc độ", suffix = "%" },
    { key = "charm", short = "Mị lực", label = "Mị lực" },
    { key = "luck", short = "May mắn", label = "May mắn" },
    { key = "demon", short = "Ma đạo", label = "Ma đạo" },
    { key = "righteous", short = "Chính đạo", label = "Chính đạo" },
    { key = "alchemy", short = "Luyện đan", label = "Tư chất luyện đan" },
    -- Chỉ số chưa có khóa áp dụng trong game (đã có ở bảng trạng thái): hiện trong mô tả để người chơi biết mà chọn
    { key = "fame", short = "Danh vọng", label = "Danh vọng" },
    { key = "crit", short = "Hội tâm", label = "Hội tâm", suffix = "%" },
    { key = "sanity", short = "Ngộ tính", label = "Ngộ tính" },
    { key = "sanityrate", short = "Tụt ngộ tính", label = "Tốc độ tụt ngộ tính", suffix = "%" },
    { key = "moodregen", short = "Hồi tâm tình", label = "Tốc độ hồi tâm tình", suffix = "%" },
    { key = "moodmax", short = "Tâm tình tối đa", label = "Tâm tình tối đa" },
    { key = "hunger", short = "Tinh lực", label = "Tinh lực" },
    { key = "hungerrate", short = "Tụt tinh lực", label = "Tốc độ tụt tinh lực", suffix = "%" },
    { key = "gongfa", short = "Công pháp", label = "Công pháp" },
    { key = "blade", short = "Đao pháp", label = "Đao pháp" },
    { key = "sword", short = "Kiếm pháp", label = "Kiếm pháp" },
    { key = "spear", short = "Thương pháp", label = "Thương pháp" },
    { key = "finger", short = "Chỉ pháp", label = "Chỉ pháp" },
    { key = "fist", short = "Quyền pháp", label = "Quyền pháp" },
    { key = "palm", short = "Chưởng pháp", label = "Chưởng pháp" },
    { key = "fengshui", short = "Phong thủy", label = "Phong thủy" },
    { key = "protect", short = "Hộ tâm", label = "Hộ tâm" },
    { key = "huafu", short = "Họa phù", label = "Họa phù" },
    { key = "range", short = "Tầm đánh", label = "Cự ly công kích" },
}
M.STAT_BY_KEY = {}
M.ROOT_KEYS = {}
for _, s in ipairs(M.STAT) do
    M.STAT_BY_KEY[s.key] = s
    if s.root then table.insert(M.ROOT_KEYS, s.key) end
end

-- Tên gọi khác của linh căn để khớp với ELEM.LIST (id hoặc label) ở máy khách
M.ROOT_ALIAS = {
    hoa = { "hoa", "hỏa", "hoả" }, tho = { "tho", "thổ", "thỗ" }, loi = { "loi", "lôi" },
    moc = { "moc", "mộc" }, thuy = { "thuy", "thủy", "thuỷ" }, phong = { "phong" },
}

-- desc/chỉ số: compact = true -> "Hỏa +20", false -> "Hỏa linh căn +20"
function M.Describe(bonus, compact, note)
    local parts = {}
    for _, s in ipairs(M.STAT) do
        local v = bonus[s.key]
        if v ~= nil and v ~= 0 then
            local name = (s.root and not compact) and s.label or s.short
            table.insert(parts, string.format("%s %+d%s", name, v, s.suffix or ""))
        end
    end
    if note ~= nil and not compact then table.insert(parts, note) end
    return table.concat(parts, ", ")
end

-- Danh sách khí vận (các khí vận khác đã bỏ)
M.LIST = {
    { id = "tam_hoa", name = "Tam Hoa Bất Diệt", rarity = "tien", bonus = { hoa = 20, tho = 20, loi = 20, attack = 6, righteous = 100 } },
    { id = "kien_moc", name = "Kiến Mộc Linh Thai", rarity = "tien", bonus = { moc = 25, qimax = 50, charm = 150, defense = 5 } },
    -- Cực Phẩm (cam) thêm từ danh sách game; Thọ mệnh / Sinh lực = hp
    { id = "trung_nang_chuyen_the", name = "Trung Năng Chuyển Thế", rarity = "cuc", bonus = { sanity = 10 }, startitem = "linhchau_random", note = "Khi bắt đầu trò chơi, mang theo một viên linh châu (ngẫu nhiên một hệ)" },
    { id = "xuyen_viet_gia", name = "Xuyên Việt Giả", rarity = "cuc", bonus = { sanity = 20, hp = 10, luck = 10, fame = 100 } },
    { id = "co_thu_linh_khu", name = "Cổ Thụ Linh Khu", rarity = "cuc", bonus = { defense = 4, protect = 10, moc = 10, hp = 5, charm = -100 } },
    { id = "long_chi_huyet_mach", name = "Long Chi Huyết Mạch", rarity = "cuc", bonus = { attack = 6, luck = 10, hp = 10 } },
    { id = "phuong_chi_huyet_mach", name = "Phượng Chi Huyết Mạch", rarity = "cuc", bonus = { attack = 6, luck = 10, charm = 100 } },
    { id = "ho_chi_huyet_mach", name = "Hổ Chi Huyết Mạch", rarity = "cuc", bonus = { attack = 6, crit = 20 } },
    { id = "tuong_chi_huyet_mach", name = "Tượng Chi Huyết Mạch", rarity = "cuc", bonus = { defense = 5, hp = 100, luck = 10 } },
    { id = "phuong_hoang_linh_the", name = "Phượng Hoàng Linh Thể", rarity = "cuc", bonus = { sword = 14, hoa = 14, charm = 150 } },
    { id = "da_ho_vu_gia", name = "Đả Hổ Vũ Giả", rarity = "cuc", bonus = { defense = 5, hoa = 15, fist = 15 } },
    { id = "ngao_cot_tranh_tranh", name = "Ngạo Cốt Tranh Tranh", rarity = "cuc", bonus = { defense = 5, hp = 130 } },
    { id = "tam_thanh_dao_dong", name = "Tam Thanh Đạo Đồng", rarity = "cuc", bonus = { sanity = 40, hp = 10, righteous = 50, moodmax = 20 } },
    { id = "truy_phong_kiem_gia", name = "Truy Phong Kiếm Giả", rarity = "cuc", bonus = { attack = 5, sword = 15, phong = 15 } },
    { id = "hang_long_vu_gia", name = "Hàng Long Vũ Giả", rarity = "cuc", bonus = { attack = 5, spear = 15, loi = 15 } },
    { id = "ma_dao_nan_dan", name = "Ma Đao Nạn Dân", rarity = "cuc", bonus = { attack = 5, blade = 15, hoa = 15 } },
    { id = "bat_dong_minh_vuong", name = "Bất Động Minh Vương", rarity = "cuc", bonus = { defense = 5, fist = 14, palm = 14, finger = 14 } },
    { id = "dan_tam_linh_dong", name = "Đan Tâm Linh Đồng", rarity = "cuc", bonus = { alchemy = 20, sanity = 10, fame = 100, righteous = 50 } },
    { id = "tuyet_the_thong_tue", name = "Tuyệt Thế Thông Tuệ", rarity = "cuc", bonus = { moodmax = -30, charm = -100 }, sanitylock = 500, note = "Ngộ tính khóa chặt ở 500" },
    { id = "thien_sat_co_tinh", name = "Thiên Sát Cô Tinh", rarity = "cuc", bonus = { attack = 8, crit = 20, charm = -300 } },
    { id = "thien_sinh_dao_tu", name = "Thiên Sinh Đạo Tử", rarity = "cuc", bonus = { defense = 6, luck = 10, charm = 100, righteous = 100 } },
    { id = "lanh_huyet", name = "Lãnh Huyết", rarity = "cuc", bonus = { attack = 6, crit = 20, charm = -100 } },
    { id = "ngu_vat_nhu_than", name = "Ngự Vật Như Thần", rarity = "cuc", bonus = { blade = 15, spear = 15, sword = 15, attack = 3, righteous = 100 } },
    { id = "nhuc_the_ma_thai", name = "Nhục Thể Ma Thai", rarity = "cuc", bonus = { fist = 15, palm = 15, finger = 15, defense = 3, demon = 100 } },
    { id = "ta_ma_khi_tu", name = "Tà Ma Khí Tử", rarity = "cuc", bonus = { gongfa = 10, charm = 100, righteous = 100 } },
    { id = "chinh_phai_du_nghiep", name = "Chính Phái Dư Nghiệt", rarity = "cuc", bonus = { gongfa = 10, charm = 100, demon = 100 } },
    { id = "phong_loi_dao_thai", name = "Phong Lôi Đạo Thai", rarity = "cuc", bonus = { phong = 25, loi = 25, righteous = 100, attack = 3 } },
    { id = "tho_moc_dao_thai", name = "Thổ Mộc Đạo Thai", rarity = "cuc", bonus = { tho = 25, moc = 25, righteous = 100, attack = 3 } },
    { id = "phong_hoa_ma_thai", name = "Phong Hỏa Ma Thai", rarity = "cuc", bonus = { phong = 25, hoa = 25, demon = 100, attack = 3 } },
    { id = "tho_thuy_ma_thai", name = "Thổ Thủy Ma Thai", rarity = "cuc", bonus = { tho = 25, thuy = 25, demon = 100, attack = 3 } },
    { id = "duoc_linh_the", name = "Dược Linh Thể", rarity = "cuc", bonus = { alchemy = 30 } },
    { id = "than_phu_hoa_thu", name = "Thần Phù Họa Thủ", rarity = "cuc", bonus = { sanity = 10, huafu = 60, fame = 100, hp = -10 } },
    { id = "vong_khi_nhan", name = "Vọng Khí Nhân", rarity = "cuc", bonus = { sanity = 10, fengshui = 50, luck = -10, fame = 100 } },
    { id = "tinh_ve", name = "Tinh Vệ Lấp Hải", rarity = "tien", bonus = { tho = 20, thuy = 5, speed = 20 } },
    { id = "vo_thanh", name = "Võ Thánh Chuyển Thế", rarity = "tien", bonus = { attack = 10, defense = 3, sanity = 20, fame = 100 } },
    { id = "ma_thai", name = "Thiên Sinh Ma Thai", rarity = "cuc", bonus = { attack = 6, crit = 20, demon = 100 } },
    -- Hiếm (tím), số liệu từ game; Thọ mệnh = hp
    { id = "long_than_ho_the", name = "Long Thần Hộ Thể", rarity = "hiem", bonus = { defense = 5, spear = 5, charm = 50 } },
    { id = "minh_vuong_the", name = "Minh Vương Thể", rarity = "hiem", bonus = { attack = -1, defense = 5, tho = 10, moc = 10 } },
    { id = "cuu_thien_loi_kiep_the", name = "Cửu Thiên Lôi Kiếp Thể", rarity = "hiem", bonus = { attack = 5, loi = 20, otherroot = -10 } },
    { id = "nguyen_duong_hoa_phan_the", name = "Nguyên Dương Hỏa Phần Thể", rarity = "hiem", bonus = { attack = 5, hoa = 20, otherroot = -10 } },
    { id = "han_luu_thuy_linh_the", name = "Hãn Lưu Thủy Linh Thể", rarity = "hiem", bonus = { attack = 5, thuy = 20, otherroot = -10 } },
    { id = "bac_vuc_phong_than_the", name = "Bắc Vực Phong Thần Thể", rarity = "hiem", bonus = { attack = 5, phong = 20, otherroot = -10 } },
    { id = "hau_hoang_tho_nguyen_the", name = "Hậu Hoàng Thổ Nguyên Thể", rarity = "hiem", bonus = { attack = 5, tho = 20, otherroot = -10 } },
    { id = "sam_la_moc_tuyet_the", name = "Sâm La Mộc Tuyệt Thể", rarity = "hiem", bonus = { attack = 5, moc = 20, otherroot = -10 } },
    { id = "lac_vu_the", name = "Lạc Vũ Thể", rarity = "hiem", bonus = { thuy = 15, phong = 15, fame = 100 } },
    { id = "phan_diem_the", name = "Phần Diễm Thể", rarity = "hiem", bonus = { attack = 5, hoa = 10, phong = 10, hp = -10 } },
    { id = "bao_viem_the", name = "Bạo Viêm Thể", rarity = "hiem", bonus = { attack = 5, hoa = 10, loi = 10, charm = -100 } },
    -- Hiếm (tím) thêm từ danh sách game; Thọ mệnh / Thể chất = hp
    { id = "tho_tinh_hau_dai", name = "Thọ Tinh Hậu Đại", rarity = "hiem", bonus = { hp = 50 } },
    { id = "cuong_vong_tu_dai", name = "Cuồng Vọng Tự Đại", rarity = "hiem", bonus = { attack = 6, defense = -2, charm = -100 } },
    { id = "kiem_ma_chuyen_the", name = "Kiếm Ma Chuyển Thế", rarity = "hiem", bonus = { sword = 25, attack = 1, demon = 50 } },
    { id = "dao_ma_chuyen_the", name = "Đao Ma Chuyển Thế", rarity = "hiem", bonus = { blade = 25, attack = 1, demon = 50 } },
    { id = "thuong_ma_chuyen_the", name = "Thương Ma Chuyển Thế", rarity = "hiem", bonus = { spear = 25, attack = 1, demon = 50 } },
    { id = "quyen_ma_chuyen_the", name = "Quyền Ma Chuyển Thế", rarity = "hiem", bonus = { fist = 25, attack = 1, demon = 50 } },
    { id = "chi_ma_chuyen_the", name = "Chỉ Ma Chuyển Thế", rarity = "hiem", bonus = { finger = 25, attack = 1, demon = 50 } },
    { id = "chuong_ma_chuyen_the", name = "Chưởng Ma Chuyển Thế", rarity = "hiem", bonus = { palm = 25, attack = 1, demon = 50 } },
    { id = "kiem_tien_chuyen_the", name = "Kiếm Tiên Chuyển Thế", rarity = "hiem", bonus = { sword = 25, attack = 1, righteous = 50 } },
    { id = "dao_tien_chuyen_the", name = "Đao Tiên Chuyển Thế", rarity = "hiem", bonus = { blade = 25, attack = 1, righteous = 50 } },
    { id = "thuong_tien_chuyen_the", name = "Thương Tiên Chuyển Thế", rarity = "hiem", bonus = { spear = 25, attack = 1, righteous = 50 } },
    { id = "quyen_tien_chuyen_the", name = "Quyền Tiên Chuyển Thế", rarity = "hiem", bonus = { fist = 25, attack = 1, righteous = 50 } },
    { id = "chi_tien_chuyen_the", name = "Chỉ Tiên Chuyển Thế", rarity = "hiem", bonus = { finger = 25, attack = 1, righteous = 50 } },
    { id = "chuong_tien_chuyen_the", name = "Chưởng Tiên Chuyển Thế", rarity = "hiem", bonus = { palm = 25, attack = 1, righteous = 50 } },
    { id = "luyen_dan_cuong_ma", name = "Luyện Đan Cuồng Ma", rarity = "hiem", bonus = { alchemy = 25, demon = 50 } },
    { id = "pha_thien_co", name = "Phá Thiên Cơ", rarity = "hiem", bonus = { fengshui = 40, hp = -20 } },
    { id = "thong_minh_ta_dinh", name = "Thông Minh Tạ Đỉnh", rarity = "hiem", bonus = { sanity = 50, charm = -300 } },
    { id = "thien_menh", name = "Thiên Mệnh Chi Tôn", rarity = "tien", bonus = { luck = 30, charm = 200 } },
    -- Tiên Phẩm (đỏ) thêm từ danh sách game; Niệm lực = qimax (nguyên khí), Cự ly công kích = range (tầm đánh)
    { id = "khuynh_quoc_khuynh_thanh", name = "Khuynh Quốc Khuynh Thành", rarity = "tien", bonus = {}, charmlock = 900, note = "Mị lực khóa chặt ở 900" },
    { id = "hinh_thien_vu_can_thich", name = "Hình Thiên Vũ Cán Thích", rarity = "tien", bonus = { attack = 10, defense = -3, hp = 100 } },
    { id = "tu_dien_thu_dich", name = "Tứ Diện Thụ Địch", rarity = "tien", bonus = { charm = -300, attack = 10, luck = 10, hp = 50 } },
    { id = "hau_nghe_xa_nhat", name = "Hậu Nghệ Xạ Nhật", rarity = "tien", bonus = { attack = 5, range = 2, crit = 20 } },
    { id = "toan_moc_thu_hoa", name = "Toản Mộc Thủ Hỏa", rarity = "tien", bonus = { hoa = 20, moc = 5, defense = 5 } },
    { id = "khoa_phu_truy_nhat", name = "Khoa Phụ Truy Nhật", rarity = "tien", bonus = { qimax = 50, speed = 150, sanity = 10 } },
    { id = "tu_cuc_thuc_loi_the", name = "Tử Cực Thực Lôi Thể", rarity = "tien", bonus = { defense = 5, loi = 35, otherroot = -10 } },
    { id = "minh_am_at_hoa_the", name = "Minh Âm Ất Hỏa Thể", rarity = "tien", bonus = { defense = 5, hoa = 35, otherroot = -10 } },
    { id = "u_tu_nhuoc_thuy_the", name = "U Tứ Nhược Thủy Thể", rarity = "tien", bonus = { defense = 5, thuy = 35, otherroot = -10 } },
    { id = "thu_nguyen_bi_phong_the", name = "Thu Nguyên Bi Phong Thể", rarity = "tien", bonus = { defense = 5, phong = 35, otherroot = -10 } },
    { id = "dich_tran_linh_tho_the", name = "Địch Trần Linh Thổ Thể", rarity = "tien", bonus = { defense = 5, tho = 35, otherroot = -10 } },
    { id = "co_dang_bach_moc_the", name = "Cổ Đằng Bách Mộc Thể", rarity = "tien", bonus = { defense = 5, moc = 35, otherroot = -10 } },
    { id = "ngu_cong_di_son", name = "Ngu Công Di Sơn", rarity = "tien", bonus = { hp = 80, hunger = 10, qimax = 50 } },
    -- Tiên Phẩm (đỏ) đợt 2; Cước lực = speed, Niệm lực = qimax, Tinh lực tối đa = hunger, Tư chất linh căn (mọi hệ) = allroot
    { id = "hong_hoc_si_toc", name = "Hồng Hộc Sĩ Tộc", rarity = "tien", bonus = { attack = 5, gongfa = 10, hunger = 10 } },
    { id = "bac_vuc_ma_anh", name = "Bắc Vực Ma Anh", rarity = "tien", bonus = { attack = 5, fist = 10, palm = 10, finger = 10, phong = 20, fame = 100 } },
    { id = "can_thi_dao_dong", name = "Cản Thi Đạo Đồng", rarity = "tien", bonus = { defense = 5, fist = 20, palm = 20, finger = 20, charm = -100, fame = 100, demon = 80 } },
    { id = "luc_dao_tu_ma_gia", name = "Lục Đạo Tu Ma Giả", rarity = "tien", bonus = { attack = 5, gongfa = 6, allroot = 6, sanity = 10, fame = 50, demon = 100 } },
    { id = "thien_menh_chi_tu", name = "Thiên Mệnh Chi Tử", rarity = "tien", bonus = { luck = 50, speed = 100, charm = 200 } },
    { id = "nhan_toc_thanh_the", name = "Nhân Tộc Thánh Thể", rarity = "tien", bonus = { attack = 8, sanity = 10, luck = 10, hp = 100, charm = 100 } },
    { id = "sat_than_khi_do", name = "Sát Thần Khí Đồ", rarity = "tien", bonus = { attack = 8, gongfa = 15, sanity = -10, demon = 100 } },
    { id = "quy_coc_ngoai_mon", name = "Quỷ Cốc Ngoại Môn", rarity = "tien", bonus = { attack = 10, sanity = 30, fame = 150, charm = 100 } },
    { id = "nhac_thien_nhat_phai", name = "Nhạc Thiên Nhất Phái", rarity = "tien", bonus = { luck = 30, charm = 200, speed = 100, moodregen = 100 } },
    { id = "thien_tam_tai", name = "Thiên Tam Tài", rarity = "tien", bonus = { phong = 25, hoa = 25, loi = 25, attack = 3 } },
    { id = "dia_tam_tai", name = "Địa Tam Tài", rarity = "tien", bonus = { tho = 25, moc = 25, thuy = 25, defense = 3 } },
    { id = "luc_can_bat_tinh", name = "Lục Căn Bất Tịnh", rarity = "tien", bonus = { allroot = 20, qimax = -80, hunger = -20, attack = 3 } },
    { id = "luc_can_thanh_tinh", name = "Lục Căn Thanh Tịnh", rarity = "tien", bonus = { allroot = -10, gongfa = 10, qimax = 200, hunger = 10 } },
    { id = "nguyen_to_chi_luc", name = "Nguyên Tố Chi Lực", rarity = "tien", bonus = { allroot = 20, gongfa = -5 } },
    { id = "khai_son_song_tuyet", name = "Khai Sơn Song Tuyệt", rarity = "tien", bonus = { fist = 30, palm = 30, defense = 5 } },
    { id = "bach_hong_quan_nhat", name = "Bạch Hồng Quán Nhật", rarity = "tien", bonus = { spear = 30, finger = 30, crit = 20 } },
    { id = "vu_phap_linh_dong", name = "Vũ Pháp Linh Đồng", rarity = "tien", bonus = { gongfa = 18, attack = 5 } },
    { id = "truong_sinh", name = "Trường Sinh Thể", rarity = "hiem", bonus = { thuy = 15, moc = 15, hp = 10 } },
    { id = "dan_tien", name = "Đan Tiên Chuyển Thế", rarity = "hiem", bonus = { alchemy = 25, righteous = 100 } },
    -- Linh Phẩm (xanh lam) thêm từ danh sách game
    { id = "phien_phien_luong_nhan", name = "Phiên Phiên Lương Nhân", rarity = "linh", bonus = { defense = 2, charm = 50, fame = 50 } },
    { id = "y_me_phieu_phieu", name = "Y Mệ Phiêu Phiêu", rarity = "linh", bonus = { phong = 5, charm = 100, fame = 50 } },
    { id = "thien_sinh_linh_the", name = "Thiên Sinh Linh Thể", rarity = "linh", bonus = { qimax = 100 } },
    { id = "ung_nhan", name = "Ưng Nhãn", rarity = "linh", bonus = { crit = 30 } },
    { id = "thien_sinh_tue_can", name = "Thiên Sinh Tuệ Căn", rarity = "linh", bonus = { hoa = 5, tho = 5, loi = 5, moc = 5, thuy = 5, phong = 5, sanity = 10 } },
    { id = "thien_tu_can_cot", name = "Thiên Tư Căn Cốt", rarity = "linh", bonus = { gongfa = 5, sanity = 10 } },
    { id = "cat_kho_nai_lao", name = "Cật Khổ Nại Lao", rarity = "linh", bonus = { sanity = -5, sanityrate = -30, hungerrate = -30 } },
    { id = "nga_hanh_nga_to", name = "Ngã Hành Ngã Tố", rarity = "linh", bonus = { demon = 50, moodregen = 50 } },
    { id = "dao_kiem_hiep_khach", name = "Đao Kiếm Hiệp Khách", rarity = "linh", bonus = { blade = 15, sword = 15 } },
    { id = "trac_nhat_chi", name = "Trạc Nhất Chỉ", rarity = "linh", bonus = { spear = 15, finger = 15 } },
    { id = "quyen_chuong_lieu_dac", name = "Quyền Chưởng Liễu Đắc", rarity = "linh", bonus = { fist = 15, palm = 15 } },
    { id = "thuong_son_nhan", name = "Thường Sơn Nhân", rarity = "linh", bonus = { spear = 10, righteous = 10 } },
    { id = "lang_hai", name = "Lang Hài", rarity = "linh", bonus = { attack = 5, fist = 10, charm = -100 } },
    { id = "kiem_than_chi_tu", name = "Kiếm Thần Chi Tử", rarity = "linh", bonus = { attack = 2, sword = 5, sanity = 10 } },
    { id = "dao_than_chi_tu", name = "Đao Thần Chi Tử", rarity = "linh", bonus = { attack = 2, blade = 5, sanity = 10 } },
    { id = "thuong_than_chi_tu", name = "Thương Thần Chi Tử", rarity = "linh", bonus = { attack = 2, spear = 5, sanity = 10 } },
    { id = "loi_kich_bat_tu", name = "Lôi Kích Bất Tử", rarity = "linh", bonus = { loi = 20 } },
    { id = "thieu_than_gia", name = "Thiêu Thán Giả", rarity = "linh", bonus = { hoa = 20 } },
    { id = "lang_ly_bach_dieu", name = "Lãng Lý Bạch Điều", rarity = "linh", bonus = { thuy = 20 } },
    { id = "doi_tho_thanh_son", name = "Đôi Thổ Thành Sơn", rarity = "linh", bonus = { tho = 20 } },
    { id = "thuc_thu_thanh_lam", name = "Thực Thụ Thành Lâm", rarity = "linh", bonus = { moc = 20 } },
    { id = "thao_thuong_phi", name = "Thảo Thượng Phi", rarity = "linh", bonus = { phong = 20 } },
    { id = "luyen_dan_cuong_nhan", name = "Luyện Đan Cuồng Nhân", rarity = "linh", bonus = { alchemy = 20, demon = 20 } },
    { id = "thuy_the", name = "Thủy Linh Thể", rarity = "hiem", bonus = { thuy = 25 } },
    { id = "loi_the", name = "Lôi Linh Thể", rarity = "hiem", bonus = { loi = 25 } },
    { id = "phong_the", name = "Phong Linh Thể", rarity = "hiem", bonus = { phong = 25 } },
    { id = "tho_the", name = "Thổ Linh Thể", rarity = "hiem", bonus = { tho = 25 } },
    { id = "moc_the", name = "Mộc Linh Thể", rarity = "hiem", bonus = { moc = 25 } },
    { id = "hoa_the", name = "Hỏa Linh Thể", rarity = "hiem", bonus = { hoa = 25 } },
    { id = "hoi_huong_dau", name = "Hồi Hương Đậu", rarity = "pham", bonus = { luck = 20, hp = -10 } },
    { id = "tru_dot", name = "Trư Đột", rarity = "pham", bonus = { attack = 6, defense = -4 } },
    { id = "moc_tuong", name = "Mộc Tượng", rarity = "pham", bonus = { attack = -1, sanity = 20 } },
    { id = "vi_nhan_chinh_phai", name = "Vi Nhân Chính Phái", rarity = "pham", bonus = { righteous = 50, charm = 100 } },
    { id = "vo_cu_loi_gia", name = "Vô Cụ Lôi Giả", rarity = "pham", bonus = { loi = 5 } },
    { id = "au_nien_ngoan_hoa", name = "Ấu Niên Ngoạn Hỏa", rarity = "pham", bonus = { hoa = 5 } },
    { id = "thien_thuy_chi_nhan", name = "Thiện Thủy Chi Nhân", rarity = "pham", bonus = { thuy = 5 } },
    { id = "con_tho_ngoan_dong", name = "Cổn Thổ Ngoan Đồng", rarity = "pham", bonus = { tho = 5 } },
    { id = "hi_hao_moc_thuc", name = "Hỉ Hảo Mộc Thực", rarity = "pham", bonus = { moc = 5 } },
    { id = "ai_phong_phong_tranh", name = "Ái Phóng Phong Tranh", rarity = "pham", bonus = { phong = 5 } },
    { id = "quy_hoa_phu", name = "Quỷ Họa Phù", rarity = "pham", bonus = { fengshui = 10, hunger = 10 } },
    { id = "thien_thuc_quai_tuong", name = "Thiển Thức Quái Tượng", rarity = "pham", bonus = { fengshui = 10, luck = 10 } },
    { id = "ham_nhan", name = "Hàm Nhân", rarity = "pham", bonus = { sanity = -10, charm = 200 } },
    { id = "nao_tu", name = "Nạo Tử", rarity = "pham", bonus = { sanity = -10, moodregen = 50 } },
    { id = "tri_ke_qua_nhan", name = "Trí Kế Quá Nhân", rarity = "pham", bonus = { sanity = 10, luck = -10, charm = 100 } },
    { id = "vu_van_long_mac", name = "Vũ Văn Lộng Mặc", rarity = "pham", bonus = { gongfa = -5, sanity = 25 } },
    { id = "thu_huong_mon_de", name = "Thư Hương Môn Đệ", rarity = "pham", bonus = { gongfa = -3, sanity = 20 } },
    { id = "vu_dao_long_thuong", name = "Vũ Đao Lộng Thương", rarity = "pham", bonus = { gongfa = 3, sanity = -5 } },
    { id = "vo_dao_the_gia", name = "Võ Đạo Thế Gia", rarity = "pham", bonus = { gongfa = 3, sanity = -5 } },
    { id = "ta_phiet_tu", name = "Tả Phiết Tử", rarity = "pham", bonus = { sanity = 15, fame = -50 } },
    { id = "thien_menh_gia_tang_ton", name = "Thiên Mệnh Giả Tằng Tôn", rarity = "pham", bonus = { luck = -5, charm = 150 } },
    { id = "chien_dau_cuong_nhan", name = "Chiến Đấu Cuồng Nhân", rarity = "pham", bonus = { attack = 2, demon = 50, charm = -100 } },
    { id = "sat_tru_gia", name = "Sát Trư Giả", rarity = "pham", bonus = { attack = 2, crit = 10 } },
    { id = "thu_sao_ban_lat", name = "Thủ Sao Bản Lật", rarity = "pham", bonus = { palm = 15, finger = -10 } },
    { id = "pha_thien_dan_cung", name = "Pha Thiện Đạn Cung", rarity = "pham", bonus = { finger = 10 } },
    { id = "hao_da_sa_bao", name = "Hảo Đả Sa Bao", rarity = "pham", bonus = { fist = 10 } },
    { id = "hao_su_bien_dam", name = "Hảo Sử Biển Đam", rarity = "pham", bonus = { spear = 10 } },
    { id = "phach_sai_hao_thu", name = "Phách Sài Hảo Thủ", rarity = "pham", bonus = { blade = 10 } },
    { id = "hao_ngoan_oa_san", name = "Hảo Ngoạn Oa Sạn", rarity = "pham", bonus = { sword = 10 } },
    { id = "thuy_huong_hai_tu", name = "Thủy Hương Hài Tử", rarity = "pham", bonus = { thuy = 10, charm = 50 } },
    { id = "sam_lam_hai_tu", name = "Sâm Lâm Hài Tử", rarity = "pham", bonus = { moc = 10, charm = 50 } },
    { id = "chich_viem_hai_tu", name = "Chích Viêm Hài Tử", rarity = "pham", bonus = { hoa = 10, charm = 50 } },
    { id = "son_khau_hai_tu", name = "Sơn Khâu Hài Tử", rarity = "pham", bonus = { tho = 10, charm = 50 } },
    { id = "truy_phong_hai_tu", name = "Truy Phong Hài Tử", rarity = "pham", bonus = { phong = 10, charm = 50 } },
    { id = "loi_dinh_hai_tu", name = "Lôi Đình Hài Tử", rarity = "pham", bonus = { loi = 10, charm = 50 } },
    { id = "tieu_dan_dong", name = "Tiểu Đan Đồng", rarity = "pham", bonus = { alchemy = 12 } },
    { id = "kham_du_su", name = "Khám Dư Sư", rarity = "pham", bonus = { fengshui = 25 } },
    { id = "dan_than_quy_toc", name = "Đan Thân Quý Tộc", rarity = "pham", bonus = { charm = 100, fame = 150 } },
    { id = "hong_thanh_nhu_loi", name = "Hống Thanh Như Lôi", rarity = "pham", bonus = { attack = 5, charm = -50, fame = 50 } },
    { id = "van_du_thien_ha", name = "Vân Du Thiên Hạ", rarity = "pham", bonus = { charm = 150, fame = 100 } },
    { id = "hao_nhien_chinh_khi", name = "Hạo Nhiên Chính Khí", rarity = "pham", bonus = { fame = 100, charm = 100, righteous = 100 } },
    { id = "ta_khi_ngoai_lo", name = "Tà Khí Ngoại Lộ", rarity = "pham", bonus = { fame = 100, charm = 100, demon = 100 } },
}

M.BY_ID = {}
for _, d in ipairs(M.LIST) do
    M.BY_ID[d.id] = d
    d.desc = M.Describe(d.bonus, false, d.note)        -- dùng trong màn chọn
    d.desc_short = M.Describe(d.bonus, true)   -- dùng trong bảng B
end

-- khí vận được phép xuất hiện khi roll: bỏ khí vận cộng linh căn của hệ chưa có trong ELEM.LIST
-- (vd "phong": thêm hệ Phong vào cosu_element_tuning.LIST thì Phong Linh Thể tự xuất hiện)
local ELEM_IDS = {}
for _, e in ipairs(ELEM.LIST) do ELEM_IDS[e.id] = true end

function M.Pool()
    local out = {}
    for _, d in ipairs(M.LIST) do
        local ok = true
        for k in pairs(d.bonus) do
            local st = M.STAT_BY_KEY[k]
            if st ~= nil and st.root and not ELEM_IDS[k] then ok = false end
        end
        if ok then table.insert(out, d) end
    end
    return out
end

-- cộng các khí vận trong chuỗi "id1,id2" -> { hoa = 20, attack = 6, ... }
function M.Sum(idstr)
    local sum = {}
    for id in string.gmatch(idstr or "", "[%w_]+") do
        local d = M.BY_ID[id]
        if d ~= nil then
            if d.sanitylock ~= nil then sum.sanitylock = math.max(sum.sanitylock or 0, d.sanitylock) end
            if d.charmlock ~= nil then sum.charmlock = math.max(sum.charmlock or 0, d.charmlock) end
            for k, v in pairs(d.bonus) do
                if k == "allroot" then
                    -- cộng cho mọi linh căn (có trong ELEM.LIST), kể cả hệ đã ghi riêng
                    for _, rk in ipairs(M.ROOT_KEYS) do
                        if ELEM_IDS[rk] then sum[rk] = (sum[rk] or 0) + v end
                    end
                elseif k == "otherroot" then
                    -- mọi linh căn (có trong ELEM.LIST) mà khí vận này không ghi riêng
                    for _, rk in ipairs(M.ROOT_KEYS) do
                        if ELEM_IDS[rk] and (d.bonus[rk] or 0) == 0 then sum[rk] = (sum[rk] or 0) + v end
                    end
                else
                    sum[k] = (sum[k] or 0) + v
                end
            end
        end
    end
    -- Mị lực khóa chặt: đặt đúng bằng giá trị khóa, bất kể các khí vận khác cộng / trừ bao nhiêu
    if sum.charmlock ~= nil then sum.charm = sum.charmlock end
    return sum
end

-- khóa linh căn (hoa, tho...) của một mục trong ELEM.LIST, nil nếu không khớp
function M.RootKeyOf(e)
    local id = string.lower(tostring(e.id or ""))
    local label = string.lower(tostring(e.label or ""))
    for key, names in pairs(M.ROOT_ALIAS) do
        for _, n in ipairs(names) do
            if n == id or n == label then return key end
        end
    end
    return nil
end

return M