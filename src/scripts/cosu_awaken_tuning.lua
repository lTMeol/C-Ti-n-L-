-- Vật phẩm cần để khai mở Nguyên Hải Thần Thức (grade lấy từ cosu_tuning: low=hạ, mid=trung, high=thượng)
return {
    REQUIRE = {
        { grade = "high", count = 1 },   -- Thượng phẩm x1
        { grade = "mid",  count = 5 },   -- Trung phẩm x5
        { grade = "low",  count = 10 },  -- Hạ phẩm x10
    },
    NEAR_DIST = 8,   -- phải đứng trong khoảng này so với NPC
}