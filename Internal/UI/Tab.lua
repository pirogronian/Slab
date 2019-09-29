--[[

MIT License

Copyright (c) 2019 Mitchell Davis <coding.jackalope@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]

local Dock = require(SLAB_PATH .. '.Internal.UI.Dock')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Style = require(SLAB_PATH .. '.Style')

local Tab = {}

local Instances = {}
local WindowToTab = {}
local Active = nil
local SelectorInstance = nil
local Stack = {}
local Pad = 6
local DropdownSize = 12

local function GetBounds(Instance)
	if Instance ~= nil then
		return Instance.X + Instance.DeltaX
			, Instance.Y + Instance.DeltaY
			, Instance.W + Instance.Border + Instance.DeltaW
			, Style.Font:getHeight()
	end

	return 0, 0, 0, 0
end

local function GetSelectorBounds(Instance)
	if Instance ~= nil then
		local X, Y, W, H = GetBounds(Instance)
		X = X + W - DropdownSize
		Y = Y + H

		local MaxW = 0
		for I, V in ipairs(Instance.Windows) do
			MaxW = math.max(Style.Font:getWidth(V.Title, MaxW))
		end
		W = MaxW + Pad * 2
		H = #Instance.Windows * Style.Font:getHeight()

		local ViewW, ViewH = love.graphics.getWidth(), love.graphics.getHeight()
		if X + W > ViewW then
			X = math.max(X - (X + W - ViewW), 0)
		end

		if Y + H > ViewH then
			Y = math.max(Y - (Y + H - ViewH), 0)
		end

		W = math.min(W, ViewW)
		H = math.min(H, ViewH)

		return X, Y, W, H
	end

	return 0, 0, 0, 0
end

local function SetActiveWindow(Instance, Id)
	if Instance ~= nil then
		Instance.ActiveWinId = Id
		Instance.ResetSize = true
		Instance.ResetPosition = true
		Instance.X = Instance.X + Instance.DeltaX
		Instance.Y = Instance.Y + Instance.DeltaY
		Instance.W = Instance.W + Instance.DeltaW
		Instance.H = Instance.H + Instance.DeltaH
	end
end

local function AlterOptions(Instance, Options)
	if Instance ~= nil then
		Options.X = Instance.X
		Options.Y = Instance.Y
		Options.W = Instance.W
		Options.H = Instance.H
		Options.Border = Instance.Border
		Options.Rounding = Instance.Rounding
		Options.Title = ""
		Options.AutoSizeWindow = false
		Options.AutoSizeWindowW = false
		Options.AutoSizeWindowH = false
		Options.ResetSize = Instance.ResetSize
		Options.ResetPosition = Instance.ResetPosition

		Instance.BgColor = Options.BgColor
		Instance.ResetSize = false
		Instance.ResetPosition = false
	end
end

local function BeginWindow(Instance, WinId, Options)
	Options = Options == nil and {} or Options

	if Instance ~= nil then
		if Instance.ActiveWinId == nil then
			Instance.ActiveWinId = WinId
			Instance.X = Options.X
			Instance.Y = Options.Y
			Instance.W = Options.W
			Instance.H = Options.H
			Instance.Border = Options.Border
			Instance.Rounding = Options.Rounding
		end

		local Title = Options.Title
		if Title == nil or Title == "" then
			Title = "Tab " .. #Instance.Windows + 1
		end

		table.insert(Instance.Windows, {Id = WinId, Title = Title})
		WindowToTab[WinId] = Instance

		if Instance.ActiveWinId == WinId then
			AlterOptions(Instance, Options)
			return true
		end
	end

	return false
end

local function ApplyWindowDelta(Instance, X, Y, W, H)
	if Instance ~= nil then
		Instance.DeltaX = X
		Instance.DeltaY = Y
		Instance.DeltaW = W
		Instance.DeltaH = H
	end
end

local function IsWindowActive(Instance, WinId)
	if Instance ~= nil then
		return Instance.ActiveWinId == WinId
	end

	return false
end

local function EndWindow(Instance, WinId, Options)
	Options = Options == nil and {} or Options
	Options.Layer = Options.Layer == nil and 'Normal' or Options.Layer
	Options.Channel = Options.Channel == nil and nil or Options.Channel
	Options.Focused = Options.Focused == nil and false or Options.Focused

	if Instance ~= nil then
		if Instance.ActiveWinId == WinId then
			Instance.Layer = Options.Layer
			Instance.Channel = Options.Channel
			Instance.Focused = Options.Focused
			return true
		end
	end

	return false
end

local function GetInstance(Id)
	if Instances[Id] == nil then
		local Instance = {}
		Instance.Id = Id
		Instance.ActiveWinId = nil
		Instance.Windows = {}
		Instance.X = 0
		Instance.Y = 0
		Instance.W = 0
		Instance.H = 0
		Instance.DeltaX = 0
		Instance.DeltaY = 0
		Instance.DeltaW = 0
		Instance.DeltaH = 0
		Instance.Border = 0
		Instance.Rounding = Style.WindowRounding
		Instance.Layer = 'Normal'
		Instance.Channel = 1
		Instance.BgColor = Style.WindowBackgroundColor
		Instance.ResetSize = false
		Instance.ResetPosition = false
		Instance.Focused = false
		Instance.Override = false
		Instances[Id] = Instance
	end

	return Instances[Id]
end

function Tab.Begin(Id, Options)
	Options = Options == nil and {} or Options
	Options.X = Options.X == nil and nil or Options.X
	Options.Y = Options.Y == nil and nil or Options.Y
	Options.W = Options.W == nil and nil or Options.W
	Options.H = Options.H == nil and nil or Options.H

	local Instance = GetInstance(Id)
	Instance.X = Options.X == nil and Instance.X or Options.X
	Instance.Y = Options.Y == nil and Instance.Y or Options.Y
	Instance.W = Options.W == nil and Instance.W or Options.W
	Instance.H = Options.H == nil and Instance.H or Options.H

	Active = Instance
	table.insert(Stack, 1, Active)
end

function Tab.BeginWindow(Id, Options)
	local DockType = Dock.GetDock(Id)
	if DockType ~= nil then
		local X, Y, W, H = Dock.GetBounds(DockType)
		Tab.Begin('Dock.' .. DockType, {X = X, Y = Y, W = W, H = H})

		if Active.ActiveWinId == nil then
			SetActiveWindow(Active, Id)
		end

		Dock.AlterOptions(Id, Options)
	end

	if Active ~= nil then
		return BeginWindow(Active, Id, Options)
	end

	return true
end

function Tab.ApplyWindowDelta(X, Y, W, H)
	ApplyWindowDelta(Active, X, Y, W, H)
end

function Tab.IsActive()
	return Active ~= nil
end

function Tab.IsWindowActive(Id)
	return IsWindowActive(Active, Id)
end

function Tab.EndWindow(Id, Options)
	local Result = true

	if Active ~= nil then
		Result = EndWindow(Active, Id, Options)

		local DockType = Dock.GetDock(Id)
		if DockType ~= nil then
			table.remove(Stack, 1)
			Active = Stack[1]
		end
	end

	return Result
end

function Tab.End(IsObstructed)
	assert(Active ~= nil, "BeginTab has not been called before EndTab!")

	DrawCommands.SetLayer(Active.Layer)
	DrawCommands.Begin({Channel = Active.Channel})

	local X, Y, W, H = GetBounds(Active)
	local Rounding = Active.Rounding

	if type(Active.Rounding) == 'number' then
		Rounding = {Active.Rounding, Active.Rounding, 0, 0}
	end

	local TitleColor = Style.WindowBackgroundColor
	if Active.Focused then
		TitleColor = Style.WindowTitleFocusedColor
	end

	local IsSingleWindow = #Active.Windows == 1

	if IsSingleWindow then
		DrawCommands.Rectangle('fill', X, Y, W, H, TitleColor, Rounding)
	else
		DrawCommands.Rectangle('fill', X, Y, W, H, Active.BgColor, Rounding)
	end
	DrawCommands.Rectangle('line', X, Y, W, H, nil, Rounding)

	local MouseX, MouseY = Mouse.Position()
	Region.Begin(Active.Id .. '.Tab.Title', {
		X = X,
		Y = Y,
		W = W,
		H = H,
		NoBackground = true,
		NoOutline = true,
		IgnoreScroll = true,
		MouseX = MouseX,
		MouseY = MouseY
	})

	local SelectorThisFrame = false
	if IsSingleWindow then
		local Title = Active.Windows[1]
		local TitleW = Style.Font:getWidth(Title.Title)
		DrawCommands.Print(Title.Title, math.floor(X + W * 0.5 - TitleW * 0.5), Y, Style.TextColor, Style.Font)
	else
		local DropdownX = X + W - DropdownSize
		local IsDropdwonHovered = DropdownX < MouseX and MouseX < DropdownX + DropdownSize 
			and Y < MouseY and MouseY < Y + H and not IsObstructed
		local TotalW = 0
		local TextX = X + Active.Border
		for I, V in ipairs(Active.Windows) do
			local TitleW = Style.Font:getWidth(V.Title)
			local BgSize = TitleW + Pad

			if TextX - X >= W then
				TotalW = TotalW + BgSize
				break
			end

			local IsHovered = TextX < MouseX and MouseX < TextX + BgSize 
				and Y <= MouseY and MouseY <= Y + H 
				and not IsObstructed 
				and not IsDropdwonHovered 
				and Region.Contains(MouseX, MouseY)

			if Active.ActiveWinId == V.Id then
				DrawCommands.Rectangle('fill', TextX, Y, BgSize, H, TitleColor)
			elseif IsHovered then
				DrawCommands.Rectangle('fill', TextX, Y, BgSize, H, Style.ButtonHoveredColor)
			end

			if IsHovered and Mouse.IsClicked(1) then
				SetActiveWindow(Active, V.Id)
			end

			DrawCommands.Print(V.Title, math.floor(TextX + BgSize * 0.5 - TitleW * 0.5), Y, Style.TextColor, Style.Font)
			TextX = TextX + BgSize
			TotalW = TotalW + BgSize
		end

		if TotalW > W then
			local Color = IsDropdwonHovered and Style.ComboBoxDropDownColor or Style.ComboBoxDropDownHoveredColor
			DrawCommands.Rectangle(
				'fill',
				DropdownX,
				Y,
				DropdownSize,
				H,
				Color
			)

			local Radius = DropdownSize * 0.45
			DrawCommands.Triangle(
				'fill',
				DropdownX + Radius,
				Y + Radius + Radius * 0.5,
				Radius,
				180
			)

			if IsDropdwonHovered and Mouse.IsClicked(1) then
				SelectorInstance = Active
				SelectorThisFrame = true
			end
		end
	end

	Region.End()
	DrawCommands.End()

	if SelectorInstance ~= nil and SelectorInstance == Active then
		DrawCommands.SetLayer('Dialog')
		DrawCommands.Begin()

		X, Y, W, H = GetSelectorBounds(SelectorInstance)
		Region.Begin(SelectorInstance.Id .. '.Selector', {
			X = X,
			Y = Y,
			W = W,
			H = H,
			Rounding = 0
		})

		local TextY = Y
		local TextH = Style.Font:getHeight()
		for I, V in ipairs(SelectorInstance.Windows) do
			local IsHovered = X < MouseX and MouseX < X + W and TextY < MouseY and MouseY < TextY + TextH

			if IsHovered then
				DrawCommands.Rectangle('fill', X, TextY, W, TextH, Style.ButtonHoveredColor)

				if Mouse.IsClicked(1) then
					SetActiveWindow(SelectorInstance, V.Id)
				end
			end

			DrawCommands.Print(
				V.Title,
				math.floor(X + W * 0.5 - Style.Font:getWidth(V.Title) * 0.5),
				TextY,
				Style.TextColor,
				Style.Font
			)
			TextY = TextY + TextH
		end

		Region.End()
		DrawCommands.End()

		if Mouse.IsClicked(1) and not SelectorThisFrame then
			SelectorInstance = nil
		end
	end

	table.remove(Stack, 1)
	Active = Stack[1]
end

function Tab.Validate()
	local Message = nil

	for I, V in ipairs(Stack) do
		if Message == nil then
			Message = "The following layouts have not had EndLayout called:\n"
		end

		Message = Message .. "'" .. V.Id .. "'\n"
	end

	assert(Message == nil, Message)

	for Id, Instance in pairs(Instances) do
		if Instance.Id == 'Dock.Left'
			or Instance.Id == 'Dock.Right'
			or Instance.Id == 'Dock.Bottom' then
			Active = Instance
			table.insert(Stack, 1, Active)
			Tab.End(false)
		end

		if Instance.Windows ~= nil then
			local Found = false
			for I, V in ipairs(Instance.Windows) do
				if V.Id == Instance.ActiveWinId then
					Found = true
					break
				end
			end

			if not Found then
				Instance.ActiveWinId = nil
			end
		end

		Instance.Windows = {}
	end
end

function Tab.Contains(WinId, X, Y)
	local Instance = WindowToTab[WinId]
	if Instance ~= nil then
		local TabX, TabY, TabW, TabH = GetBounds(Instance)
		return TabX <= X and X <= TabX + TabW and TabY <= Y and Y <= TabY + TabH
	end

	return false
end

function Tab.GetActiveWinId()
	if Active ~= nil then
		return Active.ActiveWinId
	end

	return nil
end

function Tab.HasWindow(WinId)
	if Active ~= nil then
		return Active == WindowToTab[WinId]
	end
	
	return false
end

return Tab
