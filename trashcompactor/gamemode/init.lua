GM.Config = {}

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "config.lua" )

include( 'shared.lua' )
include( 'sh_rounds.lua') 
include( 'config.lua') 

DEFINE_BASECLASS( "gamemode_base" )

--All The Props we have to respawn at the end of the round.
PROP_LIST = {}

--The Queue for the Trashman
TRASHMAN_QUEUE_LIST = {}

--The Current Trashman. Changes at the beggining of a round
CURRENT_TRASHMAN = nil

--Network Strings
util.AddNetworkString("TrashmanQueue")
util.AddNetworkString("FrozenPropsAmount")

--Changes if the Trashman or Victims win
WINNER_CHOSEN = false

--AFK Timer for the Trashman
TRASHMAN_AFKTIMER = 0
TRASHMAN_MOVED = false

--Used for Loading the Trashman Queue from file. Useful for switching between maps. Not working yet
LOAD_QUEUE = true--false
local QueueFileText = ""
UseTrashmanQueue = false

--I should probably precache these
local DefaultModels = {}
DefaultModels[1] = "male01"
DefaultModels[2] = "male02"
DefaultModels[3] = "male03"
DefaultModels[4] = "male04"
DefaultModels[5] = "male05"
DefaultModels[6] = "male06"
DefaultModels[7] = "male07"
DefaultModels[8] = "male08"
DefaultModels[9] = "male09"
DefaultModels[10] = "female01"
DefaultModels[11] = "female02"
DefaultModels[12] = "female03"
DefaultModels[13] = "female04"
DefaultModels[14] = "female06"
DefaultModels[15] = "female07"

--All the triggers found to remove the Physgun from the Trashman
TRASHMAN_STRIP_TRIGGERS = {}


function GM:InitPostEntity()
	SaveAllPropLocations()
	ClearProps()
	SpawnAllProps()
	TRASHMAN_AFKTIMER = 0
	
	--Not working yet
	--ReadTrashmanQueueFromFile()
	LOAD_QUEUE = true
	
	if(GAMEMODE.Config.StripPhysgun) then CreateAllStripTriggers() end
end

function CreateAllStripTriggers()
	local TRASHMAN_STRIP_TRIGGERS = ents.FindByName("TrashmanStripTrigger")
	
	if(#TRASHMAN_STRIP_TRIGGERS == 0) then
		print("WARNING: NO WEAPON STRIP TRIGGER WAS FOUND FOR THIS MAP. REFER TO THE WORKSHOP FOR INFORMATION.")
	end
	
	for k,v in pairs(TRASHMAN_STRIP_TRIGGERS) do
		local trigger = ents.Create("tc_striptrigger")
		trigger:SetPos(v:GetPos())
		trigger:Spawn()
		trigger:SetupBounds(v:GetCollisionBounds())
	end
end

--Finds all prop_physics and prop_physics_multiplayer and saves them to a table
function SaveAllPropLocations()
	local props = ents.FindByClass("prop_physics")
	
	local propsmulti = ents.FindByClass("prop_physics_multiplayer")
	
	table.Add(props, propsmulti)
	
	for k,v in pairs (props) do
		localprop = {}
		localprop[1] = v:GetPos()
		localprop[2] = v:GetModel()
		localprop[3] = v:GetAngles()
		
		table.insert(PROP_LIST, localprop)
	end
	--WritePropTableToFile()
end

--Does Nothing
function GM:ShutDown()
--	WriteTrashmanQueueToFile()
end

--Not Used
function WriteTrashmanQueueToFile()
	local queuelist = "" 
	
	for k,v in pairs(TRASHMAN_QUEUE_LIST) do
		if(IsValid(v)) then
			queuelist = queuelist..v:SteamID()..";"
		end
	end
	
	file.Write("TrashCompactorQueue.txt",queuelist)
	
end

--Not Used
function ReadTrashmanQueueFromFile()
	if(!file.Exists("TrashCompactorQueue.txt","DATA")) then 
		LOAD_QUEUE = true
		return false 
	end
	
	print("Read")
	
	local filedata = file.Read("TrashCompactorQueue.txt","DATA")
	
	print("FileData: "..filedata)
	
	local tbl = {}
	
	for plyid in string.gmatch(QueueFileText, '([^;]+)') do
		table.insert(tbl,plyid)
	end
	
	if(#tbl != 0) then
		timer.Create("READQUEUEFILETIMER",10,0,function()
			SetTrashmanQueueFromFile()
		end)
	else
		LOAD_QUEUE = true
	end
	
end

--Not Used
function SetTrashmanQueueFromFile()
	for plyid in string.gmatch(QueueFileText, '([^;]+)') do
		local player = player.GetBySteamID(plyid)
		print("GotPlayer: "..plyid)
		if(player != false) then
			table.insert(TRASHMAN_QUEUE_LIST,player)
			print("Inserted Into Table")
		end
		
	end
	
	LOAD_QUEUE = true
end

--Not Used
function WritePropTableToFile()
	if(#PROP_LIST <= 0) then return end
	local fileinfo = ""
	
	for k,v in pairs(PROP_LIST) do
		--for n,m in pairs(v) do
		--	fileinfo = fileinfo..m[n]..","
		--end
		fileinfo = fileinfo.."Pos:"..v[1]..";"
		fileinfo = fileinfo.."Model:"..v[2]..";"
		fileinfo = fileinfo.."Angles:"..v[3]..";"
	end
	
	print(fileinfo)
	
end

--When a player joins the server
function GM:PlayerInitialSpawn( ply ) 
	ply:SetCustomCollisionCheck( true ) 
	ply:AllowFlashlight( true ) 
	ply:SetTeam(TEAM_SPECTATOR)
	if(GetConVarNumber("tc_debug") == 1) then
		JoinTeam(ply,TEAM_VICTIMS,GAMEMODE.Config.VictimsWeaponColor)
	end
	
	ply:ChatPrint("Use !tchelp for a list of commands.")
end

--Called when players spawn. Also called when players who are alive at the end of the round reset.
function GM:PlayerSpawn( ply )
	if(ply:Team() != TEAM_SPECTATOR || GetConVarNumber("tc_debug") == 1) then
	
		PlayerLoadout(ply)
		
		ply.IsSpec = false
		
		ply:UnSpectate()
		
		ply:SetupHands()
		
		ply:SetGestureCam(false)
		umsg.Start( "DoTCGesture",ply )
		umsg.Bool(false) 
		umsg.End()
		ply:RemoveFlags(FL_ATCONTROLS)
	
		if(!GAMEMODE.Config.PointshopModels || ply:GetModel() == "models/player.mdl") then
			skin = player_manager.TranslatePlayerModel(DefaultModels[math.random(#DefaultModels)]  )
			
			ply:SetModel( skin )
		end
	
	else
		ply.IsSpec = true
		GAMEMODE:PlayerSpawnAsSpectator( ply )
	end
end

--Sets up hands for FP view
function GM:PlayerSetHandsModel( ply, ent )
	local simplemodel = player_manager.TranslateToPlayerModelName( ply:GetModel() )
	local info = player_manager.TranslatePlayerHands( simplemodel )
	if ( info ) then
		ent:SetModel( info.model )
		ent:SetSkin( info.skin )
		ent:SetBodyGroups( info.body )
	end
end

--Checks for spawnpoints
function GM:IsSpawnpointSuitable( ply, spawnpointent, bMakeSuitable )
	local Pos = spawnpointent:GetPos()
	local Ents = ents.FindInBox( Pos + Vector( -16, -16, 0 ), Pos + Vector( 16, 16, 72 ) )

	if ( ply:Team() == TEAM_SPECTATOR or ply:Team() == TEAM_UNASSIGNED ) then return true end

	local Blockers = 0

	for k, v in pairs( Ents ) do
		if ( IsValid( v ) && v:GetClass() == "player" && v:Alive() ) then

			Blockers = Blockers + 1

			if ( bMakeSuitable ) then
				v:Kill()
			end

		end
	end

	if ( bMakeSuitable ) then return true end
	if ( Blockers > 0 ) then return false end
	return true
end


--Joins Teams
function JoinTeam(ply,teamid,color)
	ply:SetTeam( teamid )
	ply:SetWeaponColor(color)
	ply:SetPlayerColor(color)
	ply:Spawn()
end

--Gets all weapons depending on the team
function PlayerLoadout( ply ) 	
	ply:StripAmmo()
	ply:StripWeapons()
	
	ply:SetJumpPower(200)
	ply:SetRunSpeed(200)
	
	if(ply:IsTrashman()) then
		if(GAMEMODE.Config.SpawnWithPhysGun) then ply:Give( "weapon_physgun" ) end
		ply:Give("weapon_physcannon")
		ply:Give("weapon_fists")
		ply:Give("weapon_frag")
		ply:GiveAmmo(2,"Grenade",true)
		ply:SetRunSpeed(300)		
	end
	
	if(ply:IsVictim()) then
		for k, v in pairs(GAMEMODE.Config.VictimWeapons) do
			ply:Give(v)
		end
	end

end 

--Respawn for Admins by pressing F3
function GM:ShowSpare1(ply)
	if(GAMEMODE.Config.AllowAdminRespawn) then
		if((ply:IsAdmin() || ply:SteamID() == "STEAM_0:1:17536040") && !ply:Alive()) then
			ply:Spawn()
		end
	end
end

--Gesture Menu F4
function GM:ShowSpare2(ply)
	ply:ConCommand("TCGestureMenu")
	
	umsg.Start( "DoTCGesture",ply )
	umsg.Bool(false) 
	umsg.End()
	ply:RemoveFlags(FL_ATCONTROLS)
	
end

--Called before a player spawns.
function GM:PlayerSelectSpawn( ply )
	local trashmanpoints = ents.FindByClass("info_player_terrorist")
	local garbagepoints = ents.FindByClass("info_player_counterterrorist")
	local spectatorpoints = ents.FindByClass("info_player_start")

	if (ply:IsTrashman()) then
		for k, v in pairs( trashmanpoints ) do
			if ( IsValid(v) && GAMEMODE:IsSpawnpointSuitable(ply,v,false)) then
				return v
			end
		end
		return trashmanpoints[1]
	elseif (ply:IsVictim()) then
		for k, v in pairs( garbagepoints ) do
			if ( IsValid(v) && GAMEMODE:IsSpawnpointSuitable(ply,v,false)) then
				return v
			end
		end
		return garbagepoints[1]
	elseif (ply:Team() == TEAM_SPECTATOR || ply:Team() == TEAM_UNASSIGNED) then
		for k, v in pairs( spectatorpoints ) do
			if ( IsValid(v) && GAMEMODE:IsSpawnpointSuitable(ply,v,false)) then
				return v
			end
		end
		return spectatorpoints[1]
	end
end

--Can always hear others voice. Allows Talking between Trashman and Victims
function GM:PlayerCanHearPlayersVoice(listener,ply)
	return true
end

--Dont Allow Players to pickup Props
function GM:AllowPlayerPickup(ply,ent)
	return false
end

--Allows Spraying Decals
function GM:PlayerSpray( ply )
	ply:AllowImmediateDecalPainting() 
	return false
end

--General Chat Function
function GM:PlayerCanSeePlayersChat( txt, isteam, plyL, plyS )
	if(!isteam) then return true end
	if(plyL:IsSameTeamAs(plyS)) then return true end
	return false
end

--Admins can Noclip only if the Config allows it (F)
function GM:PlayerNoClip( ply )
	if(!GAMEMODE.Config.AllowAdminNoClip) then return false end
	if(ply:IsAdmin() || ply:SteamID() == "STEAM_0:1:17536040") then
		return true
	else
		return false
	end
end

--Adds more force to the object you punting
function GM:GravGunPunt(ply, ent)
	if(!IsValid(ent) || !IsValid(ent:GetPhysicsObject())) then return false end
	ent:GetPhysicsObject():SetVelocity(ply:GetForward() * (ent:GetPhysicsObject():GetMass() / 4))
	return true
end

--Called when attempting to pickup props with the physgun
function GM:PhysgunPickup(ply, ent)
	if(ent:IsPlayer() || !IsValid(ent)) then return false end
	if(ent:GetClass() != "prop_physics_multiplayer" && ent:GetClass() != "prop_trash") then return false end

	--Useful for Map Making
	if(GetConVarNumber("tc_debug") == 1) then
		print("Model: "..ent:GetModel().."  Mass: "..ent:GetPhysicsObject():GetMass())
	end
	
	--All the props the Trashman has frozen
	ply.FrozenPhysicsObjects = ply.FrozenPhysicsObjects or {}
	for k,v in pairs(ply.FrozenPhysicsObjects) do
		if(IsValid(v.ent) && v.ent == ent) then
			local tbl = {}
			for y,u in pairs(ply.FrozenPhysicsObjects) do
				if((IsValid(u.ent) && u.ent != ent) || (IsValid(ent.phys) && !ent.phys:IsMoveable())) then
					table.insert(tbl,u)
				end
			end
			ply.FrozenPhysicsObjects = tbl
		end
		
		if(IsValid(v.phys) && v.phys:IsMoveable()) then
			local tbl2 = {}
			for y,u in pairs(ply.FrozenPhysicsObjects) do
				if((IsValid(u.ent) && u.ent != v.ent)) then
					table.insert(tbl2,u)
				end
			end
			ply.FrozenPhysicsObjects = tbl2
		end
	end
		
	--Checking the prop is in distance and the person trying to pick it up is a Trashman	
	if(ply:IsTrashman() || GetConVarNumber( "tc_debug" ) == 1 || ply:IsAdmin()) then
		local distancetoprop = ply:GetPos():Distance(ent:GetPos())
		if(distancetoprop > GetConVarNumber("tc_maxpropdistance")) then return false end
		
		ply.CurrentProp = ent
		
		return true
	else
		return false -- Does not allow pickup
	end
end


function GM:PhysgunDrop(ply, ent)
	ply.CurrentProp = nil
	BaseClass.PhysgunDrop( self, ply, ent)
	return true
end

--Can only freeze if you are under the limit of frozen objects
function GM:OnPhysgunFreeze( weap,phys,ent,ply )
	if(GAMEMODE.Config.FreezePropsEnabled) then
		if(ent:IsPlayer() || !IsValid(ent)) then return false end
		
		ply.FrozenPhysicsObjects = ply.FrozenPhysicsObjects or {}
	
		if(#ply.FrozenPhysicsObjects >= GetConVarNumber("tc_maxfreeze")) then return false end
		
		BaseClass.OnPhysgunFreeze( self, weapon, phys, ent, ply )
	end
end

--Drops all only if enabled
function GM:OnPhysgunReload( weapon, ply )
	if(GAMEMODE.Config.DropAllEnabled) then
		ply:PhysgunUnfreeze()
	end
end

--Can players hurt others.
function GM:PlayerShouldTakeDamage( victim, pl )
	if(pl:IsPlayer()) then
		if(victim == pl) then return true end --Can always hurt themself
		
		if(GAMEMODE.Config.FreeForAllOnRoundEnd) then -- If its the free for all
			if(CURRENTROUNDSTATE != ROUND_ENDED) then
				if(victim:IsVictim() && pl:IsVictim()) then return false end
			else
				if(victim:IsVictim() && pl:IsVictim()) then return true end
			end
		else
			if(victim:IsVictim() && pl:IsVictim()) then return false end
		end
	end
	return true
end

--Gives the magnum the instakill aswell as the goofy ragdoll force
function GM:ScalePlayerDamage( ply, hitgroup, dmginfo )
	if(dmginfo:GetDamageType() == 8194 || dmginfo:GetDamageType() == 2) then
		dmginfo:ScaleDamage( 20 )
		dmginfo:SetDamageForce( dmginfo:GetAttacker():GetForward() * 50000 + Vector(0,0,30000))
	end
end

--No Fall Damage
function GM:GetFallDamage( ply, speed )
    return 0
end

--Called when ply pressed F1
function GM:ShowHelp(ply)
	ply:SendLua( "GAMEMODE:ShowHelp()" )
end

--Players will collide with eachother
function GM:ShouldCollide(ent1,ent2)
		if(ent1:IsPlayer()) then
			if(ent2:IsPlayer()) then
				return true
			end
		elseif(ent2:IsPlayer()) then
			if(ent1:IsPlayer()) then
				return true
			end
		end
				
	return true
end

--Called every frame
function Update()
	if(IsValid(CURRENT_TRASHMAN)) then
		if(IsValid(CURRENT_TRASHMAN.CurrentProp)) then
			local distancetoprop = CURRENT_TRASHMAN:GetPos():Distance(CURRENT_TRASHMAN.CurrentProp:GetPos())
			if(distancetoprop > GetConVarNumber("tc_maxpropdistance") + 5) then
				CURRENT_TRASHMAN:SendLua("notification.AddLegacy(\"Prop exceeded maximum distance.\", NOTIFY_ERROR, 5)")
				CURRENT_TRASHMAN:ConCommand("-attack")
				CURRENT_TRASHMAN.CurrentProp = nil
			end
			umsg.Start( "GetCurrentPropDistance",CURRENT_TRASHMAN)
			umsg.Long(distancetoprop) 
			umsg.End()
		else
			umsg.Start( "GetCurrentPropDistance",CURRENT_TRASHMAN)
			umsg.Long(0) 
			umsg.End()
		end
	end
	
	if(GetConVarNumber("tc_queue") == 1) then
		UseTrashmanQueue = true
	else
		UseTrashmanQueue = false
	end
	
end
hook.Add("Think", "UpdateInit", Update)

--Used for the AFK Timer
function GM:KeyPress( ply, key )
	if(!TRASHMAN_MOVED) then
		if(IsValid(CURRENT_TRASHMAN) && GetConVarNumber("tc_afktimer") != 0) then
			if(CURRENT_TRASHMAN == ply) then
				TRASHMAN_AFKTIMER = 0
				TRASHMAN_MOVED = true
			end
		end
	end
end

--Called every frame when ply is dead
function GM:PlayerDeathThink( ply)
	if(GetConVarNumber("tc_debug") == 1) then --InstaRespawn if we are in debug mode
		ply:Spawn()
		return
	end
	
	if(ply:KeyPressed(IN_ATTACK)) then -- Spectate Next Player
		SpectateNextPlayer(ply)
		timer.Stop("ChangeCam"..ply:SteamID())
	end
	
	if(ply:KeyPressed(IN_ATTACK2)) then
		if(ply:GetObserverMode() == OBS_MODE_ROAMING) then
			ply:SetObserverMode(OBS_MODE_CHASE)
			if(IsValid(ply:GetSpectatorEnt(ent)) && !ply:GetSpectatorEnt(ent):Alive()) then
				SpectateNextPlayer(ply)
			end
		elseif(ply:GetObserverMode() == OBS_MODE_CHASE) then
			ply:Spectate(OBS_MODE_ROAMING)
		else
			ply:SetObserverMode(OBS_MODE_CHASE)
		end
	end
	
	if(IsValid(ply:GetSpectatorEnt(ent)) && !ply:GetSpectatorEnt(ent):Alive() && ply:GetObserverMode() != OBS_MODE_ROAMING) then
		SpectateNextPlayer(ply)
	end
end

function SpectateNextPlayer(ply)
	local aliveplayers = {}
	
	local specply
	
	if(IsValid(ply:GetSpectatorEnt()) && ply:GetObserverMode() == OBS_MODE_ROAMING) then
		specply = ply:GetSpectatorEnt()
	else
		for k,v in pairs(player.GetAll()) do
			if(v:Alive() && v:Team() != TEAM_SPECTATOR) then
				if(IsValid(ply:GetSpectatorEnt())) then
					if(ply:GetSpectatorEnt() != v) then
						table.insert(aliveplayers, v)
					end
				else
					table.insert(aliveplayers, v)
				end
			end
		end
		
		if(#aliveplayers == 0) then return end
		
		specply = aliveplayers[math.random(#aliveplayers)]
	end
	
	ply:Spectate (OBS_MODE_CHASE)
	ply:SpectateEntity(specply)
	ply:SetSpectatorEnt(specply)
	
end

--Called when Player dies
function GM:PlayerDeath( victim, inflictor, killer, sendmessage )
	if((inflictor:GetClass() == "prop_physics_multiplayer" && victim:IsTrashman())) then
		SendDeathNotice("",victim,"suicide",4,"")
	
	elseif(victim == killer) then
		SendDeathNotice("",victim,"suicide",4,"")
		victim:AddFrags(1) -- Will auto remove one so we dont lose points for suiciding
	
	elseif(inflictor:GetClass() == "prop_physics_multiplayer" || inflictor:GetClass() == "prop_physics_override") then
		SendDeathNotice(CURRENT_TRASHMAN,victim,"propkill",victim:Team(),"")
		if(IsValid(CURRENT_TRASHMAN)) then
			CURRENT_TRASHMAN:AddFrags(1)
			GiveDeathPoints(victim,CURRENT_TRASHMAN)
		end
	
	elseif(!killer:IsPlayer()) then
		SendDeathNotice("",victim,"worldkill",victim:Team(),"")
	elseif(inflictor:GetClass() == "npc_grenade_frag") then
		SendDeathNotice(killer,victim,"grenadekill",victim:Team(),killer:Team())
		
		GiveDeathPoints(victim,killer)
	else
		SendDeathNotice(killer,victim,"kill",victim:Team(),killer:Team())
		
		GiveDeathPoints(victim,killer)
	end
	
	victim:SetSpectatorEnt(nil)
	
	victim.IsSpec = true
	
	victim.RespawnTime = CurTime() + 5
	
	victim:SetGestureCam(false)
	umsg.Start( "DoTCGesture",victim )
	umsg.Bool(false) 
	umsg.End()
	victim:RemoveFlags(FL_ATCONTROLS)
	
	victim:StripAmmo()
	victim:StripWeapons()
	

	if(MinumumPlayersNeeded()) then
		--victim:Spawn()
	else
		--GAMEMODE:PlayerSpawnAsSpectator( ply ) TOTRY
		victim:Spectate (OBS_MODE_DEATHCAM)
		victim:SpectateEntity(victim:GetRagdollEntity())
		timer.Create("ChangeCam"..victim:SteamID(),5,1, function()
			if(IsValid(victim)) then
				if(!victim:Alive()) then
					SpectateNextPlayer(victim)
				end
			end
		end)
	end
	
end

--Used for Pointshop
function GiveDeathPoints(victim,killer)
	if(GAMEMODE.Config.PointshopPoints) then
		killer:PS_GivePoints(GAMEMODE.Config.PointshopPointsToGive)
		killer:PS_Notify("You've been given "..GAMEMODE.Config.PointshopPointsToGive.." points for killing "..victim:Nick())
	end
	
	if(GAMEMODE.Config.PointshopTwoPoints) then
		killer:PS2_AddStandardPoints(GAMEMODE.Config.PointshopPointsToGive, "You've been given "..GAMEMODE.Config.PointshopPointsToGive.." points for killing "..victim:Nick(), small)
	end
end

--Sends death notice to clients
function SendDeathNotice(killer,victim,typeofdeath,teamv,teamk)
	for k, v in pairs(player.GetAll()) do
		if(typeofdeath == "kill" || typeofdeath == "finished" || typeofdeath == "propkill" || typeofdeath == "grenadekill") then
			v:SendLua("GAMEMODE:AddDeathNotice(".."\""..killer:Nick().."\""..", 0,".."\""..typeofdeath.."\"".." , ".."\""..victim:Nick().."\""..", 1001)")
		elseif(typeofdeath == "suicide" || typeofdeath == "worldkill" ) then
			v:SendLua("GAMEMODE:AddDeathNotice(".."\""..victim:Nick().."\""..", "..teamv..",".."\""..typeofdeath.."\"".." , ".."\"".." ".."\""..", 1001)")
		end
	end
end

function SendTrashmanQueue()
	net.Start("TrashmanQueue")

	net.WriteBool(UseTrashmanQueue)
	
	net.WriteEntity(BOUGHT_TRASHMAN)

	net.WriteTable(TRASHMAN_QUEUE_LIST)

	net.Broadcast()
end

function SendFrozenAmount()
	if(!IsValid(CURRENT_TRASHMAN)) then return false end
	
	net.Start("FrozenPropsAmount")
	
	CURRENT_TRASHMAN.FrozenPhysicsObjects = CURRENT_TRASHMAN.FrozenPhysicsObjects or {}
	net.WriteInt(#CURRENT_TRASHMAN.FrozenPhysicsObjects, 32)
	
	net.Send(CURRENT_TRASHMAN)
end

function AddToQueue(sender,ply)
	local alreadycontains = false
		
	for k,v in pairs(TRASHMAN_QUEUE_LIST) do
		if(IsValid(v) && v == ply) then
			alreadycontains = true
		end
	end
	
	if(!alreadycontains) then
		table.insert(TRASHMAN_QUEUE_LIST,ply)
	end
	
	if(alreadycontains) then
		SendTCMessage( 5,sender,0,"")
	elseif(sender != ply) then
		sender:ChatPrint("You have added "..ply:Nick().." to the queue.")
	else
		SendTCMessage( 3,sender,0,"")
	end
end

function RemoveFromQueue(sender,ply)
	local newqueue = {}
		
	for k,v in pairs(TRASHMAN_QUEUE_LIST) do
		if(IsValid(v) && v != ply) then
			table.insert(newqueue,v)
		end
	end
	
	TRASHMAN_QUEUE_LIST = newqueue
	
	if(sender != ply) then
		sender:ChatPrint("You have removed "..ply:Nick().." from the queue.")
	else
		SendTCMessage( 4,sender,0,"")
	end
end

function SendTCMessage( num,ply,customnum,customstring )
	umsg.Start( "PrintTCMessage",ply )
	umsg.Char(num) 
	umsg.Long(customnum)
	umsg.String(customstring)
	umsg.End()
end

function GM:SetBoughtTrashman(ply)
	BOUGHT_TRASHMAN = ply
	SendTCMessage(6,ply,0,"")
end

function GM:GetBoughtTrashman()
	return BOUGHT_TRASHMAN or nil
end


--All Console Commands for Admins. The shouldnt be console commands at some point. 
concommand.Add( "tc_kill_player", function(sender,str,args)
	local killed = Entity(tonumber(args[1]) or -1)
	
	if(!killed:Alive()) then
		sender:ChatPrint(killed:Nick().." is already dead.")
		return false
	end
	
	if(sender:IsAdmin() || sender:SteamID() == "STEAM_0:1:17536040") then
		killed:Kill()
	end
end)

concommand.Add( "tc_kick_player", function(sender,str,args)
	local kicked = Entity(tonumber(args[1]) or -1)
	if(sender:IsAdmin() || sender:SteamID() == "STEAM_0:1:17536040") then
		kicked:Kick( "Kicked from server by:"..sender:Nick() )
	end
end)

concommand.Add( "tc_rocket_player", function(sender,str,args)
	local rocket = Entity(tonumber(args[1]) or -1)
	if(sender:IsAdmin() || sender:SteamID() == "STEAM_0:1:17536040") then
		rocket:SetVelocity(Vector(0,0,3000))
		timer.Create("TCRocket"..rocket:SteamID(),2,1, function()
			local explode = ents.Create( "env_explosion" ) -- creates the explosion
			explode:SetPos( rocket:GetPos() )
			explode:SetOwner( rocket )
			explode:Spawn()
			explode:SetKeyValue( "iMagnitude", "220" )
			explode:Fire( "Explode", 0, 0 )
		end)
	end
	sender:ChatPrint("Rocketed "..rocket:Nick().."!")
end)

concommand.Add( "tc_launch_player", function(sender,str,args)
	local rocket = Entity(tonumber(args[1]) or -1)
	if(sender:IsAdmin() || sender:SteamID() == "STEAM_0:1:17536040") then
		rocket:SetVelocity(sender:GetForward() * 3000 + Vector(0,0,300))
	end
	sender:ChatPrint("Sent "..rocket:Nick().." Flying!")
end)

concommand.Add( "tc_lock_player", function(sender,str,args)
	local lock = Entity(tonumber(args[1]) or -1)
	if(sender:IsAdmin() || sender:SteamID() == "STEAM_0:1:17536040") then
		lock:Freeze(true)
		--lock:AddFlags(FL_ATCONTROLS)
	end
	sender:ChatPrint("Locked "..lock:Nick())
	lock:ChatPrint(sender:Nick().." has locked your movements!")
end)

concommand.Add( "tc_unlock_player", function(sender,str,args)
	local unlock = Entity(tonumber(args[1]) or -1)
	if(sender:IsAdmin() || sender:SteamID() == "STEAM_0:1:17536040") then
		unlock:Freeze(false)
		--unlock:RemoveFlags(FL_ATCONTROLS)
	end
	sender:ChatPrint("Unlocked "..unlock:Nick())
	unlock:ChatPrint(sender:Nick().." has unlocked your movements!")
end)

concommand.Add( "tc_force_drop_all_props", function(sender,str,args)
	local trashman = Entity(tonumber(args[1]) or -1)
	if(sender:IsAdmin() || sender:SteamID() == "STEAM_0:1:17536040") then
		trashman:PhysgunUnfreeze()
		trashman:PhysgunUnfreeze()
		trashman:PhysgunUnfreeze()
	end
end)

concommand.Add( "tc_force_trashman", function(sender,str,args)
	local newtrashman = Entity(tonumber(args[1]) or -1)
	if(sender:IsAdmin() || sender:SteamID() == "STEAM_0:1:17536040") then
		
		NEXT_TRASHMAN = newtrashman
		
		sender:ChatPrint("Next Trashman will be "..newtrashman:Nick())
		
	end
end)

concommand.Add( "tc_add_to_trashman_queue", function(sender,str,args)
	local plytoadd = Entity(tonumber(args[1]) or -1)
	if(sender:IsAdmin() || sender == plytoadd || sender:SteamID() == "STEAM_0:1:17536040") then
		
		AddToQueue(sender,plytoadd)
	end
end)

concommand.Add( "tc_remove_from_trashman_queue", function(sender,str,args)
	local plytoremove = Entity(tonumber(args[1]) or -1)
	if(sender:IsAdmin() || sender == plytoremove || sender:SteamID() == "STEAM_0:1:17536040") then
		RemoveFromQueue(sender,plytoremove)
	end
end)

concommand.Add( "tc_gesture", function(sender,str,args)
	local ply = Entity(tonumber(args[1]) or -1)
	local gesture = args[2]
    
	if(!sender:Alive()) then return false end

	umsg.Start( "DoTCGesture",ply )
	umsg.Bool(true) 
	umsg.End()
	
	ply:AddFlags(FL_ATCONTROLS)
	
	local timeramount = 3
	
	if(gesture == "forward" || gesture == "group") then
		timeramount = 2
	elseif(gesture == "bow" || gesture == "disagree" || gesture == "cheer" || gesture == "salute" || gesture == "zombie" || gesture == "agree" || gesture == "wave" ) then
		timeramount = 3
	elseif(gesture == "becon") then
		timeramount = 4
	elseif(gesture == "laugh") then
		timeramount = 6
	elseif(gesture == "dance") then
		timeramount = 9
	elseif(gesture == "robot") then
		timeramount = 12
	elseif(gesture == "muscle") then
		timeramount = 13
	else
		umsg.Start( "DoTCGesture",ply )
		umsg.Bool(false) 
		umsg.End()
		ply:RemoveFlags(FL_ATCONTROLS)
		return false
	end
	
	timer.Stop("GestureTimer"..ply:SteamID())
	
	timer.Create("GestureTimer"..ply:SteamID(),timeramount,1, function()
		ply:SetGestureCam(false)
		umsg.Start( "DoTCGesture",ply )
		umsg.Bool(false) 
		umsg.End()
		ply:RemoveFlags(FL_ATCONTROLS)
	end)
end)

function CommandsCheck(ply,txt)
	local command = string.Explode(" ", txt)
	
	if (command[1] == "!tchelp") then
		if (ply:IsAdmin()) then 
		--	ply:ChatPrint("!setafktimer ## - Sets the AFK Timer to ##")
		--	ply:ChatPrint("!setfreezeamount ## - Sets the amount of props you can freeze to ##")
			ply:ChatPrint("!togglephysgun - Toggles spawning with the physgun")
			ply:ChatPrint("!togglefreeze - Toggles freezing with the physgun")
		--	ply:ChatPrint("!togglequeue - Toggles the Trashman Queue")
			ply:ChatPrint("!endround - Ends the Round. No Winner")
		end
		
		ply:ChatPrint("!queue - Adds/Removes Yourself from the queue. Only works if the Queue is enabled")
		
		return false
	end
	
	if (command[1] == "!togglephysgun") then
		if (ply:IsAdmin()) then 
			GAMEMODE.Config.SpawnWithPhysGun = !GAMEMODE.Config.SpawnWithPhysGun
			ply:ChatPrint("Toggled Physgun")
			return false
		else
			ply:ChatPrint("You do not have permission to run this command")
			return false
		end
	end
	
	if (command[1] == "!togglefreeze") then
		if (ply:IsAdmin()) then 
			GAMEMODE.Config.FreezePropsEnabled = !GAMEMODE.Config.FreezePropsEnabled
			CURRENT_TRASHMAN:PhysgunUnfreeze()
			CURRENT_TRASHMAN:PhysgunUnfreeze()
			CURRENT_TRASHMAN:PhysgunUnfreeze()
			ply:ChatPrint("Toggled Physgun Freeze")
			return false
		else
			ply:ChatPrint("You do not have permission to run this command")
			return false
		end
	end

	if (command[1] == "!queue") then
			if(!UseTrashmanQueue) then
				ply:ChatPrint("Queue is Disabled.")
				return false
			end
			
			if(!LOAD_QUEUE) then
				ply:ChatPrint("Queue is attempting to load from last game. Please wait "..timer.TimeLeft("READQUEUEFILETIMER").." seconds.")
				return false
			end
			
			local alreadycontains = false
		
			for k,v in pairs(TRASHMAN_QUEUE_LIST) do
				if(IsValid(v) && v == ply) then
					alreadycontains = true
				end
			end
			
			if(!alreadycontains) then
				AddToQueue(ply,ply)
			else
				RemoveFromQueue(ply,ply)
			end
		return false
	end
	
	if (command[1] == "!endround") then
		if (ply:IsAdmin()) then 
			EndRound()
			return false
		else
			ply:ChatPrint("You do not have permission to run this command")
			return false
		end
	end
	
	--if (command[1] == "!shop") then
	--	return false
	--end

end
hook.Add("PlayerSay","CommandsCheck",CommandsCheck)

