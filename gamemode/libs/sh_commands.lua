--[[
	Purpose: Library for console and chat command adding and processing.
--]]

nut.command = nut.command or {}
nut.command.buffer = nut.command.buffer or {}

if (SERVER) then
	local silent = false

	--[[
		Purpose: Set whether or not the console will show if a player runs a command.
	--]]
	function nut.command.SetShowCommandRan(state)
		silent = state
	end

	--[[
		Purpose: Checks if the command exists and determines what should be returned to the
		PlayerSay hook.
	--]]
	function nut.command.RunCommand(client, action, arguments, noMsgOnFail)
		local commandTable = nut.command.buffer[action]
		local echo = false

		if (commandTable) then
			if (commandTable.onRun) then
				if (commandTable.hasPermission) then
					if (commandTable.hasPermission(client) == false) then
						nut.util.Notify(nut.lang.Get("no_perm", client:Name()), client)

						return
					end
				elseif (commandTable.superAdminOnly) then
					if (!client:IsSuperAdmin()) then
						nut.util.Notify(nut.lang.Get("no_perm", client:Name()), client)

						return
					end
				elseif (commandTable.adminOnly) then
					if (!client:IsAdmin()) then
						nut.util.Notify(nut.lang.Get("no_perm", client:Name()), client)

						return
					end
				end

				if (!commandTable.allowDead and !client:Alive()) then
					nut.util.Notify(nut.lang.Get("dead_talk_error"), client)

					return
				end

				local result = commandTable.onRun(client, arguments)

				if (result == false) then
					echo = true
				end

				if !(silent or commandTable.silent) then
					if (#arguments > 0) then
						nut.util.AddLog(client:Name().." has ran command '"..action.." "..table.concat(arguments, " ").."'", LOG_FILTER_CONCOMMAND)
					else
						nut.util.AddLog(client:Name().." has ran command '"..action.."'", LOG_FILTER_CONCOMMAND)
					end
				end
			end
		elseif (!noMsgOnFail) then
			nut.util.Notify("That command does not exist.", client)
		end

		if (!echo) then
			return ""
		end
	end

	--[[
		Purpose: A console command as an alternative to the chat commands.
	--]]
	concommand.Add("nut", function(client, command, arguments)
		local action = string.lower(arguments[1] or "")
		table.remove(arguments, 1)

		for k, v in pairs(arguments) do
			if (type(v) == "string") then
				v = string.gsub(v, "\\", "")
				v = string.gsub(v, "'", "\"")
			end
		end

		if (!nut.command.buffer[action]) then
			nut.util.Notify("That command does not exist.", client)
		else
			nut.command.RunCommand(client, action, arguments)
		end
	end)

	--[[
		Purpose: Parses a command using various regular expressions which supports arguments
		that are enclosed in quotes. It also takes all the arguments and packs them into a
		table. This function calls nut.command.RunCommand and returns its return value.
	--]]
	function nut.command.ParseCommand(client, text, noMsgOnFail)
		if (string.sub(text, 1, 1) == "/") then
			local arguments = {}
			local text2 = string.sub(text, 2)
			local quote = (string.sub(text2, 1, 1) != "\"")

			for chunk in string.gmatch(text2, "[^\"]+") do
				quote = !quote

				if (quote) then
					table.insert(arguments, chunk)
				else
					for chunk in string.gmatch(chunk, "[^ ]+") do
						table.insert(arguments, chunk)
					end
				end
			end

			local command

			if (arguments[1]) then
				command = string.lower(arguments[1])
			end
			
			if (command) then
				table.remove(arguments, 1)

				local value = nut.command.RunCommand(client, command, arguments, noMsgOnFail)

				if (value) then
					return value
				end
			end

			return ""
		end
	end

	--[[
		Purpose: Makes an attempt to find a player based off the given string with
		nut.util.FindPlayer, otherwise it notifies the given player that the person
		could not be found.
	--]]
	function nut.command.FindPlayer(client, name, mute)
		local fault = nut.lang.Get("no_ply")

		if (!name) then
			if (!mute) then
				nut.util.Notify(fault, client)
			end

			return
		end

		local target = nut.util.FindPlayer(name)

		if (!IsValid(target)) then
			if (!mute) then
				nut.util.Notify(fault, client)
			end
		end

		return target
	end
else
	hook.Add("BuildHelpOptions", "nut_CommandHelp", function(data, tree)
		local categories = {}
		local contents = {}

		data:AddHelp("Commands", function(tree)
			local html = ""

			for k, v in nut.util.SortedPairs(nut.command.buffer) do
				if (!v.category) then
					if (v.adminOnly and !LocalPlayer():IsAdmin()) then
						continue
					end

					if (v.superAdminOnly and !LocalPlayer():IsSuperAdmin()) then
						continue
					end

					local syntax = v.syntax or "[none]"
					syntax = string.gsub(syntax, "<", "&lt;")
					syntax = string.gsub(syntax, ">", "&gt;")
					syntax = string.gsub(syntax, "%b[]", function(tag)
						return "<font color=\"#969696\">"..tag.."</font>"
					end)

					html = html.."<p><b>/"..k.."</b><br /><hi><i>Syntax:</i> "..syntax.."</p>"
				end
			end

			return html
		end, "icon16/comments.png")

		data:AddCallback("Commands", function(node, body)
			for k, v in nut.util.SortedPairs(nut.command.buffer) do
				if (v.category) then
					if (v.adminOnly and !LocalPlayer():IsAdmin()) then
						continue
					end

					if (v.superAdminOnly and !LocalPlayer():IsSuperAdmin()) then
						continue
					end

					if (!categories[v.category]) then
						categories[v.category] = node:AddNode(v.category)
					end

					local html = ""
						local syntax = v.syntax or "[none]"
						syntax = string.gsub(syntax, "<", "&lt;")
						syntax = string.gsub(syntax, ">", "&gt;")
						syntax = string.gsub(syntax, "%b[]", function(tag)
							return "<font color=\"#969696\">"..tag.."</font>"
						end)

						html = html.."<p><b>/"..k.."</b><br /><hi><i>Syntax:</i> "..syntax.."</p>"
					contents[v.category] = (contents[v.category] or "")..html
				end
			end

			for k, v in pairs(contents) do
				categories[k].DoClick = function()
					body:SetContents(v)
				end
			end
		end)
	end)
end

--[[
	Purpose: A function that inserts a command into the command system.
--]]
function nut.command.Register(commandTable, command)
	if (!command) then
		error("No command name provided.")
	end

	if (!commandTable) then
		error("No command table provided.")
	end
	
	if (PLUGIN and PLUGIN.name and !commandTable.category) then
		commandTable.category = PLUGIN.name
	end

	nut.command.buffer[string.lower(command)] = commandTable
end