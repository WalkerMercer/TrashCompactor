GM.Config = {}

ROUND_RUNNING = 0
ROUND_ENDED = 1
ROUND_STARTING = 2
ROUND_WAITING = 3

CURRENTROUNDSTATE = ROUND_STARTING

local RoundTimer = 0
local AmountOfTimeInRound = 0

local IsInRound = false

local StartRoundDelayInt = 4
local RoundRestartTimer = 0

local MAP_ERROR = false

NEXT_TRASHMAN = nil
BOUGHT_TRASHMAN = nil
PREV_TRASHMAN = nil

function Init()
	RoundTimer = GAMEMODE.Config.RoundTime * 60
	AmountOfTimeInRound = GAMEMODE.Config.RoundTime * 60
end 
hook.Add("InitPostEntity","Init",Init)

function GM:OnReloaded()
	Init()
	CURRENTROUNDSTATE = ROUND_STARTING
	SaveAllPropLocations()
	TRASHMAN_AFKTIMER = 0
end

function Update()
	if(!MAP_ERROR) then
		if(CURRENTROUNDSTATE == ROUND_STARTING) then
			if (CurTime() >= StartRoundDelayInt) then
				RoundStart()
			else
				umsg.Start( "SendMessage" )
				umsg.Char(ROUND_STARTING)
				umsg.End()
			end
		elseif (CURRENTROUNDSTATE == ROUND_RUNNING) then
			RoundThink()
			if(RoundTimer <= -2) then
				VictimsWin()
				EndRound()
			end
		elseif (CURRENTROUNDSTATE == ROUND_ENDED) then
			RoundEnd()
		elseif (CURRENTROUNDSTATE == ROUND_WAITING) then
			RoundWait()
		end
		
		if(UseTrashmanQueue) then 
			
			local newqueue = {}
		
			for k,v in pairs(TRASHMAN_QUEUE_LIST) do
				if(IsValid(v)) then
					table.insert(newqueue,v)
				end
			end
			
			TRASHMAN_QUEUE_LIST = newqueue		
		end
		
		SendTrashmanQueue() 
		SendFrozenAmount()
		
		for k,v in pairs(player.GetAll()) do
			if(IsValid(v) && v:Team() == TEAM_UNASSIGNED) then
				v:SetTeam(TEAM_SPECTATOR)
			end
		end
		
	else
		--Map isnt working
	end
end
hook.Add("Think", "Update", Update)

function RoundStart()
	if(MinumumPlayersNeeded() || (GetConVarNumber( "tc_debug" ) == 1 && IsValid(player.GetAll()[1]) && player.GetAll()[1]:Team() == TEAM_VICTIMS)) then
		CURRENTROUNDSTATE = ROUND_RUNNING
		RoundTimer = AmountOfTimeInRound
		umsg.Start( "SendMessage" )
		umsg.Char(ROUND_RUNNING)
		umsg.End()
		
		FindTrashman()
		
		WINNER_CHOSEN = false
		TRASHMAN_AFKTIMER = 0
		TRASHMAN_MOVED = false
	else
		CURRENTROUNDSTATE = ROUND_WAITING
	end
end

local SendTimerInt = 0
function RoundThink()
	if (CurTime() >= SendTimerInt) then
		umsg.Start( "SendTimer" )
		umsg.Long( RoundTimer )
		umsg.End()
		RoundTimer = RoundTimer - 1
		
		umsg.Start( "SendMessage" )
		umsg.Char(ROUND_RUNNING) 
		umsg.End()
		
		if(MinumumPlayersNeeded()) then
			local iseveryvictimdead = true
			local victims = team.GetPlayers(TEAM_VICTIMS)
			for k,v in pairs (victims) do
				if(v:Alive()) then iseveryvictimdead = false end
			end
			
			if(iseveryvictimdead) then
				--Trashman Wins!
				TrashmanWin()
				EndRound()
			end
			
			
			local iseverytrashmandead = true
			local trashmen = team.GetPlayers(TEAM_TRASHMAN)
			for k,v in pairs (trashmen) do
				if(v:Alive()) then iseverytrashmandead = false end
			end
				
			if(iseverytrashmandead) then
				--Victims Wins!
				VictimsWin()
				EndRound()
			end
			
			if(IsValid(CURRENT_TRASHMAN) && GetConVarNumber("tc_afktimer") != 0) then
				if(TRASHMAN_AFKTIMER >= GetConVarNumber("tc_afktimer")) then
					TRASHMAN_AFKTIMER = 0
					SendTCMessage( 1,nil,0,CURRENT_TRASHMAN:Nick())
					CURRENT_TRASHMAN:Kill()
				elseif(TRASHMAN_AFKTIMER + 5 == GetConVarNumber("tc_afktimer")) then
					SendTCMessage( 2,CURRENT_TRASHMAN,5,"")
				elseif(TRASHMAN_AFKTIMER + 10 == GetConVarNumber("tc_afktimer")) then
					SendTCMessage( 2,CURRENT_TRASHMAN,10,"")
				end
			
				if(!TRASHMAN_MOVED) then
					TRASHMAN_AFKTIMER = TRASHMAN_AFKTIMER + 1
				end
			end
			
		else
			if(GetConVarNumber("tc_debug") != 1) then
				EndRound()
			end			
		end
        SendTimerInt = CurTime() + 1
    end
end


function RoundEnd()
	umsg.Start( "SendMessage" )
	umsg.Char(ROUND_ENDED) 
	umsg.End()
	
	if (CurTime() >= RoundRestartTimer) then
		CURRENTROUNDSTATE = ROUND_STARTING
		StartRoundDelayInt = CurTime() + 4
		
		ClearProps()
		SpawnAllProps()
		
		ForceAllJoinVictims()
		
		WINNER_CHOSEN = false
	end
end

function RoundWait()
	umsg.Start( "SendMessage" )
	umsg.Char(ROUND_WAITING)
	umsg.End()
	
	if(MinumumPlayersNeeded() || GetConVarNumber( "tc_debug" ) == 1) then
		ClearProps()
		SpawnAllProps()
		ForceAllJoinVictims()
		
		CURRENTROUNDSTATE = ROUND_STARTING
		StartRoundDelayInt = CurTime() + 4
	end
	
end

function EndRound()
	RoundRestartTimer = CurTime() + 10
	CURRENTROUNDSTATE = ROUND_ENDED
end

function MinumumPlayersNeeded()
	local amountofply = 0	
	amountofply = #team.GetPlayers(TEAM_VICTIMS)
	amountofply = amountofply + #team.GetPlayers(TEAM_TRASHMAN)
	amountofply = amountofply + #team.GetPlayers(TEAM_SPECTATOR)
	if(amountofply >= GAMEMODE.Config.MinumumPlayersNeeded) then return true end
	return false
end

function ForceAllJoinVictims()
	for k, v in pairs(player.GetAll()) do
		JoinTeam(v,TEAM_VICTIMS,GAMEMODE.Config.VictimsWeaponColor)
		v.FrozenPhysicsObjects = nil
	end
end

function FreezeAllPlayers()
	for k, v in pairs(player.GetAll()) do
		v:AddFlags(FL_ATCONTROLS)
		v:SetJumpPower( 0 )
	end
end

function UnFreezeAllPlayers()
	for k, v in pairs(player.GetAll()) do
		v:RemoveFlags(FL_ATCONTROLS)
		v:SetJumpPower( 200 )
	end
end

function FindTrashman()
	if(NEXT_TRASHMAN != nil) then
		JoinTeam(NEXT_TRASHMAN,TEAM_TRASHMAN,GAMEMODE.Config.TrashmanWeaponColor)
		CURRENT_TRASHMAN = NEXT_TRASHMAN
		NEXT_TRASHMAN = nil
	elseif(BOUGHT_TRASHMAN != nil) then
		JoinTeam(BOUGHT_TRASHMAN,TEAM_TRASHMAN,GAMEMODE.Config.TrashmanWeaponColor)
		CURRENT_TRASHMAN = BOUGHT_TRASHMAN
		BOUGHT_TRASHMAN = nil	
		print("Used Bought Trashman!")
	elseif(UseTrashmanQueue && #TRASHMAN_QUEUE_LIST != 0) then
		if(IsValid(TRASHMAN_QUEUE_LIST[1])) then
			JoinTeam(TRASHMAN_QUEUE_LIST[1],TEAM_TRASHMAN,GAMEMODE.Config.TrashmanWeaponColor)
			CURRENT_TRASHMAN = TRASHMAN_QUEUE_LIST[1]
		end
		
		local newqueue = {}
		
		for k,v in pairs(TRASHMAN_QUEUE_LIST) do
			if(IsValid(v) && v != CURRENT_TRASHMAN) then
				table.insert(newqueue,v)
			end
		end
		
		TRASHMAN_QUEUE_LIST = newqueue
	else
		FindRandomTrashman()
	end
	
	for k,v in pairs(player.GetAll()) do
		SendTCMessage( 0,v,0,CURRENT_TRASHMAN:Nick())
	end
end

function FindRandomTrashman()
	
	local list = player.GetAll()
	local noprevtrashman = {}
			
	for k,v in pairs(list) do
		if(IsValid(PREV_TRASHMAN)) then
			if(PREV_TRASHMAN != v) then
				table.insert(noprevtrashman,v)
			end
		else
			table.insert(noprevtrashman,v)
		end
	end
	
	
	local num = math.random(#noprevtrashman)
	
	if(IsValid(noprevtrashman[num])) then
		JoinTeam(noprevtrashman[num],TEAM_TRASHMAN,GAMEMODE.Config.TrashmanWeaponColor)
		CURRENT_TRASHMAN = noprevtrashman[num]
	
	else
		if(#list == 1) then
			JoinTeam(list[1],TEAM_TRASHMAN,GAMEMODE.Config.TrashmanWeaponColor)
			CURRENT_TRASHMAN = list[1]
		else
			print("Error Finding Trashman! Num: "..num.." Amount: "..#noprevtrashman)
			
			if(#noprevtrashman != 0) then
				local ran = math.random(#list)
				JoinTeam(list[ran],TEAM_TRASHMAN,GAMEMODE.Config.TrashmanWeaponColor)
				CURRENT_TRASHMAN = list[ran]
			end
		end
	end
	
	
end

function ClearProps()
	
	if(#PROP_LIST != 0) then
		
		local propp = ents.FindByClass("prop_physics")
	
		local props = ents.FindByClass("prop_physics_multiplayer")
		
		local grenades = ents.FindByClass("npc_grenade_frag")
		
		local debris = ents.FindByClass("prop_debris")
		
		table.Add(props,propp)
		
		table.Add(props, grenades)
		
		table.Add(props, debris)
		
		for k,v in pairs (props) do
			v:Remove()
		end
	
	else
		SaveAllPropLocations()
	end
end

function SpawnAllProps()
	for k,v in pairs (PROP_LIST) do
		if(#PROP_LIST == 0) then print("Error: No Props are in the list") return end
		
	
		local ent = ents.Create( "prop_physics_multiplayer")

		if ( !IsValid(ent) || !IsValid(PROP_LIST[k])) then print("Error Making Prop") end
		
		local modelpath = PROP_LIST[k][2]
		
		if(modelpath != nil && modelpath != "") then 
		
			ent:SetModel(modelpath) 
			if (IsValid(PROP_LIST[k][1])) then ent:SetPos(PROP_LIST[k][1]) else print("Error: No Position Set for prop "..k) end
			if (IsValid(PROP_LIST[k][3])) then ent:SetAngles(PROP_LIST[k][3]) else print("Error: No Angles Set for prop "..k) end
			ent:SetCustomCollisionCheck( true )
			ent:Spawn()
		
		else
			print("Error: Model not Set For Prop "..k)
		end
	end
end

function IsValidString(astring)
	if(astring != nil || astring != "") then return true end
	return false
end

function TrashmanWin()
	if(WINNER_CHOSEN == false) then
		--print("TRASHMEN WINS")
		RoundTimer = -2
		WINNER_CHOSEN = true
		PREV_TRASHMAN = CURRENT_TRASHMAN
		umsg.Start( "SendWinMessage" )
		umsg.Char(0) 
		umsg.End()
	end
end

function VictimsWin()
	if(WINNER_CHOSEN == false) then
		--print("VICTIMS WINS")
		RoundTimer = -2
		WINNER_CHOSEN = true
		PREV_TRASHMAN = CURRENT_TRASHMAN
		umsg.Start( "SendWinMessage" )
		umsg.Char(1) 
		umsg.End()
		
		if(GAMEMODE.Config.FreeForAllOnRoundEnd) then
			for k,v in pairs(team.GetPlayers(TEAM_VICTIMS)) do
				if(IsValid(v) && v:Alive()) then
					v:GiveAmmo( 200, "357", true )
				end
			end
		end
		
		if(GAMEMODE.Config.PointshopPoints || GAMEMODE.Config.PointshopTwoPoints) then
			for k,v in pairs(team.GetPlayers(TEAM_VICTIMS)) do
				if(IsValid(v) && v:Alive()) then
					if(GAMEMODE.Config.PointshopPoints) then
						v:PS_GivePoints(GAMEMODE.Config.PointshopPointsToGive)
						v:PS_Notify("You've been given "..GAMEMODE.Config.PointshopPointsToGive.." points for surviving the round!")
					end
					
					if(GAMEMODE.Config.PointshopTwoPoints) then
						v:PS2_AddStandardPoints(GAMEMODE.Config.PointshopPointsToGive, "You've been given "..GAMEMODE.Config.PointshopPointsToGive.." for surviving the round!", small)
					end
				end
			end
		end
		
		
	end
end