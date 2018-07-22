-- Minetest Mod: hotbar
--      Version: 0.1.3
--   Licence(s): see the attached license.txt file
--       Author: aristotle, a builder on the Red Cat Creative Server
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
-- - It permanently stores the user's preference by setting and retrieving
--   the "hotbar_slots" key in the configuration file.
--
-- Changelog:
--   0.1.3
--   - New update to assure the full API support because the version 0.1.2
--     update seems to have gone wrong for some reason. (SORRY)
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

local hb = {}
hb.min = 1
hb.max = 23
hb.default = 16
hb.setting ="hotbar_slots"
hb.current = minetest.setting_get(hb.setting) or hb.default  -- The first time
hb.image = {}
hb.image.selected = "hotbar_selected_slot.png"
hb.image.bg = {}
for i = 1, hb.max do
  table.insert(hb.image.bg, string.format("hotbar_slots_bg_%02i.png", i))
end

function hb.resize(size)
  local new_size = tonumber(size)
  return hb.image.bg[new_size]
end

function hb.set(name, slots)
  local mask = {err = "[_] Wrong slots number specified: the %s accepted value is %i.",
                set = "[_] Hotbar slots number set to %i."}
	local player = minetest.get_player_by_name(name)
	if slots < hb.min then
	  minetest.chat_send_player(name, mask.err:format("minimum", hb.min))
		return
	end
	if slots > hb.max then
	  minetest.chat_send_player(name, mask.err:format("maximum", hb.max))
		return
	end
	player:hud_set_hotbar_itemcount(slots)
	player:hud_set_hotbar_selected_image(hb.image.selected)
	player:hud_set_hotbar_image(hb.resize(slots))
	minetest.setting_set(hb.setting, slots) -- automatically converted into a string
	hb.current = slots
	minetest.chat_send_player(name, mask.set:format(slots))
end

function hb.command(name, slots)
	local new_slots = tonumber(slots)
	if not new_slots then
		minetest.chat_send_player(name, "[_] Hotbar slots: " .. hb.current)
		return
	end

	hb.set(name, new_slots)
end

minetest.register_on_joinplayer(function(player)
  player:hud_set_hotbar_itemcount(hb.current)
  minetest.after(0.5,function()
    player:hud_set_hotbar_selected_image(hb.image.selected)
    player:hud_set_hotbar_image(hb.resize(hb.current))
  end)
end)

minetest.register_chatcommand("hotbar", {
	params = "[size]",
	description = string.format("If size is passed then it sets your hotbar slots number in the range [%i,%i], else it displays the current slots number.", hb.min, hb.max),
	func = hb.command,
})


