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

local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local MenuState = require(SLAB_PATH .. ".Internal.UI.MenuState")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Region = require(SLAB_PATH .. ".Internal.UI.Region")
local Sizer = require(SLAB_PATH .. '.Internal.UI.Sizer')
local Stats = require(SLAB_PATH .. ".Internal.Core.Stats")
local Style = require(SLAB_PATH .. ".Style")
local Tab = require(SLAB_PATH .. '.Internal.UI.Tab')
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")

local Window = {}

local Instances = {}
local Stack = {}
local StackLockId = nil
local PendingStack = {}
local ActiveInstance = nil
local CurrentFrameNumber = 0

local function UpdateStackIndex()
	for I = 1, #Stack, 1 do
		Stack[I].StackIndex = #Stack - I + 1
	end
end

local function PushToTop(Instance)
	for I, V in ipairs(Stack) do
		if Instance == V then
			table.remove(Stack, I)
			break
		end
	end

	table.insert(Stack, 1, Instance)

	UpdateStackIndex()
end

local function NewInstance(Id)
	local Instance = {}
	Instance.Id = Id
	Instance.X = 0.0
	Instance.Y = 0.0
	Instance.W = 200.0
	Instance.H = 200.0
	Instance.ContentW = 0.0
	Instance.ContentH = 0.0
	Instance.Title = ""
	Instance.AllowMove = true
	Instance.AllowResize = true
	Instance.AllowFocus = true
	Instance.SizerType = Sizer.GetTypes().None
	Instance.SizerFilter = nil
	Instance.SizeDeltaX = 0.0
	Instance.SizeDeltaY = 0.0
	Instance.HasResized = false
	Instance.DeltaContentW = 0.0
	Instance.DeltaContentH = 0.0
	Instance.BackgroundColor = Style.WindowBackgroundColor
	Instance.Border = 4.0
	Instance.Children = {}
	Instance.LastItem = nil
	Instance.HotItem = nil
	Instance.ContextHotItem = nil
	Instance.LastVisibleTime = 0.0
	Instance.Items = {}
	Instance.Layer = 'Normal'
	Instance.StackIndex = 0
	Instance.CanObstruct = true
	Instance.FrameNumber = 0
	Instance.LastCursorX = 0
	Instance.LastCursorY = 0
	Instance.StatHandle = nil
	return Instance
end

local function GetInstance(Id)
	if Id == nil then
		return ActiveInstance
	end

	for K, V in pairs(Instances) do
		if V.Id == Id then
			return V
		end
	end
	local Instance = NewInstance(Id)
	table.insert(Instances, Instance)
	return Instance
end

local function Contains(Instance, X, Y)
	if Instance ~= nil then
		local OffsetY = 0.0
		if Instance.Title ~= "" then
			OffsetY = Style.Font:getHeight()
		end
		local WinX, WinY = Region.GetPosition(Instance.Id)
		return WinX <= X and X <= WinX + Instance.W and WinY - OffsetY <= Y and Y <= WinY + Instance.H
	end
	return false
end

local function UpdateSize(Instance, IsObstructed)
	if Instance ~= nil and Instance.AllowResize then
		if Instance.SizerType == Sizer.GetTypes().None and IsObstructed then
			return
		end

		local X = Instance.X
		local Y = Instance.Y
		local W = Instance.W
		local H = Instance.H

		if Instance.Title ~= "" then
			local Offset = Style.Font:getHeight()
			Y = Y - Offset
			H = H + Offset
		end

		local NewX, NewY, NewW, NewH, NewSizerType = Sizer.Update({
			X = X,
			Y = Y,
			W = W,
			H = H,
			Filter = Instance.SizerFilter,
			ForcedSizer = Instance.SizerType
		})
		local SizerType = Sizer.GetTypes()

		if Mouse.IsClicked(1) then
			Instance.SizerType = NewSizerType
		elseif Mouse.IsReleased(1) then
			Instance.SizerType = SizerType.None
		end

		if Instance.SizerType ~= SizerType.None then
			if DeltaX ~= 0.0 or DeltaY ~= 0.0 then
				Instance.HasResized = true
				Instance.DeltaContentW = 0.0
				Instance.DeltaContentH = 0.0
			end

			Instance.SizeDeltaX = Instance.SizeDeltaX + (NewW - W)
			Instance.SizeDeltaY = Instance.SizeDeltaY + (NewH - H)
		end
	end
end

function Window.Top()
	return ActiveInstance
end

function Window.IsActive()
	if ActiveInstance ~= nil and ActiveInstance.Id ~= 'Global' then
		return Tab.IsActive(ActiveInstance.Id)
	end

	return false
end

function Window.SetFrameNumber(FrameNumber)
	CurrentFrameNumber = FrameNumber
end

function Window.IsObstructed(X, Y, SkipScrollCheck)
	if Region.IsScrolling() then
		return true
	end

	if Tab.Obstructs(X, Y) then
		return true
	end

	if ActiveInstance ~= nil then
		local FoundStackLock = false

		for I, V in ipairs(Stack) do
			if V.Id == StackLockId then
				FoundStackLock = true
			elseif FoundStackLock then
				return true
			end

			if Contains(V, X, Y) and V.CanObstruct then
				if ActiveInstance == V then
					if not SkipScrollCheck and Region.IsHoverScrollBar(ActiveInstance.Id) then
						return true
					end

					return false
				else
					return true
				end
			end
		end
	end

	return false
end

function Window.IsObstructedAtMouse()
	local X, Y = Mouse.Position()
	return Window.IsObstructed(X, Y)
end

function Window.Reset()
	PendingStack = {}
	ActiveInstance = GetInstance('Global')
	ActiveInstance.W = love.graphics.getWidth()
	ActiveInstance.H = love.graphics.getHeight()
	ActiveInstance.Border = 0.0
	table.insert(PendingStack, 1, ActiveInstance)
end

function Window.Begin(Id, Options)
	if  not Tab.BeginWindow(Id, Options) then
		return
	end

	local StatHandle = Stats.Begin('Window', 'Slab')

	Options = Options == nil and {} or Options
	Options.X = Options.X == nil and 50.0 or Options.X
	Options.Y = Options.Y == nil and 50.0 or Options.Y
	Options.W = Options.W == nil and 200.0 or Options.W
	Options.H = Options.H == nil and 200.0 or Options.H
	Options.ContentW = Options.ContentW == nil and 0.0 or Options.ContentW
	Options.ContentH = Options.ContentH == nil and 0.0 or Options.ContentH
	Options.BgColor = Options.BgColor == nil and Style.WindowBackgroundColor or Options.BgColor
	Options.Title = Options.Title == nil and "" or Options.Title
	Options.AllowMove = Options.AllowMove == nil and true or Options.AllowMove
	Options.AllowResize = Options.AllowResize == nil and true or Options.AllowResize
	Options.AllowFocus = Options.AllowFocus == nil and true or Options.AllowFocus
	Options.Border = Options.Border == nil and Style.WindowBorder or Options.Border
	Options.NoOutline = Options.NoOutline == nil and false or Options.NoOutline
	Options.IsMenuBar = Options.IsMenuBar == nil and false or Options.IsMenuBar
	Options.AutoSizeWindow = Options.AutoSizeWindow == nil and true or Options.AutoSizeWindow
	Options.AutoSizeWindowW = Options.AutoSizeWindowW == nil and Options.AutoSizeWindow or Options.AutoSizeWindowW
	Options.AutoSizeWindowH = Options.AutoSizeWindowH == nil and Options.AutoSizeWindow or Options.AutoSizeWindowH
	Options.AutoSizeContent = Options.AutoSizeContent == nil and true or Options.AutoSizeContent
	Options.Layer = Options.Layer == nil and 'Normal' or Options.Layer
	Options.ResetPosition = Options.ResetPosition == nil and false or Options.ResetPosition
	Options.ResetSize = Options.ResetSize == nil and Options.AutoSizeWindow or Options.ResetSize
	Options.ResetContent = Options.ResetContent == nil and Options.AutoSizeContent or Options.ResetContent
	Options.ResetLayout = Options.ResetLayout == nil and false or Options.ResetLayout
	Options.SizerFilter = Options.SizerFilter == nil and {} or Options.SizerFilter
	Options.CanObstruct = Options.CanObstruct == nil and true or Options.CanObstruct
	Options.Rounding = Options.Rounding == nil and Style.WindowRounding or Options.Rounding

	local TitleRounding = {Options.Rounding, Options.Rounding, 0, 0}
	local BodyRounding = {0, 0, Options.Rounding, Options.Rounding}

	if type(Options.Rounding) == 'table' then
		TitleRounding = Options.Rounding
		BodyRounding = Options.Rounding
	elseif Options.Title == "" then
		BodyRounding = Options.Rounding
	end

	local Instance = GetInstance(Id)
	table.insert(PendingStack, 1, Instance)

	if ActiveInstance ~= nil then
		ActiveInstance.Children[Id] = Instance
	end

	ActiveInstance = Instance
	if Options.AutoSizeWindowW then
		Options.W = 0.0
	end

	if Options.AutoSizeWindowH then
		Options.H = 0.0
	end

	if Options.ResetPosition or Options.ResetLayout then
		ActiveInstance.TitleDeltaX = 0.0
		ActiveInstance.TitleDeltaY = 0.0
	end

	if ActiveInstance.AutoSizeWindow ~= Options.AutoSizeWindow and Options.AutoSizeWindow then
		Options.ResetSize = true
	end

	if ActiveInstance.Border ~= Options.Border then
		Options.ResetSize = true
	end

	ActiveInstance.X = Options.X
	ActiveInstance.Y = Options.Y
	ActiveInstance.W = math.max(ActiveInstance.SizeDeltaX + Options.W + Options.Border, Options.Border)
	ActiveInstance.H = math.max(ActiveInstance.SizeDeltaY + Options.H + Options.Border, Options.Border)
	ActiveInstance.ContentW = Options.ContentW
	ActiveInstance.ContentH = Options.ContentH
	ActiveInstance.BackgroundColor = Options.BgColor
	ActiveInstance.Title = Options.Title
	ActiveInstance.AllowMove = Options.AllowMove
	ActiveInstance.AllowResize = Options.AllowResize and not Options.AutoSizeWindow
	ActiveInstance.AllowFocus = Options.AllowFocus
	ActiveInstance.Border = Options.Border
	ActiveInstance.IsMenuBar = Options.IsMenuBar
	ActiveInstance.AutoSizeWindow = Options.AutoSizeWindow
	ActiveInstance.AutoSizeWindowW = Options.AutoSizeWindowW
	ActiveInstance.AutoSizeWindowH = Options.AutoSizeWindowH
	ActiveInstance.AutoSizeContent = Options.AutoSizeContent
	ActiveInstance.Layer = Options.Layer
	ActiveInstance.HotItem = nil
	ActiveInstance.LastVisibleTime = love.timer.getTime()
	ActiveInstance.SizerFilter = Options.SizerFilter
	ActiveInstance.HasResized = false
	ActiveInstance.CanObstruct = Options.CanObstruct
	ActiveInstance.FrameNumber = CurrentFrameNumber
	ActiveInstance.StatHandle = StatHandle

	if ActiveInstance.StackIndex == 0 then
		table.insert(Stack, 1, ActiveInstance)
		UpdateStackIndex()
	end

	if ActiveInstance.AutoSizeContent then
		ActiveInstance.ContentW = math.max(Options.ContentW, ActiveInstance.DeltaContentW)
		ActiveInstance.ContentH = math.max(Options.ContentH, ActiveInstance.DeltaContentH)
	end

	local OffsetY = 0.0
	if ActiveInstance.Title ~= "" then
		OffsetY = Style.Font:getHeight()
		ActiveInstance.Y = ActiveInstance.Y + OffsetY

		if Options.AutoSizeWindow then
			local TitleW = Style.Font:getWidth(ActiveInstance.Title) + ActiveInstance.Border * 2.0
			ActiveInstance.W = math.max(ActiveInstance.W, TitleW)
		end
	end

	local MouseX, MouseY = Mouse.Position()
	local IsObstructed = Window.IsObstructed(MouseX, MouseY, true)
	if ActiveInstance.AllowFocus and Mouse.IsClicked(1) and not IsObstructed then
		PushToTop(ActiveInstance)
	end

	UpdateSize(ActiveInstance, IsObstructed)

	local WinX, WinY = ActiveInstance.X, ActiveInstance.Y

	DrawCommands.SetLayer(ActiveInstance.Layer)
	DrawCommands.Begin({Channel = ActiveInstance.StackIndex})
	if ActiveInstance.Title ~= "" then
		local TitleColor = ActiveInstance.BackgroundColor
		if ActiveInstance == Stack[1] then
			TitleColor = Style.WindowTitleFocusedColor
		end

		Region.Begin(ActiveInstance.Id .. '_Title', {
			X = ActiveInstance.X,
			Y = ActiveInstance.Y - OffsetY,
			W = ActiveInstance.W,
			H = OffsetY,
			BgColor = TitleColor,
			Rounding = TitleRounding,
			IgnoreScroll = true,
			CanMove = Instance.AllowMove,
			IsObstructed = IsObstructed
		})

		local X, Y, W, H = Region.GetBounds()
		local TitleX = math.floor(X + W * 0.5 - Style.Font:getWidth(ActiveInstance.Title) * 0.5)
		WinX, WinY = X, Y
		DrawCommands.Print(ActiveInstance.Title, TitleX, Y, Style.TextColor, Style.Font)

		if Region.IsMouseHovered() and Mouse.IsClicked(1) and not Window.IsObstructedAtMouse() then
			if ActiveInstance.AllowFocus then
				PushToTop(ActiveInstance)
			end
		end

		Region.End()
	end

	WinY = WinY + OffsetY

	Region.Begin(ActiveInstance.Id, {
		X = WinX,
		Y = WinY,
		W = ActiveInstance.W,
		H = ActiveInstance.H,
		ContentW = ActiveInstance.ContentW + ActiveInstance.Border,
		ContentH = ActiveInstance.ContentH + ActiveInstance.Border,
		BgColor = ActiveInstance.BackgroundColor,
		IsObstructed = IsObstructed,
		MouseX = MouseX,
		MouseY = MouseY,
		ResetContent = ActiveInstance.HasResized,
		Rounding = BodyRounding,
		NoOutline = Options.NoOutline
	})

	ActiveInstance.LastCursorX, ActiveInstance.LastCursorY = Cursor.GetPosition()
	Cursor.SetPosition(WinX + ActiveInstance.Border, WinY + ActiveInstance.Border)
	Cursor.SetAnchor(WinX + ActiveInstance.Border, WinY + ActiveInstance.Border)

	if Options.ResetSize then
		ActiveInstance.SizeDeltaX = 0.0
		ActiveInstance.SizeDeltaY = 0.0
	end

	if Options.ResetContent or Options.ResetLayout then
		ActiveInstance.DeltaContentW = 0.0
		ActiveInstance.DeltaContentH = 0.0
	end
end

function Window.End()
	if not Tab.Pop() then
		return
	end

	if ActiveInstance ~= nil then
		local Handle = ActiveInstance.StatHandle
		Region.End()
		DrawCommands.End()
		table.remove(PendingStack, 1)

		Tab.EndWindow({ChannelIndex = ActiveInstance.StackIndex})

		Cursor.SetPosition(ActiveInstance.LastCursorX, ActiveInstance.LastCursorY)
		ActiveInstance = nil
		if #PendingStack > 0 then
			ActiveInstance = PendingStack[1]
			local X, Y = Region.GetPosition()
			Cursor.SetAnchor(X + ActiveInstance.Border, Y + ActiveInstance.Border)
			DrawCommands.SetLayer(ActiveInstance.Layer)
			Region.ApplyScissor()
		end

		Stats.End(Handle)
	end
end

function Window.GetMousePosition()
	local X, Y = Mouse.Position()
	if ActiveInstance ~= nil then
		X, Y = Region.InverseTransform(ActiveInstance.Id, X, Y)
	end
	return X, Y
end

function Window.GetWidth()
	if ActiveInstance ~= nil then
		return ActiveInstance.W
	end
	return 0.0
end

function Window.GetHeight()
	if ActiveInstance ~= nil then
		return ActiveInstance.H
	end
	return 0.0
end

function Window.GetBorder()
	if ActiveInstance ~= nil then
		return ActiveInstance.Border
	end
	return 0.0
end

function Window.GetBounds(IgnoreTitleBar)
	if ActiveInstance ~= nil then
		IgnoreTitleBar = IgnoreTitleBar == nil and false or IgnoreTitleBar
		local OffsetY = (ActiveInstance.Title ~= "" and not IgnoreTitleBar) and Style.Font:getHeight() or 0.0
		local X, Y = Region.GetPosition()
		return X, Y - OffsetY, ActiveInstance.W, ActiveInstance.H + OffsetY
	end
	return 0.0, 0.0, 0.0, 0.0
end

function Window.GetPosition(IncludeTitle)
	IncludeTitle = IncludeTitle == nil and true or IncludeTitle

	if ActiveInstance ~= nil then
		local X, Y = Region.GetPosition()
		if ActiveInstance.Title ~= "" and IncludeTitle then
			Y = Y - Style.Font:getHeight()
		end
		return X, Y
	end
	return 0.0, 0.0
end

function Window.GetSize()
	if ActiveInstance ~= nil then
		return ActiveInstance.W, ActiveInstance.H
	end
	return 0.0, 0.0
end

function Window.GetContentSize()
	if ActiveInstance ~= nil then
		return ActiveInstance.ContentW, ActiveInstance.ContentH
	end
	return 0.0, 0.0
end

--[[
	This function is used to help other controls retrieve the available real estate needed to expand their
	bounds without expanding the bounds of the window by removing borders.
--]]
function Window.GetBorderlessSize()
	local W, H = 0.0, 0.0

	if ActiveInstance ~= nil then
		W = math.max(ActiveInstance.W, ActiveInstance.ContentW)
		H = math.max(ActiveInstance.H, ActiveInstance.ContentH)

		W = math.max(0.0, W - ActiveInstance.Border * 2.0)
		H = math.max(0.0, H - ActiveInstance.Border * 2.0)
	end

	return W, H
end

function Window.IsMenuBar()
	if ActiveInstance ~= nil then
		return ActiveInstance.IsMenuBar
	end
	return false
end

function Window.GetId()
	if ActiveInstance ~= nil then
		return ActiveInstance.Id
	end
	return ''
end

function Window.GetWindowAtMouse()
	local X, Y = Mouse.Position()
	local Instance = nil
	for I, V in ipairs(Instances) do
		local Child = GetHoveredInstance(V, X, Y)
		if Child ~= nil then
			Instance = Child
		end
	end
	return Instance == nil and 'None' or Instance.Id
end

function Window.AddItem(X, Y, W, H, Id)
	if ActiveInstance ~= nil then
		ActiveInstance.LastItem = Id
		if Region.IsActive(ActiveInstance.Id) then
			local WinX, WinY = Region.GetPosition()
			if ActiveInstance.AutoSizeWindowW then
				ActiveInstance.SizeDeltaX = math.max(ActiveInstance.SizeDeltaX, X + W - WinX)
			end

			if ActiveInstance.AutoSizeWindowH then
				ActiveInstance.SizeDeltaY = math.max(ActiveInstance.SizeDeltaY, Y + H - WinY)
			end

			if ActiveInstance.AutoSizeContent then
				ActiveInstance.DeltaContentW = math.max(ActiveInstance.DeltaContentW, X + W - WinX)
				ActiveInstance.DeltaContentH = math.max(ActiveInstance.DeltaContentH, Y + H - WinY)
			end
		else
			Region.AddItem(X, Y, W, H)
		end
	end
end

function Window.WheelMoved(X, Y)
	Region.WheelMoved(X, Y)
end

function Window.TransformPoint(X, Y)
	if ActiveInstance ~= nil then
		return Region.Transform(ActiveInstance.Id, X, Y)
	end
	return 0.0, 0.0
end

function Window.ResetContentSize()
	if ActiveInstance ~= nil then
		ActiveInstance.DeltaContentW = 0.0
		ActiveInstance.DeltaContentH = 0.0
	end
end

function Window.SetHotItem(HotItem)
	if ActiveInstance ~= nil then
		ActiveInstance.HotItem = HotItem
	end
end

function Window.SetContextHotItem(HotItem)
	if ActiveInstance ~= nil then
		ActiveInstance.ContextHotItem = HotItem
	end
end

function Window.GetHotItem()
	if ActiveInstance ~= nil then
		return ActiveInstance.HotItem
	end
	return nil
end

function Window.IsItemHot()
	if ActiveInstance ~= nil and ActiveInstance.LastItem ~= nil then
		return ActiveInstance.HotItem == ActiveInstance.LastItem
	end
	return false
end

function Window.GetContextHotItem()
	if ActiveInstance ~= nil then
		return ActiveInstance.ContextHotItem
	end
	return nil
end

function Window.IsMouseHovered()
	if ActiveInstance ~= nil then
		local X, Y = Mouse.Position()
		return Contains(ActiveInstance, X, Y)
	end
	return false
end

function Window.GetItemId(Id)
	if ActiveInstance ~= nil then
		if ActiveInstance.Items[Id] == nil then
			ActiveInstance.Items[Id] = ActiveInstance.Id .. '.' .. Id
		end
		return ActiveInstance.Items[Id]
	end
	return nil
end

function Window.GetLastItem()
	if ActiveInstance ~= nil then
		return ActiveInstance.LastItem
	end
	return nil
end

function Window.Validate()
	if #PendingStack > 1 then
		assert(false, "EndWindow was not called for: " .. PendingStack[1].Id)
	end

	local ShouldUpdate = false
	for I = #Stack, 1, -1 do
		if Stack[I].FrameNumber ~= CurrentFrameNumber then
			Stack[I].StackIndex = 0
			table.remove(Stack, I)
			ShouldUpdate = true
		end
	end

	if ShouldUpdate then
		UpdateStackIndex()
	end
end

function Window.HasResized()
	if ActiveInstance ~= nil then
		return ActiveInstance.HasResized
	end
	return false
end

function Window.SetStackLock(Id)
	StackLockId = Id
end

function Window.PushToTop(Id)
	local Instance = GetInstance(Id)

	if Instance ~= nil then
		PushToTop(Instance)
	end
end

function Window.GetLastVisibleTime(Id)
	local Instance = ActiveInstance

	if Id ~= nil then
		for I, V in ipairs(Instances) do
			if V.Id == Id then
				Instance = V
				break
			end
		end
	end

	if Instance ~= nil then
		return Instance.LastVisibleTime
	end

	return 0.0
end

function Window.GetLayer()
	if ActiveInstance ~= nil then
		return ActiveInstance.Layer
	end
	return 'Normal'
end

function Window.GetInstanceIds()
	local Result = {}

	for I, V in ipairs(Instances) do
		table.insert(Result, V.Id)
	end

	return Result
end

function Window.GetInstanceInfo(Id)
	local Result = {}

	local Instance = nil
	for I, V in ipairs(Instances) do
		if V.Id == Id then
			Instance = V
			break
		end
	end

	if Instance ~= nil then
		table.insert(Result, "Title: " .. Instance.Title)
		table.insert(Result, "X: " .. Instance.X)
		table.insert(Result, "Y: " .. Instance.Y)
		table.insert(Result, "W: " .. Instance.W)
		table.insert(Result, "H: " .. Instance.H)
		table.insert(Result, "ContentW: " .. Instance.ContentW)
		table.insert(Result, "ContentH: " .. Instance.ContentH)
		table.insert(Result, "SizeDeltaX: " .. Instance.SizeDeltaX)
		table.insert(Result, "SizeDeltaY: " .. Instance.SizeDeltaY)
		table.insert(Result, "DeltaContentW: " .. Instance.DeltaContentW)
		table.insert(Result, "DeltaContentH: " .. Instance.DeltaContentH)
		table.insert(Result, "Border: " .. Instance.Border)
		table.insert(Result, "Layer: " .. Instance.Layer)
		table.insert(Result, "Stack Index: " .. Instance.StackIndex)
		table.insert(Result, "AutoSizeWindow: " .. tostring(Instance.AutoSizeWindow))
		table.insert(Result, "AutoSizeContent: " .. tostring(Instance.AutoSizeContent))
	end

	return Result
end

function Window.GetStackDebug()
	local Result = {}

	for I, V in ipairs(Stack) do
		Result[I] = tostring(V.StackIndex) .. ": " .. V.Id

		if V.Id == StackLockId then
			Result[I] = Result[I] .. " (Locked)"
		end
	end

	return Result
end

function Window.IsAutoSize()
	if ActiveInstance ~= nil then
		return ActiveInstance.AutoSizeWindowW or ActiveInstance.AutoSizeWindowH
	end

	return false
end

return Window
