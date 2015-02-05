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

if (SERVER) then
	netstream.Hook("bizBuy", function(client, items)
		local char = client:getChar()
		if (!char) then
			return
		end

		local cost = 0

		for k, v in pairs(items) do
			local itemTable = nut.item.list[k]

			if (itemTable and hook.Run("CanPlayerUseBusiness", client, k) != false) then
				local amount = math.Clamp(tonumber(v) or 0, 1, 10)
				
				cost = cost + (amount * (itemTable.price or 0))
			else
				items[k] = nil
			end
		end

		if (char:hasMoney(cost)) then
			char:takeMoney(cost)

			local entity = ents.Create("nut_shipment")
			entity:SetPos(client:getItemDropPos())
			entity:Spawn()
			entity:setItems(items)
			entity:setNetVar("owner", char:getID())

			local shipments = char:getVar("charEnts") or {}
			table.insert(shipments, entity)
			char:setVar("charEnts", shipments, true)

			netstream.Start(client, "bizResp")
			hook.Run("OnCreateShipment", client, entity)
		end
	end)

	netstream.Hook("shpUse", function(client, uniqueID, drop)
		local entity = client.nutShipment
		local itemTable = nut.item.list[uniqueID]

		if (itemTable and IsValid(entity)) then
			if (entity:GetPos():Distance(client:GetPos()) > 128) then
				client.nutShipment = nil

				return
			end

			local amount = entity.items[uniqueID]

			if (amount and amount > 0) then
				if (entity.items[uniqueID] <= 0) then
					entity.items[uniqueID] = nil
				end

				if (drop) then
					nut.item.spawn(uniqueID, entity:GetPos() + Vector(0, 0, 16))
				else
					local status, fault = client:getChar():getInv():add(uniqueID)

					if (!status) then
						return client:notifyLocalized("noFit")
					end

					--netstream.Hook("updtShp", uniqueID)
				end
					
				hook.Run("OnTakeShipmentItem", client, uniqueID, amount)

				entity.items[uniqueID] = entity.items[uniqueID] - 1

				if (entity:getItemCount() < 1) then
					entity:GibBreakServer(Vector(0, 0, 0.5))
					entity:Remove()
				end
			end
		end
	end)
else
	netstream.Hook("openShp", function(entity, items)
		nut.gui.shipment = vgui.Create("nutShipment")
		nut.gui.shipment:setItems(entity, items)
	end)

	netstream.Hook("updtShp", function(entity, items)
		if (nut.gui.shipment and nut.gui.shipment:IsVisible()) then
		end
	end)

	netstream.Hook("takeShp", function(name, amount)
		if (nut.gui.shipment and nut.gui.shipment:IsVisible()) then
			local item = nut.gui.shipment.itemPanel[name]

			if (item) then
				item.amount = item.amount - 1
				item:Update(item.amount)

				if (item.amount <= 0) then
					item:Remove()
				end
			end
		end
	end)
end