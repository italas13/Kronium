local cloneref = (cloneref or clonereference or function(instance: any) return instance end)
local InputService: UserInputService = cloneref(game:GetService('UserInputService'));
local TextService: TextService = cloneref(game:GetService('TextService'));
local CoreGui: CoreGui = cloneref(game:GetService('CoreGui'));
local Teams: Teams = cloneref(game:GetService('Teams'));
local Players: Players = cloneref(game:GetService('Players'));
local RunService: RunService = cloneref(game:GetService('RunService'));
local TweenService: TweenService = cloneref(game:GetService('TweenService'));
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local DrawingLib = typeof(Drawing) == "table" and Drawing or { drawing_replaced = true };
local ProtectGui = protectgui or (function() end);
local GetHUI = gethui or (function() return CoreGui end);
local IsBadDrawingLib = false;

local function GenerateRandomName()
    local length = math.random(12, 24); local array = {}
    for i = 1, length do array[i] = string.char(math.random(97, 122)) end
    return table.concat(array)
end

local function SafeParentUI(Instance: Instance, Parent: Instance | () -> Instance)
    if not pcall(function()
        local D = typeof(Parent) == "function" and Parent() or Parent
        Instance.Parent = D
    end) then Instance.Parent = LocalPlayer:WaitForChild("PlayerGui", math.huge) end
end

local function ParentUI(UI: Instance, SkipHiddenUI: boolean?)
    UI.Name = GenerateRandomName()
    local hasGetHUI, hui = pcall(GetHUI)
    local TargetParent = (hasGetHUI and hui and hui ~= CoreGui) and hui or (LocalPlayer:WaitForChild("PlayerGui", 5) or CoreGui)
    pcall(ProtectGui, UI)
    SafeParentUI(UI, TargetParent)
end

local ScreenGui = Instance.new('ScreenGui');
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.DisplayOrder = 999;
ScreenGui.ResetOnSpawn = false;
ParentUI(ScreenGui);

local ModalScreenGui = Instance.new("ScreenGui");
ModalScreenGui.DisplayOrder = 999;
ModalScreenGui.ResetOnSpawn = false;
ParentUI(ModalScreenGui);

local ModalElement = Instance.new("TextButton");
ModalElement.BackgroundTransparency = 1; ModalElement.Modal = false;
ModalElement.Size = UDim2.fromScale(0, 0); ModalElement.Text = ""; ModalElement.ZIndex = -999;
ModalElement.Parent = ModalScreenGui;

local Toggles = {}; local Options = {}; local Labels = {}; local Buttons = {};

getgenv().Linoria = { Toggles=Toggles; Options=Options; Labels=Labels; Buttons=Buttons; };
getgenv().Toggles=Toggles; getgenv().Options=Options; getgenv().Labels=Labels; getgenv().Buttons=Buttons;

local LibraryMainOuterFrame = nil;
local Library = {
    Registry = {}; RegistryMap = {}; HudRegistry = {};

    -- Redesigned: orange dark theme
    FontColor           = Color3.fromRGB(220, 224, 232);
    MainColor           = Color3.fromRGB(17, 18, 23);
    BackgroundColor     = Color3.fromRGB(11, 12, 15);
    AccentColor         = Color3.fromRGB(255, 120, 0);
    DisabledAccentColor = Color3.fromRGB(65, 70, 82);
    OutlineColor        = Color3.fromRGB(36, 38, 48);
    DisabledOutlineColor= Color3.fromRGB(50, 54, 66);
    DisabledTextColor   = Color3.fromRGB(90, 98, 115);
    RiskColor           = Color3.fromRGB(255, 50, 50);
    Black               = Color3.new(0, 0, 0);
    Font                = Enum.Font.Code;

    OpenedFrames = {}; DependencyBoxes = {}; UnloadSignals = {}; Signals = {};
    ScreenGui = ScreenGui; ActiveTab = nil; Toggled = false; IsMobile = false;
    DevicePlatform = Enum.Platform.None; CanDrag = true; CantDragForced = false;
    NotifySide = "Left"; ShowCustomCursor = true; ShowToggleFrameInKeybinds = true;
    NotifyOnError = false; VideoLink = ""; TotalTabs = 0;
    Toggles = Toggles; Options = Options; Labels = Labels; Buttons = Buttons;
};

pcall(function() Library.DevicePlatform = InputService:GetPlatform(); end);
Library.IsMobile = (Library.DevicePlatform == Enum.Platform.Android or Library.DevicePlatform == Enum.Platform.IOS);
Library.MinSize = if Library.IsMobile then Vector2.new(550, 200) else Vector2.new(550, 300);

local RainbowStep = 0; local Hue = 0; local DPIScale = 1;

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta
    if RainbowStep >= (1/60) then
        RainbowStep = 0; Hue = Hue + (1/400);
        if Hue > 1 then Hue = 0 end
        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end));

local function ApplyDPIScale(Position)
    return UDim2.new(Position.X.Scale, Position.X.Offset*DPIScale, Position.Y.Scale, Position.Y.Offset*DPIScale);
end
local function ApplyTextScale(TextSize) return TextSize*DPIScale end

local function GetTableSize(t)
    local n = 0; for _ in pairs(t) do n=n+1 end; return n;
end

local function GetPlayers(ExcludeLocalPlayer, ReturnInstances)
    local PlayerList = Players:GetPlayers();
    if ExcludeLocalPlayer then
        local Idx = table.find(PlayerList, LocalPlayer);
        if Idx then table.remove(PlayerList, Idx) end
    end
    table.sort(PlayerList, function(a,b) return a.Name:lower() < b.Name:lower() end)
    if ReturnInstances then return PlayerList end
    local F = {}; for _,p in next, PlayerList do F[#F+1]=p.Name end; return F;
end

local function GetTeams(ReturnInstances)
    local TeamList = Teams:GetTeams();
    table.sort(TeamList, function(a,b) return a.Name:lower() < b.Name:lower() end)
    if ReturnInstances then return TeamList end
    local F = {}; for _,t in next, TeamList do F[#F+1]=t.Name end; return F;
end

function Library:SetDPIScale(value: number)
    assert(type(value)=="number", "Expected type number for DPI scale but got "..typeof(value))
    DPIScale = value/100;
    Library.MinSize = (if Library.IsMobile then Vector2.new(550,200) else Vector2.new(550,300))*DPIScale;
end

function Library:SafeCallback(Func, ...)
    if not (Func and typeof(Func)=="function") then return end
    local function run(func, ...)
        local Success, Response = pcall(func, ...)
        if Success then return Response end
        local Traceback = debug.traceback():gsub("\n"," ")
        local _,i = Traceback:find(":%d+ "); Traceback = Traceback:sub(i+1):gsub(" :",":")
        task.defer(error, Response.." - "..Traceback)
        if Library.NotifyOnError then Library:Notify(Response) end
    end
    task.spawn(run, Func, ...);
end

function Library:AttemptSave()
    if not Library.SaveManager then return end; Library.SaveManager:Save();
end

function Library:Create(Class, Properties)
    local _Instance = Class;
    if typeof(Class) == "string" then _Instance = Instance.new(Class) end
    for Property, Value in next, Properties do
        if Property=="Size" or Property=="Position" then Value=ApplyDPIScale(Value)
        elseif Property=="TextSize" then Value=ApplyTextScale(Value) end
        local ok,err = pcall(function() _Instance[Property]=Value end)
        if not ok then warn(err) end
    end
    return _Instance;
end

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;
    return Library:Create('UIStroke', {
        Color=Color3.new(0,0,0); Thickness=1;
        LineJoinMode=Enum.LineJoinMode.Miter; Parent=Inst;
    });
end

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency=1; Font=Library.Font;
        TextColor3=Library.FontColor; TextSize=16;
        TextStrokeTransparency=1; RichText=true;
    });
    Library:ApplyTextStroke(_Instance);
    Library:AddToRegistry(_Instance, {TextColor3='FontColor'}, IsHud);
    return Library:Create(_Instance, Properties);
end

function Library:MakeDraggable(Instance, Cutoff, IsMainWindow)
    Instance.Active = true;
    if Library.IsMobile == false then
        Instance.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if IsMainWindow and Library.CantDragForced then return end
                local ObjPos = Vector2.new(Mouse.X-Instance.AbsolutePosition.X, Mouse.Y-Instance.AbsolutePosition.Y)
                if ObjPos.Y > (Cutoff or 40) then return end
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    Instance.Position = UDim2.new(0, Mouse.X-ObjPos.X+(Instance.Size.X.Offset*Instance.AnchorPoint.X), 0, Mouse.Y-ObjPos.Y+(Instance.Size.Y.Offset*Instance.AnchorPoint.Y))
                    RenderStepped:Wait()
                end
            end
        end)
    else
        local Dragging,DraggingInput,DraggingStart,StartPosition;
        InputService.TouchStarted:Connect(function(Input)
            if IsMainWindow and Library.CantDragForced then Dragging=false; return end
            if not Dragging and Library:MouseIsOverFrame(Instance,Input) and (IsMainWindow==true and (Library.CanDrag==true and Library.Window.Holder.Visible==true) or true) then
                DraggingInput=Input; DraggingStart=Input.Position; StartPosition=Instance.Position;
                local OffsetPos=Input.Position-DraggingStart;
                if OffsetPos.Y>(Cutoff or 40) then Dragging=false; return end
                Dragging=true;
            end
        end)
        InputService.TouchMoved:Connect(function(Input)
            if IsMainWindow and Library.CantDragForced then Dragging=false; return end
            if Input==DraggingInput and Dragging and (IsMainWindow==true and (Library.CanDrag==true and Library.Window.Holder.Visible==true) or true) then
                local OffsetPos=Input.Position-DraggingStart;
                Instance.Position=UDim2.new(StartPosition.X.Scale,StartPosition.X.Offset+OffsetPos.X,StartPosition.Y.Scale,StartPosition.Y.Offset+OffsetPos.Y)
            end
        end)
        InputService.TouchEnded:Connect(function(Input)
            if Input==DraggingInput then Dragging=false end
        end)
    end
end

function Library:MakeDraggableUsingParent(Instance, Parent, Cutoff, IsMainWindow)
    Instance.Active = true;
    if Library.IsMobile == false then
        Instance.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if IsMainWindow and Library.CantDragForced then return end
                local ObjPos = Vector2.new(Mouse.X-Parent.AbsolutePosition.X, Mouse.Y-Parent.AbsolutePosition.Y)
                if ObjPos.Y>(Cutoff or 40) then return end
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    Parent.Position = UDim2.new(0, Mouse.X-ObjPos.X+(Parent.Size.X.Offset*Parent.AnchorPoint.X), 0, Mouse.Y-ObjPos.Y+(Parent.Size.Y.Offset*Parent.AnchorPoint.Y))
                    RenderStepped:Wait()
                end
            end
        end)
    else
        Library:MakeDraggable(Parent, Cutoff, IsMainWindow)
    end
end

function Library:MakeResizable(Instance, MinSize)
    if Library.IsMobile then return end
    Instance.Active = true;
    local ResizerImage_Size = 25*DPIScale; local ResizerImage_HoverTransparency = 0.5;
    local Resizer = Library:Create('Frame',{
        BackgroundTransparency=1; BorderSizePixel=0;
        Size=UDim2.new(0,30,0,30); Position=UDim2.new(1,-30,1,-30);
        Visible=true; ClipsDescendants=true; ZIndex=1; Parent=Instance;
    })
    local ResizerImage = Library:Create('ImageButton',{
        BackgroundColor3=Library.AccentColor; BackgroundTransparency=1; BorderSizePixel=0;
        Size=UDim2.new(2,0,2,0); Position=UDim2.new(1,-30,1,-30); ZIndex=2; Parent=Resizer;
    })
    Library:Create('UICorner',{CornerRadius=UDim.new(0.5,0); Parent=ResizerImage;})
    Library:AddToRegistry(ResizerImage,{BackgroundColor3='AccentColor'})
    Resizer.Size=UDim2.fromOffset(ResizerImage_Size,ResizerImage_Size);
    Resizer.Position=UDim2.new(1,-ResizerImage_Size,1,-ResizerImage_Size);
    MinSize = MinSize or Library.MinSize;
    local ResizerImageUICorner = Library:Create('UICorner',{CornerRadius=UDim.new(0.5,0);Parent=ResizerImage;})
    local OffsetPos;
    Resizer.Parent = Instance;
    local function FinishResize(T)
        ResizerImage.Position=UDim2.new(); ResizerImage.Size=UDim2.new(2,0,2,0);
        ResizerImage.Parent=Resizer; ResizerImage.BackgroundTransparency=T;
        ResizerImageUICorner.Parent=ResizerImage; OffsetPos=nil;
    end
    ResizerImage.MouseButton1Down:Connect(function()
        if not OffsetPos then
            OffsetPos=Vector2.new(Mouse.X-(Instance.AbsolutePosition.X+Instance.AbsoluteSize.X),Mouse.Y-(Instance.AbsolutePosition.Y+Instance.AbsoluteSize.Y))
            ResizerImage.BackgroundTransparency=1;
            ResizerImage.Size=UDim2.fromOffset(Library.ScreenGui.AbsoluteSize.X,Library.ScreenGui.AbsoluteSize.Y);
            ResizerImage.Position=UDim2.new(); ResizerImageUICorner.Parent=nil; ResizerImage.Parent=Library.ScreenGui;
        end
    end)
    ResizerImage.MouseMoved:Connect(function()
        if OffsetPos then
            local MousePos=Vector2.new(Mouse.X-OffsetPos.X,Mouse.Y-OffsetPos.Y);
            local FinalSize=Vector2.new(math.clamp(MousePos.X-Instance.AbsolutePosition.X,MinSize.X,math.huge),math.clamp(MousePos.Y-Instance.AbsolutePosition.Y,MinSize.Y,math.huge));
            Instance.Size=UDim2.fromOffset(FinalSize.X,FinalSize.Y);
        end
    end)
    ResizerImage.MouseEnter:Connect(function() FinishResize(ResizerImage_HoverTransparency) end)
    ResizerImage.MouseLeave:Connect(function() FinishResize(1) end)
    ResizerImage.MouseButton1Up:Connect(function() FinishResize(ResizerImage_HoverTransparency) end)
end

function Library:AddToolTip(InfoStr, DisabledInfoStr, HoverInstance)
    InfoStr = typeof(InfoStr)=="string" and InfoStr or nil;
    DisabledInfoStr = typeof(DisabledInfoStr)=="string" and DisabledInfoStr or nil;
    local Tooltip = Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderColor3=Library.OutlineColor;
        ZIndex=100; Parent=Library.ScreenGui; Visible=false;
    })
    Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=Tooltip;})
    Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=Tooltip;})
    local Label = Library:CreateLabel({
        Position=UDim2.fromOffset(5,2); TextSize=13; Text=InfoStr;
        TextColor3=Library.FontColor; TextXAlignment=Enum.TextXAlignment.Left;
        ZIndex=Tooltip.ZIndex+1; RichText=true; Parent=Tooltip;
    })
    Library:AddToRegistry(Tooltip,{BackgroundColor3='MainColor';BorderColor3='OutlineColor';})
    Library:AddToRegistry(Label,{TextColor3='FontColor'})
    local TooltipTable = {Tooltip=Tooltip; Disabled=false; Signals={};}
    local IsHovering = false
    local function UpdateText(Text)
        if Text==nil then return end
        local X,Y=Library:GetTextBounds(Text,Library.Font,13*DPIScale);
        Label.Text=Text; Tooltip.Size=UDim2.fromOffset(X+10,Y+6); Label.Size=UDim2.fromOffset(X,Y);
    end
    UpdateText(InfoStr)
    table.insert(TooltipTable.Signals, HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then Tooltip.Visible=false; return end
        if not TooltipTable.Disabled then
            if InfoStr==nil or InfoStr=="" then Tooltip.Visible=false; return end
            if Label.Text~=InfoStr then UpdateText(InfoStr) end
        else
            if DisabledInfoStr==nil or DisabledInfoStr=="" then Tooltip.Visible=false; return end
            if Label.Text~=DisabledInfoStr then UpdateText(DisabledInfoStr) end
        end
        IsHovering=true; Tooltip.Position=UDim2.fromOffset(Mouse.X+15,Mouse.Y+12); Tooltip.Visible=true;
        while IsHovering do
            if TooltipTable.Disabled==true and DisabledInfoStr==nil then break end
            RunService.Heartbeat:Wait(); Tooltip.Position=UDim2.fromOffset(Mouse.X+15,Mouse.Y+12);
        end
        IsHovering=false; Tooltip.Visible=false;
    end))
    table.insert(TooltipTable.Signals, HoverInstance.MouseLeave:Connect(function()
        IsHovering=false; Tooltip.Visible=false;
    end))
    if LibraryMainOuterFrame then
        table.insert(TooltipTable.Signals, LibraryMainOuterFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            if LibraryMainOuterFrame.Visible==false then IsHovering=false; Tooltip.Visible=false end
        end))
    end
    function TooltipTable:Destroy()
        Tooltip:Destroy();
        for Idx=#TooltipTable.Signals,1,-1 do
            local C=table.remove(TooltipTable.Signals,Idx); C:Disconnect();
        end
    end
    return TooltipTable
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault, condition)
    local function undoHighlight()
        local Reg=Library.RegistryMap[Instance];
        for Property,ColorIdx in next,PropertiesDefault do
            Instance[Property]=Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then Reg.Properties[Property]=ColorIdx end
        end
    end
    local function doHighlight()
        if condition and not condition() then undoHighlight(); return end
        local Reg=Library.RegistryMap[Instance];
        for Property,ColorIdx in next,Properties do
            Instance[Property]=Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then Reg.Properties[Property]=ColorIdx end
        end
    end
    HighlightInstance.MouseEnter:Connect(function() doHighlight() end)
    HighlightInstance.MouseMoved:Connect(function() doHighlight() end)
    HighlightInstance.MouseLeave:Connect(function() undoHighlight() end)
end

function Library:MouseIsOverOpenedFrame(Input)
    local Pos=Mouse;
    if Library.IsMobile and Input then Pos=Input.Position end
    for Frame,_ in next, Library.OpenedFrames do
        local AbsPos,AbsSize=Frame.AbsolutePosition,Frame.AbsoluteSize;
        if Pos.X>=AbsPos.X and Pos.X<=AbsPos.X+AbsSize.X and Pos.Y>=AbsPos.Y and Pos.Y<=AbsPos.Y+AbsSize.Y then return true end
    end
end

function Library:MouseIsOverFrame(Frame, Input)
    local Pos=Mouse;
    if Library.IsMobile and Input then Pos=Input.Position end
    local AbsPos,AbsSize=Frame.AbsolutePosition,Frame.AbsoluteSize;
    if Pos.X>=AbsPos.X and Pos.X<=AbsPos.X+AbsSize.X and Pos.Y>=AbsPos.Y and Pos.Y<=AbsPos.Y+AbsSize.Y then return true end
end

function Library:UpdateDependencyBoxes()
    for _,Depbox in next, Library.DependencyBoxes do Depbox:Update() end
end

function Library:MapValue(Value,MinA,MaxA,MinB,MaxB)
    return (1-((Value-MinA)/(MaxA-MinA)))*MinB+((Value-MinA)/(MaxA-MinA))*MaxB;
end

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds=TextService:GetTextSize(Text:gsub("<%/?[%w:]+[^>]*>",""),Size,Font,Resolution or Vector2.new(1920,1080))
    return Bounds.X,Bounds.Y
end

function Library:GetDarkerColor(Color)
    local H,S,V=Color3.toHSV(Color);
    return Color3.fromHSV(H,S,V/1.5);
end
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx=#Library.Registry+1;
    local Data={Instance=Instance;Properties=Properties;Idx=Idx;};
    table.insert(Library.Registry,Data); Library.RegistryMap[Instance]=Data;
    if IsHud then table.insert(Library.HudRegistry,Data) end
end

function Library:RemoveFromRegistry(Instance)
    local Data=Library.RegistryMap[Instance];
    if Data then
        for Idx=#Library.Registry,1,-1 do if Library.Registry[Idx]==Data then table.remove(Library.Registry,Idx) end end
        for Idx=#Library.HudRegistry,1,-1 do if Library.HudRegistry[Idx]==Data then table.remove(Library.HudRegistry,Idx) end end
        Library.RegistryMap[Instance]=nil;
    end
end

function Library:UpdateColorsUsingRegistry()
    for _,Object in next, Library.Registry do
        for Property,ColorIdx in next, Object.Properties do
            if typeof(ColorIdx)=="string" then Object.Instance[Property]=Library[ColorIdx];
            elseif typeof(ColorIdx)=='function' then Object.Instance[Property]=ColorIdx() end
        end
    end
end

function Library:GiveSignal(Signal) table.insert(Library.Signals,Signal) end

function Library:Unload()
    for Idx=#Library.Signals,1,-1 do
        local C=table.remove(Library.Signals,Idx); C:Disconnect();
    end
    for _,CB in pairs(Library.UnloadSignals) do Library:SafeCallback(CB) end
    ScreenGui:Destroy(); ModalScreenGui:Destroy(); Library.Unloaded=true; getgenv().Linoria=nil;
end

function Library:OnUnload(Callback) table.insert(Library.UnloadSignals,Callback) end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then Library:RemoveFromRegistry(Instance) end
end))

local function Trim(Text: string) return Text:match("^%s*(.-)%s*$") end

-- ================================================================
-- BASE ADDONS (ColorPicker, KeyPicker, Dropdown on toggles/labels)
-- ================================================================
local BaseAddons = {};
do
    local BaseAddonsFuncs = {};

    function BaseAddonsFuncs:AddColorPicker(Idx, Info)
        local ParentObj = self; local ToggleLabel = self.TextLabel;
        assert(Info.Default,'AddColorPicker: Missing default value.');
        local ColorPicker = {
            Value=Info.Default; Transparency=Info.Transparency or 0;
            Type='ColorPicker'; Title=typeof(Info.Title)=="string" and Info.Title or 'Color picker';
            Callback=Info.Callback or function() end;
        };
        function ColorPicker:SetHSVFromRGB(Color)
            local H,S,V=Color:ToHSV(); ColorPicker.Hue=H; ColorPicker.Sat=S; ColorPicker.Vib=V;
        end
        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        -- Compact color swatch
        local DisplayFrame = Library:Create('Frame',{
            BackgroundColor3=ColorPicker.Value; BorderSizePixel=0;
            Size=UDim2.new(0,24,0,14); ZIndex=6; Parent=ToggleLabel;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=DisplayFrame;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=DisplayFrame;})

        local CheckerFrame = Library:Create('ImageLabel',{
            BorderSizePixel=0; Size=UDim2.new(1,0,1,0); ZIndex=5;
            Image='http://www.roblox.com/asset/?id=12977615774';
            Visible=not not Info.Transparency; Parent=DisplayFrame;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=CheckerFrame;})

        local PickerFrameOuter = Library:Create('Frame',{
            Name='Color'; BackgroundColor3=Color3.new(0,0,0);
            Position=UDim2.fromOffset(DisplayFrame.AbsolutePosition.X,DisplayFrame.AbsolutePosition.Y+16);
            Size=UDim2.fromOffset(230,Info.Transparency and 271 or 253);
            Visible=false; ZIndex=15; Parent=ScreenGui;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=PickerFrameOuter;})
        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position=UDim2.fromOffset(DisplayFrame.AbsolutePosition.X,DisplayFrame.AbsolutePosition.Y+16);
        end)

        local PickerFrameInner = Library:Create('Frame',{
            BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=16; Parent=PickerFrameOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=PickerFrameInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=PickerFrameInner;})

        local Highlight = Library:Create('Frame',{
            BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,0,2); ZIndex=17; Parent=PickerFrameInner;
        });

        local SatVibMapOuter = Library:Create('Frame',{
            BorderSizePixel=0; Position=UDim2.new(0,4,0,24);
            Size=UDim2.new(0,200,0,200); ZIndex=17; Parent=PickerFrameInner;
        });
        local SatVibMapInner = Library:Create('Frame',{
            BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=18; Parent=SatVibMapOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=SatVibMapInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=SatVibMapInner;})
        local SatVibMap = Library:Create('ImageLabel',{
            BorderSizePixel=0; Size=UDim2.new(1,0,1,0); ZIndex=18;
            Image='rbxassetid://4155801252'; Parent=SatVibMapInner;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=SatVibMap;})
        local CursorOuter = Library:Create('ImageLabel',{
            AnchorPoint=Vector2.new(0.5,0.5); Size=UDim2.new(0,6,0,6);
            BackgroundTransparency=1; Image='http://www.roblox.com/asset/?id=9619665977';
            ImageColor3=Color3.new(0,0,0); ZIndex=19; Parent=SatVibMap;
        });
        local CursorInner = Library:Create('ImageLabel',{
            Size=UDim2.new(0,CursorOuter.Size.X.Offset-2,0,CursorOuter.Size.Y.Offset-2);
            Position=UDim2.new(0,1,0,1); BackgroundTransparency=1;
            Image='http://www.roblox.com/asset/?id=9619665977'; ZIndex=20; Parent=CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame',{
            BorderSizePixel=0; Position=UDim2.new(0,208,0,24);
            Size=UDim2.new(0,15,0,200); ZIndex=17; Parent=PickerFrameInner;
        });
        local HueSelectorInner = Library:Create('Frame',{
            BackgroundColor3=Color3.new(1,1,1); BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=18; Parent=HueSelectorOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=HueSelectorInner;})
        local HueCursor = Library:Create('Frame',{
            BackgroundColor3=Color3.new(1,1,1); AnchorPoint=Vector2.new(0,0.5);
            BorderSizePixel=0; Size=UDim2.new(1,0,0,1); ZIndex=18; Parent=HueSelectorInner;
        });

        -- Hex input
        local HueBoxOuter = Library:Create('Frame',{
            BorderSizePixel=0; Position=UDim2.fromOffset(4,228);
            Size=UDim2.new(0.5,-6,0,20); ZIndex=18; Parent=PickerFrameInner;
        });
        local HueBoxInner = Library:Create('Frame',{
            BackgroundColor3=Library.MainColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=18; Parent=HueBoxOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=HueBoxInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=HueBoxInner;})
        local HueBox = Library:Create('TextBox',{
            BackgroundTransparency=1; Position=UDim2.new(0,5,0,0);
            Size=UDim2.new(1,-5,1,0); Font=Library.Font;
            PlaceholderColor3=Color3.fromRGB(90,98,115); PlaceholderText='Hex color';
            Text='#FFFFFF'; TextColor3=Library.FontColor; TextSize=13;
            TextStrokeTransparency=1; TextXAlignment=Enum.TextXAlignment.Left;
            RichText=true; ZIndex=20; Parent=HueBoxInner;
        });
        Library:ApplyTextStroke(HueBox)

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(),{
            Position=UDim2.new(0.5,2,0,228); Size=UDim2.new(0.5,-6,0,20); Parent=PickerFrameInner;
        });
        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox') or Instance.new('TextBox'),{
            Text='255, 255, 255'; PlaceholderText='RGB color';
            TextColor3=Library.FontColor; RichText=true;
        });

        local TransparencyBoxOuter,TransparencyBoxInner,TransparencyCursor;
        if Info.Transparency then
            TransparencyBoxOuter = Library:Create('Frame',{
                BorderSizePixel=0; Position=UDim2.fromOffset(4,251);
                Size=UDim2.new(1,-8,0,14); ZIndex=19; Parent=PickerFrameInner;
            });
            TransparencyBoxInner = Library:Create('Frame',{
                BackgroundColor3=ColorPicker.Value; BorderSizePixel=0;
                Size=UDim2.new(1,0,1,0); ZIndex=19; Parent=TransparencyBoxOuter;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=TransparencyBoxInner;})
            Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=TransparencyBoxInner;})
            Library:Create('ImageLabel',{
                BackgroundTransparency=1; Size=UDim2.new(1,0,1,0);
                Image='http://www.roblox.com/asset/?id=12978095818';
                ZIndex=20; Parent=TransparencyBoxInner;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=Library:Create('Frame',{Parent=TransparencyBoxInner;});})
            TransparencyCursor = Library:Create('Frame',{
                BackgroundColor3=Color3.new(1,1,1); AnchorPoint=Vector2.new(0.5,0);
                BorderSizePixel=0; Size=UDim2.new(0,1,1,0); ZIndex=21; Parent=TransparencyBoxInner;
            });
        end

        local DisplayLabel = Library:CreateLabel({
            Size=UDim2.new(1,0,0,14); Position=UDim2.fromOffset(5,4);
            TextXAlignment=Enum.TextXAlignment.Left; TextSize=13; Text=ColorPicker.Title;
            TextWrapped=false; RichText=true; ZIndex=16; Parent=PickerFrameInner;
        });

        -- Context menu (copy/paste)
        local ContextMenu = {}
        do
            ContextMenu.Options={}
            ContextMenu.Container=Library:Create('Frame',{BorderSizePixel=0;ZIndex=14;Visible=false;Parent=ScreenGui;})
            Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=ContextMenu.Container;})
            ContextMenu.Inner=Library:Create('Frame',{
                BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
                Size=UDim2.fromScale(1,1); ZIndex=15; Parent=ContextMenu.Container;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=ContextMenu.Inner;})
            Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=ContextMenu.Inner;})
            Library:Create('UIListLayout',{Name='Layout';FillDirection=Enum.FillDirection.Vertical;SortOrder=Enum.SortOrder.LayoutOrder;Parent=ContextMenu.Inner;})
            Library:Create('UIPadding',{Name='Padding';PaddingLeft=UDim.new(0,4);Parent=ContextMenu.Inner;})
            local function updateMenuPosition()
                ContextMenu.Container.Position=UDim2.fromOffset((DisplayFrame.AbsolutePosition.X+DisplayFrame.AbsoluteSize.X)+4,DisplayFrame.AbsolutePosition.Y+1)
            end
            local function updateMenuSize()
                local menuWidth=60
                for _,label in next,ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then menuWidth=math.max(menuWidth,label.TextBounds.X) end
                end
                ContextMenu.Container.Size=UDim2.fromOffset(menuWidth+8,ContextMenu.Inner.Layout.AbsoluteContentSize.Y+4)
            end
            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)
            task.spawn(updateMenuPosition); task.spawn(updateMenuSize);
            Library:AddToRegistry(ContextMenu.Inner,{BackgroundColor3='BackgroundColor';})
            function ContextMenu:Show() if Library.IsMobile then Library.CanDrag=false end; self.Container.Visible=true; end
            function ContextMenu:Hide() if Library.IsMobile then Library.CanDrag=true end; self.Container.Visible=false; end
            function ContextMenu:AddOption(Str, Callback)
                if typeof(Callback)~='function' then Callback=function() end end
                local Btn=Library:CreateLabel({Active=false;Size=UDim2.new(1,0,0,15);TextSize=13;Text=Str;ZIndex=16;Parent=self.Inner;TextXAlignment=Enum.TextXAlignment.Left;RichText=true;});
                Library:OnHighlight(Btn,Btn,{TextColor3='AccentColor'},{TextColor3='FontColor'})
                Btn.InputBegan:Connect(function(Input)
                    if Input.UserInputType~=Enum.UserInputType.MouseButton1 and Input.UserInputType~=Enum.UserInputType.Touch then return end
                    Callback()
                end)
            end
            ContextMenu:AddOption('Copy color',function() Library.ColorClipboard=ColorPicker.Value; Library:Notify('Copied color!',2) end)
            ContextMenu:AddOption('Paste color',function()
                if not Library.ColorClipboard then return Library:Notify('You have not copied a color!',2) end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)
            ContextMenu:AddOption('Copy HEX',function() pcall(setclipboard,ColorPicker.Value:ToHex()); Library:Notify('Copied hex!',2) end)
            ContextMenu:AddOption('Copy RGB',function()
                pcall(setclipboard,table.concat({math.floor(ColorPicker.Value.R*255),math.floor(ColorPicker.Value.G*255),math.floor(ColorPicker.Value.B*255)},', '))
                Library:Notify('Copied RGB!',2)
            end)
        end
        ColorPicker.ContextMenu=ContextMenu;

        Library:AddToRegistry(PickerFrameInner,{BackgroundColor3='BackgroundColor';})
        Library:AddToRegistry(Highlight,{BackgroundColor3='AccentColor';})
        Library:AddToRegistry(SatVibMapInner,{BackgroundColor3='BackgroundColor';})
        Library:AddToRegistry(HueBoxInner,{BackgroundColor3='MainColor';})
        Library:AddToRegistry(HueBox,{TextColor3='FontColor';})

        local SequenceTable = {};
        for H2=0,1,0.1 do table.insert(SequenceTable,ColorSequenceKeypoint.new(H2,Color3.fromHSV(H2,1,1))) end
        Library:Create('UIGradient',{Color=ColorSequence.new(SequenceTable);Rotation=90;Parent=HueSelectorInner;})

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local ok,r=pcall(Color3.fromHex,HueBox.Text)
                if ok and typeof(r)=='Color3' then ColorPicker.Hue,ColorPicker.Sat,ColorPicker.Vib=Color3.toHSV(r) end
            end
            ColorPicker:Display()
        end)
        if RgbBox and RgbBox.FocusLost then
            RgbBox.FocusLost:Connect(function(enter)
                if enter then
                    local r2,g,b=RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                    if r2 and g and b then ColorPicker.Hue,ColorPicker.Sat,ColorPicker.Vib=Color3.toHSV(Color3.fromRGB(r2,g,b)) end
                end
                ColorPicker:Display()
            end)
        end

        function ColorPicker:Display()
            ColorPicker.Value=Color3.fromHSV(ColorPicker.Hue,ColorPicker.Sat,ColorPicker.Vib);
            SatVibMap.BackgroundColor3=Color3.fromHSV(ColorPicker.Hue,1,1);
            Library:Create(DisplayFrame,{BackgroundColor3=ColorPicker.Value;BackgroundTransparency=ColorPicker.Transparency;});
            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3=ColorPicker.Value;
                TransparencyCursor.Position=UDim2.new(1-ColorPicker.Transparency,0,0,0);
            end
            CursorOuter.Position=UDim2.new(ColorPicker.Sat,0,1-ColorPicker.Vib,0);
            HueCursor.Position=UDim2.new(0,0,ColorPicker.Hue,0);
            HueBox.Text='#'..ColorPicker.Value:ToHex()
            if RgbBox and RgbBox.Text~=nil then
                RgbBox.Text=table.concat({math.floor(ColorPicker.Value.R*255),math.floor(ColorPicker.Value.G*255),math.floor(ColorPicker.Value.B*255)},', ')
            end
            Library:SafeCallback(ColorPicker.Callback,ColorPicker.Value,ColorPicker.Transparency);
            Library:SafeCallback(ColorPicker.Changed,ColorPicker.Value,ColorPicker.Transparency);
        end

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed=Func; Library:SafeCallback(Func,ColorPicker.Value,ColorPicker.Transparency);
        end
        if ParentObj.Addons then table.insert(ParentObj.Addons,ColorPicker) end
        function ColorPicker:Show()
            for Frame,_ in next, Library.OpenedFrames do
                if Frame.Name=='Color' then Frame.Visible=false; Library.OpenedFrames[Frame]=nil end
            end
            PickerFrameOuter.Visible=true; Library.OpenedFrames[PickerFrameOuter]=true;
        end
        function ColorPicker:Hide()
            PickerFrameOuter.Visible=false; Library.OpenedFrames[PickerFrameOuter]=nil;
        end
        function ColorPicker:SetValue(HSV,Transparency)
            ColorPicker.Transparency=Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color3.fromHSV(HSV[1],HSV[2],HSV[3])); ColorPicker:Display();
        end
        function ColorPicker:SetValueRGB(Color,Transparency)
            ColorPicker.Transparency=Transparency or 0; ColorPicker:SetHSVFromRGB(Color); ColorPicker:Display();
        end

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX=SatVibMap.AbsolutePosition.X; local MaxX=MinX+SatVibMap.AbsoluteSize.X;
                    local MinY=SatVibMap.AbsolutePosition.Y; local MaxY=MinY+SatVibMap.AbsoluteSize.Y;
                    ColorPicker.Sat=(math.clamp(Mouse.X,MinX,MaxX)-MinX)/(MaxX-MinX);
                    ColorPicker.Vib=1-((math.clamp(Mouse.Y,MinY,MaxY)-MinY)/(MaxY-MinY));
                    ColorPicker:Display(); RenderStepped:Wait();
                end
                Library:AttemptSave();
            end
        end)
        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY=HueSelectorInner.AbsolutePosition.Y; local MaxY=MinY+HueSelectorInner.AbsoluteSize.Y;
                    ColorPicker.Hue=(math.clamp(Mouse.Y,MinY,MaxY)-MinY)/(MaxY-MinY);
                    ColorPicker:Display(); RenderStepped:Wait();
                end
                Library:AttemptSave();
            end
        end)
        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local MinX=TransparencyBoxInner.AbsolutePosition.X; local MaxX=MinX+TransparencyBoxInner.AbsoluteSize.X;
                        ColorPicker.Transparency=1-((math.clamp(Mouse.X,MinX,MaxX)-MinX)/(MaxX-MinX));
                        ColorPicker:Display(); RenderStepped:Wait();
                    end
                    Library:AttemptSave();
                end
            end)
        end
        DisplayFrame.InputBegan:Connect(function(Input)
            if Library:MouseIsOverOpenedFrame(Input) then return end
            if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then
                if PickerFrameOuter.Visible then ColorPicker:Hide() else ContextMenu:Hide(); ColorPicker:Show() end
            elseif Input.UserInputType==Enum.UserInputType.MouseButton2 then
                ContextMenu:Show(); ColorPicker:Hide()
            end
        end)
        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then
                local AbsPos,AbsSize=PickerFrameOuter.AbsolutePosition,PickerFrameOuter.AbsoluteSize;
                if Mouse.X<AbsPos.X or Mouse.X>AbsPos.X+AbsSize.X or Mouse.Y<(AbsPos.Y-18) or Mouse.Y>AbsPos.Y+AbsSize.Y then
                    ColorPicker:Hide()
                end
                if not Library:MouseIsOverFrame(ContextMenu.Container) then ContextMenu:Hide() end
            end
            if Input.UserInputType==Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:MouseIsOverFrame(ContextMenu.Container) and not Library:MouseIsOverFrame(DisplayFrame) then ContextMenu:Hide() end
            end
        end))
        ColorPicker:Display(); ColorPicker.DisplayFrame=DisplayFrame;
        Options[Idx]=ColorPicker;
        return self;
    end

    function BaseAddonsFuncs:AddKeyPicker(Idx, Info)
        local ParentObj=self; local ToggleLabel=self.TextLabel;
        assert(Info.Default,'AddKeyPicker: Missing default value.');
        local KeyPicker={
            Value=Info.Default; Toggled=false; Mode=Info.Mode or 'Toggle';
            Type='KeyPicker'; Callback=Info.Callback or function() end;
            ChangedCallback=Info.ChangedCallback or function() end;
            SyncToggleState=Info.SyncToggleState or false;
        };
        if KeyPicker.SyncToggleState then Info.Modes={'Toggle'}; Info.Mode='Toggle' end

        -- Compact keybind display
        local PickOuter = Library:Create('Frame',{
            BackgroundColor3=Color3.new(0,0,0); BorderSizePixel=0;
            Size=UDim2.new(0,32,0,16); ZIndex=6; Parent=ToggleLabel;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=PickOuter;})
        local PickInner = Library:Create('Frame',{
            BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=7; Parent=PickOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=PickInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=PickInner;})
        Library:AddToRegistry(PickInner,{BackgroundColor3='BackgroundColor';})
        local DisplayLabel = Library:CreateLabel({
            Size=UDim2.new(1,0,1,0); TextSize=11; Text=Info.Default;
            TextWrapped=true; RichText=true; ZIndex=8; Parent=PickInner;
        });

        local ModeSelectOuter = Library:Create('Frame',{
            BorderSizePixel=0;
            Position=UDim2.fromOffset(ToggleLabel.AbsolutePosition.X+ToggleLabel.AbsoluteSize.X+4,ToggleLabel.AbsolutePosition.Y+1);
            Size=UDim2.new(0,60,0,2); Visible=false; ZIndex=14; Parent=ScreenGui;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=ModeSelectOuter;})
        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position=UDim2.fromOffset(ToggleLabel.AbsolutePosition.X+ToggleLabel.AbsoluteSize.X+4,ToggleLabel.AbsolutePosition.Y+1);
        end)
        local ModeSelectInner = Library:Create('Frame',{
            BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=15; Parent=ModeSelectOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=ModeSelectInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=ModeSelectInner;})
        Library:AddToRegistry(ModeSelectInner,{BackgroundColor3='BackgroundColor';})
        Library:Create('UIListLayout',{FillDirection=Enum.FillDirection.Vertical;SortOrder=Enum.SortOrder.LayoutOrder;Parent=ModeSelectInner;})

        -- Keybind HUD entry
        local KeybindsToggle = {}
        do
            local KbContainer = Library:Create('Frame',{
                BackgroundTransparency=1; Size=UDim2.new(1,0,0,18);
                Visible=false; ZIndex=110; Parent=Library.KeybindContainer;
            });
            local KbOuter = Library:Create('Frame',{
                BackgroundColor3=Color3.new(0,0,0); BorderSizePixel=0;
                Size=UDim2.new(0,12,0,12); Position=UDim2.new(0,0,0,3);
                Visible=true; ZIndex=110; Parent=KbContainer;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=KbOuter;})
            local KbInner = Library:Create('Frame',{
                BackgroundColor3=Library.MainColor; BorderSizePixel=0;
                Size=UDim2.new(1,0,1,0); ZIndex=111; Parent=KbOuter;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=KbInner;})
            Library:AddToRegistry(KbInner,{BackgroundColor3='MainColor';})
            local KbLabel = Library:CreateLabel({
                BackgroundTransparency=1; Size=UDim2.new(0,216,1,0);
                Position=UDim2.new(1,5,0,-1); TextSize=13; Text="";
                TextXAlignment=Enum.TextXAlignment.Left; RichText=true; ZIndex=111; Parent=KbInner;
            });
            Library:Create('UIListLayout',{Padding=UDim.new(0,4);FillDirection=Enum.FillDirection.Horizontal;HorizontalAlignment=Enum.HorizontalAlignment.Right;SortOrder=Enum.SortOrder.LayoutOrder;Parent=KbLabel;})
            local KbRegion = Library:Create('Frame',{
                BackgroundTransparency=1; Size=UDim2.new(0,170,1,0); ZIndex=113; Parent=KbOuter;
            });
            Library:OnHighlight(KbRegion,KbOuter,{BorderColor3='AccentColor'},{BorderColor3='Black'},function() return true end);
            function KeybindsToggle:Display(State)
                KbInner.BackgroundColor3=State and Library.AccentColor or Library.MainColor;
                KbLabel.TextColor3=State and Library.AccentColor or Library.FontColor;
                Library.RegistryMap[KbInner].Properties.BackgroundColor3=State and 'AccentColor' or 'MainColor';
                Library.RegistryMap[KbLabel].Properties.TextColor3=State and 'AccentColor' or 'FontColor';
            end
            function KeybindsToggle:SetText(T) KbLabel.Text=T end
            function KeybindsToggle:SetVisibility(b) KbContainer.Visible=b end
            function KeybindsToggle:SetNormal(b)
                KeybindsToggle.Normal=b;
                KbOuter.BackgroundTransparency=b and 1 or 0;
                KbInner.BackgroundTransparency=b and 1 or 0;
                KbInner.BorderSizePixel=b and 0 or 0;
                KbLabel.Position=b and UDim2.new(1,-13,0,-1) or UDim2.new(1,5,0,-1);
            end
            Library:GiveSignal(KbRegion.InputBegan:Connect(function(Input)
                if KeybindsToggle.Normal then return end
                if (Input.UserInputType==Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType==Enum.UserInputType.Touch then
                    KeyPicker.Toggled=not KeyPicker.Toggled; KeyPicker:DoClick();
                end
            end))
            KeybindsToggle.Loaded=true;
        end

        local Modes=Info.Modes or {'Always','Toggle','Hold'}; local ModeButtons={};
        for _,Mode in next, Modes do
            local ModeButton={};
            local Label=Library:CreateLabel({Active=false;Size=UDim2.new(1,0,0,15);TextSize=13;Text=Mode;RichText=true;ZIndex=16;Parent=ModeSelectInner;});
            ModeSelectOuter.Size=ModeSelectOuter.Size+UDim2.new(0,0,0,17);
            function ModeButton:Select()
                for _,B in next,ModeButtons do B:Deselect() end
                KeyPicker.Mode=Mode; Label.TextColor3=Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3='AccentColor'; ModeSelectOuter.Visible=false;
            end
            function ModeButton:Deselect()
                KeyPicker.Mode=nil; Label.TextColor3=Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3='FontColor';
            end
            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType==Enum.UserInputType.MouseButton1 then ModeButton:Select(); Library:AttemptSave() end
            end)
            if Mode==KeyPicker.Mode then ModeButton:Select() end
            ModeButtons[Mode]=ModeButton;
        end

        function KeyPicker:Update()
            if Info.NoUI then return end
            local State=KeyPicker:GetState();
            local ShowToggle=Library.ShowToggleFrameInKeybinds and KeyPicker.Mode=='Toggle';
            if KeybindsToggle.Loaded then
                KeybindsToggle:SetNormal(not ShowToggle);
                KeybindsToggle:SetVisibility(true);
                KeybindsToggle:SetText(string.format('[%s] %s (%s)',KeyPicker.Value,Info.Text,KeyPicker.Mode));
                KeybindsToggle:Display(State);
            end
            local YSize=0; local XSize=0;
            for _,Frame in next, Library.KeybindContainer:GetChildren() do
                if Frame:IsA('Frame') and Frame.Visible then
                    YSize=YSize+18;
                    local Lbl=Frame:FindFirstChild("TextLabel",true)
                    if not Lbl then continue end
                    if Lbl.TextBounds.X>XSize then XSize=Lbl.TextBounds.X+20 end
                end
            end
            Library.KeybindFrame.Size=UDim2.new(0,math.max(XSize+10,210),0,(YSize+23+6)*DPIScale)
        end

        function KeyPicker:GetState()
            if KeyPicker.Mode=='Always' then return true
            elseif KeyPicker.Mode=='Hold' then
                if KeyPicker.Value=='None' then return false end
                local Key=KeyPicker.Value;
                if Key=='MB1' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                elseif Key=='MB2' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                else return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]) and not InputService:GetFocusedTextBox() end
            else return KeyPicker.Toggled end
        end

        function KeyPicker:SetValue(Data)
            local Key,Mode=Data[1],Data[2]; DisplayLabel.Text=Key; KeyPicker.Value=Key;
            if ModeButtons[Mode] then ModeButtons[Mode]:Select() end; KeyPicker:Update();
        end
        function KeyPicker:OnClick(Callback) KeyPicker.Clicked=Callback end
        function KeyPicker:OnChanged(Callback) KeyPicker.Changed=Callback; Callback(KeyPicker.Value) end
        if ParentObj.Addons then table.insert(ParentObj.Addons,KeyPicker) end
        function KeyPicker:DoClick()
            if ParentObj.Type=='Toggle' and KeyPicker.SyncToggleState then ParentObj:SetValue(not ParentObj.Value) end
            Library:SafeCallback(KeyPicker.Callback,KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked,KeyPicker.Toggled)
        end
        function KeyPicker:SetModePickerVisibility(b) ModeSelectOuter.Visible=b end
        function KeyPicker:GetModePickerVisibility() return ModeSelectOuter.Visible end

        local Picking=false;
        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType==Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking=true; DisplayLabel.Text='';
                local Break; local Text='';
                task.spawn(function()
                    while not Break do
                        if Text=='...' then Text='' end; Text=Text..'.'; DisplayLabel.Text=Text; task.wait(0.4);
                    end
                end)
                task.wait(0.2);
                local Event;
                Event=InputService.InputBegan:Connect(function(Input2)
                    local Key;
                    if Input2.UserInputType==Enum.UserInputType.Keyboard then Key=Input2.KeyCode.Name;
                    elseif Input2.UserInputType==Enum.UserInputType.MouseButton1 then Key='MB1';
                    elseif Input2.UserInputType==Enum.UserInputType.MouseButton2 then Key='MB2'; end
                    Break=true; Picking=false; DisplayLabel.Text=Key; KeyPicker.Value=Key;
                    Library:SafeCallback(KeyPicker.ChangedCallback,Input2.KeyCode or Input2.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed,Input2.KeyCode or Input2.UserInputType)
                    Library:AttemptSave(); Event:Disconnect();
                end)
            elseif Input.UserInputType==Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                KeyPicker:SetModePickerVisibility(not KeyPicker:GetModePickerVisibility())
            end
        end)

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if KeyPicker.Value=="Unknown" then return end
            if not Picking and not InputService:GetFocusedTextBox() then
                if KeyPicker.Mode=='Toggle' then
                    local Key=KeyPicker.Value;
                    if Key=='MB1' or Key=='MB2' then
                        if (Key=='MB1' and Input.UserInputType==Enum.UserInputType.MouseButton1) or (Key=='MB2' and Input.UserInputType==Enum.UserInputType.MouseButton2) then
                            KeyPicker.Toggled=not KeyPicker.Toggled; KeyPicker:DoClick();
                        end
                    elseif Input.UserInputType==Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name==Key then KeyPicker.Toggled=not KeyPicker.Toggled; KeyPicker:DoClick() end
                    end
                end
                KeyPicker:Update();
            end
            if Input.UserInputType==Enum.UserInputType.MouseButton1 then
                local AbsPos,AbsSize=ModeSelectOuter.AbsolutePosition,ModeSelectOuter.AbsoluteSize;
                if Mouse.X<AbsPos.X or Mouse.X>AbsPos.X+AbsSize.X or Mouse.Y<(AbsPos.Y-20) or Mouse.Y>AbsPos.Y+AbsSize.Y then
                    KeyPicker:SetModePickerVisibility(false)
                end
            end
        end))
        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if not Picking then KeyPicker:Update() end
        end))
        KeyPicker:Update(); KeyPicker.DisplayFrame=PickOuter;
        Options[Idx]=KeyPicker;
        return self;
    end

    function BaseAddonsFuncs:AddDropdown(Idx, Info)
        Info.ReturnInstanceInstead=if typeof(Info.ReturnInstanceInstead)=="boolean" then Info.ReturnInstanceInstead else false;
        if Info.SpecialType=='Player' then
            Info.ExcludeLocalPlayer=if typeof(Info.ExcludeLocalPlayer)=="boolean" then Info.ExcludeLocalPlayer else false;
            Info.Values=GetPlayers(Info.ExcludeLocalPlayer,Info.ReturnInstanceInstead); Info.AllowNull=true;
        elseif Info.SpecialType=='Team' then
            Info.Values=GetTeams(Info.ReturnInstanceInstead); Info.AllowNull=true;
        end
        assert(Info.Values,'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default,'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')
        Info.Searchable=if typeof(Info.Searchable)=="boolean" then Info.Searchable else false;
        Info.FormatDisplayValue=if typeof(Info.FormatDisplayValue)=="function" then Info.FormatDisplayValue else nil;
        local Dropdown={
            Values=Info.Values; Value=Info.Multi and {};
            DisabledValues=Info.DisabledValues or {}; Multi=Info.Multi;
            Type='Dropdown'; SpecialType=Info.SpecialType;
            Visible=if typeof(Info.Visible)=="boolean" then Info.Visible else true;
            Disabled=if typeof(Info.Disabled)=="boolean" then Info.Disabled else false;
            Callback=Info.Callback or function() end;
            OriginalText=Info.Text; Text=Info.Text;
            ExcludeLocalPlayer=Info.ExcludeLocalPlayer; ReturnInstanceInstead=Info.ReturnInstanceInstead;
        };
        local Tooltip; local ParentObj=self; local ToggleLabel=self.TextLabel; local Container=self.Container;

        local DropdownOuter=Library:Create('Frame',{
            BackgroundColor3=Color3.new(0,0,0); BorderSizePixel=0;
            Size=UDim2.new(0,60,0,16); Visible=Dropdown.Visible; ZIndex=6; Parent=ToggleLabel; Name="dropdown_outer";
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=DropdownOuter;})
        local DropdownInner=Library:Create('Frame',{
            BackgroundColor3=Library.MainColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=6; Parent=DropdownOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=DropdownInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=DropdownInner;})
        Library:AddToRegistry(DropdownOuter,{BorderColor3='Black';})
        Library:AddToRegistry(DropdownInner,{BackgroundColor3='MainColor';})

        local DropdownInnerSearch;
        if Info.Searchable then
            DropdownInnerSearch=Library:Create('TextBox',{
                BackgroundTransparency=1; Visible=false; Position=UDim2.new(0,4,0,0);
                Size=UDim2.new(0.9,-4,1,0); Font=Library.Font;
                PlaceholderColor3=Color3.fromRGB(90,98,115); PlaceholderText='Search...';
                Text=''; TextColor3=Library.FontColor; TextSize=13; TextStrokeTransparency=1;
                TextXAlignment=Enum.TextXAlignment.Left; RichText=true; ClearTextOnFocus=false;
                ZIndex=7; Parent=DropdownOuter;
            });
            Library:AddToRegistry(DropdownInnerSearch,{TextColor3='FontColor';})
        end

        local DropdownArrow=Library:Create('ImageLabel',{
            AnchorPoint=Vector2.new(0,0.5); BackgroundTransparency=1;
            Position=UDim2.new(1,-14,0.5,0); Size=UDim2.new(0,10,0,10);
            Image='http://www.roblox.com/asset/?id=6282522798'; ZIndex=8; Parent=DropdownInner;
        });
        local ItemList=Library:CreateLabel({
            Position=UDim2.new(0,4,0,0); Size=UDim2.new(1,-4,1,0);
            TextSize=13; Text='--'; TextXAlignment=Enum.TextXAlignment.Left;
            TextWrapped=false; TextTruncate=Enum.TextTruncate.AtEnd; RichText=true; ZIndex=7; Parent=DropdownInner;
        });

        Library:OnHighlight(DropdownOuter,DropdownOuter,{BorderColor3='AccentColor'},{BorderColor3='Black'},function() return not Dropdown.Disabled end)
        if typeof(Info.Tooltip)=="string" or typeof(Info.DisabledTooltip)=="string" then
            Tooltip=Library:AddToolTip(Info.Tooltip,Info.DisabledTooltip,DropdownOuter); Tooltip.Disabled=Dropdown.Disabled;
        end

        local MAX_DD=if typeof(Info.MaxVisibleDropdownItems)=="number" then math.clamp(Info.MaxVisibleDropdownItems,4,16) else 8;
        local ListOuter=Library:Create('Frame',{
            BackgroundColor3=Color3.new(0,0,0); BorderSizePixel=0;
            ZIndex=20; Visible=false; Parent=ScreenGui;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=ListOuter;})
        local function RecalcPos() ListOuter.Position=UDim2.fromOffset(DropdownOuter.AbsolutePosition.X,DropdownOuter.AbsolutePosition.Y+DropdownOuter.Size.Y.Offset+1) end
        local function RecalcSize(YSize) local Y=YSize or math.clamp(GetTableSize(Dropdown.Values)*(18*DPIScale),0,MAX_DD*(18*DPIScale))+1; ListOuter.Size=UDim2.fromOffset(DropdownOuter.AbsoluteSize.X+0.5,Y) end
        RecalcPos(); RecalcSize();
        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalcPos);
        DropdownOuter:GetPropertyChangedSignal('AbsoluteSize'):Connect(RecalcSize);

        local ListInner=Library:Create('Frame',{
            BackgroundColor3=Library.MainColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=21; Parent=ListOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=ListInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=ListInner;})
        Library:AddToRegistry(ListInner,{BackgroundColor3='MainColor';})
        local Scrolling=Library:Create('ScrollingFrame',{
            BackgroundTransparency=1; BorderSizePixel=0; CanvasSize=UDim2.new(0,0,0,0);
            Size=UDim2.new(1,0,1,0); ZIndex=21; Parent=ListInner;
            TopImage='rbxasset://textures/ui/Scroll/scroll-middle.png';
            BottomImage='rbxasset://textures/ui/Scroll/scroll-middle.png';
            ScrollBarThickness=3; ScrollBarImageColor3=Library.AccentColor;
        });
        Library:AddToRegistry(Scrolling,{ScrollBarImageColor3='AccentColor';})
        Library:Create('UIListLayout',{Padding=UDim.new(0,0);FillDirection=Enum.FillDirection.Vertical;SortOrder=Enum.SortOrder.LayoutOrder;Parent=Scrolling;})

        function Dropdown:UpdateColors()
            ItemList.TextColor3=Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1,1,1);
            DropdownArrow.ImageColor3=Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1,1,1);
        end

        function Dropdown:Display()
            local Str='';
            if Info.Multi then
                for _,Value in next,Dropdown.Values do
                    local SV=if typeof(Value)=="Instance" then Value.Name else Value;
                    if Dropdown.Value[Value] then Str=Str..(Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(SV)) or SV)..', ' end
                end
                Str=Str:sub(1,#Str-2); ItemList.Text=(Str=='' and '--' or Str);
            else
                if not Dropdown.Value then ItemList.Text='--'; return end
                local SV=if typeof(Dropdown.Value)=="Instance" then Dropdown.Value.Name else Dropdown.Value;
                ItemList.Text=Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(SV)) or SV;
            end
            local X=Library:GetTextBounds(ItemList.Text,Library.Font,ItemList.TextSize,Vector2.new(ToggleLabel.AbsoluteSize.X,math.huge))+24;
            DropdownOuter.Size=UDim2.new(0,X,0,16)
        end

        function Dropdown:GetActiveValues()
            if Info.Multi then local T={}; for V in next,Dropdown.Value do table.insert(T,V) end; return T;
            else return Dropdown.Value and 1 or 0 end
        end

        function Dropdown:BuildDropdownList()
            local DisabledValues=Dropdown.DisabledValues; local Btns={};
            for _,El in next, Scrolling:GetChildren() do if not El:IsA('UIListLayout') then El:Destroy() end end
            local Count=0;
            for _,Value in next, Dropdown.Values do
                local SV=if typeof(Value)=="Instance" then Value.Name else Value;
                if Info.Searchable and not string.lower(SV):match(string.lower(DropdownInnerSearch.Text)) then continue end
                local IsDisabled=table.find(DisabledValues,SV); local Tbl={};
                Count=Count+1;
                local Btn=Library:Create('TextButton',{
                    AutoButtonColor=false; BackgroundColor3=Library.MainColor; BorderSizePixel=0;
                    Size=UDim2.new(1,-1,0,18); Text=''; ZIndex=23; Parent=Scrolling;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=Btn;})
                Library:AddToRegistry(Btn,{BackgroundColor3='MainColor';})
                local BtnLabel=Library:CreateLabel({
                    Active=false; Size=UDim2.new(1,-6,1,0); Position=UDim2.new(0,6,0,0);
                    TextSize=13; Text=Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(SV)) or SV;
                    TextXAlignment=Enum.TextXAlignment.Left; RichText=true; ZIndex=25; Parent=Btn;
                });
                Library:OnHighlight(Btn,Btn,{BorderColor3=IsDisabled and 'DisabledAccentColor' or 'AccentColor',ZIndex=24},{BorderColor3='OutlineColor',ZIndex=23})
                local Selected=Info.Multi and Dropdown.Value[Value] or (Dropdown.Value==Value);
                function Tbl:UpdateButton()
                    Selected=Info.Multi and Dropdown.Value[Value] or (Dropdown.Value==Value);
                    BtnLabel.TextColor3=Selected and Library.AccentColor or (IsDisabled and Library.DisabledAccentColor or Library.FontColor);
                    Library.RegistryMap[BtnLabel].Properties.TextColor3=Selected and 'AccentColor' or (IsDisabled and 'DisabledAccentColor' or 'FontColor');
                end
                if not IsDisabled then
                    Btn.MouseButton1Click:Connect(function()
                        local Try=not Selected;
                        if Dropdown:GetActiveValues()==1 and not Try and not Info.AllowNull then
                        else
                            if Info.Multi then
                                Selected=Try; if Selected then Dropdown.Value[Value]=true else Dropdown.Value[Value]=nil end
                            else
                                Selected=Try; if Selected then Dropdown.Value=Value else Dropdown.Value=nil end
                                for _,OB in next,Btns do OB:UpdateButton() end
                            end
                            Tbl:UpdateButton(); Dropdown:Display();
                            Library:UpdateDependencyBoxes();
                            Library:SafeCallback(Dropdown.Callback,Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed,Dropdown.Value);
                            Library:AttemptSave();
                        end
                    end)
                end
                Tbl:UpdateButton(); Dropdown:Display(); Btns[Btn]=Tbl;
            end
            Scrolling.CanvasSize=UDim2.fromOffset(0,(Count*(18*DPIScale))+1);
            Scrolling.Visible=false; Scrolling.Visible=true;
            local Y=math.clamp(Count*(18*DPIScale),0,MAX_DD*(18*DPIScale))+1; RecalcSize(Y);
        end

        function Dropdown:SetValues(NV) if NV then Dropdown.Values=NV end; Dropdown:BuildDropdownList(); end
        function Dropdown:AddValues(NV)
            if typeof(NV)=="table" then for _,v in pairs(NV) do table.insert(Dropdown.Values,v) end
            elseif typeof(NV)=="string" then table.insert(Dropdown.Values,NV) else return end
            Dropdown:BuildDropdownList()
        end
        function Dropdown:SetDisabledValues(NV) if NV then Dropdown.DisabledValues=NV end; Dropdown:BuildDropdownList() end
        function Dropdown:AddDisabledValues(DV)
            if typeof(DV)=="table" then for _,v in pairs(DV) do table.insert(Dropdown.DisabledValues,v) end
            elseif typeof(DV)=="string" then table.insert(Dropdown.DisabledValues,DV) else return end
            Dropdown:BuildDropdownList()
        end
        function Dropdown:SetVisible(V) Dropdown.Visible=V; DropdownOuter.Visible=V; if not V then Dropdown:CloseDropdown() end end
        function Dropdown:SetDisabled(D)
            Dropdown.Disabled=D; if Tooltip then Tooltip.Disabled=D end
            if D then Dropdown:CloseDropdown() end; Dropdown:Display(); Dropdown:UpdateColors();
        end
        function Dropdown:OpenDropdown()
            if Dropdown.Disabled then return end
            if Library.IsMobile then Library.CanDrag=false end
            if Info.Searchable then ItemList.Visible=false; DropdownInnerSearch.Text=""; DropdownInnerSearch.Visible=true end
            ListOuter.Visible=true; Library.OpenedFrames[ListOuter]=true; DropdownArrow.Rotation=180; RecalcSize();
        end
        function Dropdown:CloseDropdown()
            if Library.IsMobile then Library.CanDrag=true end
            if Info.Searchable then DropdownInnerSearch.Text=""; DropdownInnerSearch.Visible=false; ItemList.Visible=true end
            ListOuter.Visible=false; Library.OpenedFrames[ListOuter]=nil; DropdownArrow.Rotation=0;
        end
        function Dropdown:OnChanged(Func)
            Dropdown.Changed=Func; if Dropdown.Disabled then return end; Library:SafeCallback(Func,Dropdown.Value);
        end
        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nT={}; for V,_ in next,Val do if table.find(Dropdown.Values,V) then nT[V]=true end end; Dropdown.Value=nT;
            else
                if not Val then Dropdown.Value=nil; elseif table.find(Dropdown.Values,Val) then Dropdown.Value=Val end
            end
            Dropdown:BuildDropdownList();
            if not Dropdown.Disabled then Library:SafeCallback(Dropdown.Callback,Dropdown.Value); Library:SafeCallback(Dropdown.Changed,Dropdown.Value) end
        end
        function Dropdown:SetText() return end

        DropdownOuter.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then return end
            if (Input.UserInputType==Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType==Enum.UserInputType.Touch then
                if ListOuter.Visible then Dropdown:CloseDropdown() else Dropdown:OpenDropdown() end
            end
        end)
        if Info.Searchable then DropdownInnerSearch:GetPropertyChangedSignal("Text"):Connect(function() Dropdown:BuildDropdownList() end) end
        InputService.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then return end
            if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then
                local AbsPos,AbsSize=ListOuter.AbsolutePosition,ListOuter.AbsoluteSize;
                if Mouse.X<AbsPos.X or Mouse.X>AbsPos.X+AbsSize.X or Mouse.Y<(AbsPos.Y-(18*DPIScale)) or Mouse.Y>AbsPos.Y+AbsSize.Y then
                    Dropdown:CloseDropdown()
                end
            end
        end)

        Dropdown:BuildDropdownList(); Dropdown:Display();
        local Defaults={}
        if typeof(Info.Default)=="string" then local i=table.find(Dropdown.Values,Info.Default); if i then table.insert(Defaults,i) end
        elseif typeof(Info.Default)=='table' then for _,V in next,Info.Default do local i=table.find(Dropdown.Values,V); if i then table.insert(Defaults,i) end end
        elseif typeof(Info.Default)=='number' and Dropdown.Values[Info.Default]~=nil then table.insert(Defaults,Info.Default) end
        if next(Defaults) then
            for i=1,#Defaults do
                local Index=Defaults[i]
                if Info.Multi then Dropdown.Value[Dropdown.Values[Index]]=true
                else Dropdown.Value=Dropdown.Values[Index] end
                if not Info.Multi then break end
            end
            Dropdown:BuildDropdownList(); Dropdown:Display();
        end
        task.delay(0.1,Dropdown.UpdateColors,Dropdown)
        Dropdown.DisplayFrame=DropdownOuter;
        if ParentObj.Addons then table.insert(ParentObj.Addons,Dropdown) end
        Options[Idx]=Dropdown;
        return self;
    end

    BaseAddons.__index=BaseAddonsFuncs;
    BaseAddons.__namecall=function(Table,Key,...) return BaseAddonsFuncs[Key](...) end;
end

-- ================================================================
-- BASE GROUPBOX (controls added inside panels)
-- ================================================================
local BaseGroupbox = {};
do
    local BaseGroupboxFuncs = {};

    function BaseGroupboxFuncs:AddBlank(Size, Visible)
        return Library:Create('Frame',{
            BackgroundTransparency=1; Size=UDim2.new(1,0,0,Size);
            Visible=if typeof(Visible)=="boolean" then Visible else true;
            ZIndex=1; Parent=self.Container;
        });
    end

    function BaseGroupboxFuncs:AddLabel(...)
        local Data={}
        if select(2,...)~=nil and typeof(select(2,...))=="table" then
            if select(1,...)~=nil then assert(typeof(select(1,...))=="string","Expected string for Idx") end
            local P=select(2,...); Data.Text=P.Text or ""; Data.DoesWrap=P.DoesWrap or false; Data.Idx=select(1,...);
        else Data.Text=select(1,...) or ""; Data.DoesWrap=select(2,...) or false; Data.Idx=select(3,...) or nil end
        Data.OriginalText=Data.Text;
        local Label={}; local Groupbox=self; local Container=Groupbox.Container;
        local TextLabel=Library:CreateLabel({
            Size=UDim2.new(1,-4,0,14); TextSize=13; Text=Data.Text;
            TextWrapped=Data.DoesWrap or false; TextXAlignment=Enum.TextXAlignment.Left;
            RichText=true; ZIndex=5; Parent=Container;
        });
        if Data.DoesWrap then
            local Y=select(2,Library:GetTextBounds(Data.Text,Library.Font,13*DPIScale,Vector2.new(TextLabel.AbsoluteSize.X,math.huge)));
            TextLabel.Size=UDim2.new(1,-4,0,Y)
        else
            Library:Create('UIListLayout',{Padding=UDim.new(0,4);FillDirection=Enum.FillDirection.Horizontal;HorizontalAlignment=Enum.HorizontalAlignment.Right;SortOrder=Enum.SortOrder.LayoutOrder;Parent=TextLabel;})
        end
        Label.TextLabel=TextLabel; Label.Container=Container;
        function Label:SetText(Text)
            TextLabel.Text=Text;
            if Data.DoesWrap then
                local Y=select(2,Library:GetTextBounds(Text,Library.Font,13*DPIScale,Vector2.new(TextLabel.AbsoluteSize.X,math.huge)));
                TextLabel.Size=UDim2.new(1,-4,0,Y)
            end
            Groupbox:Resize();
        end
        if not Data.DoesWrap then setmetatable(Label,BaseAddons) end
        Groupbox:AddBlank(4); Groupbox:Resize();
        if Data.Idx then Labels[Data.Idx]=Label else table.insert(Labels,Label) end
        return Label;
    end

    function BaseGroupboxFuncs:AddButton(...)
        local Button=typeof(select(1,...))=="table" and select(1,...) or {Text=select(1,...),Func=select(2,...)}
        Button.OriginalText=Button.Text;
        assert(typeof(Button.Func)=='function','AddButton: `Func` callback is missing.');
        local Groupbox=self; local Container=Groupbox.Container;
        local IsVisible=if typeof(Button.Visible)=="boolean" then Button.Visible else true;

        local function CreateBaseButton(B)
            local Outer=Library:Create('Frame',{
                BackgroundColor3=Color3.new(0,0,0); BorderSizePixel=0;
                Size=UDim2.new(1,-4,0,20); Visible=IsVisible; ZIndex=5;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=Outer;})
            local Inner=Library:Create('Frame',{
                BackgroundColor3=Library.MainColor; BorderSizePixel=0;
                Size=UDim2.new(1,0,1,0); ZIndex=6; Parent=Outer;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=Inner;})
            Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=Inner;})
            local Lbl=Library:CreateLabel({Size=UDim2.new(1,0,1,0);TextSize=13;Text=B.Text;RichText=true;ZIndex=6;Parent=Inner;});
            Library:AddToRegistry(Outer,{BorderColor3='Black';})
            Library:AddToRegistry(Inner,{BackgroundColor3='MainColor';})
            Library:OnHighlight(Outer,Outer,{BorderColor3='AccentColor'},{BorderColor3='Black'})
            return Outer,Inner,Lbl
        end

        local function InitEvents(B)
            local function WaitForEvent(event,timeout,validator)
                local bindable=Instance.new('BindableEvent')
                local connection=event:Once(function(...)
                    if typeof(validator)=='function' and validator(...) then bindable:Fire(true) else bindable:Fire(false) end
                end)
                task.delay(timeout,function() connection:disconnect(); bindable:Fire(false) end)
                return bindable.Event:Wait()
            end
            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame(Input) then return false end
                return Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch
            end
            B.Outer.InputBegan:Connect(function(Input)
                if B.Disabled then return end
                if not ValidateClick(Input) then return end
                if B.Locked then return end
                if B.DoubleClick then
                    Library:RemoveFromRegistry(B.Label); Library:AddToRegistry(B.Label,{TextColor3='AccentColor'})
                    B.Label.TextColor3=Library.AccentColor; B.Label.Text='Are you sure?'; B.Locked=true;
                    local clicked=WaitForEvent(B.Outer.InputBegan,0.5,ValidateClick)
                    Library:RemoveFromRegistry(B.Label); Library:AddToRegistry(B.Label,{TextColor3='FontColor'})
                    B.Label.TextColor3=Library.FontColor; B.Label.Text=B.Text; task.defer(rawset,B,'Locked',false);
                    if clicked then Library:SafeCallback(B.Func) end; return
                end
                Library:SafeCallback(B.Func);
            end)
        end

        Button.Outer,Button.Inner,Button.Label=CreateBaseButton(Button)
        Button.Outer.Parent=Container; InitEvents(Button);

        function Button:AddButton(...)
            local SubBtn=typeof(select(1,...))=="table" and select(1,...) or {Text=select(1,...),Func=select(2,...)}
            assert(typeof(SubBtn.Func)=='function','AddButton: `Func` callback is missing.');
            self.Outer.Size=UDim2.new(0.5,-2,0,20*DPIScale);
            SubBtn.Outer,SubBtn.Inner,SubBtn.Label=CreateBaseButton(SubBtn)
            SubBtn.Outer.Position=UDim2.new(1,3,0,0);
            SubBtn.Outer.Size=UDim2.fromOffset(self.Outer.AbsoluteSize.X-2,self.Outer.AbsoluteSize.Y);
            SubBtn.Outer.Parent=self.Outer;
            function SubBtn:UpdateColors() SubBtn.Label.TextColor3=SubBtn.Disabled and Library.DisabledAccentColor or Color3.new(1,1,1) end
            function SubBtn:AddToolTip(tt,dtt)
                if typeof(tt)=="string" or typeof(dtt)=="string" then
                    if SubBtn.TooltipTable then SubBtn.TooltipTable:Destroy() end
                    SubBtn.TooltipTable=Library:AddToolTip(tt,dtt,self.Outer); SubBtn.TooltipTable.Disabled=SubBtn.Disabled;
                end; return SubBtn;
            end
            function SubBtn:SetDisabled(D) SubBtn.Disabled=D; if SubBtn.TooltipTable then SubBtn.TooltipTable.Disabled=D end; SubBtn:UpdateColors() end
            function SubBtn:SetText(T) if typeof(T)=="string" then SubBtn.Text=T; SubBtn.Label.Text=T end end
            if typeof(SubBtn.Tooltip)=="string" or typeof(SubBtn.DisabledTooltip)=="string" then
                SubBtn.TooltipTable=SubBtn:AddToolTip(SubBtn.Tooltip,SubBtn.DisabledTooltip); SubBtn.TooltipTable.Disabled=SubBtn.Disabled;
            end
            task.delay(0.1,SubBtn.UpdateColors,SubBtn); InitEvents(SubBtn); table.insert(Buttons,SubBtn); return SubBtn;
        end

        function Button:UpdateColors() Button.Label.TextColor3=Button.Disabled and Library.DisabledAccentColor or Color3.new(1,1,1) end
        function Button:AddToolTip(tt,dtt)
            if typeof(tt)=="string" or typeof(dtt)=="string" then
                if Button.TooltipTable then Button.TooltipTable:Destroy() end
                Button.TooltipTable=Library:AddToolTip(tt,dtt,self.Outer); Button.TooltipTable.Disabled=Button.Disabled;
            end; return Button;
        end
        if typeof(Button.Tooltip)=="string" or typeof(Button.DisabledTooltip)=="string" then
            Button.TooltipTable=Button:AddToolTip(Button.Tooltip,Button.DisabledTooltip); Button.TooltipTable.Disabled=Button.Disabled;
        end
        function Button:SetVisible(V) IsVisible=V; Button.Outer.Visible=V; Groupbox:Resize() end
        function Button:SetText(T) if typeof(T)=="string" then Button.Text=T; Button.Label.Text=T end end
        function Button:SetDisabled(D) Button.Disabled=D; if Button.TooltipTable then Button.TooltipTable.Disabled=D end; Button:UpdateColors() end

        local Blank=Groupbox:AddBlank(4,IsVisible);
        task.delay(0.1,Button.UpdateColors,Button); Groupbox:Resize();
        table.insert(Buttons,Button); return Button;
    end

    function BaseGroupboxFuncs:AddDivider()
        local Groupbox=self; local Container=self.Container;
        Groupbox:AddBlank(2);
        local DOuter=Library:Create('Frame',{
            BackgroundColor3=Color3.new(0,0,0); BorderSizePixel=0;
            Size=UDim2.new(1,-4,0,1); ZIndex=5; Parent=Container;
        });
        local DInner=Library:Create('Frame',{
            BackgroundColor3=Library.OutlineColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=6; Parent=DOuter;
        });
        Library:AddToRegistry(DInner,{BackgroundColor3='OutlineColor';})
        Groupbox:AddBlank(4); Groupbox:Resize();
    end

    function BaseGroupboxFuncs:AddInput(Idx, Info)
        assert(Info.Text,'AddInput: Missing `Text` string.')
        Info.ClearTextOnFocus=if typeof(Info.ClearTextOnFocus)=="boolean" then Info.ClearTextOnFocus else true;
        local Textbox={
            Value=Info.Default or ''; Numeric=Info.Numeric or false; Finished=Info.Finished or false;
            Visible=if typeof(Info.Visible)=="boolean" then Info.Visible else true;
            Disabled=if typeof(Info.Disabled)=="boolean" then Info.Disabled else false;
            AllowEmpty=if typeof(Info.AllowEmpty)=="boolean" then Info.AllowEmpty else true;
            EmptyReset=if typeof(Info.EmptyReset)=="string" then Info.EmptyReset else "---";
            Type='Input'; Callback=Info.Callback or function() end;
        };
        local Groupbox=self; local Container=Groupbox.Container; local Blank;

        local InputLabel=Library:CreateLabel({
            Size=UDim2.new(1,0,0,14); TextSize=13; Text=Info.Text;
            TextXAlignment=Enum.TextXAlignment.Left; RichText=true; ZIndex=5; Parent=Container;
        });
        Groupbox:AddBlank(1);

        local TBOuter=Library:Create('Frame',{
            BackgroundColor3=Color3.new(0,0,0); BorderSizePixel=0;
            Size=UDim2.new(1,-4,0,20); ZIndex=5; Parent=Container;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=TBOuter;})
        local TBInner=Library:Create('Frame',{
            BackgroundColor3=Library.MainColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=6; Parent=TBOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=TBInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=TBInner;})
        Library:AddToRegistry(TBInner,{BackgroundColor3='MainColor';})
        Library:OnHighlight(TBOuter,TBOuter,{BorderColor3='AccentColor'},{BorderColor3='Black'})

        local TooltipTable;
        if typeof(Info.Tooltip)=="string" or typeof(Info.DisabledTooltip)=="string" then
            TooltipTable=Library:AddToolTip(Info.Tooltip,Info.DisabledTooltip,TBOuter); TooltipTable.Disabled=Textbox.Disabled;
        end

        local Cont=Library:Create('Frame',{
            BackgroundTransparency=1; ClipsDescendants=true;
            Position=UDim2.new(0,5,0,0); Size=UDim2.new(1,-5,1,0);
            ZIndex=7; Parent=TBInner;
        })
        local Box=Library:Create('TextBox',{
            BackgroundTransparency=1; Position=UDim2.fromOffset(0,0); Size=UDim2.fromScale(5,1);
            Font=Library.Font; PlaceholderColor3=Color3.fromRGB(90,98,115);
            PlaceholderText=Info.Placeholder or ''; Text=Info.Default or (if Textbox.AllowEmpty==false then Textbox.EmptyReset else "---");
            TextColor3=Library.FontColor; TextSize=13; TextStrokeTransparency=1;
            TextXAlignment=Enum.TextXAlignment.Left; RichText=true;
            TextEditable=not Textbox.Disabled; ClearTextOnFocus=not Textbox.Disabled and Info.ClearTextOnFocus;
            ZIndex=7; Parent=Cont;
        });
        Library:ApplyTextStroke(Box);
        Library:AddToRegistry(Box,{TextColor3='FontColor';})

        function Textbox:OnChanged(Func)
            Textbox.Changed=Func; if Textbox.Disabled then return end; Library:SafeCallback(Func,Textbox.Value);
        end
        function Textbox:UpdateColors()
            Box.TextColor3=Textbox.Disabled and Library.DisabledAccentColor or Library.FontColor;
            Library.RegistryMap[Box].Properties.TextColor3=Textbox.Disabled and 'DisabledAccentColor' or 'FontColor';
        end
        function Textbox:Display()
            TBOuter.Visible=Textbox.Visible; InputLabel.Visible=Textbox.Visible;
            if Blank then Blank.Visible=Textbox.Visible end; Groupbox:Resize();
        end
        function Textbox:SetValue(Text)
            if not Textbox.AllowEmpty and Trim(Text)=="" then Text=Textbox.EmptyReset end
            if Info.MaxLength and #Text>Info.MaxLength then Text=Text:sub(1,Info.MaxLength) end
            if Textbox.Numeric and not tonumber(Text) and Text:len()>0 then Text=Textbox.Value end
            Textbox.Value=Text; Box.Text=Text;
            if not Textbox.Disabled then Library:SafeCallback(Textbox.Callback,Textbox.Value); Library:SafeCallback(Textbox.Changed,Textbox.Value) end
        end
        function Textbox:SetVisible(V) Textbox.Visible=V; Textbox:Display() end
        function Textbox:SetDisabled(D)
            Textbox.Disabled=D; Box.TextEditable=not D; Box.ClearTextOnFocus=not D and Info.ClearTextOnFocus;
            if TooltipTable then TooltipTable.Disabled=D end; Textbox:UpdateColors();
        end

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter) if not enter then return end; Textbox:SetValue(Box.Text); Library:AttemptSave() end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function() Textbox:SetValue(Box.Text); Library:AttemptSave() end)
        end

        local function Update()
            local PADDING=2; local reveal=Cont.AbsoluteSize.X;
            if not Box:IsFocused() or Box.TextBounds.X<=reveal-2*PADDING then
                Box.Position=UDim2.new(0,PADDING,0,0)
            else
                local cursor=Box.CursorPosition
                if cursor~=-1 then
                    local subtext=string.sub(Box.Text,1,cursor-1)
                    local width=TextService:GetTextSize(subtext,Box.TextSize,Box.Font,Vector2.new(math.huge,math.huge)).X
                    local currentCursorPos=Box.Position.X.Offset+width
                    if currentCursorPos<PADDING then Box.Position=UDim2.fromOffset(PADDING-width,0)
                    elseif currentCursorPos>reveal-PADDING-1 then Box.Position=UDim2.fromOffset(reveal-width-PADDING-1,0) end
                end
            end
        end
        task.spawn(Update)
        Box:GetPropertyChangedSignal('Text'):Connect(Update); Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update);
        Box.FocusLost:Connect(Update); Box.Focused:Connect(Update);

        Blank=Groupbox:AddBlank(4,Textbox.Visible);
        task.delay(0.1,Textbox.UpdateColors,Textbox); Textbox:Display(); Groupbox:Resize();
        Options[Idx]=Textbox; return Textbox;
    end

    function BaseGroupboxFuncs:AddToggle(Idx, Info)
        assert(Info.Text,'AddToggle: Missing `Text` string.')
        local Toggle={
            Value=Info.Default or false; Type='Toggle';
            Visible=if typeof(Info.Visible)=="boolean" then Info.Visible else true;
            Disabled=if typeof(Info.Disabled)=="boolean" then Info.Disabled else false;
            Risky=if typeof(Info.Risky)=="boolean" then Info.Risky else false;
            OriginalText=Info.Text; Text=Info.Text;
            Callback=Info.Callback or function() end; Addons={};
        };
        local Blank; local Tooltip; local Groupbox=self; local Container=Groupbox.Container;

        -- Compact checkbox
        local ToggleOuter=Library:Create('Frame',{
            BackgroundColor3=Color3.new(0,0,0); BorderSizePixel=0;
            Size=UDim2.new(0,13,0,13); Visible=Toggle.Visible; ZIndex=5; Parent=Container;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=ToggleOuter;})
        local ToggleInner=Library:Create('Frame',{
            BackgroundColor3=Library.MainColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=6; Parent=ToggleOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=ToggleInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=ToggleInner;})
        Library:AddToRegistry(ToggleOuter,{BorderColor3='Black';})
        Library:AddToRegistry(ToggleInner,{BackgroundColor3='MainColor';})

        local ToggleLabel=Library:CreateLabel({
            Size=UDim2.new(0,216,2,0); Position=UDim2.new(1,6,-0.5,0);
            TextSize=13; Text=Info.Text; TextXAlignment=Enum.TextXAlignment.Left;
            RichText=true; ZIndex=6; Parent=ToggleInner;
        });
        Library:Create('UIListLayout',{
            Padding=UDim.new(0,4); FillDirection=Enum.FillDirection.Horizontal;
            HorizontalAlignment=Enum.HorizontalAlignment.Right; SortOrder=Enum.SortOrder.LayoutOrder; Parent=ToggleLabel;
        })

        local ToggleRegion=Library:Create('Frame',{
            BackgroundTransparency=1; Size=UDim2.new(0,170,1,0); ZIndex=8; Parent=ToggleOuter;
        });
        Library:OnHighlight(ToggleRegion,ToggleOuter,
            {BorderColor3='AccentColor'},{BorderColor3='Black'},
            function()
                if Toggle.Disabled then return false end
                for _,A in next,Toggle.Addons do if Library:MouseIsOverFrame(A.DisplayFrame) then return false end end
                return true
            end
        )

        function Toggle:UpdateColors() Toggle:Display() end
        if typeof(Info.Tooltip)=="string" or typeof(Info.DisabledTooltip)=="string" then
            Tooltip=Library:AddToolTip(Info.Tooltip,Info.DisabledTooltip,ToggleRegion); Tooltip.Disabled=Toggle.Disabled;
        end

        function Toggle:Display()
            if Toggle.Disabled then
                ToggleLabel.TextColor3=Library.DisabledTextColor;
                ToggleInner.BackgroundColor3=Toggle.Value and Library.DisabledAccentColor or Library.MainColor;
                Library.RegistryMap[ToggleInner].Properties.BackgroundColor3=Toggle.Value and 'DisabledAccentColor' or 'MainColor';
                Library.RegistryMap[ToggleLabel].Properties.TextColor3='DisabledTextColor'; return;
            end
            ToggleLabel.TextColor3=Toggle.Risky and Library.RiskColor or Library.FontColor;
            ToggleInner.BackgroundColor3=Toggle.Value and Library.AccentColor or Library.MainColor;
            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3=Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleLabel].Properties.TextColor3=Toggle.Risky and 'RiskColor' or 'FontColor';
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed=Func; if Toggle.Disabled then return end; Library:SafeCallback(Func,Toggle.Value);
        end
        function Toggle:SetValue(Bool)
            if Toggle.Disabled then return end; Bool=not not Bool; Toggle.Value=Bool; Toggle:Display();
            for _,A in next,Toggle.Addons do
                if A.Type=='KeyPicker' and A.SyncToggleState then A.Toggled=Bool; A:Update() end
            end
            if not Toggle.Disabled then Library:SafeCallback(Toggle.Callback,Toggle.Value); Library:SafeCallback(Toggle.Changed,Toggle.Value) end
            Library:UpdateDependencyBoxes();
        end
        function Toggle:SetVisible(V) Toggle.Visible=V; ToggleOuter.Visible=V; if Blank then Blank.Visible=V end; Groupbox:Resize() end
        function Toggle:SetDisabled(D)
            Toggle.Disabled=D; if Tooltip then Tooltip.Disabled=D end; Toggle:Display();
        end
        function Toggle:SetText(T) if typeof(T)=="string" then Toggle.Text=T; ToggleLabel.Text=T end end

        ToggleRegion.InputBegan:Connect(function(Input)
            if Toggle.Disabled then return end
            if (Input.UserInputType==Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType==Enum.UserInputType.Touch then
                for _,A in next,Toggle.Addons do if Library:MouseIsOverFrame(A.DisplayFrame) then return end end
                Toggle:SetValue(not Toggle.Value); Library:AttemptSave();
            end
        end)

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel); ToggleLabel.TextColor3=Library.RiskColor;
            Library:AddToRegistry(ToggleLabel,{TextColor3='RiskColor'})
        end

        Toggle:Display();
        Blank=Groupbox:AddBlank(Info.BlankSize or 7,Toggle.Visible);
        Groupbox:Resize();
        Toggle.TextLabel=ToggleLabel; Toggle.Container=Container;
        setmetatable(Toggle,BaseAddons);
        Toggles[Idx]=Toggle;
        Library:UpdateDependencyBoxes();
        return Toggle;
    end

    function BaseGroupboxFuncs:AddSlider(Idx, Info)
        assert(Info.Default,'AddSlider: Missing default value.'); assert(Info.Text,'AddSlider: Missing slider text.');
        assert(Info.Min,'AddSlider: Missing minimum value.'); assert(Info.Max,'AddSlider: Missing maximum value.');
        assert(Info.Rounding,'AddSlider: Missing rounding value.');
        local Slider={
            Value=Info.Default; Min=Info.Min; Max=Info.Max; Rounding=Info.Rounding; MaxSize=232;
            Type='Slider'; Visible=if typeof(Info.Visible)=="boolean" then Info.Visible else true;
            Disabled=if typeof(Info.Disabled)=="boolean" then Info.Disabled else false;
            OriginalText=Info.Text; Text=Info.Text;
            Prefix=typeof(Info.Prefix)=="string" and Info.Prefix or "";
            Suffix=typeof(Info.Suffix)=="string" and Info.Suffix or "";
            Callback=Info.Callback or function() end;
        };
        local Blanks={}; local SliderText=nil; local Groupbox=self; local Container=Groupbox.Container; local Tooltip;

        if not Info.Compact then
            SliderText=Library:CreateLabel({
                Size=UDim2.new(1,0,0,10); TextSize=13; Text=Info.Text;
                TextXAlignment=Enum.TextXAlignment.Left; TextYAlignment=Enum.TextYAlignment.Bottom;
                Visible=Slider.Visible; RichText=true; ZIndex=5; Parent=Container;
            });
            table.insert(Blanks,Groupbox:AddBlank(2,Slider.Visible));
        end

        local SliderOuter=Library:Create('Frame',{
            BackgroundColor3=Color3.new(0,0,0); BorderSizePixel=0;
            Size=UDim2.new(1,-4,0,10); Visible=Slider.Visible; ZIndex=5; Parent=Container;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=SliderOuter;})
        SliderOuter:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() Slider.MaxSize=SliderOuter.AbsoluteSize.X-2 end)
        Library:AddToRegistry(SliderOuter,{BorderColor3='Black';})

        local SliderInner=Library:Create('Frame',{
            BackgroundColor3=Library.MainColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=6; Parent=SliderOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=SliderInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=SliderInner;})
        Library:AddToRegistry(SliderInner,{BackgroundColor3='MainColor';})

        local Fill=Library:Create('Frame',{
            BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
            Size=UDim2.new(0,0,1,0); ZIndex=7; Parent=SliderInner;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=Fill;})
        Library:AddToRegistry(Fill,{BackgroundColor3='AccentColor';})

        -- Handle dot
        local Handle=Library:Create('Frame',{
            AnchorPoint=Vector2.new(0.5,0.5); BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
            Position=UDim2.new(0,0,0.5,0); Size=UDim2.new(0,8,0,8); ZIndex=9; Parent=SliderInner;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0.5,0);Parent=Handle;})
        Library:Create('UIStroke',{Color=Library.BackgroundColor;Thickness=1;Parent=Handle;})
        Library:AddToRegistry(Handle,{BackgroundColor3='AccentColor';})

        local DisplayLabel=Library:CreateLabel({
            Size=UDim2.new(1,0,0,0); AnchorPoint=Vector2.new(0,1);
            Position=UDim2.new(0,0,0,-2); TextSize=12; Text='';
            TextXAlignment=Enum.TextXAlignment.Right; RichText=true; ZIndex=9; Parent=SliderInner;
        });

        if typeof(Info.Tooltip)=="string" or typeof(Info.DisabledTooltip)=="string" then
            Tooltip=Library:AddToolTip(Info.Tooltip,Info.DisabledTooltip,SliderOuter); Tooltip.Disabled=Slider.Disabled;
        end

        Library:OnHighlight(SliderOuter,SliderOuter,{BorderColor3='AccentColor'},{BorderColor3='Black'},function() return not Slider.Disabled end)

        function Slider:UpdateColors()
            if SliderText then SliderText.TextColor3=Slider.Disabled and Library.DisabledAccentColor or Library.FontColor end
            DisplayLabel.TextColor3=Slider.Disabled and Library.DisabledAccentColor or Library.FontColor;
            Fill.BackgroundColor3=Slider.Disabled and Library.DisabledAccentColor or Library.AccentColor;
            Handle.BackgroundColor3=Slider.Disabled and Library.DisabledAccentColor or Library.AccentColor;
            Library.RegistryMap[Fill].Properties.BackgroundColor3=Slider.Disabled and 'DisabledAccentColor' or 'AccentColor';
            Library.RegistryMap[Handle].Properties.BackgroundColor3=Slider.Disabled and 'DisabledAccentColor' or 'AccentColor';
        end

        function Slider:Display()
            if Info.Compact then DisplayLabel.Text=Slider.Text..': '..Slider.Prefix..Slider.Value..Slider.Suffix;
            elseif Info.HideMax then DisplayLabel.Text=string.format('%s',Slider.Prefix..Slider.Value..Slider.Suffix);
            else DisplayLabel.Text=string.format('%s/%s',Slider.Prefix..Slider.Value..Slider.Suffix,Slider.Prefix..Slider.Max..Slider.Suffix); end
            local X=Library:MapValue(Slider.Value,Slider.Min,Slider.Max,0,1);
            Fill.Size=UDim2.new(X,0,1,0);
            Handle.Position=UDim2.new(X,0,0.5,0);
        end

        function Slider:OnChanged(Func)
            Slider.Changed=Func; if Slider.Disabled then return end; Library:SafeCallback(Func,Slider.Value);
        end
        local function Round(V)
            if Slider.Rounding==0 then return math.floor(V) end
            return tonumber(string.format('%.'..Slider.Rounding..'f',V))
        end
        function Slider:GetValueFromXScale(X) return Round(Library:MapValue(X,0,1,Slider.Min,Slider.Max)) end
        function Slider:SetMax(V) assert(V>Slider.Min,'Max>Min required'); Slider.Value=math.clamp(Slider.Value,Slider.Min,V); Slider.Max=V; Slider:Display() end
        function Slider:SetMin(V) assert(V<Slider.Max,'Min<Max required'); Slider.Value=math.clamp(Slider.Value,V,Slider.Max); Slider.Min=V; Slider:Display() end
        function Slider:SetValue(Str)
            if Slider.Disabled then return end; local Num=tonumber(Str); if not Num then return end
            Num=math.clamp(Num,Slider.Min,Slider.Max); Slider.Value=Num; Slider:Display();
            if not Slider.Disabled then Library:SafeCallback(Slider.Callback,Slider.Value); Library:SafeCallback(Slider.Changed,Slider.Value) end
        end
        function Slider:SetVisible(V)
            Slider.Visible=V; if SliderText then SliderText.Visible=V end; SliderOuter.Visible=V;
            for _,B in pairs(Blanks) do B.Visible=V end; Groupbox:Resize();
        end
        function Slider:SetDisabled(D) Slider.Disabled=D; if Tooltip then Tooltip.Disabled=D end; Slider:UpdateColors() end
        function Slider:SetText(T) if typeof(T)=="string" then Slider.Text=T; if SliderText then SliderText.Text=T end; Slider:Display() end end
        function Slider:SetPrefix(P) if typeof(P)=="string" then Slider.Prefix=P; Slider:Display() end end
        function Slider:SetSuffix(S) if typeof(S)=="string" then Slider.Suffix=S; Slider:Display() end end

        SliderInner.InputBegan:Connect(function(Input)
            if Slider.Disabled then return end
            if (Input.UserInputType==Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType==Enum.UserInputType.Touch then
                if Library.IsMobile then Library.CanDrag=false end
                local Sides={}; if Library.Window then Sides=Library.Window.Tabs[Library.ActiveTab]:GetSides() end
                for _,Side in pairs(Sides) do if typeof(Side)=="Instance" and Side:IsA("ScrollingFrame") then Side.ScrollingEnabled=false end end
                local mPos=Mouse.X; local gPos=Fill.AbsoluteSize.X;
                local Diff=mPos-(Fill.AbsolutePosition.X+gPos);
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos=Mouse.X; local nXOffset=math.clamp(gPos+(nMPos-mPos)+Diff,0,Slider.MaxSize);
                    local nXScale=Library:MapValue(nXOffset,0,Slider.MaxSize,0,1);
                    local nValue=Slider:GetValueFromXScale(nXScale); local OldValue=Slider.Value; Slider.Value=nValue;
                    Slider:Display();
                    if nValue~=OldValue then Library:SafeCallback(Slider.Callback,Slider.Value); Library:SafeCallback(Slider.Changed,Slider.Value) end
                    RenderStepped:Wait();
                end
                if Library.IsMobile then Library.CanDrag=true end
                for _,Side in pairs(Sides) do if typeof(Side)=="Instance" and Side:IsA("ScrollingFrame") then Side.ScrollingEnabled=true end end
                Library:AttemptSave();
            end
        end)

        task.delay(0.1,Slider.UpdateColors,Slider); Slider:Display();
        table.insert(Blanks,Groupbox:AddBlank(Info.BlankSize or 8,Slider.Visible));
        Groupbox:Resize();
        Options[Idx]=Slider; return Slider;
    end

    function BaseGroupboxFuncs:AddDropdown(Idx, Info)
        Info.ReturnInstanceInstead=if typeof(Info.ReturnInstanceInstead)=="boolean" then Info.ReturnInstanceInstead else false;
        if Info.SpecialType=='Player' then
            Info.ExcludeLocalPlayer=if typeof(Info.ExcludeLocalPlayer)=="boolean" then Info.ExcludeLocalPlayer else false;
            Info.Values=GetPlayers(Info.ExcludeLocalPlayer,Info.ReturnInstanceInstead); Info.AllowNull=true;
        elseif Info.SpecialType=='Team' then Info.Values=GetTeams(Info.ReturnInstanceInstead); Info.AllowNull=true; end
        assert(Info.Values,'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default,'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')
        Info.Searchable=if typeof(Info.Searchable)=="boolean" then Info.Searchable else false;
        Info.FormatDisplayValue=if typeof(Info.FormatDisplayValue)=="function" then Info.FormatDisplayValue else nil;
        if not Info.Text then Info.Compact=true end

        local Dropdown={
            Values=Info.Values; Value=Info.Multi and {};
            DisabledValues=Info.DisabledValues or {}; Multi=Info.Multi;
            Type='Dropdown'; SpecialType=Info.SpecialType;
            Visible=if typeof(Info.Visible)=="boolean" then Info.Visible else true;
            Disabled=if typeof(Info.Disabled)=="boolean" then Info.Disabled else false;
            Callback=Info.Callback or function() end;
            OriginalText=Info.Text; Text=Info.Text;
            ExcludeLocalPlayer=Info.ExcludeLocalPlayer; ReturnInstanceInstead=Info.ReturnInstanceInstead;
        };

        local DropdownLabel; local Blank; local CompactBlank; local Tooltip;
        local Groupbox=self; local Container=Groupbox.Container;

        if not Info.Compact then
            DropdownLabel=Library:CreateLabel({
                Size=UDim2.new(1,0,0,10); TextSize=13; Text=Info.Text;
                TextXAlignment=Enum.TextXAlignment.Left; TextYAlignment=Enum.TextYAlignment.Bottom;
                Visible=Dropdown.Visible; RichText=true; ZIndex=5; Parent=Container;
            });
            CompactBlank=Groupbox:AddBlank(2,Dropdown.Visible);
        end

        local DropdownOuter=Library:Create('Frame',{
            BackgroundColor3=Color3.new(0,0,0); BorderSizePixel=0;
            Size=UDim2.new(1,-4,0,20); Visible=Dropdown.Visible; ZIndex=5; Parent=Container;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=DropdownOuter;})
        Library:AddToRegistry(DropdownOuter,{BorderColor3='Black';})

        local DropdownInner=Library:Create('Frame',{
            BackgroundColor3=Library.MainColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=6; Parent=DropdownOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=DropdownInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=DropdownInner;})
        Library:AddToRegistry(DropdownInner,{BackgroundColor3='MainColor';})

        local DropdownInnerSearch;
        if Info.Searchable then
            DropdownInnerSearch=Library:Create('TextBox',{
                BackgroundTransparency=1; Visible=false; Position=UDim2.new(0,5,0,0); Size=UDim2.new(0.9,-5,1,0);
                Font=Library.Font; PlaceholderColor3=Color3.fromRGB(90,98,115); PlaceholderText='Search...';
                Text=''; TextColor3=Library.FontColor; TextSize=13; TextStrokeTransparency=1;
                TextXAlignment=Enum.TextXAlignment.Left; RichText=true; ClearTextOnFocus=false; ZIndex=7; Parent=DropdownOuter;
            });
            Library:AddToRegistry(DropdownInnerSearch,{TextColor3='FontColor';})
        end

        local DropdownArrow=Library:Create('ImageLabel',{
            AnchorPoint=Vector2.new(0,0.5); BackgroundTransparency=1;
            Position=UDim2.new(1,-15,0.5,0); Size=UDim2.new(0,11,0,11);
            Image='http://www.roblox.com/asset/?id=6282522798'; ZIndex=8; Parent=DropdownInner;
        });
        local ItemList=Library:CreateLabel({
            Position=UDim2.new(0,5,0,0); Size=UDim2.new(1,-5,1,0);
            TextSize=13; Text='--'; TextXAlignment=Enum.TextXAlignment.Left;
            TextWrapped=false; TextTruncate=Enum.TextTruncate.AtEnd; RichText=true; ZIndex=7; Parent=DropdownInner;
        });

        Library:OnHighlight(DropdownOuter,DropdownOuter,{BorderColor3='AccentColor'},{BorderColor3='Black'},function() return not Dropdown.Disabled end)
        if typeof(Info.Tooltip)=="string" or typeof(Info.DisabledTooltip)=="string" then
            Tooltip=Library:AddToolTip(Info.Tooltip,Info.DisabledTooltip,DropdownOuter); Tooltip.Disabled=Dropdown.Disabled;
        end

        local MAX_DD=if typeof(Info.MaxVisibleDropdownItems)=="number" then math.clamp(Info.MaxVisibleDropdownItems,4,16) else 8;
        local ListOuter=Library:Create('Frame',{
            BackgroundColor3=Color3.new(0,0,0); BorderSizePixel=0; ZIndex=20; Visible=false; Parent=ScreenGui;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=ListOuter;})
        local function RecalcPos() ListOuter.Position=UDim2.fromOffset(DropdownOuter.AbsolutePosition.X,DropdownOuter.AbsolutePosition.Y+DropdownOuter.Size.Y.Offset+1) end
        local function RecalcSize(YSize) local Y=YSize or math.clamp(GetTableSize(Dropdown.Values)*(18*DPIScale),0,MAX_DD*(18*DPIScale))+1; ListOuter.Size=UDim2.fromOffset(DropdownOuter.AbsoluteSize.X+0.5,Y) end
        RecalcPos(); RecalcSize();
        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalcPos);

        local ListInner=Library:Create('Frame',{
            BackgroundColor3=Library.MainColor; BorderSizePixel=0; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=21; Parent=ListOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=ListInner;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=ListInner;})
        Library:AddToRegistry(ListInner,{BackgroundColor3='MainColor';})
        local Scrolling=Library:Create('ScrollingFrame',{
            BackgroundTransparency=1; BorderSizePixel=0; CanvasSize=UDim2.new(0,0,0,0);
            Size=UDim2.new(1,0,1,0); ZIndex=21; Parent=ListInner;
            TopImage='rbxasset://textures/ui/Scroll/scroll-middle.png';
            BottomImage='rbxasset://textures/ui/Scroll/scroll-middle.png';
            ScrollBarThickness=3; ScrollBarImageColor3=Library.AccentColor;
        });
        Library:AddToRegistry(Scrolling,{ScrollBarImageColor3='AccentColor';})
        Library:Create('UIListLayout',{Padding=UDim.new(0,0);FillDirection=Enum.FillDirection.Vertical;SortOrder=Enum.SortOrder.LayoutOrder;Parent=Scrolling;})

        function Dropdown:UpdateColors()
            if DropdownLabel then DropdownLabel.TextColor3=Dropdown.Disabled and Library.DisabledAccentColor or Library.FontColor end
            ItemList.TextColor3=Dropdown.Disabled and Library.DisabledAccentColor or Library.FontColor;
            DropdownArrow.ImageColor3=Dropdown.Disabled and Library.DisabledAccentColor or Library.FontColor;
        end
        function Dropdown:Display()
            local Str='';
            if Info.Multi then
                for _,V in next,Dropdown.Values do
                    local SV=if typeof(V)=="Instance" then V.Name else V;
                    if Dropdown.Value[V] then Str=Str..(Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(SV)) or SV)..', ' end
                end
                Str=Str:sub(1,#Str-2); ItemList.Text=Str=='' and '--' or Str;
            else
                if not Dropdown.Value then ItemList.Text='--'; return end
                local SV=if typeof(Dropdown.Value)=="Instance" then Dropdown.Value.Name else Dropdown.Value;
                ItemList.Text=Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(SV)) or SV;
            end
        end
        function Dropdown:GetActiveValues()
            if Info.Multi then local T={}; for V in next,Dropdown.Value do table.insert(T,V) end; return T;
            else return Dropdown.Value and 1 or 0 end
        end
        function Dropdown:BuildDropdownList()
            local DisabledValues=Dropdown.DisabledValues; local Btns={};
            for _,El in next,Scrolling:GetChildren() do if not El:IsA('UIListLayout') then El:Destroy() end end
            local Count=0;
            for _,Value in next,Dropdown.Values do
                local SV=if typeof(Value)=="Instance" then Value.Name else Value;
                if Info.Searchable and not string.lower(SV):match(string.lower(DropdownInnerSearch.Text)) then continue end
                local IsDisabled=table.find(DisabledValues,SV); local Tbl={}; Count=Count+1;
                local Btn=Library:Create('TextButton',{
                    AutoButtonColor=false; BackgroundColor3=Library.MainColor; BorderSizePixel=0;
                    Size=UDim2.new(1,-1,0,18); Text=''; ZIndex=23; Parent=Scrolling;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=Btn;})
                Library:AddToRegistry(Btn,{BackgroundColor3='MainColor';})
                local BtnLabel=Library:CreateLabel({
                    Active=false; Size=UDim2.new(1,-6,1,0); Position=UDim2.new(0,6,0,0);
                    TextSize=13; Text=Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(SV)) or SV;
                    TextXAlignment=Enum.TextXAlignment.Left; RichText=true; ZIndex=25; Parent=Btn;
                });
                Library:OnHighlight(Btn,Btn,{BorderColor3=IsDisabled and 'DisabledAccentColor' or 'AccentColor',ZIndex=24},{BorderColor3='OutlineColor',ZIndex=23})
                local Selected=Info.Multi and Dropdown.Value[Value] or (Dropdown.Value==Value);
                function Tbl:UpdateButton()
                    Selected=Info.Multi and Dropdown.Value[Value] or (Dropdown.Value==Value);
                    BtnLabel.TextColor3=Selected and Library.AccentColor or (IsDisabled and Library.DisabledAccentColor or Library.FontColor);
                    Library.RegistryMap[BtnLabel].Properties.TextColor3=Selected and 'Accent
                                        Library.RegistryMap[BtnLabel].Properties.TextColor3=Selected and 'AccentColor' or (IsDisabled and 'DisabledAccentColor' or 'FontColor');
                end
                if not IsDisabled then
                    Btn.MouseButton1Click:Connect(function()
                        local Try=not Selected;
                        if Dropdown:GetActiveValues()==1 and not Try and not Info.AllowNull then
                        else
                            if Info.Multi then
                                Selected=Try; if Selected then Dropdown.Value[Value]=true else Dropdown.Value[Value]=nil end
                            else
                                Selected=Try; if Selected then Dropdown.Value=Value else Dropdown.Value=nil end
                                for _,OB in next,Btns do OB:UpdateButton() end
                            end
                            Tbl:UpdateButton(); Dropdown:Display();
                            Library:UpdateDependencyBoxes();
                            Library:SafeCallback(Dropdown.Callback,Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed,Dropdown.Value);
                            Library:AttemptSave();
                        end
                    end)
                end
                Tbl:UpdateButton(); Dropdown:Display(); Btns[Btn]=Tbl;
            end
            Scrolling.CanvasSize=UDim2.fromOffset(0,(Count*(18*DPIScale))+1);
            Scrolling.Visible=false; Scrolling.Visible=true;
            local Y=math.clamp(Count*(18*DPIScale),0,MAX_DD*(18*DPIScale))+1; RecalcSize(Y);
        end

        function Dropdown:SetValues(NV) if NV then Dropdown.Values=NV end; Dropdown:BuildDropdownList() end
        function Dropdown:AddValues(NV)
            if typeof(NV)=="table" then for _,v in pairs(NV) do table.insert(Dropdown.Values,v) end
            elseif typeof(NV)=="string" then table.insert(Dropdown.Values,NV) else return end
            Dropdown:BuildDropdownList()
        end
        function Dropdown:SetDisabledValues(NV) if NV then Dropdown.DisabledValues=NV end; Dropdown:BuildDropdownList() end
        function Dropdown:AddDisabledValues(DV)
            if typeof(DV)=="table" then for _,v in pairs(DV) do table.insert(Dropdown.DisabledValues,v) end
            elseif typeof(DV)=="string" then table.insert(Dropdown.DisabledValues,DV) else return end
            Dropdown:BuildDropdownList()
        end
        function Dropdown:SetVisible(V)
            Dropdown.Visible=V; DropdownOuter.Visible=V;
            if DropdownLabel then DropdownLabel.Visible=V end
            if not V then Dropdown:CloseDropdown() end; Groupbox:Resize();
        end
        function Dropdown:SetDisabled(D)
            Dropdown.Disabled=D; if Tooltip then Tooltip.Disabled=D end
            if D then Dropdown:CloseDropdown() end; Dropdown:Display(); Dropdown:UpdateColors();
        end
        function Dropdown:OpenDropdown()
            if Dropdown.Disabled then return end
            if Library.IsMobile then Library.CanDrag=false end
            if Info.Searchable then ItemList.Visible=false; DropdownInnerSearch.Text=""; DropdownInnerSearch.Visible=true end
            ListOuter.Visible=true; Library.OpenedFrames[ListOuter]=true; DropdownArrow.Rotation=180; RecalcSize();
        end
        function Dropdown:CloseDropdown()
            if Library.IsMobile then Library.CanDrag=true end
            if Info.Searchable then DropdownInnerSearch.Text=""; DropdownInnerSearch.Visible=false; ItemList.Visible=true end
            ListOuter.Visible=false; Library.OpenedFrames[ListOuter]=nil; DropdownArrow.Rotation=0;
        end
        function Dropdown:OnChanged(Func)
            Dropdown.Changed=Func; if Dropdown.Disabled then return end; Library:SafeCallback(Func,Dropdown.Value);
        end
        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nT={}; for V,_ in next,Val do if table.find(Dropdown.Values,V) then nT[V]=true end end; Dropdown.Value=nT;
            else if not Val then Dropdown.Value=nil; elseif table.find(Dropdown.Values,Val) then Dropdown.Value=Val end end
            Dropdown:BuildDropdownList();
            if not Dropdown.Disabled then Library:SafeCallback(Dropdown.Callback,Dropdown.Value); Library:SafeCallback(Dropdown.Changed,Dropdown.Value) end
        end
        function Dropdown:SetText(Text)
            if typeof(Text)=="string" then
                if Info.Compact then Info.Compact=false end; Dropdown.Text=Text;
                if DropdownLabel then DropdownLabel.Text=Text end; Dropdown:Display();
            end
        end

        DropdownOuter.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then return end
            if (Input.UserInputType==Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType==Enum.UserInputType.Touch then
                if ListOuter.Visible then Dropdown:CloseDropdown() else Dropdown:OpenDropdown() end
            end
        end)
        if Info.Searchable then
            DropdownInnerSearch:GetPropertyChangedSignal("Text"):Connect(function() Dropdown:BuildDropdownList() end)
        end
        InputService.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then return end
            if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then
                local AbsPos,AbsSize=ListOuter.AbsolutePosition,ListOuter.AbsoluteSize;
                if Mouse.X<AbsPos.X or Mouse.X>AbsPos.X+AbsSize.X or Mouse.Y<(AbsPos.Y-(18*DPIScale)) or Mouse.Y>AbsPos.Y+AbsSize.Y then
                    Dropdown:CloseDropdown()
                end
            end
        end)

        Dropdown:BuildDropdownList(); Dropdown:Display();
        local Defaults={}
        if typeof(Info.Default)=="string" then
            local i=table.find(Dropdown.Values,Info.Default); if i then table.insert(Defaults,i) end
        elseif typeof(Info.Default)=='table' then
            for _,V in next,Info.Default do local i=table.find(Dropdown.Values,V); if i then table.insert(Defaults,i) end end
        elseif typeof(Info.Default)=='number' and Dropdown.Values[Info.Default]~=nil then
            table.insert(Defaults,Info.Default)
        end
        if next(Defaults) then
            for i=1,#Defaults do
                local Index=Defaults[i]
                if Info.Multi then Dropdown.Value[Dropdown.Values[Index]]=true
                else Dropdown.Value=Dropdown.Values[Index] end
                if not Info.Multi then break end
            end
            Dropdown:BuildDropdownList(); Dropdown:Display();
        end

        task.delay(0.1,Dropdown.UpdateColors,Dropdown)
        Blank=Groupbox:AddBlank(Info.BlankSize or 5,Dropdown.Visible);
        Groupbox:Resize();
        Options[Idx]=Dropdown;
        return Dropdown;
    end

    function BaseGroupboxFuncs:AddDependencyBox()
        local Depbox={Dependencies={}};
        local Groupbox=self; local Container=Groupbox.Container;
        local Holder=Library:Create('Frame',{
            BackgroundTransparency=1; Size=UDim2.new(1,0,0,0); Visible=false; Parent=Container;
        });
        local Frame=Library:Create('Frame',{
            BackgroundTransparency=1; Size=UDim2.new(1,0,1,0); Visible=true; Parent=Holder;
        });
        local Layout=Library:Create('UIListLayout',{
            FillDirection=Enum.FillDirection.Vertical; SortOrder=Enum.SortOrder.LayoutOrder; Parent=Frame;
        });
        function Depbox:Resize()
            Holder.Size=UDim2.new(1,0,0,Layout.AbsoluteContentSize.Y); Groupbox:Resize();
        end
        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Depbox:Resize() end)
        Holder:GetPropertyChangedSignal('Visible'):Connect(function() Depbox:Resize() end)
        function Depbox:Update()
            for _,Dep in next,Depbox.Dependencies do
                local Elem=Dep[1]; local Value=Dep[2];
                if if Elem.Multi then not table.find(Elem:GetActiveValues(),Value) else Elem.Value~=Value then
                    Holder.Visible=false; Depbox:Resize(); return;
                end
            end
            Holder.Visible=true; Depbox:Resize();
        end
        function Depbox:SetupDependencies(Dependencies)
            for _,Dep in next,Dependencies do
                assert(typeof(Dep)=='table','SetupDependencies: Dependency must be a table.');
                assert(Dep[1],'SetupDependencies: Missing element.'); assert(Dep[2]~=nil,'SetupDependencies: Missing value.');
            end
            Depbox.Dependencies=Dependencies; Depbox:Update();
        end
        Depbox.Container=Frame;
        setmetatable(Depbox,BaseGroupbox);
        table.insert(Library.DependencyBoxes,Depbox);
        return Depbox;
    end

    BaseGroupbox.__index=BaseGroupboxFuncs;
    BaseGroupbox.__namecall=function(Table,Key,...) return BaseGroupboxFuncs[Key](...) end;
end

-- ================================================================
-- NOTIFICATION + WATERMARK + KEYBIND AREAS
-- ================================================================
do
    Library.LeftNotificationArea=Library:Create('Frame',{
        BackgroundTransparency=1; Position=UDim2.new(0,0,0,40);
        Size=UDim2.new(0,300,0,200); ZIndex=100; Parent=ScreenGui;
    });
    Library:Create('UIListLayout',{Padding=UDim.new(0,4);FillDirection=Enum.FillDirection.Vertical;SortOrder=Enum.SortOrder.LayoutOrder;Parent=Library.LeftNotificationArea;})

    Library.RightNotificationArea=Library:Create('Frame',{
        AnchorPoint=Vector2.new(1,0); BackgroundTransparency=1;
        Position=UDim2.new(1,0,0,40); Size=UDim2.new(0,300,0,200); ZIndex=100; Parent=ScreenGui;
    });
    Library:Create('UIListLayout',{Padding=UDim.new(0,4);FillDirection=Enum.FillDirection.Vertical;HorizontalAlignment=Enum.HorizontalAlignment.Right;SortOrder=Enum.SortOrder.LayoutOrder;Parent=Library.RightNotificationArea;})

    -- Watermark — compact dark bar
    local WatermarkOuter=Library:Create('Frame',{
        BorderSizePixel=0; Position=UDim2.new(0,100,0,-28);
        Size=UDim2.new(0,200,0,22); ZIndex=200; Visible=false; Parent=ScreenGui;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=WatermarkOuter;})
    local WatermarkInner=Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        Size=UDim2.new(1,0,1,0); ZIndex=201; Parent=WatermarkOuter;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=WatermarkInner;})
    Library:Create('UIStroke',{Color=Library.AccentColor;Thickness=1;Parent=WatermarkInner;})
    Library:AddToRegistry(WatermarkInner,{BackgroundColor3='MainColor';})
    local WatermarkLabel=Library:CreateLabel({
        Position=UDim2.new(0,6,0,0); Size=UDim2.new(1,-6,1,0);
        TextSize=13; TextXAlignment=Enum.TextXAlignment.Left; RichText=true; ZIndex=203; Parent=WatermarkInner;
    });
    Library.Watermark=WatermarkOuter; Library.WatermarkText=WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);

    -- Keybind frame
    local KeybindOuter=Library:Create('Frame',{
        AnchorPoint=Vector2.new(0,0.5); BorderSizePixel=0;
        Position=UDim2.new(0,10,0.5,0); Size=UDim2.new(0,210,0,22);
        Visible=false; ZIndex=100; Parent=ScreenGui;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=KeybindOuter;})
    local KeybindInner=Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        Size=UDim2.new(1,0,1,0); ZIndex=101; Parent=KeybindOuter;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=KeybindInner;})
    Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=KeybindInner;})
    Library:AddToRegistry(KeybindInner,{BackgroundColor3='MainColor';}, true)
    local KbAccentBar=Library:Create('Frame',{
        BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
        Size=UDim2.new(1,0,0,1); ZIndex=102; Parent=KeybindInner;
    });
    Library:AddToRegistry(KbAccentBar,{BackgroundColor3='AccentColor';}, true)
    local KeybindLabel=Library:CreateLabel({
        Size=UDim2.new(1,0,0,18); Position=UDim2.fromOffset(5,2);
        TextXAlignment=Enum.TextXAlignment.Left; Text='Keybinds'; RichText=true; ZIndex=104; Parent=KeybindInner;
    });
    Library:MakeDraggable(KeybindOuter);
    local KeybindContainer=Library:Create('Frame',{
        BackgroundTransparency=1; Size=UDim2.new(1,0,1,-20);
        Position=UDim2.new(0,0,0,20); ZIndex=1; Parent=KeybindInner;
    });
    Library:Create('UIListLayout',{FillDirection=Enum.FillDirection.Vertical;SortOrder=Enum.SortOrder.LayoutOrder;Parent=KeybindContainer;})
    Library:Create('UIPadding',{PaddingLeft=UDim.new(0,5);Parent=KeybindContainer;})
    Library.KeybindFrame=KeybindOuter; Library.KeybindContainer=KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end

function Library:SetWatermarkVisibility(Bool) Library.Watermark.Visible=Bool end
function Library:SetWatermark(Text)
    local X,Y=Library:GetTextBounds(Text,Library.Font,13);
    Library.Watermark.Size=UDim2.new(0,X+16,0,(Y*1.4)+4);
    Library:SetWatermarkVisibility(true); Library.WatermarkText.Text=Text;
end
function Library:SetNotifySide(Side) Library.NotifySide=Side end

function Library:Notify(...)
    local Data={Steps=1}
    local Info=select(1,...)
    if typeof(Info)=="table" then
        Data.Title=Info.Title and tostring(Info.Title) or ""; Data.Description=tostring(Info.Description);
        Data.Time=Info.Time or 5; Data.SoundId=Info.SoundId;
    else
        Data.Title=""; Data.Description=tostring(Info); Data.Time=select(2,...) or 5; Data.SoundId=select(3,...);
    end
    local Side=string.lower(Library.NotifySide);
    local XSize,YSize=Library:GetTextBounds(Data.Description,Library.Font,13); YSize=YSize+6;

    local NotifyOuter=Library:Create('Frame',{
        BorderSizePixel=0; Size=UDim2.new(0,0,0,YSize); ClipsDescendants=true; ZIndex=100;
        Parent=if Side=="left" then Library.LeftNotificationArea else Library.RightNotificationArea;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=NotifyOuter;})
    local NotifyInner=Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        Size=UDim2.new(1,0,1,0); ZIndex=101; Parent=NotifyOuter;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=NotifyInner;})
    Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=NotifyInner;})
    Library:AddToRegistry(NotifyInner,{BackgroundColor3='MainColor';}, true)

    local NotifyLabel=Library:CreateLabel({
        AnchorPoint=if Side=="left" then Vector2.new(0,0) else Vector2.new(1,0);
        Position=if Side=="left" then UDim2.new(0,6,0,0) else UDim2.new(1,-6,0,0);
        Size=UDim2.new(1,-6,1,0);
        Text=(if Data.Title=="" then "" else "["..Data.Title.."] ")..tostring(Data.Description);
        TextXAlignment=if Side=="left" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right;
        TextSize=13; RichText=true; ZIndex=103; Parent=NotifyInner;
    });
    local SideColor=Library:Create('Frame',{
        AnchorPoint=if Side=="left" then Vector2.new(0,0) else Vector2.new(1,0);
        Position=if Side=="left" then UDim2.new(0,-1,0,-1) else UDim2.new(1,-1,0,-1);
        BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
        Size=UDim2.new(0,2,1,2); ZIndex=104; Parent=NotifyOuter;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=SideColor;})
    Library:AddToRegistry(SideColor,{BackgroundColor3='AccentColor';}, true)

    function Data:Resize()
        XSize,YSize=Library:GetTextBounds(NotifyLabel.Text,Library.Font,13); YSize=YSize+6;
        pcall(NotifyOuter.TweenSize,NotifyOuter,UDim2.new(0,XSize*DPIScale+10+4,0,YSize),'Out','Quad',0.35,true);
    end
    function Data:ChangeTitle(T)
        T=if T==nil then "" else tostring(T); Data.Title=T;
        NotifyLabel.Text=(if Data.Title=="" then "" else "["..Data.Title.."] ")..tostring(Data.Description); Data:Resize();
    end
    function Data:ChangeDescription(T)
        if T==nil then return end; T=tostring(T); Data.Description=T;
        NotifyLabel.Text=(if Data.Title=="" then "" else "["..Data.Title.."] ")..tostring(Data.Description); Data:Resize();
    end
    function Data:ChangeStep() end

    Data:Resize();
    if Data.SoundId then
        Library:Create('Sound',{
            SoundId="rbxassetid://"..tostring(Data.SoundId):gsub("rbxassetid://","");
            Volume=3; PlayOnRemove=true; Parent=game:GetService("SoundService");
        }):Destroy();
    end
    pcall(NotifyOuter.TweenSize,NotifyOuter,UDim2.new(0,XSize*DPIScale+10+4,0,YSize),'Out','Quad',0.35,true);
    task.spawn(function()
        if typeof(Data.Time)=="Instance" then Data.Time.Destroying:Wait()
        else task.wait(Data.Time or 5) end
        pcall(NotifyOuter.TweenSize,NotifyOuter,UDim2.new(0,0,0,YSize),'Out','Quad',0.35,true);
        task.wait(0.35); NotifyOuter:Destroy();
    end)
    return Data
end

-- ================================================================
-- CREATE WINDOW — redesigned to match screenshot layout
-- Screenshot: dark window, top nav bar (logo + search + tabs with
-- orange underline indicator), secondary tab bar, two-column
-- content, compact footer with language icon + text.
-- ================================================================
function Library:CreateWindow(...)
    local Arguments={...}; local Config={AnchorPoint=Vector2.zero};
    if typeof(...)=='table' then Config=... else Config.Title=Arguments[1]; Config.AutoShow=Arguments[2] or false end
    if typeof(Config.Title)~="string" then Config.Title='No title' end
    if typeof(Config.TabPadding)~='number' then Config.TabPadding=1 end
    if typeof(Config.MenuFadeTime)~='number' then Config.MenuFadeTime=0.2 end
    if typeof(Config.NotifySide)~="string" then Library.NotifySide='Left' else Library.NotifySide=Config.NotifySide end
    if typeof(Config.ShowCustomCursor)~='boolean' then Library.ShowCustomCursor=true else Library.ShowCustomCursor=Config.ShowCustomCursor end
    if typeof(Config.Position)~='UDim2' then Config.Position=UDim2.fromOffset(160,50) end
    if typeof(Config.Size)~='UDim2' then
        if Library.IsMobile then
            local VPY=tonumber(workspace.CurrentCamera.ViewportSize.Y)-35;
            Config.Size=UDim2.fromOffset(600,math.clamp(VPY,200,600))
        else Config.Size=UDim2.fromOffset(600,520) end
    end
    if Config.TabPadding<=0 then Config.TabPadding=1 end
    if Config.Center then Config.Position=UDim2.new(0.5,-Config.Size.X.Offset/2,0.5,-Config.Size.Y.Offset/2) end

    local Window={Tabs={}; OriginalTitle=Config.Title; Title=Config.Title;};

    -- ── Outer shell ──────────────────────────────────────────────
    local Outer=Library:Create('Frame',{
        AnchorPoint=Config.AnchorPoint; BackgroundColor3=Color3.new(0,0,0);
        BorderSizePixel=0; Position=Config.Position; Size=Config.Size;
        Visible=false; ZIndex=1; Parent=ScreenGui;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,8);Parent=Outer;})

    local Inner=Library:Create('Frame',{
        BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
        Position=UDim2.new(0,1,0,1); Size=UDim2.new(1,-2,1,-2); ZIndex=1; Parent=Outer;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,8);Parent=Inner;})
    Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=Outer;})
    Library:AddToRegistry(Inner,{BackgroundColor3='BackgroundColor';})

    LibraryMainOuterFrame=Outer;

    -- ── Top navigation bar ───────────────────────────────────────
    -- Height 36px. Left: logo placeholder (24px square). Search field.
    -- Right: horizontal tab buttons. Orange underline on active tab.
    local NavBar=Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        Size=UDim2.new(1,0,0,36); ZIndex=2; Parent=Inner;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,8);Parent=NavBar;})
    -- mask bottom corners so it merges with content
    local NavBarBottomMask=Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        Position=UDim2.new(0,0,0.5,0); Size=UDim2.new(1,0,0.5,0); ZIndex=2; Parent=NavBar;
    });
    Library:AddToRegistry(NavBar,{BackgroundColor3='MainColor';})
    Library:AddToRegistry(NavBarBottomMask,{BackgroundColor3='MainColor';})
    -- thin separator line at bottom of navbar
    local NavSep=Library:Create('Frame',{
        BackgroundColor3=Library.OutlineColor; BorderSizePixel=0;
        Position=UDim2.new(0,0,1,0); Size=UDim2.new(1,0,0,1); ZIndex=3; Parent=NavBar;
    });
    Library:AddToRegistry(NavSep,{BackgroundColor3='OutlineColor';})

    -- Logo placeholder — 28×28, top-left
    local LogoHolder=Library:Create('Frame',{
        BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
        Position=UDim2.new(0,6,0.5,-13); Size=UDim2.new(0,26,0,26); ZIndex=3; Parent=NavBar;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=LogoHolder;})
    Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=LogoHolder;})
    Library:AddToRegistry(LogoHolder,{BackgroundColor3='BackgroundColor';})
    -- small accent dot as placeholder visual
    local LogoDot=Library:Create('Frame',{
        AnchorPoint=Vector2.new(0.5,0.5); BackgroundColor3=Library.AccentColor;
        BorderSizePixel=0; Position=UDim2.fromScale(0.5,0.5);
        Size=UDim2.new(0,8,0,8); ZIndex=4; Parent=LogoHolder;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0.5,0);Parent=LogoDot;})
    Library:AddToRegistry(LogoDot,{BackgroundColor3='AccentColor';})
    Library.LogoHolder=LogoHolder;

    -- Search field
    local SearchHolder=Library:Create('Frame',{
        BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
        Position=UDim2.new(0,38,0.5,-10); Size=UDim2.new(0,120,0,20); ZIndex=3; Parent=NavBar;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=SearchHolder;})
    Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=SearchHolder;})
    Library:AddToRegistry(SearchHolder,{BackgroundColor3='BackgroundColor';})
    local SearchIcon=Library:CreateLabel({
        Position=UDim2.new(0,4,0,0); Size=UDim2.new(0,14,1,0);
        TextSize=13; Text='🔍'; ZIndex=4; Parent=SearchHolder;
    });
    local SearchBox=Library:Create('TextBox',{
        BackgroundTransparency=1; Position=UDim2.new(0,18,0,0);
        Size=UDim2.new(1,-20,1,0); Font=Library.Font;
        PlaceholderColor3=Library.DisabledTextColor; PlaceholderText='Search...';
        Text=''; TextColor3=Library.FontColor; TextSize=13;
        TextStrokeTransparency=1; TextXAlignment=Enum.TextXAlignment.Left;
        ClearTextOnFocus=false; ZIndex=4; Parent=SearchHolder;
    });
    Library:AddToRegistry(SearchBox,{TextColor3='FontColor';})
    Library.SearchBox=SearchBox;

    -- Nav tab container — horizontal, right of search
    local NavTabArea=Library:Create('Frame',{
        BackgroundTransparency=1;
        Position=UDim2.new(0,164,0,0); Size=UDim2.new(1,-170,1,0);
        ZIndex=3; Parent=NavBar;
    });
    Library:Create('UIListLayout',{
        Padding=UDim.new(0,0); FillDirection=Enum.FillDirection.Horizontal;
        SortOrder=Enum.SortOrder.LayoutOrder; VerticalAlignment=Enum.VerticalAlignment.Center;
        Parent=NavTabArea;
    })

    -- ── Secondary sub-tab bar ────────────────────────────────────
    -- Dark strip, height 28px, compact rectangular tabs
    local SubBar=Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        Position=UDim2.new(0,0,0,36); Size=UDim2.new(1,0,0,28); ZIndex=2; Parent=Inner;
    });
    Library:AddToRegistry(SubBar,{BackgroundColor3='MainColor';})
    local SubBarSep=Library:Create('Frame',{
        BackgroundColor3=Library.OutlineColor; BorderSizePixel=0;
        Position=UDim2.new(0,0,1,0); Size=UDim2.new(1,0,0,1); ZIndex=3; Parent=SubBar;
    });
    Library:AddToRegistry(SubBarSep,{BackgroundColor3='OutlineColor';})
    local SubTabArea=Library:Create('Frame',{
        BackgroundTransparency=1; Position=UDim2.new(0,6,0,4);
        Size=UDim2.new(1,-12,1,-4); ZIndex=3; Parent=SubBar;
    });
    Library:Create('UIListLayout',{
        Padding=UDim.new(0,4); FillDirection=Enum.FillDirection.Horizontal;
        SortOrder=Enum.SortOrder.LayoutOrder; VerticalAlignment=Enum.VerticalAlignment.Center;
        Parent=SubTabArea;
    })

    -- ── Content area ─────────────────────────────────────────────
    -- Two-column scrollable, below sub-bar, above footer
    local ContentArea=Library:Create('Frame',{
        BackgroundTransparency=1;
        Position=UDim2.new(0,0,0,65); Size=UDim2.new(1,0,1,-65-24);
        ZIndex=2; Parent=Inner;
    });
    local TabContentContainer=Library:Create('Frame',{
        BackgroundTransparency=1; Size=UDim2.new(1,0,1,0); ZIndex=2; Parent=ContentArea;
    });

    -- ── Footer ───────────────────────────────────────────────────
    -- 24px, thin top border, language icon + text on left
    local Footer=Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        AnchorPoint=Vector2.new(0,1); Position=UDim2.new(0,0,1,0);
        Size=UDim2.new(1,0,0,24); ZIndex=2; Parent=Inner;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,8);Parent=Footer;})
    local FooterTopMask=Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        Position=UDim2.new(0,0,0,0); Size=UDim2.new(1,0,0.5,0); ZIndex=2; Parent=Footer;
    });
    Library:AddToRegistry(Footer,{BackgroundColor3='MainColor';})
    Library:AddToRegistry(FooterTopMask,{BackgroundColor3='MainColor';})
    local FooterTopSep=Library:Create('Frame',{
        BackgroundColor3=Library.OutlineColor; BorderSizePixel=0;
        Position=UDim2.new(0,0,0,0); Size=UDim2.new(1,0,0,1); ZIndex=3; Parent=Footer;
    });
    Library:AddToRegistry(FooterTopSep,{BackgroundColor3='OutlineColor';})
    -- Language / status icon placeholder
    local FooterIcon=Library:Create('Frame',{
        BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
        Position=UDim2.new(0,6,0.5,-6); Size=UDim2.new(0,12,0,12); ZIndex=3; Parent=Footer;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0.5,0);Parent=FooterIcon;})
    Library:AddToRegistry(FooterIcon,{BackgroundColor3='AccentColor';})
    local FooterLabel=Library:CreateLabel({
        Position=UDim2.new(0,22,0,0); Size=UDim2.new(0,120,1,0);
        TextSize=12; Text='English'; TextXAlignment=Enum.TextXAlignment.Left;
        ZIndex=3; Parent=Footer;
    });
    Library.FooterLabel=FooterLabel; Library.FooterIcon=FooterIcon;

    Library:MakeDraggable(Inner,36,true);
    if Config.Resizable then Library:MakeResizable(Outer,Library.MinSize) end

    -- Video background (preserved from original)
    local InnerVideoBackground=Library:Create('VideoFrame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        Position=UDim2.new(0,0,0,0); Size=UDim2.new(1,0,1,0);
        ZIndex=2; Visible=false; Volume=0; Looped=true; Parent=TabContentContainer;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=InnerVideoBackground;})
    Library.InnerVideoBackground=InnerVideoBackground;

    function Window:SetWindowTitle(Title)
        if typeof(Title)=="string" then Window.Title=Title end
    end

    -- ── AddTab — creates nav button + sub-tab support + two-column content ──
    function Window:AddTab(Name)
        local Tab={Groupboxes={}; Tabboxes={}; OriginalName=Name; Name=Name;};

        -- NAV button (top bar)
        local NavBtnWidth=Library:GetTextBounds(Tab.Name,Library.Font,13)+20;
        local NavBtn=Library:Create('Frame',{
            BackgroundTransparency=1; BorderSizePixel=0;
            Size=UDim2.new(0,NavBtnWidth,1,0); ZIndex=4; Parent=NavTabArea;
        });
        local NavBtnLabel=Library:CreateLabel({
            Size=UDim2.new(1,0,1,-2); TextSize=13; Text=Tab.Name;
            TextColor3=Library.DisabledTextColor; RichText=true; ZIndex=5; Parent=NavBtn;
        });
        -- orange underline indicator
        local NavIndicator=Library:Create('Frame',{
            BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
            AnchorPoint=Vector2.new(0,1); Position=UDim2.new(0,4,1,0);
            Size=UDim2.new(1,-8,0,2); ZIndex=5; Visible=false; Parent=NavBtn;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,1);Parent=NavIndicator;})
        Library:AddToRegistry(NavIndicator,{BackgroundColor3='AccentColor';})

        -- TAB frame (content area)
        local TabFrame=Library:Create('Frame',{
            BackgroundTransparency=1; Position=UDim2.new(0,0,0,0);
            Size=UDim2.new(1,0,1,0); Visible=false; ZIndex=2; Parent=TabContentContainer;
        });

        -- Two-column scrolling sides
        local LeftSide=Library:Create('ScrollingFrame',{
            BackgroundTransparency=1; BorderSizePixel=0;
            Position=UDim2.new(0,6,0,4); Size=UDim2.new(0.5,-9,1,-8);
            CanvasSize=UDim2.new(0,0,0,0); BottomImage=''; TopImage='';
            ScrollBarThickness=2; ScrollBarImageColor3=Library.AccentColor;
            ZIndex=2; Parent=TabFrame;
        });
        Library:AddToRegistry(LeftSide,{ScrollBarImageColor3='AccentColor';})
        local RightSide=Library:Create('ScrollingFrame',{
            BackgroundTransparency=1; BorderSizePixel=0;
            Position=UDim2.new(0.5,3,0,4); Size=UDim2.new(0.5,-9,1,-8);
            CanvasSize=UDim2.new(0,0,0,0); BottomImage=''; TopImage='';
            ScrollBarThickness=2; ScrollBarImageColor3=Library.AccentColor;
            ZIndex=2; Parent=TabFrame;
        });
        Library:AddToRegistry(RightSide,{ScrollBarImageColor3='AccentColor';})
        Library:Create('UIListLayout',{Padding=UDim.new(0,6);FillDirection=Enum.FillDirection.Vertical;SortOrder=Enum.SortOrder.LayoutOrder;HorizontalAlignment=Enum.HorizontalAlignment.Center;Parent=LeftSide;})
        Library:Create('UIListLayout',{Padding=UDim.new(0,6);FillDirection=Enum.FillDirection.Vertical;SortOrder=Enum.SortOrder.LayoutOrder;HorizontalAlignment=Enum.HorizontalAlignment.Center;Parent=RightSide;})

        if Library.IsMobile then
            local SidesValues={Left=tick();Right=tick();}
            LeftSide:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
                Library.CanDrag=false; local CT=tick(); SidesValues.Left=CT;
                task.wait(0.15); if SidesValues.Left==CT then Library.CanDrag=true end
            end)
            RightSide:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
                Library.CanDrag=false; local CT=tick(); SidesValues.Right=CT;
                task.wait(0.15); if SidesValues.Right==CT then Library.CanDrag=true end
            end)
        end
        for _,Side in next,{LeftSide,RightSide} do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize=UDim2.fromOffset(0,Side.UIListLayout.AbsoluteContentSize.Y);
            end)
        end

        -- Warning/info top bar (preserved)
        local TopBar,TopBarInner,TopBarLabel,TopBarTextLabel,TopBarLabelStroke,TopBarHighlight;
        do
            TopBar=Library:Create('Frame',{
                BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
                Position=UDim2.new(0,6,0,4); Size=UDim2.new(1,-12,0,0);
                ZIndex=2; Parent=TabFrame; Visible=false;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=TopBar;})
            Library:Create('UIStroke',{Color=Color3.fromRGB(248,51,51);Thickness=1;Parent=TopBar;})
            TopBarInner=Library:Create('Frame',{
                BackgroundColor3=Color3.fromRGB(100,18,14); BorderSizePixel=0;
                Size=UDim2.new(1,-2,1,-2); Position=UDim2.new(0,1,0,1); ZIndex=4; Parent=TopBar;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=TopBarInner;})
            TopBarHighlight=Library:Create('Frame',{
                BackgroundColor3=Color3.fromRGB(255,70,70); BorderSizePixel=0;
                Size=UDim2.new(1,0,0,2); ZIndex=5; Parent=TopBarInner;
            });
            TopBarLabel=Library:Create('TextLabel',{
                BackgroundTransparency=1; Font=Library.Font; TextStrokeTransparency=0;
                Size=UDim2.new(1,0,0,16); Position=UDim2.new(0,4,0,2); TextSize=13;
                Text=""; TextXAlignment=Enum.TextXAlignment.Left;
                TextColor3=Color3.fromRGB(255,55,55); RichText=true; ZIndex=5; Parent=TopBarInner;
            });
            TopBarLabelStroke=Library:ApplyTextStroke(TopBarLabel);
            TopBarLabelStroke.Color=Color3.fromRGB(160,3,3);
            TopBarTextLabel=Library:CreateLabel({
                Position=UDim2.new(0,4,0,18); Size=UDim2.new(1,-4,0,12); TextSize=13;
                Text=""; TextWrapped=true; TextXAlignment=Enum.TextXAlignment.Left;
                TextYAlignment=Enum.TextYAlignment.Top; RichText=true; ZIndex=5; Parent=TopBarInner;
            });
            Library:Create('Frame',{BackgroundTransparency=1;Size=UDim2.new(1,0,0,4);Visible=true;ZIndex=1;Parent=TopBarInner;})
        end

        function Tab:Resize()
            if TopBar.Visible then
                local Size=4;
                for _,El in next,TopBarInner:GetChildren() do
                    if not El:IsA('UIListLayout') and El.Visible then
                        if El==TopBarTextLabel then Size=Size+El.TextBounds.Y; continue end
                        Size=Size+El.Size.Y.Offset;
                    end
                end
                TopBar.Size=UDim2.new(1,-12,0,Size); local S2=Size+8;
                LeftSide.Position=UDim2.new(0,6,0,4+S2); LeftSide.Size=UDim2.new(0.5,-9,1,-8-S2);
                RightSide.Position=UDim2.new(0.5,3,0,4+S2); RightSide.Size=UDim2.new(0.5,-9,1,-8-S2);
            else
                LeftSide.Position=UDim2.new(0,6,0,4); LeftSide.Size=UDim2.new(0.5,-9,1,-8);
                RightSide.Position=UDim2.new(0.5,3,0,4); RightSide.Size=UDim2.new(0.5,-9,1,-8);
            end
        end

        function Tab:UpdateWarningBox(Info)
            if typeof(Info.Visible)=="boolean" then TopBar.Visible=Info.Visible; Tab:Resize() end
            if typeof(Info.Title)=="string" then TopBarLabel.Text=Info.Title end
            if typeof(Info.Text)=="string" then
                TopBarTextLabel.Text=Info.Text;
                local Y=select(2,Library:GetTextBounds(Info.Text,Library.Font,13,Vector2.new(TopBarTextLabel.AbsoluteSize.X,math.huge)));
                TopBarTextLabel.Size=UDim2.new(1,-4,0,Y); Tab:Resize();
            end
            TopBarInner.BackgroundColor3=Info.IsNormal and Library.BackgroundColor or Color3.fromRGB(100,18,14);
            TopBarHighlight.BackgroundColor3=Info.IsNormal and Library.AccentColor or Color3.fromRGB(255,70,70);
            TopBarLabel.TextColor3=Info.IsNormal and Library.FontColor or Color3.fromRGB(255,55,55);
        end

        -- Sub-tab button (secondary bar)
        local SubBtnWidth=Library:GetTextBounds(Tab.Name,Library.Font,12)+14;
        local SubBtn=Library:Create('Frame',{
            BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
            Size=UDim2.new(0,SubBtnWidth,1,0); ZIndex=4; Parent=SubTabArea;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=SubBtn;})
        Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=SubBtn;})
        Library:AddToRegistry(SubBtn,{BackgroundColor3='BackgroundColor';})
        local SubBtnLabel=Library:CreateLabel({
            Size=UDim2.new(1,0,1,0); TextSize=12; Text=Tab.Name;
            TextColor3=Library.DisabledTextColor; RichText=true; ZIndex=5; Parent=SubBtn;
        });

        function Tab:ShowTab()
            Library.ActiveTab=Name;
            for _,T in next,Window.Tabs do T:HideTab() end
            -- activate nav button
            NavBtnLabel.TextColor3=Library.FontColor;
            Library.RegistryMap[NavBtnLabel].Properties.TextColor3='FontColor';
            NavIndicator.Visible=true;
            -- activate sub button
            SubBtn.BackgroundColor3=Library.MainColor;
            Library.RegistryMap[SubBtn].Properties.BackgroundColor3='MainColor';
            SubBtnLabel.TextColor3=Library.FontColor;
            Library.RegistryMap[SubBtnLabel].Properties.TextColor3='FontColor';
            TabFrame.Visible=true;
            Tab:Resize();
        end
        function Tab:HideTab()
            NavBtnLabel.TextColor3=Library.DisabledTextColor;
            Library.RegistryMap[NavBtnLabel].Properties.TextColor3='DisabledTextColor';
            NavIndicator.Visible=false;
            SubBtn.BackgroundColor3=Library.BackgroundColor;
            Library.RegistryMap[SubBtn].Properties.BackgroundColor3='BackgroundColor';
            SubBtnLabel.TextColor3=Library.DisabledTextColor;
            Library.RegistryMap[SubBtnLabel].Properties.TextColor3='DisabledTextColor';
            TabFrame.Visible=false;
        end
        function Tab:SetLayoutOrder(Pos) NavBtn.LayoutOrder=Pos; SubBtn.LayoutOrder=Pos end
        function Tab:GetSides() return {["Left"]=LeftSide;["Right"]=RightSide;} end
        function Tab:SetName(N)
            if typeof(N)=="string" then
                Tab.Name=N;
                local W=Library:GetTextBounds(N,Library.Font,13)+20;
                NavBtn.Size=UDim2.new(0,W,1,0); NavBtnLabel.Text=N;
                local W2=Library:GetTextBounds(N,Library.Font,12)+14;
                SubBtn.Size=UDim2.new(0,W2,1,0); SubBtnLabel.Text=N;
            end
        end

        NavBtn.InputBegan:Connect(function(Input)
            if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then Tab:ShowTab() end
        end)
        SubBtn.InputBegan:Connect(function(Input)
            if Input.UserInputType==Enum.UserInputType.MouseButton1 or Input.UserInputType==Enum.UserInputType.Touch then Tab:ShowTab() end
        end)
        TopBar:GetPropertyChangedSignal("Visible"):Connect(function() Tab:Resize() end)

        -- AddGroupbox
        function Tab:AddGroupbox(Info)
            local Groupbox={};
            local BoxOuter=Library:Create('Frame',{
                BackgroundColor3=Library.MainColor; BorderSizePixel=0;
                Size=UDim2.new(1,0,0,30); ZIndex=2;
                Parent=Info.Side==1 and LeftSide or RightSide;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=BoxOuter;})
            Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=BoxOuter;})
            Library:AddToRegistry(BoxOuter,{BackgroundColor3='MainColor';})
            -- thin accent top bar
            local BoxAccent=Library:Create('Frame',{
                BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
                Size=UDim2.new(1,0,0,1); ZIndex=3; Parent=BoxOuter;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=BoxAccent;})
            Library:AddToRegistry(BoxAccent,{BackgroundColor3='AccentColor';})
            -- section label
            local GroupLabel=Library:CreateLabel({
                Size=UDim2.new(1,-6,0,16); Position=UDim2.new(0,6,0,2);
                TextSize=12; Text=Info.Name; TextXAlignment=Enum.TextXAlignment.Left;
                TextColor3=Library.DisabledTextColor; RichText=true; ZIndex=3; Parent=BoxOuter;
            });
            Library:AddToRegistry(GroupLabel,{TextColor3='DisabledTextColor';})
            -- thin separator under header
            local HeaderSep=Library:Create('Frame',{
                BackgroundColor3=Library.OutlineColor; BorderSizePixel=0;
                Position=UDim2.new(0,0,0,18); Size=UDim2.new(1,0,0,1); ZIndex=3; Parent=BoxOuter;
            });
            Library:AddToRegistry(HeaderSep,{BackgroundColor3='OutlineColor';})

            local Container=Library:Create('Frame',{
                BackgroundTransparency=1; Position=UDim2.new(0,4,0,20);
                Size=UDim2.new(1,-4,1,-20); ZIndex=1; Parent=BoxOuter;
            });
            Library:Create('UIListLayout',{FillDirection=Enum.FillDirection.Vertical;SortOrder=Enum.SortOrder.LayoutOrder;Parent=Container;})

            function Groupbox:Resize()
                local Size=0;
                for _,El in next,Groupbox.Container:GetChildren() do
                    if not El:IsA('UIListLayout') and El.Visible then Size=Size+El.Size.Y.Offset end
                end
                BoxOuter.Size=UDim2.new(1,0,0,(20*DPIScale+Size)+4);
            end

            Groupbox.Container=Container;
            setmetatable(Groupbox,BaseGroupbox);
            Groupbox:AddBlank(3); Groupbox:Resize();
            Tab.Groupboxes[Info.Name]=Groupbox;
            return Groupbox;
        end
        function Tab:AddLeftGroupbox(Name) return Tab:AddGroupbox({Side=1;Name=Name;}) end
        function Tab:AddRightGroupbox(Name) return Tab:AddGroupbox({Side=2;Name=Name;}) end

        -- AddTabbox (sub-panels inside a column)
        function Tab:AddTabbox(Info)
            local Tabbox={Tabs={}};
            local BoxOuter=Library:Create('Frame',{
                BackgroundColor3=Library.MainColor; BorderSizePixel=0;
                Size=UDim2.new(1,0,0,0); ZIndex=2;
                Parent=Info.Side==1 and LeftSide or RightSide;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=BoxOuter;})
            Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=BoxOuter;})
            Library:AddToRegistry(BoxOuter,{BackgroundColor3='MainColor';})

            local BoxAccent=Library:Create('Frame',{
                BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
                Size=UDim2.new(1,0,0,1); ZIndex=3; Parent=BoxOuter;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=BoxAccent;})
            Library:AddToRegistry(BoxAccent,{BackgroundColor3='AccentColor';})

            local TabboxButtons=Library:Create('Frame',{
                BackgroundTransparency=1; Position=UDim2.new(0,0,0,1);
                Size=UDim2.new(1,0,0,18); ZIndex=5; Parent=BoxOuter;
            });
            Library:Create('UIListLayout',{FillDirection=Enum.FillDirection.Horizontal;HorizontalAlignment=Enum.HorizontalAlignment.Left;SortOrder=Enum.SortOrder.LayoutOrder;Parent=TabboxButtons;})

            local TabbedSep=Library:Create('Frame',{
                BackgroundColor3=Library.OutlineColor; BorderSizePixel=0;
                Position=UDim2.new(0,0,0,19); Size=UDim2.new(1,0,0,1); ZIndex=3; Parent=BoxOuter;
            });
            Library:AddToRegistry(TabbedSep,{BackgroundColor3='OutlineColor';})

            function Tabbox:AddTab(Name)
                local Tb={};
                local Btn=Library:Create('Frame',{
                    BackgroundColor3=Library.MainColor; BorderSizePixel=0;
                    Size=UDim2.new(0.5,0,1,0); ZIndex=6; Parent=TabboxButtons;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=Btn;})
                Library:AddToRegistry(Btn,{BackgroundColor3='MainColor';})
                local BtnLabel=Library:CreateLabel({
                    Size=UDim2.new(1,0,1,0); TextSize=12; Text=Name;
                    TextXAlignment=Enum.TextXAlignment.Center; RichText=true; ZIndex=7; Parent=Btn;
                });
                local Block=Library:Create('Frame',{
                    BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
                    Position=UDim2.new(0,0,1,0); Size=UDim2.new(1,0,0,1);
                    Visible=false; ZIndex=9; Parent=Btn;
                });
                Library:AddToRegistry(Block,{BackgroundColor3='BackgroundColor';})
                local Container=Library:Create('Frame',{
                    BackgroundTransparency=1; Position=UDim2.new(0,4,0,22);
                    Size=UDim2.new(1,-4,1,-22); ZIndex=1; Visible=false; Parent=BoxOuter;
                });
                Library:Create('UIListLayout',{FillDirection=Enum.FillDirection.Vertical;SortOrder=Enum.SortOrder.LayoutOrder;Parent=Container;})

                function Tb:Show()
                    for _,T2 in next,Tabbox.Tabs do T2:Hide() end
                    Container.Visible=true; Block.Visible=true;
                    Btn.BackgroundColor3=Library.BackgroundColor;
                    Library.RegistryMap[Btn].Properties.BackgroundColor3='BackgroundColor';
                    Tb:Resize();
                end
                function Tb:Hide()
                    Container.Visible=false; Block.Visible=false;
                    Btn.BackgroundColor3=Library.MainColor;
                    Library.RegistryMap[Btn].Properties.BackgroundColor3='MainColor';
                end
                function Tb:Resize()
                    local TabCount=0; for _ in next,Tabbox.Tabs do TabCount=TabCount+1 end
                    for _,B in next,TabboxButtons:GetChildren() do
                        if not B:IsA('UIListLayout') then B.Size=UDim2.new(1/TabCount,0,1,0) end
                    end
                    if not Container.Visible then return end
                    local Size=0;
                    for _,El in next,Tb.Container:GetChildren() do
                        if not El:IsA('UIListLayout') and El.Visible then Size=Size+El.Size.Y.Offset end
                    end
                    BoxOuter.Size=UDim2.new(1,0,0,(22*DPIScale+Size)+4);
                end

                Btn.InputBegan:Connect(function(Input)
                    if (Input.UserInputType==Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType==Enum.UserInputType.Touch then
                        Tb:Show(); Tb:Resize();
                    end
                end)
                Tb.Container=Container; Tabbox.Tabs[Name]=Tb;
                setmetatable(Tb,BaseGroupbox);
                Tb:AddBlank(3); Tb:Resize();
                if #TabboxButtons:GetChildren()==2 then Tb:Show() end
                return Tb;
            end

            Tab.Tabboxes[Info.Name or '']=Tabbox;
            return Tabbox;
        end
        function Tab:AddLeftTabbox(Name) return Tab:AddTabbox({Name=Name;Side=1;}) end
        function Tab:AddRightTabbox(Name) return Tab:AddTabbox({Name=Name;Side=2;}) end

        Library.TotalTabs=Library.TotalTabs+1;
        if Library.TotalTabs==1 then Tab:ShowTab() end
        Window.Tabs[Name]=Tab;
        return Tab;
    end

    -- ── Toggle (show/hide with fade) ─────────────────────────────
    local TransparencyCache={}; local Toggled=false; local Fading=false;

    function Library:Toggle(Toggling)
        if typeof(Toggling)=="boolean" and Toggling==Toggled then return end
        if Fading then return end
        local FadeTime=Config.MenuFadeTime; Fading=true; Toggled=not Toggled;
        Library.Toggled=Toggled; ModalElement.Modal=Toggled;

        if Toggled then
            Outer.Visible=true;
            if DrawingLib.drawing_replaced~=true and IsBadDrawingLib~=true then
                IsBadDrawingLib=not(pcall(function()
                    local Cursor=DrawingLib.new("Triangle")
                    Cursor.Thickness=1; Cursor.Filled=true; Cursor.Visible=Library.ShowCustomCursor;
                    local CursorOutline=DrawingLib.new("Triangle")
                    CursorOutline.Thickness=1; CursorOutline.Filled=false;
                    CursorOutline.Color=Color3.new(0,0,0); CursorOutline.Visible=Library.ShowCustomCursor;
                    local OldMouseIconState=InputService.MouseIconEnabled;
                    pcall(function() RunService:UnbindFromRenderStep("LinoriaCursor") end)
                    RunService:BindToRenderStep("LinoriaCursor",Enum.RenderPriority.Camera.Value-1,function()
                        InputService.MouseIconEnabled=not Library.ShowCustomCursor;
                        local mPos=InputService:GetMouseLocation(); local X,Y=mPos.X,mPos.Y;
                        Cursor.Color=Library.AccentColor;
                        Cursor.PointA=Vector2.new(X,Y); Cursor.PointB=Vector2.new(X+16,Y+6); Cursor.PointC=Vector2.new(X+6,Y+16);
                        Cursor.Visible=Library.ShowCustomCursor;
                        CursorOutline.PointA=Cursor.PointA; CursorOutline.PointB=Cursor.PointB; CursorOutline.PointC=Cursor.PointC;
                        CursorOutline.Visible=Library.ShowCustomCursor;
                        if not Toggled or not ScreenGui or not ScreenGui.Parent then
                            InputService.MouseIconEnabled=OldMouseIconState;
                            if Cursor then Cursor:Destroy() end
                            if CursorOutline then CursorOutline:Destroy() end
                            RunService:UnbindFromRenderStep("LinoriaCursor")
                        end
                    end)
                end))
            end
        end

        for _,Option in Options do
            task.spawn(function()
                if Option.Type=='Dropdown' then Option:CloseDropdown();
                elseif Option.Type=='KeyPicker' then Option:SetModePickerVisibility(false);
                elseif Option.Type=='ColorPicker' then Option.ContextMenu:Hide(); Option:Hide(); end
            end)
        end

        for _,Desc in next,Outer:GetDescendants() do
            local Properties={};
            if Desc:IsA('ImageLabel') then table.insert(Properties,'ImageTransparency'); table.insert(Properties,'BackgroundTransparency');
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then table.insert(Properties,'TextTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then table.insert(Properties,'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') then table.insert(Properties,'Transparency'); end
            local Cache=TransparencyCache[Desc];
            if not Cache then Cache={}; TransparencyCache[Desc]=Cache end
            for _,Prop in next,Properties do
                if not Cache[Prop] then Cache[Prop]=Desc[Prop] end
                if Cache[Prop]==1 then continue end
                TweenService:Create(Desc,TweenInfo.new(FadeTime,Enum.EasingStyle.Linear),{[Prop]=Toggled and Cache[Prop] or 1}):Play();
            end
        end

        task.wait(FadeTime); Outer.Visible=Toggled; Fading=false;
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if typeof(Library.ToggleKeybind)=='table' and Library.ToggleKeybind.Type=='KeyPicker' then
            if Input.UserInputType==Enum.UserInputType.Keyboard and Input.KeyCode.Name==Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode==Enum.KeyCode.RightControl or (Input.KeyCode==Enum.KeyCode.RightShift and not Processed) then
            task.spawn(Library.Toggle)
        end
    end))

    -- Mobile toggle button
    if Library.IsMobile then
        local TogUIOuter=Library:Create('Frame',{
            BorderSizePixel=0; Position=UDim2.new(0.008,0,0.018,0);
            Size=UDim2.new(0,77,0,28); ZIndex=200; Visible=true; Parent=ScreenGui;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=TogUIOuter;})
        local TogUIInner=Library:Create('Frame',{
            BackgroundColor3=Library.MainColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=201; Parent=TogUIOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=TogUIInner;})
        Library:Create('UIStroke',{Color=Library.AccentColor;Thickness=1;Parent=TogUIInner;})
        Library:AddToRegistry(TogUIInner,{BackgroundColor3='MainColor';})
        local TogUIBtn=Library:Create('TextButton',{
            Position=UDim2.new(0,4,0,0); Size=UDim2.new(1,-4,1,0);
            BackgroundTransparency=1; Font=Library.Font; Text="Toggle UI";
            TextColor3=Library.FontColor; TextSize=13; TextXAlignment=Enum.TextXAlignment.Left;
            TextStrokeTransparency=1; RichText=true; ZIndex=203; Parent=TogUIInner;
        });
        Library:MakeDraggableUsingParent(TogUIBtn,TogUIOuter);
        TogUIBtn.MouseButton1Down:Connect(function() Library:Toggle() end)

        local LockOuter=Library:Create('Frame',{
            BorderSizePixel=0; Position=UDim2.new(0.008,0,0.075,0);
            Size=UDim2.new(0,77,0,28); ZIndex=200; Visible=true; Parent=ScreenGui;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=LockOuter;})
        local LockInner=Library:Create('Frame',{
            BackgroundColor3=Library.MainColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); ZIndex=201; Parent=LockOuter;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=LockInner;})
        Library:Create('UIStroke',{Color=Library.AccentColor;Thickness=1;Parent=LockInner;})
        Library:AddToRegistry(LockInner,{BackgroundColor3='MainColor';})
        local LockBtn=Library:Create('TextButton',{
            Position=UDim2.new(0,4,0,0); Size=UDim2.new(1,-4,1,0);
            BackgroundTransparency=1; Font=Library.Font; Text="Lock UI";
            TextColor3=Library.FontColor; TextSize=13; TextXAlignment=Enum.TextXAlignment.Left;
            TextStrokeTransparency=1; RichText=true; ZIndex=203; Parent=LockInner;
        });
        Library:MakeDraggableUsingParent(LockBtn,LockOuter);
        LockBtn.MouseButton1Down:Connect(function()
            Library.CantDragForced=not Library.CantDragForced;
            LockBtn.Text=Library.CantDragForced and "Unlock UI" or "Lock UI";
        end)
    end

    if Config.AutoShow then task.spawn(Library.Toggle) end
    Window.Holder=Outer; Library.Window=Window;
    return Window;
end

-- ── Player/team list refresh (unchanged) ─────────────────────────
local function OnPlayerChange()
    local PL,EPL=GetPlayers(false,true),GetPlayers(true,true);
    local SP,SEP=GetPlayers(false,false),GetPlayers(true,false);
    for _,V in next,Options do
        if V.SetValues and V.Type=='Dropdown' and V.SpecialType=='Player' then
            V:SetValues(if V.ReturnInstanceInstead then (if V.ExcludeLocalPlayer then EPL else PL) else (if V.ExcludeLocalPlayer then SEP else SP));
        end
    end
end
local function OnTeamChange()
    local TL=GetTeams(false); local STL=GetTeams(true);
    for _,V in next,Options do
        if V.SetValues and V.Type=='Dropdown' and V.SpecialType=='Team' then
            V:SetValues(if V.ReturnInstanceInstead then TL else STL);
        end
    end
end
Library:GiveSignal(Players.PlayerAdded:Connect(OnPlayerChange))
Library:GiveSignal(Players.PlayerRemoving:Connect(OnPlayerChange))
Library:GiveSignal(Teams.ChildAdded:Connect(OnTeamChange))
Library:GiveSignal(Teams.ChildRemoved:Connect(OnTeamChange))

if getgenv().skip_getgenv_linoria~=true then getgenv().Library=Library end
return Library