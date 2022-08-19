
LoadoutItems = {}

PlayersCharactersWeapons = {}


function GetCharacterInventory(char)
    for i, v in ipairs(PlayersCharactersWeapons) do
        if v.char == char then
            return i
        end
    end
    return false
end

function GetPlayerInventoryTable(ply)
    local char = ply:GetControlledCharacter()
    if char then
        for i, v in ipairs(PlayersCharactersWeapons) do
            if v.char == char then
                return v
            end
        end
    end
end

function GenerateWeaponToInsert(ply, item_name, ammo_bag, slot, ammo_clip)
    local tbl = {
        ammo_bag = ammo_bag,
        ammo_clip = ammo_clip,
        item_name = item_name,
        slot = slot,
        max_ammo = LoadoutItems[item_name].ammo_bag or 0,
    }
    --Events.CallRemote("UpdateInventoryWeapon", ply, tbl)
    return tbl
end

function GetInsertSlot(item_name)
    for i, v in ipairs(LOADOUT_SLOTS_CONFIG) do
        if v.name == LoadoutItems[item_name].slot_name then
            return i
        end
    end
    error("Missing Insert Slot for " .. item_name)

    --[[for i=1, table_count(LOADOUT_SLOTS_CONFIG) do
        local slot_taken = false

        for i2, v2 in ipairs(Inv.weapons) do
            if v2.slot == i then
                slot_taken = true
                break
            end
        end

        if not slot_taken then
            return i
        end
    end
    return Inv.selected_slot]]--
end

local function GiveInventoryPlayerWeapon(char, charInvID, i, v)
    --print("GiveInventoryPlayerWeapon", char, charInvID, i, v)
    local weapon = LoadoutItems[v.item_name].spawn_func(Vector(), Rotator())

    if LoadoutItems[v.item_name].item_type == "weapon" then
        weapon:SetAmmoBag(v.ammo_bag)
        if v.ammo_clip then
            weapon:SetAmmoClip(v.ammo_clip)
        else
            PlayersCharactersWeapons[charInvID].weapons[i].ammo_clip = weapon:GetAmmoClip()
        end
    elseif LoadoutItems[v.item_name].item_type == "grenade" then
        weapon:SetValue("RemainingGrenades", v.ammo_bag, true)
    end
    --weapon:SetScale(LoadoutItems[v.item_name].scale)

    char:PickUp(weapon)

    PlayersCharactersWeapons[charInvID].weapons[i].weapon = weapon
end

function EquipSlot(char, slot)
    --print("EquipSlot", char:GetID(), slot)
    local charInvID = GetCharacterInventory(char)
    if charInvID then
        local Inv = PlayersCharactersWeapons[charInvID]
        if slot ~= Inv.selected_slot then
            for i, v in ipairs(Inv.weapons) do
                if (v.slot == Inv.selected_slot and v.weapon) then
                    if v.weapon:IsValid() then
                        if LoadoutItems[v.item_name].item_type == "weapon" then
                            v.ammo_bag = v.weapon:GetAmmoBag()
                            v.ammo_clip = v.weapon:GetAmmoClip()
                        elseif LoadoutItems[v.item_name].item_type == "grenade" then
                            v.ammo_bag = v.weapon:GetValue("RemainingGrenades")
                        end

                        --print("Before:", v, PlayersCharactersWeapons[charInvID].weapons[i])
                        v.destroying = true
                        v.weapon:Destroy()
                        --print("holding WEAPON DESTROYED", char:GetPicked())
                        --print("After:", v, PlayersCharactersWeapons[charInvID].weapons[i])
                    end
                    v.weapon = nil
                    break
                end
            end
            for i, v in ipairs(Inv.weapons) do
                if v.slot == slot then
                    GiveInventoryPlayerWeapon(char, charInvID, i, v)
                    break
                end
            end
            Inv.selected_slot = slot
            --Events.CallRemote("UpdateSelectedSlot", char:GetPlayer(), Inv.selected_slot)
        else
            for i, v in ipairs(Inv.weapons) do
                if (v.slot == Inv.selected_slot) then
                    if not v.weapon then
                        GiveInventoryPlayerWeapon(char, charInvID, i, v)
                        break
                    elseif v.weapon:IsValid() then
                        if LoadoutItems[v.item_name].item_type == "weapon" then
                            v.ammo_bag = v.weapon:GetAmmoBag()
                            v.ammo_clip = v.weapon:GetAmmoClip()
                        elseif LoadoutItems[v.item_name].item_type == "grenade" then
                            v.ammo_bag = v.weapon:GetValue("RemainingGrenades")
                        end

                        v.destroying = true
                        v.weapon:Destroy()

                        GiveInventoryPlayerWeapon(char, charInvID, i, v)
                        break
                    end
                end
            end
        end
    end
end

function AddCharacterWeapon(char, item_name, ammo_bag, equip, ammo_clip)
    local charInvID = GetCharacterInventory(char)
    local insert_sl = GetInsertSlot(item_name)
    if charInvID then

        -- If the player already have this weapon, don't give a new one
        local already_have = false
        for i, v in ipairs(PlayersCharactersWeapons[charInvID].weapons) do
            if v.item_name == item_name then
                already_have = true
            end
        end
        if already_have then
            EquipSlot(char, PlayersCharactersWeapons[charInvID].selected_slot)
            return false
        end

        local SlotDrop = false
        for i, v in ipairs(PlayersCharactersWeapons[charInvID].weapons) do
            if v.slot == insert_sl then
                if v.weapon then
                    if not v.just_dropped then
                        v.Dropping = true
                        char:Drop()
                        v.Dropping = nil
                    else
                        --Events.CallRemote("RemoveWeaponFromSlot", char:GetPlayer(), PlayersCharactersWeapons[charInvID].weapons[i].slot)
                        table.remove(PlayersCharactersWeapons[charInvID].weapons, i)
                    end
                end
                SlotDrop = true
                break
            end
        end

        if not SlotDrop then
            for i, v in ipairs(PlayersCharactersWeapons[charInvID].weapons) do
                if v.slot == PlayersCharactersWeapons[charInvID].selected_slot then
                    if v.weapon then
                        v.just_dropped = nil
                    end
                    break
                end
            end
        end

        table.insert(PlayersCharactersWeapons[charInvID].weapons, GenerateWeaponToInsert(char:GetPlayer(), item_name, ammo_bag, insert_sl, ammo_clip))
        if equip then
            EquipSlot(char, insert_sl)
        else
            EquipSlot(char, PlayersCharactersWeapons[charInvID].selected_slot)
        end
    else
        table.insert(PlayersCharactersWeapons, {
            char = char,
            selected_slot = insert_sl,
            weapons = {
                GenerateWeaponToInsert(char:GetPlayer(), item_name, ammo_bag, insert_sl, ammo_clip),
            },
        })
        EquipSlot(char, insert_sl)
        --Events.CallRemote("UpdateSelectedSlot", char:GetPlayer(), insert_sl)
    end
end

Character.Subscribe("Destroy", function(char)
    local charInvID = GetCharacterInventory(char)
    if charInvID then
        for i, v in ipairs(PlayersCharactersWeapons[charInvID].weapons) do
            if (v.weapon and v.weapon:IsValid()) then
                v.destroying = true
                v.weapon:Destroy()
            end
        end
        table.remove(PlayersCharactersWeapons, charInvID)
    end
end)

local function DropInvItem(weapon, char, was_triggered_by_player)
    --print("Drop", weapon, char, was_triggered_by_player, weapon:GetAssetName())
    local charInvID = GetCharacterInventory(char)
    if charInvID then
        for i, v in ipairs(PlayersCharactersWeapons[charInvID].weapons) do
            if (v.weapon and v.weapon == weapon) then
                if not v.destroying then
                    weapon:SetValue("DroppedWeaponName", v.item_name, false)
                    weapon:SetValue("DroppedWeaponDTimeout", Timer.SetTimeout(function()
                        if weapon:IsValid() then
                            weapon:Destroy()
                        end
                    end, Weapons_Dropped_Destroyed_After_ms), false)
                    --print("Drop Weapon")
                    if (was_triggered_by_player or v.Dropping) then
                        --Events.CallRemote("RemoveWeaponFromSlot", char:GetPlayer(), PlayersCharactersWeapons[charInvID].weapons[i].slot)
                        table.remove(PlayersCharactersWeapons[charInvID].weapons, i)
                    end
                    v.just_dropped = true
                    --print("After Drop Weapon, weapon[1]", PlayersCharactersWeapons[charInvID].weapons[1])
                else
                    v.destroying = nil
                end
                break
            end
        end
    end
end
Weapon.Subscribe("Drop", DropInvItem)
Melee.Subscribe("Drop", DropInvItem)
Grenade.Subscribe("Drop", DropInvItem)

function PickupInvItem(weapon, char)
    --print("PickUp Event")
    local d_weap_name = weapon:GetValue("DroppedWeaponName")
    if d_weap_name then
        Timer.ClearTimeout(weapon:GetValue("DroppedWeaponDTimeout"))
        --print("Pickup_Exec")
        local ammo_bag
        local ammo_clip
        if LoadoutItems[d_weap_name].item_type == "weapon" then
            ammo_bag = weapon:GetAmmoBag()
            ammo_clip = weapon:GetAmmoClip()
        elseif LoadoutItems[d_weap_name].item_type == "grenade" then
            ammo_bag = weapon:GetValue("RemainingGrenades")
        end
        weapon:Destroy()
        AddCharacterWeapon(char, d_weap_name, ammo_bag, true, ammo_clip)
    end
end
Weapon.Subscribe("PickUp", PickupInvItem)
Melee.Subscribe("PickUp", PickupInvItem)
Grenade.Subscribe("PickUp", PickupInvItem)

Events.Subscribe("Switch_Inv_Slot", function(ply)
    local char = ply:GetControlledCharacter()
    if char then
        local charInvID = GetCharacterInventory(char)
        if charInvID then
            local slot_to_equip = PlayersCharactersWeapons[charInvID].selected_slot + 1
            if slot_to_equip > table_count(LOADOUT_SLOTS_CONFIG) then
                slot_to_equip = 1
            end
            EquipSlot(char, slot_to_equip)
        end
    end
end)

Grenade.Subscribe("Throw", function(grenade, char)
    local remaining_count = grenade:GetValue("RemainingGrenades")
    if remaining_count then
        local charInvID = GetCharacterInventory(char)
        if charInvID then
            for i, v in ipairs(PlayersCharactersWeapons[charInvID].weapons) do
                if v.weapon == grenade then
                    PlayersCharactersWeapons[charInvID].weapons[i].weapon = nil

                    PlayersCharactersWeapons[charInvID].weapons[i].ammo_bag = remaining_count - 1

                    if PlayersCharactersWeapons[charInvID].weapons[i].ammo_bag > 0 then
                        GiveInventoryPlayerWeapon(char, charInvID, i, v)
                    else
                        --Events.CallRemote("RemoveWeaponFromSlot", char:GetPlayer(), PlayersCharactersWeapons[charInvID].weapons[i].slot)
                        table.remove(PlayersCharactersWeapons[charInvID].weapons, i)
                    end

                    break
                end
            end
        end
    end
end)

function RegisterLoadoutItem(name, slot_name, spawn_func, item_type, ammo_bag, price)
    if not LoadoutItems[name] then
        LoadoutItems[name] = {
            slot_name = slot_name,
            item_type = item_type,
            spawn_func = spawn_func,
            ammo_bag = ammo_bag,
            --scale = scale or Vector(1, 1, 1),
            price = price,
        }
    else
        print("Loadout Item Already Exists", name)
    end
end

Events.Subscribe("BuyWeapon", function(ply, weapon_name)
    if ply:IsValid() then
        if Shop_Phase_Timeout then
            if LoadoutItems[weapon_name] then
                local char = ply:GetControlledCharacter()
                if char then
                    if Buy(ply, LoadoutItems[weapon_name].price) then
                        AddCharacterWeapon(char, weapon_name, LoadoutItems[weapon_name].ammo_bag, true)
                        Players_Loadouts[ply:GetID()][LoadoutItems[weapon_name].slot_name] = weapon_name
                    end
                end
            end
        end
    end
end)

Events.Subscribe("BuyOther", function(ply, other_name)
    if ply:IsValid() then
        if Shop_Phase_Timeout then
            local char = ply:GetControlledCharacter()
            if char then
                local other_table
                for i, v in ipairs(Shop_Other_Items) do
                    if v[1] == other_name then
                        other_table = v
                        break
                    end
                end
                if other_table then
                    if Buy(ply, other_table[2]) then
                        if not char:GetValue("_Has" .. other_name) then
                            if other_name == "Armor" then
                                local health = char:GetHealth()
                                char:SetHealth(clamp(health + 50, 1, 200))
                            elseif other_name == "Kevlar" then
                                local health = char:GetHealth()
                                char:SetHealth(clamp(health + 100, 1, 200))
                            end
                            char:SetValue("_Has" .. other_name, true, false)
                        end
                    end
                end
            end
        end
    end
end)

Events.Subscribe("PlantBomb", function(ply, plant_zone)
    if ply:IsValid() then
        local char = ply:GetControlledCharacter()
        if char then
            if MAP_OBJECTIVES[plant_zone] then
                local dist = MAP_OBJECTIVES[plant_zone]:DistanceSquared(char:GetLocation())

                if dist <= Bomb_Site_Radius_sq then
                    local picked = char:GetPicked()
                    if picked then
                        if NanosUtils.IsA(picked, Melee) then
                            if picked:GetValue("Bomb") then
                                local charInvID = GetCharacterInventory(char)
                                if charInvID then
                                    local Inv = PlayersCharactersWeapons[charInvID]

                                    for i, v in ipairs(Inv.weapons) do
                                        if (v.slot == Inv.selected_slot and v.weapon) then
                                            if v.weapon:IsValid() then
                                                v.destroying = true
                                                v.weapon:Destroy()
                                            end

                                            table.remove(Inv.weapons, i)
                                            break
                                        end
                                    end
                                end

                                local planted_bomb = Prop(char:GetLocation(), Rotator(0, 0, 0), "modern-weapons-assets::SM_Modern_Weapons_Explosive_01", CollisionType.NoCollision, false, GrabMode.Enabled)
                                planted_bomb:SetValue("PlantedBomb", true, true)

                                Timer.SetTimeout(function()
                                    if planted_bomb:IsValid() then
                                        Bomb_Exploded = true

                                        Events.BroadcastRemote("BombExplosion", planted_bomb:GetLocation())

                                        local players_in_radius = {}

                                        for k, v in pairs(Character.GetAll()) do
                                            if v:GetPlayer() then
                                                local _dist = planted_bomb:GetLocation():DistanceSquared(v:GetLocation())
                                                if _dist <= Bomb_Explode_Radius_sq then
                                                    table.insert(players_in_radius, v:GetPlayer())
                                                end
                                            end
                                        end

                                        for i, v in ipairs(players_in_radius) do
                                            v:SetValue("DeadExplosion", true, false)
                                        end

                                        for i, v in ipairs(players_in_radius) do
                                            if ROUNDS_RUNNING then
                                                RoundsPlayerOut(v)
                                            end
                                        end

                                        planted_bomb:Destroy()

                                        RoundEnd()
                                    end
                                end, Bomb_Explode_Time_ms)

                                Events.BroadcastRemote("SpawnBombSound", char:GetLocation())
                            end
                        end
                    end
                end
            end
        end
    end
end)

Events.Subscribe("DefusedBomb", function(ply)
    if ply:IsValid() then
        if ply:GetValue("PlayerTeam") == 2 then
            local char = ply:GetControlledCharacter()
            if char then
                Bomb_Defused = true
                RoundEnd()
            end
        end
    end
end)









function SpawnKnife(vector, rotator)
    vector = vector or Vector()
    rotator = rotator or Rotator()

    local melee_weap = Melee(vector or Vector(), rotator or Rotator(), "nanos-world::SM_M9", CollisionType.Normal, true, HandlingMode.SingleHandedMelee)
	melee_weap:AddAnimationCharacterUse("nanos-world::AM_Mannequin_Melee_Stab_Attack", 1, AnimationSlotType.UpperBody)
	melee_weap:SetDamageSettings(0.3, 0.3)
	melee_weap:SetCooldown(0.25)
	melee_weap:SetBaseDamage(30)

    return melee_weap
end

function SpawnGrenade()
    vector = vector or Vector()
    rotator = rotator or Rotator()

    local new_grenade = Grenade(
        vector,
        rotator,
        "nanos-world::SM_Grenade_G67",
        "nanos-world::P_Grenade_Special",
        "nanos-world::A_Explosion_Large"
    )
    new_grenade:SetDamage(90, 0, 200, 2000, 1)
    new_grenade:SetTimeToExplode(2)

    return new_grenade
end

function SpawnBomb(vector, rotator)
    vector = vector or Vector()
    rotator = rotator or Rotator()

    local melee_weap = Melee(vector or Vector(), rotator or Rotator(), "modern-weapons-assets::SM_Modern_Weapons_Explosive_01", CollisionType.Normal, true, HandlingMode.SingleHandedMelee)
	melee_weap:AddAnimationCharacterUse("nanos-world::AM_Mannequin_Melee_Stab_Attack", 1, AnimationSlotType.UpperBody)
	melee_weap:SetBaseDamage(0)
    melee_weap:SetValue("Bomb", true, true)

    return melee_weap
end

RegisterLoadoutItem("AK47", "Primary", NanosWorldWeapons.AK47, "weapon", 90, 2700)
RegisterLoadoutItem("AK74U", "Primary", NanosWorldWeapons.AK74U, "weapon", 90, 2000)
RegisterLoadoutItem("AR4", "Primary", NanosWorldWeapons.AR4, "weapon", 90, 2400)
RegisterLoadoutItem("UMP45", "Primary", NanosWorldWeapons.UMP45, "weapon", 90, 1800)
RegisterLoadoutItem("SPAS12", "Primary", NanosWorldWeapons.SPAS12, "weapon", 20, 2000)
RegisterLoadoutItem("Rem870", "Primary", NanosWorldWeapons.Rem870, "weapon", 20, 1600)

RegisterLoadoutItem("Glock", "Secondary", NanosWorldWeapons.Glock, "weapon", 50, 600)
RegisterLoadoutItem("M1911", "Secondary", NanosWorldWeapons.M1911, "weapon", 50, 200)

RegisterLoadoutItem("Knife", "Melee", SpawnKnife, "melee")

RegisterLoadoutItem("Grenade", "Special", SpawnGrenade, "grenade", 1, 800)

RegisterLoadoutItem("Bomb", "Bomb", SpawnBomb, "melee")