local S = areas.S

local enable_damage = minetest.settings:get_bool("enable_damage")

local old_is_protected = minetest.is_protected

local disallowed = {
	["^[A-Za-z]+[0-9][0-9][0-9]"] = "You play using an unofficial client. Your actions are limited. "..
			"Download \"MultiCraft ― Build and Mine!\" on Google Play / App Store to play ad-free!"
}

local function old_version(name)
	local info = minetest.get_player_information(name)
	if info and info.version_string and info.version_string < "0.4.16" then
		return true
	end
end

-- Disable some actions for Guests
function minetest.is_protected_action(pos, name)
	for r, reason in pairs(disallowed) do
		if name:lower():find(r) then
			if old_version(name) then
				minetest.chat_send_player(name, reason)
				return true
			end
		end
	end

	if not areas:canInteract(pos, name) then
		return true
	end
	return old_is_protected(pos, name)
end

--==--

function minetest.is_protected(pos, name)
	if not areas:canInteract(pos, name) then
		return true
	end
	return old_is_protected(pos, name)
end

minetest.register_on_protection_violation(function(pos, name)
	if not areas:canInteract(pos, name) then
		local owners = areas:getNodeOwners(pos)
		minetest.chat_send_player(name,
			S("@1 is protected by @2.",
				minetest.pos_to_string(pos),
				table.concat(owners, ", ")))

		-- Little damage player
		local player = minetest.get_player_by_name(name)
		if player and player:is_player() then
			if enable_damage then
				local hp = player:get_hp()
				if hp and hp > 2 then
					player:set_hp(hp - 1)
				end
			end
			local player_pos = player:get_pos()
			if pos.y < player_pos.y then
				player:set_pos({
					x = player_pos.x,
					y = player_pos.y + 1,
					z = player_pos.z
				})
			end
		end
	end
end)

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, _, _, damage)
	if not enable_damage then
		return false
	end

	-- If it's a mob, deal damage as usual
	if not hitter or not hitter:is_player() then
		return false
	end

	-- It is possible to use cheats
	if time_from_last_punch < 0.25 then
		minetest.chat_send_player(hitter:get_player_name(), S("Wow, wow, take it easy!"))
		return true
	end

	-- Check if the victim is in an area with allowed PvP or in an unprotected area
	local inAreas = areas:getAreasAtPos(player:get_pos())
	-- If the table is empty, PvP is not allowed
	if not next(inAreas) then
		return true
	end
	-- Do any of the areas have allowed PvP?
	for id, area in pairs(inAreas) do
		if area.canPvP then
			return false
		end
	end

	-- Otherwise, it doesn't do damage
	minetest.chat_send_player(hitter:get_player_name(), S("PvP is not allowed in this area!"))
	return true
end)
