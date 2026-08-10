local width, height = 40, 60 -- 80 x 120 movement cells
local blocks = {}
for by = 0, height - 1 do
  for bx = 0, width - 1 do
    local center = bx >= 12 and bx <= 27
    local value
    if center and by >= 18 and by <= 43 then
      value = ({ 13, 13, 14, 13, 12, 13, 8, 13 })[((by + bx) % 8) + 1]
    else
      value = ({ 0, 0, 1, 3, 4, 8, 9, 11 })[((bx * 5 + by * 3) % 8) + 1]
    end
    blocks[#blocks + 1] = value
  end
end
return {
  id = "DDD_ROUTE21_ABYSS", label = "DramaticDeepDiveRoute21Abyss",
  index = 1201, tileset = "DDD_UNDERWATER", width = width, height = height,
  borderBlock = 15, outdoor = false, region = "DRAMATIC_DEEP_DIVE",
  blocks = blocks, warps = {}, objects = {}, signs = {},
}
