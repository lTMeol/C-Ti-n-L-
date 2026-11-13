-- Chỉ số chiến đấu mới: Hội tâm, Bạo kích, Hộ tâm, Kháng bạo, Kháng công pháp, Kháng linh căn.
-- Mọi con số nằm ở đây; logic ở cosu_stats.lua, component components/cosu_stats.lua.
-- Đơn vị đều là phần trăm (5 = 5%).
local M = {}

M.RES_CAP = 90 -- mọi loại kháng giảm tối đa 90%

-- netvar = tên netvar trên player (bảng thông tin nhân vật đọc đúng các tên này)
-- base = giá trị gốc của người chơi; max = trần
M.DEF = {
    crit    = { base = 5,   max = 100, netvar = "_cosu_crit" },    -- Hội tâm: tỉ lệ gây sát thương chí mạng
    critdmg = { base = 150, max = 500, netvar = "_cosu_critdmg" }, -- Bạo kích: sát thương khi chí mạng (150 = nhân 1,5)
    guard   = { base = 0,   max = 100, netvar = "_cosu_guard" },   -- Hộ tâm: trừ thẳng vào tỉ lệ chí mạng của kẻ đánh mình
    critres = { base = 0,   max = 90,  netvar = "_cosu_critres" }, -- Kháng bạo: giảm phần sát thương cộng thêm của đòn chí mạng
    artres  = { base = 0,   max = 90,  netvar = "_cosu_artres" },  -- Kháng công pháp: giảm sát thương đòn đánh thường quái gây ra
    rootres = { base = 0,   max = 90,  netvar = "_cosu_rootres" }, -- Kháng linh căn: giảm sát thương nguyên tố (linh căn) của quái
}

-- Quái: chỉ quái có cảnh giới (boss, quái tự nhiên) mới có chí mạng, tăng theo số chuyển
M.MOB = {
    CRIT_PER_RANK = 3,      -- Nhất Chuyển 3%, Nhị 6%, Tam 9% ...
    CRITDMG_BASE = 150,
    CRITDMG_PER_RANK = 10,  -- Nhất 160%, Nhị 170% ...
    GUARD_PER_RANK = 0,     -- Hộ tâm của quái (trừ vào tỉ lệ chí mạng người chơi)
    CRITRES_PER_RANK = 0,   -- Kháng bạo của quái
}

return M