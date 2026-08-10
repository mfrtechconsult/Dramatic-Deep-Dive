-- Wild encounter ecology by actual continuous Deep Dive depth.
-- Ten slots are kept per band so Encounter.roll can reuse Gen1Recomp's
-- vanilla encounter buckets and RNG unchanged.
return {
  DDD_ROUTE19_REEF_PASSAGE = {
    { id = "sunlit_reef", minDepth = 0, maxDepth = 130, rate = 6, slots = {
      { level = 22, species = "HORSEA" }, { level = 22, species = "TENTACOOL" },
      { level = 23, species = "KRABBY" }, { level = 23, species = "STARYU" },
      { level = 24, species = "HORSEA" }, { level = 24, species = "SHELLDER" },
      { level = 25, species = "TENTACOOL" }, { level = 25, species = "KRABBY" },
      { level = 26, species = "STARYU" }, { level = 27, species = "SEADRA" },
    } },
    { id = "reef_channel", minDepth = 130, maxDepth = 999, rate = 5, slots = {
      { level = 24, species = "SHELLDER" }, { level = 25, species = "HORSEA" },
      { level = 25, species = "TENTACOOL" }, { level = 26, species = "SEADRA" },
      { level = 26, species = "STARYU" }, { level = 27, species = "SHELLDER" },
      { level = 27, species = "TENTACRUEL" }, { level = 28, species = "SEADRA" },
      { level = 29, species = "TENTACRUEL" }, { level = 30, species = "GYARADOS" },
    } },
  },
  DDD_ROUTE20_SEAFLOOR = {
    { id = "coral_shelves", minDepth = 0, maxDepth = 160, rate = 6, slots = {
      { level = 25, species = "TENTACOOL" }, { level = 25, species = "HORSEA" },
      { level = 26, species = "KRABBY" }, { level = 26, species = "STARYU" },
      { level = 27, species = "SHELLDER" }, { level = 27, species = "HORSEA" },
      { level = 28, species = "TENTACOOL" }, { level = 28, species = "KINGLER" },
      { level = 29, species = "STARYU" }, { level = 30, species = "SEADRA" },
    } },
    { id = "open_blue", minDepth = 160, maxDepth = 320, rate = 5, slots = {
      { level = 27, species = "SHELLDER" }, { level = 27, species = "SEADRA" },
      { level = 28, species = "TENTACOOL" }, { level = 29, species = "SEAKING" },
      { level = 29, species = "STARYU" }, { level = 30, species = "SEADRA" },
      { level = 30, species = "TENTACRUEL" }, { level = 31, species = "CLOYSTER" },
      { level = 31, species = "TENTACRUEL" }, { level = 32, species = "GYARADOS" },
    } },
    { id = "seafoam_rift", minDepth = 320, maxDepth = 999, rate = 4, slots = {
      { level = 30, species = "SEADRA" }, { level = 30, species = "TENTACRUEL" },
      { level = 31, species = "CLOYSTER" }, { level = 31, species = "DEWGONG" },
      { level = 32, species = "SEAKING" }, { level = 32, species = "TENTACRUEL" },
      { level = 33, species = "CLOYSTER" }, { level = 34, species = "GYARADOS" },
      { level = 35, species = "DEWGONG" }, { level = 36, species = "GYARADOS" },
    } },
  },
  DDD_SEAFOAM_SUNKEN_CAVE = {
    { id = "ice_gallery", minDepth = 0, maxDepth = 200, rate = 5, slots = {
      { level = 28, species = "SEEL" }, { level = 28, species = "SHELLDER" },
      { level = 29, species = "SLOWPOKE" }, { level = 29, species = "SEEL" },
      { level = 30, species = "SHELLDER" }, { level = 30, species = "SLOWPOKE" },
      { level = 31, species = "DEWGONG" }, { level = 31, species = "CLOYSTER" },
      { level = 32, species = "SLOWBRO" }, { level = 33, species = "DEWGONG" },
    } },
    { id = "blue_hole", minDepth = 200, maxDepth = 999, rate = 4, slots = {
      { level = 31, species = "SEEL" }, { level = 31, species = "CLOYSTER" },
      { level = 32, species = "SLOWBRO" }, { level = 32, species = "DEWGONG" },
      { level = 33, species = "CLOYSTER" }, { level = 33, species = "SEADRA" },
      { level = 34, species = "DEWGONG" }, { level = 34, species = "TENTACRUEL" },
      { level = 35, species = "CLOYSTER" }, { level = 36, species = "GYARADOS" },
    } },
  },
  DDD_ROUTE21_ABYSS = {
    { id = "sunlit_water", minDepth = 0, maxDepth = 170, rate = 6, slots = {
      { level = 27, species = "TENTACOOL" }, { level = 27, species = "HORSEA" },
      { level = 28, species = "STARYU" }, { level = 28, species = "KRABBY" },
      { level = 29, species = "SHELLDER" }, { level = 29, species = "HORSEA" },
      { level = 30, species = "STARYU" }, { level = 30, species = "SEADRA" },
      { level = 31, species = "TENTACRUEL" }, { level = 32, species = "GYARADOS" },
    } },
    { id = "twilight_water", minDepth = 170, maxDepth = 380, rate = 5, slots = {
      { level = 29, species = "SEADRA" }, { level = 29, species = "SHELLDER" },
      { level = 30, species = "TENTACRUEL" }, { level = 30, species = "SEAKING" },
      { level = 31, species = "STARMIE" }, { level = 31, species = "SEADRA" },
      { level = 32, species = "CLOYSTER" }, { level = 32, species = "TENTACRUEL" },
      { level = 33, species = "GYARADOS" }, { level = 34, species = "DEWGONG" },
    } },
    { id = "abyssal_water", minDepth = 380, maxDepth = 999, rate = 4, slots = {
      { level = 32, species = "TENTACRUEL" }, { level = 32, species = "SEADRA" },
      { level = 33, species = "CLOYSTER" }, { level = 33, species = "DEWGONG" },
      { level = 34, species = "STARMIE" }, { level = 34, species = "TENTACRUEL" },
      { level = 35, species = "CLOYSTER" }, { level = 35, species = "GYARADOS" },
      { level = 36, species = "DEWGONG" }, { level = 38, species = "GYARADOS" },
    } },
  },
}
