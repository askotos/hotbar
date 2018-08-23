-- Minetest Mod: hotbar
--      Version: 0.1.4
--   Licence(s): see the attached license.txt file
--       Author: aristotle, a builder on Red Cat Creative
--
-- This mod allows the player to set his/her own hotbar slots number
-- by adding a new command.
--
--   hotbar [size]
--
-- By itself, hotbar types the hotbar slots number in the chat;
-- when it is followed by a number in the correct range that is now [1,23],
-- the command accordingly sets the new slots number.
--
-- Features:
-- - It may permanently store the user's preferences by setting & retrieving
--   the "hotbar_slots" & "hotbar_mode" keys in the configuration file.
-- - For those of us who are running MT 0.4.16+, the hotbar size may be
--   different in each world / map.
--
-- Changelog:
--   0.1.4
--   - A new command - /hotbar_mode - has been added to take advantage of
--     the 0.4.16+ mod_storage API.
--     In singleplayer, the suggested default mode for the most recent
--     clients (0.4.16+) should now be WORLD, because when this mode is
--     active a different size can be stored in each world.
--     The original global behavior / mode is now called LEGACY, and
--     should be the default and only one for any MT < 0.4.16
--     because of the lack of the mod_storage API (not tested).
--     No further effort will be put to provide an alternative storage
--     system for any MT < 0.4.16.
--     A third mode - SESSION - is the only mode available when the mod
--     is running on a server. The player can change the slots number,
--     but every new session its value is restored to the default.
--     The SESSION mode is available in singleplayer too.
--   - The slots range has been extended to include the 0: because of this
--     it is now possible to hide the hotbar, the wielded item (and,
--     consequently, the hand).
--   - The deprecated minetest.setting_{get,set}() calls have been removed:
--     this avoids some warnings, but might at the same time limit the
--     compatibility with MT versions < 0.4.16 (not tested too).
--   - The code has been refactoried to better support future comprehension
--     and extensibility (eg for a clientmod version): most of it should
--     now be hopefully self explainatory to me! and even to the occasional
--     modder. :D
--   - FIXES
--     - The slots number is now checked not to be a float (ty GreenDimond).
--   0.1.3
--   - New update to assure the full API support because the version 0.1.2
--     update seems to have gone wrong for some reason. (SORRY. Ty _Xenon)
--     The accepted slots number should now be in the range [1,23]!
--   0.1.2
--   - Some of the existing textures have been modified to comply with an even
--     size (as recommended)
--   - The missing textures have been added.
--   - Some of the textures have been renamed to better support sorting.
--   - As a consequence, the size range has been extended from [1,16] to the
--     fully supported one [1,23]
--   0.1.1
--   - The code that did not properly show the error message when the
--     received size was out of bounds has been corrected
--   - The accepted range has been extended from [4,16] to [1,16].
--   - Some code optimization to avoid strings repetitions
--   0.1.0
--   - The hotbar is now correctly shown even when there are no items in it.
--
-- For now this is all folks: happy builds and explorations! :)
-- aristotle

local VERSION = "0.1.4"
local MODES = {legacy = "legacy", world = "world", session = "session"} -- this redundancy simplifies later checks
local DEFAULT = {mode = MODES.world, slots = {legacy = 16, world = 10, session = 12}}
local MOD_STORAGE = {}
if not minetest.get_mod_storage then
  -- MT < 0.4.16
  MOD_STORAGE.present = false
  MOD_STORAGE.settings = false
  -- get_method = minetest.settings:get
  -- set_method = minetest.settings:set -- automatically converted into a string
                                        -- this is how it worked up to v0.1.3 included
else
  -- MT 0.4.16+
  MOD_STORAGE.present = true
  MOD_STORAGE.settings = minetest.get_mod_storage()
  -- get_method = ms:get_int
  -- set_method = ms:set_int
end


local stringified_table_keys = function(what, sep)
  -- what: table
  -- sep: keys separator (a string)
  local rc = ""
  for k, v in pairs(what) do
    rc = rc .. k .. sep
  end
  return string.sub(rc, 1, -#sep - 1)
end

local new_masked_array = function(mask, max)
  local rc = {}
  for i = 1, max do
    table.insert(rc, string.format(mask, i))
  end
  return rc
end

local read_mode = function(key, default_value)
  -- returns one of the modes the array MODES contains
  -- if requested and necessary, stores the default mode
  local result
  local value
  if minetest.is_singleplayer() then
    value = minetest.settings:get(key)
    if type(value) == "string" then
      if #value > 0 then
        value = string.lower(value)
        if not MODES[value] then
          value = default_value
        end
      else
        value = default_value
      end
    else
      value = default_value
    end
  else
    -- not singleplayer
    value = MODES.session
  end
  return value
end

local get_mode = function(storage, key, default_value)
  -- returns a valid mode
  -- if the requested one is wrong, it corrects it
  local bool_to_string = function(value)
    local rc = "false"
    if value then
      rc = "true"
    end
    return rc
  end
  
  local value = read_mode(key, default_value)
  local wrong = false
  if not minetest.is_singleplayer() then
    value = MODES.session
  end
  if value == MODES.world then
    if not storage.present then
      value = MODES.legacy
      wrong = true
    end
  end
  if wrong then
     minetest.settings:set(key, value)
     minetest.log("error",
                  "[MOD] hotbar v" .. VERSION ..
                  " automatically changed and saved the mode. " ..
                  "The mode has now been set to " ..
                  string.upper(value) .. ".")
  end
  return value
end

local get_and_set_initial_slots = function(storage, mode_value, key, default_value)
  local current
  if not minetest.is_singleplayer() then
    mode_value = MODES.session
  end
  
  if mode_value == MODES.legacy then
    local result = tonumber(minetest.settings:get(key))
    current = result or default_value  -- The first time
    if not result then
      minetest.settings:set(key, current)
    else
      result = math.floor(result)
    end

  elseif mode_value == MODES.world then
    local result = minetest.deserialize(storage.settings:get_string(key))
    if type(result) == "number" then
      current = result
    else
      current = default_value -- The first time
      storage.settings:set_string(key, minetest.serialize(current))
    end
    
  elseif mode_value == MODES.session then
      current = default_value -- Session initial value
  
  else
    current = default_value -- Unplanned case
    minetest.log("error",
                 "[MOD] hotbar v" .. VERSION ..
                 ": the specified mode - " .. string.upper(mode_value) ..
                 " - is unmanaged and has been overridden and set to " ..
                 string.upper(default_value) .. ".")
  end
  
  return current
end

local adjust_hotbar = function(name, slots, selected_image, bg_image)
  local player = minetest.get_player_by_name(name)
  if slots == 0 then
    player:hud_set_flags({hotbar = false, wielditem = false})
  else
    player:hud_set_flags({hotbar = true, wielditem = true})
    player:hud_set_hotbar_itemcount(slots)
    player:hud_set_hotbar_selected_image(selected_image)
    player:hud_set_hotbar_image(bg_image)
  end
end

local hb = {}

hb.adjust = adjust_hotbar

hb.mode = { key = "hotbar_mode" }
hb.slots = { key = "hotbar_slots", min = 0, max = 23 }
hb.image = { selected = "hotbar_selected_slot.png", bg = {} }

hb.mode.current = get_mode(MOD_STORAGE, hb.mode.key, DEFAULT.mode) 
hb.slots.current = get_and_set_initial_slots(MOD_STORAGE, hb.mode.current, hb.slots.key, DEFAULT.slots[hb.mode.current])
hb.image.bg.array = new_masked_array("hotbar_slots_bg_%02i.png", hb.slots.max)

hb.image.bg.get = function(slots)
  return hb.image.bg.array[tonumber(slots)]
end

hb.slots.set = function(name, slots)
  local mask = {err = "[_] Wrong slots number specified: the %s accepted value is %i.",
                set = "[_] Hotbar slots number set to %i."}
  if slots < hb.slots.min then
    minetest.chat_send_player(name, mask.err:format("minimum", hb.slots.min))
	  return
  end
  if slots > hb.slots.max then
	  minetest.chat_send_player(name, mask.err:format("maximum", hb.slots.max))
	  return
  end
  slots = math.floor(slots) -- to avoid fractions
  hb.adjust(name, slots, hb.image.selected, hb.image.bg.get(slots))
  
  if hb.mode.current == MODES.legacy then
    minetest.settings:set(hb.slots.key, slots)
  elseif hb.mode.current == MODES.world then
    MOD_STORAGE.settings:set_string(hb.slots.key, minetest.serialize(slots))
    minetest.log("warning",
                 "[MOD] hotbar v" .. VERSION ..
                 " operating in " .. hb.mode.current ..
                 " mode: " .. name ..
                 " has changed the slots number to " .. slots .. ".")
  elseif hb.mode.current == MODES.session then
    if minetest.is_singleplayer() then
      -- This is an ephemral / transient storage that is to survive while in a map
      -- and trying different hotbar modes.
      -- As a commodity, singleplayer can override the default value to get it back
      -- if he/she switched back from another mode during the same session.
      -- This does not have to happen on a server to avoid that other players
      -- overrided it or that their default / current value might be overridden by
      -- others.
      DEFAULT.slots[hb.mode.current] = slots
    end
  else
    minetest.log("error",
                 "[MOD] hotbar v" .. VERSION ..
                 ": it is still not possible to set the slots number in " ..
                 string.upper(hb.mode.current) .. " mode.")
    minetest.chat_send_player(name, string.upper(hb.mode.current) .. " mode is not managed yet!")
    return
  end
  if hb.mode.current ~= MODES.session then
    hb.slots.current = slots
  end
  minetest.chat_send_player(name, mask.set:format(slots))
end

hb.slots.command = function(name, slots)
  local new_slots = tonumber(slots)
  if not new_slots then
    minetest.chat_send_player(name, "[_] Hotbar slots: " .. hb.slots.current)
    return
  end
  hb.slots.set(name, new_slots)
end

hb.mode.command = function(name, mode)
  local message
  
  if not minetest.is_singleplayer() or #mode == 0 then
    -- display current settings
    local player = minetest.get_player_by_name(name)
    minetest.chat_send_player(name, "[_] Hotbar mode: " .. string.upper(hb.mode.current))
    minetest.chat_send_player(name, "[_] Hotbar slots: " .. player:hud_get_hotbar_itemcount())
    minetest.chat_send_player(name, "[_] Hotbar version: " .. VERSION)
    return
  end
  
  mode = string.lower(mode)
  if MODES[mode] then
    if mode == MODES.legacy or mode == MODES.world or mode == MODES.session then
      message = "hotbar mode changed to " .. string.upper(mode)
    else
      -- This is wrong and must be logged for further investigation
      message = "Your request to change the hotbar mode to " ..
                string.upper(mode) .. " has been declined because it is unmanaged."

      minetest.log("error",
                   "[MOD] hotbar v" .. VERSION ..
                 ": " .. message)
      minetest.chat_send_player(name, "[_] " .. message)
      return
    end
  else
    -- this might just be a mispelled mode, nothing to worry about:
    -- no log is required.
    message = "[_] Wrong hotbar mode - " ..
              string.upper(mode) .. " - specified."
    minetest.chat_send_player(name, message)
    return
  end
  if mode == MODES.legacy or mode == MODES.world or mode == MODES.session then
    minetest.settings:set(hb.mode.key, mode)
  end
  hb.mode.current = mode
  hb.slots.current = get_and_set_initial_slots(MOD_STORAGE, hb.mode.current, hb.slots.key, DEFAULT.slots[hb.mode.current])
  hb.slots.set(name, hb.slots.current)
  minetest.log("warning", "[MOD] hotbar v" .. VERSION .. ": [" .. name .. "] " .. message)
  minetest.chat_send_player(name, "[_] " .. message)
end

hb.on_joinplayer = function(player)
  hb.adjust(player:get_player_name(), hb.slots.current, hb.image.selected, hb.image.bg.get(hb.slots.current))
end

minetest.register_on_joinplayer(hb.on_joinplayer)

minetest.register_chatcommand("hotbar", {
	params = "[slots]",
	description = string.format("If slots is not passed then it displays" ..
	                            " the current slots number, else if it is" ..
	                            " set to 0 then the hotbar gets hidden," ..
	                            " while any other value in the range " ..
	                            " [%i,%i] will show and accordingly " ..
	                            " resize the hotbar.",
	                            hb.slots.min + 1,
	                            hb.slots.max),
	func = hb.slots.command,
	privs = {interact = true},
})

minetest.register_chatcommand("hotbar_mode", {
	params = "[mode]",
	description = "If mode is not passed then it shows the current mode, " ..
	              "else it will change the mode to one of the supported " ..
	              "ones: " .. stringified_table_keys(MODES, ", ") .. ".",
	func = hb.mode.command,
	privs = {interact = true},
})

minetest.log("action", "[MOD] hotbar v" .. VERSION .. " operating in " .. hb.mode.current .. " mode. Slots number is set to " .. hb.slots.current .. ".")

