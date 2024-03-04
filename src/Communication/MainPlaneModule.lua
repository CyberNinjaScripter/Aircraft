local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Communication = ReplicatedStorage:WaitForChild("Communication")

local PlaneModule = {
    Functions = {

    },

    Variables = {
        PlaneRenderLimit = 500,
        IsStudio = RunService:IsStudio()
    },

    Templates = {
        Callsign = Assets.CallSign,
        Flight = Assets.Flight,
        FlightPathLine = Assets.FlightPathLine,
        Plane = Assets.Plane
    }
}

PlaneModule.Variables.TerrainColors = {
    {Color = Color3.new(0, 1, 0.701961), Meters = 9000},
    {Color = Color3.new(1, 0.768627, 0.396078), Meters = 4500},
    {Color = Color3.new(1, 0.466667, 0.47451), Meters = 0}
}

local function ValidateData(SensorData)
    local SensorData_Encoded = HttpService:JSONEncode(SensorData)
    local SensorData_Decoded = HttpService:JSONDecode(SensorData_Encoded)
    local Aircrafts = SensorData_Decoded.states
    local TimeStamp = SensorData_Decoded.time

    if PlaneModule.Variables.IsStudio then
        print("Sensors Responded With: " , SensorData_Decoded)
    end

    if Aircrafts and TimeStamp then
        for i,_ in pairs(Aircrafts) do
            if i > 500 then
                Aircrafts[i] = nil
            end
        end

        return true,Aircrafts,TimeStamp
    else
        warn("Invalid data type!: Sensors Responded With: " , SensorData_Decoded)

        return false
    end
end

PlaneModule.Functions.GetAltitudeColor = function(Altitude)
    local LowerMeter = 0
	local ColorMeter = Color3.new(1, 0.466667, 0.47451)

	for _,v in pairs(PlaneModule.Variables.TerrainColors) do
		if v.Meters <= Altitude and v.Meters >= LowerMeter then
			LowerMeter = v.Meters
			ColorMeter = v.Color
		end
	end

	return ColorMeter
end

PlaneModule.Functions.GetPlaneSize = function(MapSize)
	local Size = math.clamp(3/(MapSize.X.Scale*100),0,0.03) 
	return UDim2.new(Size,0,Size,0)
end

PlaneModule.Functions.ConvertCoordinates = function(Latitude, Longitude)
	local RadLatitude,RadLongitude = math.rad(Latitude) , math.rad(Longitude)

    local X = (RadLongitude + math.pi) / (2 * math.pi)
    local Y = (math.pi - math.log(math.tan(RadLatitude / 2 + math.pi / 4))) / (2 * math.pi)
    
	return Vector2.new(X, Y)
end

PlaneModule.Functions.ConvertPosition = function(Position)
    local RadLongitude = Position.X * 2 * math.pi - math.pi
    local RadLatitude = (math.atan(math.exp(math.pi - Position.Y * 2 * math.pi)) - math.pi / 4) * 2
    
    local Latitude = math.deg(RadLatitude)
    local Longitude = math.deg(RadLongitude)
    
    return Latitude, Longitude
end

PlaneModule.Functions.GetSensorData = function()
    local Success,SensorData = Communication.RequestSensorData:InvokeServer()

    if Success then
        return ValidateData(SensorData)
    end
end

PlaneModule.Functions.GetEventData = function()
    local Success,EventData = Communication.RequestEventData:InvokeServer()

    if Success then
        return EventData
    end
end

PlaneModule.Functions.GetFlightTemplate = function(FlightData_Labeled)
    local Flight_Clone = PlaneModule.Templates.Flight:Clone()

    local Success,Error = pcall(function()
        Flight_Clone.Altitude.Text = FlightData_Labeled.Altitude_Baro and tostring(FlightData_Labeled.Altitude_Baro).." Meters" or "N/A"
        Flight_Clone.CallSign.Text = FlightData_Labeled.CallSign or "N/A"
        Flight_Clone.Latitude.Text = "Latitude: "..tostring(FlightData_Labeled.Location_Latitude) or "Latitude: N/A"
        Flight_Clone.Longitude.Text = "Longitude: "..tostring(FlightData_Labeled.Location_Longitude) or "Longitude: N/A"

        Flight_Clone.Origin.Text = FlightData_Labeled.CountryOfOrigin or "N/A"
        Flight_Clone.Squawk.Text = FlightData_Labeled.Transponder_Squawk and "Squawk: "..tostring(FlightData_Labeled.Transponder_Squawk) or "Squawk: N/A"
        Flight_Clone.Velocity.Text = FlightData_Labeled.Velocity and "Velocity: "..tostring(FlightData_Labeled.Velocity).." m/s" or "Velocity: N/A"
        Flight_Clone.VerticalRate.Text = FlightData_Labeled.VerticalRate and "VS: "..tostring(FlightData_Labeled.VerticalRate).." m/s" or "VS: N/A"

        Flight_Clone.LastContact.Text = FlightData_Labeled.LastContact and "LC: "..os.date("%c",FlightData_Labeled.LastContact) or "LC: N/A"
        Flight_Clone.LastUpdated.Text = FlightData_Labeled.LastPositionUpdate and "LPU: "..os.date("%c",FlightData_Labeled.LastPositionUpdate) or "LPU: N/A"

        Flight_Clone.Name = FlightData_Labeled.Transponder_Address
    end)

    if not Success then
        warn(Error)
    end

    return Flight_Clone
end

PlaneModule.Functions.GetFlightPath = function(LastKnownPosition,Plane)
	local Position1 = Vector2.new(LastKnownPosition.X.Scale, LastKnownPosition.Y.Scale)
	local Position2 = Vector2.new(Plane.Position.X.Scale, Plane.Position.Y.Scale)
	
	local Distance = (Position1 - Position2).Magnitude

    return UDim2.new(Distance/Plane.Size.X.Scale,0,0,3.5) , UDim2.new(0.5,0,Distance/Plane.Size.X.Scale/2,0)
end

return PlaneModule