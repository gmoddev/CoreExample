--[[
	Not_Lowest
	PlayerTracker
	Delinquent Studios LLC

	────────────────────────────────────────────────────────────
	Overview
	────────────────────────────────────────────────────────────
	PlayerTracker tracks a single player's session and sends a
	Discord webhook embed when tracking ends.

	It records:
	• Username
	• UserId
	• Server JobId
	• Join time (UTC)
	• Leave time (UTC)
	• Total session duration (HH:MM:SS)
	• Studio status

	Tracking automatically ends when:
	• The player leaves the server
	• The player instance is destroyed
	• A timed auto-end expires (optional)
	• EndTracking() is called manually

	────────────────────────────────────────────────────────────
	Constructor
	────────────────────────────────────────────────────────────
	PlayerTracker.Track(
		Player: Player,
		WebhookUrl: string,
		AutoStart: boolean?,     -- Optional
		EndTime: number?         -- Optional (seconds until auto-end)
	)

	Returns: PlayerTracker instance

	Parameters:
	• Player      → Player to track
	• WebhookUrl  → Fully constructed Discord webhook URL
	• AutoStart   → If true, tracking begins immediately
	• EndTime     → If provided with AutoStart, auto-ends after X seconds

	────────────────────────────────────────────────────────────
	Basic Usage
	────────────────────────────────────────────────────────────

	local Webhook: Secret = HttpService:GetSecret("StaffTrackingWebhook")
	local CompletedWebhook = Webhook:AddPrefix("https://yourdomain.com/api/webhooks/")
	local GroupId = 35144747

	local function PlayerAdded(Player)
		local GroupRank = Player:GetRankInGroup(GroupId)
		if GroupRank < 49 then
			return
		end

		-- Auto start, auto cleanup on leave
		PlayerTracker.Track(Player, CompletedWebhook, true)

		-- Auto start, auto end after 1 hour
		PlayerTracker.Track(Player, CompletedWebhook, true, 60 * 60)

		-- Manual control example
		local Tracker = PlayerTracker.Track(Player, CompletedWebhook)
		Tracker:StartTracking()

		task.delay(60 * 60, function()
			Tracker:EndTracking(true) -- true = destroy after send
		end)
	end

	────────────────────────────────────────────────────────────
	Advanced Customization
	────────────────────────────────────────────────────────────

	Tracker:SetTitle("Custom Session End Title")
	Tracker:SetColor(Color3.fromRGB(255, 0, 0))
	Tracker:SetWebhook(NewWebhookUrl)

	────────────────────────────────────────────────────────────
	Important Notes
	────────────────────────────────────────────────────────────
	• This module tracks ONE player per instance.
	• Destroy() should be called if you manually manage lifecycle.
	• Webhook requests are sent asynchronously (non-blocking).
	• Errors during HTTP requests are silently protected via pcall.
	• Safe to use in live servers and Studio.

	────────────────────────────────────────────────────────────
	Recommended Use Case
	────────────────────────────────────────────────────────────
	Staff session logging, moderator tracking, analytics logging,
	compliance monitoring, or any session-based auditing system.
]]


local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerTracker = {}
PlayerTracker.__index = PlayerTracker

local IsStudio = RunService:IsStudio()

local function FormatUnixTime(UnixTime: number)
	return os.date("!%Y-%m-%d %H:%M:%S UTC", UnixTime)
end

local function FormatDuration(Seconds: number)
	local Hours = math.floor(Seconds / 3600)
	local Minutes = math.floor((Seconds % 3600) / 60)
	local Secs = Seconds % 60
	return string.format("%02d:%02d:%02d", Hours, Minutes, Secs)
end


function PlayerTracker.Track(Player: Player, WebhookUrl: string, AutoStart: boolean?, EndTime: number?)
	assert(Player and Player:IsA("Player"), "Invalid player")
	assert(WebhookUrl ~= nil, "Webhook required")

	local self = setmetatable({}, PlayerTracker)

	self.Player = Player
	self.Webhook = WebhookUrl
	self.JobId = game.JobId

	self.JoinTime = os.time()
	self.LeaveTime = nil

	self.IsTracking = false
	self._Ended = false
	self._Destroyed = false

	self.Color = 0x2ECC71
	self.Title = "Player Session Ended"

	self._Connections = {}

	if AutoStart then
		self:StartTracking()

		if EndTime then
			task.delay(EndTime, function()
				if not self._Ended and not self._Destroyed then
					self:EndTracking(true)
				end
			end)
		end
	end

	return self
end

function PlayerTracker:StartTracking()
	if self.IsTracking or self._Destroyed then return end
	self.IsTracking = true

	self._Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(Player)
		if Player == self.Player then
			self:EndTracking(true)
		end
	end)

	self._Connections.PlayerDestroying = self.Player.Destroying:Connect(function()
		self:EndTracking(true)
	end)
	
	return self
end

function PlayerTracker:EndTracking(DestroyAfter: boolean?)
	if self._Ended or self._Destroyed then return end
	self._Ended = true
	self.IsTracking = false

	self.LeaveTime = os.time()
	self:_Send()

	if DestroyAfter then
		task.defer(function()
			self:Destroy()
		end)
		return nil
	end
	
	return self
end

function PlayerTracker:SetWebhook(NewWebhook: string)
	if self._Destroyed then return nil end
	self.Webhook = NewWebhook
	
	return self
end

function PlayerTracker:_Send()
	if self._Destroyed or not self.Webhook or not self.Player then return end

	local DurationSeconds = math.max(0, self.LeaveTime - self.JoinTime)

	local Payload = {
		embeds = {
			{
				title = self.Title,
				color = self.Color,
				fields = {
					{ name = "Username", value = self.Player.Name, inline = true },
					{ name = "UserId", value = tostring(self.Player.UserId), inline = true },
					{ name = "JobId", value = self.JobId, inline = false },
					{ name = "Joined At", value = FormatUnixTime(self.JoinTime), inline = true },
					{ name = "Left At", value = FormatUnixTime(self.LeaveTime), inline = true },
					{ name = "Total Time", value = FormatDuration(DurationSeconds), inline = false },
					{ name = "IsStudio", value = tostring(IsStudio) == "true" and "Yes" or "No", inline = true}
				},
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", self.LeaveTime),
			}
		}
	}

	task.spawn(function()
		pcall(function()
			HttpService:PostAsync(
				self.Webhook,
				HttpService:JSONEncode(Payload),
				Enum.HttpContentType.ApplicationJson
			)
		end)
	end)
	return self
end

function PlayerTracker:SetTitle(string: string)
	if not string or typeof(string) ~= "string" then return end
	self.Title = string
	return self
end

function PlayerTracker:SetColor(Color: Color3)
	if typeof(Color) ~= "Color3" then return self end

	self.Color =
		math.floor(Color.R * 255) * 65536 +
		math.floor(Color.G * 255) * 256 +
		math.floor(Color.B * 255)

	return self
end

function PlayerTracker:Destroy()
	if self._Destroyed then return end
	self._Destroyed = true

	for _, Connection in pairs(self._Connections) do
		if Connection then
			Connection:Disconnect()
		end
	end

	table.clear(self._Connections)

	self.Player = nil
	self.Webhook = nil
	self.JoinTime = nil
	self.LeaveTime = nil
end

return PlayerTracker
