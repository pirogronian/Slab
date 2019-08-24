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

local Mouse = require(SLAB_PATH .. '.Internal.Input.Mouse')
local Region = require(SLAB_PATH .. '.Internal.UI.Region')
local Style = require(SLAB_PATH .. '.Style')

local Sizer = {}

local SizerType =
{
	None = 0,
	N = 1,
	E = 2,
	S = 3,
	W = 4,
	NE = 5,
	SE = 6,
	SW = 7,
	NW = 8
}

local function IsSizerEnabled(Filter, Sizer)
	if Filter ~= nil then
		if #Filter > 0 then
			for I, V in ipairs(Filter) do
				if V == Sizer then
					return true
				end
			end
			return false
		end
		return true
	end
	return false
end

function Sizer.GetTypes()
	return SizerType
end

function Sizer.Update(Options)
	Options = Options == nil and {} or Options
	Options.X = Options.X == nil and 0 or Options.X
	Options.Y = Options.Y == nil and 0 or Options.Y
	Options.W = Options.W == nil and 0 or Options.W
	Options.H = Options.H == nil and 0 or Options.H
	Options.Filter = Options.Filter == nil and {} or Options.Filter
	Options.Border = Options.Border == nil and Style.WindowBorder or Options.Border
	Options.ForcedSizer = Options.ForcedSizer == nil and Sizer.None or Options.ForcedSizer

	if Region.IsHoverScrollBar() then
		return 0, 0, SizerType.None
	end

	local X, Y = Options.X, Options.Y
	local W, H = Options.W, Options.H
	local Filter = Options.Filter
	local Border = Options.Border
	local DeltaX, DeltaY = Mouse.GetDelta()
	local MouseX, MouseY = Mouse.Position()
	local NewSizerType = Options.ForcedSizer
	local ScrollPad = Region.GetScrollPad()

	if NewSizerType == SizerType.None then
		if X <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + H then
			if X <= MouseX and MouseX <= X + ScrollPad and Y <= MouseY and MouseY <= Y + ScrollPad and IsSizerEnabled(Filter, "NW") then
				Mouse.SetCursor('sizenwse')
				NewSizerType = SizerType.NW
			elseif X + W - ScrollPad <= MouseX and MouseX <= X + W and Y <= MouseY and MouseY <= Y + ScrollPad and IsSizerEnabled(Filter, "NE") then
				Mouse.SetCursor('sizenesw')
				NewSizerType = SizerType.NE
			elseif X + W - ScrollPad <= MouseX and MouseX <= X + W and Y + H - ScrollPad <= MouseY and MouseY <= Y + H and IsSizerEnabled(Filter, "SE") then
				Mouse.SetCursor('sizenwse')
				NewSizerType = SizerType.SE
			elseif X <= MouseX and MouseX <= X + ScrollPad and Y + H - ScrollPad <= MouseY and MouseY <= Y + H and IsSizerEnabled(Filter, "SW") then
				Mouse.SetCursor('sizenesw')
				NewSizerType = SizerType.SW
			elseif X <= MouseX and MouseX <= X + ScrollPad and IsSizerEnabled(Filter, "W") then
				Mouse.SetCursor('sizewe')
				NewSizerType = SizerType.W
			elseif X + W - ScrollPad <= MouseX and MouseX <= X + W and IsSizerEnabled(Filter, "E") then
				Mouse.SetCursor('sizewe')
				NewSizerType = SizerType.E
			elseif Y <= MouseY and MouseY <= Y + ScrollPad and IsSizerEnabled(Filter, "N") then
				Mouse.SetCursor('sizens')
				NewSizerType = SizerType.N
			elseif Y + H - ScrollPad <= MouseY and MouseY <= Y + H and IsSizerEnabled(Filter, "S") then
				Mouse.SetCursor('sizens')
				NewSizerType = SizerType.S
			end
		end
	end

	if NewSizerType ~= SizerType.None then
		if W <= Border then
			if (NewSizerType == SizerType.W or
				NewSizerType == SizerType.NW or
				NewSizerType == SizerType.SW) and
				DeltaX > 0.0 then
				DeltaX = 0.0
			end

			if (NewSizerType == SizerType.E or
				NewSizerType == SizerType.NE or
				NewSizerType == SizerType.SE) and
				DeltaX < 0.0 then
				DeltaX = 0.0
			end
		end

		if H <= Border then
			if (NewSizerType == SizerType.N or
				NewSizerType == SizerType.NW or
				NewSizerType == SizerType.NE) and
				DeltaY > 0.0 then
				DeltaY = 0.0
			end

			if (NewSizerType == SizerType.S or
				NewSizerType == SizerType.SE or
				NewSizerType == SizerType.SW) and
				DeltaY < 0.0 then
				DeltaY = 0.0
			end
		end

		if NewSizerType == SizerType.N then
			Mouse.SetCursor('sizens')
			Y = Y + DeltaY
			H = H - DeltaY
		elseif NewSizerType == SizerType.E then
			Mouse.SetCursor('sizewe')
			W = W + DeltaX
		elseif NewSizerType == SizerType.S then
			Mouse.SetCursor('sizens')
			H = H + DeltaY
		elseif NewSizerType == SizerType.W then
			Mouse.SetCursor('sizewe')
			X = X + DeltaX
			W = W - DeltaX
		elseif NewSizerType == SizerType.NW then
			Mouse.SetCursor('sizenwse')
			X = X + DeltaX
			W = W - DeltaX
			Y = Y + DeltaY
			H = H - DeltaY
		elseif NewSizerType == SizerType.NE then
			Mouse.SetCursor('sizenesw')
			W = W + DeltaX
			Y = Y + DeltaY
			H = H - DeltaY
		elseif NewSizerType == SizerType.SE then
			Mouse.SetCursor('sizenwse')
			W = W + DeltaX
			H = H + DeltaY
		elseif NewSizerType == SizerType.SW then
			Mouse.SetCursor('sizenesw')
			X = X + DeltaX
			W = W - DeltaX
			H = H + DeltaY
		end
	end

	return X, Y, W, H, NewSizerType
end

return Sizer
