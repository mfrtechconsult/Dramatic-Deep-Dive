local width, height = 80, 32 -- 160 x 64 movement cells
local decorative = { 0, 0, 0, 1, 3, 4, 8, 9, 11, 12, 13, 14 }
local blocks = {}
for by = 0, height - 1 do
  for bx = 0, width - 1 do
    local value = decorative[((bx * 7 + by * 11 + bx * by) % #decorative) + 1]
    -- Broad open basins separated by a darker Seafoam rift.
    if by >= 4 and by <= 27 and ((bx >= 2 and bx <= 27)
        or (bx >= 34 and bx <= 47) or (bx >= 53 and bx <= 77)) then
      value = ({ 0, 0, 1, 3, 4, 8, 11 })[((bx + by * 3) % 7) + 1]
    end
    blocks[#blocks + 1] = value
  end
end
local caveBlockX, caveBlockY = 40, 16
blocks[caveBlockY * width + caveBlockX + 1] = 7
return {
  id = "DDD_ROUTE20_SEAFLOOR", label = "DramaticDeepDiveRoute20Seafloor",
  index = 1200, tileset = "DDD_UNDERWATER", width = width, height = height,
  borderBlock = 15, outdoor = false, region = "DRAMATIC_DEEP_DIVE", blocks = blocks,
  warps = { { x = caveBlockX * 2, y = caveBlockY * 2,
    destMap = "DDD_SEAFOAM_SUNKEN_CAVE", destWarp = 1 } },
  objects = {}, signs = {},
}
