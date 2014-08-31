local PLUGIN = PLUGIN
PLUGIN.name = "Auto-complete"
PLUGIN.author = "Atebite and Chessnut"
PLUGIN.desc = "Adds autocompletion for chat commands."

if (CLIENT) then
	local chatText = ""
	local textColor = Color(231, 231, 231)
	local outline = Color(0, 0, 0, 150)
	
	function PLUGIN:HUDPaint()
		local frame = nut.chat.panel.frame
		
		if (IsValid(frame) and LocalPlayer():IsTyping()) then
			if (chatText:sub(1, 1) == "/") then
				local spacer = 0
				local counter = 0
				local x, y = frame:GetPos()
				local height = frame:GetTall()
				
				for k,v in pairs(nut.command.buffer) do
					if (chatText:sub(2, #k):lower() == k and counter < 4) then
						draw.SimpleTextOutlined("/"..k, "nut_ChatFont", x + 9, (y + tall - 6) + spacer, textColor, 0, 0, 1, outline)
						
						spacer = spacer + 17
						counter = counter + 1
					end
				end
			end
		end
	end

	function PLUGIN:ChatTextChanged(text)
		chatText = text
	end

	function PLUGIN:FinishChat()
		chatText = ""
	end
end
