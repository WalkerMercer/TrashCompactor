GM.Name 	= "Trash Compactor"
GM.Author 	= "VictimofScience & Landmine752"
GM.Email 	= ""
GM.Website 	= "http://steamcommunity.com/id/VictimofScience/"
GM.Help		= "Beware the Trashman"
 
DeriveGamemode( "base" )
 
if ( CLIENT ) then
	CreateConVar( "cl_playercolor", "0.24 0.34 0.41", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" )
	CreateConVar( "cl_weaponcolor", "0.30 1.80 2.10", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" )
	CreateConVar( "cl_playermodel", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The skin to use, if the model has any" )
	CreateConVar( "cl_playerbodygroups", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The bodygroups to use, if the model has any" )
end


--Team IDS
TEAM_TRASHMAN = 4
TEAM_VICTIMS = 5

--Adding Player Fucntions
PlayerOverride = FindMetaTable("Player")

PlayerOverride.CurrentProp = nil
PlayerOverride.IsSpec = false

function GM:CreateTeams()
	--TEAM SETUP
	team.SetUp( TEAM_TRASHMAN, "Trashman", Color( 0, 255, 0 ), true )
	team.SetSpawnPoint( TEAM_TRASHMAN , { "info_player_terrorist", "info_player_rebel", "info_player_deathmatch" } )
	
	team.SetUp( TEAM_VICTIMS, "Victims", Color( 0, 0, 255 ), true )
	team.SetSpawnPoint( TEAM_VICTIMS, { "info_player_counterterrorist", "info_player_rebel", "info_player_deathmatch" } )
	

	--SPECTATOR
	team.SetUp( TEAM_SPECTATOR, "Spectators", Color( 200, 200, 200 ), true )
	team.SetSpawnPoint( TEAM_SPECTATOR, { "info_player_start" } ) 
	
	--UNASSIGNED
	team.SetUp( TEAM_UNASSIGNED, "Unassigned", Color( 200, 200, 200 ), true )
	team.SetSpawnPoint( TEAM_UNASSIGNED, { "info_player_start" } ) 
 
end

function PlayerOverride:SetGestureCam(set)
	self.GestureCam = set
end

function PlayerOverride:GetGestureCam()
	return self.GestureCam or false
end


function PlayerOverride:GetSpectatorEnt()
	return self.SpectatorEnt
end

function PlayerOverride:SetSpectatorEnt(ent)
	self.SpectatorEnt = ent
end

function PlayerOverride:IsSameTeamAs(ply)
	if((self:IsVictim() && ply:IsVictim()) || (self:IsTrashman() && ply:IsTrashman())) then
		return true
	else
		return false
	end
end


function PlayerOverride:IsTrashman()
	if(self:Team() == TEAM_TRASHMAN) then
		return true
	else
		return false
	end
end

function PlayerOverride:IsVictim()
	if(self:Team() == TEAM_VICTIMS) then
		return true
	else
		return false
	end
end


local CMoveData = FindMetaTable( "CMoveData" )

function CMoveData:RemoveKeys( keys )
	-- Using bitwise operations to clear the key bits.
	local newbuttons = bit.band( self:GetButtons(), bit.bnot( keys ) )
	self:SetButtons( newbuttons )
end

hook.Add( "SetupMove", "Disable Jumping", function( ply, mvd, cmd )
	if(GetConVarNumber("tc_customjump") == 1) then
		if mvd:KeyDown( IN_JUMP ) then
			mvd:RemoveKeys( IN_JUMP )
			local vel = mvd:GetVelocity()
			if(vel.z < 2 && vel.z > -2) then
				mvd:SetVelocity(Vector(vel.x,vel.y,GetConVarNumber("tc_customjumppower")))
			end
		end
	end
end )
