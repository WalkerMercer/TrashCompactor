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
				RoundRestartTimer = CurTime() + 10
				VictimsWin()
				CURRENTROUNDSTATE = ROUND_ENDED
			end
		elseif (CURRENTROUNDSTATE == ROUND_ENDED) then
			RoundEnd()
		elseif (CURRENTROUNDSTATE == ROUND_WAITING) then
			RoundStart()
		end
	else
		--Map isnt working
	end
end
hook.Add("Think", "Update", Update)

function RoundStart()
	local amountofply = #player.GetAll()
	if(amountofply >= GAMEMODE.Config.MinumumPlayersNeeded || GetConVarNumber( "tc_debug" ) == 1) then
		CURRENTROUNDSTATE = ROUND_RUNNING
		RoundTimer = AmountOfTimeInRound
		umsg.Start( "SendMessage" )
		umsg.Char(ROUND_RUNNING)
		umsg.End()
		
		SpawnAllProps()
		FindRandomTrashman()
		WINNER_CHOSEN = false
	else
		umsg.Start( "SendMessage" )
		umsg.Char(ROUND_WAITING)
		umsg.End()
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
		
		if(#player.GetAll() >= GAMEMODE.Config.MinumumPlayersNeeded) then
			local iseveryvictimdead = true
			local victims = team.GetPlayers(TEAM_VICTIMS)
			for k,v in pairs (victims) do
				if(v:Alive()) then iseveryvictimdead = false end
			end
			
			if(iseveryvictimdead) then
				--Trashman Wins!
				RoundRestartTimer = CurTime() + 10
				TrashmanWin()
				CURRENTROUNDSTATE = ROUND_ENDED
			end
			
			
			local iseverytrashmandead = true
			local trashmen = team.GetPlayers(TEAM_TRASHMAN)
			for k,v in pairs (trashmen) do
				if(v:Alive()) then iseverytrashmandead = false end
			end
				
			if(iseverytrashmandead) then
				--Victims Wins!
				RoundRestartTimer = CurTime() + 10
				VictimsWin()
				CURRENTROUNDSTATE = ROUND_ENDED
			end
			
			if(IsValid(CURRENT_TRASHMAN) && GAMEMODE.Config.TrashmanAfkTimer != 0) then
				if(TRASHMAN_AFKTIMER >= GAMEMODE.Config.TrashmanAfkTimer) then
					TRASHMAN_AFKTIMER = 0
					--for k,v in pairs(player.GetAll()) do
						SendTCMessage( 1,nil,0,CURRENT_TRASHMAN:Nick())
					--end
					CURRENT_TRASHMAN:Kill()
				elseif(TRASHMAN_AFKTIMER + 5 == GAMEMODE.Config.TrashmanAfkTimer) then
					SendTCMessage( 2,CURRENT_TRASHMAN,5,"")
				elseif(TRASHMAN_AFKTIMER + 10 == GAMEMODE.Config.TrashmanAfkTimer) then
					SendTCMessage( 2,CURRENT_TRASHMAN,10,"")
				end
			
				TRASHMAN_AFKTIMER = TRASHMAN_AFKTIMER + 1

			end
			
		else
			if(GetConVarNumber("tc_debug") != 1) then
				RoundRestartTimer = CurTime() + 10
				CURRENTROUNDSTATE = ROUND_ENDED
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
		
		WINNER_CHOSEN = false
		
		for k, v in pairs(player.GetAll()) do
			JoinTeam(v,TEAM_VICTIMS,Vector(0,0,1))
		end
	end
end

function ResetPlayers()
	for k, v in pairs(player.GetAll()) do
		v:Spawn()
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

function FindRandomTrashman()
	if(NEXT_TRASHMAN != nil) then
		JoinTeam(NEXT_TRASHMAN,TEAM_TRASHMAN,Vector(0,1,0))
		CURRENT_TRASHMAN = NEXT_TRASHMAN
		NEXT_TRASHMAN = nil
	else
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
		
			JoinTeam(noprevtrashman[num],TEAM_TRASHMAN,Vector(0,1,0))
			CURRENT_TRASHMAN = noprevtrashman[num]
		
		else
			
			print("Error Finding Trashman! Num: "..num.." Amount: "..#noprevtrashman)
			
			local ran = math.random(#list)
			JoinTeam(list[ran],TEAM_TRASHMAN,Vector(0,1,0))
			CURRENT_TRASHMAN = list[ran]
			
		end
	end
	
	for k,v in pairs(player.GetAll()) do
		SendTCMessage( 0,v,0,CURRENT_TRASHMAN:Nick())
	end
end

function ClearProps()
	local props = ents.FindByClass("prop_*")
	
	local grenades = ents.FindByClass("npc_grenade_frag")
	
	table.Add(props, grenades)
	
	for k,v in pairs (props) do
		v:Remove()
	end
end

function SpawnAllProps()
	for k,v in pairs (PROP_LIST) do
		local ent
		--if(PROP_LIST[k][2] == "models/props_c17/oildrum001_explosive.mdl") then
			ent = ents.Create( "prop_physics_multiplayer")
		--else
			--ent = ents.Create( "prop_trash")
		--end
		if ( !ent:IsValid() ) then return end
		ent:SetModel(PROP_LIST[k][2])
		ent:SetPos(PROP_LIST[k][1])
		ent:SetAngles(PROP_LIST[k][3])
		ent:SetCustomCollisionCheck( true )
		ent.Held = false
		ent:Spawn()
	end
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
	end
end