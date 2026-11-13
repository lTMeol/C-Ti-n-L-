-- Đánh dấu một vật phẩm là nguyên thạch và cho biết phẩm của nó.
local Stone = Class(function(self, inst)
    self.inst = inst
    self.grade = "low"
end)

return Stone
