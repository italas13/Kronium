local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService');
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

    Toggles = Toggles;
    Options = Options;

    -- Reference Image Exact Color Palette (Dark / Charcoal / Crisp White / Blue Accent)
    BackgroundColor = Color3.fromRGB(10, 10, 12);       -- #0A0A0C (Pure deep dark window background)
    MainColor = Color3.fromRGB(12, 13, 16);             -- #0C0D10 (Panel / Groupbox card background)
    SecondaryBgColor = Color3.fromRGB(15, 17, 21);      -- #0F1115 (Secondary background)
    ControlColor = Color3.fromRGB(18, 20, 25);          -- #121419 (Buttons, dropdowns, inputs, checkboxes)
    OutlineColor = Color3.fromRGB(30, 33, 42);          -- #1E212A (Subtle dark 1px borders)
    OutlineColorLight = Color3.fromRGB(44, 48, 60);     -- #2C303C (Hover/sub-tab borders)

    FontColor = Color3.fromRGB(235, 238, 245);          -- #EBEEF5 (Primary text - bright clean white)
    SecondaryFontColor = Color3.fromRGB(120, 126, 142); -- #787E8E (Inactive tabs, subheadings, placeholder)
    MutedFontColor = Color3.fromRGB(85, 90, 104);       -- #555A68 (Caret icons, disabled elements)

    AccentColor = Color3.fromRGB(22, 139, 255);         -- #168BFF (Blue Accent - sliders, active tab line, checkmark)
    AccentColorDark = Color3.fromRGB(10, 110, 220);     -- #0A6EDC (Active click state)
    AccentHover = Color3.fromRGB(54, 160, 255);         -- #36A0FF (Hover state)
    RiskColor = Color3.fromRGB(255, 65, 65);            -- Error/Risk red

    Black = Color3.fromRGB(0, 0, 0);
    White = Color3.fromRGB(255, 255, 255);

    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
    FontMedium = Enum.Font.GothamMedium,

    DPIScale = 1,
    ToggleKeybind = nil,
    ShowCustomCursor = true,
    ForceCheckbox = false,
    ShowToggleFrameInKeybinds = true,

    OpenedFrames = {};
    DependencyBoxes = {};
    Signals = {};
    ScreenGui = ScreenGui;
};

local RainbowStep = 0;
local Hue = 0;

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta;
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0;
        Hue = Hue + (1 / 400);
        if Hue > 1 then Hue = 0; end;
        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end;
end));

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();
    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;
    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);
    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();
    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;
    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if not f then return; end;
    if not Library.NotifyOnError then
        return f(...);
    end;
    local success, event = pcall(f, ...);
    if not success then
        local _, i = event:find(":%d+: ");
        if not i then
            return Library:Notify(event);
        end;
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

function Library:ApplyCorner(Inst, Radius)
    return Library:Create('UICorner', {
        CornerRadius = UDim.new(0, Radius or 4);
        Parent = Inst;
    });
end;

function Library:ApplyStroke(Inst, Color, Thickness)
    return Library:Create('UIStroke', {
        Color = Color or Library.OutlineColor;
        Thickness = Thickness or 1;
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
        LineJoinMode = Enum.LineJoinMode.Round;
        Parent = Inst;
    });
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.FontMedium;
        TextColor3 = Library.FontColor;
        TextSize = 12;
        TextStrokeTransparency = 1;
        TextXAlignment = Enum.TextXAlignment.Left;
    });

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end;

function Library:SetDPIScale(Scale)
    Scale = (tonumber(Scale) or 100) / 100;
    Library.DPIScale = Scale;
    if Library.Window and Library.Window.Holder then
        local BaseSize = Library.Window.BaseSize or Vector2.new(600, 590);
        Library.Window.Holder.Size = UDim2.fromOffset(BaseSize.X * Scale, BaseSize.Y * Scale);
    end;
end;

function Library:SetToggleKeybind(Keybind)
    Library.ToggleKeybind = Keybind;
end;

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;
    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            );
            if ObjPos.Y > (Cutoff or 42) then
                return;
            end;
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
    end);
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 12);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.SecondaryBgColor,
        Size = UDim2.fromOffset(X + 10, Y + 8),
        ZIndex = 200,
        Parent = Library.ScreenGui,
        Visible = false,
    });
    Library:ApplyCorner(Tooltip, 3);
    local TooltipStroke = Library:ApplyStroke(Tooltip, Library.OutlineColor, 1);

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(5, 4),
        Size = UDim2.fromOffset(X, Y),
        TextSize = 12,
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Tooltip.ZIndex + 1,
        Parent = Tooltip,
    });

    Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'SecondaryBgColor' });
    Library:AddToRegistry(TooltipStroke, { Color = 'OutlineColor' });
    Library:AddToRegistry(Label, { TextColor3 = 'FontColor' });

    local IsHovering = false;
    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return; end;
        IsHovering = true;
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 14, Mouse.Y + 12);
        Tooltip.Visible = true;
        while IsHovering do
            RunService.Heartbeat:Wait();
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 14, Mouse.Y + 12);
        end;
    end);

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false;
        Tooltip.Visible = false;
    end);
end;

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];
        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end);

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];
        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end);
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
    if not Frame or not Frame.Visible then return false; end;
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
        return true;
    end;
    return false;
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
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080));
    return Bounds.X, Bounds.Y;
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };
    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;
    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];
    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;
        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
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
                Object.Instance[Property] = ColorIdx();
            end;
        end;
    end;
end;

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal);
end;

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx);
        Connection:Disconnect();
    end;
    if Library.OnUnload then
        Library.OnUnload();
    end;
    ScreenGui:Destroy();
end;

function Library:OnUnload(Callback)
    Library.OnUnload = Callback;
end;

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end));

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

        -- Circular Color Dot Indicator matching reference screenshot exactly
        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            Size = UDim2.new(0, 11, 0, 11);
            ZIndex = 6;
            Parent = ToggleLabel;
        });
        Library:ApplyCorner(DisplayFrame, 6);
        local DisplayStroke = Library:ApplyStroke(DisplayFrame, Library.OutlineColor, 1);
        Library:AddToRegistry(DisplayStroke, { Color = 'OutlineColor' });

        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });
        Library:ApplyCorner(CheckerFrame, 6);

        -- Gear Icon button (if specified or default)
        local GearBtn;
        if Info.SettingsIcon ~= false then
            GearBtn = Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(0, 13, 0, 13);
                Image = 'rbxassetid://10734950020';
                ImageColor3 = Library.SecondaryFontColor;
                ZIndex = 6;
                Parent = ToggleLabel;
            });
            Library:AddToRegistry(GearBtn, { ImageColor3 = 'SecondaryFontColor' });
        end;

        -- Color Picker popup window
        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Library.MainColor;
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X - 190, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(220, Info.Transparency and 260 or 240);
            Visible = false;
            ZIndex = 150;
            Parent = ScreenGui,
        });
        Library:ApplyCorner(PickerFrameOuter, 4);
        local PickerStroke = Library:ApplyStroke(PickerFrameOuter, Library.OutlineColor, 1);
        Library:AddToRegistry(PickerFrameOuter, { BackgroundColor3 = 'MainColor' });
        Library:AddToRegistry(PickerStroke, { Color = 'OutlineColor' });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(
                math.clamp(DisplayFrame.AbsolutePosition.X - 190, 10, math.huge),
                DisplayFrame.AbsolutePosition.Y + 18
            );
        end);

        local TopIndicator = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -12, 0, 2);
            Position = UDim2.new(0, 6, 0, 0);
            ZIndex = 152;
            Parent = PickerFrameOuter;
        });
        Library:ApplyCorner(TopIndicator, 1);
        Library:AddToRegistry(TopIndicator, { BackgroundColor3 = 'AccentColor' });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, -16, 0, 16);
            Position = UDim2.fromOffset(8, 6);
            TextSize = 12;
            Font = Library.FontBold;
            Text = ColorPicker.Title;
            TextColor3 = Library.FontColor;
            ZIndex = 152;
            Parent = PickerFrameOuter;
        });

        local SatVibMap = Library:Create('ImageLabel', {
            Position = UDim2.new(0, 8, 0, 26);
            Size = UDim2.new(0, 175, 0, 155);
            ZIndex = 152;
            Image = 'rbxassetid://4155801252';
            Parent = PickerFrameOuter;
        });
        Library:ApplyCorner(SatVibMap, 3);
        local SatVibStroke = Library:ApplyStroke(SatVibMap, Library.OutlineColor, 1);
        Library:AddToRegistry(SatVibStroke, { Color = 'OutlineColor' });

        local CursorOuter = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundColor3 = Library.White;
            ZIndex = 154;
            Parent = SatVibMap;
        });
        Library:ApplyCorner(CursorOuter, 3);
        Library:ApplyStroke(CursorOuter, Library.Black, 1);

        local HueSelectorOuter = Library:Create('Frame', {
            Position = UDim2.new(0, 190, 0, 26);
            Size = UDim2.new(0, 18, 0, 155);
            ZIndex = 152;
            Parent = PickerFrameOuter;
        });
        Library:ApplyCorner(HueSelectorOuter, 3);
        local HueStroke = Library:ApplyStroke(HueSelectorOuter, Library.OutlineColor, 1);
        Library:AddToRegistry(HueStroke, { Color = 'OutlineColor' });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 153;
            Parent = HueSelectorOuter;
        });
        Library:ApplyCorner(HueSelectorInner, 3);

        local SequenceTable = {};
        for H = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(H, Color3.fromHSV(H, 1, 1)));
        end;
        Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        local HueCursor = Library:Create('Frame', {
            BackgroundColor3 = Library.White;
            AnchorPoint = Vector2.new(0, 0.5);
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 154;
            Parent = HueSelectorInner;
        });
        Library:ApplyCorner(HueCursor, 1);
        Library:ApplyStroke(HueCursor, Library.Black, 1);

        -- Inputs (Hex & RGB)
        local HueBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.ControlColor;
            Position = UDim2.fromOffset(8, 188),
            Size = UDim2.new(0.5, -12, 0, 20),
            ZIndex = 152,
            Parent = PickerFrameOuter;
        });
        Library:ApplyCorner(HueBoxOuter, 3);
        local HexStroke = Library:ApplyStroke(HueBoxOuter, Library.OutlineColor, 1);
        Library:AddToRegistry(HueBoxOuter, { BackgroundColor3 = 'ControlColor' });
        Library:AddToRegistry(HexStroke, { Color = 'OutlineColor' });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 4, 0, 0);
            Size = UDim2.new(1, -8, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Library.SecondaryFontColor;
            PlaceholderText = '#FFFFFF',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 11;
            TextXAlignment = Enum.TextXAlignment.Center;
            ZIndex = 153,
            Parent = HueBoxOuter;
        });

        local RgbBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.ControlColor;
            Position = UDim2.new(0.5, 4, 0, 188),
            Size = UDim2.new(0.5, -12, 0, 20),
            ZIndex = 152,
            Parent = PickerFrameOuter;
        });
        Library:ApplyCorner(RgbBoxOuter, 3);
        local RgbStroke = Library:ApplyStroke(RgbBoxOuter, Library.OutlineColor, 1);
        Library:AddToRegistry(RgbBoxOuter, { BackgroundColor3 = 'ControlColor' });
        Library:AddToRegistry(RgbStroke, { Color = 'OutlineColor' });

        local RgbBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 4, 0, 0);
            Size = UDim2.new(1, -8, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Library.SecondaryFontColor;
            PlaceholderText = '255, 255, 255',
            Text = '255, 255, 255',
            TextColor3 = Library.FontColor;
            TextSize = 11;
            TextXAlignment = Enum.TextXAlignment.Center;
            ZIndex = 153,
            Parent = RgbBoxOuter;
        });

        -- Context Menu
        local ContextMenu = {};
        do
            ContextMenu.Container = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor,
                ZIndex = 160,
                Visible = false,
                Parent = ScreenGui
            });
            Library:ApplyCorner(ContextMenu.Container, 3);
            local CtxStroke = Library:ApplyStroke(ContextMenu.Container, Library.OutlineColor, 1);
            Library:AddToRegistry(ContextMenu.Container, { BackgroundColor3 = 'MainColor' });
            Library:AddToRegistry(CtxStroke, { Color = 'OutlineColor' });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Padding = UDim.new(0, 2);
                Parent = ContextMenu.Container;
            });
            Library:Create('UIPadding', {
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4),
                PaddingBottom = UDim.new(0, 4),
                Parent = ContextMenu.Container,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X + 6,
                    DisplayFrame.AbsolutePosition.Y
                );
            end;
            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition);

            function ContextMenu:Show()
                updateMenuPosition();
                self.Container.Visible = true;
            end;
            function ContextMenu:Hide()
                self.Container.Visible = false;
            end;

            function ContextMenu:AddOption(Str, Callback)
                local Button = Library:Create('TextButton', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 18),
                    Font = Library.FontMedium,
                    TextSize = 11,
                    Text = Str,
                    TextColor3 = Library.FontColor,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 162,
                    Parent = ContextMenu.Container,
                });
                Library:AddToRegistry(Button, { TextColor3 = 'FontColor' });

                Button.MouseEnter:Connect(function()
                    Button.TextColor3 = Library.AccentColor;
                end);
                Button.MouseLeave:Connect(function()
                    Button.TextColor3 = Library.FontColor;
                end);
                Button.MouseButton1Click:Connect(function()
                    ContextMenu:Hide();
                    if Callback then Callback(); end;
                end);
            end;

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value;
                Library:Notify('Copied color!', 2);
            end);
            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('You have not copied a color!', 2);
                end;
                ColorPicker:SetValueRGB(Library.ColorClipboard);
            end);
            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, '#' .. ColorPicker.Value:ToHex());
                Library:Notify('Copied hex code to clipboard!', 2);
            end);
            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({
                    math.floor(ColorPicker.Value.R * 255),
                    math.floor(ColorPicker.Value.G * 255),
                    math.floor(ColorPicker.Value.B * 255)
                }, ', '));
                Library:Notify('Copied RGB values to clipboard!', 2);
            end);

            ContextMenu.Container.Size = UDim2.fromOffset(105, 88);
        end;

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            DisplayFrame.BackgroundColor3 = ColorPicker.Value;
            DisplayFrame.BackgroundTransparency = ColorPicker.Transparency;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex();
            RgbBox.Text = table.concat({
                math.floor(ColorPicker.Value.R * 255),
                math.floor(ColorPicker.Value.G * 255),
                math.floor(ColorPicker.Value.B * 255)
            }, ', ');

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value);
        end;

        function ColorPicker:Show()
            for Frame, _ in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Library.OpenedFrames[Frame] = nil;
                end;
            end;
            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color3.fromHSV(HSV[1], HSV[2], HSV[3]));
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

                    ColorPicker.Hue = (MouseY - MinY) / (MaxY - MinY);
                    ColorPicker:Display();
                    RenderStepped:Wait();
                end;
                Library:AttemptSave();
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide();
                else
                    ContextMenu:Hide();
                    ColorPicker:Show();
                end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show();
                ColorPicker:Hide();
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < AbsPos.Y or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    ColorPicker:Hide();
                end;
                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide();
                end;
            end;
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide();
                end;
            end;
        end));

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame;
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

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' };
            Info.Mode = 'Toggle';
        end;

        -- Segmented Keybind Badge matching reference screenshot: [ - - - 🗔 ]
        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.ControlColor;
            Size = UDim2.new(0, 44, 0, 18);
            ZIndex = 6;
            Parent = ToggleLabel;
        });
        Library:ApplyCorner(PickOuter, 3);
        local PickStroke = Library:ApplyStroke(PickOuter, Library.OutlineColor, 1);
        Library:AddToRegistry(PickOuter, { BackgroundColor3 = 'ControlColor' });
        Library:AddToRegistry(PickStroke, { Color = 'OutlineColor' });

        local PickLayout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 2),
            Parent = PickOuter,
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(0, 24, 1, 0);
            Font = Library.FontMedium;
            TextSize = 10;
            Text = Info.Default == '' or Info.Default == 'None' and '---' or Info.Default;
            TextColor3 = Library.SecondaryFontColor;
            TextXAlignment = Enum.TextXAlignment.Center;
            ZIndex = 7;
            Parent = PickOuter;
        });
        Library:AddToRegistry(DisplayLabel, { TextColor3 = 'SecondaryFontColor' });

        local IconImage = Library:Create('ImageLabel', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 11, 0, 11);
            Image = 'rbxassetid://10734950020';
            ImageColor3 = Library.SecondaryFontColor;
            ZIndex = 7;
            Parent = PickOuter;
        });
        Library:AddToRegistry(IconImage, { ImageColor3 = 'SecondaryFontColor' });

        -- Mode Selection Dropdown
        local ModeSelectOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            Size = UDim2.new(0, 75, 0, 64);
            Visible = false;
            ZIndex = 140;
            Parent = ScreenGui;
        });
        Library:ApplyCorner(ModeSelectOuter, 3);
        local ModeStroke = Library:ApplyStroke(ModeSelectOuter, Library.OutlineColor, 1);
        Library:AddToRegistry(ModeSelectOuter, { BackgroundColor3 = 'MainColor' });
        Library:AddToRegistry(ModeStroke, { Color = 'OutlineColor' });

        local function updateModePos()
            ModeSelectOuter.Position = UDim2.fromOffset(
                PickOuter.AbsolutePosition.X,
                PickOuter.AbsolutePosition.Y + PickOuter.AbsoluteSize.Y + 4
            );
        end;
        PickOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateModePos);

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Padding = UDim.new(0, 2);
            Parent = ModeSelectOuter;
        });
        Library:Create('UIPadding', {
            PaddingLeft = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 4),
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 4),
            Parent = ModeSelectOuter,
        });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 16);
            TextSize = 11;
            Visible = false;
            ZIndex = 110;
            Parent = Library.KeybindContainer;
        }, true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for _, Mode in next, Modes do
            local ModeButton = {};
            local Btn = Library:Create('TextButton', {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                Font = Library.Font,
                TextSize = 11,
                Text = Mode,
                TextColor3 = Library.SecondaryFontColor,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 142,
                Parent = ModeSelectOuter,
            });

            function ModeButton:Select()
                for _, OtherBtn in next, ModeButtons do
                    OtherBtn:Deselect();
                end;
                KeyPicker.Mode = Mode;
                Btn.TextColor3 = Library.AccentColor;
                ModeSelectOuter.Visible = false;
            end;

            function ModeButton:Deselect()
                Btn.TextColor3 = Library.SecondaryFontColor;
            end;

            Btn.MouseButton1Click:Connect(function()
                ModeButton:Select();
                Library:AttemptSave();
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;
            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then return; end;
            local State = KeyPicker:GetState();
            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text or 'Keybind', KeyPicker.Mode);
            ContainerLabel.Visible = true;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;

            local YSize = 0;
            local XSize = 0;
            for _, Label in next, Library.KeybindContainer:GetChildren() do
                if Label:IsA('TextLabel') and Label.Visible then
                    YSize = YSize + 16;
                    if Label.TextBounds.X > XSize then
                        XSize = Label.TextBounds.X;
                    end;
                end;
            end;
            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 16, 180), 0, YSize + 28);
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' or KeyPicker.Value == '' then return false; end;
                local Key = KeyPicker.Value;
                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = (Key == 'None' or Key == '') and '---' or Key;
            KeyPicker.Value = Key;
            if ModeButtons[Mode] then
                ModeButtons[Mode]:Select();
            end;
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback;
        end;

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback;
            Callback(KeyPicker.Value);
        end;

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker);
        end;

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value);
            end;
            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled);
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled);
        end;

        local Picking = false;
        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true;
                DisplayLabel.Text = '...';
                DisplayLabel.TextColor3 = Library.AccentColor;

                task.wait(0.2);
                local Event;
                Event = InputService.InputBegan:Connect(function(Inp)
                    local Key;
                    if Inp.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Inp.KeyCode.Name;
                    elseif Inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Inp.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    end;

                    Picking = false;
                    DisplayLabel.Text = (Key == 'None' or Key == '') and '---' or Key;
                    DisplayLabel.TextColor3 = Library.SecondaryFontColor;
                    KeyPicker.Value = Key;

                    Library:SafeCallback(KeyPicker.ChangedCallback, Inp.KeyCode or Inp.UserInputType);
                    Library:SafeCallback(KeyPicker.Changed, Inp.KeyCode or Inp.UserInputType);
                    Library:AttemptSave();

                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                updateModePos();
                ModeSelectOuter.Visible = not ModeSelectOuter.Visible;
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if not Picking then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;
                    if Key == 'MB1' or Key == 'MB2' then
                        if (Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1)
                        or (Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2) then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick();
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick();
                        end;
                    end;
                end;
                KeyPicker:Update();
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 and ModeSelectOuter.Visible then
                if not Library:IsMouseOverFrame(ModeSelectOuter) and not Library:IsMouseOverFrame(PickOuter) then
                    ModeSelectOuter.Visible = false;
                end;
            end;
        end));

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if not Picking then
                KeyPicker:Update();
            end;
        end));

        KeyPicker:Update();
        Options[Idx] = KeyPicker;
        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};
do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;
        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size or 4);
            ZIndex = 1;
            Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};
        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 16);
            Font = Library.FontBold;
            TextSize = 12;
            Text = Text;
            TextColor3 = Library.FontColor;
            TextWrapped = DoesWrap or false;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });
        Library:AddToRegistry(TextLabel, { TextColor3 = 'FontColor' });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.FontBold, 12, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)));
            TextLabel.Size = UDim2.new(1, 0, 0, Y);
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 6);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                VerticalAlignment = Enum.VerticalAlignment.Center;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end;

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(NewText)
            TextLabel.Text = NewText;
            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(NewText, Library.FontBold, 12, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)));
                TextLabel.Size = UDim2.new(1, 0, 0, Y);
            end;
            Groupbox:Resize();
        end;

        if not DoesWrap then
            setmetatable(Label, BaseAddons);
        end;

        Groupbox:AddBlank(3);
        Groupbox:Resize();
        return Label;
    end;

    function Funcs:AddButton(...)
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...);
            if type(Props) == 'table' then
                Obj.Text = Props.Text;
                Obj.Func = Props.Func;
                Obj.DoubleClick = Props.DoubleClick;
                Obj.Tooltip = Props.Tooltip;
            else
                Obj.Text = select(1, ...);
                Obj.Func = select(2, ...);
            end;
            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end;

        ProcessButtonParams('Button', Button, ...);

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(BtnObj)
            -- Compact dark button matching reference screenshot
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Library.ControlColor;
                Size = UDim2.new(1, 0, 0, 24);
                ZIndex = 5;
            });
            Library:ApplyCorner(Outer, 4);
            local Stroke = Library:ApplyStroke(Outer, Library.OutlineColor, 1);
            Library:AddToRegistry(Outer, { BackgroundColor3 = 'ControlColor' });
            Library:AddToRegistry(Stroke, { Color = 'OutlineColor' });

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                Font = Library.FontMedium;
                TextSize = 12;
                Text = BtnObj.Text;
                TextColor3 = Library.FontColor;
                TextXAlignment = Enum.TextXAlignment.Center;
                ZIndex = 6;
                Parent = Outer;
            });
            Library:AddToRegistry(Label, { TextColor3 = 'FontColor' });

            Outer.MouseEnter:Connect(function()
                Stroke.Color = Library.AccentColor;
                Outer.BackgroundColor3 = Color3.fromRGB(24, 27, 34);
            end);
            Outer.MouseLeave:Connect(function()
                Stroke.Color = Library.OutlineColor;
                Outer.BackgroundColor3 = Library.ControlColor;
            end);

            return Outer, Label;
        end;

        local function InitEvents(BtnObj)
            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then return false; end;
                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return false; end;
                return true;
            end;

            BtnObj.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return; end;
                if BtnObj.Locked then return; end;

                if BtnObj.DoubleClick then
                    BtnObj.Label.TextColor3 = Library.AccentColor;
                    BtnObj.Label.Text = 'Are you sure?';
                    BtnObj.Locked = true;

                    task.delay(1.5, function()
                        if BtnObj.Locked then
                            BtnObj.Label.TextColor3 = Library.FontColor;
                            BtnObj.Label.Text = BtnObj.Text;
                            BtnObj.Locked = false;
                        end;
                    end);
                    return;
                end;

                Library:SafeCallback(BtnObj.Func);
            end);
        end;

        Button.Outer, Button.Label = CreateBaseButton(Button);
        Button.Outer.Parent = Container;
        InitEvents(Button);

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer);
            end;
            return self;
        end;

        function Button:AddButton(...)
            local SubButton = {};
            ProcessButtonParams('SubButton', SubButton, ...);
            self.Outer.Size = UDim2.new(0.5, -3, 0, 24);

            SubButton.Outer, SubButton.Label = CreateBaseButton(SubButton);
            SubButton.Outer.Position = UDim2.new(1, 6, 0, 0);
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X, self.Outer.AbsoluteSize.Y);
            SubButton.Outer.Parent = self.Outer;

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer);
                end;
                return SubButton;
            end;

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip);
            end;

            InitEvents(SubButton);
            return SubButton;
        end;

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip);
        end;

        Groupbox:AddBlank(4);
        Groupbox:Resize();
        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container;
        Groupbox:AddBlank(2);

        local Div = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 5;
            Parent = Container;
        });
        Library:AddToRegistry(Div, { BackgroundColor3 = 'OutlineColor' });

        Groupbox:AddBlank(5);
        Groupbox:Resize();
    end;

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.');
        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Font = Library.FontMedium;
            TextSize = 12;
            Text = Info.Text;
            TextColor3 = Library.FontColor;
            ZIndex = 5;
            Parent = Container;
        });
        Library:AddToRegistry(InputLabel, { TextColor3 = 'FontColor' });

        Groupbox:AddBlank(2);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.ControlColor;
            Size = UDim2.new(1, 0, 0, 24);
            ZIndex = 5;
            Parent = Container;
        });
        Library:ApplyCorner(TextBoxOuter, 4);
        local Stroke = Library:ApplyStroke(TextBoxOuter, Library.OutlineColor, 1);
        Library:AddToRegistry(TextBoxOuter, { BackgroundColor3 = 'ControlColor' });
        Library:AddToRegistry(Stroke, { Color = 'OutlineColor' });

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter);
        end;

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 8, 0, 0);
            Size = UDim2.new(1, -16, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Library.SecondaryFontColor;
            PlaceholderText = Info.Placeholder or '';
            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 12;
            TextStrokeTransparency = 1;
            TextXAlignment = Enum.TextXAlignment.Left;
            ClearTextOnFocus = false;
            ZIndex = 6;
            Parent = TextBoxOuter;
        });
        Library:AddToRegistry(Box, { TextColor3 = 'FontColor' });

        Box.Focused:Connect(function()
            Stroke.Color = Library.AccentColor;
        end);
        Box.FocusLost:Connect(function()
            Stroke.Color = Library.OutlineColor;
        end);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end;
            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then
                    Text = Textbox.Value;
                end;
            end;
            Textbox.Value = Text;
            Box.Text = Text;
            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return; end;
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end;

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(4);
        Groupbox:Resize();
        Options[Idx] = Textbox;
        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddToggle: Missing `Text` string.');
        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';
            Callback = Info.Callback or function(Value) end;
            Addons = {};
            Risky = Info.Risky;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local RowFrame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 18);
            ZIndex = 5;
            Parent = Container;
        });

        -- Compact square checkbox matching reference screenshot: 14x14px, rounded 3px
        local CheckboxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.ControlColor;
            Position = UDim2.new(0, 0, 0.5, -7);
            Size = UDim2.new(0, 14, 0, 14);
            ZIndex = 6;
            Parent = RowFrame;
        });
        Library:ApplyCorner(CheckboxOuter, 3);
        local CheckboxStroke = Library:ApplyStroke(CheckboxOuter, Library.OutlineColor, 1);
        Library:AddToRegistry(CheckboxOuter, { BackgroundColor3 = 'ControlColor' });
        Library:AddToRegistry(CheckboxStroke, { Color = 'OutlineColor' });

        local Checkmark = Library:Create('ImageLabel', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, -2, 1, -2);
            Position = UDim2.fromOffset(1, 1);
            Image = 'rbxassetid://6031094667';
            ImageColor3 = Library.White;
            Visible = false;
            ZIndex = 7;
            Parent = CheckboxOuter;
        });

        local ToggleLabel = Library:CreateLabel({
            Position = UDim2.new(0, 22, 0, 0);
            Size = UDim2.new(1, -22, 1, 0);
            Font = Library.FontMedium;
            TextSize = 12;
            Text = Info.Text;
            TextColor3 = Library.SecondaryFontColor;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = RowFrame;
        });

        -- Layout for Addons on the right (KeyPicker badges, Color circles, Gear icons)
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 5);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            VerticalAlignment = Enum.VerticalAlignment.Center;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        local ClickRegion = Library:Create('TextButton', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Text = '';
            ZIndex = 8;
            Parent = RowFrame;
        });

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ClickRegion);
        end;

        function Toggle:Display()
            if Toggle.Value then
                CheckboxOuter.BackgroundColor3 = Library.AccentColor;
                CheckboxStroke.Color = Library.AccentColor;
                Checkmark.Visible = true;
                ToggleLabel.TextColor3 = Library.White;
                ToggleLabel.Font = Library.FontBold;
            else
                CheckboxOuter.BackgroundColor3 = Library.ControlColor;
                CheckboxStroke.Color = Library.OutlineColor;
                Checkmark.Visible = false;
                ToggleLabel.TextColor3 = Library.SecondaryFontColor;
                ToggleLabel.Font = Library.FontMedium;
            end;
        end;

        function Toggle:UpdateColors()
            Toggle:Display();
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);
            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool;
                    Addon:Update();
                end;
            end;

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ClickRegion.MouseButton1Click:Connect(function()
            if Library:MouseIsOverOpenedFrame() then return; end;
            Toggle:SetValue(not Toggle.Value);
            Library:AttemptSave();
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel);
            ToggleLabel.TextColor3 = Library.RiskColor;
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' });
        end;

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 4);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;
        Library:UpdateDependencyBoxes();
        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        -- Slider row layout matching reference screenshot:
        -- Bold title on left ("Max Distance"), numeric value on right ("500")
        local TitleRow = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 16);
            ZIndex = 5;
            Parent = Container;
        });

        local TitleLabel = Library:CreateLabel({
            Size = UDim2.new(0.7, 0, 1, 0);
            Font = Library.FontBold;
            TextSize = 12;
            Text = Info.Text;
            TextColor3 = Library.FontColor;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = TitleRow;
        });
        Library:AddToRegistry(TitleLabel, { TextColor3 = 'FontColor' });

        local ValueLabel = Library:CreateLabel({
            Size = UDim2.new(0.3, 0, 1, 0);
            Position = UDim2.new(0.7, 0, 0, 0);
            Font = Library.Font;
            TextSize = 12;
            Text = tostring(Info.Default);
            TextColor3 = Library.SecondaryFontColor;
            TextXAlignment = Enum.TextXAlignment.Right;
            ZIndex = 5;
            Parent = TitleRow;
        });
        Library:AddToRegistry(ValueLabel, { TextColor3 = 'SecondaryFontColor' });

        Groupbox:AddBlank(3);

        -- Slider Track matching reference: thin 4px line, blue fill, circular white knob
        local SliderOuter = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 10);
            ZIndex = 5;
            Parent = Container;
        });

        local Track = Library:Create('Frame', {
            BackgroundColor3 = Color3.fromRGB(26, 28, 36);
            Size = UDim2.new(1, 0, 0, 3);
            Position = UDim2.new(0, 0, 0.5, -1);
            BorderSizePixel = 0;
            ZIndex = 6;
            Parent = SliderOuter;
        });
        Library:ApplyCorner(Track, 2);

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = Track;
        });
        Library:ApplyCorner(Fill, 2);
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' });

        -- Circular handle knob (white, centered on end of fill)
        local Handle = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Position = UDim2.new(1, 0, 0.5, 0);
            Size = UDim2.new(0, 10, 0, 10);
            BackgroundColor3 = Library.White;
            ZIndex = 8;
            Parent = Fill;
        });
        Library:ApplyCorner(Handle, 5);
        local HandleStroke = Library:ApplyStroke(Handle, Library.AccentColor, 1);
        Library:AddToRegistry(HandleStroke, { Color = 'AccentColor' });

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter);
        end;

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end;
            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value));
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';
            ValueLabel.Text = tostring(Slider.Value) .. Suffix;
            local Pct = math.clamp((Slider.Value - Slider.Min) / (Slider.Max - Slider.Min), 0, 1);
            Fill.Size = UDim2.new(Pct, 0, 1, 0);
        end;

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
            HandleStroke.Color = Library.AccentColor;
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);
            if not Num then return; end;
            Num = math.clamp(Round(Num), Slider.Min, Slider.Max);
            Slider.Value = Num;
            Slider:Display();
            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SliderOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = Track.AbsolutePosition.X;
                    local MaxX = MinX + Track.AbsoluteSize.X;
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX);
                    local Pct = (MouseX - MinX) / (MaxX - MinX);
                    local nValue = Round(Slider.Min + ((Slider.Max - Slider.Min) * Pct));
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;
                    Slider:Display();

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;
                    RenderStepped:Wait();
                end;
                Library:AttemptSave();
            end;
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Options[Idx] = Slider;
        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.');

        if not Info.Text then
            Info.Compact = true;
        end;

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {} or nil;
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType;
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 14);
                Font = Library.FontBold;
                TextSize = 12;
                Text = Info.Text;
                TextColor3 = Library.FontColor;
                ZIndex = 5;
                Parent = Container;
            });
            Library:AddToRegistry(DropdownLabel, { TextColor3 = 'FontColor' });
            Groupbox:AddBlank(2);
        end;

        -- Dropdown Box matching reference screenshot:
        -- Sleek dark rectangular box, 1px border #1E212A, rounded 4px, chevron down arrow
        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.ControlColor;
            Size = UDim2.new(1, 0, 0, 24);
            Active = true;
            ZIndex = 5;
            Parent = Container;
        });
        Library:ApplyCorner(DropdownOuter, 4);
        local DropdownStroke = Library:ApplyStroke(DropdownOuter, Library.OutlineColor, 1);
        Library:AddToRegistry(DropdownOuter, { BackgroundColor3 = 'ControlColor' });
        Library:AddToRegistry(DropdownStroke, { Color = 'OutlineColor' });

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 8, 0, 0);
            Size = UDim2.new(1, -28, 1, 0);
            Font = Library.FontMedium;
            TextSize = 12;
            Text = '--';
            TextColor3 = Library.FontColor;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextTruncate = Enum.TextTruncate.AtEnd;
            ZIndex = 6;
            Parent = DropdownOuter;
        });
        Library:AddToRegistry(ItemList, { TextColor3 = 'FontColor' });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(1, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -6, 0.5, 0);
            Size = UDim2.new(0, 10, 0, 10);
            Image = 'rbxassetid://6034818372';
            ImageColor3 = Library.SecondaryFontColor;
            ZIndex = 6;
            Parent = DropdownOuter;
        });
        Library:AddToRegistry(DropdownArrow, { ImageColor3 = 'SecondaryFontColor' });

        -- Invisible full-size click button to guarantee 100% reliable dropdown clicks
        local ClickButton = Library:Create('TextButton', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Text = '';
            ZIndex = 8;
            Parent = DropdownOuter;
        });

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ClickButton);
        end;

        local MAX_DROPDOWN_ITEMS = 8;
        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            ZIndex = 140;
            Visible = false;
            Parent = ScreenGui;
        });
        Library:ApplyCorner(ListOuter, 4);
        local ListStroke = Library:ApplyStroke(ListOuter, Library.OutlineColor, 1);
        Library:AddToRegistry(ListOuter, { BackgroundColor3 = 'MainColor' });
        Library:AddToRegistry(ListStroke, { Color = 'OutlineColor' });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(
                DropdownOuter.AbsolutePosition.X,
                DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 2
            );
        end;

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 22 + 4));
        end;

        RecalculateListPosition();
        RecalculateListSize();
        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ScrollBarThickness = 2;
            ScrollBarImageColor3 = Library.AccentColor;
            ZIndex = 141;
            Parent = ListOuter;
        });
        Library:AddToRegistry(Scrolling, { ScrollBarImageColor3 = 'AccentColor' });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 1);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });
        Library:Create('UIPadding', {
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 2),
            PaddingLeft = UDim.new(0, 2),
            PaddingRight = UDim.new(0, 2),
            Parent = Scrolling;
        });

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for _, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;
                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;

            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};
                for Value, _ in next, Dropdown.Value do
                    table.insert(T, Value);
                end;
                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') and not Element:IsA('UIPadding') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;
            for _, Value in next, Values do
                local Table = {};
                Count = Count + 1;

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    Size = UDim2.new(1, 0, 0, 20);
                    ZIndex = 142;
                    Parent = Scrolling;
                });
                Library:ApplyCorner(Button, 3);
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor' });

                local Selected;
                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                local Indicator = Library:Create('Frame', {
                    BackgroundColor3 = Library.AccentColor;
                    Size = UDim2.new(0, 2, 0, 10);
                    Position = UDim2.new(0, 4, 0.5, -5);
                    Visible = not not Selected;
                    BorderSizePixel = 0;
                    ZIndex = 143;
                    Parent = Button;
                });
                Library:ApplyCorner(Indicator, 1);
                Library:AddToRegistry(Indicator, { BackgroundColor3 = 'AccentColor' });

                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2.new(1, -16, 1, 0);
                    Position = UDim2.new(0, 10, 0, 0);
                    Font = Library.FontMedium;
                    TextSize = 11;
                    Text = Value;
                    TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 144;
                    Parent = Button;
                });
                Library:AddToRegistry(ButtonLabel, { TextColor3 = Selected and 'AccentColor' or 'FontColor' });

                Button.MouseEnter:Connect(function()
                    Button.BackgroundColor3 = Library.ControlColor;
                end);
                Button.MouseLeave:Connect(function()
                    Button.BackgroundColor3 = Library.MainColor;
                end);

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;
                    Indicator.Visible = not not Selected;
                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                end;

                local ItemClickBtn = Library:Create('TextButton', {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(1, 0, 1, 0);
                    Text = '';
                    ZIndex = 145;
                    Parent = Button;
                });

                ItemClickBtn.MouseButton1Click:Connect(function()
                    local Try = not Selected;
                    if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        return;
                    end;

                    if Info.Multi then
                        Selected = Try;
                        if Selected then
                            Dropdown.Value[Value] = true;
                        else
                            Dropdown.Value[Value] = nil;
                        end;
                    else
                        Selected = Try;
                        if Selected then
                            Dropdown.Value = Value;
                        else
                            Dropdown.Value = nil;
                        end;
                        for _, OtherButton in next, Buttons do
                            OtherButton:UpdateButton();
                        end;
                    end;

                    Table:UpdateButton();
                    Dropdown:Display();
                    Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                    Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
                    Library:AttemptSave();

                    if not Info.Multi then
                        Dropdown:CloseDropdown();
                    end;
                end);

                Table:UpdateButton();
                Buttons[Button] = Table;
            end;

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 21) + 4);
            local Y = math.clamp(Count * 21 + 4, 24, MAX_DROPDOWN_ITEMS * 21 + 4);
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;
            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            RecalculateListPosition();
            ListOuter.Visible = true;
            Library.OpenedFrames[ListOuter] = true;
            DropdownArrow.Rotation = 180;
            DropdownStroke.Color = Library.AccentColor;
        end;

        function Dropdown:CloseDropdown()
            ListOuter.Visible = false;
            Library.OpenedFrames[ListOuter] = nil;
            DropdownArrow.Rotation = 0;
            DropdownStroke.Color = Library.OutlineColor;
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};
                for Value, _ in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true;
                    end;
                end;
                Dropdown.Value = nTable;
            else
                if not Val then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;
            Dropdown:BuildDropdownList();
            Dropdown:Display();
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        ClickButton.MouseButton1Click:Connect(function()
            if ListOuter.Visible then
                Dropdown:CloseDropdown();
            else
                Dropdown:OpenDropdown();
            end;
        end);

        -- Global click outside listener with safe mouse exclusion for DropdownOuter
        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and ListOuter.Visible then
                if not Library:IsMouseOverFrame(ListOuter) and not Library:IsMouseOverFrame(DropdownOuter) then
                    Dropdown:CloseDropdown();
                end;
            end;
        end));

        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {};
        if type(Info.Default) == 'string' then
            local IdxFound = table.find(Dropdown.Values, Info.Default);
            if IdxFound then table.insert(Defaults, IdxFound); end;
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local IdxFound = table.find(Dropdown.Values, Value);
                if IdxFound then table.insert(Defaults, IdxFound); end;
            end;
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default);
        end;

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i];
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true;
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end;
                if not Info.Multi then break; end;
            end;
            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end;

        Groupbox:AddBlank(Info.BlankSize or 4);
        Groupbox:Resize();
        Options[Idx] = Dropdown;
        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = { Dependencies = {} };
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });

        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);
        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];
                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end;
            Holder.Visible = true;
            Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not a table.');
                assert(Dependency[1], 'SetupDependencies: Missing element.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Missing value.');
            end;
            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;
        setmetatable(Depbox, BaseGroupbox);
        table.insert(Library.DependencyBoxes, Depbox);
        return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

-- Overlays & HUD Elements
do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 16, 0, 50);
        Size = UDim2.new(0, 260, 0, 300);
        ZIndex = 120;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 6);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    local WatermarkOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        Position = UDim2.new(0, 100, 0, 10);
        Size = UDim2.new(0, 180, 0, 22);
        ZIndex = 120;
        Visible = false;
        Parent = ScreenGui;
    });
    Library:ApplyCorner(WatermarkOuter, 3);
    local WatermarkStroke = Library:ApplyStroke(WatermarkOuter, Library.OutlineColor, 1);
    Library:AddToRegistry(WatermarkOuter, { BackgroundColor3 = 'MainColor' });
    Library:AddToRegistry(WatermarkStroke, { Color = 'OutlineColor' });

    local WatermarkIndicator = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(0, 2, 1, -4);
        Position = UDim2.new(0, 2, 0, 2);
        ZIndex = 121;
        Parent = WatermarkOuter;
    });
    Library:ApplyCorner(WatermarkIndicator, 1);
    Library:AddToRegistry(WatermarkIndicator, { BackgroundColor3 = 'AccentColor' });

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 8, 0, 0);
        Size = UDim2.new(1, -10, 1, 0);
        Font = Library.FontMedium;
        TextSize = 11;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 122;
        Parent = WatermarkOuter;
    });

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);

    -- Keybind List Window
    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundColor3 = Library.MainColor;
        Position = UDim2.new(0, 16, 0.5, 0);
        Size = UDim2.new(0, 180, 0, 26);
        Visible = false;
        ZIndex = 120;
        Parent = ScreenGui;
    });
    Library:ApplyCorner(KeybindOuter, 3);
    local KeybindStroke = Library:ApplyStroke(KeybindOuter, Library.OutlineColor, 1);
    Library:AddToRegistry(KeybindOuter, { BackgroundColor3 = 'MainColor' });
    Library:AddToRegistry(KeybindStroke, { Color = 'OutlineColor' });

    local KeybindIndicator = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, -6, 0, 2);
        Position = UDim2.new(0, 3, 0, 0);
        ZIndex = 121;
        Parent = KeybindOuter;
    });
    Library:ApplyCorner(KeybindIndicator, 1);
    Library:AddToRegistry(KeybindIndicator, { BackgroundColor3 = 'AccentColor' });

    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 22);
        Position = UDim2.fromOffset(8, 2);
        Font = Library.FontBold;
        TextSize = 11;
        TextXAlignment = Enum.TextXAlignment.Left;
        Text = 'Keybinds';
        ZIndex = 122;
        Parent = KeybindOuter;
    });

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -24);
        Position = UDim2.new(0, 0, 0, 24);
        ZIndex = 121;
        Parent = KeybindOuter;
    });
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Padding = UDim.new(0, 2);
        Parent = KeybindContainer;
    });
    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 4),
        Parent = KeybindContainer,
    });

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.FontMedium, 11);
    Library.Watermark.Size = UDim2.new(0, X + 18, 0, 22);
    Library:SetWatermarkVisibility(true);
    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.FontMedium, 11);
    YSize = math.max(YSize + 12, 26);

    local NotifyOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        Size = UDim2.new(0, 0, 0, YSize);
        ClipsDescendants = true;
        ZIndex = 130;
        Parent = Library.NotificationArea;
    });
    Library:ApplyCorner(NotifyOuter, 3);
    local NotifyStroke = Library:ApplyStroke(NotifyOuter, Library.OutlineColor, 1);
    Library:AddToRegistry(NotifyOuter, { BackgroundColor3 = 'MainColor' });
    Library:AddToRegistry(NotifyStroke, { Color = 'OutlineColor' });

    local LeftColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(0, 2, 1, 0);
        ZIndex = 131;
        Parent = NotifyOuter;
    });
    Library:ApplyCorner(LeftColor, 1);
    Library:AddToRegistry(LeftColor, { BackgroundColor3 = 'AccentColor' });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 8, 0, 0);
        Size = UDim2.new(1, -12, 1, 0);
        Font = Library.FontMedium;
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 11;
        ZIndex = 132;
        Parent = NotifyOuter;
    });

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 20, 0, YSize), 'Out', 'Quad', 0.2, true);

    task.spawn(function()
        task.wait(Time or 5);
        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.2, true);
        task.wait(0.2);
        NotifyOuter:Destroy();
    end);
end;

-- Main Window Creation (Exact 1:1 Replica of Reference Image with Blue Accent Theme)
function Library:CreateWindow(...)
    local Arguments = { ... };
    local Config = { AnchorPoint = Vector2.zero };

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1];
        Config.AutoShow = Arguments[2] or false;
    end;

    if type(Config.Title) ~= 'string' then Config.Title = 'Kronium'; end;
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 12; end;
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2; end;

    -- Proportions matching reference screenshot (~600 x 590)
    local WindowBaseSize = Vector2.new(600, 590);
    if typeof(Config.Size) == 'UDim2' then
        WindowBaseSize = Vector2.new(Config.Size.X.Offset, Config.Size.Y.Offset);
    end;

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(200, 80); end;
    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5);
        Config.Position = UDim2.fromScale(0.5, 0.5);
    end;

    local Window = {
        Tabs = {};
        CurrentTab = nil;
        BaseSize = WindowBaseSize;
    };
    Library.Window = Window;

    -- Outer Window Frame: #0A0A0C, 1px border #1E212A, crisp sharp desktop aesthetic
    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Library.BackgroundColor,
        Position = Config.Position,
        Size = UDim2.fromOffset(WindowBaseSize.X * Library.DPIScale, WindowBaseSize.Y * Library.DPIScale),
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 1,
        Parent = ScreenGui,
    });
    Library:ApplyCorner(Outer, 2);
    local WindowStroke = Library:ApplyStroke(Outer, Library.OutlineColor, 1);
    Library:AddToRegistry(Outer, { BackgroundColor3 = 'BackgroundColor' });
    Library:AddToRegistry(WindowStroke, { Color = 'OutlineColor' });

    Library:MakeDraggable(Outer, 40);

    -- 1. TOP NAVIGATION BAR (Height 38px, matching reference screenshot)
    local TopBar = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 38),
        ZIndex = 2,
        Parent = Outer,
    });
    Library:AddToRegistry(TopBar, { BackgroundColor3 = 'BackgroundColor' });

    -- Top bar bottom separator line (#1E212A)
    local TopBarSeparator = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 3,
        Parent = TopBar,
    });
    Library:AddToRegistry(TopBarSeparator, { BackgroundColor3 = 'OutlineColor' });

    -- Far Left Logo Section: 36px wide with vertical separator line on the right
    local LogoSection = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0, 38, 1, 0),
        ZIndex = 4,
        Parent = TopBar,
    });

    local LogoHolder = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, -9, 0.5, -9),
        Size = UDim2.new(0, 18, 0, 18),
        ZIndex = 5,
        Parent = LogoSection,
    });
    Window.LogoHolder = LogoHolder;

    -- Vertical separator line between Logo and Search
    local LogoDivider = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        ZIndex = 4,
        Parent = LogoSection,
    });
    Library:AddToRegistry(LogoDivider, { BackgroundColor3 = 'OutlineColor' });

    -- Inline Search Bar Container next to logo divider
    local SearchContainer = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 44, 0.5, -10),
        Size = UDim2.new(0, 95, 0, 20),
        ZIndex = 4,
        Parent = TopBar,
    });

    local SearchIcon = Library:Create('ImageLabel', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0.5, -5),
        Size = UDim2.new(0, 10, 0, 10),
        Image = 'rbxassetid://6031154871',
        ImageColor3 = Library.SecondaryFontColor,
        ZIndex = 5,
        Parent = SearchContainer,
    });
    Library:AddToRegistry(SearchIcon, { ImageColor3 = 'SecondaryFontColor' });

    local SearchBox = Library:Create('TextBox', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -16, 1, 0),
        Font = Library.Font,
        PlaceholderColor3 = Library.SecondaryFontColor,
        PlaceholderText = 'Search...',
        Text = '',
        TextColor3 = Library.FontColor,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 5,
        Parent = SearchContainer,
    });
    Library:AddToRegistry(SearchBox, { TextColor3 = 'FontColor' });

    -- Horizontal Navigation Tabs Container (Auto-sized / smoothly scrollable so NO tabs are ever cut off)
    local TabArea = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 145, 0, 0),
        Size = UDim2.new(1, -150, 1, -1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 0,
        ClipsDescendants = true,
        ZIndex = 4,
        Parent = TopBar,
    });

    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding or 12),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabArea,
    });

    TabListLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        TabArea.CanvasSize = UDim2.fromOffset(TabListLayout.AbsoluteContentSize.X + 10, 0);
    end);

    -- 2. SECONDARY SUBTAB BAR (Positioned below TopBar, ~30px height, matching [ General ] [ Weapons ])
    local SubNavContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 38),
        Size = UDim2.new(1, 0, 0, 34),
        Visible = false,
        ZIndex = 2,
        Parent = Outer,
    });
    Library:AddToRegistry(SubNavContainer, { BackgroundColor3 = 'BackgroundColor' });

    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 14),
        PaddingTop = UDim.new(0, 4),
        Parent = SubNavContainer,
    });

    -- 3. MAIN CONTENT CONTAINER (Houses all tabs)
    local MainContent = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 44),
        Size = UDim2.new(1, -28, 1, -76),
        ZIndex = 2,
        Parent = Outer,
    });

    -- 4. FOOTER BAR (Height 32px at bottom, matching reference: Globe + English)
    local FooterBar = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -30),
        Size = UDim2.new(1, 0, 0, 30),
        ZIndex = 2,
        Parent = Outer,
    });
    Library:AddToRegistry(FooterBar, { BackgroundColor3 = 'BackgroundColor' });

    -- Footer top separator line (#1E212A)
    local FooterSeparator = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 3,
        Parent = FooterBar,
    });
    Library:AddToRegistry(FooterSeparator, { BackgroundColor3 = 'OutlineColor' });

    local GlobeIcon = Library:Create('ImageLabel', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0.5, -6),
        Size = UDim2.new(0, 13, 0, 13),
        Image = 'rbxassetid://10734950309',
        ImageColor3 = Library.SecondaryFontColor,
        ZIndex = 4,
        Parent = FooterBar,
    });
    Library:AddToRegistry(GlobeIcon, { ImageColor3 = 'SecondaryFontColor' });

    local FooterText = Library:CreateLabel({
        Position = UDim2.new(0, 32, 0, 0),
        Size = UDim2.new(0, 150, 1, 0),
        Font = Library.FontBold,
        TextSize = 12,
        Text = 'English',
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
        Parent = FooterBar,
    });
    Library:AddToRegistry(FooterText, { TextColor3 = 'FontColor' });

    function Window:SetWindowTitle(Title)
    end;

    -- Icon map for automatic tab icons matching reference screenshot
    local TabIcons = {
        ['aimbot'] = 'rbxassetid://10734888252',
        ['combat'] = 'rbxassetid://10734888252',
        ['visuals'] = 'rbxassetid://10723346959',
        ['esp'] = 'rbxassetid://10723346959',
        ['misc'] = 'rbxassetid://10734950309',
        ['world'] = 'rbxassetid://10734950309',
        ['settings'] = 'rbxassetid://10734950020',
        ['configs'] = 'rbxassetid://10734950020',
        ['player'] = 'rbxassetid://10747373176',
        ['players'] = 'rbxassetid://10747373176',
        ['main'] = 'rbxassetid://10734950309',
        ['outfits'] = 'rbxassetid://10734950309',
        ['autofarm'] = 'rbxassetid://10709790644',
        ['exploits'] = 'rbxassetid://10734950309',
    };

    function Window:AddTab(Name, CustomIcon)
        local Tab = {
            Name = Name,
            Groupboxes = {},
            Tabboxes = {},
            SubTabs = {},
            CurrentSubTab = nil,
        };

        local CleanName = Name:gsub('<[^>]->', ''):lower();
        local IconId = CustomIcon or TabIcons[CleanName] or 'rbxassetid://10734950309';
        local TabTextWidth = Library:GetTextBounds(Name:gsub('<[^>]->', ''), Library.FontBold, 12);
        local TabWidth = TabTextWidth + 22;

        -- Main Navigation Tab Button
        local TabButton = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, TabWidth, 1, 0),
            ZIndex = 5,
            Parent = TabArea,
        });

        local TabIcon = Library:Create('ImageLabel', {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0.5, -6),
            Size = UDim2.new(0, 13, 0, 13),
            Image = IconId,
            ImageColor3 = Library.SecondaryFontColor,
            ZIndex = 6,
            Parent = TabButton,
        });

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 18, 0, 0),
            Size = UDim2.new(1, -18, 1, 0),
            Font = Library.FontBold,
            TextSize = 12,
            Text = Name,
            TextColor3 = Library.SecondaryFontColor,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6,
            Parent = TabButton,
        });

        -- Thin Blue Underline Indicator underneath active tab matching reference screenshot
        local TabIndicator = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 1, -2),
            Size = UDim2.new(1, 0, 0, 2),
            Visible = false,
            ZIndex = 7,
            Parent = TabButton,
        });
        Library:AddToRegistry(TabIndicator, { BackgroundColor3 = 'AccentColor' });

        local TabClickBtn = Library:Create('TextButton', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = '',
            ZIndex = 8,
            Parent = TabButton,
        });

        -- Primary Tab Frame (Houses two-column layout)
        local TabFrame = Library:Create('Frame', {
            Name = Name .. '_TabFrame',
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Visible = false,
            ZIndex = 2,
            Parent = MainContent,
        });
        Tab.TabFrame = TabFrame;

        -- SubTab buttons holder for this tab
        local SubTabButtonsHolder = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Visible = false,
            Parent = SubNavContainer,
        });
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 6),
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = SubTabButtonsHolder,
        });
        Tab.SubTabButtonsHolder = SubTabButtonsHolder;

        local ContentHolder = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Parent = TabFrame,
        });
        Tab.ContentHolder = ContentHolder;

        -- Two-Column Layout Setup (~48.5% Left, ~49.5% Right, gap 12px, hidden scrollbars)
        local function SetupTwoColumnLayout(ParentContainer)
            local LeftSide = Library:Create('ScrollingFrame', {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0.5, -6, 1, 0),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 0,
                ZIndex = 2,
                Parent = ParentContainer,
            });

            local RightSide = Library:Create('ScrollingFrame', {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.new(0.5, 6, 0, 0),
                Size = UDim2.new(0.5, -6, 1, 0),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 0,
                ZIndex = 2,
                Parent = ParentContainer,
            });

            local LeftLayout = Library:Create('UIListLayout', {
                Padding = UDim.new(0, 10),
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Parent = LeftSide,
            });

            local RightLayout = Library:Create('UIListLayout', {
                Padding = UDim.new(0, 10),
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Parent = RightSide,
            });

            LeftLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                LeftSide.CanvasSize = UDim2.fromOffset(0, LeftLayout.AbsoluteContentSize.Y + 8);
            end);
            RightLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                RightSide.CanvasSize = UDim2.fromOffset(0, RightLayout.AbsoluteContentSize.Y + 8);
            end);

            return LeftSide, RightSide;
        end;

        local LeftSide, RightSide = SetupTwoColumnLayout(ContentHolder);
        Tab.LeftSide = LeftSide;
        Tab.RightSide = RightSide;

        function Tab:ShowTab()
            for _, OtherTab in next, Window.Tabs do
                OtherTab:HideTab();
            end;

            Window.CurrentTab = Tab;
            TabButtonLabel.TextColor3 = Library.White;
            TabIcon.ImageColor3 = Library.AccentColor;
            TabIndicator.Visible = true;
            TabFrame.Visible = true;

            local HasSubTabs = #SubTabButtonsHolder:GetChildren() > 1;
            if HasSubTabs then
                SubNavContainer.Visible = true;
                SubTabButtonsHolder.Visible = true;
                MainContent.Position = UDim2.new(0, 14, 0, 74);
                MainContent.Size = UDim2.new(1, -28, 1, -106);
            else
                SubNavContainer.Visible = false;
                SubTabButtonsHolder.Visible = false;
                MainContent.Position = UDim2.new(0, 14, 0, 44);
                MainContent.Size = UDim2.new(1, -28, 1, -76);
            end;
        end;

        function Tab:HideTab()
            TabButtonLabel.TextColor3 = Library.SecondaryFontColor;
            TabIcon.ImageColor3 = Library.SecondaryFontColor;
            TabIndicator.Visible = false;
            TabFrame.Visible = false;
            SubTabButtonsHolder.Visible = false;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
        end;

        -- Helper to create groupbox matching reference image:
        -- Section Header (Aim Modifications ^) + dark card with 1px subtle border #1E212A
        local function CreateGroupboxOnTarget(TargetSide, Info)
            local Groupbox = {};

            local SectionContainer = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 80),
                ZIndex = 2,
                Parent = TargetSide,
            });

            -- Header: Section Title + Chevron ^
            local HeaderRow = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(1, 0, 0, 16),
                ZIndex = 3,
                Parent = SectionContainer,
            });

            local HeaderLabel = Library:CreateLabel({
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(1, -20, 1, 0),
                Font = Library.FontBold,
                TextSize = 12,
                Text = Info.Name,
                TextColor3 = Library.FontColor,
                ZIndex = 4,
                Parent = HeaderRow,
            });
            Library:AddToRegistry(HeaderLabel, { TextColor3 = 'FontColor' });

            local Chevron = Library:Create('ImageLabel', {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -2, 0.5, 0),
                Size = UDim2.new(0, 9, 0, 9),
                Image = 'rbxassetid://6034818372',
                ImageColor3 = Library.MutedFontColor,
                Rotation = 180,
                ZIndex = 4,
                Parent = HeaderRow,
            });

            -- Panel Card Body: #0C0D10, 1px border #1E212A, rounded 4px
            local CardOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor,
                Position = UDim2.new(0, 0, 0, 20),
                Size = UDim2.new(1, 0, 1, -20),
                ZIndex = 3,
                Parent = SectionContainer,
            });
            Library:ApplyCorner(CardOuter, 4);
            local CardStroke = Library:ApplyStroke(CardOuter, Library.OutlineColor, 1);
            Library:AddToRegistry(CardOuter, { BackgroundColor3 = 'MainColor' });
            Library:AddToRegistry(CardStroke, { Color = 'OutlineColor' });

            local InnerContainer = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 8),
                Size = UDim2.new(1, -16, 1, -16),
                ZIndex = 4,
                Parent = CardOuter,
            });

            local Layout = Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 3),
                Parent = InnerContainer,
            });

            function Groupbox:Resize()
                local ContentSize = Layout.AbsoluteContentSize.Y;
                SectionContainer.Size = UDim2.new(1, 0, 0, ContentSize + 36);
            end;

            Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Groupbox:Resize();
            end);

            Groupbox.Container = InnerContainer;
            setmetatable(Groupbox, BaseGroupbox);

            Groupbox:AddBlank(2);
            Groupbox:Resize();
            return Groupbox;
        end;

        function Tab:AddGroupbox(Info)
            local Target = Info.Side == 1 and LeftSide or RightSide;
            local Groupbox = CreateGroupboxOnTarget(Target, Info);
            Tab.Groupboxes[Info.Name] = Groupbox;
            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1, Name = Name });
        end;

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2, Name = Name });
        end;

        -- Tabbox (Subtabs inside columns matching [ General ] [ Weapons ] pill style)
        function Tab:AddTabbox(Info)
            local Tabbox = { Tabs = {} };
            local Target = Info.Side == 1 and LeftSide or RightSide;

            local SectionContainer = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 80),
                ZIndex = 2,
                Parent = Target,
            });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 24),
                ZIndex = 4,
                Parent = SectionContainer,
            });
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
                Parent = TabboxButtons,
            });

            local CardOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor,
                Position = UDim2.new(0, 0, 0, 28),
                Size = UDim2.new(1, 0, 1, -28),
                ZIndex = 3,
                Parent = SectionContainer,
            });
            Library:ApplyCorner(CardOuter, 4);
            local CardStroke = Library:ApplyStroke(CardOuter, Library.OutlineColor, 1);
            Library:AddToRegistry(CardOuter, { BackgroundColor3 = 'MainColor' });
            Library:AddToRegistry(CardStroke, { Color = 'OutlineColor' });

            function Tabbox:AddTab(SubTabName)
                local SubTab = {};

                local TextW = Library:GetTextBounds(SubTabName, Library.FontBold, 12);
                local Btn = Library:Create('Frame', {
                    BackgroundColor3 = Library.ControlColor,
                    Size = UDim2.new(0, TextW + 20, 1, 0),
                    ZIndex = 5,
                    Parent = TabboxButtons,
                });
                Library:ApplyCorner(Btn, 3);
                local BtnStroke = Library:ApplyStroke(Btn, Library.OutlineColor, 1);

                local BtnLabel = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0),
                    Font = Library.FontBold,
                    TextSize = 12,
                    Text = SubTabName,
                    TextColor3 = Library.SecondaryFontColor,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 6,
                    Parent = Btn,
                });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 8, 0, 8),
                    Size = UDim2.new(1, -16, 1, -16),
                    Visible = false,
                    ZIndex = 4,
                    Parent = CardOuter,
                });

                local Layout = Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 3),
                    Parent = Container,
                });

                function SubTab:Resize()
                    if not Container.Visible then return; end;
                    SectionContainer.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y + 44);
                end;

                Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                    SubTab:Resize();
                end);

                function SubTab:Show()
                    for _, Other in next, Tabbox.Tabs do
                        Other:Hide();
                    end;
                    Container.Visible = true;
                    Btn.BackgroundColor3 = Color3.fromRGB(18, 20, 24);
                    BtnStroke.Color = Color3.fromRGB(58, 63, 77);
                    BtnLabel.TextColor3 = Library.White;
                    SubTab:Resize();
                end;

                function SubTab:Hide()
                    Container.Visible = false;
                    Btn.BackgroundColor3 = Library.ControlColor;
                    BtnStroke.Color = Library.OutlineColor;
                    BtnLabel.TextColor3 = Library.SecondaryFontColor;
                end;

                local ClickArea = Library:Create('TextButton', {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Text = '',
                    ZIndex = 7,
                    Parent = Btn,
                });
                ClickArea.MouseButton1Click:Connect(function()
                    SubTab:Show();
                end);

                SubTab.Container = Container;
                setmetatable(SubTab, BaseGroupbox);
                SubTab:AddBlank(2);

                Tabbox.Tabs[SubTabName] = SubTab;
                if #TabboxButtons:GetChildren() == 2 then
                    SubTab:Show();
                end;
                return SubTab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;
            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1 });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2 });
        end;

        -- Secondary Subtab Support directly on Tab (e.g. Tab:AddSubTab('General'))
        function Tab:AddSubTab(SubName)
            local Sub = {
                Groupboxes = {},
                Tabboxes = {},
            };

            local TextW = Library:GetTextBounds(SubName, Library.FontBold, 12);
            local SubBtn = Library:Create('Frame', {
                BackgroundColor3 = Library.ControlColor,
                Size = UDim2.new(0, TextW + 20, 0, 24),
                ZIndex = 5,
                Parent = SubTabButtonsHolder,
            });
            Library:ApplyCorner(SubBtn, 3);
            local SubBtnStroke = Library:ApplyStroke(SubBtn, Library.OutlineColor, 1);

            local SubBtnLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0),
                Font = Library.FontBold,
                TextSize = 12,
                Text = SubName,
                TextColor3 = Library.SecondaryFontColor,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 6,
                Parent = SubBtn,
            });

            local SubContent = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Visible = false,
                Parent = ContentHolder,
            });

            local SubLeft, SubRight = SetupTwoColumnLayout(SubContent);
            Sub.LeftSide = SubLeft;
            Sub.RightSide = SubRight;

            function Sub:Show()
                for _, OtherSub in next, Tab.SubTabs do
                    OtherSub:Hide();
                end;
                Tab.CurrentSubTab = Sub;
                SubContent.Visible = true;
                SubBtn.BackgroundColor3 = Color3.fromRGB(18, 20, 24);
                SubBtnStroke.Color = Color3.fromRGB(58, 63, 77);
                SubBtnLabel.TextColor3 = Library.White;
            end;

            function Sub:Hide()
                SubContent.Visible = false;
                SubBtn.BackgroundColor3 = Library.ControlColor;
                SubBtnStroke.Color = Library.OutlineColor;
                SubBtnLabel.TextColor3 = Library.SecondaryFontColor;
            end;

            local ClickArea = Library:Create('TextButton', {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = '',
                ZIndex = 7,
                Parent = SubBtn,
            });
            ClickArea.MouseButton1Click:Connect(function()
                Sub:Show();
            end);

            function Sub:AddGroupbox(Info)
                local Target = Info.Side == 1 and SubLeft or SubRight;
                local Groupbox = CreateGroupboxOnTarget(Target, Info);
                Sub.Groupboxes[Info.Name] = Groupbox;
                return Groupbox;
            end;

            function Sub:AddLeftGroupbox(Name)
                return Sub:AddGroupbox({ Side = 1, Name = Name });
            end;

            function Sub:AddRightGroupbox(Name)
                return Sub:AddGroupbox({ Side = 2, Name = Name });
            end;

            Tab.SubTabs[SubName] = Sub;
            if #SubTabButtonsHolder:GetChildren() == 2 then
                Sub:Show();
            end;

            return Sub;
        end;

        TabClickBtn.MouseButton1Click:Connect(function()
            Tab:ShowTab();
        end);

        if #MainContent:GetChildren() == 1 then
            Tab:ShowTab();
        end;

        Window.Tabs[Name] = Tab;
        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, 0),
        Visible = true,
        Text = '',
        Modal = false,
        Parent = ScreenGui,
    });

    local TransparencyCache = {};
    local Toggled = false;
    local Fading = false;

    function Library:Toggle()
        if Fading then return; end;
        local FadeTime = Config.MenuFadeTime or 0.2;
        Fading = true;
        Toggled = not Toggled;
        ModalElement.Modal = Toggled;

        if Toggled then
            Outer.Visible = true;
        end;

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {};
            if Desc:IsA('ImageLabel') then
                table.insert(Properties, 'ImageTransparency');
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
                table.insert(Properties, 'TextTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') then
                table.insert(Properties, 'Transparency');
            end;

            local Cache = TransparencyCache[Desc];
            if not Cache then
                Cache = {};
                TransparencyCache[Desc] = Cache;
            end;

            for _, Prop in next, Properties do
                if not Cache[Prop] then
                    Cache[Prop] = Desc[Prop];
                end;
                if Cache[Prop] == 1 then
                    continue;
                end;
                TweenService:Create(
                    Desc,
                    TweenInfo.new(FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { [Prop] = Toggled and Cache[Prop] or 1 }
                ):Play();
            end;
        end;

        task.wait(FadeTime);
        Outer.Visible = Toggled;
        Fading = false;
    end;

    -- Toggle keybind handling (supports KeyPicker table, Enum.KeyCode, or string)
    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        local Key = Library.ToggleKeybind;
        if type(Key) == 'table' and Key.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key.Value then
                task.spawn(Library.Toggle);
            end;
        elseif typeof(Key) == 'EnumItem' then
            if Input.KeyCode == Key then
                task.spawn(Library.Toggle);
            end;
        elseif type(Key) == 'string' and Key ~= '' then
            if Input.KeyCode.Name == Key then
                task.spawn(Library.Toggle);
            end;
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle);
        end;
    end));

    if Config.AutoShow then
        task.spawn(Library.Toggle);
    end;

    Window.Holder = Outer;
    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();
    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;

Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().Library = Library;
return Library;
