--!strict
-- Gold [VIP] prefix in chat for VIP pass owners. The server marks owners
-- with the "Pass_VIP" player attribute (see PassService).

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTags = {}

function ChatTags.Start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local source = message.TextSource
		if not source then
			return nil
		end
		local speaker = Players:GetPlayerByUserId(source.UserId)
		if not speaker or speaker:GetAttribute("Pass_VIP") ~= true then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = '<font color="#FFD54A">[VIP]</font> ' .. message.PrefixText
		return properties
	end
end

return ChatTags
