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

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Item"
ENT.Category = "NutScript"
ENT.Spawnable = false
ENT.RenderGroup 		= RENDERGROUP_BOTH

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_junk/watermelon01.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physObj = self:GetPhysicsObject()

		if (IsValid(physObj)) then
			physObj:EnableMotion(true)
			physObj:Wake()
		end
	end

	function ENT:setItem(itemID)
		local itemTable = nut.item.instances[itemID]

		if (itemTable) then
			self:SetSkin(itemTable.skin or 0)
			self:SetModel(itemTable.model)
			self:PhysicsInit(SOLID_VPHYSICS)
			self:SetSolid(SOLID_VPHYSICS)
			self:setNetVar("id", itemTable.uniqueID)
			self.nutItemID = itemID

			if (table.Count(itemTable.data) > 0) then
				self:setNetVar("data", itemTable.data)
			end

			local physObj = self:GetPhysicsObject()

			if (!IsValid(physObj)) then
				local min, max = Vector(-8, -8, -8), Vector(8, 8, 8)

				self:PhysicsInitBox(min, max)
				self:SetCollisionBounds(min, max)
			end

			if (IsValid(physObj)) then
				physObj:EnableMotion(true)
				physObj:Wake()
			end
		end
	end

	function ENT:OnRemove()
		if (!nut.shuttingDown and !self.nutIsSafe and self.nutItemID) then
			local item = nut.item.instances[self.nutItemID]

			if (item) then
				if (item.onRemoved) then
					item:onRemoved()
				end

				nut.db.query("DELETE FROM nut_items WHERE _itemID = "..self.nutItemID)
			end
		end
	end
else
	ENT.DrawEntityInfo = true

	local toScreen = FindMetaTable("Vector").ToScreen
	local colorAlpha = ColorAlpha

	function ENT:onDrawEntityInfo(alpha)
		local itemTable = self.getItemTable(self)

		if (itemTable) then
			local oldData = itemTable.data
			itemTable.data = self.getNetVar(self, "data", {})
			itemTable.entity = self

			local position = toScreen(self.LocalToWorld(self, self.OBBCenter(self)))
			local x, y = position.x, position.y
			local description = itemTable.getDesc(itemTable)

			if (description != self.desc) then
				self.desc = description
				self.lines, self.offset = nut.util.wrapText(description, ScrW() / 3, "nutSmallFont")
				self.offset = self.offset * 0.5
			end
			
			nut.util.drawText(itemTable.name, x, y, colorAlpha(nut.config.get("color"), alpha), 1, 1, nil, alpha * 0.65)

			local lines = self.lines
			local offset = self.offset

			for i = 1, #lines do
				nut.util.drawText(lines[i], x, y + (i * 16), colorAlpha(color_white, alpha), 1, 1, "nutSmallFont", alpha * 0.65)
			end

			itemTable.entity = nil
			itemTable.data = oldData
		end		
	end

	function ENT:DrawTranslucent()
		local itemTable = self:getItemTable()

		if (itemTable and itemTable.drawEntity) then
			itemTable:drawEntity(self, itemTable)
		end
	end
end

function ENT:getItemTable()
	return nut.item.list[self:getNetVar("id", "")]
end

function ENT:getData(key, default)
	local data = self:getNetVar("data", {})

	return data[key] or default
end

function ENT:getDataTable()
	local data = self:getNetVar("data", {})

	return data
end