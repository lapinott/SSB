----------------------------------------------
--            Save Skill Builds             --
--        Edda's skill builds saver         --
----------------------------------------------


-- Main objects
SSB = {}
SSB.Builds = {}
SSB.Options = {}
SSB.Bindings = {}
SSB.User = {}
SSB.User.Builds = {}
SSB.User.Options = {}
SSB.User.Bindings = {}
SSB.User.SavedBuildCount = 0

-- Init main vars
SSB.name = "SSB"
SSB.niceName = " » "
SSB.command = "/ssb"
SSB.version = 1.6
SSB.varVersion = 1
SSB.maxKeybinds = 50
SSB.barOne = "barOne"
SSB.barTwo = "barTwo"
SSB.skillOne = "skillOne"
SSB.skillTwo = "skillTwo"
SSB.skillThree = "skillThree"
SSB.skillFour = "skillFour"
SSB.skillFive = "skillFive"
SSB.skillSix = "skillSix"
SSB.currentActiveSkillBar = nil
SSB.currentActiveSkillBarLocked = nil
SSB.saveActionBarSwapPending = false
SSB.saveActionBarSwapPendingBuildId = nil
SSB.loadActionBarSwapPending = false
SSB.loadActionBarSwapPendingBuildId = nil
SSB.saveBuildId = nil
SSB.loadBuildId = nil
SSB.silentLoad = false
SSB.inCombat = false
SSB.textNil = "nil"
SSB.swapEventCount = 0

-- Skill types
SSB.skillTypes = {}
table.insert(SSB.skillTypes, SKILL_TYPE_ARMOR);
table.insert(SSB.skillTypes, SKILL_TYPE_AVA);
table.insert(SSB.skillTypes, SKILL_TYPE_CLASS);
table.insert(SSB.skillTypes, SKILL_TYPE_GUILD);
table.insert(SSB.skillTypes, SKILL_TYPE_NONE);
table.insert(SSB.skillTypes, SKILL_TYPE_RACIAL);
table.insert(SSB.skillTypes, SKILL_TYPE_WEAPON);
table.insert(SSB.skillTypes, SKILL_TYPE_WORLD);

-- User's
SSB.User.Options.Verbous = true;
SSB.User.Options.availableKeyBinds = 10

-- Init
function SSB.Initialize(eventCode, addOnName)

	-- Verify Add-On
	if (addOnName ~= SSB.name) then return end
	
	-- Load user's variables
	SSB.User = ZO_SavedVars:New("SSBMem", math.floor(SSB.varVersion), nil, SSB.User, nil);
	
	-- Register the slash command handler
	SLASH_COMMANDS[SSB.command] = SSB.SlashCommands;
	
	-- Shortcuts - read-only
	setmetatable (SSB.Builds, {__index = SSB.User.Builds})
	setmetatable (SSB.Options, {__index = SSB.User.Options})
	setmetatable (SSB.Bindings, {__index = SSB.User.Bindings})
	
	-- Register keybinds
	for i = 1, SSB.User.Options.availableKeyBinds, 1 do ZO_CreateStringId("SI_BINDING_NAME_SSB_LOAD_BUILD_" .. i, "Load build #" .. i) end
	
	-- Init some vars
	SSB.currentActiveSkillBar, SSB.currentActiveSkillBarLocked = GetActiveWeaponPairInfo()
	
	-- Attach Event listeners
	EVENT_MANAGER:RegisterForEvent(SSB.name, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, SSB.WeaponSwap);
	EVENT_MANAGER:RegisterForEvent(SSB.name, EVENT_PLAYER_COMBAT_STATE, SSB.CombatState);
	
	return true
end

-- Main loop
function SSB.DoNothing() return nil end

-- Weapons swapped event
function SSB.WeaponSwap (event, activeWeaponPair, locked)

	-- 1.6 hack -> 3 weapon swap events fired per weapon swap......
	if activeWeaponPair == SSB.currentActiveSkillBar then return nil end
	--SSB.swapEventCount = (SSB.swapEventCount + 1) % 3;
	--if SSB.swapEventCount > 0 then return nil end
	
	-- Save active skillbar
	SSB.currentActiveSkillBar = activeWeaponPair;
	SSB.currentActiveSkillBarLocked = locked;
	
	-- Update pending
	if SSB.saveActionBarSwapPending then SSB.SaveBuild (nil) end
	if SSB.loadActionBarSwapPending then SSB.LoadBuild (SSB.loadActionBarSwapPendingBuildId) end
	
	--d(activeWeaponPair)
	
	return nil
end

-- Combat state event
function SSB.CombatState (event, inCombat) SSB.inCombat = inCombat end

-- Save build
function SSB.SaveBuild (buildName)

	-- Check if build name already exists
	local overWrite = false
	local overWriteId = nil
	for buildId, buildData in pairs(SSB.User.Builds) do
	
		-- Check
		if string.lower(buildData["friendlyName"]) == string.lower(buildName) then
			
			-- Save build ID to overwrite
			overWrite = true
			overWriteId = buildId;
		end
	end

	-- Build count id
	if not SSB.saveActionBarSwapPending and not overWrite then SSB.User.SavedBuildCount = SSB.User.SavedBuildCount + 1 end
	
	-- Create build object - Regular
	if not SSB.saveActionBarSwapPending and not overWrite then
		SSB.saveBuildId = "@" .. tostring(GetTimeStamp() * 1000 + GetGameTimeMilliseconds() % 1000);
		SSB.User.Builds[SSB.saveBuildId] = {}
		SSB.User.Builds[SSB.saveBuildId]["friendlyId"] = SSB.User.SavedBuildCount;
		SSB.User.Builds[SSB.saveBuildId]["friendlyName"] = buildName;
	end
	
	-- Create build object - Overwrite
	if not SSB.saveActionBarSwapPending and overWrite then
		SSB.saveBuildId = overWriteId;
		SSB.User.Builds[SSB.saveBuildId][SSB.barOne] = {};
		SSB.User.Builds[SSB.saveBuildId][SSB.barTwo] = {};
	end
	
	-- Build id
	if not SSB.saveActionBarSwapPending then SSB.saveActionBarSwapPendingBuildId = SSB.saveBuildId end
	if SSB.saveActionBarSwapPending then SSB.saveBuildId = SSB.saveActionBarSwapPendingBuildId end
	
	-- Get current skills
	local skills = {}
	
	-- Speed up
	local skillFound = false;
	
	-- Slot indexes
	for slotIndex = 3, 8, 1 do
		
		-- Current slot index data
		local slotName = GetSlotName(slotIndex);
		local slotTexture = GetSlotTexture(slotIndex);
		local slotType = GetSlotType(slotIndex);
		local slotBoundId = GetSlotBoundId(slotIndex);
		skillFound = false;
		
		-- Ability type
		for index, skillType in pairs(SSB.skillTypes) do
		
			-- Skill index
			for skillIndex = 1, GetNumSkillLines(index), 1 do
			
				-- Ability index
				for abilityIndex = 1, GetNumSkillAbilities(index, skillIndex), 1 do
				
					-- Save ability info
					local name, texture, v3, v4, v5, v6, v7 = GetSkillAbilityInfo(skillType, skillIndex, abilityIndex);
					
					-- Check
					if (texture == slotTexture or texture == SSB.Textures[slotTexture] or name == slotName or name == SSB.Dictionnary[slotName]) and name ~= "" then
					
					-- check
					d(GetSkillAbilityId(skillType, skillIndex, abilityIndex))
					d('.. texture = ' .. texture)
					d('.. slotTexture = ' .. slotTexture)
					
						-- Save build item
						skills[slotIndex - 2] = {slotName, slotTexture, abilityIndex, skillIndex, skillType, slotIndex}
						skillFound = true;
						break;
					end
					
					-- Speed up
					if skillFound then break end
				end
				
				-- Speed up
				if skillFound then break end
			end
			
			-- Speed up
			if skillFound then break end
		end
	end
	
	-- Bar index
	local barIndex = nil
	if SSB.currentActiveSkillBar == 1 then barIndex = SSB.barOne end
	if SSB.currentActiveSkillBar == 2 then barIndex = SSB.barTwo end
	
	-- Save current build
	SSB.User.Builds[SSB.saveBuildId][barIndex] = {
		[SSB.skillOne] = skills[1] or SSB.textNil,
		[SSB.skillTwo] = skills[2] or SSB.textNil,
		[SSB.skillThree] = skills[3] or SSB.textNil,
		[SSB.skillFour] = skills[4] or SSB.textNil,
		[SSB.skillFive] = skills[5] or SSB.textNil,
		[SSB.skillSix] = skills[6] or SSB.textNil
	}
	
	-- Action bar swap pending
	if GetUnitLevel("player") >= 15 then SSB.saveActionBarSwapPending = not SSB.saveActionBarSwapPending end
	
	-- Clean up
	if not SSB.saveActionBarSwapPending then SSB.saveActionBarSwapPendingBuildId = nil end
	if not SSB.saveActionBarSwapPending then SSB.saveBuildId = nil end
	
	-- Exit message
	local savedOrOverwritten;
	if overWrite then savedOrOverwritten = "overwritten";
	else savedOrOverwritten = "saved" end
	if SSB.saveActionBarSwapPending then d(SSB.niceName .. "Build for action bar n°" .. tostring(SSB.currentActiveSkillBar) .. " " .. savedOrOverwritten .. " with id #" .. tostring(SSB.User.SavedBuildCount) .. " ! Please swap your weapons.") end
	if not SSB.saveActionBarSwapPending then d(SSB.niceName .. "Build for action bar n°" .. tostring(SSB.currentActiveSkillBar) .. " " .. savedOrOverwritten .. " with id #" .. tostring(SSB.User.SavedBuildCount) .. " !") end
	
	return nil
end

-- Load build
function SSB.LoadBuild (buildNameOrId)

	-- Return if player is in combat
	if SSB.inCombat then
		
		-- Notify and exit
		d(SSB.niceName .. "You can't do this now !");
		
		return false
	end
	
	-- Check if build exists
	local buildExists = false
	local buildToLoad = nil
	
	-- Iterate builds
	for buildId, buildData in pairs(SSB.User.Builds) do
	
		-- Check
		if string.lower(buildData["friendlyName"]) == string.lower(buildNameOrId)
		or string.lower(buildData["friendlyId"]) == string.lower(buildNameOrId)
		or buildId == buildNameOrId then
			buildExists = true
			buildToLoad = buildData;
			SSB.loadBuildId = buildId;
		end
	end
	
	-- Exit if build not found
	if not buildExists then d(SSB.niceName .. "This build doesn't exist !") return false end
	
	-- Build id
	if not SSB.loadActionBarSwapPending then SSB.loadActionBarSwapPendingBuildId = SSB.loadBuildId end
	if SSB.loadActionBarSwapPending then SSB.loadBuildId = SSB.loadActionBarSwapPendingBuildId end
	
	-- Bar index
	local barIndex = nil
	if SSB.currentActiveSkillBar == 1 then barIndex = SSB.barOne end
	if SSB.currentActiveSkillBar == 2 then barIndex = SSB.barTwo end
	
	-- Bar data
	local barData = buildToLoad[barIndex]
	
	-- Load skill for each slot
	for skillKey, skill in pairs(barData) do SlotSkillAbilityInSlot(skill[5], skill[4], skill[3], skill[6]) end
	
	-- Action bar swap pending
	if GetUnitLevel("player") >= 15 then SSB.loadActionBarSwapPending = not SSB.loadActionBarSwapPending end
	
	-- Clean up
	if not SSB.loadActionBarSwapPending then SSB.loadActionBarSwapPendingBuildId = nil end
	if not SSB.loadActionBarSwapPending then SSB.loadBuildId = nil end
	
	-- Exit message
	if not SSB.silentLoad and SSB.loadActionBarSwapPending then d(SSB.niceName .. "Build id #" .. buildToLoad["friendlyId"] .. " [" .. buildToLoad["friendlyName"] .. "] loaded for action bar n°" .. tostring(SSB.currentActiveSkillBar) .. " ! Please swap your weapons.") end
	if not SSB.silentLoad and not SSB.loadActionBarSwapPending then d(SSB.niceName .. "Build id #" .. buildToLoad["friendlyId"] .. " [" .. buildToLoad["friendlyName"] .. "] loaded for action bar n°" .. tostring(SSB.currentActiveSkillBar) .. " !") end
	
	-- Notify
	return nil
end

-- Show build
function SSB.ShowBuild (buildNameOrId)
	
	-- Check if build exists
	local buildExists = false
	local buildToLoad = nil
	
	-- Iterate builds
	for buildId, buildData in pairs(SSB.User.Builds) do
	
		-- Check
		if string.lower(buildData["friendlyName"]) == string.lower(buildNameOrId)
		or string.lower(buildData["friendlyId"]) == string.lower(buildNameOrId)
		or buildId == buildNameOrId then
			buildExists = true
			buildToShow = buildData;
		end
	end
	
	-- Exit if build not found
	if not buildExists then d(SSB.niceName .. "This build doesn't exist !") return false end
	
	-- Show build
	d(SSB.niceName .. "Showing build #" .. buildToShow["friendlyId"] .. " with name '" .. buildToShow["friendlyName"] .. "'");
	d(".Action bar #1");
	if buildToShow[SSB.barOne][SSB.skillOne] ~= SSB.textNil then d("..Skill #1 : " .. buildToShow[SSB.barOne][SSB.skillOne][1]) end
	if buildToShow[SSB.barOne][SSB.skillTwo] ~= SSB.textNil then d("..Skill #2 : " .. buildToShow[SSB.barOne][SSB.skillTwo][1]) end
	if buildToShow[SSB.barOne][SSB.skillThree] ~= SSB.textNil then d("..Skill #3 : " .. buildToShow[SSB.barOne][SSB.skillThree][1]) end
	if buildToShow[SSB.barOne][SSB.skillFour] ~= SSB.textNil then d("..Skill #4 : " .. buildToShow[SSB.barOne][SSB.skillFour][1]) end
	if buildToShow[SSB.barOne][SSB.skillFive] ~= SSB.textNil then d("..Skill #5 : " .. buildToShow[SSB.barOne][SSB.skillFive][1]) end
	if buildToShow[SSB.barOne][SSB.skillSix] ~= SSB.textNil then d("..Ultimate : " .. buildToShow[SSB.barOne][SSB.skillSix][1]) end
	if buildToShow[SSB.barTwo] ~= nil then
		d(".Action bar #2")
		if buildToShow[SSB.barTwo][SSB.skillOne] ~= SSB.textNil then d("..Skill #1 : " .. buildToShow[SSB.barTwo][SSB.skillOne][1]) end
		if buildToShow[SSB.barTwo][SSB.skillTwo] ~= SSB.textNil then d("..Skill #2 : " .. buildToShow[SSB.barTwo][SSB.skillTwo][1]) end
		if buildToShow[SSB.barTwo][SSB.skillThree] ~= SSB.textNil then d("..Skill #3 : " .. buildToShow[SSB.barTwo][SSB.skillThree][1]) end
		if buildToShow[SSB.barTwo][SSB.skillFour] ~= SSB.textNil then d("..Skill #4 : " .. buildToShow[SSB.barTwo][SSB.skillFour][1]) end
		if buildToShow[SSB.barTwo][SSB.skillFive] ~= SSB.textNil then d("..Skill #5 : " .. buildToShow[SSB.barTwo][SSB.skillFive][1]) end
		if buildToShow[SSB.barTwo][SSB.skillSix] ~= SSB.textNil then d("..Ultimate : " .. buildToShow[SSB.barTwo][SSB.skillSix][1]) end
	end
	
	return nil
end

-- Delete build
function SSB.DeleteBuild (buildNameOrId)
	
	-- Check if build exists
	local buildExists = false
	
	-- Iterate builds
	for buildId, buildData in pairs(SSB.User.Builds) do
	
		-- Check
		if string.lower(buildData["friendlyName"]) == string.lower(buildNameOrId)
		or string.lower(buildData["friendlyId"]) == string.lower(buildNameOrId)
		or buildId == buildNameOrId then
			buildExists = true
			buildToDeleteId = buildId;
			buildFriendlyId = buildData["friendlyId"];
			buildFriendlyName = buildData["friendlyName"];
		end
	end
	
	-- Exit if build not found
	if not buildExists then d(SSB.niceName .. "This build doesn't exist !") return false end
	
	-- Delete build
	SSB.User.Builds[buildToDeleteId] = nil
	
	-- Delete binding if exists
	for bindId, buildId in pairs(SSB.User.Bindings) do
		if buildId == buildToDeleteId then SSB.User.Bindings[bindId] = nil end
	end
	
	-- Notify
	d(SSB.niceName .. "Build #" .. buildFriendlyId .. " with name '" .. buildFriendlyName .. "' deleted !");
	
	return nil
end

-- Clear builds
function SSB.clear ()
	
	-- Clear builds
	SSB.User.Builds = {}
	
	-- Clear bindings
	SSB.User.Bindings = {}
	
	-- Reset counter
	SSB.User.SavedBuildCount = 0
	
	-- Notify
	d(SSB.niceName .. 'All builds cleared !');
	
	return nil
end

-- Show builds
function SSB.ListBuilds ()
	
	-- Check if we have builds to show
	if SSB.Count (SSB.User.Builds) == 0 then
		
		-- Notify and exit
		d(SSB.niceName .. "You don't have any saved builds yet !");
		
		return false
	end
	
	-- Check if we have builds to show
	if SSB.Count (SSB.User.Builds) > 0 then
		
		-- Parse builds
		for buildId, buildData in pairs(SSB.User.Builds) do
			
			-- Display builds
			d(SSB.niceName .. "Build #" .. buildData["friendlyId"] .. " : " .. buildData["friendlyName"]);
		end
	end
	
	return nil
end

function SSB.ListBindings ()
	
	-- Get all bindings
	local count = 0;
	for bindingKey, bindingId in pairs(SSB.User.Bindings) do
		d(SSB.niceName .. "Keybind ID #" .. bindingKey .. " bound to " .. SSB.User.Builds[bindingId].friendlyName);
		count = count + 1
	end
	
	-- Exit
	if count == 0 then d('You don\'t have any bindings yet.') end
	
	return nil
end

-- Keybinds
function SSB.LoadBuild_HK (bindId)
	
	-- Return if binding not set
	if SSB.Bindings[bindId] == nil then
		
		-- Notify
		d(SSB.niceName .. "Binding #" .. tostring(bindId) .. " is not bind to any build !");
		d(SSB.niceName .. "To bind this key use '/ssb bind " .. tostring(bindId) .. " [bindNameOrId]'");
		return false
	end
	
	-- Else load build
	SSB.silentLoad = true
	SSB.LoadBuild (SSB.Bindings[bindId])
	SSB.silentLoad = true
	
	return nil
end

-- Bind key to build
function SSB.Bind (bindId, buildNameOrId)

	-- Check if build exists
	local buildExists = false
	
	-- Iterate builds
	for buildId, buildData in pairs(SSB.User.Builds) do
	
		-- Check
		if string.lower(buildData["friendlyName"]) == string.lower(buildNameOrId)
		or string.lower(buildData["friendlyId"]) == string.lower(buildNameOrId)
		or buildId == buildNameOrId then
			buildExists = true
			buildToBindId = buildId;
			buildFriendlyId = buildData["friendlyId"];
			buildFriendlyName = buildData["friendlyName"];
		end
	end
	
	-- Exit if build not found
	if not buildExists then d(SSB.niceName .. "This build doesn't exist !") return false end
	
	-- Bind build
	SSB.User.Bindings[bindId] = buildToBindId;
	
	-- Notify
	d(SSB.niceName .. "Binding #" .. tostring(bindId) .. " now bound to build ID " .. buildFriendlyId .. " [" .. buildFriendlyName .. "] !");
	
	return nil
end

-- Add available bindings
function SSB.AddKeyBinds (n)
	
	-- Exit if max keybinds reached
	if SSB.User.Options.availableKeyBinds + n > SSB.maxKeybinds then
		d('You can\'t have more than ' .. SSB.maxKeybinds .. ' keybinds.');
		return false;
	end
	
	-- Create new keybinds
	for i = SSB.User.Options.availableKeyBinds + 1, SSB.User.Options.availableKeyBinds + n, 1 do
		ZO_CreateStringId("SI_BINDING_NAME_SSB_LOAD_BUILD_" .. i, "Load build #" .. i)
	end
	
	-- Save #keybinds
	SSB.User.Options.availableKeyBinds = SSB.User.Options.availableKeyBinds + n
	
	-- Notify
	d('You now have ' .. SSB.User.Options.availableKeyBinds .. ' available keybinds. Please type /reloadui')
	
	return nil
end

-- Count table size
function SSB.Count (t)
	if type(t) ~= "table" then return false end
	if next(t) == nil then return 0 end
	local count = 0;
	for k, v in pairs(t) do
		if rawget(t, k) ~= nil then count = count + 1 end
	end
	return count;
end

-- String split
function SSB.SplitCommand(command)

	-- Search for white-space indexes
	local chunk = command;
	local index = string.find(command, " ");
	if index == nil then return {command, nil} end

	-- Iterate our command for white-space indexes
	local explode = {};
	local n = 1;
	while index ~= nil do
		explode[n] = string.sub(chunk, 1, index - 1);
		chunk = string.sub(chunk, index + 1, #chunk);
		index = string.find(chunk, " ");
		n = n + 1;
	end

	-- Add chunk after last white-space
	explode[n] = chunk;

	return explode;
end

-- Help command
function SSB.GetHelpString()
	local helpString = "\n Save Skill Builds v" .. SSB.version .. " - Usable commands : \n\n ";
	helpString = helpString .. "- '/ssb save [buildName]' : saves a build to [buildName] \n ";
	helpString = helpString .. "- '/ssb s' : alias for 'save' \n ";
	helpString = helpString .. "- '/ssb load [buildNameOrId]' : loads build with name or ID [buildNameOrId] \n ";
	helpString = helpString .. "- '/ssb l' : alias for 'load' \n ";
	helpString = helpString .. "- '/ssb list' : lists all your builds with Name and ID \n ";
	helpString = helpString .. "- '/ssb show [buildNameOrId]' : displays a detailed view of build with name or ID [buildNameOrId] \n ";
	helpString = helpString .. "- '/ssb bind [bindId] [buildNameOrId]' : binds the [bindId] hotkey with build [buildNameOrId] \n ";
	helpString = helpString .. "- '/ssb bindings' : lists all your bindings \n ";
	helpString = helpString .. "- '/ssb b' : alias for 'bind' \n "
	helpString = helpString .. "- '/ssb delete [buildNameOrId]' : deletes build with name or ID [buildNameOrId] \n "
	helpString = helpString .. "- '/ssb d' : alias for 'delete' \n "
	helpString = helpString .. "- '/ssb clear' : !! clears all your builds !! \n "
	return helpString;
end

function SSB.SlashCommands(text)

	local command = SSB.SplitCommand(text);
	local trigger = command[1];
	
	if trigger == '?' or trigger == 'help' then d(SSB.GetHelpString()) end
	if trigger == 's' or trigger == 'save' then
		if command[2] == nil then
			d(SSB.niceName .. "Please give a name to your build !")
		elseif command[2] == tostring(tonumber(command[2])) then
			d(SSB.niceName .. "Your build name can't be a number !")
		else SSB.SaveBuild(command[2]) end
	end
	if trigger == 'l' or trigger == 'load' then
		if command[2] == nil then
			d(SSB.niceName .. "Please specify the name or ID of the build you wish to load !");
		else SSB.LoadBuild (command[2]) end
	end
	if trigger == 'list' then SSB.ListBuilds () end
	if trigger == 'show' then
		if command[2] == nil then
			d(SSB.niceName .. "Please specify the name or ID of the build you wish to show !");
		else SSB.ShowBuild (command[2]) end
	end
	if trigger == 'd' or trigger == 'delete' then
		if command[2] == nil then
			d(SSB.niceName .. "Please specify the name or ID of the build you wish to delete !");
		else SSB.DeleteBuild (command[2]) end
	end
	if trigger == 'b' or trigger == 'bind' then
		if command[2] == nil then
			d(SSB.niceName .. "Please provide the #id of the binding you wish to bind !");
		elseif tostring(tonumber(command[2])) ~= command[2] or tostring(tonumber(command[2])) == command[2] and tonumber(command[2]) > SSB.User.Options.availableKeyBinds then
			d(SSB.niceName .. "This keybind is not available !")
		elseif command[3] == nil then
			d(SSB.niceName .. "Please specify the name or ID of the build you wish to bind to binding #" .. command[2] .. " !");
		else SSB.Bind (command[2], command[3]) end
	end
	if trigger == 'bindings' then SSB.ListBindings () end
	if trigger == 'addkb' then SSB.AddKeyBinds (5) end
	if trigger == 'clear' then SSB.clear() end
	return nil
end

-- Hook initialization onto the ADD_ON_LOADED event
EVENT_MANAGER:RegisterForEvent(SSB.name, EVENT_ADD_ON_LOADED, SSB.Initialize);
