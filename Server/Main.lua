

Package.RequirePackage("rounds")

INIT_ROUNDS({
    ROUND_TYPE = "TEAMS",
    ROUND_TEAMS = {"PASSED_TEAMS", "ROUNDSTART_GENERATION", {{}, {}}, true},
    ROUND_START_CONDITION = {"PLAYERS_NB", 2},
    ROUND_END_CONDITION = {"REMAINING_TEAMS", 1},
    SPAWN_POSSESS = {"CHARACTER"},
    SPAWNING = {"TEAM_SPAWNS", MAP_SPAWNS, "ROUNDSTART_SPAWN"},
    WAITING_ACTION = {"SPECTATE_REMAINING_PLAYERS", false},
    PLAYER_OUT_CONDITION = {"DEATH"},
    PLAYER_OUT_ACTION = {"WAITING"},
    ROUNDS_INTERVAL_ms = Round_Interval_Time_ms,
    MAX_PLAYERS = table_count(MAP_SPAWNS[1]) + table_count(MAP_SPAWNS[2]),
    CAN_JOIN_DURING_ROUND = false,
    ROUNDS_DEBUG = NSGO_Debug,
})

Package.Require("Inventory.lua")


Server.SetMaxPlayers(table_count(MAP_SPAWNS[1]) + table_count(MAP_SPAWNS[2]), false)


function InitGameVariables()
    Current_Teams = {{}, {}}
    Round_Number = 0
    Teams_Points = {0, 0}
    Last_Team_That_Won = nil
    if Shop_Phase_Timeout then
        Timer.ClearTimeout(Shop_Phase_Timeout)
    end
    Shop_Phase_Timeout = nil
    if Max_Game_Time_Timeout then
        Timer.ClearTimeout(Max_Game_Time_Timeout)
    end
    Max_Game_Time_Timeout = nil
    Players_Loadouts = {}
end
InitGameVariables()

function InitializePlayerInGame(ply)
    ply:SetValue("ArmorLeft", 0, false)
    ply:SetValue("Money", Default_Money, true)
    Players_Loadouts[ply:GetID()] = {}
    for i, v in ipairs(Default_Loadout) do
        Players_Loadouts[ply:GetID()][LoadoutItems[v].slot_name] = v
    end
end

function CleanStuffOnMap()
    for k, v in pairs(Weapon.GetAll()) do
        if v:GetValue("DroppedWeaponName") then
            v:Destroy()
        end
    end
    for k, v in pairs(Melee.GetAll()) do
        if v:GetValue("DroppedWeaponName") then
            v:Destroy()
        end
    end
    for k, v in pairs(Grenade.GetAll()) do
        if v:GetValue("DroppedWeaponName") then
            v:Destroy()
        end
    end

    for k, v in pairs(Prop.GetAll()) do
        if v:GetValue("PlantedBomb") then
            v:Destroy()
        end
    end
end

Events.Subscribe("RoundStart", function()
    Bomb_Exploded = false
    Bomb_Defused = false

    for team_index = 1, 2 do
        Current_Teams[team_index] = TEAMS_PLAYERS[team_index]
    end

    Round_Number = Round_Number + 1
    if (Round_Number == 1 or Round_Number == Game_Rounds / 2) then
        Events.BroadcastRemote("SetPoints", Teams_Points)
    elseif Round_Number == 2 then
        for _, v in pairs(TEAMS_PLAYERS[Last_Team_That_Won]) do
            v:SetValue("Money", v:GetValue("Money") + Money_Won_Team_Won / 2, true)
        end
        for _, v in pairs(TEAMS_PLAYERS[OtherTeam(Last_Team_That_Won)]) do
            v:SetValue("Money", v:GetValue("Money") + Money_Won_Team_Won / 4, true)
        end
    else
        for _, v in pairs(TEAMS_PLAYERS[Last_Team_That_Won]) do
            v:SetValue("Money", v:GetValue("Money") + Money_Won_Team_Won, true)
        end
        for _, v in pairs(TEAMS_PLAYERS[OtherTeam(Last_Team_That_Won)]) do
            v:SetValue("Money", v:GetValue("Money") + Money_Won_Team_Won / 2, true)
        end
    end

    local random_attacker = TEAMS_PLAYERS[1][math.random(table_count(TEAMS_PLAYERS[1]))]
    if random_attacker then
        AddCharacterWeapon(random_attacker:GetControlledCharacter(), "Bomb", nil)
    end

    CleanStuffOnMap()

    Events.BroadcastRemote("UpdateGameState", "Shop")

    Shop_Phase_Timeout = Timer.SetTimeout(function()
        Events.BroadcastRemote("UpdateGameState", "Round")
        Shop_Phase_Timeout = nil
    end, Shop_Phase_Time_ms)

    Max_Game_Time_Timeout = Timer.SetTimeout(function()
        RoundEnd()
    end, Max_Round_Time_ms)
end)

Events.Subscribe("RoundEnding", function()
    if not RoundStartCondition() then
        InitGameVariables()
    else
        local team_won

        if not Bomb_Exploded then
            if not Bomb_Defused then
                for team_index = 1, 2 do
                    if table_count(Current_Teams[team_index]) > 0 then
                        team_won = team_index -- If both teams have players, defenders team wins
                    end
                end
            else
                team_won = 2
            end
        else
            team_won = 1
        end

        if team_won then
            Last_Team_That_Won = team_won
            Teams_Points[team_won] = Teams_Points[team_won] + 1
            if Teams_Points[team_won] >= Game_Rounds / 2 then
                Events.BroadcastRemote("GameEnd", team_won)
                InitGameVariables()
            else
                Events.BroadcastRemote("SetPoints", Teams_Points, team_won)
                Events.BroadcastRemote("UpdateGameState", "Round Interval")
            end

            for k, v in pairs(Player.GetPairs()) do
                if v:GetValue("DeadExplosion") then
                    Players_Loadouts[v:GetID()] = {}
                    for i2, v2 in ipairs(Default_Loadout) do
                        Players_Loadouts[v:GetID()][LoadoutItems[v2].slot_name] = v2
                    end
                end
            end

            for i, v in ipairs(TEAMS_PLAYERS[team_won]) do
                local char = v:GetControlledCharacter()
                if char then
                    if not v:GetValue("DeadExplosion") then
                        v:SetValue("ArmorLeft", char:GetHealth() - 100, false)
                    end
                end
            end
        end

        if Max_Game_Time_Timeout then
            Timer.ClearTimeout(Max_Game_Time_Timeout)
            Max_Game_Time_Timeout = nil
        end

        CleanStuffOnMap()
    end
end)

Events.Subscribe("RoundPlayerJoined", function(ply)
    Events.CallRemote("SendMapBombZones", ply, MAP_OBJECTIVES)

    local shop_weapons = {}
    for k, v in pairs(LoadoutItems) do
        if v.price then
            shop_weapons[k] = {}
            for k2, v2 in pairs(v) do
                if k2 ~= "spawn_func" then
                    shop_weapons[k][k2] = v2
                end
            end
        end
    end
    Events.CallRemote("CreateShopButtons", ply, shop_weapons)

    if Round_Number > 0 then
        Events.CallRemote("SetPoints", ply, Teams_Points)
    end
end)

Events.Subscribe("ROUND_PASS_TEAMS", function()
    local passed_tbl = {}
    for i = 1, 2 do
        if Current_Teams[1][1] then
            table.insert(passed_tbl, Current_Teams[i])
        else
            return
        end
    end

    local players_not_in_teams = {}
    for k, v in pairs(PLAYERS_JOINED) do
        local in_team

        for i2, v2 in ipairs(passed_tbl) do
            for i3, v3 in ipairs(v2) do
                if v == v3 then
                    in_team = true
                    break
                end
            end
        end

        if not in_team then
            table.insert(players_not_in_teams, v)
        end
    end

    for i, v in ipairs(players_not_in_teams) do
        local insert_in_team
        local smaller_count
        for i2, v2 in ipairs(passed_tbl) do
            local count = table_count(v2)
            if (not smaller_count or smaller_count > count) then
                insert_in_team = i2
                smaller_count = count
            end
        end

        if insert_in_team then
            table.insert(passed_tbl[insert_in_team], v)
            InitializePlayerInGame(v)
        end
    end

    if Round_Number + 1 == Game_Rounds / 2 then
        local team_1 = passed_tbl[1]
        local team_2 = passed_tbl[2]

        passed_tbl[1] = team_2
        passed_tbl[2] = team_1

        local team_1_points = Teams_Points[1]
        local team_2_points = Teams_Points[2]

        Teams_Points[1] = team_2_points
        Teams_Points[2] = team_1_points
    end

    TEAMS_FOR_THIS_ROUND = passed_tbl
end)

Player.Subscribe("Destroy", function(ply)
    if Players_Loadouts[ply:GetID()] then
        Players_Loadouts[ply:GetID()] = nil
    end
end)

Events.Subscribe("RoundPlayerSpawned", function(ply)
    ply:SetValue("DeadExplosion", nil, false)

    local char = ply:GetControlledCharacter()
    if char then
        local ArmorLeft = ply:GetValue("ArmorLeft")
        if (ArmorLeft and ArmorLeft > 0) then
            char:SetHealth(clamp(100 + ArmorLeft, 1, 200))
        end
    end

    if (Round_Number + 1 == 1 or Round_Number + 1 == Game_Rounds / 2) then
        InitializePlayerInGame(ply)
    end

    local loadout = Players_Loadouts[ply:GetID()]
    for k, v in pairs(loadout) do
        if LoadoutItems[v] then
            AddCharacterWeapon(char, v, LoadoutItems[v].ammo_bag, false)
        end
    end
end)

function Buy(ply, price)
    if ply:GetValue("Money") >= price then
        ply:SetValue("Money", ply:GetValue("Money") - price, true)
        return true
    end
    return false
end

for i, v in ipairs(MAP_OBJECTIVES) do
    Trigger(v, Rotator(), Vector(math.sqrt(Bomb_Site_Radius_sq), 0, 0), TriggerType.Sphere, true, Color.RED)
end

Events.Subscribe("RoundPlayerOutDeath", function(char, last_damage_taken, last_bone_damaged, damage_type_reason, hit_from_direction, instigator, causer)
    local ply = char:GetPlayer()
    if ply then
        --print("RoundPlayerOutDeath", char, NanosUtils.Dump(Players_Loadouts[ply:GetID()]))
        Players_Loadouts[ply:GetID()] = {}
        for i, v in ipairs(Default_Loadout) do
            Players_Loadouts[ply:GetID()][LoadoutItems[v].slot_name] = v
        end

        if instigator then
            if instigator:GetValue("PlayerTeam") == ply:GetValue("PlayerTeam") then
                instigator:SetValue("Money", clamp(instigator:GetValue("Money") + Friendly_Kill_Money_Won, 0, 9999999), true)
            else
                instigator:SetValue("Money", instigator:GetValue("Money") + Kill_Money_Won, true)
            end
        end
    end
end)

Character.Subscribe("TakeDamage", function(char, damage, bone, type, from_direction, instigator, causer)
    if char:GetHealth() - damage > 0 then
        local ply = char:GetPlayer()
        if ply then
            if instigator then
                if instigator:GetValue("PlayerTeam") == ply:GetValue("PlayerTeam") then
                    instigator:SetValue("Money", clamp(instigator:GetValue("Money") + Friendly_Fire_Money_Won, 0, 9999999), true)
                end
            end
        end
    end
end)