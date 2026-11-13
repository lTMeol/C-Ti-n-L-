-- Số liệu Nguyên Khí. Chỉnh ở đây, không cần động vào code khác.
local QI = {
    MAX = 100,            -- nguyên khí tối đa
    REGEN_DAYS = 1,       -- hồi đầy trong bấy nhiêu ngày (1 ngày = TUNING.TOTAL_DAY_TIME giây)
    TICK = 1,             -- cứ bao nhiêu giây thì cộng nguyên khí một lần

    DEFAULT_COST = 20,    -- kỹ năng nào không có trong bảng COST thì tốn chừng này

    -- Tiêu hao mỗi lần dùng, tra theo tên kỹ năng (skill_main / skill_slot trong cosu_gu_tuning).
    -- Muốn riêng cho một con cổ thì thêm qi_cost vào mục của nó trong GU.LIST (ưu tiên hơn bảng này).
    COST = {
        star     = 30, -- Ngôi Sao
        quanghoa = 30, -- Quang Hóa
    },

    FAIL_TALK = "Nguyên khí không đủ!",
}
return QI
