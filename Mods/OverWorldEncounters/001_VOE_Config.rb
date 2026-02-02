# IMPORTANT!!
# If you are using Roaming Pokémon, it is necessary to add
# next if $game_temp.overworld_encounter
# after each mention of: next if $PokemonGlobal.roamedAlready
# otherwise Overworld Encounters can trigger Roaming Battles

class VOESettings
  BLACK_LIST_MAPS = [61, 62, 63, 64, 65, 66]
  BLACK_LIST_WATER = [96]
  REFLECTION_MAP_IDS = [70, 103, 105]

  GRASS_TILES = [
    :Grass, :TallGrass, :DeepSand, :SpringGrass, :SpringTallGrass, :SummerGrass, :SummerTallGrass,
    :AutumnGrass, :AutumnTallGrass, :WinterGrass, :WinterTallGrass, :SpringRockyGrass, :SummerRockyGrass,
    :AutumnRockyGrass, :WinterRockyGrass, :SpringForestGrass, :SummerForestGrass, :AutumnForestGrass,
    :WinterForestGrass,
  ]
  WATER_TILES = [:Water, :StillWater, :Dirty_Water, :SpringWater, :SummerWater, :AutumnWater, :WinterWater]

  FLEE_SOUND = "Door exit"
  SHINY_SOUND = "Mining reveal"
  
  # How many encounters will be spawned on each map (mapId => numberOfEvents) (0 = default)
  MAX_PER_MAP = {
    # 42 => 0,
    # 57 => 3,
    0 => 5,
  }

  # Dynamic Settings via ModSettings
  def self.const_missing(name)
    begin
      if defined?(ModSettingsMenu) && ModSettingsMenu.respond_to?(:get)
        case name
        when :DISABLE_SETTINGS
          val = ModSettingsMenu.get(:voe_disable_settings)
          return (val == 1) if val != nil
        when :LOG_SPAWNS
          val = ModSettingsMenu.get(:voe_log_spawns)
          return (val == 1) if val != nil
        when :SHINY_RATE
          val = ModSettingsMenu.get(:voe_shiny_rate)
          return val if val != nil && val.is_a?(Numeric)
        when :MAX_DISTANCE
          val = ModSettingsMenu.get(:voe_max_distance)
          return val if val != nil && val.is_a?(Numeric)
        when :DELETE_EVENTS
          val = ModSettingsMenu.get(:voe_delete_events)
          return (val == 1) if val != nil
        when :DELETE_SHINY
          val = ModSettingsMenu.get(:voe_delete_shiny)
          return (val == 1) if val != nil
        when :BRIGHT_SHINY
          val = ModSettingsMenu.get(:voe_brt_shiny)
          return (val == 1) if val != nil
        when :COLORFUL_TEXT
          val = ModSettingsMenu.get(:voe_colorful_text)
          return (val == 1) if val != nil
        when :WATER_SPAWNS_ONLY_SURFING
          val = ModSettingsMenu.get(:voe_water_surf_only)
          return (val == 1) if val != nil
        when :DIFFERENT_ENCOUNTERS
          val = ModSettingsMenu.get(:voe_diff_enc)
          return (val == 1) if val != nil
        when :ENCOUNTER_TABLE
          val = ModSettingsMenu.get(:voe_enc_table)
          return val if val != nil && val.is_a?(Numeric)
        when :SPAWN_ANIMATION
          val = ModSettingsMenu.get(:voe_spawn_anim)
          return val if val != nil && val.is_a?(Numeric)
        when :SHINY_ANIMATION
          val = ModSettingsMenu.get(:voe_shiny_anim)
          return val if val != nil && val.is_a?(Numeric)
        when :MAX_ENCOUNTERS
          val = ModSettingsMenu.get(:voe_max_encounters)
          return val if val != nil && val.is_a?(Numeric)
        when :FUSION_ENCOUNTERS
          val = ModSettingsMenu.get(:voe_fusion_encounters)
          return (val == 1) if val != nil
        when :FUSION_RATE
          val = ModSettingsMenu.get(:voe_fusion_rate)
          return val if val != nil && val.is_a?(Numeric)
        when :HORDE_BATTLES
          val = ModSettingsMenu.get(:voe_horde_battles)
          return (val == 1) if val != nil
        when :HORDE_DISTANCE
          val = ModSettingsMenu.get(:voe_horde_distance)
          return val if val != nil && val.is_a?(Numeric)
        when :SPAWN_ON_LOAD
          val = ModSettingsMenu.get(:voe_spawn_on_load)
          return (val == 1) if val != nil
        when :INITIAL_SPAWN_COUNT
          val = ModSettingsMenu.get(:voe_initial_spawn_count)
          return val if val != nil && val.is_a?(Numeric)
        end
      end
    rescue => e
      # If there's an error accessing mod settings, fall through to defaults
      echoln "[VOE] Error accessing setting #{name}: #{e.message}" if defined?(echoln)
    end
    # Fallback/Default values if ModSettings not ready or key not found
    case name
      when :DISABLE_SETTINGS then false
      when :LOG_SPAWNS then false
      when :SHINY_RATE then 8192
      when :MAX_DISTANCE then 8
      when :DELETE_EVENTS then true
      when :DELETE_SHINY then false
      when :BRIGHT_SHINY then true
      when :COLORFUL_TEXT then true
      when :WATER_SPAWNS_ONLY_SURFING then true
      when :DIFFERENT_ENCOUNTERS then false
      when :ENCOUNTER_TABLE then 1
      when :SPAWN_ANIMATION then 2
      when :SHINY_ANIMATION then 2  # Use same as spawn, or set to 0 to disable
      when :MAX_ENCOUNTERS then 5
      when :FUSION_ENCOUNTERS then true
      when :FUSION_RATE then 10
      when :HORDE_BATTLES then true
      when :HORDE_DISTANCE then 2
      when :SPAWN_ON_LOAD then false
      when :INITIAL_SPAWN_COUNT then 6
      else super
    end
  end

  # The amount of encounters currently on the map
  def self.current_encounters
    return 0 unless $game_map

    unless @current_encounters
      count = 0
      $game_map.events.each_value do |event|
        next unless event.name[/OverworldPkmn/i]

        count += 1
      end
      @current_encounters = count
    end
    @current_encounters
  end

  # Setter for the current encounters
  class << self
    attr_writer :current_encounters
  end

  # Star sparkle management
  @sparkles ||= []
  def self.add_sparkle(sparkle); @sparkles << sparkle; end
  def self.update_sparkles
    # echoln "[VOE] Updating #{@sparkles.length} sparkles" if @sparkles.length > 0 && VOESettings::LOG_SPAWNS
    @sparkles.delete_if { |s| s.update }
  end
  def self.clear_sparkles
    @sparkles.each { |s| s.dispose }
    @sparkles.clear
  end

  # Map visit tracking (to prevent respawning if recently visited)
  @map_visit_times ||= {}
  def self.get_map_visit_time(map_id)
    @map_visit_times ||= {}
    return @map_visit_times[map_id] || 0
  end
  
  def self.set_map_visit_time(map_id, time)
    @map_visit_times ||= {}
    @map_visit_times[map_id] = time
  end
  
  def self.map_recently_visited?(map_id, seconds = 20)
    last_visit = get_map_visit_time(map_id)
    return false if last_visit == 0
    time_since_visit = Time.now.to_f - last_visit
    return time_since_visit < seconds
  end

  def self.get_max
    # Use mod settings override if available
    max = MAX_ENCOUNTERS
    return max if max > 0
    
    # Otherwise check per-map settings
    return MAX_PER_MAP[$game_map.map_id] if MAX_PER_MAP[$game_map.map_id]

    MAX_PER_MAP[0]
  end
end

# Removed MenuHandlers.add

class Spriteset_Map
  alias voe_update  update
  alias voe_dispose dispose
  def dispose
    VOESettings.clear_sparkles
    voe_dispose
  end

  def update
    begin
      voe_update
    rescue => e
      # Swallow animation errors
    end
    
    VOESettings.update_sparkles

    @character_sprites.each do |sprite|
      next unless sprite&.character
      
      # Apply dark silhouette to fusion encounters (nearly black)
      if sprite.character.name&.include?("(Fusion)")
        sprite.tone.set(-255, -255, -255, 255) rescue nil  # Nearly black silhouette
        next  # Skip other processing for fusions
      end
      
      # Bright shinies (unaffected by day/night)
      next unless VOESettings::BRIGHT_SHINY
      if sprite.character.name&.include?("(Shiny)")
        sprite.tone.set(0, 0, 0, 0) rescue nil
      end
    end
  end
end

class PokemonSystem
  attr_accessor :owpkmnenabled # Whether Overworld Pokémon appear (0=on, 1=off)

  def owpkmnenabled=(val); @owpkmnenabled = val; end
  def owpkmnenabled; @owpkmnenabled; end
end

class PokemonOption_Scene
  alias owpkmn_pbEndScene pbEndScene unless method_defined?(:owpkmn_pbEndScene)

  def pbEndScene
    owpkmn_pbEndScene
    # Use VOESettings::DISABLE_SETTINGS which maps to ModSettings
    if VOESettings::DISABLE_SETTINGS
      $game_map.events.each_value do |event|
        next unless event.name[/OverworldPkmn/i]

        pbDestroyOverworldEncounter(event, true, false)
      end
    end
  end
end

# --------------------------------------------------------
# Method from Followers EX Plugin
# --------------------------------------------------------
def pbOWSpriteFilename(species, form = 0, gender = 0, shiny = false, shadow = false, swimming = false)
  species_data = GameData::Species.try_get(species)
  return nil unless species_data
  species_name = species_data.species.to_s
  species_id = species_data.id_number  # Numeric ID like 19 for Rattata
  
  # Build possible folders to check (standard Essentials locations)
  folders_to_check = []
  
  if swimming
    folders_to_check << (shiny ? "Swimming Shiny/" : "Swimming/")
    folders_to_check << (shiny ? "Levitates Shiny/" : "Levitates/")
  end
  folders_to_check << (shiny ? "Followers shiny/" : "Followers/")
  folders_to_check << "Followers/"  # Fallback to non-shiny
  
  # Check standard Graphics/Characters/<folder>/ location with species NAME
  folders_to_check.each do |folder|
    if form > 0
      std_path = "Graphics/Characters/#{folder}#{species_name}_#{form}"
      return "Graphics/Characters/#{folder}#{species_name}_#{form}" if pbResolveBitmap(std_path)
    end
    std_path = "Graphics/Characters/#{folder}#{species_name}"
    return "Graphics/Characters/#{folder}#{species_name}" if pbResolveBitmap(std_path)
  end
  
  # Try with numeric ID format (e.g., 019.png, 019s.png for shiny)
  id_str = format("%03d", species_id)
  id_str_shiny = "#{id_str}s"
  
  path = shiny ? "Graphics/Characters/#{id_str_shiny}" : "Graphics/Characters/#{id_str}"
  return path if pbResolveBitmap(path)
  
  # Non-shiny fallback for numeric
  path = "Graphics/Characters/#{id_str}"
  return path if pbResolveBitmap(path)
  
  # Last resort - just return base path (may fail if sprite doesn't exist)
  return "Graphics/Characters/Followers/#{species_name}"
end

def pbChooseWildPokemonByVersion(map_ID, enc_type, version)
  # Get the encounter table
  encounter_data = GameData::Encounter.get(map_ID, version)
  enc_list = encounter_data.types[enc_type]

  # Calculate the total probability value
  chance_total = 0

  return [:DITTO, 69] if enc_list.nil?
  enc_list.each { |a| chance_total += a[0] }

  # Escolhe o Pokémon aleatoriamente a partir da Tabela de Encontro
  rnd = rand(chance_total)
  encounter = nil
  enc_list.each do |enc|
    rnd -= enc[0]
    next if rnd >= 0

    encounter = enc
    break
  end

  # Return [species, level]
  level = rand(encounter[2]..encounter[3])
  [encounter[1], level]
end

def pbGetTileID(map_id, x, y)
  return 0 if (x == 0 || y == 0) || (x.nil? || y.nil?)
  debug = false

  echoln "[getTileID] #{map_id}, #{x}, #{y}" if debug
  return 0 unless $map_factory
  thistile = $map_factory.getRealTilePos(map_id, x, y)
  map = $map_factory.getMap(thistile[0])
  tile_id = map.data[thistile[1], thistile[2], 0]

  echoln "[getTileID] #{tile_id}" if debug
  return 0 if tile_id == nil
  return GameData::TerrainTag.try_get(map.terrain_tags[tile_id]).id
end

def pbConvertMoveCommands(list)
  list.map do |entry|
    if entry.is_a?(Symbol)
      # Ex: :move_down
      code = VOE_MOVE_COMMANDS[entry]
      RPG::MoveCommand.new(code)
    elsif entry.is_a?(Array)
      # Ex: [:wait, 30] ou [:jump, 1, -1]
      cmd, *params = entry
      code = VOE_MOVE_COMMANDS[cmd]
      RPG::MoveCommand.new(code, params)
    elsif entry.is_a?(Hash)
      # Ex: { :switch_on => 5 }
      cmd = entry.keys.first
      args = [entry[cmd]].flatten
      code = VOE_MOVE_COMMANDS[cmd]
      RPG::MoveCommand.new(code, args)
    else
      entry
    end
  end
end

VOE_MOVE_COMMANDS = {
  move_down: 1,
  move_left: 2,
  move_right: 3,
  move_up: 4,

  move_lower_left: 5,
  move_lower_right: 6,
  move_upper_left: 7,
  move_upper_right: 8,

  move_random: 9,
  move_toward_player: 10,
  move_away_from_player: 11,
  move_forward: 12,
  move_backward: 13,

  jump: 14,                  # Ex: [:jump, 2, 1]
  wait: 15,                  # Ex: [:wait, 60]

  turn_down: 16,
  turn_left: 17,
  turn_right: 18,
  turn_up: 19,

  turn_right_90: 20,
  turn_left_90: 21,
  turn_180: 22,
  turn_90_random: 23,

  turn_random: 24,
  turn_toward_player: 25,
  turn_away_from_player: 26,

  switch_on: 27,             # Ex: { switch_on: "A" }
  switch_off: 28,            # Ex: { switch_off: "A" }
  change_speed: 29,          # Ex: [:change_speed, 4]
  change_freq: 30,           # Ex: [:change_freq, 3]

  walk_anime_on: 31,
  walk_anime_off: 32,
  step_anime_on: 33,
  step_anime_off: 34,
  direction_fix_on: 35,
  direction_fix_off: 36,
  through_on: 37,
  through_off: 38,
  always_on_top_on: 39,
  always_on_top_off: 40,

  change_graphic: 41,        # Ex: [:change_graphic, "Trainer", 2, 1]
  change_opacity: 42,        # Ex: [:change_opacity, 128]
  change_blend: 43,          # Ex: [:change_blend, 1]
  play_se: 44,               # Ex: [:play_se, RPG::AudioFile.new("Jump", 80, 100)]

  script: 45,                # Ex: [:script, "echoln('test!')"]
  end: 0,
}
