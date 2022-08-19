

Package.RequirePackage("egui")
Package.RequirePackage("rounds")

Package.Require("Sh_Funcs.lua")
Package.Require("Config.lua")

Input.Register("Switch Inventory Slot", "X")

local self_team = 1
local planting_bomb_timeout
local planting_bomb_progress
local beep_sound
local defusing_bomb_timeout
local defusing_bomb_progress

Canvas_Data = {
    Top_Text = nil,
    Points = nil,
    Team_Won = nil,
    Time_Remaining = nil,
}

local NSGO_Canvas = Canvas(
    true,
    Color.TRANSPARENT,
    0,
    true
)
NSGO_Canvas:Subscribe("Update", function(self, width, height)
    if Canvas_Data.Top_Text then
        self:DrawText(Canvas_Data.Top_Text, Vector2D(Client.GetViewportSize().X * 0.5, 80), FontType.OpenSans, 25, Color.WHITE, 0, true, true, Color.TRANSPARENT, Vector2D(1, 1), true, Color.BLACK)
    end

    if Canvas_Data.Points then
        local ply = Client.GetLocalPlayer()
        if ply then
            self:DrawText(Canvas_Data.Points[self_team] .. "               |               " .. Canvas_Data.Points[OtherTeam(self_team)], Vector2D(Client.GetViewportSize().X * 0.5, 30), FontType.OpenSans, 21, Color.WHITE, 0, true, true, Color.TRANSPARENT, Vector2D(1, 1), false, Color.BLACK)
        end
    end

    if Canvas_Data.Team_Won then
        local text
        local color
        if Canvas_Data.Team_Won == self_team then
            text = "You Won!"
            color = Color.GREEN
        else
            text = "You Lost!"
            color = Color.RED
        end
        self:DrawText(text, Vector2D(Client.GetViewportSize().X * 0.5, Client.GetViewportSize().Y * 0.5), FontType.OpenSans, 100, color, 0, true, true, Color.TRANSPARENT, Vector2D(1, 1), true, Color.BLACK)
    end

    local ply = Client.GetLocalPlayer()
    if ply then
        local char = ply:GetControlledCharacter()
        if char then
            self:DrawText(tostring(char:GetHealth()) .. " HP", Vector2D(Client.GetViewportSize().X * 0.95, 30), FontType.OpenSans, 16, Color.GREEN, 0, true, true, Color.TRANSPARENT, Vector2D(1, 1), false, Color.BLACK)

            local weapon = char:GetPicked()
            if weapon then
                local ammo_text = "0 / 0"

                if (not NanosUtils.IsA(weapon, Grenade) and not NanosUtils.IsA(weapon, Melee)) then
                    ammo_text = tostring(weapon:GetAmmoClip()) .. " / " .. tostring(weapon:GetAmmoBag())
                elseif NanosUtils.IsA(weapon, Grenade) then
                    local grenades_remaining = weapon:GetValue("RemainingGrenades")
                    if grenades_remaining then
                        ammo_text = tostring(grenades_remaining) .. " / " .. tostring(grenades_remaining)
                    end
                end

                self:DrawText(ammo_text, Vector2D(Client.GetViewportSize().X * 0.87, Client.GetViewportSize().Y * 0.9), FontType.OpenSans, 35, Color.WHITE, 0, true, true, Color.TRANSPARENT, Vector2D(1, 1), true, Color.BLACK)
            end
        end

        local money = ply:GetValue("Money")
        if money then
            self:DrawText(tostring(money) .. "$", Vector2D(Client.GetViewportSize().X * 0.95, Client.GetViewportSize().Y * 0.95), FontType.OpenSans, 25, Color.GREEN, 0, true, true, Color.TRANSPARENT, Vector2D(1, 1), false, Color.BLACK)
        end
    end

    if Canvas_Data.Time_Remaining then
        self:DrawText(tostring(math.floor(Canvas_Data.Time_Remaining / 1000 + 0.5)), Vector2D(Client.GetViewportSize().X * 0.5, 115), FontType.OpenSans, 18, Color.WHITE, 0, true, true, Color.TRANSPARENT, Vector2D(1, 1), true, Color.BLACK)
    end
end)



local Shop_Window = EGUI.Window(Client.GetViewportSize().X * 0.38, Client.GetViewportSize().Y * 0.2, 400, 600, "Shop GUI", true, false)
Shop_Window:SetVisible(false)

local tabPanel = EGUI.TabPanel(0, 0, 400, 50, Shop_Window)
local Shop_Tabs = {}
for i, v in ipairs(LOADOUT_SLOTS_CONFIG) do
    if v.in_shop then
        local tab = tabPanel:AddTab(v.name)
        Shop_Tabs[v.name] = tab
    end
end
Shop_Tabs["Other"] = tabPanel:AddTab("Other")

local Shop_Buttons = {}

function CreateShopButton(name, price, parent_name)
    if not Shop_Buttons[parent_name] then
        Shop_Buttons[parent_name] = {}
    end

    local button = EGUI.Button(1, table_count(Shop_Buttons[parent_name]) * 55, 400, 50, name .. " " .. price .. "$", Shop_Tabs[parent_name])

    Shop_Buttons[parent_name][name] = {button, price}

    button:SetColor(EGUI.Color.Danger)

    button:Subscribe("LeftClick", function()
        if Shop_Window:IsVisible() then
            if button:GetColor() == EGUI.Color.Success then
                if parent_name ~= "Other" then
                    Events.CallRemote("BuyWeapon", name)
                else
                    Events.CallRemote("BuyOther", name)
                end
            end
        end
    end)
end


for i, v in ipairs(Shop_Other_Items) do
    CreateShopButton(v[1], v[2], "Other")
end

Events.Subscribe("CreateShopButtons", function(shop_weapons)
    for k, v in pairs(shop_weapons) do
        if Shop_Tabs[v.slot_name] then
            CreateShopButton(k, v.price, v.slot_name)
        end
    end
end)


Events.Subscribe("UpdateGameState", function(text)
    Canvas_Data.Top_Text = text .. " Phase"
    Canvas_Data.Team_Won = nil

    if text == "Shop" then
        ShowShopWindow()
        Canvas_Data.Time_Remaining = Shop_Phase_Time_ms
    elseif text == "Round" then
        Client.SetMouseEnabled(false)
        Client.SetInputEnabled(true)

        Shop_Window:SetVisible(false)

        Canvas_Data.Time_Remaining = Max_Round_Time_ms
    elseif text == "Round Interval" then
        Canvas_Data.Time_Remaining = Round_Interval_Time_ms
    end

    if beep_sound then
        if beep_sound:IsValid() then
            beep_sound:Destroy()
        end
        beep_sound = nil
    end
end)

Player.Subscribe("ValueChange", function(ply, key, value)
    if ply == Client.GetLocalPlayer() then
        if key == "PlayerTeam" then
            if value then
                self_team = value
            end
        elseif key == "Money" then
            ChangeButtonsColors(value)
        end
    end
end)

Events.Subscribe("SetPoints", function(points, team_won)
    Canvas_Data.Points = points
end)

Events.Subscribe("GameEnd", function(team_won)
    Canvas_Data.Team_Won = team_won
end)

function ChangeButtonsColors(money)
    for k, v in pairs(Shop_Buttons) do
        for k2, v2 in pairs(v) do
            if v2[2] <= money then
                Shop_Buttons[k][k2][1]:SetColor(EGUI.Color.Success)
            else
                Shop_Buttons[k][k2][1]:SetColor(EGUI.Color.Danger)
            end
        end
    end
end

function ShowShopWindow()
    Client.SetMouseEnabled(true)
    Client.SetInputEnabled(false)

    local money = Client.GetLocalPlayer():GetValue("Money")
    if money then
        ChangeButtonsColors(money)
        Shop_Window:SetVisible(true)
    end
end

Input.Bind("Switch Inventory Slot", InputEvent.Pressed, function()
    local local_player = Client.GetLocalPlayer()
    local local_char = local_player:GetControlledCharacter()
    if local_char then
        Events.CallRemote("Switch_Inv_Slot")
    end
end)

Client.Subscribe("Tick", function(ds)
    if Canvas_Data.Time_Remaining then
        --print(Canvas_Data.Time_Remaining)
        Canvas_Data.Time_Remaining = Canvas_Data.Time_Remaining - (ds * 1000)
        if Canvas_Data.Time_Remaining < 0 then
            Canvas_Data.Time_Remaining = nil
        end
    end

    if planting_bomb_timeout then
        planting_bomb_progress:SetValue(Timer.GetRemainingTime(planting_bomb_timeout) * 100 / Bomb_Plant_Time_ms)
    end

    if defusing_bomb_timeout then
        defusing_bomb_progress:SetValue(Timer.GetRemainingTime(defusing_bomb_timeout) * 100 / Bomb_Defuse_Time_ms)
    end
end)

Events.Subscribe("SendMapBombZones", function(zones)
    MAP_OBJECTIVES = zones
end)



Events.Subscribe("SpawnBombSound", function(loc)
    beep_sound = Sound(
        loc,
        "package://" .. Package.GetPath() .. "/Client/Sounds/beep.ogg",
        false,
        false,
        SoundType.SFX,
        1.8,
        1
    )
end)

Events.Subscribe("BombExplosion", function(loc)
    local ex_sound = Sound(
        loc,
        "nanos-world::A_Explosion_Large",
        false,
        true,
        SoundType.SFX,
        1,
        1
    )
end)




Input.Bind("Interact", InputEvent.Pressed, function()
    local local_player = Client.GetLocalPlayer()
    local local_char = local_player:GetControlledCharacter()
    if local_char then
        local picked = local_char:GetPicked()
        if picked then
            if NanosUtils.IsA(picked, Melee) then
                if picked:GetValue("Bomb") then
                    local plant_zone
                    for i, v in ipairs(MAP_OBJECTIVES) do
                        local dist = v:DistanceSquared(local_char:GetLocation())
                        if dist <= Bomb_Site_Radius_sq then
                            plant_zone = i
                            break
                        end
                    end

                    if plant_zone then
                        if not planting_bomb_timeout then
                            planting_bomb_progress = EGUI.ProgressBar(Client.GetViewportSize().X * 0.4, Client.GetViewportSize().Y * 0.7, 400, 30)
                            planting_bomb_timeout = Timer.SetTimeout(function()
                                Events.CallRemote("PlantBomb", plant_zone)
                                planting_bomb_timeout = nil
                                planting_bomb_progress:Delete()
                            end, Bomb_Plant_Time_ms)
                        end
                    end
                end
            end
        end
    end
end)

Input.Bind("Interact", InputEvent.Released, function()
    local local_player = Client.GetLocalPlayer()
    local local_char = local_player:GetControlledCharacter()
    if local_char then
        if planting_bomb_timeout then
            Timer.ClearTimeout(planting_bomb_timeout)
            planting_bomb_timeout = nil
            planting_bomb_progress:Delete()
        end
    end
end)

Prop.Subscribe("Grab", function(prop, char)
    if prop:GetValue("PlantedBomb") then
        local ply = Client.GetLocalPlayer()
        local self_char = ply:GetControlledCharacter()
        if self_char then
            if self_char == char then
                Client.SetInputEnabled(false)
                defusing_bomb_progress = EGUI.ProgressBar(Client.GetViewportSize().X * 0.4, Client.GetViewportSize().Y * 0.7, 400, 30)
                defusing_bomb_timeout = Timer.SetTimeout(function()
                    Events.CallRemote("DefusedBomb")
                    defusing_bomb_timeout = nil
                    defusing_bomb_progress:Delete()
                    Client.SetInputEnabled(true)
                end, Bomb_Defuse_Time_ms)
            end
        end
    end
end)

Character.Subscribe("Destroy", function(char)
    local ply = Client.GetLocalPlayer()
    if ply:GetControlledCharacter() == char then
        Client.SetInputEnabled(true)
    end
end)