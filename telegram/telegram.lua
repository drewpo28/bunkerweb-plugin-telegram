local cjson = require("cjson")
local class = require("middleclass")
local http = require("resty.http")
local plugin = require("bunkerweb.plugin")
local utils = require("bunkerweb.utils")

local telegram = class("telegram", plugin)

local ngx = ngx
local ngx_req = ngx.req
local ERR = ngx.ERR
local WARN = ngx.WARN
local INFO = ngx.INFO
local NOTICE = ngx.NOTICE
local ngx_timer = ngx.timer
local HTTP_INTERNAL_SERVER_ERROR = ngx.HTTP_INTERNAL_SERVER_ERROR
local HTTP_TOO_MANY_REQUESTS = ngx.HTTP_TOO_MANY_REQUESTS
local HTTP_OK = ngx.HTTP_OK
local http_new = http.new
local has_variable = utils.has_variable
local get_variable = utils.get_variable
local get_reason = utils.get_reason
local tostring = tostring
local encode = cjson.encode

local char_to_hex = function(c)
  return string.format("%%%02X", string.byte(c))
end

local function urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub("`", "")
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w ])", char_to_hex)
  url = url:gsub(" ", "+")

  return url
end

local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end

local urldecode = function(url)
  if url == nil then
    return
  end
  url = url:gsub("+", " ")
  url = url:gsub("%%(%x%x)", hex_to_char)
  return url
end

local api_telegram_url = function(self, data)

  local apiurl_template = "https://api.telegram.org/{{bot_token}}/sendMessage?chat_id={{chat_id}}&text="
  local bot_token = self.variables["TELEGRAM_BOT_TOKEN"]
  local chat_id = self.variables["TELEGRAM_CHAT_ID"]

  return apiurl_template:gsub("{{bot_token}}", bot_token):gsub("{{chat_id}}", chat_id) .. urlencode(data)
end

function telegram:initialize(ctx)
	-- Call parent initialize
	plugin.initialize(self, "telegram", ctx)
end

function telegram:log(bypass_use_telegram)
	-- Check if telegram is enabled
	if not bypass_use_telegram then
		if self.variables["USE_TELEGRAM"] ~= "yes" then
			return self:ret(true, "telegram plugin not enabled")
		end
	end
	-- Check if request is denied
	local reason, reason_data = get_reason(self.ctx)
	if reason == nil then
		return self:ret(true, "request not denied")
	end
	-- Compute data
	local data = {}
	data.content = "```Denied request for IP "
		.. self.ctx.bw.remote_addr
		.. " (reason = "
		.. reason
		.. " / reason data = "
		.. encode(reason_data or {})
		.. ").\n\nRequest data :\n\n"
		.. ngx.var.request
		.. "\n"
	local headers, err = ngx_req.get_headers()
	if not headers then
		data.content = data.content .. "error while getting headers : " .. err
	else
		for header, value in pairs(headers) do
			data.content = data.content .. header .. ": " .. value .. "\n"
		end
	end
	data.content = data.content .. "```"
	-- Send request
	local hdr
	hdr, err = ngx_timer.at(0, self.send, self, data)
	if not hdr then
		return self:ret(true, "can't create report timer : " .. err)
	end
	return self:ret(true, "scheduled timer")
end

-- luacheck: ignore 212
function telegram.send(premature, self, data)
	self.logger:log(ERR, "Telegram Send call")

	local httpc, err = http_new()
	if not httpc then
		self.logger:log(ERR, "can't instantiate http object : " .. err)
	end

	local url = api_telegram_url(self, data.content)
	local res, err_http = httpc:request_uri(url, { method = "GET" })
	httpc:close()
	if not res then
		self.logger:log(ERR, "error while sending request : " .. err_http)
	end
	if res.status < 200 or res.status > 299 then
		self.logger:log(ERR, "request returned status " .. tostring(res.status))
		return
	end
	self.logger:log(INFO, "request sent to telegram")
end

function telegram:log_default()
	-- Check if telegram is activated
	local check, err = has_variable("USE_TELEGRAM", "yes")
	if check == nil then
		return self:ret(false, "error while checking variable USE_TELEGRAM (" .. err .. ")")
	end
	if not check then
		return self:ret(true, "telegram plugin not enabled")
	end
	-- Check if default server is disabled
	check, err = get_variable("DISABLE_DEFAULT_SERVER", false)
	if check == nil then
		return self:ret(false, "error while getting variable DISABLE_DEFAULT_SERVER (" .. err .. ")")
	end
	if check ~= "yes" then
		return self:ret(true, "default server not disabled")
	end
	-- Call log method
	return self:log(true)
end

function telegram:api()
	self.logger:log(ERR, "Telegram API call start")
	if self.ctx.bw.uri == "/telegram/ping" and self.ctx.bw.request_method == "POST" then

		self.logger:log(ERR, "Telegram API call method check passed")
		-- Check telegram connection
		local check, err = has_variable("USE_TELEGRAM", "yes")
		if check == nil then
			return self:ret(true, "error while checking variable USE_TELEGRAM (" .. err .. ")")
		end
		if not check then
			return self:ret(true, "telegram plugin not enabled")
		end

		-- Send test data to telegram
		local data = {
			content = "```Test message from bunkerweb```",
		}
		-- Send request
		local httpc
		httpc, err = http_new()
		if not httpc then
			self.logger:log(ERR, "can't instantiate http object : " .. err)
		end

		local url = api_telegram_url(self, data.content) 
		local res, err_http = httpc:request_uri(url, { method = "GET" })
		httpc:close()
		if not res then
			self.logger:log(ERR, "error while sending request : " .. err_http)
		end
		if res.status < 200 or res.status > 299 then
			return self:ret(true, "request returned status " .. tostring(res.status), HTTP_INTERNAL_SERVER_ERROR)
		end
		return self:ret(true, "request sent to telegram", HTTP_OK)
	end
	return self:ret(false, "success")
end

return telegram
