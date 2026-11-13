-- Số liệu của Lò Luyện Đan (chỉnh ở đây, không cần sửa prefab / modmain)
local COSU = require("cosu_tuning")
local PILL = require("cosu_pill_tuning")

local FURN = {}

FURN.PREFAB = "cosu_lo_luyen_dan"
FURN.PLACER = "cosu_lo_luyen_dan_placer"
FURN.BANK = "cs_lo_luyen_dan"
FURN.BUILD = "cs_lo_luyen_dan"
FURN.ANIM = "idle"

-- Kích thước hiển thị trong game. Khung anim rất lớn (669x1262) nên cần thu nhỏ.
-- Thấy lò to/nhỏ quá thì chỉnh số này.
FURN.ANIM_SCALE = 1.0
FURN.PHYSICS_RADIUS = 1.2

-- Lửa (layer snow, snow_2, snow_3, snow_4) chỉ cháy khi đang luyện
FURN.FLAME_ONLY_WHEN_BREWING = true
FURN.FLAME_LAYERS = { "snow", "snow_2", "snow_3", "snow_4" }

FURN.BREW_TIME = 60 -- giây

-- Đan được luyện ra: số n của PILL.PrefabName(n).
-- Đan n dùng ở Đỉnh Phong chuyển n để lên chuyển n+1  =>  "đan lên chuyển 2" = 1.
-- Nếu đan đó thực ra là số 2 trong mod của bạn thì đổi thành 2.
FURN.OUTPUT_PILL = 1
FURN.OUTPUT_COUNT = 1

-- Nguyên liệu luyện đan (tổng số lượng trong 4 ô)
FURN.INGREDIENTS = {
    { prefab = "houndstooth", count = 10 },     -- răng chó
    { prefab = "pigskin", count = 10 },         -- da lợn
    { prefab = "silk", count = 10 },            -- tơ nhện
    { prefab = COSU.PREFAB.low, count = 40 },   -- nguyên thạch hạ phẩm
}

-- Chi phí chế tạo cái lò
FURN.BUILD_COST = {
    { prefab = COSU.PREFAB.mid, count = 10 },   -- nguyên thạch trung phẩm
    { prefab = "goldnugget", count = 20 },      -- vàng
    { prefab = "cutstone", count = 10 },        -- đá cắt
    { prefab = "boards", count = 10 },          -- ván gỗ
}

FURN.ACCEPT = {}
for _, v in ipairs(FURN.INGREDIENTS) do
    FURN.ACCEPT[v.prefab] = true
end

function FURN.OutputPrefab()
    return PILL.PrefabName(FURN.OUTPUT_PILL)
end

-- Chạy được ở cả server lẫn máy khách (dùng replica)
function FURN.CountItems(container)
    local counts = {}
    if container == nil then return counts end
    for i = 1, container:GetNumSlots() do
        local item = container:GetItemInSlot(i)
        if item ~= nil then
            local n = item.replica.stackable ~= nil and item.replica.stackable:StackSize() or 1
            counts[item.prefab] = (counts[item.prefab] or 0) + n
        end
    end
    return counts
end

function FURN.HasAll(container)
    if container == nil then return false end
    local counts = FURN.CountItems(container)
    for _, v in ipairs(FURN.INGREDIENTS) do
        if (counts[v.prefab] or 0) < v.count then return false end
    end
    return true
end

return FURN