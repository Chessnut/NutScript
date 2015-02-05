--[[
    NutScript is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    NutScript is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with NutScript.  If not, see <http://www.gnu.org/licenses/>.
--]]

nut.flag = nut.flag or {}
nut.flag.list = nut.flag.list or {}

-- Adds a flag that does something when set.
function nut.flag.add(flag, desc, callback)
	-- Add the flag to a list, storing the description and callback (if there is one).
	nut.flag.list[flag] = {desc = desc, callback = callback}
end

if (SERVER) then
	-- Called to apply flags when a player has spawned.
	function nut.flag.onSpawn(client)
		-- Check if they have a valid character.
		if (client:getChar()) then
			-- Get all of the character's flags.
			local flags = client:getChar():getFlags()

			for i = 1, #flags do
				-- Get each individual flag.
				local flag = flags:sub(i, i)
				local info = nut.flag.list[flag]

				-- Check if the flag has a callback.
				if (info and info.callback) then
					-- Run the callback, passing the player and true so they get whatever benefits.
					info.callback(client, true)
				end
			end
		end
	end
end

do
	-- Extend the character metatable to allow flag giving/taking.
	local character = FindMetaTable("Character")

	-- Flags can only be set server-side.
	if (SERVER) then
		-- Set the flag data to the flag string.
		function character:setFlags(flags)
			self:setData("f", flags)
		end

		-- Add a flag to the flag string.
		function character:giveFlags(flags)
			-- Get the individual flags within the flag string.
			for i = 1, #flags do
				local flag = flags:sub(i, i)
				local info = nut.flag.list[flag]

				-- Call the callback if the flag has been registered.
				if (info and info.callback) then
					-- Pass the player and true (true for the flag being given.)
					info.callback(self:getPlayer(), true)
				end
			end

			self:setFlags(self:getFlags()..flags)
		end

		-- Remove the flags from the flag string.
		function character:takeFlags(flags)
			local oldFlags = self:getFlags()
			local newFlags = oldFlags

			-- Get the individual flags within the flag string.
			for i = 1, #flags do
				local flag = flags:sub(i, i)
				local info = nut.flag.list[flag]

				-- Call the callback if the flag has been registered.
				if (info and info.callback) then
					-- Pass the player and false (false since the flag is being taken)
					info.callback(self:getPlayer(), false)
				end

				newFlags = newFlags:gsub(flag, "")
			end

			if (newFlags != oldFlags) then
				self:setFlags(newFlags)
			end
		end
	end

	-- Return the flag string.
	function character:getFlags()
		return self:getData("f", "")
	end

	-- Check if the flag string contains the flags specified.
	function character:hasFlags(flags)
		for i = 1, #flags do
			if (self:getFlags():find(flags:sub(i, i), 1, true)) then
				return true
			end
		end

		return false
	end
end

do
	nut.flag.add("p", "Access to the physgun.", function(client, isGiven)
		if (isGiven) then
			client:Give("weapon_physgun")
			client:SelectWeapon("weapon_physgun")
		else
			client:StripWeapon("weapon_physgun")
		end
	end)

	nut.flag.add("t", "Access to the toolgun", function(client, isGiven)
		if (isGiven) then
			client:Give("gmod_tool")
			client:SelectWeapon("gmod_tool")
		else
			client:StripWeapon("gmod_tool")
		end
	end)
end