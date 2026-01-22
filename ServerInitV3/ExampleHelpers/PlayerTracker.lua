--[[
Not_Lowest
Delinquent Studios LLC

Example
local Webhook: Secret = HttpService:GetSecret("StaffTrackingWebhook")
local CompletedWebhook = Webhook:AddPrefix("https://webhook.lewisakura.moe/api/webhooks/")

local GroupId = 35144747

local function PlayerAdded(plr)
	local GroupRank = plr:GetRankInGroup(GroupId)
	if GroupRank < 49 then
		return
	end
	--// Tracker auto handles cleanup
	local Tracker = PlayerTracker.Track(plr,CompletedWebhook,true)
	-- Or, you can do this 
	local Tracker = PlayerTracker.Track(plr,CompletedWebhook,true,(60*60)) -- 1 hour auto end
	-- Or, you can do this 
	local Tracker = PlayerTracker.Track(plr,CompletedWebhook)
	Tracker:StartTracking()
	task.delay(60*60,function()
		Tracker:EndTracking(true) --// True = auto delete
	end)
end

]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local PlayerTracker = {}
PlayerTracker.__index = PlayerTracker

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


-- Cleanup
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
