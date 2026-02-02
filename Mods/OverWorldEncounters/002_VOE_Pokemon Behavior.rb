def pbInteractOverworldEncounter
  return if $PokemonGlobal.bridge > 0
  $game_temp.overworld_encounter = true
  evt = pbMapInterpreter.get_self
  evt.lock
  pkmn = evt.variable[0]
  return pbDestroyOverworldEncounter(evt) if pkmn.nil?
  
  # Check for nearby encounters for horde battle (2v1)
  nearby_encounter = nil
  nearby_event = nil
  
  if VOESettings::HORDE_BATTLES  # 2v1 even with just 1 Pokemon!
    horde_dist = VOESettings::HORDE_DISTANCE
    $game_map.events.each_value do |event|
      next if event.id == evt.id  # Skip self
      next unless event.name[/OverworldPkmn/i]
      next if event.variable.nil?
      next if event.variable[0].nil?
      
      # Check true distance between encounters (Euclidean)
      dx = event.x - evt.x
      dy = event.y - evt.y
      true_distance = Math.sqrt(dx * dx + dy * dy)
      if true_distance <= horde_dist
        nearby_encounter = event.variable[0]
        nearby_event = event
        echoln "[VOE] Horde! Found nearby #{nearby_encounter.name} at distance #{true_distance.round(1)}" if VOESettings::LOG_SPAWNS
        break
      end
    end
  end
  
  GameData::Species.play_cry_from_pokemon(pkmn)
  name = pkmn.name
  name_half = (name.length.to_f / 2).ceil
  textcol = VOESettings::COLORFUL_TEXT ? ((pkmn.genderless?) ? "" : (pkmn.male?) ? "\\b" : "\\r") : ""
  
  if nearby_encounter
    # Double battle! (2v1 horde)
    GameData::Species.play_cry_from_pokemon(nearby_encounter)
    name2 = nearby_encounter.name
    pbMessage(_INTL("{1}{2} and {3} appeared together!", textcol, name, name2))
    setBattleRule("double")
    decision = pbWildBattleCore(pkmn, nearby_encounter)
    # Destroy both encounters
    pbDestroyOverworldEncounter(nearby_event, decision == 4, decision != 4)
  else
    # Single battle
    pbMessage(_INTL("{1}{2}!", textcol, name[0, name_half] + name[name_half] + name[name_half]))
    decision = pbWildBattleCore(pkmn)
  end
  
  $game_temp.overworld_encounter = false
  pbDestroyOverworldEncounter(evt, decision == 4, decision != 4)
end

def pbTrainersSeePkmn(evt)
  result = false
  # If event is running
  return result if $game_system.map_interpreter.running?
  # All event loops
  $game_map.events.each_value do |event|
    next if !event.name[/trainer\((\d+)\)/i] && !event.name[/sight\((\d+)\)/i]
    distance = $~[1].to_i
    next if !pbEventCanReachPlayer?(event, evt, distance)
    next if event.jumping? || event.over_trigger?
    result = true
  end
  return result
end

def get_grass_tile(full_map = false)
  possible_tiles = []
  
  if full_map
    # Search the entire map for initial spawns, but sample randomly to reduce cost
    # Instead of checking every tile, sample a subset
    sample_rate = 4  # Check every 4th tile to reduce computation
    checked = 0
    max_checks = 500  # Limit total checks to prevent freezing
    
    (0...$game_map.width).step(sample_rate) do |x|
      (0...$game_map.height).step(sample_rate) do |y|
        checked += 1
        break if checked >= max_checks  # Safety limit
        
        # Don't check if on top of the player (only skip player position, not nearby)
        next if x == $game_player.x && y == $game_player.y
        # Don't spawn on impassable tiles
        next if !$game_map.passable?(x, y, 0) unless VOESettings::WATER_TILES.include?($game_map.terrain_tag(x, y).id)
        # Don't spawn if on top of an event (quick check)
        next if $game_map.event_at_position(x, y) rescue false

        # Returning by Tile Ids
        terrain_id = $game_map.terrain_tag(x, y).id rescue :None
        next if terrain_id == :Rock

        # Spawn only if on an encounter tile
        next unless
          VOESettings::GRASS_TILES.include?(terrain_id) ||
          VOESettings::WATER_TILES.include?(terrain_id) ||
          $PokemonEncounters.has_cave_encounters?

        # Add to possible tiles
        possible_tiles.push([x, y])
      end
      break if checked >= max_checks
    end
    
    # Filter water tiles if needed (do this once at the end instead of during loop)
    if VOESettings::WATER_SPAWNS_ONLY_SURFING && !$PokemonGlobal.surfing
      possible_tiles.delete_if { |tile| VOESettings::WATER_TILES.include?($game_map.terrain_tag(tile[0], tile[1]).id) }
    end

    if VOESettings::BLACK_LIST_WATER.include?($game_map.map_id)
      possible_tiles.delete_if { |tile| VOESettings::WATER_TILES.include?($game_map.terrain_tag(tile[0], tile[1]).id) }
    end
  else
    # Original behavior: search near player
    possible_distance = (VOESettings::MAX_DISTANCE * 0.75).round
    if defined?(VOEOutbreak) && VOEOutbreak.active?
      possible_distance = VOESettings::OUTBREAK_RADIUS
    end
    (($game_player.x - possible_distance)..($game_player.x + possible_distance)).each do |x|
      # Don't check if out of bounds
      next if x < 0 || x >= $game_map.width
      (($game_player.y - possible_distance)..($game_player.y + possible_distance)).each do |y|
        # Don't check if out of bounds
        next if y < 0 || y >= $game_map.height
        # Don't check if on top of the player
        next if x == $game_player.x && y == $game_player.y
        # Don't spawn on impassable tiles
        next if !$game_map.passable?(x, y, 0) unless VOESettings::WATER_TILES.include?($game_map.terrain_tag(x, y).id)
        # Don't spawn if on top of an event
        on_top = false
        $game_map.events.each_value do |event|
          next unless event.at_coordinate?(x, y)
          on_top = true
          break
        end

        # Returning by Tile Ids
        next if $game_map.terrain_tag(x, y).id == :Rock
        next if on_top

        # Don't spawn if a trainer can see it
        next if pbTrainersSeePkmn(Temp_Event.new(x, y, $game_map.map_id))
        # Spawn only if on an encounter tile

        next unless
          VOESettings::GRASS_TILES.include?($game_map.terrain_tag(x, y).id) ||
          VOESettings::WATER_TILES.include?($game_map.terrain_tag(x, y).id) ||
          $PokemonEncounters.has_cave_encounters?

        # Add to possible tiles
        possible_tiles.push([x, y])

        if VOESettings::WATER_SPAWNS_ONLY_SURFING
          possible_tiles.dup.each do |tile|
            possible_tiles.delete(tile) if VOESettings::WATER_TILES.include?($game_map.terrain_tag(tile[0], tile[1]).id) unless $PokemonGlobal.surfing
          end
        end

        if VOESettings::BLACK_LIST_WATER.include?($game_map.map_id)
          possible_tiles.dup.each do |tile|
            possible_tiles.delete(tile) if VOESettings::WATER_TILES.include?($game_map.terrain_tag(tile[0], tile[1]).id)
          end
        end
      end
    end
  end
  
  return (possible_tiles.empty? ? [] : possible_tiles.sample)
end

def pbDestroyOverworldEncounter(event, animation = true, play_sound = false, force = false)
  return if $scene.is_a?(Scene_Intro) || $scene.is_a?(Scene_DebugIntro)
  return if event.nil?
  return if event.variable.nil?
  unless force || $game_variables[1] == 1 || $game_variables[1] == 4
    # Block shiny despawn if setting is enabled OR during outbreak with no-despawn
    if event.variable[0].shiny?
      return if VOESettings::DELETE_SHINY == false
      return if defined?(VOEOutbreak) && VOEOutbreak.block_shiny_despawn?
    end
  end
  echoln "Despawning #{event.variable[0].name}" if VOESettings::LOG_SPAWNS
  if play_sound
    dist = (((event.x - $game_player.x).abs + (event.y - $game_player.y).abs) / 4).floor
    pbSEPlay(VOESettings::FLEE_SOUND, [75, 65, 55, 40, 27, 22, 15][dist], 150) if dist <= 6 && dist >= 0 unless dist.nil?
  end
  spriteset = $scene.spriteset
  spriteset&.addUserAnimation(VOESettings::SPAWN_ANIMATION, event.x, event.y, true, 1) if animation
  
  # ALWAYS fully delete the event to prevent invisible walls
  begin
    # First clear the sprite
    spriteset&.delete_character(event)
    
    # Remove from map events
    $game_map.events.delete(event.id) if $game_map&.events
    
    # Also try the Rf method if available
    if event.variable && event.variable[1]
      Rf.delete_event(event.variable[1]) rescue nil
    end
  rescue => e
    echoln "[VOE] Error deleting event: #{e.message}" if VOESettings::LOG_SPAWNS
  end
  
  # Clear event data to prevent re-interaction
  event.setVariable(nil) rescue nil
  event.through = true rescue nil
  event.character_name = "" rescue nil
  
  VOESettings.current_encounters -= 1
  $game_variables[1] = 0
end

def pbDistanceToPlayer(evt)
  return if !evt
  dx = evt.x - $game_player.x
  dy = evt.y - $game_player.y
  return Math.sqrt(dx * dx + dy * dy).round
end

def pbPokemonIdle(evt)
  return if rand(3) == 1
  return if !evt
  return if evt.lock?
  return pbDestroyOverworldEncounter(evt) if evt.variable.nil?
  
  # Only do random/terrain despawns very rarely
  if rand(1000) == 1  # Very rare random despawn
    unless evt.variable[0].shiny?
      pbDestroyOverworldEncounter(evt)
      return
    end
  end
  
  evt.move_random
  
  # Only despawn by distance if DELETE_EVENTS is enabled
  if VOESettings::DELETE_EVENTS
    dist = pbDistanceToPlayer(evt)
    if dist > VOESettings::MAX_DISTANCE && !evt.variable[0].shiny?
      pbDestroyOverworldEncounter(evt)
      return
    end
  end
  
  # Play cry occasionally
  dist = (((evt.x - $game_player.x).abs + (evt.y - $game_player.y).abs) / 4).floor
  GameData::Species.play_cry_from_pokemon(evt.variable[0], [75, 65, 55, 40, 27, 22, 15][dist]) if dist <= 6 && dist >= 0 && rand(20) == 1 unless dist.nil?
end

def pbChangeEventSprite(event, pkmn, water = false)
  shiny = pkmn.shiny?
  shiny = pkmn.superVariant if (pkmn.respond_to?(:superVariant) && !pkmn.superVariant.nil? && pkmn.super_shiny?)

  fname = nil
  
  # Check if this is a fusion (marked in event name)
  is_fusion = event.name.include?("(Fusion)")
  
  begin
    if is_fusion && defined?(isSpeciesFusion) && isSpeciesFusion(pkmn.species)
      # For fusions, show BODY species sprite as silhouette
      body_species = get_body_species_from_symbol(pkmn.species)
      fname = pbOWSpriteFilename(body_species, 0, 0, false, false, water)
      
      # If body sprite not found, try to use a generic Pokemon sprite
      if nil_or_empty?(fname) || !pbResolveBitmap(fname)
        echoln "[VOE] Warning: No sprite found for fusion body #{body_species}, trying head" if VOESettings::LOG_SPAWNS
        head_species = get_head_species_from_symbol(pkmn.species)
        fname = pbOWSpriteFilename(head_species, 0, 0, false, false, water)
      end
    else
      fname = pbOWSpriteFilename(pkmn.species, pkmn.form, pkmn.gender, shiny, pkmn.shadow, water)
      fname = pbOWSpriteFilename(pkmn.species, 0, pkmn.gender, shiny, pkmn.shadow, water) if pkmn.species == :MINIOR
    end
  rescue => e
    echoln "[VOE] Error getting sprite for #{pkmn.species}: #{e.message}" if VOESettings::LOG_SPAWNS
    fname = nil
  end

  # If no sprite found, use a fallback (return early to prevent visibility issues)
  if nil_or_empty?(fname) || !pbResolveBitmap(fname)
    echoln "[VOE] Warning: No sprite found for #{pkmn.species}, trying fallback" if VOESettings::LOG_SPAWNS
    # Try to use a common sprite as fallback
    fname = pbOWSpriteFilename(:PIDGEY, 0, 0, false, false, false)
    if nil_or_empty?(fname) || !pbResolveBitmap(fname)
      # Last resort - use a simple known sprite path
      fname = "Graphics/Characters/Followers/PIDGEY"
      if !pbResolveBitmap(fname)
        echoln "[VOE] Error: Cannot find any fallback sprite!" if VOESettings::LOG_SPAWNS
        return  # Give up, can't display sprite
      end
    end
  end
  
  fname.gsub!("Graphics/Characters/", "")
  
  # Ensure the character name is not empty
  if nil_or_empty?(fname)
    fname = "Followers/PIDGEY"  # Hard fallback
  end
  
  event.character_name = fname
  
  if event.move_route_forcing
    hue = pkmn.respond_to?(:superHue) && pkmn.super_shiny? ? pkmn.superHue : 0
    event.character_hue = hue
  end
  
  # Apply dark silhouette effect for fusions (but not on shiny reveal)
  if is_fusion && !shiny
    event.character_hue = 0  # Reset hue
    # Mark for dark tone application (handled in Spriteset_Map update)
  end
end

class Game_Temp
  attr_accessor :overworld_encounter
  attr_accessor :frames_updated
  attr_accessor :pending_initial_spawns
  attr_accessor :spawn_frame_counter

  def overworld_encounter
    @overworld_encounter = false if !@overworld_encounter
    return @overworld_encounter
  end

  def overworld_encounter=(val)
    @overworld_encounter = val
  end

  def frames_updated
    @frames_updated = 0 if !@frames_updated
    return @frames_updated
  end

  def frames_updated=(val)
    @frames_updated = val
  end

  def pending_initial_spawns
    @pending_initial_spawns = 0 if !@pending_initial_spawns
    return @pending_initial_spawns
  end

  def pending_initial_spawns=(val)
    @pending_initial_spawns = val
  end

  def spawn_frame_counter
    @spawn_frame_counter = 0 if !@spawn_frame_counter
    return @spawn_frame_counter
  end

  def spawn_frame_counter=(val)
    @spawn_frame_counter = val
  end
end

# Added map_id attr to be compatible with pbEventCanReachPlayer at v21.1 Bug Fixes
class Temp_Event
  attr_reader :x, :y, :map_id

  def initialize(x, y, map_id)
    @x = x
    @y = y
    @map_id = map_id
  end
end
