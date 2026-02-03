**VOE Bug Fixes & Improvements Update!**

Major stability and quality-of-life improvements to Kuray's Overworld Encounters!

**Race Condition Fixes**
- Fixed hash modification errors during event iteration (now uses safe copies)
- Fixed encounter counter going negative (now floors at 0)
- Added nil event safety checks to prevent crashes
- Fixed horde despawn issues (both events now properly destroyed)

**Outbreak Blacklist Behavior**
- Outbreaks blocked from starting on blacklisted maps
- Outbreaks end immediately when entering blacklisted maps (cleanup included)
- 15% map entry trigger respects blacklist + 5 second delay

**Outbreak Cooldown System**
- 20-60 minute cooldown after outbreaks end
- Both update loop timer AND 15% map entry trigger respect cooldown
- Debug-triggered outbreaks bypass cooldown (for testing)

**Terrain Mismatch Fix**
- `get_random_species_from_any_map()` now defaults to Land types only
- Pure Water types (Magikarp, Goldeen, etc.) rejected for land spawns
- Dual-types like Water/Flying still allowed on land

**Tile Finding Improvements**
- Changed from grid sampling to random sampling (better coverage)
- Increased attempts from 500 to 800
- Added fallback to passable tiles for caves/dungeons without terrain tags

**Version Manager Simplification**
- Removed in-game networking code (fixed Ruby environment issues)
- Simplified to display version info only

**Files Modified:**
- `001_VOE_Config.rb` - Outbreak logic, cooldown, blacklist, terrain validation
- `002_VOE_Pokemon Behavior.rb` - Tile finding, counter safety
- `003_VOE_Event Handlers.rb` - Safe iteration, outbreak triggers with delay
- `005_VOE_VersionManager.rb` - Simplified version display
