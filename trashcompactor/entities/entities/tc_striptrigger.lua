AddCSLuaFile();

ENT.PrintName       = "Trash Compactor Strip Trigger"
ENT.Author          = "VictimofScience"
ENT.Type            = "brush"
ENT.Base 			= "base_gmodentity"
ENT.Spawnable       = false
ENT.AdminSpawnable  = false

function ENT:Initialize()
	if (CLIENT) then return end
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetSolid( SOLID_BBOX )
	self:SetTrigger(true)
end

function ENT:SetupBounds(minv,maxv)
	self:SetCollisionBounds(minv,maxv)
end

function ENT:StartTouch(ent)
	if(ent:IsPlayer()) then
		if(ent:GetActiveWeapon():GetClass() == "weapon_physgun") then
			ent:SelectWeapon( "weapon_physcannon" )
		end
		ent:StripWeapon("weapon_physgun")
	end
end


