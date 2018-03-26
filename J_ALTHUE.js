//# sourceURL=J_ALTHUE.js
// This program is free software: you can redistribute it and/or modify
// it under the condition that it is for private or home useage and 
// this whole comment is reproduced in the source code file.
// Commercial utilisation is not authorized without the appropriate
// written agreement from amg0 / alexis . mermet @ gmail . com
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

//-------------------------------------------------------------
// wes  Plugin javascript Tabs
//-------------------------------------------------------------
var ALTHUE_Svs = 'urn:upnp-org:serviceId:althue1';
var ip_address = data_request_url;

function goodip(ip)
{
	// @duiffie contribution
	var reg = new RegExp('^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(:\\d{1,5})?$', 'i');
	return(reg.test(ip));
}

if (typeof String.prototype.format == 'undefined') {
	String.prototype.format = function()
	{
		var args = new Array(arguments.length);

		for (var i = 0; i < args.length; ++i) {
			// `i` is always valid index in the arguments object
			// so we merely retrieve the value
			args[i] = arguments[i];
		}

		return this.replace(/{(\d+)}/g, function(match, number) { 
			return typeof args[number] != 'undefined' ? args[number] : match;
		});
	};
};

function findDeviceIdx(deviceID) 
{
	//jsonp.ud.devices
    for(var i=0; i<jsonp.ud.devices.length; i++) {
        if (jsonp.ud.devices[i].id == deviceID) 
			return i;
    }
	return null;
}

//-------------------------------------------------------------
// Device TAB : Donate
//-------------------------------------------------------------	
function ALTHUE_Donate(deviceID) {
	var htmlDonate='For those who really like this plugin and feel like it, you can donate what you want here on Paypal. It will not buy you more support not any garantee that this can be maintained or evolve in the future but if you want to show you are happy and would like my kids to transform some of the time I steal from them into some <i>concrete</i> returns, please feel very free ( and absolutely not forced to ) to donate whatever you want.  thank you ! ';
	htmlDonate+='<form action="https://www.paypal.com/cgi-bin/webscr" method="post" target="_top"><input type="hidden" name="cmd" value="_donations"><input type="hidden" name="business" value="alexis.mermet@free.fr"><input type="hidden" name="lc" value="FR"><input type="hidden" name="item_name" value="Alexis Mermet"><input type="hidden" name="item_number" value="althue"><input type="hidden" name="no_note" value="0"><input type="hidden" name="currency_code" value="EUR"><input type="hidden" name="bn" value="PP-DonationsBF:btn_donateCC_LG.gif:NonHostedGuest"><input type="image" src="https://www.paypalobjects.com/en_US/FR/i/btn/btn_donateCC_LG.gif" border="0" name="submit" alt="PayPal - The safer, easier way to pay online!"><img alt="" border="0" src="https://www.paypalobjects.com/fr_FR/i/scr/pixel.gif" width="1" height="1"></form>';
	var html = '<div>'+htmlDonate+'</div>';
	set_panel_html(html);
}

//-------------------------------------------------------------
// Device TAB : Settings
//-------------------------------------------------------------	

function ALTHUE_Settings(deviceID) {
	get_device_state_async(deviceID,  ALTHUE_Svs, 'Credentials', function(credentials) {
		// var credentials = get_device_state(deviceID,  ALTHUE_Svs, 'Credentials',1);
		var debug  = get_device_state(deviceID,  ALTHUE_Svs, 'Debug',1);
		var linkok = (credentials !="" ) && (credentials != null)
		var poll = get_device_state(deviceID,  ALTHUE_Svs, 'RefreshPeriod',1);
		var ip_address = jsonp.ud.devices[findDeviceIdx(deviceID)].ip;
		var configs = [
			// { name: "UserFTP", label: "User pour FTP" , placeholder: "doit etre configure sur le ALTHUE, par default adminftp"},
			// { name: "PasswordFTP", type:"password", label: "Password pour FTP" , placeholder: "doit etre configure sur le ALTHUE, par default wesftp"},
			{ name: "NamePrefix", label: "Prefix pour les noms" , placeholder: "Prefix ou vide"},
			// { name: "AnalogClamps", label: "Pinces Analogiques" , placeholder: "comma separated list of indexes" , func: goodcsv},
			// { name: "AnalogInputs", label: "Inputs Analogiques" , placeholder: "comma separated list of indexes", func: goodcsv},
			// { name: "Relais1W", label: "Relais 1Wire" , placeholder: "comma separated list of relais number", func: goodcsv},
			// { name: "PulseCounters", label: "Compteurs Impulsion" , placeholder: "comma separated list of indexes", func: goodcsv},
			// { name: "TempSensors", label: "Senseurs de Température" , placeholder: "comma separated list of indexes", func: goodcsv},
			// { name: "VirtualSwitches", label: "Switch Virtuels" , placeholder: "comma separated list of indexes", func: goodcsv}
		];

		var htmlConfigs = "";
		jQuery.each( configs, function(idx,obj) {
			var value = get_device_state(deviceID,  ALTHUE_Svs, obj.name,1);
			htmlConfigs += '	\
						<div class="form-group col-xs-6 col-6">																	\
							<label for="althue-{0}">{1}</label>		\
							<input type="{3}" class="form-control" id="althue-{0}" placeholder="{2}" value="{4}">	\
						</div>																										\
			'.format(
				obj.name,
				obj.label,
				obj.placeholder,
				obj.type || "text",
				value
			);
		});
		var html =
		'                                                           \
		  <div id="althue-settings row">                                           \
			<form class="" id="althue-settings-form">                        \
						<div class="form-row"> \
							<div class="form-group col-xs-6 col-6">																	\
								<label for="althue-ipaddr">IP Addr</label>		\
								<input type="text" class="form-control" id="althue-ipaddr" placeholder="xx.xx.xx.xx">	\
							</div>																										\
							<div class="form-group col-xs-6 col-6">																	\
								<label for="althue-RefreshPeriod">Polling in sec</label>			\
								<input type="number" min="1" max="600" class="form-control" id="althue-RefreshPeriod" placeholder="5">	\
							</div> 																								\
						</div> 																								\
						<div class="form-row"> \
							<div class="form-group col-xs-6 col-6">																	\
								<label for="althue-username">Link Status</label>		\
								<div class="form-row"> \
									<div id="althue-linkstatus" class="col-4 '+(linkok ? 'bg-success' : 'bg-danger')+'"> \
										<div></div>	\
									</div> \
									<div class="col-8"> \
										<button type="button" id="althue-linkaction" class="btn btn-secondary">Test</button>	\
									</div> \
								</div> \
							</div>			\																							\
						</div>			\																							\
						<div class="form-row"> \
							'+htmlConfigs+'																							\
						</div>			\																							\
						<div class="form-row"> \
							<div class="form-group col-xs-12 col-12">																	\
								<button id="althue-submit" type="submit" class="btn btn-primary">Submit</button>	\
							</div>																										\
						</div>																										\
					</form>                                                 \
		  </div>                                                    \
		'		
		set_panel_html(html);
		jQuery( "#althue-linkstatus").height(29);			// required in UI7 
		jQuery( "#althue-ipaddr" ).val(ip_address);
		jQuery( "#althue-username" ).val(credentials);
		jQuery( "#althue-RefreshPeriod" ).val(poll);
		jQuery( "#althue-linkaction").click( function(e) {
			get_device_state_async(deviceID,  ALTHUE_Svs, 'Credentials', function(credentials) {
				var action = (credentials!="") ? "UnpairWithHue" : "PairWithHue";
				var url = buildUPnPActionUrl(deviceID,ALTHUE_Svs,action)
				jQuery("#althue-linkaction").addClass("disabled")
				jQuery.ajax({
					type: "GET",
					url: url,
					cache: false,
				}).done( function(data) {
					// get real value
					get_device_state_async(deviceID,  ALTHUE_Svs, 'Credentials', function(credentials) {
						var linkok = (credentials !="" ) && (credentials != null)
						jQuery( "#althue-linkstatus").removeClass("bg-danger bg-success").addClass(linkok ? 'bg-success' : 'bg-danger')
					})
				})
				.fail(function() {
					alert('Action Failed!');
				})
				.always(function(){
					jQuery("#althue-linkaction").removeClass("disabled")
				});
			})
		});
		
		jQuery( "#althue-settings-form" ).on("submit", function(event) {
			var bReload = true;
			event.preventDefault();
			var ip_address = jQuery( "#althue-ipaddr" ).val();
			var usr = jQuery( "#althue-username" ).val();
			// var pwd = jQuery( "#althue-pwd" ).val();
			var poll = jQuery( "#althue-RefreshPeriod" ).val();
			
			// var encode = btoa( "{0}:{1}".format(usr,pwd) );
			if (goodip(ip_address)) {
				// saveVar( deviceID,  ALTHUE_Svs, "Credentials", usr, 0 )
				saveVar( deviceID,  ALTHUE_Svs, "RefreshPeriod", poll, 0 )
				saveVar( deviceID,  null , "ip", ip_address, 0 )
				jQuery.each( configs, function(idx,obj) {
					var val = jQuery("#althue-"+obj.name).val();
					bReload = bReload && save( deviceID,  ALTHUE_Svs, obj.name, val, jQuery.isFunction(obj.func) ? obj.func : null, 0 )
				});
			} else {
				alert("Invalid IP address")
				bReload = false;
			}
			
			if (bReload) {
				jQuery.get(data_request_url+"id=reload");
				alert("Now reloading Luup engine for the changes to be effective");
			}
			// http://ip_address:3480/data_request?id=reload
			return false;
		})
	});
}


//-------------------------------------------------------------
// Variable saving 
//-------------------------------------------------------------
function get_device_state_async(deviceID,  service, varName, func ) {
	var url = data_command_url+'id=variableget&DeviceNum='+deviceID+'&serviceId='+service+'&Variable='+varName;
	jQuery.get(url)
	.done( function(data) {
		if (jQuery.isFunction(func)) {
			(func)(data)
		}
	})
}

function save(deviceID, service, varName, varVal, func, reload) {
	// reload is optional parameter and defaulted to false
	if (typeof reload === "undefined" || reload === null) { 
		reload = false; 
	}

    if ((!func) || func(varVal)) {
        //set_device_state(deviceID,  ipx800_Svs, varName, varVal);
		saveVar(deviceID,  service, varName, varVal, reload)
        jQuery('#althue-' + varName).css('color', 'black');
		return true;
    } else {
        jQuery('#althue-' + varName).css('color', 'red');
		alert(varName+':'+varVal+' is not correct');
    }
	return false;
}

function saveVar(deviceID,  service, varName, varVal, reload)
{
	if (service) {
		set_device_state(deviceID, service, varName, varVal, 0);	// lost in case of luup restart
	} else {
		jQuery.get( buildAttributeSetUrl( deviceID, varName, varVal) );
	}
}

function goodcsv(v)
{
	var reg = new RegExp('^[0-9]*(,[0-9]+)*$', 'i');
	return(reg.test(v));
}

//-------------------------------------------------------------
// Helper functions to build URLs to call VERA code from JS
//-------------------------------------------------------------

function buildAttributeSetUrl( deviceID, varName, varValue)
{
	var urlHead = '' + ip_address + 'id=variableset&DeviceNum='+deviceID+'&Variable='+varName+'&Value='+varValue;
	return urlHead;
}

function buildUPnPActionUrl(deviceID,service,action,params)
{
	var urlHead = ip_address +'id=action&output_format=json&DeviceNum='+deviceID+'&serviceId='+service+'&action='+action;//'&newTargetValue=1';
	if (params != undefined) {
		jQuery.each(params, function(index,value) {
			urlHead = urlHead+"&"+index+"="+value;
		});
	}
	return urlHead;
}

function buildHandlerUrl(deviceID,command,params)
{
	//http://192.168.1.5:3480/data_request?id=lr_IPhone_Handler
	var urlHead = ip_address +'id=lr_ALTHUE_Handler&command='+command+'&DeviceNum='+deviceID;
	jQuery.each(params, function(index,value) {
		urlHead = urlHead+"&"+index+"="+encodeURIComponent(value);
	});
	return encodeURI(urlHead);
}

