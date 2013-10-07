--[[
	Purpose: A library for custom chat commands and types of chat classes for roleplay.
	This include classes such as OOC or /me. This file will also define some default
	chat classes.
--]]

if (!netstream) then
	include("sh_netstream.lua")
end

nut.chat = nut.chat or {}
nut.chat.classes = nut.chat.classes or {}

--[[
	Purpose: Registers a chat class using a table passed as a structure.
	The structure contains:
		canHear (function/number): If it is a function, determines whether
			or not the listener can see the speaker's chat. If it is a number,
			it will detect if the distance between the listener and speaker
			is less than or equal to it.
		onChat (function): What happens when the player uses that class. This
			is primarily for adding the actual text to the chat.
		canSay (function): Whether or not the speaker can use the chat class.
		prefix (string/table): What is needed to start the text to identify the class.
		font (string): An optional argument to override the font for that chat class.
--]]
function nut.chat.Register(class, structure)
	structure.canHear = structure.canHear or function() return true end

	if (type(structure.canHear) == "number") then
		local distance = structure.canHear

		function structure.canHear(speaker, listener)
			if (speaker:GetPos():Distance(listener:GetPos()) > distance) then
				return false
			end

			return true
		end
	end

	structure.onChat = structure.onChat or function(speaker, text)
		chat.AddText(speaker, Color(255, 255, 255), ": "..text)
	end
	structure.canSay = structure.canSay or function(speaker)
		local result = nut.schema.Call("ChatClassCanSay", class, structure, speaker)

		if (result != nil) then
			return result
		end

		if (!speaker:Alive() and !structure.deadCanTalk) then
			nut.util.Notify(nut.lang.Get("dead_talk_error"), speaker)

			return false
		end

		return true
	end

	nut.schema.Call("ChatClassRegister", class, structure)
	nut.chat.classes[class] = structure
end

-- Register chat classes.
do
	local r, g, b = 114, 175, 237

	nut.chat.Register("whisper", {
		canHear = nut.config.whisperRange,
		onChat = function(speaker, text)
			chat.AddText(Color(r - 25, g - 25, b - 25), speaker:Name()..": "..text)
		end,
		prefix = {"/w", "/whisper"}
	})

	nut.chat.Register("looc", {
		canHear = nut.config.chatRange,
		onChat = function(speaker, text)
			chat.AddText(Color(r, g, b), "[LOOC] "..speaker:Name()..": "..text)
		end,
		prefix = {".//", "[[", "/looc"},
		canSay = function(speaker)
			return true
		end
	})

	nut.chat.Register("it", {
		canHear = nut.config.chatRange,
		onChat = function(speaker, text)
			chat.AddText(Color(r, g, b), "**"..text)
		end,
		prefix = "/it",
		font = "nut_ChatFontAction"
	})

	nut.chat.Register("ic", {
		canHear = nut.config.chatRange,
		onChat = function(speaker, text)
			chat.AddText(Color(r, g, b), speaker:Name()..": "..text)
		end
	})

	nut.chat.Register("yell", {
		canHear = nut.config.yellRange,
		onChat = function(speaker, text)
			chat.AddText(Color(r + 35, g + 35, b + 35), speaker:Name()..": "..text)
		end,
		prefix = {"/y", "/yell"}
	})

	nut.chat.Register("me", {
		canHear = nut.config.chatRange,
		onChat = function(speaker, text)
			chat.AddText(Color(r, g, b), "**"..speaker:Name().." "..text)
		end,
		prefix = {"/me", "/action"},
		font = "nut_ChatFontAction"
	})

	nut.chat.Register("ooc", {
		onChat = function(speaker, text)
			chat.AddText(Color(250, 40, 40), "[OOC] ", speaker, color_white, ": "..text)
			
		if (LocalPlayer():IsAdmin()) then
			chat.AddText(Color(40, 250, 40), "[ADMIN]", speaker, color_white, ": "..text)
			end
		end,
		prefix = {"//", "/ooc"},
		deadCanTalk = true,
		canSay = function(speaker)
			local nextOOC = speaker:GetNutVar("nextOOC", 0)

			if (nextOOC < CurTime()) then
				speaker:SetNutVar("nextOOC", CurTime() + nut.config.oocDelay)
				return true
			end

			nut.util.Notify("You must wait "..math.ceil(nextOOC - CurTime()).." more second(s) before using OOC.", client)

			return false
		end
	})

	nut.chat.Register("event", {
		onChat = function(speaker, text)
			if (!speaker:IsAdmin()) then
				nut.util.Notify(nut.lang.Get("no_perm", speaker:Name()), speaker)

				return
			end

			chat.AddText(Color(194, 93, 39), text)
		end,
		prefix = "/event",
	})

	nut.chat.Register("roll", {
		canHear = nut.config.chatRange,
		onChat = function(speaker, text)
			chat.AddText(Color(158, 122, 196), text)
		end
	})
end

if (CLIENT) then
	NUT_CVAR_CHATFILTER = CreateClientConVar("nut_chatfilter", "none", true, true)

	local function isChatFiltered(uniqueID)
		local info = NUT_CVAR_CHATFILTER:GetString()

		if (string.find(info, "none")) then
			return false
		end

		local exploded = string.Explode(",", string.gsub(info, " ", ""))

		return table.HasValue(exploded, uniqueID)
	end

	-- Handle standard game messages.
	hook.Add("ChatText", "nut_GameMessages", function(index, name, text, messageType)
		if (index == 0 and name == "Console") then
			if (isChatFiltered("gamemsg")) then
				return
			end

			chat.AddText(nut.config.gameMsgColor, text)
		end

		return true
	end)

	hook.Add("ChatOpened", "nut_Typing", function(teamChat)
		if (!nut.config.showTypingText) then
			netstream.Start("nut_Typing", "1")
		end
	end)

	hook.Add("FinishChat", "nut_Typing", function(teamChat)
		netstream.Start("nut_Typing", "")
	end)

	local nextSend = 0

	hook.Add("ChatTextChanged", "nut_Typing", function(text)
		if (nut.config.showTypingText) then
			if (nextSend < CurTime()) then
				netstream.Start("nut_Typing", text)
				nextSend = CurTime() + 0.25
			end
		end
	end)

	-- Handle a chat message from the server and parse it with the appropriate chat class.
	netstream.Hook("nut_ChatMessage", function(data)
		local speaker = data[1]
		local mode = data[2]
		local text = data[3]
		local class = nut.chat.classes[mode]

		if (!IsValid(speaker) or !speaker.character or !class or isChatFiltered(mode)) then
			return
		end

		if !nut.schema.Call("ChatClassPreText", class, speaker, text, mode) then --** allows you inturrupt the text when the hook is returned true ( can be used for Non-RP Chat filter or Curse word filter. )
			class.onChat(speaker, text)
		end

		nut.schema.Call("ChatClassPostText", class, speaker, text, mode)
	end)
else
	netstream.Hook("nut_Typing", function(client, data)
		client:SetNetVar("typing", data)
	end)

	-- Send a chat class to the clients that can hear it based off the classes's canHear function.
	function nut.chat.Send(client, mode, text)
		local listeners = {client}
		local class = nut.chat.classes[mode]

		if (!class.canSay(client)) then
			return ""
		end

		for k, v in pairs(player.GetAll()) do
			if (class.canHear(client, v)) then
				listeners[#listeners + 1] = v
			end
		end

		netstream.Start(listeners, "nut_ChatMessage", {client, mode, text})

		local color = team.GetColor(client:Team())
		local channel = "r"
		local highest = 0

		for k, v in pairs(color) do
			if (v > highest and k != "a") then
				highest = v
				channel = k
			end

			if (v <= 50) then
				color[k] = 0
			end
		end

		if (highest <= 200) then
			color[channel] = 200
		else
			color[channel] = 255
		end
		
		MsgC(color, client:Name())
		MsgC(color_white, ": ")
		MsgC(Color(200, 200, 200), "("..string.upper(mode)..") ")
		MsgC(color_white, text.."\n")
	end

	-- Proccess the text and see if it is a chat class or chat command.
	function nut.chat.Process(client, text)
		if (!client.character) then
			nut.util.Notify(nut.lang.Get("nochar_talk_error"), client)
			
			return
		end

		local mode
		local text2 = string.lower(text)

		for k, v in pairs(nut.chat.classes) do
			if (type(v.prefix) == "table") then
				for k2, v2 in pairs(v.prefix) do
					local length = #v2 + 1

					if (string.Left(text2, length) == v2.." ") then
						mode = k
						text = string.sub(text, length + 1)

						break
					end
				end
			elseif (v.prefix) then
				local length = #v.prefix + 1

				if (string.Left(text2, length) == v.prefix.." ") then
					mode = k
					text = string.sub(text, length + 1)
				end
			end
		end

		mode = mode or "ic"

		if (mode == "ic") then
			local value = nut.command.ParseCommand(client, text)

			if (value) then
				return value
			end
		end

		nut.chat.Send(client, mode, text)

		return ""
	end
end

local playerMeta = FindMetaTable("Player")

function playerMeta:IsTyping()
	return self:GetNetVar("typing", "") != ""
end
