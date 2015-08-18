GM.Name 	= "Trash Compactor"
GM.Author 	= "VictimofScience"
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


PlayerOverride = FindMetaTable("Player")

PlayerOverride.CurrentProp = nil

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
