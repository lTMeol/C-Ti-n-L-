-- Thành phần đánh dấu NPC khai mở. Logic nằm ở modmain (hành động) và cosu_cultivation (TryAwaken).
local Awakener = Class(function(self, inst)
    self.inst = inst
end)

return Awakener