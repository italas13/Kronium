local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};
    HudRegistry = {};

    -- [ MODERN LIGHT-BLUE & DARK PREMIUM THEME ]
    FontColor = Color3.fromRGB(245, 245, 250);
    MainColor = Color3.fromRGB(24, 24, 29);
    BackgroundColor = Color3.fromRGB(16, 16, 20);
    AccentColor = Color3.fromRGB(75, 175, 255); -- Light Blue Theme
    OutlineColor = Color3.fromRGB(45, 45, 55);
    RiskColor = Color3.fromRGB(255, 75, 75),
    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.GothamMedium, -- Upgraded typography

    OpenedFrames = {};
    DependencyBoxes = {};
    Signals = {};
    ScreenGui = ScreenGui;
};

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0
        Hue = Hue + (1 / 400);
        if Hue > 1 then Hue = 0; end;
        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();
    for i = 1, #PlayerList do PlayerList[i] = PlayerList[i].Name; end;
    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);
    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();
    for i = 1, #TeamList do TeamList[i] = TeamList[i].Name; end;
    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then return; end;
    if not Library.NotifyOnError then return f(...); end;
    local success, event = pcall(f, ...);
    if not success then
        local _, i = event:find(":%d+: ");
        if not i then return Library:Notify(event); end;
        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;
    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;
    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;
    return _Instance;
end;

-- [ ANIMATION & ROUNDING UTILITIES ]
function Library:Round(Inst, Radius)
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, Radius or 4)
    Corner.Parent = Inst
    return Corner
end

function Library:Stroke(Inst, Color, Thickness)
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color or Library.OutlineColor
    Stroke.Thickness = Thickness or 1
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Parent = Inst
    return Stroke
end

function Library:CreateShadow(Parent, Size, Opacity)
    local Shadow = Instance.new("ImageLabel")
    Shadow.Name = "DropShadow"
    Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    Shadow.BackgroundTransparency = 1
    Shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    Shadow.Size = UDim2.new(1, Size or 34, 1, Size or 34)
    Shadow.ZIndex = Parent.ZIndex - 1
    Shadow.Image = "rbxassetid://5554236805"
    Shadow.ImageColor3 = Color3.new(0, 0, 0)
    Shadow.ImageTransparency = Opacity or 0.35
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    Shadow.Parent = Parent
    return Shadow
end

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;
    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Round;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 13;
        TextStrokeTransparency = 0;
        RichText = true; -- Fixes the font tag color issue
    });

    Library:ApplyTextStroke(_Instance);
    Library:AddToRegistry(_Instance, { TextColor3 = 'FontColor'; }, IsHud);
    return Library:Create(_Instance, Properties);
end;

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;
    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            );
            if ObjPos.Y > (Cutoff or 40) then return; end;
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Instance.Position = UDim2.new(
                    0,
                    Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                    0,
                    Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                );
                RenderStepped:Wait();
            end;
        end;
    end)
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 13);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        Size = UDim2.fromOffset(X + 8, Y + 6),
        ZIndex = 100,
        Parent = Library.ScreenGui,
        Visible = false,
    })
    
    Library:Round(Tooltip, 4)
    local Stroke = Library:Stroke(Tooltip, Library.OutlineColor, 1)
    Library:CreateShadow(Tooltip, 20, 0.45)

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(4, 2),
        Size = UDim2.fromOffset(X, Y);
        TextSize = 13;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,
        Parent = Tooltip;
    });

    Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'MainColor'; });
    Library:AddToRegistry(Stroke, { Color = 'OutlineColor'; });
    Library:AddToRegistry(Label, { TextColor3 = 'FontColor' });

    local IsHovering = false
    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        IsHovering = true
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true
        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];
        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];
        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
function Library:GetLighterColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, math.clamp(V * 1.5, 0, 1));
end;

Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = { Instance = Instance; Properties = Properties; Idx = Idx; };
    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;
    if IsHud then table.insert(Library.HudRegistry, Data); end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];
    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then table.remove(Library.Registry, Idx); end;
        end;
        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then table.remove(Library.HudRegistry, Idx); end;
        end;
        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end
    if Library.OnUnload then Library.OnUnload() end
    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);
            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            Size = UDim2.new(0, 28, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });
        Library:Round(DisplayFrame, 3)
        local DisplayStroke = Library:Stroke(DisplayFrame, Library:GetDarkerColor(ColorPicker.Value), 1)

        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });
        Library:Round(CheckerFrame, 3)

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });
        Library:Round(PickerFrameOuter, 6)
        Library:CreateShadow(PickerFrameOuter, 30, 0.4)

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });
        Library:Round(PickerFrameInner, 6)
        local PickerStroke = Library:Stroke(PickerFrameInner, Library.OutlineColor, 1)

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });
        Library:Round(Highlight, 2)

        local SatVibMapOuter = Library:Create('Frame', {
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });
        Library:Round(SatVibMapInner, 4)
        local SatMapStroke = Library:Stroke(SatVibMapInner, Library.OutlineColor, 1)

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });
        Library:Round(SatVibMap, 4)

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });
        Library:Round(HueSelectorOuter, 4)
        local HueStroke = Library:Stroke(HueSelectorOuter, Library.OutlineColor, 1)

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });
        Library:Round(HueSelectorInner, 4)

        local HueCursor = Library:Create('Frame', { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });
        Library:Round(HueBoxInner, 4)
        local HueBoxStroke = Library:Stroke(HueBoxInner, Library.OutlineColor, 1)

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(150, 150, 150);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 13;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });
        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });
        local RgbBoxStroke = Library:Stroke(RgbBoxBase.Frame, Library.OutlineColor, 1)

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create('Frame', {
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });
            Library:Round(TransparencyBoxInner, 4)
            local TransStroke = Library:Stroke(TransparencyBoxInner, Library.OutlineColor, 1)
            Library:AddToRegistry(TransStroke, { Color = 'OutlineColor' });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });

            TransparencyCursor = Library:Create('Frame', { 
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                Size = UDim2.new(0, 2, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 13;
            Text = ColorPicker.Title,
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });

        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                ZIndex = 14,
                Visible = false,
                Parent = ScreenGui
            })
            Library:Round(ContextMenu.Container, 6)
            Library:CreateShadow(ContextMenu.Container, 20, 0.4)

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            });
            Library:Round(ContextMenu.Inner, 6)
            local CtxStroke = Library:Stroke(ContextMenu.Inner, Library.OutlineColor, 1)
            Library:AddToRegistry(CtxStroke, { Color = 'OutlineColor' })

            Library:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });

            Library:Create('UIPadding', {
                Name = 'Padding',
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then menuWidth = math.max(menuWidth, label.TextBounds.X) end
                end
                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, { BackgroundColor3 = 'BackgroundColor'; });

            function ContextMenu:Show() self.Container.Visible = true end
            function ContextMenu:Hide() self.Container.Visible = false end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then Callback = function() end end
                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });
                Library:OnHighlight(Button, Button, 
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );
                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)
            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then return Library:Notify('You have not copied a color!', 2) end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)
            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)
            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)
        end

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; });
        Library:AddToRegistry(PickerStroke, { Color = 'OutlineColor' })
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; });
        Library:AddToRegistry(SatMapStroke, { Color = 'OutlineColor' })
        Library:AddToRegistry(HueSelectorOuter, { BackgroundColor3 = 'MainColor'; });
        Library:AddToRegistry(HueStroke, { Color = 'OutlineColor' })
        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; });
        Library:AddToRegistry(HueBoxStroke, { Color = 'OutlineColor' })
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; });
        Library:AddToRegistry(RgbBoxStroke, { Color = 'OutlineColor' })
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};
        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result) end
            end
            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b)) end
            end
            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);
            DisplayFrame.BackgroundColor3 = ColorPicker.Value;
            DisplayFrame.BackgroundTransparency = ColorPicker.Transparency;
            DisplayStroke.Color = Library:GetDarkerColor(ColorPicker.Value);

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);
            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then Frame.Visible = false; Library.OpenedFrames[Frame] = nil; end;
            end;
            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX);
                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();
                    RenderStepped:Wait();
                end;
                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();
                    RenderStepped:Wait();
                end;
                Library:AttemptSave();
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then ColorPicker:Hide()
                else ContextMenu:Hide(); ColorPicker:Show() end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show(); ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX);
                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));
                        ColorPicker:Display();
                        RenderStepped:Wait();
                    end;
                    Library:AttemptSave();
                end;
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    ColorPicker:Hide();
                end;
                if not Library:IsMouseOverFrame(ContextMenu.Container) then ContextMenu:Hide() end
            end;
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame
        Options[Idx] = ColorPicker;
        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle';
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;
            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then Info.Modes = { 'Toggle' }; Info.Mode = 'Toggle'; end

        local PickOuter = Library:Create('Frame', {
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        });
        Library:Round(PickOuter, 4)

        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        });
        Library:Round(PickInner, 4)
        local PickStroke = Library:Stroke(PickInner, Library.OutlineColor, 1)

        Library:AddToRegistry(PickInner, { BackgroundColor3 = 'BackgroundColor'; });
        Library:AddToRegistry(PickStroke, { Color = 'OutlineColor'; });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        });

        local ModeSelectOuter = Library:Create('Frame', {
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60, 0, 45 + 2);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });
        Library:Round(ModeSelectOuter, 4)
        Library:CreateShadow(ModeSelectOuter, 20, 0.4)

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        });
        Library:Round(ModeSelectInner, 4)
        local ModeStroke = Library:Stroke(ModeSelectInner, Library.OutlineColor, 1)

        Library:AddToRegistry(ModeSelectInner, { BackgroundColor3 = 'BackgroundColor'; });
        Library:AddToRegistry(ModeStroke, { Color = 'OutlineColor'; });

        Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = ModeSelectInner; });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18);
            TextSize = 13;
            Visible = false;
            ZIndex = 110;
            Parent = Library.KeybindContainer;
        },  true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};
            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do Button:Deselect(); end;
                KeyPicker.Mode = Mode;
                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';
                ModeSelectOuter.Visible = false;
            end;
            function ModeButton:Deselect()
                KeyPicker.Mode = nil;
                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then ModeButton:Select(); Library:AttemptSave(); end;
            end);

            if Mode == KeyPicker.Mode then ModeButton:Select(); end;
            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then return; end;
            local State = KeyPicker:GetState();

            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);
            ContainerLabel.Visible = true;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;
            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';

            local YSize, XSize = 0, 0
            for _, Label in next, Library.KeybindContainer:GetChildren() do
                if Label:IsA('TextLabel') and Label.Visible then
                    YSize = YSize + 18;
                    if (Label.TextBounds.X > XSize) then XSize = Label.TextBounds.X end
                end;
            end;
            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then return false; end
                local Key = KeyPicker.Value;
                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else return KeyPicker.Toggled; end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback) KeyPicker.Clicked = Callback end
        function KeyPicker:OnChanged(Callback) KeyPicker.Changed = Callback; Callback(KeyPicker.Value) end
        if ParentObj.Addons then table.insert(ParentObj.Addons, KeyPicker) end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then ParentObj:SetValue(not ParentObj.Value) end
            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;
        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true;
                DisplayLabel.Text = '';
                local Break;
                local Text = '';
                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then Text = ''; end;
                        Text = Text .. '.';
                        DisplayLabel.Text = Text;
                        wait(0.4);
                    end;
                end);
                wait(0.2);
                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;
                    if Input.UserInputType == Enum.UserInputType.Keyboard then Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then Key = 'MB2'; end;
                    Break = true; Picking = false;

                    DisplayLabel.Text = Key; KeyPicker.Value = Key;
                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)
                    Library:AttemptSave();
                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;
                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled; KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then KeyPicker.Toggled = not KeyPicker.Toggled; KeyPicker:DoClick() end;
                    end;
                end;
                KeyPicker:Update();
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input) if (not Picking) then KeyPicker:Update(); end; end))
        KeyPicker:Update();
        Options[Idx] = KeyPicker;
        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...) return Funcs[Key](...); end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};
    function Funcs:AddBlank(Size)
        Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1, 0, 0, Size); ZIndex = 1; Parent = self.Container; });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};
        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 13;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 13, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', { Padding = UDim.new(0, 4); FillDirection = Enum.FillDirection.Horizontal; HorizontalAlignment = Enum.HorizontalAlignment.Right; SortOrder = Enum.SortOrder.LayoutOrder; Parent = TextLabel; });
        end

        Label.TextLabel = TextLabel; Label.Container = Container;
        function Label:SetText(Text)
            TextLabel.Text = Text
            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 13, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end
            Groupbox:Resize();
        end

        if (not DoesWrap) then setmetatable(Label, BaseAddons); end
        Groupbox:AddBlank(5);
        Groupbox:Resize();
        return Label;
    end;

    function Funcs:AddButton(...)
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text; Obj.Func = Props.Func; Obj.DoubleClick = Props.DoubleClick; Obj.Tooltip = Props.Tooltip;
            else Obj.Text = select(1, ...); Obj.Func = select(2, ...); end
            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)
        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 22); -- Sleeker buttons
                ZIndex = 5;
            });
            Library:Round(Outer, 4)

            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            });
            Library:Round(Inner, 4)
            local Stroke = Library:Stroke(Inner, Library.OutlineColor, 1)

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 13;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Inner;
            });

            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 185, 185))
                });
                Rotation = 90;
                Parent = Inner;
            });

            Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; });
            Library:AddToRegistry(Stroke, { Color = 'OutlineColor'; });

            -- Animations
            Inner.MouseEnter:Connect(function()
                TweenService:Create(Inner, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {BackgroundColor3 = Library:GetLighterColor(Library.MainColor)}):Play()
            end)
            Inner.MouseLeave:Connect(function()
                TweenService:Create(Inner, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {BackgroundColor3 = Library.MainColor}):Play()
            end)

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)
                    if type(validator) == 'function' and validator(...) then bindable:Fire(true) else bindable:Fire(false) end
                end)
                task.delay(timeout, function() connection:disconnect(); bindable:Fire(false) end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then return false end
                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return false end
                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                TweenService:Create(Button.Outer, TweenInfo.new(0.1, Enum.EasingStyle.Bounce), {Size = UDim2.new(1, -6, 0, 20)}):Play()
                
                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })
                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true
                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })
                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)
                    if clicked then Library:SafeCallback(Button.Func) end
                else
                    Library:SafeCallback(Button.Func);
                end
            end)
            
            Button.Outer.InputEnded:Connect(function(Input)
                TweenService:Create(Button.Outer, TweenInfo.new(0.1, Enum.EasingStyle.Bounce), {Size = UDim2.new(1, -4, 0, 22)}):Play()
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container
        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then Library:AddToolTip(tooltip, self.Outer) end
            return self
        end

        function Button:AddButton(...)
            local SubButton = {}
            ProcessButtonParams('SubButton', SubButton, ...)
            self.Outer.Size = UDim2.new(0.5, -2, 0, 22)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)
            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then Library:AddToolTip(tooltip, self.Outer) end
                return SubButton
            end
            if type(SubButton.Tooltip) == 'string' then SubButton:AddTooltip(SubButton.Tooltip) end
            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then Button:AddTooltip(Button.Tooltip) end
        Groupbox:AddBlank(5); Groupbox:Resize(); return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        Groupbox:AddBlank(2);
        
        local DividerOuter = Library:Create('Frame', { BackgroundColor3 = Color3.new(0, 0, 0); Size = UDim2.new(1, -4, 0, 3); ZIndex = 5; Parent = self.Container; });
        Library:Round(DividerOuter, 2)
        local DividerInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = DividerOuter; });
        Library:Round(DividerInner, 2)
        local Stroke = Library:Stroke(DividerInner, Library.OutlineColor, 1)

        Library:AddToRegistry(DividerInner, { BackgroundColor3 = 'MainColor'; });
        Library:AddToRegistry(Stroke, { Color = 'OutlineColor'; });
        Groupbox:AddBlank(7); Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')
        local Textbox = {
            Value = Info.Default or ''; Numeric = Info.Numeric or false; Finished = Info.Finished or false;
            Type = 'Input'; Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 15); TextSize = 13; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 5; Parent = Container; });
        Groupbox:AddBlank(1);

        local TextBoxOuter = Library:Create('Frame', { Size = UDim2.new(1, -4, 0, 22); ZIndex = 5; Parent = Container; });
        Library:Round(TextBoxOuter, 4)
        local TextBoxInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = TextBoxOuter; });
        Library:Round(TextBoxInner, 4)
        local Stroke = Library:Stroke(TextBoxInner, Library.OutlineColor, 1)

        Library:AddToRegistry(TextBoxInner, { BackgroundColor3 = 'MainColor'; });
        Library:AddToRegistry(Stroke, { Color = 'OutlineColor'; });

        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, TextBoxOuter) end

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190))
            });
            Rotation = 90; Parent = TextBoxInner;
        });

        local TContainer = Library:Create('Frame', { BackgroundTransparency = 1; ClipsDescendants = true; Position = UDim2.new(0, 5, 0, 0); Size = UDim2.new(1, -5, 1, 0); ZIndex = 7; Parent = TextBoxInner; })
        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1; Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(5, 1),
            Font = Library.Font; PlaceholderColor3 = Color3.fromRGB(150, 150, 150); PlaceholderText = Info.Placeholder or '';
            Text = Info.Default or ''; TextColor3 = Library.FontColor; TextSize = 13; TextStrokeTransparency = 0; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 7; Parent = TContainer;
        });
        Library:ApplyTextStroke(Box);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then Text = Text:sub(1, Info.MaxLength); end;
            if Textbox.Numeric then if (not tonumber(Text)) and Text:len() > 0 then Text = Textbox.Value end end
            Textbox.Value = Text; Box.Text = Text;
            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end
                Textbox:SetValue(Box.Text); Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text); Library:AttemptSave();
            end);
        end

        local function Update()
            local PADDING = 2; local reveal = TContainer.AbsoluteSize.X
            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X
                    local currentCursorPos = Box.Position.X.Offset + width
                    if currentCursorPos < PADDING then Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0) end
                end
            end
        end

        task.spawn(Update); Box:GetPropertyChangedSignal('Text'):Connect(Update); Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update);
        Box.FocusLost:Connect(Update); Box.Focused:Connect(Update);
        Library:AddToRegistry(Box, { TextColor3 = 'FontColor'; });

        function Textbox:OnChanged(Func) Textbox.Changed = Func; Func(Textbox.Value); end;
        Groupbox:AddBlank(5); Groupbox:Resize(); Options[Idx] = Textbox; return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddToggle: Missing `Text` string.')
        local Toggle = { Value = Info.Default or false; Type = 'Toggle'; Callback = Info.Callback or function(Value) end; Addons = {}, Risky = Info.Risky, };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleOuter = Library:Create('Frame', { Size = UDim2.new(0, 16, 0, 16); ZIndex = 5; Parent = Container; });
        Library:Round(ToggleOuter, 4)
        local ToggleInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = ToggleOuter; });
        Library:Round(ToggleInner, 4)
        local Stroke = Library:Stroke(ToggleInner, Library.OutlineColor, 1)

        Library:AddToRegistry(ToggleInner, { BackgroundColor3 = 'MainColor'; });
        Library:AddToRegistry(Stroke, { Color = 'OutlineColor'; });

        local ToggleLabel = Library:CreateLabel({ Size = UDim2.new(0, 216, 1, 0); Position = UDim2.new(1, 8, 0, 0); TextSize = 13; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 6; Parent = ToggleInner; });
        Library:Create('UIListLayout', { Padding = UDim.new(0, 4); FillDirection = Enum.FillDirection.Horizontal; HorizontalAlignment = Enum.HorizontalAlignment.Right; SortOrder = Enum.SortOrder.LayoutOrder; Parent = ToggleLabel; });

        local ToggleRegion = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(0, 170, 1, 0); ZIndex = 8; Parent = ToggleOuter; });

        function Toggle:UpdateColors() Toggle:Display(true); end;
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, ToggleRegion) end

        function Toggle:Display(instant)
            local targetColor = Toggle.Value and Library.AccentColor or Library.MainColor
            local targetStroke = Toggle.Value and Library.AccentColorDark or Library.OutlineColor
            
            if instant then
                ToggleInner.BackgroundColor3 = targetColor
                Stroke.Color = targetStroke
            else
                TweenService:Create(ToggleInner, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = targetColor}):Play()
                TweenService:Create(Stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Color = targetStroke}):Play()
            end
            
            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[Stroke].Properties.Color = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:OnChanged(Func) Toggle.Changed = Func; Func(Toggle.Value); end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool); Toggle.Value = Bool; Toggle:Display();
            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then Addon.Toggled = Bool; Addon:Update() end
            end
            Library:SafeCallback(Toggle.Callback, Toggle.Value); Library:SafeCallback(Toggle.Changed, Toggle.Value); Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value); Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display(true);
        Groupbox:AddBlank(Info.BlankSize or 7); Groupbox:Resize();
        Toggle.TextLabel = ToggleLabel; Toggle.Container = Container; setmetatable(Toggle, BaseAddons);
        Toggles[Idx] = Toggle; Library:UpdateDependencyBoxes(); return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default; Min = Info.Min; Max = Info.Max; Rounding = Info.Rounding;
            MaxSize = 232; Type = 'Slider'; Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 10); TextSize = 13; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; TextYAlignment = Enum.TextYAlignment.Bottom; ZIndex = 5; Parent = Container; });
            Groupbox:AddBlank(3);
        end

        local SliderOuter = Library:Create('Frame', { Size = UDim2.new(1, -4, 0, 14); ZIndex = 5; Parent = Container; });
        Library:Round(SliderOuter, 4)
        local SliderInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = SliderOuter; });
        Library:Round(SliderInner, 4)
        local Stroke = Library:Stroke(SliderInner, Library.OutlineColor, 1)

        Library:AddToRegistry(SliderInner, { BackgroundColor3 = 'MainColor'; });
        Library:AddToRegistry(Stroke, { Color = 'OutlineColor'; });

        local Fill = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; Size = UDim2.new(0, 0, 1, 0); ZIndex = 7; Parent = SliderInner; });
        Library:Round(Fill, 4)
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor'; });

        local DisplayLabel = Library:CreateLabel({ Size = UDim2.new(1, 0, 1, 0); TextSize = 13; Text = 'Infinite'; ZIndex = 9; Parent = SliderInner; });

        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, SliderOuter) end

        function Slider:UpdateColors() Fill.BackgroundColor3 = Library.AccentColor; end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';
            if Info.Compact then DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix); end

            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2.new(0, X, 1, 0);
        end;

        function Slider:OnChanged(Func) Slider.Changed = Func; Func(Slider.Value); end;
        local function Round(Value) if Slider.Rounding == 0 then return math.floor(Value); end; return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value)) end;
        function Slider:GetValueFromXOffset(X) return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max)); end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str); if (not Num) then return; end;
            Num = math.clamp(Num, Slider.Min, Slider.Max); Slider.Value = Num; Slider:Display();
            Library:SafeCallback(Slider.Callback, Slider.Value); Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local mPos = Mouse.X; local gPos = Fill.Size.X.Offset; local Diff = mPos - (Fill.AbsolutePosition.X + gPos);
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X; local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize);
                    local nValue = Slider:GetValueFromXOffset(nX); local OldValue = Slider.Value; Slider.Value = nValue;
                    Slider:Display();
                    if nValue ~= OldValue then Library:SafeCallback(Slider.Callback, Slider.Value); Library:SafeCallback(Slider.Changed, Slider.Value); end;
                    RenderStepped:Wait();
                end;
                Library:AttemptSave();
            end;
        end);

        Slider:Display(); Groupbox:AddBlank(Info.BlankSize or 6); Groupbox:Resize(); Options[Idx] = Slider; return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then Info.Values = GetPlayersString(); Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then Info.Values = GetTeamsString(); Info.AllowNull = true; end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')
        if (not Info.Text) then Info.Compact = true; end;

        local Dropdown = { Values = Info.Values; Value = Info.Multi and {}; Multi = Info.Multi; Type = 'Dropdown'; SpecialType = Info.SpecialType; Callback = Info.Callback or function(Value) end; };
        local Groupbox = self; local Container = Groupbox.Container; local RelativeOffset = 0;

        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 10); TextSize = 13; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; TextYAlignment = Enum.TextYAlignment.Bottom; ZIndex = 5; Parent = Container; });
            Groupbox:AddBlank(3);
        end

        for _, Element in next, Container:GetChildren() do if not Element:IsA('UIListLayout') then RelativeOffset = RelativeOffset + Element.Size.Y.Offset; end; end;

        local DropdownOuter = Library:Create('Frame', { Size = UDim2.new(1, -4, 0, 22); ZIndex = 5; Parent = Container; });
        Library:Round(DropdownOuter, 4)
        local DropdownInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = DropdownOuter; });
        Library:Round(DropdownInner, 4)
        local Stroke = Library:Stroke(DropdownInner, Library.OutlineColor, 1)

        Library:AddToRegistry(DropdownInner, { BackgroundColor3 = 'MainColor'; });
        Library:AddToRegistry(Stroke, { Color = 'OutlineColor'; });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190)) });
            Rotation = 90; Parent = DropdownInner;
        });

        local DropdownArrow = Library:Create('ImageLabel', { AnchorPoint = Vector2.new(0, 0.5); BackgroundTransparency = 1; Position = UDim2.new(1, -16, 0.5, 0); Size = UDim2.new(0, 12, 0, 12); Image = 'http://www.roblox.com/asset/?id=6282522798'; ZIndex = 8; Parent = DropdownInner; });
        local ItemList = Library:CreateLabel({ Position = UDim2.new(0, 5, 0, 0); Size = UDim2.new(1, -5, 1, 0); TextSize = 13; Text = '--'; TextXAlignment = Enum.TextXAlignment.Left; TextWrapped = true; ZIndex = 7; Parent = DropdownInner; });

        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, DropdownOuter) end

        local MAX_DROPDOWN_ITEMS = 8;
        local ListOuter = Library:Create('Frame', { ZIndex = 20; Visible = false; Parent = ScreenGui; ClipsDescendants = true; });
        Library:Round(ListOuter, 4)
        Library:CreateShadow(ListOuter, 25, 0.4)

        local function RecalculateListPosition() ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1); end;
        RecalculateListPosition(); DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        local ListInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, 0, 1, 0); ZIndex = 21; Parent = ListOuter; });
        Library:Round(ListInner, 4)
        local ListStroke = Library:Stroke(ListInner, Library.OutlineColor, 1)

        Library:AddToRegistry(ListInner, { BackgroundColor3 = 'MainColor'; });
        Library:AddToRegistry(ListStroke, { Color = 'OutlineColor'; });

        local Scrolling = Library:Create('ScrollingFrame', { BackgroundTransparency = 1; BorderSizePixel = 0; CanvasSize = UDim2.new(0, 0, 0, 0); Size = UDim2.new(1, 0, 1, 0); ZIndex = 21; Parent = ListInner; TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png', BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png', ScrollBarThickness = 3, ScrollBarImageColor3 = Library.AccentColor, });
        Library:AddToRegistry(Scrolling, { ScrollBarImageColor3 = 'AccentColor' })
        Library:Create('UIListLayout', { Padding = UDim.new(0, 0); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Scrolling; });

        function Dropdown:Display()
            local Values = Dropdown.Values; local Str = '';
            if Info.Multi then
                for Idx, Value in next, Values do if Dropdown.Value[Value] then Str = Str .. Value .. ', '; end; end;
                Str = Str:sub(1, #Str - 2);
            else Str = Dropdown.Value or ''; end;
            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then local T = {}; for Value, Bool in next, Dropdown.Value do table.insert(T, Value); end; return T;
            else return Dropdown.Value and 1 or 0; end;
        end;
        
        function Dropdown:GetItemCount()
            return #Dropdown.Values
        end

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values; local Buttons = {};
            for _, Element in next, Scrolling:GetChildren() do if not Element:IsA('UIListLayout') then Element:Destroy(); end; end;
            local Count = 0;

            for Idx, Value in next, Values do
                local Table = {}; Count = Count + 1;
                local Button = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, -1, 0, 20); ZIndex = 23; Active = true, Parent = Scrolling; });
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor'; });

                local ButtonLabel = Library:CreateLabel({ Active = false; Size = UDim2.new(1, -6, 1, 0); Position = UDim2.new(0, 6, 0, 0); TextSize = 13; Text = Value; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 25; Parent = Button; });

                local Selected; if Info.Multi then Selected = Dropdown.Value[Value]; else Selected = Dropdown.Value == Value; end;
                function Table:UpdateButton()
                    if Info.Multi then Selected = Dropdown.Value[Value]; else Selected = Dropdown.Value == Value; end;
                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                ButtonLabel.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local Try = not Selected;
                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;
                                if Selected then Dropdown.Value[Value] = true; else Dropdown.Value[Value] = nil; end;
                            else
                                Selected = Try;
                                if Selected then Dropdown.Value = Value; else Dropdown.Value = nil; end;
                                for _, OtherButton in next, Buttons do OtherButton:UpdateButton(); end;
                            end;
                            Table:UpdateButton(); Dropdown:Display();
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value); Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
                            Library:AttemptSave();
                        end;
                    end;
                end);
                Table:UpdateButton(); Dropdown:Display(); Buttons[Button] = Table;
            end;
            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);
        end;

        function Dropdown:SetValues(NewValues) if NewValues then Dropdown.Values = NewValues; end; Dropdown:BuildDropdownList(); end;

        function Dropdown:OpenDropdown()
            ListOuter.Visible = true;
            Library.OpenedFrames[ListOuter] = true;
            TweenService:Create(DropdownArrow, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Rotation = 180}):Play();
            
            local Y = math.clamp(Dropdown:GetItemCount() * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, 0)
            TweenService:Create(ListOuter, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, Y)}):Play()
        end;

        function Dropdown:CloseDropdown()
            Library.OpenedFrames[ListOuter] = nil;
            TweenService:Create(DropdownArrow, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Rotation = 0}):Play();
            local tw = TweenService:Create(ListOuter, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, 0)})
            tw:Play()
            tw.Completed:Connect(function() if not Library.OpenedFrames[ListOuter] then ListOuter.Visible = false end end)
        end;

        function Dropdown:OnChanged(Func) Dropdown.Changed = Func; Func(Dropdown.Value); end;
        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {}; for Value, Bool in next, Val do if table.find(Dropdown.Values, Value) then nTable[Value] = true end; end; Dropdown.Value = nTable;
            else
                if (not Val) then Dropdown.Value = nil; elseif table.find(Dropdown.Values, Val) then Dropdown.Value = Val; end;
            end;
            Dropdown:BuildDropdownList(); Library:SafeCallback(Dropdown.Callback, Dropdown.Value); Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then Dropdown:CloseDropdown(); else Dropdown:OpenDropdown(); end;
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    Dropdown:CloseDropdown();
                end;
            end;
        end);

        Dropdown:BuildDropdownList(); Dropdown:Display();
        local Defaults = {}
        if type(Info.Default) == 'string' then local Idx = table.find(Dropdown.Values, Info.Default); if Idx then table.insert(Defaults, Idx) end
        elseif type(Info.Default) == 'table' then for _, Value in next, Info.Default do local Idx = table.find(Dropdown.Values, Value); if Idx then table.insert(Defaults, Idx) end end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then table.insert(Defaults, Info.Default) end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]; if Info.Multi then Dropdown.Value[Dropdown.Values[Index]] = true else Dropdown.Value = Dropdown.Values[Index]; end
                if (not Info.Multi) then break end
            end
            Dropdown:BuildDropdownList(); Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5); Groupbox:Resize(); Options[Idx] = Dropdown; return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = { Dependencies = {}; }; local Groupbox = self; local Container = Groupbox.Container;
        local Holder = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1, 0, 0, 0); Visible = false; Parent = Container; });
        local Frame = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1, 0, 1, 0); Visible = true; Parent = Holder; });
        local Layout = Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Frame; });

        function Depbox:Resize() Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y); Groupbox:Resize(); end;
        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Depbox:Resize(); end);
        Holder:GetPropertyChangedSignal('Visible'):Connect(function() Depbox:Resize(); end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1]; local Value = Dependency[2];
                if Elem.Type == 'Toggle' and Elem.Value ~= Value then Holder.Visible = false; Depbox:Resize(); return; end;
            end;
            Holder.Visible = true; Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            Depbox.Dependencies = Dependencies; Depbox:Update();
        end;

        Depbox.Container = Frame; setmetatable(Depbox, BaseGroupbox); table.insert(Library.DependencyBoxes, Depbox); return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...) return Funcs[Key](...); end;
end;

do
    Library.NotificationArea = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0, 0, 0, 40); Size = UDim2.new(0, 300, 0, 200); ZIndex = 100; Parent = ScreenGui; });
    Library:Create('UIListLayout', { Padding = UDim.new(0, 4); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Library.NotificationArea; });

    local WatermarkOuter = Library:Create('Frame', { Position = UDim2.new(0, 100, 0, -25); Size = UDim2.new(0, 213, 0, 24); ZIndex = 200; Visible = false; Parent = ScreenGui; });
    Library:Round(WatermarkOuter, 6)
    Library:CreateShadow(WatermarkOuter, 25, 0.4)

    local WatermarkInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, 0, 1, 0); ZIndex = 201; Parent = WatermarkOuter; });
    Library:Round(WatermarkInner, 6)
    local WStroke = Library:Stroke(WatermarkInner, Library.AccentColor, 1)
    Library:AddToRegistry(WStroke, { Color = 'AccentColor'; });

    local InnerFrame = Library:Create('Frame', { BackgroundColor3 = Color3.new(1, 1, 1); BorderSizePixel = 0; Position = UDim2.new(0, 1, 0, 1); Size = UDim2.new(1, -2, 1, -2); ZIndex = 202; Parent = WatermarkInner; });
    Library:Round(InnerFrame, 6)

    local Gradient = Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)), ColorSequenceKeypoint.new(1, Library.MainColor), }); Rotation = -90; Parent = InnerFrame; });
    Library:AddToRegistry(Gradient, { Color = function() return ColorSequence.new({ ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)), ColorSequenceKeypoint.new(1, Library.MainColor), }); end });

    local WatermarkLabel = Library:CreateLabel({ Position = UDim2.new(0, 6, 0, 0); Size = UDim2.new(1, -4, 1, 0); TextSize = 13; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 203; Parent = InnerFrame; RichText = true });
    Library.Watermark = WatermarkOuter; Library.WatermarkText = WatermarkLabel; Library:MakeDraggable(Library.Watermark);

    local KeybindOuter = Library:Create('Frame', { AnchorPoint = Vector2.new(0, 0.5); Position = UDim2.new(0, 10, 0.5, 0); Size = UDim2.new(0, 210, 0, 20); Visible = false; ZIndex = 100; Parent = ScreenGui; });
    Library:Round(KeybindOuter, 6)
    Library:CreateShadow(KeybindOuter, 25, 0.4)

    local KeybindInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, 0, 1, 0); ZIndex = 101; Parent = KeybindOuter; });
    Library:Round(KeybindInner, 6)
    local KStroke = Library:Stroke(KeybindInner, Library.OutlineColor, 1)
    Library:AddToRegistry(KeybindInner, { BackgroundColor3 = 'MainColor'; }, true);
    Library:AddToRegistry(KStroke, { Color = 'OutlineColor' }, true);

    local ColorFrame = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1, 0, 0, 2); ZIndex = 102; Parent = KeybindInner; });
    Library:Round(ColorFrame, 2)
    Library:AddToRegistry(ColorFrame, { BackgroundColor3 = 'AccentColor'; }, true);

    local KeybindLabel = Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 20); Position = UDim2.fromOffset(5, 2), TextXAlignment = Enum.TextXAlignment.Left, Text = 'Keybinds'; ZIndex = 104; Parent = KeybindInner; });
    local KeybindContainer = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1, 0, 1, -20); Position = UDim2.new(0, 0, 0, 20); ZIndex = 1; Parent = KeybindInner; });
    Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = KeybindContainer; });
    Library:Create('UIPadding', { PaddingLeft = UDim.new(0, 5), Parent = KeybindContainer, })
    Library.KeybindFrame = KeybindOuter; Library.KeybindContainer = KeybindContainer; Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool) Library.Watermark.Visible = Bool; end;
function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 13);
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3);
    Library:SetWatermarkVisibility(true)
    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 13);
    YSize = YSize + 12

    local NotifyOuter = Library:Create('Frame', { Position = UDim2.new(0, 100, 0, 10); Size = UDim2.new(0, 0, 0, YSize); ClipsDescendants = true; ZIndex = 100; Parent = Library.NotificationArea; });
    Library:Round(NotifyOuter, 6)
    Library:CreateShadow(NotifyOuter, 25, 0.4)

    local NotifyInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, 0, 1, 0); ZIndex = 101; Parent = NotifyOuter; });
    Library:Round(NotifyInner, 6)
    local NStroke = Library:Stroke(NotifyInner, Library.OutlineColor, 1)

    Library:AddToRegistry(NotifyInner, { BackgroundColor3 = 'MainColor'; }, true);
    Library:AddToRegistry(NStroke, { Color = 'OutlineColor' }, true)

    local InnerFrame = Library:Create('Frame', { BackgroundColor3 = Color3.new(1, 1, 1); BorderSizePixel = 0; Position = UDim2.new(0, 1, 0, 1); Size = UDim2.new(1, -2, 1, -2); ZIndex = 102; Parent = NotifyInner; });
    Library:Round(InnerFrame, 6)
    
    local Gradient = Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)), ColorSequenceKeypoint.new(1, Library.MainColor), }); Rotation = -90; Parent = InnerFrame; });
    Library:AddToRegistry(Gradient, { Color = function() return ColorSequence.new({ ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)), ColorSequenceKeypoint.new(1, Library.MainColor), }); end });

    local NotifyLabel = Library:CreateLabel({ Position = UDim2.new(0, 8, 0, 0); Size = UDim2.new(1, -4, 1, 0); Text = Text; TextXAlignment = Enum.TextXAlignment.Left; TextSize = 13; ZIndex = 103; Parent = InnerFrame; RichText = true; });
    local LeftColor = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Position = UDim2.new(0, 0, 0, 0); Size = UDim2.new(0, 4, 1, 0); ZIndex = 104; Parent = NotifyOuter; });
    Library:Round(LeftColor, 6)
    Library:AddToRegistry(LeftColor, { BackgroundColor3 = 'AccentColor'; }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 16, 0, YSize), 'Out', 'Quart', 0.5, true);

    task.spawn(function()
        wait(Time or 5);
        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quart', 0.5, true);
        wait(0.5);
        NotifyOuter:Destroy();
    end);
end;

function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then Config = ...; else Config.Title = Arguments[1]; Config.AutoShow = Arguments[2] or false; end
    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end
    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end

    if Config.Center then Config.AnchorPoint = Vector2.new(0.5, 0.5); Config.Position = UDim2.fromScale(0.5, 0.5) end

    local Window = { Tabs = {}; };
    local Outer = Library:Create('Frame', { AnchorPoint = Config.AnchorPoint, Position = Config.Position, Size = Config.Size, Visible = false; ZIndex = 1; Parent = ScreenGui; BackgroundTransparency = 1 });
    Library:CreateShadow(Outer, 50, 0.5)

    Library:MakeDraggable(Outer, 25);

    local Inner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, 0, 1, 0); ZIndex = 1; Parent = Outer; });
    Library:Round(Inner, 8)
    local WindowStroke = Library:Stroke(Inner, Library.AccentColor, 1)

    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; });
    Library:AddToRegistry(WindowStroke, { Color = 'AccentColor'; });

    local WindowLabel = Library:CreateLabel({ Position = UDim2.new(0, 10, 0, 0); Size = UDim2.new(0, 0, 0, 30); Text = Config.Title or ''; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 1; Parent = Inner; RichText = true; });

    local MainSectionOuter = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; Position = UDim2.new(0, 8, 0, 30); Size = UDim2.new(1, -16, 1, -38); ZIndex = 1; Parent = Inner; });
    Library:Round(MainSectionOuter, 6)
    local SectionStroke = Library:Stroke(MainSectionOuter, Library.OutlineColor, 1)
    
    Library:AddToRegistry(MainSectionOuter, { BackgroundColor3 = 'BackgroundColor'; });
    Library:AddToRegistry(SectionStroke, { Color = 'OutlineColor' });

    local TabArea = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0, 8, 0, 8); Size = UDim2.new(1, -16, 0, 24); ZIndex = 1; Parent = MainSectionOuter; });
    local TabListLayout = Library:Create('UIListLayout', { Padding = UDim.new(0, Config.TabPadding); FillDirection = Enum.FillDirection.Horizontal; SortOrder = Enum.SortOrder.LayoutOrder; Parent = TabArea; });

    local TabContainer = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Position = UDim2.new(0, 8, 0, 35); Size = UDim2.new(1, -16, 1, -43); ZIndex = 2; Parent = MainSectionOuter; });
    Library:Round(TabContainer, 4)
    local TContainerStroke = Library:Stroke(TabContainer, Library.OutlineColor, 1)

    Library:AddToRegistry(TabContainer, { BackgroundColor3 = 'MainColor'; });
    Library:AddToRegistry(TContainerStroke, { Color = 'OutlineColor' })

    function Window:SetWindowTitle(Title) WindowLabel.Text = Title; end;

    function Window:AddTab(Name)
        local Tab = { Groupboxes = {}; Tabboxes = {}; };
        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16);

        local TabButton = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; Size = UDim2.new(0, TabButtonWidth + 14, 1, 0); ZIndex = 1; Parent = TabArea; });
        Library:Round(TabButton, 4)
        local TButtonStroke = Library:Stroke(TabButton, Library.OutlineColor, 1)

        Library:AddToRegistry(TabButton, { BackgroundColor3 = 'BackgroundColor'; });
        Library:AddToRegistry(TButtonStroke, { Color = 'OutlineColor' });

        local TabButtonLabel = Library:CreateLabel({ Position = UDim2.new(0, 0, 0, 0); Size = UDim2.new(1, 0, 1, -1); Text = Name; ZIndex = 1; Parent = TabButton; RichText = true });

        local TabIndicator = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Position = UDim2.new(0.5, 0, 1, -2); Size = UDim2.new(0, 0, 0, 2); AnchorPoint = Vector2.new(0.5, 0); Visible = false; ZIndex = 2; Parent = TabButton; });
        Library:Round(TabIndicator, 2)
        Library:AddToRegistry(TabIndicator, { BackgroundColor3 = 'AccentColor'; });

        local TabFrame = Library:Create('Frame', { Name = 'TabFrame', BackgroundTransparency = 1; Position = UDim2.new(0, 0, 0, 0); Size = UDim2.new(1, 0, 1, 0); Visible = false; ZIndex = 2; Parent = TabContainer; });
        local LeftSide = Library:Create('ScrollingFrame', { BackgroundTransparency = 1; BorderSizePixel = 0; Position = UDim2.new(0, 8 - 1, 0, 8 - 1); Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2); CanvasSize = UDim2.new(0, 0, 0, 0); BottomImage = ''; TopImage = ''; ScrollBarThickness = 0; ZIndex = 2; Parent = TabFrame; });
        local RightSide = Library:Create('ScrollingFrame', { BackgroundTransparency = 1; BorderSizePixel = 0; Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1); Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2); CanvasSize = UDim2.new(0, 0, 0, 0); BottomImage = ''; TopImage = ''; ScrollBarThickness = 0; ZIndex = 2; Parent = TabFrame; });

        Library:Create('UIListLayout', { Padding = UDim.new(0, 8); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; HorizontalAlignment = Enum.HorizontalAlignment.Center; Parent = LeftSide; });
        Library:Create('UIListLayout', { Padding = UDim.new(0, 8); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; HorizontalAlignment = Enum.HorizontalAlignment.Center; Parent = RightSide; });

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y); end);
        end;

        function Tab:ShowTab()
            for _, Tab in next, Window.Tabs do Tab:HideTab(); end;
            TabIndicator.Visible = true;
            TweenService:Create(TabIndicator, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, -8, 0, 2)}):Play()
            TabButton.BackgroundColor3 = Library.MainColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor';
            TabFrame.Visible = true;
        end;

        function Tab:HideTab()
            TweenService:Create(TabIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 0, 2)}):Play()
            TabButton.BackgroundColor3 = Library.BackgroundColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor';
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(Position) TabButton.LayoutOrder = Position; TabListLayout:ApplyLayout(); end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};
            local BoxOuter = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; Size = UDim2.new(1, 0, 0, 507 + 2); ZIndex = 2; Parent = Info.Side == 1 and LeftSide or RightSide; });
            Library:Round(BoxOuter, 4)
            local BoxStroke = Library:Stroke(BoxOuter, Library.OutlineColor, 1)

            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor'; });
            Library:AddToRegistry(BoxStroke, { Color = 'OutlineColor' });

            local Highlight = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1, 0, 0, 2); ZIndex = 5; Parent = BoxOuter; });
            Library:Round(Highlight, 2)
            Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });

            local GroupboxLabel = Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 18); Position = UDim2.new(0, 6, 0, 4); TextSize = 13; Text = Info.Name; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 5; Parent = BoxOuter; RichText = true; });

            local Container = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0, 6, 0, 26); Size = UDim2.new(1, -12, 1, -26); ZIndex = 1; Parent = BoxOuter; });
            Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Container; });

            function Groupbox:Resize()
                local Size = 0;
                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then Size = Size + Element.Size.Y.Offset; end;
                end;
                BoxOuter.Size = UDim2.new(1, 0, 0, 26 + Size + 6);
            end;

            Groupbox.Container = Container; setmetatable(Groupbox, BaseGroupbox); Groupbox:AddBlank(3); Groupbox:Resize(); Tab.Groupboxes[Info.Name] = Groupbox; return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name) return Tab:AddGroupbox({ Side = 1; Name = Name; }); end;
        function Tab:AddRightGroupbox(Name) return Tab:AddGroupbox({ Side = 2; Name = Name; }); end;

        function Tab:AddTabbox(Info)
            local Tabbox = { Tabs = {}; };
            local BoxOuter = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; Size = UDim2.new(1, 0, 0, 0); ZIndex = 2; Parent = Info.Side == 1 and LeftSide or RightSide; });
            Library:Round(BoxOuter, 4)
            local BoxStroke = Library:Stroke(BoxOuter, Library.OutlineColor, 1)

            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor'; });
            Library:AddToRegistry(BoxStroke, { Color = 'OutlineColor' });

            local Highlight = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1, 0, 0, 2); ZIndex = 10; Parent = BoxOuter; });
            Library:Round(Highlight, 2)
            Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });

            local TabboxButtons = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0, 0, 0, 1); Size = UDim2.new(1, 0, 0, 22); ZIndex = 5; Parent = BoxOuter; });
            Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal; HorizontalAlignment = Enum.HorizontalAlignment.Left; SortOrder = Enum.SortOrder.LayoutOrder; Parent = TabboxButtons; });

            function Tabbox:AddTab(Name)
                local Tab = {};
                local Button = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(0.5, 0, 1, 0); ZIndex = 6; Parent = TabboxButtons; });
                Library:Round(Button, 4)
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor'; });

                local ButtonLabel = Library:CreateLabel({ Size = UDim2.new(1, 0, 1, 0); TextSize = 13; Text = Name; TextXAlignment = Enum.TextXAlignment.Center; ZIndex = 7; Parent = Button; RichText = true; });
                local Container = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0, 6, 0, 26); Size = UDim2.new(1, -12, 1, -26); ZIndex = 1; Visible = false; Parent = BoxOuter; });
                Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Container; });

                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do Tab:Hide(); end;
                    Container.Visible = true;
                    Button.BackgroundColor3 = Library.BackgroundColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';
                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Button.BackgroundColor3 = Library.MainColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function Tab:Resize()
                    local TabCount = 0; for _, Tab in next, Tabbox.Tabs do TabCount = TabCount + 1; end;
                    for _, Button in next, TabboxButtons:GetChildren() do if not Button:IsA('UIListLayout') then Button.Size = UDim2.new(1 / TabCount, 0, 1, 0); end; end;
                    if (not Container.Visible) then return; end;
                    local Size = 0; for _, Element in next, Tab.Container:GetChildren() do if (not Element:IsA('UIListLayout')) and Element.Visible then Size = Size + Element.Size.Y.Offset; end; end;
                    BoxOuter.Size = UDim2.new(1, 0, 0, 26 + Size + 6);
                end;

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then Tab:Show(); Tab:Resize(); end;
                end);

                Tab.Container = Container; Tabbox.Tabs[Name] = Tab; setmetatable(Tab, BaseGroupbox); Tab:AddBlank(3); Tab:Resize();
                if #TabboxButtons:GetChildren() == 2 then Tab:Show(); end;
                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox; return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 1; }); end;
        function Tab:AddRightTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 2; }); end;

        TabButton.InputBegan:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseButton1 then Tab:ShowTab(); end; end);
        if #TabContainer:GetChildren() == 1 then Tab:ShowTab(); end;
        Window.Tabs[Name] = Tab; return Tab;
    end;

    local ModalElement = Library:Create('TextButton', { BackgroundTransparency = 1; Size = UDim2.new(0, 0, 0, 0); Visible = true; Text = ''; Modal = false; Parent = ScreenGui; });
    local TransparencyCache = {}; local Toggled = false; local Fading = false;

    function Library:Toggle()
        if Fading then return; end;
        local FadeTime = Config.MenuFadeTime; Fading = true; Toggled = (not Toggled); ModalElement.Modal = Toggled;

        if Toggled then
            Outer.Visible = true;
            task.spawn(function()
                local State = InputService.MouseIconEnabled;
                local Cursor = Drawing.new('Triangle'); Cursor.Thickness = 1; Cursor.Filled = true; Cursor.Visible = true;
                local CursorOutline = Drawing.new('Triangle'); CursorOutline.Thickness = 1; CursorOutline.Filled = false; CursorOutline.Color = Color3.new(0, 0, 0); CursorOutline.Visible = true;
                while Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false;
                    local mPos = InputService:GetMouseLocation();
                    Cursor.Color = Library.AccentColor;
                    Cursor.PointA = Vector2.new(mPos.X, mPos.Y); Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6); Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16);
                    CursorOutline.PointA = Cursor.PointA; CursorOutline.PointB = Cursor.PointB; CursorOutline.PointC = Cursor.PointC;
                    RenderStepped:Wait();
                end;
                InputService.MouseIconEnabled = State; Cursor:Remove(); CursorOutline:Remove();
            end);
        end;

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {};
            if Desc:IsA('ImageLabel') then table.insert(Properties, 'ImageTransparency'); table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then table.insert(Properties, 'TextTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') then table.insert(Properties, 'Transparency'); end;

            local Cache = TransparencyCache[Desc];
            if (not Cache) then Cache = {}; TransparencyCache[Desc] = Cache; end;

            for _, Prop in next, Properties do
                if not Cache[Prop] then Cache[Prop] = Desc[Prop]; end;
                if Cache[Prop] == 1 then continue; end;
                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Quart), { [Prop] = Toggled and Cache[Prop] or 1 }):Play();
            end;
        end;

        task.wait(FadeTime); Outer.Visible = Toggled; Fading = false;
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then task.spawn(Library.Toggle) end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end
    Window.Holder = Outer; return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();
    for _, Value in next, Options do if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then Value:SetValues(PlayerList); end; end;
end;

Players.PlayerAdded:Connect(OnPlayerChange); Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().Library = Library
return Library
