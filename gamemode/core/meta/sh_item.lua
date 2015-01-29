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

local _R = debug.getregistry()

local ITEM = _R.Item or {}
ITEM.__index = ITEM
ITEM.name = "Undefined"
ITEM.desc = ITEM.desc or "An item that is undefined."
ITEM.id = ITEM.id or 0
ITEM.uniqueID = "undefined"

function ITEM:__tostring()
	return "item["..self.uniqueID.."]["..self.id.."]"
end

function ITEM:getID()
	return self.id
end

function ITEM:getDesc()
	if (type(self.desc) == "function") then
		print(self)
		return "ERROR"
	end

	return CLIENT and L(self.desc or "noDesc") or self.desc
end

-- Dev Buddy. You don't have to print the item data with PrintData();
function ITEM:print(detail)
	if (detail == true) then
		print(Format("%s[%s]: >> [%s](%s,%s)", self.uniqueID, self.id, self.owner, self.gridX, self.gridY))
	else
		print(Format("%s[%s]", self.uniqueID, self.id))
	end
end

-- Dev Buddy, You don't have to make another function to print the item Data.
function ITEM:printData()
	self:print(true)
	print("ITEM DATA:")
	for k, v in pairs(self.data) do
		print(Format("[%s] = %s", k, v))
	end
end

function ITEM:call(method, client, entity, ...)
	local oldPlayer, oldEntity = self.player, self.entity

	self.player = self.player or client
	self.entity = self.entity or entity

	if (self.functions[method]) then
		local results = {self.functions[method](self, ...)}

		self.player = nil
		self.entity = nil

		return unpack(results)
	end

	self.player = oldPlayer
	self.entity = oldEntity
end

function ITEM:getOwner()
	local inventory = nut.item.inventories[self.invID]

	if (inventory) then
		return (inventory.getReceiver and inventory:getReceiver())
	end

	local id = self:getID()

	for k, v in ipairs(player.GetAll()) do
		local character = v:getChar()

		if (character and character:getInv():getItemByID(id)) then
			return v
		end
	end
end

function ITEM:setData(key, value, receivers, noSave, checkEntity)
	self.data = self.data or {}
	self.data[key] = value

	if (SERVER) then
		if (checkEntity) then
			local ent = self:getEntity()

			if (IsValid(ent)) then
				local data = ent:getNetVar("data", {})
				data[key] = value

				ent:setNetVar("data", data)
			end
		end
	end

	if (receivers != false) then
		if (self:getOwner()) then
			netstream.Start(receivers or self:getOwner(), "invData", self:getID(), key, value)
		end
	end

	if (!noSave) then
		if (nut.db) then
			nut.db.updateTable({_data = self.data}, nil, "items", "_itemID = "..self:getID())
		end
	end	
end

function ITEM:getData(key, default)
	if (self.data) then
		if (key == true) then
			return self.data
		end

		local value = self.data[key]

		if (value == nil) then
			if (IsValid(self.entity)) then
				local data = self.entity:getNetVar("data", {})
				local value = data[key]

				if (value != nil) then
					return value
				end
			end

			return default
		else
			return value
		end
	else
		self.data = {}
		return default
	end
end

function ITEM:hook(name, func)
	if (name and func) then
		self.hooks[name] = func
	end
end

function ITEM:remove()
	local inv = nut.item.inventories[self.invID]
	local x2, y2

	if (self.invID > 0 and inv) then
		for x = self.gridX, self.gridX + (self.width - 1) do
			if (inv.slots[x]) then
				for y = self.gridY, self.gridY + (self.height - 1) do
					local item = inv.slots[x][y]

					if (item.id == self.id) then
						inv.slots[x][y] = nil
					else
						print("ERROR OCCURED INDEX: " .. self.id)
						print("RECURSIVE x: " .. x .. " y: " .. y)
						print("REQUESTED ITEM POS x: " .. self.gridX .. " y: " .. self.gridY)
						return false
					end
				end
			end
		end
	else
		local inv = nut.item.inventories[self.invID]

		if (inv) then
			nut.item.inventories[self.invID][self.id] = nil
		end
	end

	if (SERVER and !noReplication) then
		local receiver = inv.getReceiver and inv:getReceiver()

		if (self.invID != 0) then
			if (IsValid(receiver) and receiver:getChar() and inv.owner == receiver:getChar():getID()) then
				netstream.Start(receiver, "invRm", self.id, inv:getID())
			else
				netstream.Start(receiver, "invRm", self.id, inv:getID(), inv.owner)
			end
		end

		if (!noDelete) then
			local item = nut.item.instances[self.id]

			if (item and item.onRemoved) then
				item:onRemoved()
			end
			
			nut.db.query("DELETE FROM nut_items WHERE _itemID = "..self.id)
			nut.item.instances[self.id] = nil
		end
	end

	return true
end

if (SERVER) then
	function ITEM:getEntity()
		local id = self:getID()

		for k, v in ipairs(ents.FindByClass("nut_item")) do
			if (v.nutItemID == id) then
				return v
			end
		end
	end
	-- Spawn an item entity based off the item table.
	function ITEM:spawn(position, angles)
		-- Check if the item has been created before.
		if (nut.item.instances[self.id]) then
			-- If the first argument is a player, then we will find a position to drop
			-- the item based off their aim.
			if (type(position) == "Player") then
				position = position:getItemDropPos()
			end

			-- Spawn the actual item entity.
			local entity = ents.Create("nut_item")
			entity:SetPos(position)
			entity:SetAngles(angles or Angle(0, 0, 0))
			-- Make the item represent this item.
			entity:setItem(self.id)

			-- Return the newly created entity.
			return entity
		end
	end

	-- Transfers an item to a specific inventory.
	function ITEM:transfer(invID, x, y, client, noReplication, isLogical)
		invID = invID or 0
		
		if (self.invID == invID) then
			return false, "same inv"
		end
		
		local inventory = nut.item.inventories[invID]
		local curInv = nut.item.inventories[self.invID or 0]

		if (hook.Run("CanItemBeTransfered", self, curInv, inventory) == false) then
			return false, "notAllowed"
		end

		local authorized = false

		if (curInv and !IsValid(client)) then
			client = (curInv.getReceiver and curInv:getReceiver() or nil)
		end

		if (inventory and inventory.onAuthorizeTransfer and inventory:onAuthorizeTransfer(client, curInv, self)) then
			authorized = true
		end

		if (!authorized and self.onCanBeTransfered and self:onCanBeTransfered(curInv, inventory) == false) then
			return false, "notAllowed"
		end

		if (curInv) then
			if (invID and invID > 0 and inventory) then
				local targetInv = inventory
				local bagInv

				if (!x and !y) then
					x, y, bagInv = inventory:findEmptySlot(self.width, self.height)
				end

				if (bagInv) then
					targetInv = bagInv
				end

				if (!x or !y) then
					return false, "noSpace"
				end

				local prevID = self.invID
				local status, result = targetInv:add(self.id, nil, nil, x, y, noReplication)

				if (status) then
					if (self.invID > 0 and prevID != 0) then
						curInv:remove(self.id, false, true)
						self.invID = invID

						return true
					elseif (self.invID > 0 and prevID == 0) then
						local inventory = nut.item.inventories[0]
						inventory[self.id] = nil

						return true
					end
				else
					return false, result
				end
			elseif (IsValid(client)) then
				self.invID = 0

				curInv:remove(self.id, false, true)
				nut.db.query("UPDATE nut_items SET _invID = 0 WHERE _itemID = "..self.id)

				if (isLogical != true) then
					local entity = self:spawn(client)
					entity.prevPlayer = client
					entity.prevOwner = client:getChar().id

					return entity		
				else
					local inventory = nut.item.inventories[0]
					inventory[self:getID()] = self

					return true
				end
			else
				return false, "noOwner"
			end
		else
			return false, "invalidInventory"
		end
	end
end

_R.Item = ITEM