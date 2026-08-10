local width, height = 48, 24 -- 96 x 48 movement cells
local decorative = { 0, 0, 1, 3, 4, 8, 9, 11, 12, 13, 14 }
local trench = { 13, 13, 14, 12, 8, 13, 14 }
local blocks = {}
for by = 0, height - 1 do
  for bx = 0, width - 1 do
    local value
    if bx == 0 or by == 0 or bx == width - 1 or by == height - 1 then
      value = 15
    elseif bx >= 16 and bx <= 31 then
      value = trench[((bx + by * 3) % #trench) + 1]
    else
      value = decorative[((bx * 5 + by * 7 + bx * by) % #decorative) + 1]
    end
    blocks[#blocks + 1] = value
  end
end
return {
  id = "DDD_ROUTE19_REEF_PASSAGE", label = "DramaticDeepDiveRoute19ReefPassage",
  index = 1203, tileset = "DDD_UNDERWATER", width = width, height = height,
  borderBlock = 15, outdoor = false, region = "DRAMATIC_DEEP_DIVE",
  blocks = blocks, warps = {}, objects = {}, signs = {},
}
