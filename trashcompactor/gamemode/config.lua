

--CONFIG SETTINGS

--Use thr Trashman Queue? (Use tc_queue 1  console command now)
--GM.Config.UseTrashmanQueue = true

--Round length in minutes
GM.Config.RoundTime = 5

--Amount of players needed before the round will start.
GM.Config.MinumumPlayersNeeded = 2

--Trashmen can double tap reload to drop all at once
GM.Config.DropAllEnabled = true

--Trashmen can freeze objects
GM.Config.FreezePropsEnabled = true

--Maximum amount of props the Trashman can freeze (Use tc_maxfreeze ## console command now)
--GM.Config.MaxFreezeAmount = 10

--Props will collide with each other
GM.Config.PropCollision = false

--Trashmen spawn with the Physgun
GM.Config.SpawnWithPhysGun = true

--Strip Trashman of Physgun when he jumps down?
GM.Config.StripPhysgun = true



--Max grab distance for props (Use tc_maxpropdistance ### console command now)
--GM.Config.MaxPropDistance = 800

--Can Victims fight it out if they survive the round?
GM.Config.FreeForAllOnRoundEnd = true

--Allow admins to noclip
GM.Config.AllowAdminNoClip = true

--Allow Admin respawn with F3
GM.Config.AllowAdminRespawn = true

--Trashman AFK Timer. Set 0 to disable (Use tc_afktimer ## console command now)
--GM.Config.TrashmanAfkTimer = 20

--Enable pointshop playermodels
GM.Config.PointshopModels = false

--Enable pointshops points
GM.Config.PointshopPoints = false

--Enable Pointshop points for Pointshop2
GM.Config.PointshopTwoPoints = false

--Amount of points to give for kills. Requires either pointshops to be enabled
GM.Config.PointshopPointsToGive = 10

--Colors--

--Default color for the Trashman team. For GUI only. (Red Green Blue Alpha format. Leave Alpha at 255) Default is 120,152,27,255
GM.Config.TrashmanColor = Color(120,152,27,255)

--Default color for the Victims team. For GUI only. Default is 46,92,165,255
GM.Config.VictimsColor = Color(46,92,165,255)

--Default color for the Trashman weapon and skin (Red Green Blue format. Value between 1 & 0 work best. ex 0.58)
GM.Config.TrashmanWeaponColor = Vector(0,1,0)

--Default color for the Victims weapon and skin
GM.Config.VictimsWeaponColor = Vector(0,0,1)


--Weapons the victims will spawn with
GM.Config.VictimWeapons = {
	"weapon_357",
	"weapon_fists"
}

--When You Press F1 this is the link that will open
GM.Config.HelpButtonLink = "http://steamcommunity.com/sharedfiles/filedetails/?id=495998201"