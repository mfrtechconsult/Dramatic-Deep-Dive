local width, height = 32, 24 -- 64 x 48 movement cells
local water = { 0, 1, 3, 4, 8, 9, 11, 12, 13, 14 }
local blocks = {}
for by = 0, height - 1 do
  for bx = 0, width - 1 do
    local value = water[((bx * 3 + by * 5 + bx * by) % #water) + 1]
    if by > 2 and by < height - 3 and bx > 2 and bx < width - 3
        and ((bx + by * 2) % 17 == 0) then
      value = 10
    end
    blocks[#blocks + 1] = value
  end
end
local exitBlockX, exitBlockY = 4, 4
blocks[exitBlockY * width + exitBlockX + 1] = 7
return {
  id = "DDD_SEAFOAM_SUNKEN_CAVE", label = "DramaticDeepDiveSeafoamSunkenCave",
  index = 1202, tileset = "DDD_UNDERWATER", width = width, height = height,
  borderBlock = 2, outdoor = false, region = "DRAMATIC_DEEP_DIVE", blocks = blocks,
  warps = { { x = exitBlockX * 2, y = exitBlockY * 2,
    destMap = "DDD_ROUTE20_SEAFLOOR", destWarp = 1 } },
  objects = {}, signs = {},
}
