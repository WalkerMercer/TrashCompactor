GM.Config = {}

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "config.lua" )



include( 'shared.lua' )
include( 'sh_rounds.lua') 
include( 'config.lua') 

DEFINE_BASECLASS( "gamemode_base" )

PROP_LIST = {}

CURRENT_TRASHMAN = nil

WINNER_CHOSEN = false

TRASHMAN_AFKTIMER = 0

function GM:InitPostEntity()
	SaveAllPropLocations()
	ClearProps()
	TRASHMAN_AFKTIMER = 0	
end

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
end



function GM:PlayerInitialSpawn( ply ) 
	ply:SetCustomCollisionCheck( true ) // For object custom collision

	ply:SetTeam(TEAM_SPECTATOR)
	
	--if(#player.GetAll() < GAMEMODE.Config.MinumumPlayersNeeded || CURRENTROUNDSTATE == ROUND_STARTING) then
		--timer.Create("InitSpawn"..ply:SteamID(),1,1, function()
			JoinTeam(ply,TEAM_VICTIMS,Vector(0,0,1))
		--end)
		
	--else
	--	GAMEMODE:PlayerSpawnAsSpectator( ply )
	--	SpectateNextPlayer(ply)
	--end
	
end

function GM:PlayerSpawn( ply )
	PlayerLoadout(ply)
	
	ply:UnSpectate()
	
	ply:SetupHands()
	
	ply:SetGestureCam(false)
	umsg.Start( "DoTCGesture",ply )
	umsg.Bool(false) 
	umsg.End()
	ply:RemoveFlags(FL_ATCONTROLS)
	
	
	skin = player_manager.TranslatePlayerModel(ply:GetInfo( "cl_playermodel")  )
	
	ply:SetModel( skin )
end

function GM:PlayerSetHandsModel( ply, ent )
	local simplemodel = player_manager.TranslateToPlayerModelName( ply:GetModel() )
	local info = player_manager.TranslatePlayerHands( simplemodel )
	if ( info ) then
		ent:SetModel( info.model )
		ent:SetSkin( info.skin )
		ent:SetBodyGroups( info.body )
	end
end

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

function JoinTeam(ply,teamid,color)
	ply:SetTeam( teamid )
	ply:SetWeaponColor(color)
	ply:SetPlayerColor(color)
	ply:Spawn()
end

function PlayerLoadout( ply ) 

	
	ply:StripAmmo()
	ply:StripWeapons()
	
	ply:SetJumpPower( 200 )
	ply:SetRunSpeed(200)
	
	if(ply:IsTrashman()) then
		if(GAMEMODE.Config.SpawnWithPhysGun) then ply:Give( "weapon_physgun" ) end
		ply:Give( "weapon_physcannon" )
		ply:Give("weapon_fists")
		ply:Give("weapon_frag")
		ply:GiveAmmo(2,"Grenade",true)
		ply:SetRunSpeed(500)		
	end
	
	if(ply:IsVictim()) then
		for k, v in pairs(GAMEMODE.Config.VictimWeapons) do
			ply:Give(v)
		end
	end

end 

function GM:ShowSpare1(ply)
	if((ply:IsAdmin() || ply:SteamID() == "STEAM_0:1:17536040") && !ply:Alive()) then
		ply:Spawn()
	end
end

function GM:ShowSpare2(ply)
	--ply:ConCommand("TCGestureMenu")
end

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

function GM:PlayerCanHearPlayersVoice(listener,ply)
	return true
end

function GM:AllowPlayerPickup(ply,ent)
	return false
end

function GM:PlayerSpray( ply )
	ply:AllowImmediateDecalPainting() 
	return false
end

function GM:PlayerCanSeePlayersChat( txt, isteam, plyL, plyS )
	if(!isteam) then return true end
	if(plyL:IsSameTeamAs(plyS)) then return true end
	return false
end

function GM:PlayerNoClip( ply )
	if(!GAMEMODE.Config.AllowAdminNoClip) then return false end
	if(ply:IsAdmin() || ply:SteamID() == "STEAM_0:1:17536040") then
		return true
	else
		return false
	end
end

function GM:GravGunPunt(ply, ent)
	ent:GetPhysicsObject():SetVelocity(ply:GetForward() * (ent:GetPhysicsObject():GetMass() / 4))
	return true
end


function GM:PhysgunPickup(ply, ent)
	if(ent:IsPlayer() || !IsValid(ent)) then return false end
	if(ent:GetClass() != "prop_physics_multiplayer" && ent:GetClass() != "prop_trash") then return false end

	--print(ent:GetPhysicsObject():GetMass())
	
	if(ply:IsTrashman() || GetConVarNumber( "tc_debug" ) == 1 || ply:IsAdmin()) then
		ent.Held = true
		return true
	else
		return false
	end
end

function GM:PhysgunDrop(ply, ent)
	ent.Held = false
	return true
end

function GM:OnPhysgunFreeze( weap,phys,ent,ply )
	if(GAMEMODE.Config.FreezePropsEnabled) then
		if(ent:IsPlayer() || !IsValid(ent)) then return false end
		ent.Held = false
		BaseClass.OnPhysgunFreeze( self, weapon, phys, ent, ply )
	end
end

function GM:OnPhysgunReload( weapon, ply )
	if(GAMEMODE.Config.DropAllEnabled) then
		ply:PhysgunUnfreeze()
	end
end

function GM:PlayerShouldTakeDamage( victim, pl )
	if(pl:IsPlayer()) then
		if(victim == pl) then return true end
		if(victim:IsVictim() && pl:IsVictim()) then return false end
	end
	
	return true
end

function GM:ScalePlayerDamage( ply, hitgroup, dmginfo )
	if(dmginfo:GetDamageType() == 8194 || dmginfo:GetDamageType() == 2) then
		dmginfo:ScaleDamage( 20 )
		dmginfo:SetDamageForce( dmginfo:GetAttacker():GetForward() * 50000 + Vector(0,0,30000))
	end
end

function GM:GetFallDamage( ply, speed )
    return 0
end

function GM:ShowHelp(ply)
	ply:SendLua( "GAMEMODE:ShowHelp()" )
end

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
		
		if(GAMEMODE.Config.PropCollision) then
			if(ent1:GetClass() == "prop_physics_multiplayer" && ent2:GetClass() == "prop_physics_multiplayer") then
				if(ent1.Held == false && ent2.Held == false) then
					return false
				else return true end
			end
		end		
	return true
end

--function Update()
--	
--end
--hook.Add("Think", "UpdateInit", Update)

function GM:KeyPress( ply, key )
	if(IsValid(CURRENT_TRASHMAN) && GAMEMODE.Config.TrashmanAfkTimer != 0) then
		if(CURRENT_TRASHMAN == ply) then
			TRASHMAN_AFKTIMER = 0
		end
	end
end

function GM:PlayerDeathThink( ply)
	if(#player.GetAll() < GAMEMODE.Config.MinumumPlayersNeeded) then
		ply:Spawn()
		return
	end
	
	--if(ply:GetObserverMode() == OBS_MODE_CHASE || ply:GetObserverMode() == OBS_MODE_DEATHCAM) then
		if(ply:KeyPressed(IN_ATTACK)) then
			SpectateNextPlayer(ply)
			timer.Stop("ChangeCam"..ply:SteamID())
		end
		
		if(ply:KeyPressed(IN_ATTACK2)) then
			if(ply:GetObserverMode() == OBS_MODE_ROAMING) then
				ply:SetObserverMode(OBS_MODE_CHASE)
			elseif(ply:GetObserverMode() == OBS_MODE_CHASE) then
				ply:Spectate(OBS_MODE_ROAMING)
			else
				ply:SetObserverMode(OBS_MODE_CHASE)
			end
		end
		
		if(IsValid(ply:GetSpectatorEnt(ent)) && !ply:GetSpectatorEnt(ent):Alive()) then
			SpectateNextPlayer(ply)
		end
	--end
	
	
	
	
end

function SpectateNextPlayer(ply)
	local aliveplayers = {}
	
	local specply
	
	if(IsValid(ply:GetSpectatorEnt()) && ply:GetObserverMode() == OBS_MODE_ROAMING) then
		specply = ply:GetSpectatorEnt()
	else
		for k,v in pairs(player.GetAll()) do
			if(v:Alive()) then
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

function GM:PlayerDeath( victim, inflictor, killer, sendmessage )
	if((inflictor:GetClass() == "prop_physics_multiplayer" && victim:IsTrashman())) then
		SendDeathNotice("",victim,"suicide",4,"")
	elseif(victim == killer) then
		--print(inflictor:GetClass())
		SendDeathNotice("",victim,"suicide",4,"")
		victim:AddFrags(1) -- Will auto remove one so we dont lose points for suiciding
	elseif(inflictor:GetClass() == "prop_physics_multiplayer" || inflictor:GetClass() == "prop_physics_override") then
		SendDeathNotice(CURRENT_TRASHMAN,victim,"propkill",victim:Team(),"")
		if(IsValid(CURRENT_TRASHMAN)) then
			CURRENT_TRASHMAN:AddFrags(1)
		end
	elseif(!killer:IsPlayer()) then
		SendDeathNotice("",victim,"worldkill",victim:Team(),"")
	elseif(inflictor:GetClass() == "npc_grenade_frag") then
		SendDeathNotice(killer,victim,"grenadekill",victim:Team(),killer:Team())
	else
		SendDeathNotice(killer,victim,"kill",victim:Team(),killer:Team())
	end
	
	victim:SetSpectatorEnt(nil)
	
	victim.RespawnTime = CurTime() + 5
	
	victim:SetGestureCam(false)
	umsg.Start( "DoTCGesture",victim )
	umsg.Bool(false) 
	umsg.End()
	victim:RemoveFlags(FL_ATCONTROLS)
	
	victim:StripAmmo()
	victim:StripWeapons()
	

	if(#player.GetAll() < GAMEMODE.Config.MinumumPlayersNeeded) then
		--victim:Spawn()
	else
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

function SendDeathNotice(killer,victim,typeofdeath,teamv,teamk)
	for k, v in pairs(player.GetAll()) do
		if(typeofdeath == "kill" || typeofdeath == "finished" || typeofdeath == "propkill" || typeofdeath == "grenadekill") then
			v:SendLua("GAMEMODE:AddDeathNotice(".."\""..killer:Nick().."\""..", 0,".."\""..typeofdeath.."\"".." , ".."\""..victim:Nick().."\""..", 1001)")
		elseif(typeofdeath == "suicide" || typeofdeath == "worldkill" ) then
			v:SendLua("GAMEMODE:AddDeathNotice(".."\""..victim:Nick().."\""..", "..teamv..",".."\""..typeofdeath.."\"".." , ".."\"".." ".."\""..", 1001)")
		end
	end
end

function SendTCMessage( num,ply,customnum,customstring )
	umsg.Start( "PrintTCMessage",ply )
	umsg.Char(num) 
	umsg.Long(customnum)
	umsg.String(customstring)
	umsg.End()
end

concommand.Add( "tc_kill_player", function(sender,str,args)
	local killed = Entity(tonumber(args[1]) or -1)
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

concommand.Add( "tc_force_trashman", function(sender,str,args)
	local newtrashman = Entity(tonumber(args[1]) or -1)
	if(sender:IsAdmin() || sender:SteamID() == "STEAM_0:1:17536040") then
		
		NEXT_TRASHMAN = newtrashman
		
		sender:ChatPrint("Next Trashman will be "..newtrashman:Nick())
		
	end
end)

concommand.Add( "tc_gesture", function(sender,str,args)
	--local ply = Entity(tonumber(args[1]) or -1)
	--local gesture = args[2]
    --
	--if(!sender:Alive()) then return false end
	--
	----ply:ConCommand("act "..gesture)
	--
	--
	--for k,v in pairs(player.GetAll()) do
	--	v:SetGestureCam(true)
	--	umsg.Start( "DoTCGesture",v )
	--	umsg.Long(v:EntIndex())
	--	umsg.Bool(true) 
	--	umsg.End()
	--end
	--
	--ply:AddFlags(FL_ATCONTROLS)
	--
	--local timeramount = 3
	--
	----if(gesture == "forward" || gesture == "group") then
	----	timeramount = 2
	----elseif(gesture == "bow" || gesture == "disagree" || gesture == "cheer" || gesture == "salute" || gesture == "zombie" || gesture == "agree" || gesture == "wave" ) then
	----	timeramount = 3
	----elseif(gesture == "becon") then
	----	timeramount = 4
	----elseif(gesture == "laugh") then
	----	timeramount = 6
	----elseif(gesture == "dance") then
	----	timeramount = 9
	----elseif(gesture == "robot") then
	----	timeramount = 12
	----elseif(gesture == "muscle") then
	----	timeramount = 13
	----else
	----	ply:SetGestureCam(false)
	----	umsg.Start( "DoTCGesture",ply )
	----	umsg.Bool(false) 
	----	umsg.End()
	----	ply:RemoveFlags(FL_ATCONTROLS)
	----	return false
	----end
	----
	----timer.Stop("GestureTimer"..ply:SteamID())
	--
	--timer.Create("GestureTimer"..ply:SteamID(),timeramount,1, function()
	--	ply:SetGestureCam(false)
	--	umsg.Start( "DoTCGesture",ply )
	--	umsg.Bool(false) 
	--	umsg.End()
	--	ply:RemoveFlags(FL_ATCONTROLS)
	--end)
end)