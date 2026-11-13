-- Linh Căn (8 hệ) và Mảnh Vỡ Nguyên Tố dùng để chế ra chúng.
-- Thêm/bớt hệ hoặc chỉnh số lượng ở đây, không cần sửa chỗ khác.
local M = {}

-- cần bao nhiêu mảnh vỡ để chế 1 linh căn
M.SHARDS_PER_ROOT = 50

-- Hình vật phẩm khi nằm dưới đất.
--   USE_CUSTOM_ANIM = false : dùng tạm hoạt họa viên ngọc của game, nhuộm màu (GROUND_*) - để thử khi chưa có anim
--   USE_CUSTOM_ANIM = true  : dùng 1 file anim chung làm từ 16 ảnh PNG (Anim Tool > Load Sequence > Export).
--                             Mỗi vật phẩm hiện 1 khung hình trong anim đó. Khung = vị trí của ảnh khi nạp
--                             (xếp theo tên file, đếm từ 0): xem ANIM_ORDER bên dưới.
--                             Phải có file ANIM_ZIP rồi mới bật true, thiếu file là game báo lỗi khi nạp mod.
M.USE_CUSTOM_ANIM = true
M.ANIM_ZIP = "anim/cosu_element.zip"
M.ANIM_BANK = "cosu_element"   -- tên bank trong Anim Tool (mặc định của tool là "png", đổi cho khỏi trùng mod khác)
M.ANIM_BUILD = "cosu_element"  -- tên build
M.ANIM_NAME = "idle"           -- tên animation (mặc định của tool là "png")
M.ANIM_SCALE = 1.0             -- phóng/thu hình dưới đất (ảnh 128px có thể to hơn ý muốn; thử 0.5 nếu to quá)

M.GROUND_BANK = "gems"
M.GROUND_BUILD = "gems"
M.GROUND_ANIM = "opalpreciousgem"

-- Tất cả icon nằm chung 1 atlas (tạo bằng Atlas Ctor của DST Mod Tool, Atlas Name = cosu_element).
-- Tên từng icon trong atlas = tên file PNG, ví dụ cosu_linhcan_hoa.tex
M.ATLAS = "images/inventoryimages/cosu_element.xml"
M.TEX = "images/inventoryimages/cosu_element.tex"

-- id dùng để ghép tên prefab:  cosu_linhcan_<id>  và  cosu_manh_<id>
-- tint = màu nhuộm hình dưới đất (r, g, b)
M.LIST = {
    { id = "hoa",   label = "Hỏa",   tint = { 1.00, 0.35, 0.20 } },
    { id = "moc",   label = "Mộc",   tint = { 0.40, 1.00, 0.35 } },
    { id = "thuy",  label = "Thủy",  tint = { 0.30, 0.65, 1.00 } },
    { id = "tho",   label = "Thổ",   tint = { 0.80, 0.55, 0.30 } },
    { id = "loi",   label = "Lôi",   tint = { 0.65, 0.40, 1.00 } },
    { id = "am",    label = "Ám",    tint = { 0.35, 0.25, 0.55 } },
    { id = "quang", label = "Quang", tint = { 1.00, 0.95, 0.60 } },
    { id = "kim",   label = "Kim",   tint = { 0.85, 0.90, 1.00 } },
}

-- Thứ tự khung hình = tên file PNG xếp theo bảng chữ cái (Load Sequence nạp theo thứ tự này):
--   0-7  : cosu_linhcan_ am, hoa, kim, loi, moc, quang, tho, thuy
--   8-15 : cosu_manh_    am, hoa, kim, loi, moc, quang, tho, thuy
-- Nếu Anim Tool nạp thứ tự khác thì sửa thẳng bảng này.
M.ANIM_ORDER = {}
for _, e in ipairs(M.LIST) do
    table.insert(M.ANIM_ORDER, "cosu_linhcan_" .. e.id)
    table.insert(M.ANIM_ORDER, "cosu_manh_" .. e.id)
end
table.sort(M.ANIM_ORDER)
M.ANIM_FRAME = {}   -- tên prefab -> số khung (từ 0)
for i, name in ipairs(M.ANIM_ORDER) do
    M.ANIM_FRAME[name] = i - 1
end
M.ANIM_FRAME_COUNT = #M.ANIM_ORDER

for i, e in ipairs(M.LIST) do
    e.index = i
    e.root = "cosu_linhcan_" .. e.id
    e.shard = "cosu_manh_" .. e.id
    e.root_name = e.label .. " Linh Căn"
    e.shard_name = "Mảnh Vỡ " .. e.label
    e.root_atlas = M.ATLAS
    e.root_image = e.root .. ".tex"
    e.shard_atlas = M.ATLAS
    e.shard_image = e.shard .. ".tex"
end

----------------------------------------------------------------- Chiến đấu nguyên tố
-- Toàn bộ số liệu của hệ thống sát thương nguyên tố nằm ở đây; logic ở cosu_element_combat.lua.
M.COMBAT = {
    -- ===== Cảnh giới của quái =====
    -- Quái có cảnh giới (từ Nhất Chuyển trở lên) mới có linh căn và mới có kháng:
    --   * số linh căn = số chuyển (tối đa #LIST - BOSS_MIN_OPEN hệ, để người chơi còn đường đánh)
    --   * mỗi linh căn có 1 con số (vd Hỏa linh căn: 30): mỗi đòn quái trúng người chơi gây thêm đúng số đó sát thương hệ đó
    --   * kháng PHYS_RESIST sát thương thường từ người chơi và đồng minh
    --   * giảm sát thương nguyên tố CÙNG HỆ với linh căn của nó: ELEM_RESIST_PER_RANK x số chuyển
    --     (Nhất 10%, Nhị 20%, ... Cửu 90%). Hệ quái không có linh căn thì không bị giảm.
    -- Quái cảnh giới 0 ("Không"): không linh căn, không kháng gì.
    PHYS_RESIST = 0.5,
    ELEM_RESIST_PER_RANK = 0.10,
    ELEM_RESIST_MAX = 0.9,      -- giảm tối đa (Cửu Chuyển = 90%)

    -- con số của mỗi linh căn = ngẫu nhiên trong [MIN x số chuyển, MAX x số chuyển]
    -- (Nhất 5-15, Nhị 10-30, Tam 15-45, Tứ 20-60 ...)
    ROOT_VALUE_PER_RANK_MIN = 5,
    ROOT_VALUE_PER_RANK_MAX = 15,

    MOB_PROC_CHANCE = 1.0,      -- xác suất mỗi linh căn bộc phát trong mỗi đòn trúng người chơi (1.0 = lúc nào cũng gây thêm).
                                -- Hạ xuống (vd 0.5) nếu muốn mỗi hệ tung xúc xắc riêng.

    BOSS_MIN_OPEN = 3,          -- luôn chừa ít nhất 3 hệ không có linh căn
    BOSS_DEFAULT_RANK = 2,      -- boss không ghi trong BOSS_RANK
    -- cảnh giới của boss theo prefab
    BOSS_RANK = {
        -- Nhị Chuyển: boss nhỏ
        leif = 2, leif_sparse = 2, spiderqueen = 2, warg = 2, claywarg = 2, gingerbreadwarg = 2,
        lordfruitfly = 2, mutatedwarg = 2, koalefant_summer = 2, koalefant_winter = 2,
        -- Tam Chuyển: boss mùa và boss giữa game
        deerclops = 3, bearger = 3, moose = 3, dragonfly = 3, beequeen = 3, klaus = 3,
        toadstool = 3, malbatross = 3, antlion = 3, minotaur = 3,
        eyeofterror = 3, twinofterror1 = 3, twinofterror2 = 3,
        mutateddeerclops = 3, mutatedbearger = 3,
        -- Tứ Chuyển: boss khó cuối game
        stalker = 4, stalker_forest = 4, stalker_atrium = 4, toadstool_dark = 4,
        crabking = 4, daywalker = 4, daywalker2 = 4,
        alterguardian_phase1 = 4, alterguardian_phase2 = 4, alterguardian_phase3 = 4,
    },
    -- linh căn mặc định của boss (luôn có nếu số chuyển đủ chỗ, phần còn lại bốc ngẫu nhiên cho đủ số lượng)
    BOSS_FIXED = {
        dragonfly = { "hoa" },
        deerclops = { "thuy" },
        crabking = { "thuy" },
        malbatross = { "thuy" },
        antlion = { "tho" },
        leif = { "moc" },
        leif_sparse = { "moc" },
        stalker = { "am" },
        stalker_forest = { "am" },
        stalker_atrium = { "am" },
        toadstool_dark = { "am" },
        alterguardian_phase1 = { "quang" },
        alterguardian_phase2 = { "quang" },
        alterguardian_phase3 = { "quang" },
    },

    -- Quái thường (trừ mob nhỏ): cảnh giới 0, nhưng có tỷ lệ thấp là Nhất Chuyển
    NORMAL_CHANCE = 0.10,       -- 10% quái thường là Nhất Chuyển (1 linh căn)
    -- quái có hệ "tự nhiên" (chó lửa, chó băng...): luôn là Nhất Chuyển, linh căn là hệ này
    NATURAL_RANK = 1,
    NATURAL = {
        firehound = "hoa", icehound = "thuy", lightninggoat = "loi",
        rocky = "tho", knight = "kim", bishop = "kim", rook = "kim",
        crawlinghorror = "am", terrorbeak = "am", nightmarebeak = "am", crawlingnightmare = "am",
    },

    RANK_NAMES = { "Nhất Chuyển", "Nhị Chuyển", "Tam Chuyển", "Tứ Chuyển", "Ngũ Chuyển",
                   "Lục Chuyển", "Thất Chuyển", "Bát Chuyển", "Cửu Chuyển" },

    -- Số mảnh vỡ rơi cho MỖI linh căn của quái (thay cho rơi ngẫu nhiên)
    SHARDS_NORMAL = 3,
    SHARDS_BOSS = 7,

    -- ===== Người chơi =====
    -- Mỗi cổ trùng đang trang bị (Bản Mệnh Cổ + 9 ô) CỘNG TRỰC TIẾP một linh căn cho người chơi, giống quái:
    -- vd Tích Lịch Cổ +20 Lôi linh căn thì mỗi đòn đánh gây thêm đúng 20 sát thương Lôi.
    -- Người chơi đánh ra TẤT CẢ hệ đang có trong mỗi đòn (không còn tung xúc xắc). Hệ nào quái cũng có linh căn thì bị
    -- giảm 10% x số chuyển của quái. Nhiều cổ cùng hệ thì cộng dồn.
    GU_ROOT_VALUE = {              -- tên prefab cổ trùng -> con số linh căn nó cộng (hệ lấy từ `elem` trong cosu_gu_tuning.LIST)
        cosu_gu_tichlich = 20,
        cosu_gu_uloi = 30,
        cosu_gu_thientinh = 20,
        cosu_gu_thientinh_vuong = 30,
    },
    GU_ROOT_DEFAULT = 20,          -- cổ trùng không ghi trong bảng trên

    RESIST_PER_GU = 10,         -- mỗi cổ trùng hệ X: giảm 10 sát thương nguyên tố X nhận vào
    RESIST_GU_CAP = 3,
    RESIST_PER_ARMOR = 15,      -- mỗi món đồ đúng hệ giảm 15 (đội đủ mũ + giáp = 30)
    -- đồ kháng nguyên tố: hệ -> { prefab = true }. Thêm tay nếu muốn.
    ARMOR_ELEM = {
        quang = { armor_lunarplant = true, lunarplanthat = true },
        am = { armor_voidcloth = true, voidclothhat = true },
    },

    -- Cổ trùng -> hệ. Ưu tiên trường `elem` ghi thẳng trong cosu_gu_tuning.LIST (elem = "loi");
    -- không có thì tra bảng này theo tên prefab của cổ trùng.
    GU_ELEM = {
        -- hiện đã ghi thẳng `elem` trong cosu_gu_tuning.LIST nên bảng này để trống
    },
}

----------------------------------------------------------------- Bảng thông tin nhân vật
-- Phím mở/đóng bảng (widgets/cosu_charinfo.lua): máu, đói, tỉnh táo, nguyên khí, cảnh giới, linh căn đang có.
M.CHARINFO = {
    KEY = "B",
    TITLE = "Thông Tin Nhân Vật",
    -- tên giai theo _cosu_stage. STAGE_FIRST = giá trị của giai đầu tiên (0 hoặc 1); đổi nếu bảng hiện lệch giai
    STAGE_NAMES = { "Sơ Giai", "Trung Giai", "Cao Giai", "Đỉnh Phong" },
    STAGE_FIRST = 1,
    LOCKED_TEXT = "Chưa khai mở",
    TAB_STATUS = "Trạng thái",
    TAB_GU = "Cổ trùng",
    NO_GU_TEXT = "Chưa luyện hóa cổ trùng nào",

    -- Thông tin từng cổ trùng trong trang "Cổ trùng" (key = tên prefab). rank = số chuyển của con cổ.
    -- skills = mô tả kỹ năng, lore = mô tả theo kiểu tu tiên (môi trường sống, tập tính...). Sửa chữ thoải mái.
    GU_INFO = {
        cosu_gu_thientinh = {
            rank = 2,
            skills = "Nội tại: toàn thân phát ánh sáng yếu như đom đóm, soi đường trong đêm. Đặt ở ô Bản Mệnh Cổ, ánh sáng mạnh gấp 2,5 lần.",
            lore = "Thiên Tinh Huỳnh Cổ vốn là đom đóm được cổ sư nuôi bằng sâu phát sáng, trên mình mang một điểm tinh quang như sao trời. "
                .. "Nó sống ở rừng sâu và hang động ẩm tối, đêm đến bay thành từng đàn, ưa nơi có hơi đất ẩm và nấm phát sáng. "
                .. "Cổ sư nhập môn thường dùng nó làm đèn dẫn đường, cũng là con cổ đầu tiên dẫn tinh quang vào Nguyên Hải.",
        },
        cosu_gu_tichlich = {
            rank = 2,
            skills = "Nội tại: trong người mang sấm sét, cộng Lôi linh căn. Thiên Lôi: kỹ năng chủ động dẫn sấm sét đánh vào kẻ địch.",
            lore = "Tích Lịch Cổ sinh ra từ nơi sấm sét hay giáng xuống, thân nhỏ như hạt đậu, vảy đen lóe điện quang. "
                .. "Nó sống nơi núi cao giông bão, thích bám sừng của loài dê hút điện và nuốt tia sét để lớn. "
                .. "Cổ sư luyện nó bằng mảnh vỡ nguyên tố Lôi, sừng và sữa dê điện; tính khí nóng nảy, giận lên là phóng điện khắp người.",
        },
        cosu_gu_thientinh_vuong = {
            rank = 3,
            skills = "Nội tại: tỏa sáng như đèn lồng, ở Bản Mệnh Cổ sáng mạnh hơn. Quang Hóa: tung hồn ma tấn công kẻ địch. Ngôi Sao: thả ngôi sao soi sáng xung quanh (có hồi chiêu).",
            lore = "Thiên Tinh Huỳnh Vương Cổ là con cổ đã dung hợp Quang linh căn, tiến hóa từ Thiên Tinh Huỳnh Cổ thành vua của các loài cổ phát sáng. "
                .. "Nó chỉ xuất hiện ở nơi tinh quang tụ lại, các đàn đom đóm trong vùng đều xoay quanh nó mà bay. "
                .. "Ánh sáng của nó xua tan bóng tối, khiến lũ âm vật không dám lại gần.",
        },
        cosu_gu_anthach = {
            rank = 1,
            skills = "Chỉ trang bị được ở 9 ô thường, không đặt được vào Bản Mệnh Cổ. Ẩn Thân: kỹ năng bật/tắt, tiêu 1 nguyên khí mỗi 2 giây, khi bật không sinh vật nào phát hiện được mình.",
            lore = "Ẩn Thạch Cổ trông chẳng khác một viên đá xám tròn trịa, thân phủ lớp vỏ sần sùi, nằm im cả ngày không nhúc nhích. "
                .. "Nó sống lẫn giữa đá núi và bãi sỏi, hễ có động là co mình lại, hòa vào đá đến mức mắt thú cũng không nhận ra. "
                .. "Loài cổ này rất hiếm, cổ sư thường chỉ may mắn gặp được khi mở những viên đá nguyên thạch chưa ai đục.",
        },
        cosu_gu_uloi = {
            rank = 3,
            skills = "Nội tại: miễn nhiễm sát thương điện, chạy nhanh +20% (Bản Mệnh Cổ +30%). Lôi Hóa: ăn sừng dê / mảnh vỡ Lôi / Lôi linh căn để đòn đánh kèm điện. Giáng Lôi (chỉ ở Bản Mệnh Cổ): một tia sét lớn trong vùng 3x3 ô, 600 sát thương.",
            lore = "U Lôi Huyễn Điệp Cổ là con bướm tím mang theo sấm sét, cánh vẽ hoa văn như tia chớp. "
                .. "Nó sống ở đầm lầy và đồng hoang hay có dông tố, bay lượn trong mưa giông mà không hề bị thương. "
                .. "Cổ sư luyện nó từ sừng dê, sừng cá voi và Lôi Linh Căn; người nuôi được nó có thể mượn sấm trời làm sức mình.",
        },
    },
    NO_ROOT_TEXT = "Chưa có linh căn",
    SCALE = 1,
    BG_ALPHA = 0.88,
}

----------------------------------------------------------------- Cửa sổ thông tin trên đầu quái
-- Rê chuột vào quái: hiện "Cảnh giới", "Chủng loại" và danh sách linh căn (widgets/cosu_mobinfo.lua).
M.MOBINFO = {
    -- chủng loại: boss = yêu thú; quái thù địch với người chơi (hostile/monster, hoặc đang nhắm vào người chơi) = quái thú; còn lại = phàm thú
    KIND_NAMES = { boss = "Yêu thú", quai = "Quái thú", pham = "Phàm thú" },
    KIND_COLOURS = {
        boss = { 1.0, 0.35, 0.30, 1 },
        quai = { 1.0, 0.70, 0.30, 1 },
        pham = { 0.60, 1.0, 0.60, 1 },
    },
    NO_ROOT_TEXT = "Không",
    LABEL_ROOT = "Linh căn: ",
    LABEL_KIND = "Chủng loại: ",
    LABEL_RANK = "Cảnh giới: ",
    NO_RANK_TEXT = "Không",

    OFFSET = 3.2,        -- độ cao cửa sổ so với chân quái (đơn vị thế giới), nhân theo kích thước quái
    EPIC_OFFSET = 7,     -- như trên nhưng cho boss (to hơn)
    FONT_SIZE = 22,
    SCALE = 1,           -- phóng to / thu nhỏ cả cửa sổ
    BG_ALPHA = 0.7,      -- độ đậm nền
    MAX_DIST = 60,       -- server chỉ trả thông tin cho quái trong phạm vi này
    REFRESH = 10,        -- giây: bao lâu thì hỏi lại server thông tin của cùng 1 con quái
}

----------------------------------------------------------------- Số sát thương nổi
-- Số hiện ra khi quái hoặc người chơi nhận sát thương (cosu_damage_fx.lua, chỉ chạy trên máy khách).
-- Mỗi hệ nguyên tố một màu; sát thương thường: trắng khi đánh quái, đỏ khi người chơi nhận.
M.DMGNUM = {
    COLOURS = {
        p     = { 1.00, 1.00, 1.00 },  -- sát thương thường lên quái
        pp    = { 1.00, 0.25, 0.25 },  -- sát thương thường lên người chơi
        hoa   = { 1.00, 0.45, 0.10 },
        moc   = { 0.40, 0.90, 0.30 },
        thuy  = { 0.30, 0.75, 1.00 },
        tho   = { 0.85, 0.65, 0.25 },
        loi   = { 0.70, 0.55, 1.00 },
        am    = { 0.80, 0.20, 0.65 },
        quang = { 1.00, 0.95, 0.35 },
        kim   = { 0.80, 0.90, 0.95 },
    },
    RESIST_TEXT = "0",   -- hiện khi miễn nhiễm hoàn toàn một hệ (màu theo hệ đó)

    SIZE = 20,           -- cỡ chữ
    SIZE_PLAYER = 22,    -- cỡ chữ khi người chơi nhận sát thương
    STACK_X = 1.4,       -- khoảng cách ngang giữa các số cùng lúc (đơn vị thế giới)
    STACK_Y = 1.0,       -- khoảng cách dọc giữa các hàng số cùng lúc
    LIFE = 1.0,          -- số tồn tại bao lâu (giây)
    RISE = 1.8,          -- bay lên bao nhiêu (đơn vị thế giới)
    HEIGHT = 2.4,        -- độ cao xuất phát so với chân (nhân theo kích thước)
    EPIC_HEIGHT = 5,     -- như trên nhưng cho boss
    RADIUS = 40,         -- chỉ gửi cho người chơi trong phạm vi này
    MAX_PER_FLUSH = 12,  -- tối đa số mỗi lần gửi cho 1 người (chống dồn)
    MAX_ACTIVE = 40,     -- tối đa số đang hiện cùng lúc trên màn hình
}

return M