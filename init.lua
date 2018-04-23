-- Minetest Mod: hotbar
--      Version: 0.1.0
--   Licence(s): see the attached license.txt file
--       Author: aristotle, a builder on the Red Cat Creative Server
--
-- This mod allows the player to set his/her own hotbar slots number
-- by adding a new command.
--
--   hotbar [size]
--
-- By itself, hotbar types the hotbar slots number in the chat;
-- when it is followed by a number in the correct range that is [4,16],
-- the command accordingly sets the new slots number.
--
-- Features:
-- - It permanently stores the user's preference by setting and retrieving
--   the "hotbar_slots" key in the configuration file.
--
-- Changelog:
-- - The hotbar is now correctly shown even when there are no items in it.
--
-- FYI
-- The potential range of the hotbar slots number is [1,16]: the next update
-- will cover it too. :D
--
-- For now this is all folks: happy builds and explorations! :)
-- aristotle

local hb = {}
hb.min = 4
hb.max = 16
hb.default = 16
hb.setting ="hotbar_slots"
hb.current = minetest.setting_get(hb.setting) or hb.default  -- The first time
hb.image = {}
hb.image.selected = "hotbar_slot_selected.png"
hb.image.bg = {nil, nil, nil,
               "hotbar_slots_bg_4.png", 
               "hotbar_slots_bg_5.png", 
               "hotbar_slots_bg_6.png", 
               "hotbar_slots_bg_7.png",
               "hotbar_slots_bg_8.png",
               "hotbar_slots_bg_9.png",
               "hotbar_slots_bg_10.png",
               "hotbar_slots_bg_11.png",
               "hotbar_slots_bg_12.png",
               "hotbar_slots_bg_13.png",
               "hotbar_slots_bg_14.png",
               "hotbar_slots_bg_15.png",
               "hotbar_slots_bg_16.png"}

function hb.show_min()
    minetest.chat_send_player(name, "[_] The minimum slots number is " .. hb.min .. ".")
end

function hb.show_max()
    minetest.chat_send_player(name, "[_] The maximum slots number is " .. hb.max .. ".")
end

function hb.resize(size)
	local new_size = tonumber(size)
	return hb.image.bg[new_size]
end

function hb.set(name, slots)
	local player = minetest.get_player_by_name(name)
	if slots < hb.min then
	  hb.show_min()
		return
	end
	if slots > hb.max then
	  hb.show_max()
		return
	end
	player:hud_set_hotbar_itemcount(slots)
	player:hud_set_hotbar_selected_image(hb.image.selected)
	player:hud_set_hotbar_image(hb.resize(slots))
	minetest.setting_set(hb.setting, slots) -- automatically converted into a string
	hb.current = slots
	minetest.chat_send_player(name, "[_] Hotbar slots number set to " .. slots .. ".")
end

function hb.show(name, slots)
	minetest.chat_send_player(name, "[_] Hotbar slots: " .. slots)
end

function hb.command(name, slots)
	local new_slots = tonumber(slots)
	if not new_slots then
		hb.show(name, hb.current)
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
	description = "If size is passed then it sets your hotbar slots number in the range [4,16], else it displays the current slots number.",
	func = hb.command,
})


