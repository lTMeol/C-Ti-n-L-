-- Danh sách cổ trùng có thể luyện hóa vào Nguyên Hải.
-- Thêm cổ trùng mới: thêm 1 dòng vào LIST (KHÔNG đổi thứ tự các dòng cũ,
-- vì save game lưu theo số thứ tự).
local T = {}

T.MAX_GU = 24 -- số ô chứa cổ trùng ở hàng dưới
T.SLOTS = 9   -- số ô vuông (mở theo chuyển: chuyển n mở ô n)

-- Ánh sáng khi cổ trùng (có light) nằm trong 9 ô trang bị hoặc ô Bản Mệnh Cổ.
-- Số liệu xấp xỉ đèn lồng, chưa đối chiếu với game: chỉnh tại đây cho vừa ý.
T.LIGHT = {
    radius = 1.5,
    intensity = 0.8,
    falloff = 0.5,
    colour = { 200 / 255, 200 / 255, 50 / 255 },
}
T.MAIN_LIGHT_MULT = 2.5 -- ánh sáng mạnh: bán kính sáng nhân hệ số này

-- Gỡ cổ trùng đang trang bị ra khỏi ô cần tiêu linh thạch (lấy trong túi).
-- grade là khóa phẩm trong cosu_tuning.GRADES / PREFAB (cosu_stones.lua): "low", "mid", ...
-- !!! Nếu phẩm "thượng" của bạn không tên "high" thì đổi grade của main cho đúng.
local COSU = require "cosu_tuning"
T.UNEQUIP_STONE = {
    main = { grade = "high", count = 1 }, -- ô Bản Mệnh Cổ
    slot = { grade = "mid", count = 1 },  -- 9 ô trang bị
}
for _, st in pairs(T.UNEQUIP_STONE) do
    st.prefab = COSU.PREFAB[st.grade]
    st.name = COSU.NAME[st.grade] or st.prefab -- tên hiển thị lấy đúng tên nguyên thạch trong game
end

-- Độ đói của cổ trùng: mỗi con (đã luyện hóa, dù trang bị hay chưa) có thanh đói riêng.
-- Đầy lúc vừa luyện hóa, tụt về 0 sau DURATION giây; về 0 là cổ chết mất vĩnh viễn.
-- Cho ăn bằng đồ ăn trong túi / balo: cộng thêm (giá trị đói của món / FULL_VALUE) vào thanh.
T.HUNGER = {
    DURATION = (TUNING ~= nil and TUNING.TOTAL_DAY_TIME) or 480, -- giây để từ đầy về 0 (mặc định đúng 1 ngày trong game)
    WARN = 0.25,           -- còn bấy nhiêu thì nhân vật cảnh báo
    FULL_VALUE = 75,       -- món có giá trị đói bằng số này làm đầy cả thanh (thịt chín 25 = 1/3 thanh)
    MIN_FOOD_VALUE = 5,    -- món ít đói/không đói vẫn tính tối thiểu bấy nhiêu
    -- loại đồ ăn được phép cho ăn (tên khóa trong FOODTYPE của game)
    FOOD_TYPES = { "GENERIC", "MEAT", "VEGGIE", "GOODIES", "SEEDS", "BERRY", "INSECT", "MONSTER", "RAW", "ROUGHAGE" },
}
T.HUNGER.FEED_SET, T.HUNGER.FEED_TAGS = {}, {}
for _, name in ipairs(T.HUNGER.FOOD_TYPES) do
    local ft = FOODTYPE ~= nil and FOODTYPE[name] or nil
    if ft ~= nil then
        T.HUNGER.FEED_SET[ft] = true
        table.insert(T.HUNGER.FEED_TAGS, "edible_" .. ft)
    end
end

-- Số liệu hai kỹ năng chủ động (Sao trời của Thiên Tinh Huỳnh Cổ, Quang Hóa của Vương Cổ).
T.VUONG = {
    -- Sao trời (giống Gậy Gọi Sao): dùng prefab ánh sáng của game
    STAR_COOLDOWN = 40,     -- hồi chiêu (giây), thả sao mới thì sao cũ biến mất
    STAR_RANGE = 25,        -- xa nhất bao nhiêu so với người chơi (vòng chọn bị kẹp trong phạm vi này)
    STAR_CAST_DELAY = 0.9,  -- chờ hoạt ảnh vung gậy xong mới hiện ánh sáng (giây)

    -- Các mục dưới đây chỉ còn dùng cho prefab cũ cosu_gu_star (ngôi sao đã lưu trong save).
    -- Sao trời mới không dùng. Xóa cùng lúc với file cosu_gu_star.lua nếu muốn dọn.
    STAR_DAYS = 5,
    STAR_HEIGHT = 3,
    STAR_SCALE = 1.8,
    STAR_LIGHT = { radius = 6, intensity = 0.85, falloff = 0.6, colour = { 1.0, 0.92, 0.55 } },

    -- Quang Hóa (cổ nằm ở ô Bản Mệnh Cổ)
    QUANG_DURATION = 15,       -- thời gian tích đòn đánh (giây)
    QUANG_COOLDOWN = 30,       -- hồi chiêu (giây), tính sau khi hết trạng thái
    QUANG_DAMAGE = 20,         -- sát thương hồn ma đầu tiên
    QUANG_DAMAGE_STEP = 1,     -- mỗi hồn ma sau cộng thêm bấy nhiêu (đòn thứ n = 20 + (n-1))
    QUANG_RADIUS = 20,         -- tìm kẻ địch trong phạm vi này quanh người chơi
    QUANG_INTERVAL = 0.15,     -- khoảng cách giữa hai hồn ma (giây)
    QUANG_PROJECTILE = "alterguardianhat_projectile", -- hồn ma của Enlightened Crown
    QUANG_SCALE = 1.3,
}

-- Tích Lịch Cổ (cổ trùng hệ Lôi)
T.TICHLICH = {
    -- Nội tại: có trong 9 ô trang bị (hoặc Bản Mệnh Cổ nếu PASSIVE_IN_MAIN) -> đánh thường có tỷ lệ gọi sét
    PASSIVE_IN_MAIN = true,
    PASSIVE_CHANCE = 0.25,   -- 25% mỗi đòn đánh thường
    PASSIVE_DAMAGE = 50,

    -- Kỹ năng ở ô Bản Mệnh Cổ: Thiên Lôi
    BOLT_COUNT = 30,         -- số tia sét
    BOLT_DAMAGE = 60,        -- sát thương mỗi tia
    BOLT_RADIUS = 12,        -- phạm vi quanh người chơi: 3 ô = 12 đơn vị (1 ô = 4)
    BOLT_INTERVAL = 0.1,     -- khoảng cách giữa hai tia (giây)
    COOLDOWN = 45,           -- hồi chiêu (giây)
    QI_COST = 30,            -- nguyên khí tiêu hao
}

-- U Lôi Huyễn Điệp Cổ (cổ trùng hệ Lôi)
T.ULOI = {
    -- Nội tại (trang bị ở 9 ô hoặc Bản Mệnh Cổ): miễn nhiễm điện / giật điện / sét + tăng tốc chạy
    SPEED_SLOT = 1.2,        -- ô thường: +20% tốc độ di chuyển
    SPEED_MAIN = 1.3,        -- ô Bản Mệnh Cổ: +30%

    -- Kỹ năng Lôi Hóa (cả ô thường lẫn Bản Mệnh Cổ): tiêu 1 vật phẩm trong túi để vào trạng thái lôi hóa.
    -- Thứ tự dưới đây cũng là thứ tự ưu tiên tiêu hao (món rẻ nhất trước).
    LOIHOA_FOODS = {
        { prefab = "lightninggoathorn", name = "Sừng Dê", seconds = 20 },
        { elem = "loi", part = "shard", name = "Mảnh Vỡ Lôi", seconds = 40 },
        { elem = "loi", part = "root", name = "Lôi Linh Căn", seconds = 60 },
    },
    LOIHOA_MAX = 120,        -- ăn khi đang lôi hóa thì cộng dồn thời gian, tối đa bấy nhiêu giây
    LOIHOA_COOLDOWN = 0,     -- hồi chiêu (giây)
    -- Đòn đánh thường trong lôi hóa: tổng sát thương = hệ số x sát thương gốc (phần tăng thêm là sát thương điện)
    LOIHOA_MULT = 1.5,
    LOIHOA_WET_MULT = 2.5,   -- khi mục tiêu đang ướt

    -- Kỹ năng Giáng Lôi (chỉ ở ô Bản Mệnh Cổ): chọn vị trí bằng chuột phải như Sao trời
    GIANGLOI_DAMAGE = 600,   -- TỔNG sát thương, chia đều cho 2 đợt sét (mỗi đợt 300)
    GIANGLOI_HALF = 4,       -- nửa cạnh vùng trúng: 2x2 ô = 8 đơn vị (1 ô = 4) -> nửa cạnh 4 (vòng chỉ báo và lúc cast dùng chung)
    GIANGLOI_RANGE = 20,     -- xa nhất bao nhiêu so với người chơi
    GIANGLOI_COOLDOWN = 60,  -- hồi chiêu (giây)
    GIANGLOI_CAST_DELAY = 0.5, -- chờ hoạt ảnh vung gậy xong mới sét giáng xuống (giây)
    GIANGLOI_FX = "cosu_giangloi_fx", -- prefab hiệu ứng tia sét (animation cosu_giangloi)
    GIANGLOI_HIT_DELAY = 0.5, -- giây từ lúc hiệu ứng hiện đến lúc tia sét chạm đất (frame chạm đất / 30)
    GIANGLOI_FX_SCALE = 1.33, -- phóng to tia sét (thu nhỏ theo 4/6 so với vùng 3x3 cũ)
    GIANGLOI_RETICULE_SCALE = 1.07, -- phóng to vòng chọn vị trí cho vừa vùng 2x2 ô (chỉnh theo mắt)
}

-- Ẩn Thạch Cổ (chỉ ra từ Thạch Quán; KHÔNG trang bị được vào Bản Mệnh Cổ)
T.ANTHACH = {
    -- Kỹ năng Ẩn Thân (bật/tắt, chỉ ở 9 ô trang bị): không sinh vật nào phát hiện / nhắm tới mình
    QI_COST = 1,         -- nguyên khí tiêu mỗi lần tính (lần đầu trừ ngay lúc bật)
    QI_INTERVAL = 2,     -- cứ bấy nhiêu giây trừ QI_COST một lần; hết nguyên khí thì tự tắt
    COOLDOWN = 0,        -- hồi chiêu sau khi bật (giây)
    ALPHA = 0.4,         -- độ mờ của nhân vật khi ẩn thân (1 = bình thường)
    DROP_INTERVAL = 0.5, -- giây giữa 2 lần bắt quái đang nhắm mình bỏ mục tiêu
    DROP_RADIUS = 40,    -- tìm quái đang nhắm mình trong phạm vi này
}

-- Thạch Bì Cổ (chỉ ra từ Thạch Quán; KHÔNG trang bị được vào Bản Mệnh Cổ)
T.THACHBI = {
    -- Nội tại (chỉ ở 9 ô trang bị): giảm sát thương linh căn của quái bộc phát lên mình, đổi lại chạy chậm hơn
    ROOT_TAKEN_MULT = 0.78, -- sát thương linh căn nhận vào x0.78 (giảm 22%)
    SPEED_MULT = 0.9,       -- di tốc x0.9 (giảm 10%)
}

-- Nguyên khí tiêu hao của từng kỹ năng (cổ có nhiều kỹ năng dùng qi_costs = { kind = số })
function T.GetQiCost(gu, kind, QI)
    return (gu.qi_costs ~= nil and gu.qi_costs[kind]) or gu.qi_cost or QI.COST[kind] or QI.DEFAULT_COST
end

-- Danh sách kỹ năng chủ động của cổ ở ô place (skill_main / skill_slot có thể là chuỗi hoặc bảng nhiều kỹ năng)
function T.GetSkills(gu, place)
    local s = place == 0 and gu.skill_main or gu.skill_slot
    if s == nil then return {} end
    if type(s) == "table" then return s end
    return { s }
end

-- Phím tắt dùng kỹ năng chủ động (theo loại kỹ năng). Tên phím theo hằng KEY_ của game: "Z" -> KEY_Z.
-- Đổi chữ cái tại đây nếu trùng phím khác; để nil / xóa dòng thì chỉ bấm được bằng nút trên màn hình.
T.SKILL_KEYS = {
    quanghoa = "Z",
    star = "X",
    thunder = "C",
    loihoa = "V",
    giangloi = "B",
}

-- rank: cảnh giới của cổ (2 = nhị chuyển, 3 = tam chuyển...). Luyện hóa cần cảnh giới người chơi >= rank.
-- light: 1 = sáng yếu, 2 = sáng mạnh (nhiều con cùng trang bị thì lấy cấp cao nhất)
-- skill_main: kỹ năng chủ động khi nằm ở ô Bản Mệnh Cổ (xem cosu_gu_bag.lua)
T.LIST = {
    {
        prefab = "cosu_gu_thientinh",
        rank = 2, -- cảnh giới (chuyển): người chơi phải đạt chuyển này mới luyện hóa được
        elem = "quang", -- hệ nguyên tố (xem cosu_element_tuning.COMBAT)
        name = "Thiên Tinh Huỳnh Cổ",
        light = 1,
        tip_main = "Phát ra ánh sáng yếu. Kỹ năng: Sao trời", -- chữ hiện khi rê chuột vào ô Bản Mệnh Cổ
        tip_slot = "Phát ra ánh sáng yếu",                    -- chữ hiện khi rê chuột vào 1 trong 9 ô
        skill_main = "star",
    },
    {
        prefab = "cosu_gu_thientinh_vuong",
        rank = 3, -- cảnh giới (chuyển): người chơi phải đạt chuyển này mới luyện hóa được
        elem = "quang",
        name = "Thiên Tinh Huỳnh Vương Cổ",
        light = 2,
        tip_main = "Phát ra ánh sáng mạnh. Kỹ năng: Quang Hóa",
        tip_slot = "Phát ra ánh sáng mạnh",
        skill_main = "quanghoa",
    },
    {
        prefab = "cosu_gu_tichlich",
        rank = 2, -- cảnh giới (chuyển): người chơi phải đạt chuyển này mới luyện hóa được
        elem = "loi",
        name = "Tích Lịch Cổ",
        passive = "thunder", -- nội tại: đánh thường có tỷ lệ gọi sét (xem T.TICHLICH)
        tip_main = "Đánh thường có 25% gọi sét (50 sát thương). Kỹ năng: Thiên Lôi",
        tip_slot = "Đánh thường có 25% gọi sét giáng xuống mục tiêu (50 sát thương)",
        skill_main = "thunder",
        qi_cost = 30, -- giữ bằng T.TICHLICH.QI_COST
    },
    {
        prefab = "cosu_gu_uloi",
        rank = 3, -- cảnh giới (chuyển): người chơi phải đạt chuyển này mới luyện hóa được
        elem = "loi",
        name = "U Lôi Huyễn Điệp Cổ",
        passive_elec = true, -- miễn nhiễm điện + tăng tốc chạy (xem T.ULOI)
        tip_main = "Miễn nhiễm điện, giật điện, sét; tăng 30% tốc độ di chuyển. Kỹ năng: Lôi Hóa, Giáng Lôi",
        tip_slot = "Miễn nhiễm điện, giật điện, sét; tăng 20% tốc độ di chuyển. Kỹ năng: Lôi Hóa",
        skill_main = { "loihoa", "giangloi" },
        skill_slot = "loihoa",
        qi_costs = { loihoa = 20, giangloi = 50 },
    },
    {
        prefab = "cosu_gu_anthach",
        rank = 1, -- nhất chuyển
        name = "Ẩn Thạch Cổ",
        no_main = true,   -- không trang bị được vào ô Bản Mệnh Cổ (xem CosuGuBag:Equip)
        shop_only = true, -- chỉ tìm thấy khi đổ thạch (không có công thức chế tạo)
        tip_main = "Không thể trang bị vào ô Bản Mệnh Cổ",
        tip_slot = "Kỹ năng: Ẩn Thân (bật/tắt, 1 nguyên khí mỗi 2 giây, không bị sinh vật nào phát hiện)",
        skill_slot = "anthan",
        qi_costs = { anthan = 1 },
    },
    {
        prefab = "cosu_gu_thachbi",
        rank = 1, -- nhất chuyển
        name = "Thạch Bì Cổ",
        no_main = true,   -- không trang bị được vào ô Bản Mệnh Cổ (xem CosuGuBag:Equip)
        shop_only = true, -- chỉ tìm thấy khi đổ thạch (không có công thức chế tạo)
        atlas_from = "cosu_gu_anthach", -- dùng chung file xml/tex với Ẩn Thạch Cổ (trong xml có sẵn vùng ảnh cosu_gu_thachbi.tex)
        passive_thachbi = true, -- nội tại: giảm sát thương linh căn nhận vào, giảm di tốc (xem T.THACHBI)
        tip_main = "Không thể trang bị vào ô Bản Mệnh Cổ",
        tip_slot = "Giảm 22% sát thương linh căn nhận vào, nhưng giảm 10% tốc độ di chuyển",
    },
}

T.ID = {}
for i, gu in ipairs(T.LIST) do
    T.ID[gu.prefab] = i
    gu.atlas = "images/inventoryimages/" .. (gu.atlas_from or gu.prefab) .. ".xml"
    gu.image = gu.prefab .. ".tex"
end

return T