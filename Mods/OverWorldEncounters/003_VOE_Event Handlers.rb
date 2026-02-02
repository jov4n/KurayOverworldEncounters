def pbGenerateOverworldEncounters(water = false, full_map = false)
  return false if $scene.is_a?(Scene_Intro) || $scene.is_a?(Scene_DebugIntro)
  return false if !$PokemonEncounters
  return false if !$Trainer || $Trainer.able_pokemon_count == 0
  # return false if $PokemonGlobal.surfing

  if VOESettings.current_encounters < VOESettings.get_max
    tile = get_grass_tile(full_map)
    
    # Check if valid tile was found BEFORE accessing its elements
    if tile.nil? || tile.empty?
      echoln "[VOE] No valid spawn tile found (full_map=#{full_map}, current_encounters=#{VOESettings.current_encounters}, max=#{VOESettings.get_max})" if VOESettings::LOG_SPAWNS
      return false
    end
    
    tile_id = $game_map.map_id < 2 ? :Grass : pbGetTileID($game_map.map_id, tile[0], tile[1])
    water = VOESettings::WATER_TILES.include?(tile_id)
    echoln "# --------------------------------------------------------------- #" if VOESettings::LOG_SPAWNS
    echoln "[generateOWEncounter line 15] #{tile_id} (#{tile}) [Water? #{water}]" if VOESettings::LOG_SPAWNS

    if water
      enc_type = $PokemonEncounters.find_valid_encounter_type_for_time(:Water, pbGetTimeNow)
    else
      enc_type = $PokemonEncounters.find_valid_encounter_type_for_time(:Land, pbGetTimeNow)
      if enc_type.nil?
        enc_type = $PokemonEncounters.has_cave_encounters? ? $PokemonEncounters.find_valid_encounter_type_for_time(:Cave, pbGetTimeNow) : $PokemonEncounters.encounter_type
      end
    end

    echoln "[generateOWEncounter line 26] #{enc_type}" if VOESettings::LOG_SPAWNS
    if enc_type.nil?
      echoln "[VOE] No valid encounter type found for map #{$game_map.map_id}" if VOESettings::LOG_SPAWNS
      return false
    end

    # ========================
    # Create Pokemon Routine
    # ========================

    is_fusion = false
    fusion_body_species = nil
    fusion_head_species = nil
    
    # Check if this should be a fusion encounter
    if VOESettings::FUSION_ENCOUNTERS && rand(VOESettings::FUSION_RATE) == 0
      # Get two random Pokemon from the encounter table
      if VOESettings::DIFFERENT_ENCOUNTERS
        pkmn1_data = pbChooseWildPokemonByVersion($game_map.map_id, enc_type, VOESettings::ENCOUNTER_TABLE)
        pkmn2_data = pbChooseWildPokemonByVersion($game_map.map_id, enc_type, VOESettings::ENCOUNTER_TABLE)
      else
        pkmn1_data = $PokemonEncounters.choose_wild_pokemon_for_map($game_map.map_id, enc_type)
        pkmn2_data = $PokemonEncounters.choose_wild_pokemon_for_map($game_map.map_id, enc_type)
      end
      
      if pkmn1_data && pkmn2_data && pkmn1_data[0] != pkmn2_data[0]
        # Body = pkmn1, Head = pkmn2 (head determines behavior/temperament)
        fusion_body_species = pkmn1_data[0]
        fusion_head_species = pkmn2_data[0]
        
        # Get dex numbers for fusion
        body_dex = getDexNumberForSpecies(fusion_body_species)
        head_dex = getDexNumberForSpecies(fusion_head_species)
        
        # Only create fusion if both are base Pokemon (not already fusions)
        if body_dex <= Settings::NB_POKEMON && head_dex <= Settings::NB_POKEMON
          fusion_species = getFusedPokemonIdFromDexNum(body_dex, head_dex)
          avg_level = ((pkmn1_data[1] + pkmn2_data[1]) / 2.0).round
          pkmn = Pokemon.new(fusion_species, avg_level)
          is_fusion = true
          echoln "[generateOWEncounter] FUSION! Body: #{fusion_body_species}, Head: #{fusion_head_species}" if VOESettings::LOG_SPAWNS
        end
      end
    end
    
    # Regular encounter if not a fusion
    unless is_fusion
      if VOESettings::DIFFERENT_ENCOUNTERS
        pkmn_data = pbChooseWildPokemonByVersion($game_map.map_id, enc_type, VOESettings::ENCOUNTER_TABLE)
      else
        pkmn_data = $PokemonEncounters.choose_wild_pokemon_for_map($game_map.map_id, enc_type)
      end
      pkmn = Pokemon.new(pkmn_data[0], pkmn_data[1])
    end

    echoln "[generateOWEncounter] Spawning #{pkmn.species} for #{enc_type}" if VOESettings::LOG_SPAWNS
    echoln "# --------------------------------------------------------------- #" if VOESettings::LOG_SPAWNS

    if [:SCATTERBUG, :SPEWPA, :VIVILLON].include?(pkmn.species)
      debug = true
      region = pbGetCurrentRegion

      v_form = case region
        when 0; 3 # Creatia: Garden Pattern
        else; 0         end
      pkmn.form = v_form
      echoln "Vivillon family changed to form #{v_form}" if debug
    end

    echoln "Spawning #{pkmn.name} (Water? #{water})#{is_fusion ? ' [FUSION]' : ''}" if VOESettings::LOG_SPAWNS

    pkmn.level = (pkmn.level + rand(-2..2)).clamp(2, GameData::GrowthRate.max_level)
    pkmn.calc_stats
    pkmn.reset_moves
    pkmn.shiny = rand(VOESettings::SHINY_RATE) == 0  # rand(4) returns 0-3, so check for 0
    echoln "[VOE] Shiny check: #{pkmn.shiny?} (rate: 1/#{VOESettings::SHINY_RATE})" if VOESettings::LOG_SPAWNS

    echoln "#{pkmn.name} nature: #{pkmn.nature.id} (#{pkmn.nature.id.class.to_s})" if VOESettings::LOG_SPAWNS

    # ========================
    # Create Event Routine
    # ========================
    r_event = Rf.create_event do |e|
      # Event Name
      e.name = water ? "OverworldPkmn_Swim" : "OverworldPkmn"
      e.name = e.name + " Reflection" if VOESettings::REFLECTION_MAP_IDS.include?($game_map.map_id)
      e.name = e.name + " (Shiny)" if pkmn.shiny?
      e.name = e.name + " (Fusion)" if is_fusion

      # Event position
      e.x = tile[0]
      e.y = tile[1]

      # Event Page
      e.pages[0].step_anime = true
      e.pages[0].trigger = 0
      e.pages[0].list.clear
      e.pages[0].move_speed = 2
      e.pages[0].move_frequency = 2

      # For fusions, use HEAD species for behavior (head = temperament)
      behavior_species = pkmn.species
      if is_fusion && defined?(isSpeciesFusion) && isSpeciesFusion(pkmn.species)
        behavior_species = get_head_species_from_symbol(pkmn.species)
      end
      
      move_data = VOEMovement::Poke_Move[behavior_species] || VOEMovement::Poke_Move[behavior_species.to_sym]
      move_data = VOEMovement::Nature_Move[pkmn.nature.id] unless move_data

      if move_data
        echoln "#{pkmn.name} (#{pkmn.nature.id}) move route:\n#{move_data[:move_route]}" #if VOESettings::LOG_SPAWNS

        route = RPG::MoveRoute.new
        route.repeat = true
        route.skippable = true
        route.list = pbConvertMoveCommands(move_data[:move_route])

        e.pages[0].move_speed = move_data[:move_speed] if move_data.has_key?(:move_speed)
        e.pages[0].move_frequency = move_data[:move_frequency] if move_data.has_key?(:move_frequency)
        e.pages[0].move_type = 3
        e.pages[0].move_route = route
        e.pages[0].trigger = 2 if move_data.has_key?(:touch) && move_data[:touch] == true
      end

      # Event Final Compilation
      Compiler.push_script(e.pages[0].list, "pbInteractOverworldEncounter")
      Compiler.push_end(e.pages[0].list)
    end

    event = r_event[:event]

    event.setVariable([pkmn, r_event])
    echoln "Spawned Event Name: #{event.name}" if VOESettings::LOG_SPAWNS

    spriteset = $scene.spriteset
    dist = (((event.x - $game_player.x).abs + (event.y - $game_player.y).abs) / 4).floor
    if pkmn.shiny?
      # Play shiny sound effect
      if dist && dist <= 6 && dist >= 0
        pbSEPlay(VOESettings::SHINY_SOUND, [75, 65, 55, 40, 27, 22, 15][dist], 100) rescue nil
      end
      # Script-based sparkles (no RPG Maker animation needed)
      pbVOESparkle(event) if spriteset
    end
    pbChangeEventSprite(event, pkmn, water)
    event.direction = rand(1..4) * 2
    event.through = false
    # Play cry occasionally
    if dist && dist <= 6 && dist >= 0 && rand(20) == 1
      GameData::Species.play_cry_from_pokemon(pkmn, [75, 65, 55, 40, 27, 22, 15][dist]) rescue nil
    end
    VOESettings.current_encounters += 1
    echoln "[VOE] Successfully spawned encounter. Total: #{VOESettings.current_encounters}" if VOESettings::LOG_SPAWNS
    return true
  else
    echoln "[VOE] Max encounters reached (#{VOESettings.current_encounters}/#{VOESettings.get_max})" if VOESettings::LOG_SPAWNS
    return false
  end
end

# --------------------------------------------------------------------------------
# Event Handlers (Legacy Events.on... Adaptation)
# --------------------------------------------------------------------------------

# 1. On Enter Map (Legacy: onMapChange)
Events.onMapChange += proc { |_sender, e|
  old_map_id = e[0]
  # Always log map changes for debugging
  echoln "[VOE] onMapChange triggered: old_map_id=#{old_map_id}, new_map_id=#{$game_map.map_id}"

  # Blacklist
  if VOESettings::BLACK_LIST_MAPS.include?($game_map.map_id)
    echoln "[VOE] Map #{$game_map.map_id} is blacklisted, skipping spawns"
    next
  end
  if $game_map.map_id < 2
    echoln "[VOE] Map ID #{$game_map.map_id} is < 2, skipping spawns"
    next
  end
  # Try both $MapFactory and $map_factory (different versions use different names)
  map_factory = defined?($MapFactory) ? $MapFactory : (defined?($map_factory) ? $map_factory : nil)
  unless map_factory
    echoln "[VOE] Map factory is nil in onMapChange, will try spawning in onMapSceneChange instead"
    next
  end
  echoln "[VOE] Passed initial checks in onMapChange"

  # Add Old Map to Variable
  # In legacy onMapChange, $game_map is already the NEW map.
  # We need to clean up events on the OLD map? 
  # Wait, the logic gets the OLD map to clear encounters?
  # "map = $map_factory.getMapNoAdd(old_map_id)"
  # Yes, it cleans up previous map's encounters.
  
  if old_map_id && old_map_id > 0
    map_factory = defined?($MapFactory) ? $MapFactory : (defined?($map_factory) ? $map_factory : nil)
    map = map_factory.getMapNoAdd(old_map_id) if map_factory
    if map
      map.events.each_value do |event|
        next unless event.name[/OverworldPkmn/i]
        # We can't easily destroy events on a map that isn't the current one via standard methods
        # if they rely on the scene spriteset, but the data modifications are fine.
        # pbDestroyOverworldEncounter checks $scene.spriteset which might form the NEW map.
        # However, we allow it to try.
        # Ideally we just reset the data.
        VOESettings.current_encounters = 0 if VOESettings.current_encounters > 0
      end
    end
  end
  
  # Reset counter
  VOESettings.current_encounters = 0

  # Don't spawn here - let onMapSceneChange handle it with frame-based spawning
  # This prevents freezing by spreading spawns across multiple frames
}

# 2. On New Spriteset (Legacy: onSpritesetCreate)
Events.onSpritesetCreate += proc { |_sender, e|
  spriteset = e[0]
  viewport = e[1]
  
  # Blacklist
  next if VOESettings::BLACK_LIST_MAPS.include?($game_map.map_id)

  next if $game_map.map_id < 2
  next if !$PokemonEncounters
  
  $game_map.events.each_value do |event|
    next unless event.name[/OverworldPkmn/i]
    next if event.variable.nil?
    pkmn = event.variable[0]
    next if pkmn.nil?
    water = VOESettings::WATER_TILES.include?(pbGetTileID($game_map.map_id, event.x, event.y))
    pbChangeEventSprite(event, pkmn, water)
  end
}

# 2b. On Map Scene Change - Spawn encounters when map scene is ready
Events.onMapSceneChange += proc { |_sender, e|
  scene = e[0]
  mapChanged = e[1]
  
  # Only spawn on initial map load, not on scene regeneration
  next unless mapChanged
  
  echoln "[VOE] onMapSceneChange triggered (mapChanged=#{mapChanged}), checking for initial spawns"
  
  # Blacklist
  next if VOESettings::BLACK_LIST_MAPS.include?($game_map.map_id)
  next if $game_map.map_id < 2
  next if !$PokemonEncounters
  next if !$Trainer || $Trainer.able_pokemon_count == 0
  
  # Check if spawn on load is enabled and we haven't spawned yet
  begin
    spawn_on_load_enabled = VOESettings::SPAWN_ON_LOAD
    echoln "[VOE] SPAWN_ON_LOAD setting: #{spawn_on_load_enabled}, current_encounters: #{VOESettings.current_encounters}"
    
    # Check if map was recently visited (within last 20 seconds)
    recently_visited = VOESettings.map_recently_visited?($game_map.map_id, 20)
    echoln "[VOE] Map #{$game_map.map_id} recently visited: #{recently_visited}"
    
    if spawn_on_load_enabled && VOESettings.current_encounters == 0 && !recently_visited
      initial_count = VOESettings::INITIAL_SPAWN_COUNT
      max_allowed = VOESettings.get_max
      spawn_count = [initial_count, max_allowed].min
      
      echoln "[VOE] Queueing #{spawn_count} initial encounters to spawn over multiple frames (initial_count=#{initial_count}, max_allowed=#{max_allowed})"
      
      # Queue spawns to happen over multiple frames to prevent freezing
      $game_temp.pending_initial_spawns = spawn_count
      
      # Record the visit time
      VOESettings.set_map_visit_time($game_map.map_id, Time.now.to_f)
    elsif recently_visited
      echoln "[VOE] Skipping initial spawns - map was visited recently"
    end
  rescue => err
    echoln "[VOE] Error in spawn on load (onMapSceneChange): #{err.class} - #{err.message}"
    echoln "[VOE] Backtrace: #{err.backtrace.join("\n")}"
  end
}

# 3. On Frame Update (Legacy: onMapUpdate)
Events.onMapUpdate += proc { |_sender, _e|
  # Blacklist
  next if VOESettings::BLACK_LIST_MAPS.include?($game_map.map_id)

  next if $game_map.map_id < 2
  next if VOESettings::DISABLE_SETTINGS || $PokemonSystem.owpkmnenabled == 1
  next if $game_temp.in_menu
  next if !$PokemonEncounters
  
  # Handle pending initial spawns (spawn one every many frames to prevent freezing)
  if $game_temp.pending_initial_spawns && $game_temp.pending_initial_spawns > 0
    # Only spawn every 30 frames to prevent freezing (about 2 per second at 60 FPS)
    # Also skip if player is moving or menu is open to avoid lag
    if $game_player.moving? || $game_temp.in_menu || pbMapInterpreterRunning?
      # Skip this frame if player is busy
      next
    end
    
    $game_temp.spawn_frame_counter ||= 0
    $game_temp.spawn_frame_counter += 1
    
    if $game_temp.spawn_frame_counter >= 30
      $game_temp.spawn_frame_counter = 0
      max_allowed = VOESettings.get_max
      if VOESettings.current_encounters < max_allowed
        # Update graphics before spawning to keep things smooth
        Graphics.update
        Input.update
        result = pbGenerateOverworldEncounters(false, true)  # full_map = true for initial spawns
        $game_temp.pending_initial_spawns -= 1 if result
        echoln "[VOE] Spawned initial encounter (#{$game_temp.pending_initial_spawns} remaining)" if VOESettings::LOG_SPAWNS
        # Update again after spawning
        Graphics.update
        Input.update
      else
        $game_temp.pending_initial_spawns = 0
      end
      
      if $game_temp.pending_initial_spawns == 0
        echoln "[VOE] Finished initial spawns. Total encounters: #{VOESettings.current_encounters}"
        $game_temp.spawn_frame_counter = 0
      end
    end
    
    # Skip normal spawn logic this frame if we're still spawning initial encounters
    next if $game_temp.pending_initial_spawns > 0
  end
  
  $game_temp.frames_updated += 1
  next if $game_temp.frames_updated < 600 # <<< Updated Frame Rate
  $game_temp.frames_updated = 0
  
  $game_map.events.each_value do |event|
    next unless event.name[/OverworldPkmn/i]
    next if event.variable.nil?
    pbPokemonIdle(event)
  end
  pbGenerateOverworldEncounters
}

# 4. On Step Taken (Legacy: onStepTaken)
Events.onStepTaken += proc { |_sender, _e|
  # Blacklist
  next if VOESettings::BLACK_LIST_MAPS.include?($game_map.map_id)

  next if $game_map.map_id < 2
  next if !$scene.is_a?(Scene_Map)
  next if VOESettings::DISABLE_SETTINGS || $PokemonSystem.owpkmnenabled == 1
  next if $game_temp.in_menu
  next if !$PokemonEncounters
  
  $game_map.events.each_value do |event|
    next unless event.name[/OverworldPkmn/i]
    next if event.variable.nil?
    pbDestroyOverworldEncounter(event) if pbTrainersSeePkmn(event)
  end
}
