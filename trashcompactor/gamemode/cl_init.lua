GM.Config = {}



include( 'config.lua')
include( 'shared.lua')

killicon.AddFont("kill", "TargetID", "has killed", Color(255,255,255,255))
killicon.AddFont("suicide", "TargetID", "took the easy way out.", Color(255,255,255,255))
killicon.AddFont("worldkill", "TargetID", "died.", Color(255,255,255,255))

killicon.AddFont( "propkill",		"HL2MPTypeDeath",	"9",	Color(255,255,255,255) )
killicon.AddFont( "grenadekill",	"HL2MPTypeDeath",	"4",	Color(255,255,255,255) )

local CurrentPropDistance = 0

local TRASHMAN_QUEUE = {}

local IsInTrashmanQueue = false
local PlaceInQueue = -1

local BOUGHT_TRASHMAN = nil

local NumberOfFrozenObjects = 0

local UseTrashmanQueue = false

local ColorLerp = 0
local ClorCountingUp = true

function Fade( a, b, frac, alpha )
    local res, me
     res = Color( 0, 0, 0, alpha )
     me = ( 1 - frac )
    res.r = ( a.r * me ) + ( b.r * frac )
    res.g = ( a.g * me ) + ( b.g * frac )
    res.b = ( a.b * me ) + ( b.b * frac )
    return res
end

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
	
	if (Message == 0) then 
		CURRENTSTATE = ROUND_RUNNING
		WINMESSAGETYPE = 0
	elseif (Message == 1) then 
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
	
	if (Message == 0) then
		ROUND_WINNING_MESSAGE = "Trashmen Win!"
		WINMESSAGETYPE = 1
	elseif (Message == 1) then
		ROUND_WINNING_MESSAGE = "Victims Win!"
		WINMESSAGETYPE = 2
	end
end
usermessage.Hook ("SendWinMessage" , GetWinMessage )

function DrawHud()

	LocalPlayer():ConCommand("physgun_wheelspeed 10") -- not my favorite way of doing this but prevents prop killing 

	if(ClorCountingUp) then
		ColorLerp = ColorLerp + 0.001
		if(ColorLerp > 1) then
			ClorCountingUp = false
		end
	else
		ColorLerp = ColorLerp - 0.001
		if(ColorLerp < 0) then
			ClorCountingUp = true
		end
	end
	
	if(GetConVarNumber( "cl_drawhud" ) == 1) then
		draw.NoTexture()
		
		--Draws The Win Message
		if(WINMESSAGETYPE != 0) then
			draw.RoundedBox( 10, ScrW() / 2 - (ScrW() / 6) / 2, ScrH() / 12.5, ScrW() / 6, ScrH() / 14, Color( 0, 0, 0, 200 ) )
			if(WINMESSAGETYPE == 1) then
				draw.DrawText("TRASHMAN WINS!" , "CloseCaption_Bold", ScrW() / 2  , ScrH() /  10, GAMEMODE.Config.TrashmanColor, TEXT_ALIGN_CENTER )
			elseif(WINMESSAGETYPE == 2) then
				draw.DrawText("VICTIMS WINS!" , "CloseCaption_Bold", ScrW() / 2  , ScrH() /  10, GAMEMODE.Config.VictimsColor, TEXT_ALIGN_CENTER )
			end
		end
		
		--Draws Notice about Trashman Queue
		if(UseTrashmanQueue) then
			CheckTrashmanQueue()
			if(PlaceInQueue != -1) then
				draw.RoundedBox( 5, ScrW() / 2 - (ScrW() /6) / 2, ScrH() / 1.18, ScrW() / 6, ScrH() / 17, Color( 0, 0, 0, 200 ) )
				draw.DrawText("Your place in the Queue: "..PlaceInQueue , "HudHintTextLarge", ScrW() / 2, ScrH() / 1.15, Color( 255,255,255,255 ), TEXT_ALIGN_CENTER )
			else
				draw.RoundedBox( 5, ScrW() / 2 - (ScrW() /6) / 2, ScrH() / 1.18, ScrW() / 6, ScrH() / 17, Color( 0, 0, 0, 200 ) )
				draw.DrawText("  You are not in the Trashman Queue. \n Open the Scoreboard or type !queue \n to add yourself." , "HudHintTextLarge", ScrW() / 2, ScrH() / 1.175, Fade(Color(255,255,255,255),GAMEMODE.Config.TrashmanColor,ColorLerp,255), TEXT_ALIGN_CENTER )
			end
		end
		
		--Draws Amount of Frozen Objects
		if(LocalPlayer():IsTrashman()) then
			draw.RoundedBox( 5, ScrW() / 2 - (ScrW() /6) / 2, ScrH() / 1.22, ScrW() / 6, ScrH() / 43, Color( 0, 0, 0, 200 ) )
			draw.DrawText("Frozen Objects: "..NumberOfFrozenObjects.."/"..GetConVarNumber("tc_maxfreeze"), "HudHintTextLarge", ScrW() / 2, ScrH() / 1.215, Color( 255,255,255,255 ), TEXT_ALIGN_CENTER )
		end
		
		--Draws Info for Spectators
		if(LocalPlayer():Team() == TEAM_SPECTATOR || ((LocalPlayer():Team() == TEAM_VICTIMS || LocalPlayer():Team() == TEAM_TRASHMAN) && !LocalPlayer():Alive())) then
			draw.RoundedBox( 5, ScrW() / 2 - (ScrW() /6) / 2, ScrH() / 45, ScrW() / 6, ScrH() / 43, Color( 0, 0, 0, 200 ) )
			draw.DrawText("You will spawn next round.", "HudHintTextLarge", ScrW() / 2, ScrH() / 39, Color( 255,255,255,255 ), TEXT_ALIGN_CENTER )
		end
		
		--Draws Remaining Victims number
		local aliveplayers = 0
		for k,v in pairs(team.GetPlayers(TEAM_VICTIMS)) do
			if(IsValid(v) && v:Alive()) then
				aliveplayers = aliveplayers + 1
			end
		end
		draw.RoundedBox( 5, ScrW() / 55, ScrH() / 1.18, ScrW() / 8.6, ScrH() / 25, Color( 0, 0, 0, 200 ) )
		draw.DrawText("Remaining Victims: "..aliveplayers.."/"..#team.GetPlayers(TEAM_VICTIMS) , "HudHintTextLarge", ScrW() / 13, ScrH() / 1.165, Color( 255,255,255,255 ), TEXT_ALIGN_CENTER )

		--Draws Death Notices
		GAMEMODE:DrawDeathNotice( 0.85, 0.04 )
		
		--Draws the Current Prop Distance if youre the Trashman
		if(LocalPlayer():IsTrashman()) then
			if(CurrentPropDistance != 0) then
				draw.RoundedBox( 5, ScrW() / 55, ScrH() / 1.25, ScrW() / 8.6, ScrH() / 25, Color( 0, 0, 0, 200 ) )
				draw.DrawText("Prop Distance: "..CurrentPropDistance.."/"..GetConVarNumber("tc_maxpropdistance"), "HudHintTextLarge", ScrW() / 13  , ScrH() / 1.23, Color( 255,255,255,255 ), TEXT_ALIGN_CENTER )
			end
		end
		
		
		--Draws The Round Timer
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

--Hides Parts of the Hud
function HideHud(hud)
	for k, v in pairs({"CHudBattery",  "CHudSecondaryAmmo", "CHudDamageIndicator"})do --"CHudHealth", "CHudAmmo",
		if hud == v then return false end
	end
end
hook.Add("HUDShouldDraw", "HideHud", HideHud)

--Used for Drawing Round Info
function DrawMessage( message,color )
	draw.DrawText(message , "TargetID", ScrW() / 2 , ScrH() / 1.075, color, TEXT_ALIGN_CENTER )
end

--Used for Drawing Team Winner
function DrawWinMessage( message)
	draw.DrawText(message , "TargetID", ScrW() / 2 , ScrH() / 1.055, Color( 255,255,255,255 ), TEXT_ALIGN_CENTER )
end

--Converts Seconds To Clock
function SecondsToClock(sSeconds)
	nHours = string.format("%02.f", math.floor(sSeconds/3600));
	nMins = string.format("%02.f", math.floor(sSeconds/60 - (nHours*60)));
	nSecs = string.format("%02.f", math.floor(sSeconds - nHours*3600 - nMins *60));
	return nMins..":"..nSecs
end

--Gestures we can perform by using F4
local Gestures = {"bow","cheer", "laugh", "muscle", "zombie", "robot", "dance", "agree", "becon", "disagree", "salute", "wave", "forward", "group", "glide"}

--Gestures
local frame
function GestureMenu()
	if(!LocalPlayer():Alive()) then return false end

	frame = vgui.Create( "DFrame" )
	
	local wper = ScrW() / 2
	local hper = ScrH() / 2
	
	frame:SetPos( 0,0 )
	frame:SetSize( ScrW() / 6, hper ) 
	frame:SetTitle( "Gestures" )
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
	
	local framescroll = vgui.Create( "DScrollPanel", frame )
	framescroll:SetSize( wper  , hper - 30 )
	framescroll:SetPos( 0,30)
	
	local GestureList   = vgui.Create( "DIconLayout", framescroll )
	GestureList:SetSize( wper , hper )
	GestureList:SetPos( 0,30)
	GestureList:SetSpaceY( 5 )
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
			LocalPlayer():ConCommand("act "..v)
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


--Scoreboard Drawing
local scoreboardframe
local queueframe
			
function DrawAScoreboard() --Not Commenting this cause its a clusterfuck of a mess

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
	
	local serverinfo = vgui.Create( "DLabel",title )
	serverinfo:SetColor(Color(255,255,255,255))
	serverinfo:SetFont("Trebuchet18")
	local serverstringtouse = GetHostName()
	
	serverinfo:SetText(serverstringtouse)
	serverinfo:SizeToContents()
	serverinfo:Center()
	serverinfo:SetPos((wper / 45),serverinfo.y)
	
	local playeramntinfo = vgui.Create( "DLabel",title )
	playeramntinfo:SetColor(Color(255,255,255,255))
	playeramntinfo:SetFont("Trebuchet18")
	playeramntinfo:SetText("Players: "..#player.GetAll().."/"..game.MaxPlayers())
	playeramntinfo:SizeToContents()
	playeramntinfo:Center()
	playeramntinfo:SetPos((wper / 1.15),serverinfo.y)
	
	
	
	local trashmanframe = vgui.Create( "DPanel",scoreboardframe )
	
	local wper = ScrW() / 2.5
	local hper = ScrH() / 1.25
	
	trashmanframe:SetPos( (ScrW() / 2)- (wper / 2), (ScrH() / 2) - (hper / 2) + (wper / 16) ) --Set the window in the middle of the players screen/game window
	trashmanframe:SetSize( wper , hper / 8.9) --Set the size
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
	TrashmanList:SetPos( 0,30)
	TrashmanList:SetSpaceY( 5 ) //Sets the space inbetween the panels on the X Axis by 5
	TrashmanList:SetSpaceX( 45 )

	
	for k, v in pairs(team.GetPlayers(TEAM_TRASHMAN)) do
		local ListItem = TrashmanList:Add( "DButton" ) //Add DPanel to the DIconLayout
		ListItem:SetSize( wper , wper / 16 ) //Set the size of it
		ListItem:SetText("")

		function ListItem:Paint(width,height)
			local color = GAMEMODE.Config.TrashmanColor
			if(v:Alive()) then
				surface.SetDrawColor( Color( color.r,color.g,color.b, 200 ))
			else
				surface.SetDrawColor( Color( color.r,color.g,color.b, 80))
			end
			
			
			surface.DrawRect( 0,0,width,height)
		end
		ListItem.DoRightClick = function() 
			GAMEMODE:OpenContextMenu(v)
		end
		
		ListItem.DoClick = function()
			v:ShowProfile()
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
		plykills:SetText("K:"..v:Frags().." / D:"..v:Deaths().."  Ping: "..v:Ping())
		plykills:SizeToContents()
		plykills:Center()
		plykills:SetPos((wper / 16) * 10.4,plykills.y)
		
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
					local color = GAMEMODE.Config.VictimsColor
					if(v:Alive()) then
						surface.SetDrawColor( Color( color.r,color.g,color.b, 200 ))
					else
						surface.SetDrawColor( Color( color.r,color.g,color.b, 80))
					end
					surface.DrawRect( 0,0,width,height)
				end
			end
			ListItem.DoRightClick = function() 
				GAMEMODE:OpenContextMenu(v)
			end
			
			ListItem.DoClick = function()
				v:ShowProfile()
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
			plykills:SetText("K:"..v:Frags().." / D:"..v:Deaths().."  Ping: "..v:Ping())
			plykills:SizeToContents()
			plykills:Center()
			plykills:SetPos((wper / 16) * 10.4,plykills.y)
		end
	end	
end

function DrawTheQueue()

	queueframe = vgui.Create( "DPanel" )
	
	local wper = ScrW() / 2.5
	local hper = ScrH() / 1.25
	
	--Mostly For Screen Scaling. Wont work in 4:3 Aspect
	queueframe:SetPos( (ScrW() / 1.3)- (wper / 6), (ScrH() / 2) - (hper / 2) ) 
	queueframe:SetSize( wper / 3, hper ) 
	queueframe:MakePopup()

	local queuetitle = vgui.Create( "DPanel",queueframe )
	
	queuetitle:SetPos( queueframe:GetPos() ) 
	queuetitle:SetSize( wper / 3 ,   (wper / 16)) 
	queuetitle:SetBackgroundColor(GAMEMODE.Config.TrashmanColor)
	queuetitle:MakePopup()

	
	local queuetitletext = vgui.Create( "DLabel",queuetitle )
	queuetitletext:SetPos((wper / 16) * 1.4,0)
	queuetitletext:SetColor(Color(255,255,255,255))
	queuetitletext:SetFont("Trebuchet18")
	queuetitletext:SetText("Trashman Queue                     ") --Best Spacing
	queuetitletext:SizeToContents()
	queuetitletext:Center()
	
	
	local plusbutton = vgui.Create( "DButton" )
	plusbutton:SetParent(queuetitle)
	plusbutton:SetPos(queuetitle:GetWide() / 1.35,queuetitle:GetTall() / 4.5)
	plusbutton:SetSize(20,20 ) //Set the size of it
	plusbutton:SetText("")
    plusbutton:SetTooltip("Add Yourself to the Queue.")
	
	plusbutton:SetImage("icon16/user_add.png")
	
	function plusbutton:Paint(width,height)
		
	end
	
	plusbutton.DoClick = function() 	
		RunConsoleCommand("tc_add_to_trashman_queue",LocalPlayer():EntIndex())
	end
		
	
	local minusbutton = vgui.Create( "DButton" )
	minusbutton:SetParent(queuetitle)
	minusbutton:SetPos(queuetitle:GetWide() / 1.15,queuetitle:GetTall() / 4.5)
	minusbutton:SetSize(20,20 ) //Set the size of it
	minusbutton:SetText("")
    minusbutton:SetTooltip("Remove Yourself from the Queue.")
	
	minusbutton:SetImage("icon16/user_delete.png")
	
	function minusbutton:Paint(width,height)
		
	end
	
	minusbutton.DoClick = function() 
		RunConsoleCommand("tc_remove_from_trashman_queue",LocalPlayer():EntIndex())
	end
	
	
	
	local queuelistframe = vgui.Create( "DPanel",queueframe )
	
	
	queuelistframe:SetPos( (ScrW() / 1.3)- (wper / 6) ,(wper / 16) * 3.3) 
	queuelistframe:SetSize( wper / 3, hper -  (wper / 16)) 
	queuelistframe:MakePopup()
		
	local queuescroll = vgui.Create( "DScrollPanel", queuelistframe ) 
	queuescroll:SetSize( wper / 3 , hper - 45 ) 
	queuescroll:SetPos( 0,0)
	
	local queuelist = vgui.Create( "DIconLayout", queuescroll ) 
	queuelist:SetSize( wper / 3 , hper )
	queuelist:SetPos( 0,0)
	queuelist:SetSpaceY( 5 ) 
	queuelist:SetSpaceX( 45 )
	
	
	local i = 1
	for k,v in pairs(TRASHMAN_QUEUE) do
		if(IsValid(v)) then
			local ListItem = queuelist:Add( "DButton" ) //Add DPanel to the DIconLayout
			ListItem:SetSize( wper / 3 , wper / 16 ) //Set the size of it
			ListItem:SetText("")
		
			function ListItem:Paint(width,height)
				surface.SetDrawColor( Color( 40,40,40, 200))
				surface.DrawRect( 0,0,width,height)
			end
			
		
			local av = vgui.Create( "AvatarImage",ListItem )
			av:SetSize( wper / 16,wper / 16 )
			av:SetPos(0,0)
			av:SetPlayer( v,64 )
			
			local plyname = vgui.Create( "DLabel",ListItem )
			local x,y = ListItem:GetSize()
			plyname:SetColor(Color(255,255,255,255))
			plyname:SetFont("Trebuchet18")
			plyname:SetText(i.."  "..v:Nick())
			plyname:SizeToContents()
			plyname:Center()
			plyname:SetPos((wper / 16) * 1.3 ,plyname.y)
			
			plyname.DoRightClick = function() 
		
			end
			
			plyname.DoClick = function() 
		
			end
			
			if(LocalPlayer():IsAdmin()) then
				local plyminusbutton = vgui.Create( "DButton" ) //Add DPanel to the DIconLayout
				plyminusbutton:SetParent(ListItem)
				plyminusbutton:SetPos(ListItem:GetWide() / 1.2,ListItem:GetTall() / 6)
				plyminusbutton:SetSize(20,20 ) //Set the size of it
				plyminusbutton:SetText("")
				plyminusbutton:SetTooltip("Remove player from the Queue.")
				
				plyminusbutton:SetImage("icon16/user_delete.png")
				
				function plyminusbutton:Paint(width,height)
					
				end
				
				plyminusbutton.DoClick = function() 
					RunConsoleCommand("tc_remove_from_trashman_queue",v:EntIndex())
				end
			end
			
			i = i + 1
		end
	end
end

--Context Menu from right clicking players in the scoreboard
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
		
		if(ply:IsTrashman()) then
			local unfreeze = Menu:AddOption("Unfreeze All Props")
			unfreeze:SetIcon( "icon16/package_delete.png" )
			
			function unfreeze:DoClick()
				RunConsoleCommand("tc_force_drop_all_props",ply:EntIndex())
			end
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
		if(IsValid(ply)) then
			ply:SetMuted(!ply:IsMuted())
			surface.PlaySound("garrysmod/ui_click.wav")
		end
	end

	Menu:Open()
end

--Opening the Scoreboard
function GM:ScoreboardShow()
	DrawAScoreboard()
	if(UseTrashmanQueue) then DrawTheQueue() end
	scoreboardframe:SetVisible(true)
	if(UseTrashmanQueue) then queueframe:SetVisible(true) end
	RememberCursorPosition()
	gui.EnableScreenClicker(false)	
end

--Closing the Scoreboard
function GM:ScoreboardHide()
	if(IsValid(Menu)) then
		Menu:Hide()
	end
	if(IsValid(scoreboardframe)) then scoreboardframe:SetVisible(false) end
	if(IsValid(queueframe)) then queueframe:SetVisible(false) end
	RememberCursorPosition()
	gui.EnableScreenClicker(false)
end

--Prints Chat Messages
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
	elseif(i == 3) then
		chat.AddText(Color(120,152,27),"[TrashCompactor]: ", Color(58,191,184), "You have added yourself to the queue.")
	elseif(i == 4) then
		chat.AddText(Color(120,152,27),"[TrashCompactor]: ", Color(58,191,184), "You have removed yourself from the queue.")
	elseif(i == 5) then
		chat.AddText(Color(120,152,27),"[TrashCompactor]: ", Color(209,0,39), "ERROR: ", Color(58,191,184), "Player is already in the queue.")
	elseif(i == 6) then
		chat.AddText(Color(120,152,27),"[TrashCompactor]: ", Color(58,191,184), "You will become the Trashman next round.")
	end
end
usermessage.Hook ("PrintTCMessage" , PrintTCMessage )

--Is 3rd Person Cam?
local GestureCam = false
function DoTCGesture(data)
	GestureCam = data:ReadBool()
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

--Drawing ourself only if we are in a gesture
hook.Add( "ShouldDrawLocalPlayer", "MyShouldDrawLocalPlayer", function( ply )
	return GestureCam
end )

--Getting The Trashman Queue
net.Receive( "TrashmanQueue", function( len )
	UseTrashmanQueue = net.ReadBool()
	BOUGHT_TRASHMAN = net.ReadEntity()
	local tbl = net.ReadTable()
	TRASHMAN_QUEUE = tbl
end )

net.Receive( "FrozenPropsAmount", function( len )
	NumberOfFrozenObjects = net.ReadInt(32)
end )

function GetDeathTime(data)
	RespawnTime = data:ReadLong()
	if(Killer != nil) then
		Killer = data:ReadEntity()
	end
end
usermessage.Hook ("GetDeathTime" , GetDeathTime )

--Gets our position in the Trashman Queue
function CheckTrashmanQueue()
	for k,v in pairs(TRASHMAN_QUEUE) do
		if(IsValid(v) && v == LocalPlayer()) then
			PlaceInQueue = k
			return
		end
	end
	PlaceInQueue = -1
end

function GM:GetBoughtTrashman()
	return BOUGHT_TRASHMAN
end

function GM:ShowHelp()
	gui.OpenURL( GAMEMODE.Config.HelpButtonLink )
end

--Unused
function MapError()
	MAP_ERROR = true
end
usermessage.Hook ("MapError" , MapError )

function GetCurrentPropDistance(data)
	CurrentPropDistance = data:ReadLong()
end
usermessage.Hook ("GetCurrentPropDistance" , GetCurrentPropDistance )
