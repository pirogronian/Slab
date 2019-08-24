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

local Cursor = require(SLAB_PATH .. '.Internal.Core.Cursor')
local DrawCommands = require(SLAB_PATH .. '.Internal.Core.DrawCommands')
local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Sizer = require(SLAB_PATH ..'.Internal.UI.Sizer')
local Style = require(SLAB_PATH .. '.Style')

local Tab = {}

local Instances = {}
local Stack = {}
local Active = nil
local TitlePad = 6
local DropdownSize = 12
local SelectorInstance = nil
local SelectorW = 0

local function GetTextW(Text)
	return Style.Font:getWidth(Text)
end

local function GetTitleH()
	return Style.Font:getHeight()
end

local function HasGrab(Instance)
	if Instance ~= nil then
		local SizerTypes = Sizer.GetTypes()
		return Instance.HoveredSizerType ~= SizerTypes.None and Instance.SizerType ~= SizerTypes.None
	end

	return false
end

local function GetDropdownX(Instance)
	if Instance ~= nil then
		return Instance.X + Instance.W + Instance.Border - DropdownSize
	end

	return 0
end

local function IsDropdownHovered(Instance)
	if Instance ~= nil and Instance.HasDropdown then
		local MouseX, MouseY = Mouse.Position()
		local X = GetDropdownX(Instance)
		local Y = Instance.Y
		return X <= MouseX and MouseX <= X + DropdownSize and Y <= MouseY and MouseY <= Y + GetTitleH()
	end

	return false
end

local function UpdateSize(Instance)
	if Instance ~= nil then
		local SizerTypes = Sizer.GetTypes()
		local X, Y, W, H, SizerType = Sizer.Update({
			X = Instance.X,
			Y = Instance.Y,
			W = Instance.W + Instance.Border,
			H = Instance.H + Instance.Border + GetTitleH(),
			ForcedSizer = Instance.SizerType
		})

		Instance.HoveredSizerType = SizerType
		if Mouse.IsClicked(1) then
			Instance.SizerType = SizerType
		elseif Mouse.IsReleased(1) then
			Instance.SizerType = SizerTypes.None
		end

		if Instance.SizerType ~= SizerTypes.None then
			Instance.X = X
			Instance.Y = Y
			Instance.W = W - Instance.Border
			Instance.H = H - Instance.Border - GetTitleH()
		end
	end
end

local function UpdateTitleBar(Instance)
	local SizerTypes = Sizer.GetTypes()
	if Instance ~= nil and Instance.HoveredSizerType == SizerTypes.None and not IsDropdownHovered(Instance) then
		local MouseX, MouseY = Mouse.Position()

		if Mouse.IsClicked(1) then
			local X = Instance.X
			local Y = Instance.Y

			if X <= MouseX and MouseX <= X + Instance.W + Instance.Border and
				Y <= MouseY and MouseY <= Y + GetTitleH() then
				Instance.IsMoving = true
			end
		elseif Mouse.IsReleased(1) then
			Instance.IsMoving = false
		end

		if Instance.IsMoving then
			local DeltaX, DeltaY = Mouse.GetDelta()
			Instance.X = Instance.X + DeltaX
			Instance.Y = Instance.Y + DeltaY
		end
	end
end

local function GetSelectorBounds(Instance)
	if Instance ~= nil then
		local X = GetDropdownX(Instance)
		local Y = Instance.Y + GetTitleH()
		local W = SelectorW + TitlePad * 2
		local H = #Instance.Titles * Style.Font:getHeight()

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

local function DrawSelector(Instance)
	local NewWinId = nil

	if Instance ~= nil then
		local X, Y, W, H = GetSelectorBounds(Instance)
		local TextH = Style.Font:getHeight()

		local TextX = X + TitlePad
		local TextY = Y

		DrawCommands.SetLayer('Dialog')
		DrawCommands.Begin({Channel = Instance.ChannelIndex})
		Region.Begin(Instance.Id .. '.Tab.Selector.Region', {
			X = X,
			Y = Y,
			W = W,
			H = H,
			Rounding = 0
		})

		local MouseX, MouseY = Mouse.Position()
		MouseX, MouseY = Region.InverseTransform(nil, MouseX, MouseY)

		for I, V in ipairs(Instance.Titles) do
			if X <= MouseX and MouseX <= X + W and TextY <= MouseY and MouseY <= TextY + TextH then
				DrawCommands.Rectangle('fill', X, TextY, W, TextH, Style.TextHoverBgColor)

				if Mouse.IsClicked(1) then
					NewWinId = V.WinId
				end
			end

			DrawCommands.Print(V.Title, math.floor(TextX), math.floor(TextY), Style.TextColor, Style.Font)
			TextY = TextY + Style.Font:getHeight()
		end

		Region.End()
		DrawCommands.End()
	end

	return NewWinId
end

local function DrawDropdown(Instance)
	if Instance ~= nil then
		local Clicked = Mouse.IsClicked(1)
		if Clicked and SelectorInstance == Instance then
			SelectorInstance = nil
		end

		local Color = Style.ComboBoxDropDownColor
		if IsDropdownHovered(Instance) then
			Color = Style.ComboBoxDropDownHoveredColor

			if Clicked then
				SelectorInstance = Instance
			end
		end

		DrawCommands.Rectangle(
			'fill',
			GetDropdownX(Instance),
			Instance.Y,
			DropdownSize,
			GetTitleH(),
			Color
		)

		local Radius = DropdownSize * 0.45
		DrawCommands.Triangle(
			'fill',
			GetDropdownX(Instance) + Radius,
			Instance.Y + Radius + Radius * 0.5,
			Radius,
			180,
			ComboBoxArrowColor
		)
	end
end

local function DrawTitle(Instance, Options, WinId)
	local Result = false

	if Instance ~= nil then
		local IsSelected = Instance.ActiveWinId == WinId
		local Title = Options.Title
		if Title ~= nil and Title ~= "" then
			local X = Instance.X + Instance.CursorX
			local Y = Instance.Y
			local MouseX, MouseY = Mouse.Position()
			local TitleW = GetTextW(Title)
			local Color = Style.WindowTitleFocusedColor

			if IsSelected then
				Instance.ActiveWinTitleSize = GetTextW(Title)
				X = Instance.X
			else
				X = X + Instance.ActiveWinTitleSize + TitlePad * 2
				Instance.CursorX = Instance.CursorX + TitleW + TitlePad * 2
			end

			if X <= MouseX and MouseX <= X + TitleW + TitlePad * 2 and
				Y <= MouseY and MouseY <= Y + GetTitleH() and
				not IsDropdownHovered(Instance) then

				if Mouse.IsClicked(1) then
					Result = true
				end

				if not IsSelected then
					Color = Style.TextHoverBgColor
				end

				IsSelected = true
			end

			if IsSelected then
				DrawCommands.Rectangle('fill', X, Instance.Y, TitleW + TitlePad * 2, GetTitleH(), Color)
			end

			DrawCommands.Print(Title, math.floor(X + TitlePad), math.floor(Y), Style.TextColor, Style.Font)

			table.insert(Instance.Titles, {Title = Title, WinId = WinId})
			SelectorW = math.max(SelectorW, GetTextW(Title))
		end
	end

	return Result
end

local function DrawTitleBar(Instance)
	if Instance ~= nil then
		Region.Begin(Instance.Id .. '.Tab.Region', {
			X = Instance.X,
			Y = Instance.Y,
			W = Instance.W + Instance.Border,
			H = GetTitleH(),
			IgnoreScroll = true,
			Rounding = {Style.WindowRounding, Style.WindowRounding, 0, 0}
		})
	end
end

local function AlterOptions(Instance, Options)
	Options = Options == nil and {} or Options

	if Instance ~= nil then
		Options.Title = ""
		Options.AllowResize = false
		Options.IsMenuBar = false
		Options.AutoSizeWindow = false
		Options.AutoSizeWindowW = false
		Options.AutoSizeWindowH = false

		Options.X = Instance.X
		Options.Y = Instance.Y + GetTitleH()
		Options.W = Instance.W
		Options.H = Instance.H
		Options.Rounding = {0, 0, Style.WindowRounding, Style.WindowRounding}
	end
end

local function SetActiveWindow(Instance, WinId, Options)
	Options = Options == nil and {} or Options

	if Instance ~= nil then
		if Instance.ActiveWinId == nil then
			Instance.X = Options.X == nil and 50.0 or Options.X
			Instance.Y = Options.Y == nil and 50.0 or Options.Y
			Instance.W = Options.W == nil and 200.0 or Options.W
			Instance.H = Options.H == nil and 200.0 or Options.H
			Instance.Border = Options.Border == nil and Style.WindowBorder or Options.Border
			Instance.W = Instance.W + Instance.Border
		elseif Instance.ActiveWinId ~= WinId then
			Options.ResetSize = true
		end

		Instance.ActiveWinId = WinId
	end
end

local function GetInstance(Id)
	if Instances[Id] == nil then
		local Instance = {}
		Instance.Id = Id
		Instance.WinIds = {}
		Instance.ActiveWinId = nil
		Instance.ActiveWinTitleSize = 0
		Instance.X = 0
		Instance.Y = 0
		Instance.W = 0
		Instance.H = 0
		Instance.Border = 0
		Instance.CursorX = 0
		Instance.IsMoving = false
		Instance.SizerType = 0
		Instance.HoveredSizerType = 0
		Instance.ChannelIndex = 0
		Instance.WindowStack = {}
		Instance.Titles = nil
		Instance.HasDropdown = false
		Instances[Id] = Instance
	end

	return Instances[Id]
end

function Tab.Begin(Id, Options)
	Options = Options == nil and {} or Options

	local Instance = GetInstance(Id)
	Instance.CursorX = 0
	Instance.Titles = {}
	SelectorW = 0

	UpdateTitleBar(Instance)
	UpdateSize(Instance)

	DrawCommands.SetLayer('Normal')
	DrawCommands.Begin({Channel = Instance.ChannelIndex})
	DrawTitleBar(Instance)

	Active = Instance
	table.insert(Stack, 1, Instance)
end

function Tab.End()
	assert(Active ~= nil, "Tab.Begin has not been called.")
	
	Region.End()
	DrawCommands.End()

	Active.CursorX = Active.CursorX + Active.ActiveWinTitleSize + TitlePad * 2
	Active.HasDropdown = Active.CursorX > Active.W
	if Active.HasDropdown then
		local LastSelector = SelectorInstance

		DrawCommands.SetLayer('Normal')
		DrawCommands.Begin({Channel = Active.ChannelIndex})
		DrawDropdown(Active)
		DrawCommands.End()

		if LastSelector == Active then
			local NewWinId = DrawSelector(LastSelector)
			if NewWinId ~= nil then
				SetActiveWindow(Active, NewWinId, nil)
			end
		end
	end

	table.remove(Stack, 1)
	Active = Stack[1]
end

function Tab.BeginWindow(WinId, Options)
	if Active ~= nil then
		if Active.ActiveWinId == nil then
			SetActiveWindow(Active, WinId, Options)
		end

		if DrawTitle(Active, Options, WinId) then
			SetActiveWindow(Active, WinId, Options)
		end

		table.insert(Active.WindowStack, 1, WinId)

		if Active.ActiveWinId ~= WinId then
			return false
		end

		AlterOptions(Active, Options)
	end

	return true
end

function Tab.EndWindow(Options)
	if Active ~= nil then
		Options = Options == nil and {} or Options
		Options.ChannelIndex = Options.ChannelIndex == nil and 0 or Options.ChannelIndex

		Active.ChannelIndex = Options.ChannelIndex
	end
end

function Tab.Pop()
	if Active ~= nil then
		local WinId = Active.WindowStack[1]
		table.remove(Active.WindowStack, 1)
		return Active.ActiveWinId == WinId
	end

	return true
end

function Tab.Obstructs(X, Y)
	for K, V in pairs(Instances) do
		if HasGrab(V) then
			return true
		end

		if V.X <= X and X <= V.X + V.W + V.Border and V.Y <= Y and Y <= V.Y + GetTitleH() then
			return true
		end

		if SelectorInstance ~= nil then
			local SX, SY, SW, SH = GetSelectorBounds(SelectorInstance)
			
			if SX <= X and X <= SX + SW and SY <= Y and Y <= SY + SH then
				return true
			end
		end
	end

	return false
end

function Tab.IsActive(WinId)
	if Active ~= nil then
		return Active.ActiveWinId == WinId
	end

	return true
end

function Tab.Validate()
	local Message = nil

	for I, V in ipairs(Stack) do
		if Message == nil then
			Message = "The following Tabs have not had EndTabs called:\n"
		end

		Message = Message .. "'" .. V.Id .. "'\n"
	end

	assert(Message == nil, Message)
end

return Tab
