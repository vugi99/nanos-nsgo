function table_count(ta)
    local count = 0
    for k, v in pairs(ta) do count = count + 1 end
    return count
end

function split_str(str,sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

function OtherTeam(team)
    if team == 1 then
        return 2
    else
        return 1
    end
end

function clamp(val, min, max)
    if val < min then
        return min
    elseif val > max then
        return max
    else
        return val
    end
end