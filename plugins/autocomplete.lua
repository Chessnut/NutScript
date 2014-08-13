local PLUGIN = PLUGIN
PLUGIN.name = "Command autocomplete"
PLUGIN.author = "Atebite"
PLUGIN.desc = "Adds autocompletion for chat commands."

if CLIENT then
	local me = LocalPlayer()

	local chat_text = ""
	local cur_suggest = ""

	local commands = nut.command.buffer

	local panel_pos_x, panel_pos_y = nut.chat.panel.frame:GetPos()
	local panel_tall = nut.chat.panel.frame:GetTall()

	function PLUGIN:HUDPaint()
		if me:IsTyping() then
			if string.match(chat_text, "/") then
				local spacer = 0
				local counter = 0

				for k,v in pairs(commands) do
					if string.match(k, chat_text:sub(2)) and counter < 4 then
						if counter == 0 then
							cur_suggest = k
						end

						draw.SimpleTextOutlined("/"..k, "nut_ChatFont", panel_pos_x + 9, (panel_pos_y + panel_tall - 6) + spacer, Color(231, 231, 231), 0, 0, 1, Color(0, 0, 0, 150))
						
						spacer = spacer + 17
						counter = counter + 1
					end
				end
			end
		end
	end

	function PLUGIN:ChatTextChanged(txt)
		chat_text = txt
	end

	function PLUGIN:FinishChat()
		chat_text = ""
	end
end