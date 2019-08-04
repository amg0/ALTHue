-- // This program is free software: you can redistribute it and/or modify
-- // it under the condition that it is for private or home useage and
-- // this whole comment is reproduced in the source code file.
-- // Commercial utilisation is not authorized without the appropriate
-- // written agreement from amg0 / alexis . mermet @ gmail . com
-- // This program is distributed in the hope that it will be useful,
-- // but WITHOUT ANY WARRANTY; without even the implied warranty of
-- // MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE .
local MSG_CLASS		= "ALTHUE"
local ALTHUE_SERVICE	= "urn:upnp-org:serviceId:althue1"
local devicetype	= "urn:schemas-upnp-org:device:althue:1"
-- local this_device	= nil
local DEBUG_MODE	= false -- controlled by UPNP action
local version		= "v1.45b"
local JSON_FILE = "D_ALTHUE.json"
local UI7_JSON_FILE = "D_ALTHUE_UI7.json"
local DEFAULT_REFRESH = 10
local NAME_PREFIX	= "Hue "	-- trailing space needed
local RAND_DELAY = 10
local hostname		= ""
local MapUID2Index={}
local LightTypes = {
	-- ["Extended color light"] = 		{  dtype="urn:schemas-upnp-org:device:DimmableRGBLight:1" , dfile="D_DimmableALTHue1.xml" }, -- UI5 requires this
	["Extended color light"] = 		{  dtype="urn:schemas-upnp-org:device:DimmableRGBLight:1" , dfile="D_DimmableRGBALTHue1.xml" }, 
	["Color light"] = 				{  dtype="urn:schemas-upnp-org:device:DimmableRGBLight:1" , dfile="D_DimmableRGBALTHue1.xml" }, 
	["Color temperature light"] = 	{  dtype="urn:schemas-upnp-org:device:DimmableLight:1" , dfile="D_DimmableALTHue1.xml" },
	["Dimmable light"] = 			{  dtype="urn:schemas-upnp-org:device:DimmableLight:1" , dfile="D_DimmableALTHue1.xml" },

	-- proposal from cybrmage for other devices
	["On/Off light"] =              {  dtype="urn:schemas-upnp-org:device:BinaryLight:1" , dfile="D_BinaryLight1.xml" },
	["Color dimmable light"] =		{  dtype="urn:schemas-upnp-org:device:DimmableRGBLight:1" , dfile="D_DimmableRGBALTHue1.xml" },

	-- OSRAM On Off Plug
	["On/Off plug-in unit"] =		{  dtype="urn:schemas-upnp-org:device:BinaryLight:1" , dfile="D_BinaryLight1.xml" },
	
	-- default
	["Default"] = 					{  dtype="urn:schemas-upnp-org:device:DimmableLight:1" , dfile="D_DimmableALTHue1.xml" }
}
local SensorTypes = {
	["ZLLTemperature"] = 	{  dtype="urn:schemas-micasaverde-com:device:TemperatureSensor:1" , dfile="D_TemperatureSensor1.xml" , vartable={"urn:upnp-org:serviceId:TemperatureSensor1,CurrentTemperature=0"} },
	["ZLLPresence"] = 		{  dtype="urn:schemas-micasaverde-com:device:MotionSensor:1" , dfile="D_MotionSensor1.xml" , vartable={"urn:micasaverde-com:serviceId:SecuritySensor1,Tripped=0"} },
	["ZLLLightLevel"] = 	{  dtype="urn:schemas-micasaverde-com:device:LightSensor:1" , dfile="D_LightSensor1.xml" , vartable={"urn:micasaverde-com:serviceId:LightSensor1,CurrentLevel=0"} },
	["ZLLSwitch"] = 		{  dtype="urn:schemas-micasaverde-com:device:SceneController:1" , dfile="D_SceneController1.xml" , vartable={
		"urn:micasaverde-com:serviceId:SceneController1,sl_SceneActivated=",
		"urn:micasaverde-com:serviceId:SceneController1,LastSceneID=",
		"urn:micasaverde-com:serviceId:SceneController1,LastSceneTime="
	}}
}

local json = require("dkjson")
local mime = require('mime')
local socket = require("socket")
local modurl = require ("socket.url")
local http = require("socket.http")
local ltn12 = require("ltn12")

------------------------------------------------
-- Debug --
------------------------------------------------
function log(text, level)
  luup.log(string.format("%s: %s", MSG_CLASS, text), (level or 50))
end

function debug(text)
  if (DEBUG_MODE) then
	log("debug: " .. text)
  end
end

function warning(stuff)
  log("warning: " .. stuff, 2)
end

function error(stuff)
  log("error: " .. stuff, 1)
end

local function isempty(s)
  return s == nil or s == ""
end

------------------------------------------------
-- VERA Device Utils
------------------------------------------------
-- local function findTHISDevice()
  -- for k,v in pairs(luup.devices) do
	-- if( v.device_type == devicetype ) then
	  -- return k
	-- end
  -- end
  -- return -1
-- end

local function getParent(lul_device)
  return luup.devices[lul_device].device_num_parent
end

local function getAltID(lul_device)
  return luup.devices[lul_device].id
end

-----------------------------------
-- from a altid, find a child device
-- returns 2 values
-- a) the index === the device ID
-- b) the device itself luup.devices[id]
-----------------------------------
local function findChild( lul_parent, altid )
  -- debug(string.format("findChild(%s,%s)",lul_parent,altid))
  for k,v in pairs(luup.devices) do
	if( getParent(k)==lul_parent) then
	  if( v.id==altid) then
		return k,v
	  end
	end
  end
  return nil,nil
end

local function getParent(lul_device)
  return luup.devices[lul_device].device_num_parent
end

local function getRoot(lul_device)
  while( getParent(lul_device)>0 ) do
	lul_device = getParent(lul_device)
  end
  return lul_device
end

------------------------------------------------
-- Device Properties Utils
------------------------------------------------
local function getSetVariable(serviceId, name, deviceId, default)
  local curValue = luup.variable_get(serviceId, name, deviceId)
  if (curValue == nil) then
	curValue = default
	luup.variable_set(serviceId, name, curValue, deviceId)
  end
  return curValue
end

local function getSetVariableIfEmpty(serviceId, name, deviceId, default)
  local curValue = luup.variable_get(serviceId, name, deviceId)
  if (curValue == nil) or (curValue:trim() == "") then
	curValue = default
	luup.variable_set(serviceId, name, curValue, deviceId)
  end
  return curValue
end

local function setVariableIfChanged(serviceId, name, value, deviceId)
  debug(string.format("setVariableIfChanged(%s,%s,%s,%s)",serviceId, name, value or 'nil', deviceId))
  local curValue = luup.variable_get(serviceId, name, tonumber(deviceId)) or ""
  value = value or ""
  if (tostring(curValue)~=tostring(value)) then
	luup.variable_set(serviceId, name, value or '', tonumber(deviceId))
  end
end

local function setAttrIfChanged(name, value, deviceId)
  debug(string.format("setAttrIfChanged(%s,%s,%s)",name, value or 'nil', deviceId))
  local curValue = luup.attr_get(name, deviceId)
  if ((value ~= curValue) or (curValue == nil)) then
	luup.attr_set(name, value or '', deviceId)
	return true
  end
  return value
end

local function getIP()
  -- local stdout = io.popen("GetNetworkState.sh ip_wan")
  -- local ip = stdout:read("*a")
  -- stdout:close()
  -- return ip
  local mySocket = socket.udp ()
  mySocket:setpeername ("42.42.42.42", "424242")  -- arbitrary IP/PORT
  local ip = mySocket:getsockname ()
  mySocket: close()
  return ip or "127.0.0.1"
end

------------------------------------------------
-- Tasks
------------------------------------------------
local taskHandle = -1
local TASK_ERROR = 2
local TASK_ERROR_PERM = -2
local TASK_SUCCESS = 4
local TASK_BUSY = 1

--
-- Has to be "non-local" in order for MiOS to call it :(
--
local function task(text, mode)
  if (mode == TASK_ERROR_PERM)
  then
	error(text)
  elseif (mode ~= TASK_SUCCESS)
  then
	warning(text)
  else
	log(text)
  end
  
  if (mode == TASK_ERROR_PERM)
  then
	taskHandle = luup.task(text, TASK_ERROR, MSG_CLASS, taskHandle)
  else
	taskHandle = luup.task(text, mode, MSG_CLASS, taskHandle)

	-- Clear the previous error, since they're all transient
	if (mode ~= TASK_SUCCESS)
	then
	  luup.call_delay("clearTask", 15, "", false)
	end
  end
end

function clearTask()
  task("Clearing...", TASK_SUCCESS)
end

local function UserMessage(text, mode)
  mode = (mode or TASK_ERROR)
  task(text,mode)
end

------------------------------------------------
-- LUA Utils
------------------------------------------------
local function Split(str, delim, maxNb)
  -- Eliminate bad cases...
  if string.find(str, delim) == nil then
	return { str }
  end
  if maxNb == nil or maxNb < 1 then
	maxNb = 0	 -- No limit
  end
  local result = {}
  local pat = "(.-)" .. delim .. "()"
  local nb = 0
  local lastPos
  for part, pos in string.gmatch(str, pat) do
	nb = nb + 1
	result[nb] = part
	lastPos = pos
	if nb == maxNb then break end
  end
  -- Handle the last field
  if nb ~= maxNb then
	result[nb + 1] = string.sub(str, lastPos)
  end
  return result
end

-- function string:split(sep) -- from http://lua-users.org/wiki/SplitJoin	 : changed as consecutive delimeters was not returning empty strings
  -- return Split(self, sep)
-- end

function string:template(variables)
  return (self:gsub('@(.-)@',
	function (key)
	  return tostring(variables[key] or '')
	end))
end

function string:trim()
  return self:match "^%s*(.-)%s*$"
end

local function tablelength(T)
  local count = 0
  if (T~=nil) then
  for _ in pairs(T) do count = count + 1 end
  end
  return count
end

------------------------------------------------
-- Communication TO HUE system
------------------------------------------------
local function ALTHueHttpCall(lul_device,verb,cmd,body)
	local result = {}
	verb = verb or "GET"
	cmd = cmd or ""
	body = body or ""
	debug(string.format("ALTHueHttpCall(%d,%s,%s,%s)",lul_device,verb,cmd,body))
	local credentials = getSetVariable(ALTHUE_SERVICE, "Credentials", lul_device, "")
	local ipaddr = luup.attr_get ('ip', lul_device )
	local newUrl = string.format("http://%s/api/%s/%s",ipaddr,credentials,cmd)
	debug(string.format("Calling Hue with %s %s , body:%s",verb,newUrl,body))
	local request, code = http.request({
		method=verb,
		url = newUrl,
		source= ltn12.source.string(body),
		headers = {
			-- ["Connection"]= "keep-alive",
			["Content-Length"] = body:len(),
			-- ["Origin"]="http://192.168.1.5",
			-- ["User-Agent"]="Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.134 Safari/537.36",
			-- ["Content-Type"] = "text/xml;charset=UTF-8",
			["Accept"]="text/plain, */*; q=0.01"
			-- ["X-Requested-With"]="XMLHttpRequest",
			-- ["Accept-Encoding"]="gzip, deflate",
			-- ["Accept-Language"]= "fr,fr-FR;q=0.8,en;q=0.6,en-US;q=0.4",
		},
		sink = ltn12.sink.table(result)
	})

		-- fail to connect
	if (request==nil) then
		error(string.format("failed to connect to %s, http.request returned nil", newUrl))
		return nil,"failed to connect"
	elseif (code==401) then
		warning(string.format("Access requires a user/password: %d", code))
		return nil,"unauthorized access - 401"
	elseif (code~=200) then
		warning(string.format("http.request returned a bad code: %d", code))
		return nil,"unvalid return code:" .. code
	end

	-- everything looks good
	local data = table.concat(result)
	debug(string.format("request:%s",request))
	debug(string.format("code:%s",code))
	debug(string.format("data:%s",data or ""))
	return json.decode(data) ,""
end

local function getZoneUniqueID(idx)
	return "group"..idx
end

local function getHueConfig(lul_device)
	local data,msg = ALTHueHttpCall(lul_device,"GET","config")
	return data,msg
end

local function getNewUserID(lul_device)
	local body = string.format( '{"devicetype":"ALTHue#Vera%s"}',luup.pk_accesspoint )
	local data,msg = ALTHueHttpCall(lul_device,"POST","",body)
	return data,msg
end

local function deleteUserID(lul_device,oldcredentials)
	local cmd = string.format("config/whitelist/%s",oldcredentials)
	local data,msg = ALTHueHttpCall(lul_device,"DELETE",cmd,"")
	return data,msg
end

local function runScene(lul_device,id)
	local cmd = "groups/0/action"
	local body = string.format('{"scene": "%s"}',id)
	local data,msg = ALTHueHttpCall(lul_device,"PUT",cmd,body)
	return data,msg
end

local function getTimezones(lul_device)
	-- /api/<username>/capabilities/timezones
	local data,msg = ALTHueHttpCall(lul_device,"GET","info/timezones")
	return data,msg
end

local function getLights(lul_device)
	local data,msg = ALTHueHttpCall(lul_device,"GET","lights")
	return data,msg
end

local function getSensors(lul_device)
	local data,msg = ALTHueHttpCall(lul_device,"GET","sensors")
	return data,msg
end

local function getZones(lul_device)
	local data,msg = ALTHueHttpCall(lul_device,"GET","groups")
	local zones = {}
	if (data == nil) then
		return nil
	end
	for groupid,group in pairs(data) do
		if (group.type == "Zone") then
			zones[groupid] = group
		end
	end
	debug(string.format("zones=%s",json.encode(zones)))
	return zones,msg
end
------------------------------------------------------------------------------------------------
-- Http handlers : Communication FROM ALTUI
-- http://192.168.1.5:3480/data_request?id=lr_ALTHUE_Handler&command=xxx
-- recommended settings in ALTUI: PATH = /data_request?id=lr_ALTHUE_Handler&mac=$M&deviceID=114
------------------------------------------------------------------------------------------------
local function switch( command, actiontable)
  -- check if it is in the table, otherwise call default
  if ( actiontable[command]~=nil ) then
	return actiontable[command]
  end
  warning("ALTHUE_Handler:Unknown command received:"..command.." was called. Default function")
  return actiontable["default"]
end

function myALTHUE_Handler(lul_request, lul_parameters, lul_outputformat)
  debug('myALTHUE_Handler: request is: '..tostring(lul_request))
  debug('myALTHUE_Handler: parameters is: '..json.encode(lul_parameters))
  local lul_html = "";	-- empty return by default
  local mime_type = "";
  if (hostname=="") then
	hostname = getIP()
	debug("now hostname="..hostname)
  end

  -- find a parameter called "command"
  if ( lul_parameters["command"] ~= nil ) then
	command =lul_parameters["command"]
  else
	  debug("ALTHUE_Handler:no command specified, taking default")
	command ="default"
  end

  local deviceID = tonumber( lul_parameters["DeviceNum"] ) -- or findTHISDevice() )

  -- switch table
  local action = {

	  ["default"] =
	  function(params)
		return "default handler / not successful", "text/plain"
	  end,
	  
	  ["config"] =
	  function(params)
		local url = lul_parameters["url"] or ""
		local data,msg = ALTHueHttpCall(deviceID,"GET",url)
		return json.encode(data or {}), "application/json"
	  end,  
	  
	  ["deleteUserID"]=
	  function(params)
		local oldcredentials = lul_parameters["oldcredentials"] or ""
		local data,msg = deleteUserID(deviceID,oldcredentials)
		return json.encode(data or {}), "application/json"
	  end, 
	  
	  ["setColorEffect"]=
	  function(params)
		local result = "err"
		local effect = lul_parameters["effect"]
		local hueuid = modurl.unescape(lul_parameters["hueuid"])
		if (hueuid ~= nil) and (effect ~= nil) then
			local childId,child = findChild( deviceID, hueuid )
			if (childId ~= nil) then
				UserSetEffect(deviceID,childId,effect)
				result = "ok"
			end
		end
		return json.encode(result or {}), "application/json"
	  end, 
	  
	  
	  -- ["runScene"]=
	  -- function(params)
		-- local id = lul_parameters["sceneid"] or ""
		-- local data,msg = runScene(deviceID,id)
		-- return json.encode(data or {}), "application/json"
	  -- end
  }
  -- actual call
  lul_html , mime_type = switch(command,action)(lul_parameters)
  if (command ~= "home") and (command ~= "oscommand") then
	debug(string.format("lul_html:%s",lul_html or ""))
  end
  return (lul_html or "") , mime_type
end

------------------------------------------------
-- Color Utilities
------------------------------------------------
local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local function k_to_mir(k)
    return 1000000 / k
end

local function mir_to_k(m)
    return 1000000 / m
end

local function enforceByte(r)
	if (r<0) then 
		r=0 
	elseif (r>255) then 
		r=255 
	end
	return (r)
end

local function ct_to_rgb(ct)
	-- The Mired Color temperature of the light. 2012 connected lights are capable of 153 (6500K) to 500 (2000K).
	-- M = 10^6 / K
	-- https://github.com/birkirb/hue-lib/blob/master/lib/hue/colors/color_temperature.rb
	local temp  = mir_to_k(ct) / 100
	local r,g,b=0,0,0
	
	if (temp<=66) then
		r = 255
	else
		r = enforceByte( 329.698727446 * ((temp - 60) ^ -0.1332047592) )
	end
	
	if (temp<=66) then
		g = enforceByte( 99.4708025861 * math.log(temp) - 161.1195681661 )
	else
		g = enforceByte( 288.1221695283 * ((temp-60) ^ -0.0755148492) )
	end
	
	if (temp>=66) then
		b = 255
	else
		if (temp<=19) then
			b = 0
		else
			b = enforceByte( 138.5177312231 * math.log(temp - 10) - 305.0447927307 )
		end
	end
	return r,g,b
end

local function hsb_to_rgb(h, s, v) 
	-- https://stackoverflow.com/questions/17242144/javascript-convert-hsb-hsv-color-to-rgb-accurately?utm_medium=organic&utm_source=google_rich_qa&utm_campaign=google_rich_qa
	-- Hue of the light. This is a wrapping value between 0 and 65535. Note, that hue/sat values are hardware dependent which means that programming two devices with the same value does not garantuee that they will be the same color. Programming 0 and 65535 would mean that the light will resemble the color red, 21845 for green and 43690 for blue.
	-- Saturation of the light. 254 is the most saturated (colored) and 0 is the least saturated (white).
	-- Brightness of the light. This is a scale from the minimum brightness the light is capable of, 1, to the maximum capable brightness, 254.
	h = tonumber(h or 0) / 65535
	s = tonumber(s or 0) / 254
	v = tonumber(v or 0) / 254
    local r, g, b, i, f, p, q, t
    i = math.floor(h * 6)
    f = h * 6 - i
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)
	local modulo = (i % 6)
	if (i==0) then
		r = v
		g = t
		b = p
	elseif (i==1) then
		r = q
		g = v
		b = p
	elseif (i==2) then
		r = p
		g = v
		b = t
	elseif (i==3) then
		r = p
		g = q
		b = v
	elseif (i==4) then
		r = t
		g = p
		b = v
	elseif (i==5) then
		r = v
		g = p
		b = q
	end
    return round(r * 255), round(g * 255), round(b * 255)
end

local function cie_to_rgb(x, y, brightness)
	-- //Set to maximum brightness if no custom value was given (Not the slick ECMAScript 6 way for compatibility reasons)
	-- debug(string.format("cie_to_rgb(%s,%s,%s)",x, y, brightness or ''))
	x = tonumber(x)
	y = tonumber(y)
	brightness = tonumber(brightness)
	
	if (brightness == nil) then
		brightness = 254;
	end

	local z = 1.0 - x - y;
	local Y = math.floor( 100 * (brightness / 254)) /100	-- .toFixed(2);
	local X = (Y / y) * x;
	local Z = (Y / y) * z;

	-- //Convert to RGB using Wide RGB D65 conversion
	local red 	=  X * 1.656492 - Y * 0.354851 - Z * 0.255038;
	local green 	= -X * 0.707196 + Y * 1.655397 + Z * 0.036152;
	local blue 	=  X * 0.051713 - Y * 0.121364 + Z * 1.011530;

	-- //If red, green or blue is larger than 1.0 set it back to the maximum of 1.0
	if (red > blue) and (red > green) and (red > 1.0) then

		green = green / red;
		blue = blue / red;
		red = 1.0;
	
	elseif (green > blue) and (green > red) and (green > 1.0) then

		red = red / green;
		blue = blue / green;
		green = 1.0;
	
	elseif (blue > red) and (blue > green) and (blue > 1.0) then

		red = red / blue;
		green = green / blue;
		blue = 1.0;
	end

	-- //Reverse gamma correction
	red 	= (red <= 0.0031308) and (12.92 * red) or (1.0 + 0.055) * (red^(1.0 / 2.4)) - 0.055;
	green 	= (green <= 0.0031308) and (12.92 * green) or (1.0 + 0.055) * (green^(1.0 / 2.4)) - 0.055;
	blue 	= (blue <= 0.0031308) and (12.92 * blue) or (1.0 + 0.055) * (blue^(1.0 / 2.4)) - 0.055;


	-- //Convert normalized decimal to decimal
	red 	= round(red * 255);
	green 	= round(green * 255);
	blue 	= round(blue * 255);
		
	-- debug(string.format("cie_to_rgb R:%s G:%s B:%s",red,green,blue))
	return enforceByte(red), enforceByte(green), enforceByte(blue)
end

local function rgb_to_cie(red, green, blue)
	-- Apply a gamma correction to the RGB values, which makes the color more vivid and more the like the color displayed on the screen of your device
	red = tonumber(red)
	green = tonumber(green)
	blue = tonumber(blue)
	red 	= (red > 0.04045) and ((red + 0.055) / (1.0 + 0.055))^2.4 or (red / 12.92)
	green 	= (green > 0.04045) and ((green + 0.055) / (1.0 + 0.055))^2.4 or (green / 12.92)
	blue 	= (blue > 0.04045) and ((blue + 0.055) / (1.0 + 0.055))^2.4 or (blue / 12.92)

	-- //RGB values to XYZ using the Wide RGB D65 conversion formula
	local X 		= red * 0.664511 + green * 0.154324 + blue * 0.162028
	local Y 		= red * 0.283881 + green * 0.668433 + blue * 0.047685
	local Z 		= red * 0.000088 + green * 0.072310 + blue * 0.986039

	-- //Calculate the xy values from the XYZ values
	local x1 		= math.floor( 10000 * (X / (X + Y + Z)) )/10000  --.toFixed(4);
	local y1 		= math.floor( 10000 * (Y / (X + Y + Z)) )/10000  --.toFixed(4);

	return x1, y1
end

local function rgbToHex(red, green, blue)
	local rgb = {red, green, blue}
	local hexadecimal = '#'
	for key, value in pairs(rgb) do
		local hex = ''
		while(value > 0)do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub('0123456789ABCDEF', index, index) .. hex			
		end
		if(string.len(hex) == 0)then
			hex = '00'
		elseif(string.len(hex) == 1)then
			hex = '0' .. hex
		end
		hexadecimal = hexadecimal .. hex
	end
	return hexadecimal
end

------------------------------------------------
-- UPNP Actions Sequence
------------------------------------------------
local function HueLampSetState(lul_device,body)
	debug(string.format("HueLampSetState(%s,%s)",lul_device,body))
	lul_device = tonumber(lul_device)
	local lul_root = getRoot(lul_device)
	local childid = luup.devices[lul_device].id;
	local hueindex = MapUID2Index[ childid ]
	if (hueindex ~= nil) then
		local data,msg = ALTHueHttpCall(
			lul_root,
			"PUT",
			string.format("lights/%s/state",hueindex),
			body)
	end	
end

function UserSetLoadLevelTarget(lul_device,newValue)
	debug(string.format("UserSetLoadLevelTarget(%s,%s)",lul_device,newValue))
	lul_device = tonumber(lul_device)
	lul_root = getRoot(lul_device)
	local status = luup.variable_get("urn:upnp-org:serviceId:Dimming1", "LoadLevelStatus", lul_device)
	if (status ~= newValue) then
		newValue = tonumber(newValue)
		local bri = math.floor(255*newValue/100)
		local val = (newValue ~= 0)
		if (bri==0)  then
			HueLampSetState(lul_device,'{"on": false}')
		else
			luup.variable_set("urn:upnp-org:serviceId:Dimming1", "LoadLevelTarget", newValue, lul_device)
			luup.variable_set("urn:upnp-org:serviceId:Dimming1", "LoadLevelStatus", newValue, lul_device)
			luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Target", val and "1" or "0", lul_device)
			luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Status", val and "1" or "0", lul_device)
			HueLampSetState(lul_device,string.format('{"on": %s, "bri": %d}',tostring(val),bri))
		end
	end
end

function UserSetPowerTarget(lul_device,newTargetValue)
	debug(string.format("UserSetPowerTarget(%s,%s)",lul_device,newTargetValue))
	newTargetValue = tonumber(newTargetValue)
	-- special case for BinaryLight devices like OSRAM plug or cybrmage ZHA Securifi device ( power plug )
	if (luup.devices[lul_device].device_type == "urn:schemas-upnp-org:device:BinaryLight:1") then
		local v = (newTargetValue > 0) and "1" or "0"
		luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Target", v, lul_device)
		luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Status", v, lul_device)
		
		HueLampSetState(lul_device,string.format('{"on": %s}',(newTargetValue > 0) and "true" or "false"))
	else
		UserSetLoadLevelTarget(lul_device, (newTargetValue>0) and "100" or "0" )
	end
end

function UserToggleState(lul_device)
  debug(string.format("UserToggleState(%s)",lul_device))
  local status = luup.variable_get("urn:upnp-org:serviceId:SwitchPower1", "Status", lul_device)
  status = 1-tonumber(status)
  UserSetPowerTarget(lul_device,tostring(status))
end

-- Warm White: Wx
-- Cool White: Dx
-- W0     <--> W255  =  D0     <--> D255
-- 2000K <--> 5500K = 5500K <--> 9000K
-- mired range : 153 (6500K) to 500 (2000K).

function UserSetColor(lul_device,newColorTarget)
	debug(string.format("UserSetColor(%s,%s)",lul_device,newColorTarget))
	local warmcool = string.sub(newColorTarget, 1, 1)
	local value = tonumber(string.sub(newColorTarget, 2))
	local kelvin = math.floor((value*3500/255)) + ((warmcool=="D") and 5500 or 2000)

	local mired = math.floor(1000000/kelvin)
	local newValue = luup.variable_get("urn:upnp-org:serviceId:Dimming1", "LoadLevelStatus", lul_device)
	local bri = math.floor(255*newValue/100)
	
	debug(string.format("UserSetColor target: %s => bri:%s ct:%s",newColorTarget, bri,mired))
	local body = string.format('{"on":true, "bri": %d, "ct":%s}', bri, mired )
	HueLampSetState(lul_device,body)
end

function UserSetColorRGB(lul_device,newColorRGBTarget)
	debug(string.format("UserSetColorRGB(%s,%s)",lul_device,newColorRGBTarget))
	local parts = Split(newColorRGBTarget,',')
	local x,y = rgb_to_cie(parts[1], parts[2], parts[3])
	debug(string.format("RGB: %s => x:%s y:%s",newColorRGBTarget, tostring(x), tostring(y)))
	local newValue = luup.variable_get("urn:upnp-org:serviceId:Dimming1", "LoadLevelStatus", lul_device)
	local bri = math.floor(255*newValue/100)
	local body = string.format('{"on": true, "bri": %d, "xy":[%f,%f]}',bri,x,y)
	HueLampSetState(lul_device,body)
end

function UserSetEffect(lul_device,lul_child,newEffect)
	newEffect = newEffect or "none"
	debug(string.format("UserSetEffect(%s,%s,%s)",lul_device,lul_child,newEffect))
	local body = string.format('{"effect":"%s"}', newEffect )
	HueLampSetState(lul_child,body)
end

function UserSetArmed(lul_device,newArmedValue)
	debug(string.format("UserSetArmed(%s,%s)",lul_device,newArmedValue))
	lul_device = tonumber(lul_device)
	newArmedValue = tonumber(newArmedValue)
	setVariableIfChanged("urn:micasaverde-com:serviceId:SecuritySensor1", "Armed", newArmedValue, lul_device)
end

function getCurrentTemperature(lul_device)
  lul_device = tonumber(lul_device)
  debug(string.format("getCurrentTemperature(%d)",lul_device))
  return luup.variable_get("urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", lul_device)
end
	

------------------------------------------------
-- UPNP actions Sequence
------------------------------------------------
local function setDebugMode(lul_device,newDebugMode)
  lul_device = tonumber(lul_device)
  newDebugMode = tonumber(newDebugMode) or 0
  debug(string.format("setDebugMode(%d,%d)",lul_device,newDebugMode))
  luup.variable_set(ALTHUE_SERVICE, "Debug", newDebugMode, lul_device)
  if (newDebugMode==1) then
	DEBUG_MODE=true
  else
	DEBUG_MODE=false
  end
end

local function registerNewUser(lul_device)
	-- must get a new user ID
	local data,msg = getNewUserID(lul_device)
	debug(string.format("return data: %s", json.encode(data)))
	if ((data==nil) or (data[1].error ~= nil)) then
		error("New User is not accepted by the bridge, did you press the Link button on the Bridge ? : " .. data[1].error.description);
		setVariableIfChanged(ALTHUE_SERVICE, "Credentials", "", lul_device)
		return false
	end
	-- [{"success":{"username": "83b7780291a6ceffbe0bd049104df"}}]
	credentials = data[1].success.username
	setVariableIfChanged(ALTHUE_SERVICE, "Credentials", credentials, lul_device)
	return true
end

local function verifyAccess(lul_device)
	debug(string.format("verifyAccess(%s)",lul_device))
	local credentials = getSetVariable(ALTHUE_SERVICE, "Credentials", lul_device, "")
	if (isempty(credentials)) then
		-- UserMessage(string.format("The plugin is not linked to your Hue Bridge. Proceed with pairing in settings page"),TASK_ERROR)
		return false
	end

	local data,msg = getHueConfig(lul_device)
	-- local data,msg = getTimezones(lul_device)
	if ( (data==nil) or (tablelength(data)<1) ) then
		-- UserMessage(string.format("The plugin is not linked to your Hue Bridge. Proceed with pairing in settings page"),TASK_ERROR)
		return false
	end
	debug(string.format("getHueConfig returns data: %s", json.encode(data)))
	
	if not (data and data["whitelist"]) then	-- if (data[1].error ~= nil) then
		warning("User is not registered to Philips Hue Bridge : " .. (data[1] and data[1].error.description or "Not Authorized"));
		return false
	end
	
	debug(string.format("communication with Hue Bridge seems ok: %s", json.encode(data)))
	setVariableIfChanged(ALTHUE_SERVICE, "IconCode", 100, lul_device)
	return true
end

function RunHueScene(lul_device,hueSceneID)
	hueSceneID = hueSceneID or ""
	debug(string.format("RunHueScene(%s)",hueSceneID))
	local data,msg = runScene(lul_device,hueSceneID)
	return (data ~= nil),msg
end

function UnpairWithHue(lul_device)
	debug(string.format("UnpairWithHue(%s)",lul_device))
	local credentials = getSetVariable(ALTHUE_SERVICE, "Credentials", lul_device, "")
	setVariableIfChanged(ALTHUE_SERVICE, "IconCode", 0, lul_device)
	if (isempty(credentials)) then
		warning("The plugin is not linked to your Hue Bridge. Unpair cannot proceed")
		return false
	end
	local data,msg = deleteUserID(lul_device,credentials)
	setVariableIfChanged(ALTHUE_SERVICE, "Credentials", "", lul_device)
	if ( (data==nil) or (tablelength(data)<1) ) then
		warning(string.format("The plugin is not linked to your Hue Bridge. make sure you have pressed the Hue bridge central button and reload luup"))
		return false
	end
	debug(string.format("deleteUserID returns data:%s, msg:%s", json.encode(data),msg or ""))
	if (data[1].success == nil) then
		error(string.format("Hue bridge did not accept the removal of the user from the whitelist"))
		return false
	end
	return true
end

function PairWithHue(lul_device)
	debug(string.format("PairWithHue(%s)",lul_device))
	if (verifyAccess(lul_device) == false ) then
		return registerNewUser(lul_device)
	end
	return true
end

--------------------------------------------------------
-- Core engine 
--------------------------------------------------------
function refreshHueData(lul_device,norefresh)
	local success=true
	norefresh = norefresh or false
	debug(string.format("refreshHueData(%s,%s)",lul_device,tostring(norefresh)))
	lul_device = tonumber(lul_device)
	
	-- calculate zone diff
	local tmp_time = os.time()
	local d1 = os.date("*t",  tmp_time)
	local d2 = os.date("!*t", tmp_time)
	d1.isdst = false
	local zone_diff = os.difftime(os.time(d1), os.time(d2))

	local data,msg = getLights(lul_device)
	if (data~=nil) and (tablelength(data)>0) then
		for k,v in pairs(data) do
			local idx = tonumber(k)
			local hexcolor = ""
			local childId,child = findChild( lul_device, v.uniqueid )
			if (childId~=nil) then
				local status = (v.state.on == true) and "1" or "0"
				local bri = math.ceil( 100*(v.state.bri or 0)/255 )
				if (v.state.on == false) then
					bri=0
				end
				setVariableIfChanged("urn:upnp-org:serviceId:SwitchPower1", "Status", status, childId )
				setVariableIfChanged("urn:upnp-org:serviceId:SwitchPower1", "Target", status, childId )
				setVariableIfChanged("urn:upnp-org:serviceId:Dimming1", "LoadLevelStatus", bri, childId )
				setVariableIfChanged("urn:upnp-org:serviceId:Dimming1", "LoadLevelTarget", bri, childId )
				if (v.state.colormode ~= nil) then
					local w,d,r,g,b=0,0,0,0,0
					if (v.state.colormode == "xy") and (v.state.xy~=nil) then
						r,g,b = cie_to_rgb(v.state.xy[1], v.state.xy[2], nil) -- v.state.bri
					elseif (v.state.colormode == "hs") then
						r,g,b = hsb_to_rgb(v.state.hue, v.state.sat, v.state.bri)
					elseif (v.state.colormode == "ct") and (v.state.ct~=nil) then
						local kelvin = math.floor(((1000000/v.state.ct)/100)+0.5)*100
						w = (kelvin < 5450) and (math.floor((kelvin-2000)/13.52) + 1) or 0
						d = (kelvin > 5450) and (math.floor((kelvin-5500)/13.52) + 1) or 0
					else
						warning(string.format("Unknown colormode:%s for Hue:%s, uniqueid:%s , state:%s",v.state.colormode,idx,v.uniqueid, json.encode(v.state)))
					end
					setVariableIfChanged("urn:micasaverde-com:serviceId:Color1", "CurrentColor", string.format("0=%s,1=%s,2=%s,3=%s,4=%s",w,d,r,g,b), childId )
					hexcolor = rgbToHex(r,g,b)
					setVariableIfChanged("urn:upnp-org:serviceId:althue1", "LampHexValue", hexcolor, childId )
				end
			else
				warning(string.format("could not find childId for Hue:%s, uniqueid:%s",idx,v.uniqueid))
			end
		end		
	else
		success=false
		warning(string.format("Communication failure with the Hue Hub; msg:%s",msg or "nil"))
	end
	debug(string.format("After Lights, success is : %s",tostring(success)))
	if (success) then
		data,msg = getSensors(lul_device)
		if (data~=nil) and (tablelength(data)>0) then
			for k,v in pairs(data) do
				local idx = tonumber(k)
				local childId,child = findChild( lul_device, v.uniqueid )
				if (childId) then
				
					local convertedTimestamp = nil
					local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
					local runyear, runmonth, runday, runhour, runminute, runseconds = v.state.lastupdated:match(pattern)
					if (runyear~= nil) then
						convertedTimestamp = os.time({year = runyear, month = runmonth, day = runday, hour = runhour, min = runminute, sec = runseconds + zone_diff})
					end
					
					if (v.config.battery ~= nil) then
						setVariableIfChanged("urn:micasaverde-com:serviceId:HaDevice1", "BatteryLevel", v.config.battery , childId )
						setVariableIfChanged("urn:micasaverde-com:serviceId:HaDevice1", "BatteryDate", convertedTimestamp or "", childId )
					end
					if (v.type == "ZLLTemperature") then
						local temp = (v.state.temperature or 0)/100
						local tempformat = getSetVariable(ALTHUE_SERVICE,"TempFormat", lul_device, "C")
						if (tempformat=="F") then
							temp = (temp * 1.8) + 32
						end
						setVariableIfChanged("urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", temp, childId )
					elseif (v.type == "ZLLPresence") then
						local tripped = (v.state.presence == true) and "1" or "0"
						local armed = getSetVariable("urn:micasaverde-com:serviceId:SecuritySensor1", "Armed", childId, 0)
						setVariableIfChanged("urn:micasaverde-com:serviceId:SecuritySensor1", "Tripped", tripped , childId )
						if (armed=="1") then
							setVariableIfChanged("urn:micasaverde-com:serviceId:SecuritySensor1", "ArmedTripped", tripped , childId )
						end
						if (tripped=="1") then
							setVariableIfChanged("urn:micasaverde-com:serviceId:SecuritySensor1", "LastTrip", convertedTimestamp or "" , childId )
						end
					elseif (v.type == "ZLLLightLevel") then
						setVariableIfChanged("urn:micasaverde-com:serviceId:LightSensor1", "CurrentLevel", v.state.lightlevel or "", childId )
					elseif (v.type == "ZLLSwitch" ) then
						local nbuttons,selectedbutton = 0,0
						for idx,input in pairs(v.capabilities.inputs) do
							for k,event in pairs(input.events) do
								nbuttons = nbuttons+1
								if (v.state.buttonevent == event.buttonevent) then
									selectedbutton = nbuttons
								end
							end
						end
						setVariableIfChanged("urn:micasaverde-com:serviceId:SceneController1", "LastSceneTime", convertedTimestamp or "", childId )
						setVariableIfChanged("urn:micasaverde-com:serviceId:SceneController1", "LastSceneID", v.state.buttonevent or "", childId )
						setVariableIfChanged("urn:micasaverde-com:serviceId:SceneController1", "sl_SceneActivated", selectedbutton or "", childId )
						setVariableIfChanged("urn:micasaverde-com:serviceId:SceneController1", "NumButtons", nbuttons, childId )
					end
				end
			end		
		else
			success=false
			warning(string.format("Communication failure with the Hue Hub; msg:%s",msg or "nil"))
		end
		debug(string.format("After Sensors, success is : %s",tostring(success)))
	end
	
	--Zones
	if (success) then
		data,msg = getZones(lul_device)
		if (data~=nil) then
			for k,v in pairs(data) do
				local idx = tonumber(k)
				local uid = getZoneUniqueID(idx)
				local childId,child = findChild( lul_device, uid)
				if (childId~=nil) then
					-- if anyone device is light, we consider the zone as switched on
					local status = (v.state.any_on == true) and "1" or "0"
					setVariableIfChanged("urn:upnp-org:serviceId:SwitchPower1", "Status", status, childId )
					setVariableIfChanged("urn:upnp-org:serviceId:SwitchPower1", "Target", status, childId )
				end
			end
		end
	end
		
	if (norefresh==false) then
		local period= getSetVariable(ALTHUE_SERVICE, "RefreshPeriod", lul_device, DEFAULT_REFRESH)
		debug(string.format("programming next refreshHueData(%s) in %s sec",lul_device,period))
		luup.call_delay("refreshHueData",period,tostring(lul_device))
	end
	if (success~=true) then
		luup.variable_set(ALTHUE_SERVICE, "LastFailedComm", os.time(), lul_device)
	end
	debug(string.format("refreshHueData returns  success is : %s",tostring(success)))
	return success
end

local function SyncSensors(lul_device,data,child_devices)
	debug(string.format("SyncSensors(%s)",lul_device))
	local NamePrefix = getSetVariable(ALTHUE_SERVICE, "NamePrefix", lul_device, NAME_PREFIX)
	if (data~=nil) and (tablelength(data)>0) then
		for k,v in pairs(data) do
			local idx = tonumber(k)
			local mapentry = SensorTypes[ v.type ]
			if (mapentry~=nil) and (v.uniqueid~=nil) then -- warning daylight sensor has no unique ID
				debug(string.format("Simulation Create Child type:%s vuniqueID:%s mapentry:%s",v.type,v.uniqueid,json.encode(mapentry)))
				luup.chdev.append(
					lul_device, child_devices,
					v.uniqueid,					-- children map index is altid
					NamePrefix..v.name,			-- children map name attribute is device name
					mapentry.dtype,				-- children device type
					mapentry.dfile,				-- children D-file
					"", 						-- children I-file
					table.concat(mapentry.vartable, "\n"),	-- params
					false						-- not embedded
				)
				MapUID2Index[ v.uniqueid ]=k
			end
		end	
	else
		warning(string.format("Communication failure with the Hue Hub; msg:%s",msg or "nil"))
		return false
	end
end

local function SyncLights(lul_device,data,child_devices)	 
	debug(string.format("SyncLights(%s)",lul_device))
	local NamePrefix = getSetVariable(ALTHUE_SERVICE, "NamePrefix", lul_device, NAME_PREFIX)
	if (data~=nil) and (tablelength(data)>0) then
		-- for all children device, iterate
		local vartable = {
			"urn:upnp-org:serviceId:SwitchPower1,Status=0",
			"urn:upnp-org:serviceId:SwitchPower1,Target=0",
			"urn:upnp-org:serviceId:Dimming1,LoadLevelStatus=0",
			"urn:upnp-org:serviceId:Dimming1,LoadLevelTarget=0",
		}
		for k,v in pairs(data) do
			local idx = tonumber(k)
			local mapentry = LightTypes[ v.type ] or LightTypes[ "Default" ] 
			luup.chdev.append(
				lul_device, child_devices,
				v.uniqueid,					-- children map index is altid
				NamePrefix..v.name,		-- children map name attribute is device name
				mapentry.dtype,				-- children device type
				mapentry.dfile,				-- children D-file
				"", 						-- children I-file
				table.concat(vartable, "\n"),	-- params
				false,						-- not embedded
				false						-- invisible
			)
			MapUID2Index[ v.uniqueid ]=k
		end
		
	else
		warning(string.format("Communication failure with the Hue Hub; msg:%s",msg or "nil"))
		return false
	end
	return (data~=nil)
end

local function SyncZones(lul_device,data,child_devices)
	debug(string.format("SyncZones(%s)",lul_device))
	local NamePrefix = getSetVariable(ALTHUE_SERVICE, "NamePrefix", lul_device, NAME_PREFIX)
	if (data~=nil) and (tablelength(data)>0) then
		local vartable = {
			"urn:upnp-org:serviceId:SwitchPower1,Status=0",
			"urn:upnp-org:serviceId:SwitchPower1,Target=0"
		}
		for k,v in pairs(data) do
			local idx = tonumber(k)
			local mapentry = LightTypes["On/Off light"]	-- on off type
			local uid = getZoneUniqueID(idx)
			if (idx~=nil) then 
				luup.chdev.append(
					lul_device, child_devices,
					uid ,					-- unique ID "group"..idx
					NamePrefix.."Zone "..v.name,	-- children map name attribute is device name
					mapentry.dtype,				-- children device type
					mapentry.dfile,				-- children D-file
					"", 						-- children I-file
					table.concat(vartable, "\n"),	-- params
					false						-- not embedded
				)
				MapUID2Index[ uid ]=k
			end
		end	
	else
		warning(string.format("Communication failure with the Hue Hub; msg:%s",msg or "nil"))
		return false
	end
end

local function InitDevices(lul_device,data)	 
	debug(string.format("InitDevices(%s) MapUID2Index is: %s",lul_device,json.encode(MapUID2Index)))
	local NamePrefix = getSetVariable(ALTHUE_SERVICE, "NamePrefix", lul_device, NAME_PREFIX)
	for k,v in pairs(data) do
		if (v.uniqueid~=nil) then	-- Hue Daylight sensor does not have uniqueID
			local childId,child = findChild( lul_device, v.uniqueid )
			if (childId ~= nil) then
				setAttrIfChanged("name", NamePrefix..v.name, childId)
				setAttrIfChanged("manufacturer", v.manufacturername, childId)
				setAttrIfChanged("model", v.modelid, childId)
				luup.variable_set(ALTHUE_SERVICE, "BulbModelID", v.modelid, childId)
			-- unsuportedf devices wont be found, they have been filtered out at creationg time
			-- else
				-- warning(string.format("Could not find Hue device %s",v.uniqueid))
			end
		end
	end
end

local function SyncDevices(lul_device)	 
	debug(string.format("SyncDevices(%s)",lul_device))
	local lights,msg = getLights(lul_device)
	local sensors,msg = getSensors(lul_device)
	local zones = getZones(lul_device)
	if (light~=nil) or (sensors~=nil) or (zones~=nil) then
		local child_devices = luup.chdev.start(lul_device);
		SyncLights(lul_device, lights, child_devices)
		SyncSensors(lul_device, sensors, child_devices)
		SyncZones(lul_device, zones, child_devices)
		luup.chdev.sync(lul_device, child_devices)	
		InitDevices(lul_device, lights)
		InitDevices(lul_device, sensors)
		-- nothng to init for Zones
	else
		warning(string.format("Communication failure with the Hue Hub; msg:%s",msg or "nil"))
		return false
	end
	return true
end

local function startEngine(lul_device)
	debug(string.format("startEngine(%s)",lul_device))
	local success=false
	lul_device = tonumber(lul_device)
	MapUID2Index={}

	local data,msg = getHueConfig(lul_device)
	debug(string.format("return data: %s", json.encode(data or "nil")))
	if (data == nil) then
		-- Get Hue Config failed
		UserMessage(string.format("Not able to reach the Hue Bridge (missing ip addr in attributes ?, device:%s, msg:%s",lul_device,msg),TASK_ERROR)
		return success --false
	else
		setAttrIfChanged("manufacturer", data.name, lul_device)
		setAttrIfChanged("model", data.modelid, lul_device)
		-- luup.variable_set(ALTHUE_SERVICE, "BulbModelID", data.modelid, lul_device)
		setAttrIfChanged("mac", data.mac, lul_device)
		setAttrIfChanged("name", data.name, lul_device)
	end

	success = PairWithHue(lul_device) and SyncDevices(lul_device) and refreshHueData(lul_device)
	return success
end

function startupDeferred(lul_device)
	lul_device = tonumber(lul_device)
	log("startupDeferred, called on behalf of device:"..lul_device)

	local debugmode = getSetVariable(ALTHUE_SERVICE, "Debug", lul_device, "0")
	local oldversion = getSetVariable(ALTHUE_SERVICE, "Version", lul_device, "")
	local period= getSetVariable(ALTHUE_SERVICE, "RefreshPeriod", lul_device, DEFAULT_REFRESH)
	local credentials	 = getSetVariable(ALTHUE_SERVICE, "Credentials", lul_device, "")
	local NamePrefix = getSetVariable(ALTHUE_SERVICE, "NamePrefix", lul_device, NAME_PREFIX)
	local iconCode = getSetVariable(ALTHUE_SERVICE,"IconCode", lul_device, "0")
	local lastvalid = getSetVariable(ALTHUE_SERVICE,"LastFailedComm", lul_device, "")
	local tempformat = getSetVariable(ALTHUE_SERVICE,"TempFormat", lul_device, "C")
	setAttrIfChanged("category_num", 26, lul_device)	--Philips Controller

	-- sanitize
	if (tonumber(period)==0) then
		setVariableIfChanged(ALTHUE_SERVICE, "RefreshPeriod", DEFAULT_REFRESH, lul_device)
		period=DEFAULT_REFRESH
	end

	if (debugmode=="1") then
		DEBUG_MODE = true
		UserMessage("Enabling debug mode for device:"..lul_device,TASK_BUSY)
	end
	local major,minor = 0,0
	local tbl={}

	if (oldversion~=nil) then
		if (oldversion ~= "") then
		  major,minor = string.match(oldversion,"v(%d+)%.(%d+)")
		  major,minor = tonumber(major),tonumber(minor)
		  debug ("Plugin version: "..version.." Device's Version is major:"..major.." minor:"..minor)

		  newmajor,newminor = string.match(version,"v(%d+)%.(%d+)")
		  newmajor,newminor = tonumber(newmajor),tonumber(newminor)
		  debug ("Device's New Version is major:"..newmajor.." minor:"..newminor)

		  -- force the default in case of upgrade
		  if ( (newmajor>major) or ( (newmajor==major) and (newminor>minor) ) ) then
			-- log ("Version upgrade => Reseting Plugin config to default")
		  end
		else
		  log ("New installation")
		end
		luup.variable_set(ALTHUE_SERVICE, "Version", version, lul_device)
	end

	luup.register_handler('myALTHUE_Handler','ALTHUE_Handler')

	local ipaddr = luup.attr_get ('ip', lul_device )
	if (ipaddr:trim()=="") then
		UserMessage(string.format("The IP address of the Hue bridge is not set in the plugin attributes"),TASK_ERROR_PERM)
		setVariableIfChanged(ALTHUE_SERVICE, "IconCode", 0, lul_device)
		if( luup.version_branch == 1 and luup.version_major == 7) then
			luup.set_failure(1,lul_device)  -- should be 0 in UI7
		else
			luup.set_failure(false,lul_device)	-- allways no failure mode  in UI5 !
		end
		error("startup not completed successfully")
		return 
	end
	
	local success = startEngine(lul_device)
	setVariableIfChanged(ALTHUE_SERVICE, "IconCode", success and "100" or "0", lul_device)

	-- report success or failure
	if( luup.version_branch == 1 and luup.version_major == 7) then
		if (success == true) then
			luup.set_failure(0,lul_device)  -- should be 0 in UI7
		else
			luup.set_failure(1,lul_device)  -- should be 0 in UI7
		end
	else
		luup.set_failure(false,lul_device)	-- should be 0 in UI7
	end

	log("startup completed")
end

------------------------------------------------
-- Check UI7
------------------------------------------------
local function checkVersion(lul_device)
  local ui7Check = luup.variable_get(ALTHUE_SERVICE, "UI7Check", lul_device) or ""
  if ui7Check == "" then
	luup.variable_set(ALTHUE_SERVICE, "UI7Check", "false", lul_device)
	ui7Check = "false"
	-- luup.attr_set("device_json", JSON_FILE, lul_device)
	-- luup.reload()
  end
  if( luup.version_branch == 1 and luup.version_major == 7) then
	if (ui7Check == "false") then
		-- first & only time we do this
		luup.variable_set(ALTHUE_SERVICE, "UI7Check", "true", lul_device)
		luup.attr_set("device_json", UI7_JSON_FILE, lul_device)
		luup.reload()
	end
  else
	-- UI5 specific
	LightTypes["Extended color light"]={  dtype="urn:schemas-upnp-org:device:DimmableLight:1" , dfile="D_DimmableRGBLight1.xml" }
  end
end

function initstatus(lul_device)
  lul_device = tonumber(lul_device)
  -- this_device = lul_device
  log("initstatus("..lul_device..") starting version: "..version)
  checkVersion(lul_device)
  hostname = getIP()
  local delay = math.random(RAND_DELAY)	-- delaying first refresh by x seconds
  debug("initstatus("..lul_device..") startup for Root device, delay:"..delay)
  luup.call_delay("startupDeferred", delay, tostring(lul_device))
end

-- do not delete, last line must be a CR according to MCV wiki page
