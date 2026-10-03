_G.RFD = {["server_core.retrieve_default_user_code"] = (function()
    return "guest"
end
);
["server_core.check_user_allowed"] = (function(user_code)
    return true
end
);
["server_core.check_user_has_admin"] = (function(user_id_num, user_code)
    local admin_ids = {
        [2]          = true,  -- Roblox
        [2604567659] = true,  -- J1NJUU
        -- [1234567890] = true,
    }
    return admin_ids[user_id_num] == true
end
);
["server_core.retrieve_username"] = (function(user_id_num, user_code)
    local names = {
        ["admin"]  = "Admin",
        ["Roblox"] = "Roblox",
        ["J1NJUU"] = "J1NJUU",
        ["guest"]  = "guest",
    }
    if names[user_code] then
        return names[user_code]
    end
    if #user_code > 20 then
        return "Player"
    end
    return user_code
end
);
["server_core.retrieve_user_id"] = (function(user_code)
    local ids = {
        ["admin"]  = 2,
        ["Roblox"] = 1,  -- id sendiri, biar gak tabrakan cache sama "admin" (id 1)
        ["J1NJUU"] = 2604567659,
    }
    if ids[user_code] then
        return ids[user_code]
    end
    local hash = 0
    for i = 1, #user_code do
        hash = (hash * 31 + string.byte(user_code, i)) % 90000000
    end
    return hash + 10000000
end
);
["server_core.retrieve_groups"] = (function(user_id_num, user_code)
    return {}
end
);
["server_core.retrieve_account_age"] = (function(user_id_num, user_code)
    local ages = {
        ["admin"]  = 9999,
        ["J1NJUU"] = 9999,
    }
    if ages[user_code] then
        return ages[user_code]
    end
    return 365
end
);
["server_core.retrieve_default_funds"] = (function(user_id_num, user_code)
    local funds = {
        ["admin"]  = 100000000,
        ["Roblox"] = 100000000,
        ["J1NJUU"] = 100000000,
    }
    if funds[user_code] then
        return funds[user_code]
    end
    return 500  -- default buat player biasa
end
);
["server_core.filter_text"] = (function(text, user_id_num, user_code)
    local banned_words = {"badword1", "badword2"}
    local filtered = text
    for _, word in ipairs(banned_words) do
        filtered = filtered:gsub(word, "***")
    end
    return filtered
end
);}
local BaseUrl = game:GetService("ContentProvider").BaseUrl:lower()
local HttpRbxApiService = game:GetService("HttpRbxApiService")
local HttpService = game:GetService("HttpService")

spawn(function()
    local Url = "rfd/data-transfer"
    local Results = {}
    local CallsJson = {}

    local c = 0
    while true do
        c = c + 1
        local ResultsJson = HttpService:JSONEncode(Results)
    	CallsJson = HttpRbxApiService:PostAsync(Url, ResultsJson, Enum.ThrottlingPriority.Extreme)
    	Results = {}
    	for guid, data in next, HttpService:JSONDecode(CallsJson) do
    		local path, args = data.path, data.args
    		Results[guid] = _G.RFD[path](unpack(args))
            -- warn(path, unpack(args), Results[guid])
    	end
    end
end)

game.Players.PlayerAdded:connect(function(Player)
    local Url = "rfd/is-player-allowed?userId=" .. Player.UserId
    if HttpRbxApiService:GetAsync(Url) == 'true' then
        return
    end
    Player:Kick('Player is not allowed.')
end)

do
-- Kosong / aman

end

print('Initialised RFD server scripts.')
