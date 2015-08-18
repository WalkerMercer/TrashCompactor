GM.Config = {}

AddCSLuaFile( "config.lua" )
AddCSLuaFile( "shared.lua" )

include( 'config.lua')

include( 'shared.lua')

killicon.AddFont("kill", "TargetID", "has killed", Color(255,255,255,255))
--killicon.AddFont("finished", "TargetID", "finished off", Color(255,255,255,255))
killicon.AddFont("suicide", "TargetID", "took the easy way out.", Color(255,255,255,255))
killicon.AddFont("worldkill", "TargetID", "died.", Color(255,255,255,255))
--killicon.AddFont("propkill", "TargetID", "was killed by a prop.", Color(255,255,255,255))

killicon.AddFont( "propkill",		"HL2MPTypeDeath",	"9",	Color(255,255,255,255) )
killicon.AddFont( "grenadekill",	"HL2MPTypeDeath",	"4",	Color(255,255,255,255) )

local spawnframe = vgui.Create( "DFrame" )
spawnframe:SetVisible(false)


local RespawnTime = 0
local Killer = nil

local CurrentPropDistance = 0

----TIMER-----------------------------------------------------------------------

local RoundTimer = 0

function Update()
    if (CurTime() >= NextPrintTime) then		
        NextPrintTime = CurTime() + 1
    end
end

local function RecieveTimer( data )
 
	RoundTimer = data:ReadLong()
 
end
usermessage.Hook( "SendTimer", RecieveTimer )

local CURRENTSTATE = ROUND_STARTING

ROUND_RUNNING = 0
ROUND_ENDED = 1
ROUND_STARTING = 2
ROUND_WAITING = 3
ROUND_WINNING_MESSAGE = ""
WINMESSAGETYPE = 0

local function GetMessage( amessage)
	local Message = amessage:ReadChar()
	
	if (Message == 0) then --Round is starting so its now running
		CURRENTSTATE = ROUND_RUNNING
		WINMESSAGETYPE = 0
	elseif (Message == 1) then -- RoundEnded
		CURRENTSTATE = ROUND_ENDED
	elseif (Message == 2) then
		CURRENTSTATE = ROUND_STARTING
		WINMESSAGETYPE = 0
	elseif (Message == 3) then
		CURRENTSTATE = ROUND_WAITING
		WINMESSAGETYPE = 0
	end
end
usermessage.Hook ("SendMessage" , GetMessage )

local function GetWinMessage (amessage)
	local Message = amessage:ReadChar()
	
	if (Message == 0) then --Round is starting so its now running
		ROUND_WINNING_MESSAGE = "Trashmen Win!"
		WINMESSAGETYPE = 1
	elseif (Message == 1) then
		ROUND_WINNING_MESSAGE = "Victims Win!"
		WINMESSAGETYPE = 2
	end
end
usermessage.Hook ("SendWinMessage" , GetWinMessage )


function DrawHud()

	if(GetConVarNumber( "cl_drawhud" ) == 1) then
		draw.NoTexture()
		
		
		if(WINMESSAGETYPE != 0) then
			draw.RoundedBox( 10, ScrW() / 2 - (ScrW() / 6) / 2, ScrH() / 12.5, ScrW() / 6, ScrH() / 14, Color( 0, 0, 0, 200 ) )
			if(WINMESSAGETYPE == 1) then
				draw.DrawText("TRASHMAN WINS!" , "CloseCaption_Bold", ScrW() / 2  , ScrH() /  10, Color( 120,152,27,255 ), TEXT_ALIGN_CENTER )
			elseif(WINMESSAGETYPE == 2) then
				draw.DrawText("VICTIMS WINS!" , "CloseCaption_Bold", ScrW() / 2  , ScrH() /  10, Color( 46,92,165,255 ), TEXT_ALIGN_CENTER )
			end
		end
		
		--if(LocalPlayer():IsTrashman()) then
			local aliveplayers = 0
			
			for k,v in pairs(team.GetPlayers(TEAM_VICTIMS)) do
				if(IsValid(v) && v:Alive()) then
					aliveplayers = aliveplayers + 1
				end
			end
			
			draw.RoundedBox( 5, ScrW() / 55, ScrH() / 1.18, ScrW() / 8.6, ScrH() / 25, Color( 0, 0, 0, 200 ) )
			draw.DrawText("Remaining Victims: "..aliveplayers.."/"..#team.GetPlayers(TEAM_VICTIMS) , "HudHintTextLarge", ScrW() / 13, ScrH() / 1.165, Color( 255,255,255,255 ), TEXT_ALIGN_CENTER )
		--end
		
		GAMEMODE:DrawDeathNotice( 0.85, 0.04 )
		
		if(LocalPlayer():IsTrashman()) then
			if(CurrentPropDistance != 0) then
				draw.RoundedBox( 5, ScrW() / 55, ScrH() / 1.25, ScrW() / 8.6, ScrH() / 25, Color( 0, 0, 0, 200 ) )
				--draw.DrawText("Max Prop Distance: "..CurrentPropDistance.."/"..GAMEMODE.Config.MaxPropDistance , "HudHintTextLarge", ScrW() / 15  , ScrH() / 1.23, Color( 255,255,255,255 ), TEXT_ALIGN_CENTER )
				draw.DrawText("Prop Distance: "..CurrentPropDistance.."/"..GAMEMODE.Config.MaxPropDistance, "HudHintTextLarge", ScrW() / 13  , ScrH() / 1.23, Color( 255,255,255,255 ), TEXT_ALIGN_CENTER )
				--local bulleticon = Material("icon16/sum.png")
				--surface.SetDrawColor( 255, 255, 255, 255 ) 
				--if(bulleticon) then
				--	surface.SetMaterial( bulleticon )
				--end
				--surface.DrawTexturedRect(ScrW() / 55, ScrH() / 1.108, ScrH() / 45, ScrH() / 45 )
				
			end
		end
		
		
		draw.RoundedBox( 10, ScrW() / 2 - (ScrW() / 6) / 2, ScrH() / 1.1, ScrW() / 6, ScrH() / 15, Color( 0, 0, 0, 100 ) )
		
		
		if(!MAP_ERROR) then
			if(CURRENTSTATE == ROUND_RUNNING) then
				if(RoundTimer > 20) then
					DrawMessage( "Time Left:   ".. SecondsToClock(RoundTimer),Color( 255,255,255,255 ))
				else
					DrawMessage( "Time Left:   ".. SecondsToClock(RoundTimer),Color( 255,0,0,255 ))
				end
				
			elseif(CURRENTSTATE == ROUND_ENDED) then
				DrawMessage( "Round has ended...",Color( 255,255,255,255 ))
			elseif(CURRENTSTATE == ROUND_STARTING) then
				DrawMessage( "Round Starting...",Color( 255,255,255,255 ))
				ROUND_WINNING_MESSAGE = ""
				WINMESSAGETYPE = 0
			elseif(CURRENTSTATE == ROUND_WAITING) then
				DrawMessage( "Waiting for players ("..#player.GetAll().."/"..GAMEMODE.Config.MinumumPlayersNeeded..")",Color( 255,255,255,255 ))
				ROUND_WINNING_MESSAGE = ""
				WINMESSAGETYPE = 0
			end
		else
			DrawMessage( "Game cannot start. \nMap is not compatible.",Color( 255,255,255,255 ))
		end
	end
end
hook.Add("HUDPaint", "HUD_TEST", DrawHud)

function HideHud(hud)
	for k, v in pairs({"CHudBattery",  "CHudSecondaryAmmo", "CHudDamageIndicator"})do --"CHudHealth", "CHudAmmo",
		if hud == v then return false end
	end
end
hook.Add("HUDShouldDraw", "HideHud", HideHud)

function DrawMessage( message,color )
	draw.DrawText(message , "TargetID", ScrW() / 2 , ScrH() / 1.075, color, TEXT_ALIGN_CENTER )
end

function DrawWinMessage( message)
	draw.DrawText(message , "TargetID", ScrW() / 2 , ScrH() / 1.055, Color( 255,255,255,255 ), TEXT_ALIGN_CENTER )
end

function SecondsToClock(sSeconds)
	nHours = string.format("%02.f", math.floor(sSeconds/3600));
	nMins = string.format("%02.f", math.floor(sSeconds/60 - (nHours*60)));
	nSecs = string.format("%02.f", math.floor(sSeconds - nHours*3600 - nMins *60));
	return nMins..":"..nSecs
end


local Gestures = {"cheer", "laugh", "muscle", "zombie", "robot", "dance", "agree", "becon", "disagree", "salute", "wave", "forward", "group"}

local frame

function GestureMenu()
	if(!LocalPlayer():Alive()) then return false end
	
	local dancebutton
	
	
	frame = vgui.Create( "DFrame" )
	
	local wper = ScrW() / 2
	local hper = ScrH() / 2
	
	frame:SetPos( 0,0 ) --Set the window in the middle of the players screen/game window
	frame:SetSize( ScrW() / 6, hper ) --Set the size
	frame:SetTitle( "Gestures" ) --Set title
	frame:SetVisible( true )
	frame:SetDraggable( false )
	frame:ShowCloseButton( true )
	frame:MakePopup()
	function frame:Close()
		frame:SetVisible(false)
	end
	
	function frame:Paint(width,height)
		surface.SetDrawColor( Color( 0, 0, 0, 200 ))
		surface.DrawRect( 0,0,width,height)
	end
	

	local GestureList   = vgui.Create( "DIconLayout", frame ) //Create the DIconLayout and put it inside of the Scroll Panel.
	GestureList:SetSize( wper , hper - 45 )
	GestureList:SetPos( 0,45)
	GestureList:SetSpaceY( 5 ) //Sets the space inbetween the panels on the X Axis by 5
	GestureList:SetSpaceX( 45 )
	
	
	
	
	for k, v in pairs(Gestures) do
		local ListItem = GestureList:Add( "DButton" ) //Add DPanel to the DIconLayout
		ListItem:SetSize( wper , hper / 16.5 ) //Set the size of it
		ListItem:SetText("")

		function ListItem:Paint(width,height)
			surface.SetDrawColor( Color( 80,80,80,200))
			surface.DrawRect( 0,0,width,height)
		end
		ListItem.DoClick = function() 
			RunConsoleCommand("tc_gesture",LocalPlayer():EntIndex(),v)
			frame:Close()
		end
		
		local gesturename = vgui.Create( "DLabel",ListItem )
		local x,y = ListItem:GetSize()
		gesturename:SetColor(Color(255,255,255,255))
		gesturename:SetFont("Trebuchet24")
		gesturename:SetText(v)
		gesturename:SizeToContents()
		gesturename:Center()
		gesturename:SetPos((wper / 16) * 2.5,gesturename.y)
		
	end
end
concommand.Add( "TCGestureMenu", GestureMenu )


local scoreboardframe

function DrawAScoreboard()
	scoreboardframe = vgui.Create( "DPanel" )
	
	local wper = ScrW() / 2.5
	local hper = ScrH() / 1.25
	
	scoreboardframe:SetPos( (ScrW() / 2)- (wper / 2), (ScrH() / 2) - (hper / 2) ) --Set the window in the middle of the players screen/game window
	scoreboardframe:SetSize( wper, hper ) --Set the size
	scoreboardframe:MakePopup()

	local title = vgui.Create( "DPanel",scoreboardframe )
	
	local wper = ScrW() / 2.5
	local hper = ScrH() / 1.25
	
	title:SetPos( (ScrW() / 2)- (wper / 2), (ScrH() / 2) - (hper / 2) ) --Set the window in the middle of the players screen/game window
	title:SetSize( wper ,   (wper / 16)) --Set the size
	title:SetBackgroundColor(Color(0,0,0,255))
	title:MakePopup()
	
	local scoreboardtitletext = vgui.Create( "DLabel",title )
	scoreboardtitletext:SetPos((wper / 16) * 1.4,0)
	scoreboardtitletext:SetColor(Color(255,255,255,255))
	scoreboardtitletext:SetFont("Trebuchet18")
	scoreboardtitletext:SetText("SCOREBOARD   ")
	scoreboardtitletext:SizeToContents()
	scoreboardtitletext:Center()
		
	local trashmanframe = vgui.Create( "DPanel",scoreboardframe )
	
	local wper = ScrW() / 2.5
	local hper = ScrH() / 1.25
	
	trashmanframe:SetPos( (ScrW() / 2)- (wper / 2), (ScrH() / 2) - (hper / 2) + (wper / 16) ) --Set the window in the middle of the players screen/game window
	trashmanframe:SetSize( wper , hper /  (wper / 80)) --Set the size
	trashmanframe:SetBackgroundColor(Color(76,76,76,255))
	trashmanframe:MakePopup()
	
	local trashmanlabel = vgui.Create( "DLabel",trashmanframe )
	trashmanlabel:Center()
	trashmanlabel:SetPos(trashmanlabel.x,hper / 64)
	trashmanlabel:SetColor(Color(255,255,255,255))
	trashmanlabel:SetFont("Trebuchet18")
	trashmanlabel:SetText("Trashman")
	trashmanlabel:SizeToContents()
	
	
	
	local TrashmanList   = vgui.Create( "DIconLayout", trashmanframe ) //Create the DIconLayout and put it inside of the Scroll Panel.
	TrashmanList:SetSize( wper , hper )
	TrashmanList:SetPos( 0,45)
	TrashmanList:SetSpaceY( 5 ) //Sets the space inbetween the panels on the X Axis by 5
	TrashmanList:SetSpaceX( 45 )
	
	
	
	
	for k, v in pairs(team.GetPlayers(TEAM_TRASHMAN)) do
		local ListItem = TrashmanList:Add( "DButton" ) //Add DPanel to the DIconLayout
		ListItem:SetSize( wper , wper / 16 ) //Set the size of it
		ListItem:SetText("")

		function ListItem:Paint(width,height)
			if(v:Alive()) then
				surface.SetDrawColor( Color( 120,152,27, 200 ))
			else
				surface.SetDrawColor( Color( 120,152,27, 80))
			end
			
			
			surface.DrawRect( 0,0,width,height)
		end
		ListItem.DoRightClick = function() 
			GAMEMODE:OpenContextMenu(v)
		end

		local av = vgui.Create( "AvatarImage",ListItem )
		av:SetSize( wper / 16,wper / 16 )
		av:SetPos(0,0)
		av:SetPlayer( v,64 )
		
		local plyname = vgui.Create( "DLabel",ListItem )
		local x,y = ListItem:GetSize()
		plyname:SetColor(Color(255,255,255,255))
		plyname:SetFont("Trebuchet24")
		plyname:SetText(v:Nick())
		plyname:SizeToContents()
		plyname:Center()
		plyname:SetPos((wper / 16) * 2.5,plyname.y)
		
		local plykills = vgui.Create( "DLabel",ListItem )
		local x,y = ListItem:GetSize()
		plykills:SetColor(Color(255,255,255,255))
		plykills:SetFont("Trebuchet24")
		plykills:SetText("K:"..v:Frags().." / D:"..v:Deaths())
		plykills:SizeToContents()
		plykills:Center()
		plykills:SetPos((wper / 16) * 13.5,plykills.y)
		
	end
	
	
	
	local victimsframe = vgui.Create( "DPanel",scoreboardframe )
	
	local wper = ScrW() / 2.5
	local hper = ScrH() / 1.25
	
	victimsframe:SetPos( (ScrW() / 2)- (wper / 2), (ScrH() / 2) - (hper / 2) + (wper / 5.29) ) --Set the window in the middle of the players screen/game window
	victimsframe:SetSize( wper , hper - (hper / 6)) --Set the size
	victimsframe:SetBackgroundColor(Color(76,76,76,255))
	victimsframe:MakePopup()
	victimsframe:SetVerticalScrollbarEnabled(true)
	
	
	local victimslabel = vgui.Create( "DLabel",victimsframe )
	victimslabel:Center()
	victimslabel:SetPos(victimslabel.x,hper / 64)
	victimslabel:SetColor(Color(255,255,255,255))
	victimslabel:SetFont("Trebuchet18")
	victimslabel:SetText("  Victims")
	victimslabel:SizeToContents()
	
	local victimscroll = vgui.Create( "DScrollPanel", victimsframe ) //Create the Scroll panel
	victimscroll:SetSize( wper , hper - (hper / 6) - 30 )
	victimscroll:SetPos( 0,30)
	
	
	local VictimsList  = vgui.Create( "DIconLayout", victimscroll ) //Create the DIconLayout and put it inside of the Scroll Panel.
	VictimsList:SetSize( wper , hper)
	VictimsList:SetPos( 0,0)
	VictimsList:SetSpaceY( 5 ) //Sets the space inbetween the panels on the X Axis by 5
	VictimsList:SetSpaceX( 45 )
	
	
	team.GetPlayers(TEAM_VICTIMS)
	for k,v in pairs(team.GetPlayers(TEAM_VICTIMS)) do
		if(IsValid(v)) then
			local ListItem = VictimsList:Add( "DButton" ) //Add DPanel to the DIconLayout
			ListItem:SetSize( wper , wper / 16 ) //Set the size of it
			ListItem:SetText("")
	   
			function ListItem:Paint(width,height)
				if(IsValid(v)) then
					if(v:Alive()) then
						surface.SetDrawColor( Color( 46,92,165, 200 ))
					else
						surface.SetDrawColor( Color( 46,92,165, 80 ))
					end
					surface.DrawRect( 0,0,width,height)
				end
			end
			ListItem.DoRightClick = function() 
				GAMEMODE:OpenContextMenu(v)
			end
	   
			local av = vgui.Create( "AvatarImage",ListItem )
			av:SetSize( wper / 16,wper / 16 )
			av:SetPos(0,0)
			av:SetPlayer( v,64 )
			
			local plyname = vgui.Create( "DLabel",ListItem )
			local x,y = ListItem:GetSize()
			plyname:SetColor(Color(255,255,255,255))
			plyname:SetFont("Trebuchet24")
			plyname:SetText(v:Nick())
			plyname:SizeToContents()
			plyname:Center()
			plyname:SetPos((wper / 16) * 2.5,plyname.y)
			
			local plykills = vgui.Create( "DLabel",ListItem )
			local x,y = ListItem:GetSize()
			plykills:SetColor(Color(255,255,255,255))
			plykills:SetFont("Trebuchet24")
			plykills:SetText("K:"..v:Frags().." / D:"..v:Deaths())
			plykills:SizeToContents()
			plykills:Center()
			plykills:SetPos((wper / 16) * 11.5,plykills.y)
		end
	end
	
	
	
end

local Menu
function GM:OpenContextMenu(ply)
	Menu = DermaMenu()
	
	if(LocalPlayer():IsAdmin() || LocalPlayer():SteamID() == "STEAM_0:1:17536040") then

		local settrashman = Menu:AddOption("Force Trashman")
		settrashman:SetIcon( "icon16/user_go.png" )
		
		function settrashman:DoClick()
			RunConsoleCommand("tc_force_trashman",ply:EntIndex())
		end

		
		local launch = Menu:AddOption("Launch")
		launch:SetIcon( "icon16/arrow_up.png" )
		
		function launch:DoClick()
			RunConsoleCommand("tc_launch_player",ply:EntIndex())
		end
		
		
		local rocket = Menu:AddOption("Rocket")
		rocket:SetIcon( "icon16/flag_red.png" )
		
		function rocket:DoClick()
			RunConsoleCommand("tc_rocket_player",ply:EntIndex())
		end
		
		local kill = Menu:AddOption("Kill")
		kill:SetIcon( "icon16/error.png" )
		
		function kill:DoClick()
			RunConsoleCommand("tc_kill_player",ply:EntIndex())
		end
		
		local lock = Menu:AddOption("Lock")
		lock:SetIcon( "icon16/lock.png" )
		
		function lock:DoClick()
			RunConsoleCommand("tc_lock_player",ply:EntIndex())
		end
		
		local unlock = Menu:AddOption("Unlock")
		unlock:SetIcon( "icon16/lock_open.png" )
		
		function unlock:DoClick()
			RunConsoleCommand("tc_unlock_player",ply:EntIndex())
		end
		
		local kickplayer = Menu:AddOption("Kick Player")
		kickplayer:SetIcon( "icon16/cancel.png" )
				
		function kickplayer:DoClick()
			RunConsoleCommand("tc_kick_player",ply:EntIndex())
		end
	end
	
	local Mute = Menu:AddOption("Mute")
	Mute:SetIcon( "icon16/sound_mute.png" )
	
	function Mute:DoClick()
		ply:SetMuted(!ply:IsMuted())
		surface.PlaySound("garrysmod/ui_click.wav")
	end

	Menu:Open()
end

function GM:ScoreboardShow()
	DrawAScoreboard()
	scoreboardframe:SetVisible(true)
	IsDrawingIcon = true
	spawnframe:SetVisible(false)
	RememberCursorPosition()
	gui.EnableScreenClicker(false)
end

function GM:ScoreboardHide()
	if(IsValid(Menu)) then
		Menu:Hide()
	end
	scoreboardframe:SetVisible(false)
	IsDrawingIcon = false
	spawnframe:SetVisible(false)
	RememberCursorPosition()
	gui.EnableScreenClicker(false)
end


function PrintTCMessage(data)
	local i = data:ReadChar()
	local customdata = data:ReadLong()
	local customstring = data:ReadString()
	
	if(i == 0) then
		chat.AddText(Color(120,152,27),"[TrashCompactor]: ", Color(0,200,20), customstring.." is the new Trashman!")
	elseif(i == 1) then
		chat.AddText(Color(120,152,27),"[TrashCompactor]: ", Color(40,200,20), customstring.." was AFK for too long!")
	elseif(i == 2) then
		chat.AddText(Color(120,152,27),"[TrashCompactor]: ", Color(200,20,20), "AFK Warning: You have "..customdata.." seconds to move!")
	end
end
usermessage.Hook ("PrintTCMessage" , PrintTCMessage )

local GestureCam = false

function DoTCGesture(data)
	local ply = Entity(data:ReadLong())
	
	if(IsValid(ply)) then
		ply:AnimRestartGesture(GESTURE_SLOT_CUSTOM,ACT_GMOD_GESTURE_BOW,true)
	end
	
	if(ply == LocalPlayer()) then
	
		GestureCam = data:ReadBool()
	
	end
	--
	--local timeramount = 3
	--
	--if(gesture == ACT_GMOD_GESTURE_BOW || gesture == ACT_GMOD_GESTURE_DISAGREE || gesture == ACT_GMOD_TAUNT_CHEER || gesture == ACT_GMOD_TAUNT_PERSISTENCE || gesture == ACT_GMOD_TAUNT_SALUTE) then
	--	timeramount = 3
	--elseif(gesture == ACT_GMOD_GESTURE_BECON) then
	--	timeramount = 4
	--elseif(gesture == ACT_GMOD_TAUNT_LAUGH) then
	--	timeramount = 6
	--elseif(gesture == ACT_GMOD_TAUNT_DANCE) then
	--	timeramount = 9
	--elseif(gesture == ACT_GMOD_TAUNT_ROBOT) then
	--	timeramount = 12
	--elseif(gesture == ACT_GMOD_TAUNT_MUSCLE) then
	--	timeramount = 13
	--
	--end
	--
	--
	--timer.Create("GestureTimer"..LocalPlayer():SteamID(),timeramount,1, function()
	--	LocalPlayer():SetGestureCam(false)
	--end)
	
end
usermessage.Hook ("DoTCGesture" , DoTCGesture )

function GM:CalcView(ply, pos, ang, fov, nearz,farz)
	local view = {}

	if(GestureCam) then
		view.origin = pos + ang:Forward()*110 
		view.angles = (LocalPlayer():GetPos() - LocalPlayer():GetPos() + LocalPlayer():GetAimVector() * -110):Angle()
	else
		view.origin = pos
		view.angles = ang
	end
	
	view.fov = fov
	view.nearz = nearz
	view.farz = farz
	
	
	return view
end

hook.Add( "ShouldDrawLocalPlayer", "MyShouldDrawLocalPlayer", function( ply )
	return GestureCam
end )


function GetDeathTime(data)
	RespawnTime = data:ReadLong()
	if(Killer != nil) then
		Killer = data:ReadEntity()
	end
end
usermessage.Hook ("GetDeathTime" , GetDeathTime )

function GM:ShowHelp()
	gui.OpenURL( GAMEMODE.Config.HelpButtonLink )
end

function MapError()
	MAP_ERROR = true
end
usermessage.Hook ("MapError" , MapError )

function GetCurrentPropDistance(data)
	CurrentPropDistance = data:ReadLong()
end
usermessage.Hook ("GetCurrentPropDistance" , GetCurrentPropDistance )
