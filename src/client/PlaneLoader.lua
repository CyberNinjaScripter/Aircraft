local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local MainPlaneModule = require(Assets:WaitForChild("MainPlaneModule"))

local MainPanel = script.Parent:WaitForChild("MainPanel")
local Map = script.Parent:WaitForChild("Map")

local DataDebounce = true
local PreviousSelected = false
local CallSignPreview = Assets.CallSign
local FlightPathLine = Assets.FlightPathLine
local LastKnownPosition

local function LoadFlight(FlightData)
    local FlightData_Labeled = {
        Transponder_Address   = FlightData[1],
        CallSign = FlightData[2],
        CountryOfOrigin = FlightData[3],
        LastPositionUpdate = FlightData[4],
        LastContact = FlightData[5],
        Location_Longitude = FlightData[6],
        Location_Latitude = FlightData[7],
        Altitude_Baro = FlightData[8],
        OnGround = FlightData[9],
        Velocity = FlightData[10],
        Cardinal_Direction = FlightData[11],
        VerticalRate = FlightData[12],
        SensorIDs = FlightData[13],
        Altitude_Geo = FlightData[14],
        Transponder_Squawk = FlightData[15],
        SpecialPurposeIndicator = FlightData[16],
        SourcePosition = FlightData[17],
        FlightCategory = FlightData[18]
    }

    local FlightTemplate = MainPlaneModule.Functions.GetFlightTemplate(FlightData_Labeled)
    
    MainPanel.CurrentEvent.TextLabel.Text = "New Aircraft Detected at Latitude: "..tostring(FlightData_Labeled.Location_Latitude).." Longitude: "..tostring(FlightData_Labeled.Location_Longitude).." Altitude: "..tostring(FlightData_Labeled.Altitude_Baro).." by sensor: "..(FlightData_Labeled.SensorIDs or "N/A").."! Callsign: "..tostring((FlightData_Labeled.CallSign or "N/A"))

    FlightTemplate.Parent = MainPanel.ScrollingFrame

    MainPanel.ScrollingFrame.CanvasPosition = Vector2.new(0,1000000000)

    if FlightData_Labeled.Transponder_Address and FlightData_Labeled.Cardinal_Direction and FlightData_Labeled.Location_Longitude and FlightData_Labeled.Location_Latitude and FlightData_Labeled.Altitude_Baro and not FlightData_Labeled.OnGround and FlightData_Labeled.CallSign then
        local PlaneExists = Map.Display:FindFirstChild(FlightData_Labeled.Transponder_Address)

        if PlaneExists then
            local UpdatedPlaneCoordinates = MainPlaneModule.Functions.ConvertCoordinates(FlightData_Labeled.Location_Latitude,FlightData_Labeled.Location_Longitude)

            local Tween = TweenService:Create(PlaneExists,TweenInfo.new(60,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{Position = UDim2.new(UpdatedPlaneCoordinates.X,0,UpdatedPlaneCoordinates.Y,0) })
            Tween:Play()
        else
            local RadarPlane = Assets.Plane:Clone()

            local PlaneCoordinates = MainPlaneModule.Functions.ConvertCoordinates(FlightData_Labeled.Location_Latitude,FlightData_Labeled.Location_Longitude)

            RadarPlane.Position = UDim2.new(PlaneCoordinates.X,0,PlaneCoordinates.Y,0)
            RadarPlane.Rotation = FlightData_Labeled.Cardinal_Direction
            RadarPlane.Name = FlightData_Labeled.Transponder_Address
            RadarPlane.Callsign.Value = FlightData_Labeled.CallSign
            RadarPlane.Velocity.Value = FlightData_Labeled.Velocity or 0
            
            RadarPlane.Altitude.Value = FlightData_Labeled.Altitude_Baro or 0
            
            RadarPlane.VerticalRate.Value = FlightData_Labeled.VerticalRate or 0

            RadarPlane.Visible = FlightData_Labeled.CallSign:lower():match(Map.Filter.TextLabel.Text:lower()) or FlightData_Labeled.Transponder_Address:lower():match(Map.Filter.TextLabel.Text:lower()) 
            
            if RadarPlane.Visible and script.HighlightedPlane.Value then
                RadarPlane.Visible = false
            end

            RadarPlane.ImageColor3 = MainPlaneModule.Functions.GetAltitudeColor(FlightData_Labeled.Altitude_Baro)
            RadarPlane.OriginalColor.Value = MainPlaneModule.Functions.GetAltitudeColor(FlightData_Labeled.Altitude_Baro)

            RadarPlane.Parent = Map.Display
            RadarPlane.ZIndex = FlightData_Labeled.Altitude_Baro

            RadarPlane.MouseEnter:Connect(function()
                RadarPlane.PlaneSelected.Value = true
                
                for _,v in pairs(Map.Display:GetChildren()) do
                    if v:IsA("ImageButton") then
                        v.ImageColor3 = v.OriginalColor.Value
                    end
                end

                RadarPlane.ImageColor3 = Color3.new(1, 1, 1)
                CallSignPreview.Frame.CallSign.Text = RadarPlane.Callsign.Value
                CallSignPreview.Parent = RadarPlane.Parent
                CallSignPreview.Position = RadarPlane.Position
            end)

            RadarPlane.MouseLeave:Connect(function()
                if RadarPlane.PlaneSelected.Value then
                    RadarPlane.PlaneSelected.Value = false
                    RadarPlane.ImageColor3 = RadarPlane.OriginalColor.Value
                    CallSignPreview.Parent = script
                end
            end)

            RadarPlane.MouseButton1Click:Connect(function()
                script.HighlightedPlane.Value = RadarPlane
                
                LastKnownPosition = UDim2.new(PlaneCoordinates.X,0,PlaneCoordinates.Y,0)
                
                for _,v in pairs(Map.FlightDetails.ScrollingFrame:GetChildren()) do
                    if v:IsA("ImageButton") then
                        v.TextLabel.Text = v.Name..": N/A"
                        v.TextLabel.Text = v.Name..": "..FlightTemplate[v.Name].Text
                    end
                end
            end)

            RadarPlane.Size = MainPlaneModule.Functions.GetPlaneSize(Map.Display.Size)
        end
    end
end

MainPanel.Connect.MouseButton1Click:Connect(function()
	if not DataDebounce then print("Debounce!") return end

	DataDebounce = false

	MainPanel.CurrentEvent.TextLabel.Text = "Connecting To Sensors!"
    
	task.wait(1)

	local Success,Flights,TimeStamp = MainPlaneModule.Functions.GetSensorData()

    if Success then
        Map.TimeStamp.Text = "Live Data From: "..os.date("%c",TimeStamp)
        MainPanel.CurrentEvent.TextLabel.Text = "Connected!"

        for _,FlightData in pairs(Flights) do
            task.wait()
    
            task.spawn(function()
                LoadFlight(FlightData)
            end)
        end
    end

	DataDebounce = true
end)

MainPanel.ShowMap.MouseButton1Click:Connect(function()
	Map.Visible = not Map.Visible
    MainPanel.ScrollingFrame.ScrollingEnabled = not Map.Visible
end)

Map.Filter.TextLabel:GetPropertyChangedSignal("Text"):Connect(function()
	local Text = script.Parent.Map.Filter.TextLabel.Text:lower()

	for _,v in pairs(Map.Display:GetChildren()) do
		if v:IsA("ImageButton") then
			local Name = v.Callsign.Value:lower()
			v.Visible = Name:match(Text) or Name:match(v.Name:lower())
		end
	end
end)

local function Move(Plane,Velocity,VerticalRate)
	local Rotation = math.rad(Plane.Rotation)
	local Direction = Vector2.new(math.sin(Rotation), -math.cos(Rotation))

    Plane.Velocity.Value += math.random(-5,5)/10

    if Plane.Altitude.Value >= 1000 then
        Plane.VerticalRate.Value += math.random(-5,5)/10
    else
        Plane.VerticalRate.Value += math.random(0,5)/10
    end

    Plane.Altitude.Value = tonumber(Plane.Altitude.Value) + tonumber(VerticalRate/30)


	Plane.Position = UDim2.new(
		Plane.Position.X.Scale + Direction.X * Velocity/100000000,
		Plane.Position.X.Offset,
		Plane.Position.Y.Scale + Direction.Y * Velocity/100000000,
		Plane.Position.Y.Offset
	)
end

RunService.RenderStepped:Connect(function()
	for _,v in pairs(Map.Display:GetChildren()) do
		if v:IsA("ImageButton") then
			v.Size = MainPlaneModule.Functions.GetPlaneSize(Map.Display.Size)
			Move(v,v.Velocity.Value,v.VerticalRate.Value)
		end
	end
end)

Map.InputBegan:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 then
		local Plane = script.HighlightedPlane.Value
		
		if Plane then
			Plane.PlaneSelected.Value = false
			script.HighlightedPlane.Value = nil
		end
		
		CallSignPreview.Parent = script
		script.Parent.Map.FlightDetails.Visible = false
	end
end)

local function UpdateFlightPlan(Plane)
    local FlightPlanSize , FlightPlanPosition = MainPlaneModule.Functions.GetFlightPath(LastKnownPosition,Plane)

    FlightPathLine.Size = FlightPlanSize
    FlightPathLine.Position = FlightPlanPosition
    FlightPathLine.Parent = Plane
end

local Courtine = coroutine.create(function()
    while task.wait() do
        for _,v in pairs(Map.Display:GetChildren()) do
            if v:IsA("ImageButton") then
                local Flight = MainPanel.ScrollingFrame:FindFirstChild(v.Name)

                if Flight then
                    Flight.BackgroundColor3 = Color3.fromRGB(13, 61, 108)
                    
                    task.wait()

                    local Latitude, Longitude = MainPlaneModule.Functions.ConvertPosition(Vector2.new(v.Position.X.Scale,v.Position.Y.Scale))
            
                    Flight.Latitude.Text = Latitude and "Latitude: "..tostring(math.round(Latitude)) or "N/A"
                    Flight.Longitude.Text = Longitude and "Longitude: "..tostring(math.round(Longitude)) or "N/A"
                    Flight.Velocity.Text = v.Velocity.Value and "Velocity: "..tostring(math.round(v.Velocity.Value)).." m/s" or "Velocity: N/A"
                    Flight.VerticalRate.Text = v.VerticalRate.Value and "VS: "..tostring(math.round(v.VerticalRate.Value)).." m/s" or "VS: N/A"
                    Flight.Altitude.Text = v.Altitude.Value and tostring(math.round(v.Altitude.Value)).." Meters" or "N/A"
                    Flight.LastUpdated.Text = "LC: "..os.date("%c") or "LC: N/A"
                    Flight.LastContact.Text = "LPU: "..os.date("%c") or "LPU: N/A"

                    task.wait()

                    Flight.BackgroundColor3 = Color3.fromRGB(10, 45, 81)
                end
            
                if not v.PlaneSelected.Value then
                    local UpdatedColor = MainPlaneModule.Functions.GetAltitudeColor(v.Altitude.Value)
            
                    v.ImageColor3 = UpdatedColor
                    v.OriginalColor.Value = UpdatedColor
                end
            end
        end
    end
end)

coroutine.resume(Courtine)

MainPanel.Event.MouseButton1Click:Connect(function()
    local EventData = MainPlaneModule.Functions.GetEventData()

    for _,v in pairs(EventData) do
        if v.geometry then
            for _,v in pairs(v.geometry) do
                local Event = Assets:WaitForChild("Event")
                local EventCoordinates = MainPlaneModule.Functions.ConvertCoordinates(v[1],v[2])
                
                Event.Position = UDim2.new(EventCoordinates.X,0,EventCoordinates.Y,0)
                Event.Parent = Map.Display
            end
        end
    end
end)

while task.wait() do
	local Plane = script.HighlightedPlane.Value
	
	if Plane then	
		for _,v in pairs(Map.Display:GetChildren()) do
			if v:IsA("ImageButton") then
				v.Visible = false
			end
		end
		
		Plane.Visible = true

		Plane.ImageColor3 = Color3.new(1, 1, 1)

		Map.FlightDetails.ScrollingFrame.Altitude.TextLabel.Text = "Altitude: "..tostring(math.round(Plane.Altitude.Value)).." Meters" or "N/A"
		Map.FlightDetails.ScrollingFrame.Velocity.TextLabel.Text = "Velocity: "..tostring(math.round(Plane.Velocity.Value)).." m/s" or "Velocity: N/A"
        Map.FlightDetails.ScrollingFrame.VerticalRate.TextLabel.Text = "VS: "..tostring(math.round(Plane.VerticalRate.Value)).." m/s" or "VS: N/A"

		CallSignPreview.Frame.CallSign.Text = Plane.Callsign.Value
		CallSignPreview.Parent = Plane.Parent
		CallSignPreview.Position = Plane.Position

        UpdateFlightPlan(Plane)

        Map.FlightDetails.Visible = true
		
		PreviousSelected = true
	elseif PreviousSelected then
		PreviousSelected = false

		for _,v in pairs(Map.Display:GetChildren()) do
			if v:IsA("ImageButton") then
				v.Visible = true
				v.ImageColor3 = v.OriginalColor.Value
			end
		end
		
		FlightPathLine.Parent = script
	end
end