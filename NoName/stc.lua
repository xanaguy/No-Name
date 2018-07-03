if RequiredScript == "lib/managers/menumanager" then
	if not _G.STC then
		_G.STC = _G.STC or {}
		STC.Annouced_List = {}
		STC._path = ModPath
		STC._mpath = ModPath .. "loc/"
		STC._savepath = SavePath .. "STC_control.txt"
		STC.settings = {
			Pd2Stat = true,
			Pd2Stat_extra = true,
			Skill = true,
			Ingame = true,
			Toggle = true,
			}
		STC.Caught = {false,false,false,false}
	end

	function STC:Save()
		local file = io.open(self._savepath, "w+")
		if file then
			file:write(json.encode(self.settings))
			file:close()
		end
	end

	function STC:Load()
		local file = io.open(self._savepath, "r")
		if file then
			for k, v in pairs(json.decode(file:read("*all")) or {}) do
				self.settings[k] = v
			end
			file:close()
		end
	end
	STC:Load()

	function STC:Cheater_Announce(peer)
		STC:Message_Receive(peer:name() .. " " .. managers.localization:text("stc_message"))
		STC.Caught[peer:id()] = true
		STC:Cheater_Pause(peer, 3)
		STC:Cheater_Tase(peer, 0.5)
	end

	function STC:Message_Receive(message)
		if managers.chat then
			managers.chat:_receive_message(1, "STC", message .. ".", Color.red)
		end
	end
	
	function STC:Cheater_Tase(peer, interval)
		DelayedCalls:Add("STC:Cheater_Stopped_" .. tostring(peer:id()), interval, function()
			if Utils:IsInHeist() and STC.settings.Toggle == true and STC.Caught[peer:id()] == true then
				if peer ~= nil and peer then
					local player_unit = managers.criminals:character_unit_by_peer_id(peer:id())
					managers.network:session():send_to_peers_synched("sync_player_movement_state", player_unit, "arrested", player_unit:character_damage():down_time(), player_unit:id())
					player_unit:movement():sync_movement_state("arrested", player_unit:character_damage():down_time())
					player_unit:network():send_to_unit( { "sync_player_movement_state", player_unit, "arrested", 0, player_unit:id() } )
					if peer ~= nil and peer then
						STC:Cheater_Tase(peer, 5)
					end
				end
			end
		end)
	end

	function STC:Cheater_Pause(peer, interval)
		DelayedCalls:Add("STC:Cheater_Stopped_" .. tostring(peer:id()), interval, function()
			if Utils:IsInHeist() and STC.settings.Toggle == true and STC.Caught[peer:id()] == true then
				if peer ~= nil and peer then
					peer:send("start_timespeed_effect", "pause", "pausable", "player;game;game_animation", 0.05, 1, 3600, 1)
					if peer ~= nil and peer then
						STC:Cheater_Pause(peer, 5)
					end
				end
			end
		end)
	end
	
	function STC:inChat()
		local value = false
		if managers.hud ~= nil and managers.hud._chat_focus == true then
			value = true
		end
		if managers.menu_component ~= nil and managers.menu_component._game_chat_gui ~= nil and managers.menu_component._game_chat_gui:input_focus() == true then
			value = true
		end
		return value
	end

	--Localization
	Hooks:Add("LocalizationManagerPostInit", "STC:Localization", function(loc)
		loc:load_localization_file(STC._mpath .. "local.txt")
	end)

	--Menu
	Hooks:Add("MenuManagerInitialize", "STC:Menu_Init", function(menu_manager)

		STC.Toggle = function(self)
			if STC:inChat() == false and managers.network._session then
				if STC.settings.Toggle == true then
					STC.settings.Toggle = false
					STC:Save()
					for peer_id, peer in pairs(managers.network._session._peers) do
						peer:send("start_timespeed_effect", "pause", "pausable", "player;game;game_animation", 1, 1, 3600, 1)
					end
					if Utils:IsInHeist() then
						STC:Message_Receive(managers.localization:text("stc_restore"))
					else
						STC:Message_Receive(managers.localization:text("stc_off"))
					end
				else
					STC.settings.Toggle = true
					STC:Save()
					if Utils:IsInHeist() then
						for peer_id, peer in pairs(managers.network._session._peers) do
							STC:Inspect(peer)
						end
						STC:Message_Receive(managers.localization:text("stc_recheck"))
					else
						STC:Message_Receive(managers.localization:text("stc_on"))
					end
				end
			end
		end
		
		MenuCallbackHandler.STC_Pd2Stat_callback = function(self, item)
			STC.settings.Pd2Stat = (item:value() == "on" and true or false)
			STC:Save()
		end

		MenuCallbackHandler.STC_Pd2Stat_extra_callback = function(self, item)
			STC.settings.Pd2Stat_extra = (item:value() == "on" and true or false)
			STC:Save()
		end

		MenuCallbackHandler.STC_Skill_callback = function(self, item)
			STC.settings.Skill = (item:value() == "on" and true or false)
			STC:Save()
		end

		MenuCallbackHandler.STC_Ingame_callback = function(self, item)
			STC.settings.Ingame = (item:value() == "on" and true or false)
			STC:Save()
		end

		STC:Load()
		MenuHelper:LoadFromJsonFile(STC._path .. "menu.txt", STC, STC.settings)
	end)

end
if RequiredScript == "lib/managers/gameplaycentralmanager" then

	function STC:Inspect(peer)
		if STC.Caught[peer:id()] == false then
			if STC.settings.Pd2Stat == true then
				STC:Pd2Stats(peer)
			elseif STC.settings.Skill == true then
				STC:Skills(peer)
			end
		else
			STC:Cheater_Announce(peer)
		end
	end

	function STC:Pd2Stats(peer)
		dohttpreq("http://api.pd2stats.com/cheater/v3/?type=saf&id=".. peer:user_id(),
		function(page)
			local answer = false
			--[[
			for param, val in string.gmatch(page, "([%w_]+)=([%w_]+)") do
				if string.len(val) > 17 then
					val = string.gsub(val, "_", " ")
					answer = STC:Extra_Pd2stats(val)
					if answer == true then
						break
					end
				end
			end
			--]]
			if answer == true then
				STC:Cheater_Announce(peer)
			elseif STC.settings.Skill == true then
				STC:Skills(peer)
			end
		end)
	end

	function STC:Extra_Pd2stats(text)
		if STC.settings.Pd2Stat_extra == true then
			local answer = string.find(text, "Not enough heists completed") and true or false
			if answer == false then
				return true
			end
			return false
		else
			return true
		end
	end

	function STC:Skills(peer)
		local number = 0
		local sum = 0
		local answer = false
		if peer ~= nil then
			local skills_perk_deck_info = string.split(peer:skills(), "-") or {}
			if #skills_perk_deck_info == 2 then
				local skills = string.split(skills_perk_deck_info[1], "_")
				local perk_deck = string.split(skills_perk_deck_info[2], "_")
				for i=1, #skills do
					number = tonumber(skills[i])
					sum = sum + number
					if number > 117 then
						answer = true
					end
				end
				if sum > 120 then
					answer = true
				end
				if sum > (tonumber(peer:level()) + 2 * math.floor(tonumber(peer:level()) / 10)) then
					answer = true
				end
				if answer == true then
				end
			end
		end
		if answer == true then
			STC:Cheater_Announce(peer)
		end
	end

	Hooks:PostHook(GamePlayCentralManager, "start_heist_timer", "STC:Cheater_lookup", function(self)
		if STC.settings.Toggle == true then
			for peer_id, peer in pairs(managers.network._session._peers) do
				STC:Inspect(peer)
			end
		end
	end)

end

if RequiredScript == "lib/network/base/networkpeer" then

	Hooks:PostHook(BaseNetworkSession, "on_set_member_ready", "STC:Cheater_lookup_ready", function(self, peer_id, ready, state_changed, from_network)
		if STC.settings.Toggle == true then
			local peer = managers.network:session():peer(peer_id)
			if Utils:IsInHeist() then
				if peer ~= nil and peer then
					if peer:waiting_for_player_ready() == true then
						STC:Inspect(peer)
					end
				end
			end
		end
	end)

	Hooks:Add("BaseNetworkSessionOnPeerRemoved", "STC:Person_removed", function(peer, peer_id, reason)
		STC.Caught[peer:id()] = false
	end)

end

if RequiredScript == "lib/network/base/networkpeer" then

	Hooks:PostHook(NetworkPeer, "mark_cheater", "STC:Cheater_was_tagged", function(self, reason, auto_kick)
		STC.Caught[self:id()] = true
		if Utils:IsInHeist() and STC.settings.Toggle == true and STC.settings.Ingame == true then
			if self ~= nil and self then
				if self:waiting_for_player_ready() == true then
					STC:Cheater_Announce(self)
				end
			end
		end
	end)

end