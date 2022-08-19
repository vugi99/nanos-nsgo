
Package.Require("Sh_Funcs.lua")
Package.Require("Config.lua")

Package.RequirePackage("nanos-world-weapons")
Package.RequirePackage("egui")

function LoadServerFiles()
    Package.Require("Main.lua")
end


local map_path = Server.GetMap()
if map_path then
    local splited_map_path = split_str(map_path, ":")
    if (splited_map_path[1] and splited_map_path[2]) then
        local map_path_in_maps = "Server/Maps/" .. splited_map_path[1] .. ";" .. splited_map_path[2] .. ".lua"
        local map_files = Package.GetFiles("Server/Maps", ".lua")
        for i, v in ipairs(map_files) do
            if v == map_path_in_maps then
                Package.Require(v)
                print("NSGO : Map Config Loaded")
                LoadServerFiles()
                break
            end
        end
    end
end

print("NSGO " .. Package.GetVersion() .. " Loaded")