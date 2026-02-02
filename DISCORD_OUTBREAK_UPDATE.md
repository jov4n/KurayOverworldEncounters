**Outbreak Settings Update!**

Outbreak event system in Kuray's Overworld Encounters! Random outbreaks spawn massive Pokemon swarms with enhanced shiny rates!

**Outbreak Features**

**Outbreak Events** - Enable random outbreak events that spawn swarms of Pokemon! Outbreaks trigger automatically every 20-60 minutes on valid maps.

**Outbreak Duration** - How long outbreaks last: 5, 10, or 15 minutes (default: 10). Timer displayed on-screen during active outbreaks.

**Outbreak Variety** - Choose outbreak type: Mixed Species (variety) or Same Species (all same Pokemon). Same Species locks one Pokemon per terrain type.

**Outbreak Shiny Rate** - Shiny multiplier during outbreaks (1-10x, default: 1x). Increase for better shiny odds during outbreaks!

**No Shiny Despawn (Outbreak)** - Prevents shiny Pokemon from despawning during outbreaks (default: ON). Ensures you don't miss shinies!

**Outbreak Initial Spawns** - Pokemon count when outbreak starts (3-12, default: 6). Burst spawn when outbreak begins.

**Outbreak Max Pokemon** - Maximum encounters during outbreaks (5-20, default: 12). Higher than normal max for bigger swarms!

**Outbreak Spawn Rate** - Frames between spawns during outbreaks (50-500, default: 200). Lower = faster spawning.

**Outbreak Radius** - Spawn radius around player (5-30 tiles, default: 15). Controls how far outbreak Pokemon can spawn.

**Outbreak Shiny Panic** - Rare event (1/8096 chance per second) that turns ALL outbreak Pokemon shiny for 1 minute! Shows "PANIC!" on timer.

**How It Works**

- Outbreaks trigger randomly every 20-60 minutes when enabled
- On-screen UI shows timer, type, and shiny multiplier
- Outbreak Pokemon marked with "(Outbreak)" in their name
- Automatically ends when timer expires or you leave the map
- Can be triggered manually via map events using `VOEOutbreak.start_outbreak(species)`

**Settings Location**

All outbreak settings in Mod Settings under "Encounters" category. Outbreaks enabled by default!
