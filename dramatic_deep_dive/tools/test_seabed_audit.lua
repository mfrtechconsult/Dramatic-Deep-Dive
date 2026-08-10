-- Headless contract test for exact generated water coverage.
local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local Audit = dofile(root .. "/src/SeabedAudit.lua")

local water = {
  ["0:0"] = true, ["1:0"] = true, ["2:0"] = true,
  ["0:1"] = true, ["1:1"] = true, ["2:1"] = true,
}
local floorDepth = {}
for key in pairs(water) do floorDepth[key] = 120 end

local entry = {
  id = "ROUTE_TEST",
  underwaterMapId = "DDD_SEABED_ROUTE_TEST",
  water = water,
  waterCount = 6,
  floorDepth = floorDepth,
  def = { width = 2, height = 1 },
  seams = {},
}
local atlas = {
  stats = { waterCells = 6 },
  mapIds = function() return { "ROUTE_TEST" } end,
  surface = function(_, id) if id == "ROUTE_TEST" then return entry end end,
}

local generated = {
  maps = {
    {
      id = "DDD_SEABED_ROUTE_TEST",
      width = 2, height = 1,
      blocks = { 31, 19 },
      connections = {},
    },
  },
  dives = {
    ["atlas:ROUTE_TEST"] = {
      links = {
        {
          id = "row0",
          surface = { mapId = "ROUTE_TEST", x = 0, y = 0 },
          underwater = { mapId = "DDD_SEABED_ROUTE_TEST", x = 0, y = 0 },
          width = 3, height = 1,
        },
        {
          id = "row1",
          surface = { mapId = "ROUTE_TEST", x = 0, y = 1 },
          underwater = { mapId = "DDD_SEABED_ROUTE_TEST", x = 0, y = 1 },
          width = 3, height = 1,
        },
      },
    },
  },
  volumes = {
    ["atlas:ROUTE_TEST"] = {
      cellRuns = {
        [0] = { { x0 = 0, x1 = 2 } },
        [1] = { { x0 = 0, x1 = 2 } },
      },
    },
  },
}

local report = Audit.validate(atlas, generated)
assert(report.ok, table.concat(report.errors, "\n"))
assert(report.waterCells == 6 and report.diveCells == 6 and report.volumeCells == 6,
  "exact water/DIVE/volume totals should match")

-- Prove that the audit catches an uncovered water cell.
local removed = table.remove(generated.dives["atlas:ROUTE_TEST"].links)
local broken = Audit.validate(atlas, generated)
assert(not broken.ok, "missing DIVE coverage must fail the audit")
assert(#broken.errors >= 1, "broken coverage should report a concrete error")
table.insert(generated.dives["atlas:ROUTE_TEST"].links, removed)

-- Prove that non-identity mapping is rejected.
generated.dives["atlas:ROUTE_TEST"].links[1].underwater.x = 1
local shifted = Audit.validate(atlas, generated)
assert(not shifted.ok, "shifted generated DIVE mapping must fail the audit")

generated.dives["atlas:ROUTE_TEST"].links[1].underwater.x = 0
print("Seabed coverage audit OK: exact coverage and failure detection verified")
