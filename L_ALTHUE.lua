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
local this_device	= nil
local DEBUG_MODE	= false -- controlled by UPNP action
local version		= "v0.02"
local UI7_JSON_FILE = "D_ALTHUE_UI7.json"
local DEFAULT_REFRESH = 30
local NAME_PREFIX	= "Hue "	-- trailing space needed
local hostname		= ""
local MapUID2Index={}

local json = require("dkjson")
local mime = require('mime')
local socket = require("socket")
local http = require("socket.http")
local ltn12 = require("ltn12")
-- local lom = require("lxp.lom") -- http://matthewwild.co.uk/projects/luaexpat/lom.html
-- local xpath = require("xpath")

-- altid is the object ID ( like the relay ID ) on the ALTHUE server
local childmap = {
  ["SONDE%s"] = {
	devtype="urn:schemas-micasaverde-com:device:TemperatureSensor:1",
	devfile="D_TemperatureSensor1.xml",
	name="SONDE %s",
	map="TempSensors" -- user choice in a CSV string 1 to 8 ex:	 2,3
  },
  ["ad%s"] = {
	devtype="urn:schemas-micasaverde-com:device:GenericSensor:1",
	devfile="D_GenericSensor1.xml",
	name="ANALOG %s",
	map="AnalogInputs" -- user choice in a CSV string 1 to 8 ex:  2,3
  },
  ["rl%s"] = {
	devtype="urn:schemas-upnp-org:device:BinaryLight:1",
	devfile="D_BinaryLight1.xml",
	name="RELAIS %s",
	map={1,2} -- hard coded dev 1 and 2
  },
  ["rl1w%s"] = {
	devtype="urn:schemas-upnp-org:device:BinaryLight:1",
	devfile="D_BinaryLight1.xml",
	name="RELAIS 1W %s",
	map="Relais1W"	-- user choice in a CSV string 1 to 8 ex:  2,3
  },
  ["in%s"] = {
	devtype="urn:schemas-upnp-org:device:BinaryLight:1",
	devfile="D_BinaryLight1.xml",
	name="ENTREE %s",
	map={1,2} -- hard coded dev 1 and 2
  },
  ["vs%s"] = {
	devtype="urn:schemas-upnp-org:device:BinaryLight:1",
	devfile="D_BinaryLight1.xml",
	name="SWITCH %s",
	map="VirtualSwitches" -- user choice in a CSV string 1 to 8 ex:	 2,3
  },
  ["tic%s"] = {
	devtype="urn:schemas-micasaverde-com:device:PowerMeter:1",
	devfile="D_PowerMeter1.xml",
	name="TIC %s",
	map={1,2} -- hard coded dev 1 and 2
  },
  ["pa%s"] = {
	devtype="urn:schemas-micasaverde-com:device:PowerMeter:1",
	devfile="D_PowerMeter1.xml",
	name="PINCE %s",
	map="AnalogClamps" -- user choice in a CSV string 1 to 8 ex:  2,3
  },
  ["pls%s"] = {
	devtype="urn:schemas-micasaverde-com:device:PowerMeter:1",
	devfile="D_PowerMeter1.xml",
	name="PULSE %s",
	map="PulseCounters" -- user choice in a CSV string 1 to 8 ex:  2,3
  }
}

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

local function findTHISDevice()
  for k,v in pairs(luup.devices) do
	if( v.device_type == devicetype ) then
	  return k
	end
  end
  return -1
end

------------------------------------------------
-- Device Properties Utils
------------------------------------------------
function getSetVariable(serviceId, name, deviceId, default)
  local curValue = luup.variable_get(serviceId, name, deviceId)
  if (curValue == nil) then
	curValue = default
	luup.variable_set(serviceId, name, curValue, deviceId)
  end
  return curValue
end

function getSetVariableIfEmpty(serviceId, name, deviceId, default)
  local curValue = luup.variable_get(serviceId, name, deviceId)
  if (curValue == nil) or (curValue:trim() == "") then
	curValue = default
	luup.variable_set(serviceId, name, curValue, deviceId)
  end
  return curValue
end

function setVariableIfChanged(serviceId, name, value, deviceId)
  debug(string.format("setVariableIfChanged(%s,%s,%s,%s)",serviceId, name, value, deviceId))
  local curValue = luup.variable_get(serviceId, name, tonumber(deviceId)) or ""
  value = value or ""
  if (tostring(curValue)~=tostring(value)) then
	luup.variable_set(serviceId, name, value, tonumber(deviceId))
  end
end

function setAttrIfChanged(name, value, deviceId)
  debug(string.format("setAttrIfChanged(%s,%s,%s)",name, value, deviceId))
  local curValue = luup.attr_get(name, deviceId)
  if ((value ~= curValue) or (curValue == nil)) then
	luup.attr_set(name, value, deviceId)
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

function UserMessage(text, mode)
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

function string:split(sep) -- from http://lua-users.org/wiki/SplitJoin	 : changed as consecutive delimeters was not returning empty strings
  return Split(self, sep)
  -- local sep, fields = sep or ":", {}
  -- local pattern = string.format("([^%s]+)", sep)
  -- self:gsub(pattern, function(c) fields[#fields+1] = c end)
  -- return fields
end


function string:template(variables)
  return (self:gsub('@(.-)@',
	function (key)
	  return tostring(variables[key] or '')
	end))
end

function string:trim()
  return self:match "^%s*(.-)%s*$"
end

------------------------------------------------
-- VERA Device Utils
------------------------------------------------

local function tablelength(T)
  local count = 0
  if (T~=nil) then
  for _ in pairs(T) do count = count + 1 end
  end
  return count
end

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
-- Communication TO ALTHUE system
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
		return 0,"failed to connect"
	elseif (code==401) then
		warning(string.format("Access requires a user/password: %d", code))
		return 0,"unauthorized access - 401"
	elseif (code~=200) then
		warning(string.format("http.request returned a bad code: %d", code))
		return 0,"unvalid return code:" .. code
	end

	-- everything looks good
	local data = table.concat(result)
	debug(string.format("request:%s",request))
	debug(string.format("code:%s",code))

	return json.decode(data) ,""
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

local function getTimezones(lul_device)
	-- /api/<username>/capabilities/timezones
	local data,msg = ALTHueHttpCall(lul_device,"GET","info/timezones")
	return data,msg
end

local function getLights(lul_device)
	local data,msg = ALTHueHttpCall(lul_device,"GET","lights")
	return data,msg
end

------------------------------------------------------------------------------------------------
-- Http handlers : Communication FROM ALTUI
-- http://192.168.1.5:3480/data_request?id=lr_ALTHUE_Handler&command=xxx
-- recommended settings in ALTUI: PATH = /data_request?id=lr_ALTHUE_Handler&mac=$M&deviceID=114
------------------------------------------------------------------------------------------------
function switch( command, actiontable)
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

  local deviceID = this_device or tonumber(lul_parameters["DeviceNum"] or findTHISDevice() )

  -- switch table
  local action = {

	  ["default"] =
	  function(params)
		return "default handler / not successful", "text/plain"
	  end
  }
  -- actual call
  lul_html , mime_type = switch(command,action)(lul_parameters)
  if (command ~= "home") and (command ~= "oscommand") then
	debug(string.format("lul_html:%s",lul_html or ""))
  end
  return (lul_html or "") , mime_type
end

------------------------------------------------
-- STARTUP Sequence
------------------------------------------------

function UserSetPowerTarget(lul_device,newTargetValue)
  lul_device = tonumber(lul_device)
  debug(string.format("UserSetPowerTarget(%s,%s)",lul_device,newTargetValue))
  local status = luup.variable_get("urn:upnp-org:serviceId:SwitchPower1", "Status", lul_device)
  if (status ~= newTargetValue) then
	local val = "ON";
	if (newTargetValue=="0") then
	  val = "OFF";
	end
	
	
	-- altid is the relay ID on the ALTHUE
	-- local childid = luup.devices[lul_device].id;
	-- prefix rl1W should be replaced by rl
	-- childid = string.gsub(childid, "1w", "")
	-- luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Status", newTargetValue, lul_device)
	-- local xmldata = ALTHueHttpCall(lul_device,"RL.cgx",childid.."="..val)
  else
	debug(string.format("UserSetPowerTarget(%s,%s) - same status, ignoring",lul_device,newTargetValue))
  end
end

function UserToggleState(lul_device)
  debug(string.format("UserToggleState(%s)",lul_device))
  local status = luup.variable_get("urn:upnp-org:serviceId:SwitchPower1", "Status", lul_device)
  status = 1-tonumber(status)
  UserSetPowerTarget(lul_device,tostring(status))
end

function getCurrentTemperature(lul_device)
  lul_device = tonumber(lul_device)
  debug(string.format("getCurrentTemperature(%d)",lul_device))
  return luup.variable_get("urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", lul_device)
end

local function loadALTHueData(lul_device,xmldata)
  debug(string.format("loadALTHueData(%s) xml=%s",lul_device,xmldata))
  return true
end

function refreshEngineCB(lul_device,norefresh)
  norefresh = norefresh or false
  debug(string.format("refreshEngineCB(%s,%s)",lul_device,tostring(norefresh)))
  lul_device = tonumber(lul_device)
  local period= getSetVariable(ALTHUE_SERVICE, "RefreshPeriod", lul_device, DEFAULT_REFRESH)

  local xmldata = nil --ALTHueHttpCall(lul_device,"")
  if (xmldata ~= nil) then
	loadALTHueData(lul_device,xmldata)
  else
	UserMessage(string.format("missing ip addr or credentials for device "..lul_device),TASK_ERROR_PERM)
  end

  debug(string.format("programming next refreshEngineCB(%s) in %s sec",lul_device,period))
  if (norefresh==false) then
	luup.call_delay("refreshEngineCB",period,tostring(lul_device))
  end
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

local function refreshData(lul_device)
  lul_device = tonumber(lul_device)
  debug(string.format("refreshData(%d)",lul_device))
  refreshEngineCB(lul_device,true)
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
	setVariableIfChanged(ALTHUE_SERVICE, "IconCode", 100, lul_device)
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

	local data,msg = getTimezones(lul_device)
	if ( (data==nil) or (tablelength(data)<1) ) then
		-- UserMessage(string.format("The plugin is not linked to your Hue Bridge. Proceed with pairing in settings page"),TASK_ERROR)
		return false
	end
	debug(string.format("getTimezones returns data: %s", json.encode(data)))
	
	if (data[1].error ~= nil) then
		warning("User is not registered to Philips Hue Bridge : " .. data[1].error.description);
		return false
	end
	
	debug(string.format("communication with Hue Bridge seems ok: %s", json.encode(data)))
	setVariableIfChanged(ALTHUE_SERVICE, "IconCode", 100, lul_device)
	return true
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

local function SyncLights(lul_device)
	debug(string.format("SyncLights(%s)",lul_device))
	local data,msg = getLights(lul_device)
	if (data~=nil) and (data["1"] ~=nil) then
		-- for all children device, iterate
		MapUID2Index={}
		local child_devices = luup.chdev.start(lul_device);
		for k,v in pairs(data) do
			local idx = tonumber(k)
			luup.chdev.append(
				lul_device, child_devices,
				v.uniqueid,					-- children map index is altid
				NAME_PREFIX..v.name,		-- children map name attribute is device name
				"urn:schemas-upnp-org:device:BinaryLight:1",	-- children device type
				"D_BinaryLight1.xml",		-- children D-file
				"", 						-- children I-file
				"",							-- params
				false						-- not embedded
			)
			MapUID2Index[ v.uniqueid ]=k
		end
		luup.chdev.sync(lul_device, child_devices)	
	end
	debug(string.format("MapUID2Index is: %s",json.encode(MapUID2Index)))
	for k,v in pairs(data) do
		local childId,child = findChild( lul_device, v.uniqueid )
		setAttrIfChanged("name", NAME_PREFIX..v.name, childId)
		setAttrIfChanged("manufacturer", v.manufacturername, childId)
		setAttrIfChanged("model", v.modelid, childId)
	end
	return data,msg
end

local function startEngine(lul_device)
	debug(string.format("startEngine(%s)",lul_device))
	lul_device = tonumber(lul_device)

	local data,msg = getHueConfig(lul_device)
	if (data == nil) then
		-- Get Hue Config failed
		UserMessage(string.format("Not able to reach the Hue Bridge (missing ip addr in attributes ?, device:%s, msg:%s",lul_device,msg),TASK_ERROR)
		return false
	end
	debug(string.format("return data: %s", json.encode(data)))
	setAttrIfChanged("manufacturer", data.name, lul_device)
	setAttrIfChanged("model", data.modelid, lul_device)
	setAttrIfChanged("mac", data.mac, lul_device)
	setAttrIfChanged("name", data.name, lul_device)

	if (PairWithHue(lul_device)) then
		data,msg = SyncLights(lul_device)
		-- todo , set the attributes, set the states
	end
	return true
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
  -- local ipaddr = luup.attr_get ('ip', lul_device )

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
		log ("Version upgrade => Reseting Plugin config to default and FTP uploading the *.CGX file on the ALTHUE server")

	  end
	else
	  log ("New installation")
	end
	luup.variable_set(ALTHUE_SERVICE, "Version", version, lul_device)
  end

  -- start handlers
  -- createChildren(lul_device)
  -- start engine
  local success = false
  success = startEngine(lul_device)

  -- NOTHING to start
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
  end
  if( luup.version_branch == 1 and luup.version_major == 7 and ui7Check == "false") then
	luup.variable_set(ALTHUE_SERVICE, "UI7Check", "true", lul_device)
	luup.attr_set("device_json", UI7_JSON_FILE, lul_device)
	luup.reload()
  end
end

function initstatus(lul_device)
  lul_device = tonumber(lul_device)
  this_device = lul_device
  log("initstatus("..lul_device..") starting version: "..version)
  checkVersion(lul_device)
  hostname = getIP()
  local delay = 1	-- delaying first refresh by x seconds
  debug("initstatus("..lul_device..") startup for Root device, delay:"..delay)
  luup.call_delay("startupDeferred", delay, tostring(lul_device))
end

-- do not delete, last line must be a CR according to MCV wiki page
