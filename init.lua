-- Minetest Mod: hotbar
--      Version: 0.1.5a
--   Licence(s): see the attached license.txt file
--       Author: aristotle, a builder on Red Cat Creative
--
-- This mod allows the player to set his/her own hotbar slots number
-- by adding a new command.
--
--   hotbar [size]
--
-- By itself, hotbar types the hotbar slots number in the chat;
-- when it is followed by a number in the correct range that is now [0,23],
-- the command accordingly sets the new slots number.
--
-- Features:
-- - It may permanently store the user's preferences by setting & retrieving
--   the "hotbar_slots" & "hotbar_mode" keys in the configuration file.
-- - For those of us who are running MT 0.4.16+, the hotbar size may be
--   different in each world / map.
--
-- Changelog:
--   0.1.5a
--   - Running luacheck underlined that a couple of fixes were needed:
--     1. normalize() scope is now local
--     2. a few lines had their trailing blanks removed.
--   - A couple of "security fixes" have been applied to disallow any
--     floating value inside minetest.conf and the modstorage that might
--     have made the mod fail at load time in legacy and world mode.
--   0.1.5
--   - Went back to just one command: hotbar, now improved to just not take
--     the size, but the mode as well.
--   - Some feedback messages have been fixed.
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

local VERSION = "0.1.5a"
local MODES = {legacy = "legacy", world = "world", session = "session"} -- this redundancy simplifies later checks
local DEFAULT = {mode = MODES.world, slots = {legacy = 16, world = 10, session = 12}}
local MOD_STORAGE = {}
if not core.get_mod_storage then
  -- MT < 0.4.16
  MOD_STORAGE.present = false
  MOD_STORAGE.settings = false
else
  -- MT 0.4.16+
  MOD_STORAGE.present = true
  MOD_STORAGE.settings = core.get_mod_storage()
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
  if not core.is_singleplayer() then
    return MODES.session
  end
  local value = core.settings:get(key)
  if type(value) ~= "string" or #value == 0 then
    return default_value
  end
  value = string.lower(value)
  if not MODES[value] then
    value = default_value
  end
  return value
end

local get_mode = function(storage, key, default_value)
  if not core.is_singleplayer() then
    return MODES.session
  end
  local value = read_mode(key, default_value)
  local wrong = false
  if value == MODES.world then
    if not storage.present then
      value = MODES.legacy
      wrong = true
    end
  end
  if wrong then
     core.settings:set(key, value)
     core.log("error",
              "[MOD] hotbar v" .. VERSION ..
              " automatically changed and saved the mode. " ..
              "The mode has now been set to " ..
              string.upper(value) .. ".")
  end
  return value
end

local get_and_set_initial_slots = function(storage, mode_value, key, default_value)
  local current
  if not core.is_singleplayer() then
    mode_value = MODES.session
    default_value = DEFAULT.slots[mode_value]
  end

  if mode_value == MODES.legacy then
    local result = tonumber(core.settings:get(key))
    current = result or default_value  -- The first time
    if not result then
      -- first time
      core.settings:set(key, current)
    else
      current = math.floor(result)
      if current ~= result then
        -- result is a float
        core.settings:set(key, current)
      end
    end

  elseif mode_value == MODES.world then
    local result = core.deserialize(storage.settings:get_string(key))
    if type(result) == "number" then
      current = math.floor(result)
      if current ~= result then
        -- result is a float
        storage.settings:set_string(key, core.serialize(current))
      end
    else
      current = default_value -- The first time
      storage.settings:set_string(key, core.serialize(current))
    end

  elseif mode_value == MODES.session then
      current = default_value -- Session initial value

  else
    current = default_value -- Unplanned case
    core.log("error",
             "[MOD] hotbar v" .. VERSION ..
             ": the specified mode - " .. string.upper(mode_value) ..
             " - is unmanaged and has been overridden and set to " ..
             string.upper(default_value) .. ".")
  end

  return current
end

local adjust_hotbar = function(name, slots, selected_image, bg_image_getter)
  local player = core.get_player_by_name(name)
  if slots == 0 then
    player:hud_set_hotbar_itemcount(1)
    player:hud_set_hotbar_selected_image(selected_image)
    player:hud_set_hotbar_image(bg_image_getter(1))
    player:hud_set_flags({hotbar = false, wielditem = false})
  else
    player:hud_set_hotbar_itemcount(slots)
    player:hud_set_hotbar_selected_image(selected_image)
    player:hud_set_hotbar_image(bg_image_getter(slots))
    player:hud_set_flags({hotbar = true, wielditem = true})
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
  local mask = {err = "[%s] Wrong slots number specified: the %s accepted value is %i.",
                set = "[%s] Hotbar slots number set to %i."}
  local display_name = name
  if minetest.is_singleplayer() then
    display_name = '_'
  end
  if slots < hb.slots.min then
    core.chat_send_player(name, mask.err:format(display_name, "minimum", hb.slots.min))
	return
  end
  if slots > hb.slots.max then
	core.chat_send_player(name, mask.err:format(display_name, "maximum", hb.slots.max))
	return
  end
  slots = math.floor(slots) -- to avoid fractions
  hb.adjust(name, slots, hb.image.selected, hb.image.bg.get)

  if hb.mode.current == MODES.legacy then
    core.settings:set(hb.slots.key, slots)
  elseif hb.mode.current == MODES.world then
    MOD_STORAGE.settings:set_string(hb.slots.key, core.serialize(slots))
    core.log("warning",
             "[MOD] hotbar v" .. VERSION ..
             " operating in " .. hb.mode.current ..
             " mode: " .. name ..
             " has changed the slots number to " .. slots .. ".")
  elseif hb.mode.current == MODES.session then
    if core.is_singleplayer() then
      -- This is an ephemeral / transient storage that is to survive while in a map
      -- and trying different hotbar modes.
      -- As a commodity, singleplayer can override the default value to get it back
      -- if he/she switched back from another mode during the same session.
      -- This has not to happen on a server to avoid that other players
      -- overrided it or that their default / current value might be overridden by
      -- others.
      DEFAULT.slots[hb.mode.current] = slots
    end
  else
    core.log("error",
             "[MOD] hotbar v" .. VERSION ..
             ": it is still not possible to set the slots number in " ..
             string.upper(hb.mode.current) .. " mode.")
    core.chat_send_player(name, string.upper(hb.mode.current) .. " mode is not managed yet!")
    return
  end
  if hb.mode.current ~= MODES.session then
    hb.slots.current = slots
  end
  core.chat_send_player(name, mask.set:format(display_name, slots))
end

show_info = function(arg)
  local normalize = function(request)
    local rc = {mode = true, slots = true, version = true}
    if type(request) ~= 'table' then
      return rc
    end
    for k, v in pairs(request) do
      if k == 'mode' or k == 'slots' or k == 'version' then
        if type(v) ~= 'boolean' then
          rc[k] = false
        else
          rc[k] = v
        end
      end
    end
    return rc
  end

  local player = core.get_player_by_name(arg.name)
  local out_name = arg.name
  local out_mode = string.upper(arg.mode)
  if core.is_singleplayer() then
    out_name = "_"  -- overridden
  end
  local message = string.format("[%s] ", out_name)
  local slots = player:hud_get_hotbar_itemcount()
  local flag = player:hud_get_flags()
  if not flag.hotbar then
    slots = 0
  end
  local wanted = normalize(arg.wanted)

  if wanted.mode and wanted.slots then
    message = message .. out_mode .. " / " .. slots
    if wanted.version then
      message = message .. " [" .. VERSION .. "]"
    end
  elseif wanted.mode then
    message = message .. out_mode
  elseif wanted.slots then
    message = message .. slots
  end
  core.chat_send_player(arg.name, message)
end

hb.slots.command = function(name, slots)
  if slots == nil then
    show_info({name = name, mode = hb.mode.current, wanted = {version = false, slots = true}})
    return
  end

  local new_slots = tonumber(slots)
  if type(new_slots) == 'number' then
    hb.slots.set(name, new_slots)
  else
    -- new_slots type is nil => is type string?
    hb.mode.command(name, slots)
  end
end

hb.mode.command = function(name, mode)
  local singleplayer = core.is_singleplayer()
  local display_name = name
  if singleplayer then
    display_name = '_'
  end
  local message = string.format("[%s] ", display_name)

  if #mode == 0 then
    -- display current settings
    show_info({name = name, mode = hb.mode.current, wanted = {version = false, slots = true, mode = true}})
    return
  end

  mode = string.lower(mode)

  if MODES[mode] then
    if singleplayer then
      if mode == MODES.legacy or mode == MODES.world or mode == MODES.session then
        message = message .. "Hotbar mode changed to " .. string.upper(mode) .. "."
      else
        -- This is wrong and must be logged for further investigation
        message = message .. "Your request to change the hotbar mode to " ..
                  string.upper(mode) .. " has been declined because it is unmanaged."

        core.log("error", "[MOD] hotbar v" .. VERSION .. ": " .. message)
        core.chat_send_player(name, message)
        return
      end
    else
      -- not singleplayer
      if mode ~= MODES.session then
        message = message .. string.upper(mode) .. " mode cannot be set on a server."
      else
        message = message .. "Requesting to change mode and then trying to set the same one."
      end
      core.chat_send_player(name, message)
      return
    end
  else
    -- this might just be a mispelled mode, nothing to worry about:
    -- no log is required.
    message = message .. "Wrong hotbar mode - " ..
              string.upper(mode) .. " - specified."
    core.chat_send_player(name, message)
    return
  end

  if not singleplayer then
    return
  end

  if mode == MODES.legacy or mode == MODES.world or mode == MODES.session then
    core.settings:set(hb.mode.key, mode)
  end
  hb.mode.current = mode
  hb.slots.current = get_and_set_initial_slots(MOD_STORAGE,
                                               hb.mode.current,
                                               hb.slots.key,
                                               DEFAULT.slots[hb.mode.current])
  hb.slots.set(name, hb.slots.current)
  core.log("warning", "[MOD] hotbar v" .. VERSION .. ": " .. message)
  core.chat_send_player(name, message)
end

hb.on_joinplayer = function(player)
  hb.adjust(player:get_player_name(), hb.slots.current, hb.image.selected, hb.image.bg.get)
end

minetest.register_on_joinplayer(hb.on_joinplayer)

minetest.register_chatcommand("hotbar", {
  params = "[slots|mode]",
  description = "Invoked with no argument, it displays" ..
                " the current mode and slots number." ..
                " To set" ..
                " the slots number any integer in the range" ..
                " [0, 23] is valid. If set to 0, the hotbar" ..
                " gets hidden, any other number will unhide" ..
                " it." ..
                " Supported modes are " ..
                stringified_table_keys(MODES, ", ") .. ".",
  func = hb.slots.command,
  privs = {interact = true},
})

core.log("action",
         "[MOD] hotbar v" .. VERSION .. " operating in " .. hb.mode.current ..
         " mode. Slots number is set to " .. hb.slots.current .. ".")

