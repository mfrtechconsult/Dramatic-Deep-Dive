# Dramatic Deep Dive

Dramatic Deep Dive is an **independent HM08 DIVE and free-depth underwater gameplay mod for Gen1Recomp**.

The `0.5.0-alpha.2` development line replaces the old handful of handcrafted underwater maps with a **generated full-Kanto seabed network**. The rule is now simple:

> **If Gen1Recomp considers a Kanto movement cell to be water, Dramatic Deep Dive gives that cell an underwater counterpart.**

The surface DIVE dark-water mask has therefore been removed. There is no longer a special painted subset of water to look for: **water itself is the DIVE area**.

See `docs/KANTO_SEABED_OVERHAUL.md` for the full architecture and validation contract.
