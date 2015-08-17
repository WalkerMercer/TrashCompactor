--CONFIG SETTINGS

--Round length in minutes
GM.Config.RoundTime = 5

--Amount of players needed before the round will start.
GM.Config.MinumumPlayersNeeded = 2

--Trashmen can double tap reload to drop all at once
GM.Config.DropAllEnabled = true

--Trashmen can freeze objects
GM.Config.FreezePropsEnabled = true

--Props will collide with each other
GM.Config.PropCollision = false

--Trashmen spawn with the Physgun
GM.Config.SpawnWithPhysGun = true

--Allow admins to noclip
GM.Config.AllowAdminNoClip = true

--Trashman AFK Timer. Set 0 to disable --Broken
GM.Config.TrashmanAfkTimer = 0


--Enable pointshop playermodels
GM.Config.PointshopModels = false

--Enable pointshops points
GM.Config.PointshopPoints = false

--Enable Pointshop points for Pointshop2
GM.Config.PointshopTwoPoints = false

--Amount of points to give for kills. Requires either pointshops to be enabled
GM.Config.PointshopPointsToGive = 10


--Weapons the victims will spawn with
GM.Config.VictimWeapons = {
	"weapon_357",
	"weapon_fists"
}

--When You Press F1 this is the link that will open
GM.Config.HelpButtonLink = "http://steamcommunity.com/sharedfiles/filedetails/?id=495998201"