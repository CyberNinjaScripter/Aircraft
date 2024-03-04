local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local SensorData = require(Assets:WaitForChild("Planes"))

ReplicatedStorage.Communication.RequestSensorData.OnServerInvoke = function() 
	local Success,Data = pcall(function()
		--return HttpService:JSONDecode(HttpService:GetAsync("https://opensky-network.org/api/states/all"))
        return SensorData
	end)
	
	return Success,Data
end