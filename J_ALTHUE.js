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
// ALTHUE  Plugin javascript Tabs
//-------------------------------------------------------------

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

var myapi = window.api || null
var ALTHUE = (function(api,$) {
	var ALTHUE_Svs = 'urn:upnp-org:serviceId:althue1';

	//-------------------------------------------------------------
	// Device TAB : Dump Json
	//-------------------------------------------------------------	
	function ALTHUE_Dump(deviceID) {
		var url = ALTHUE.buildHandlerUrl(deviceID,"config","")
		$.get(url).done(function(data) {
			var html=''
			var html = '<pre>'+JSON.stringify(data,null,2)+'</pre>';
			set_panel_html(html);
		})
	};
	
	//-------------------------------------------------------------
	// Device TAB : Info
	//-------------------------------------------------------------	
	function ALTHUE_Information(deviceID) {
		var url = ALTHUE.buildHandlerUrl(deviceID,"config",{url:''})
		$.get(url).done(function(data) {
			var model = []
			jQuery.each( data.lights || [], function(idx,light) {
				model.push({
					id:idx,
					type: light.type,
					name: light.name,
					manufacturer:light.manufacturername,
					model: light.modelid,
					swversion:light.swversion,
					reachable:light.state.reachable,
				})
			})
			var html = ALTHUE.array2Table(model,'id',[],'My Hue Lights','ALTHue-cls','ALTHue-lightstbl',false)

			model = []
			jQuery.each( data.sensors || [], function(idx,item) {
				model.push({
					id:idx,
					type: item.type,
					name: item.name,
					manufacturer:item.manufacturername,
					model: item.modelid,
					swversion:item.swversion,
					lastupdated:item.state.lastupdated,
				})
			})
			html += ALTHUE.array2Table(model,'id',[],'My Hue Sensors','ALTHue-cls','ALTHue-sensorstbl',false)

			set_panel_html(html);
		})
	};
	
	//-------------------------------------------------------------
	// Device TAB : Applications
	//-------------------------------------------------------------	
	function ALTHUE_Applications(deviceID) {
		ALTHUE.get_device_state_async(deviceID,  ALTHUE.ALTHUE_Svs, 'Credentials', function(credentials) {
			var url = ALTHUE.buildHandlerUrl(deviceID,"config",{url:'config'})
			$.get(url).done(function(data) {
				var model = []
				jQuery.each( data.whitelist || [], function(idx,app) {
					model.push({
						name: app.name,
						// key: idx,
						lastuse: app["last use date"],
						create: app["create date"],
						del: (idx==credentials) ? '' : '<button data-idx="{0}" class="btn btn-sm althue-delapp"> <i  class="fa fa-trash-o text-danger" aria-hidden="true" title="Delete"></i> Del</button>'.format(idx)
					})
				})
				var html = ALTHUE.array2Table(model,'id',[],'My Hue Apps','ALTHue-cls','ALTHue-appstbl',false)
				set_panel_html(html);
				jQuery(".althue-delapp").click(function(e){
					var id = jQuery(this).data('idx');
					var url = ALTHUE.buildHandlerUrl(deviceID,"deleteUserID",{oldcredentials:id})
				})
			})
		});
	};
	
	//-------------------------------------------------------------
	// Device TAB : Settings
	//-------------------------------------------------------------	

	function ALTHUE_Settings(deviceID) {
		ALTHUE.get_device_state_async(deviceID,  ALTHUE.ALTHUE_Svs, 'Credentials', function(credentials) {
			// var credentials = get_device_state(deviceID,  ALTHUE.ALTHUE_Svs, 'Credentials',1);
			var debug  = get_device_state(deviceID,  ALTHUE.ALTHUE_Svs, 'Debug',1);
			var linkok = ((credentials !="" ) && (credentials != null)) ? 1 : 0;
			var map = [
				{btnText:"Pair", bgColor:"bg-danger", txtHelp:"Press Hue Link button"},
				{btnText:"Unpair", bgColor:"bg-success", txtHelp:"Pairing Success"},			
			];
			var poll = get_device_state(deviceID,  ALTHUE.ALTHUE_Svs, 'RefreshPeriod',1);
			var ip_address = jsonp.ud.devices[ALTHUE.findDeviceIdx(deviceID)].ip;
			var configs = [
				{ name: "NamePrefix", label: "Prefix for names" , placeholder: "Prefix or empty"},
			];
			var htmlip = '\
					<label for="althue-ipaddr">IP Addr</label>		\
					<div class="input-group">\
					  <input type="text" class="form-control" id="althue-ipaddr" placeholder="xx.xx.xx.xx">\
					  <div class="input-group-append">\
						<button id="althue-discovery-btn" class="btn btn-outline-secondary dropdown-toggle" type="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">Discovery meethue.com</button>\
						<div class="dropdown-menu">\
						</div>\
					  </div>\
					</div>'
			var htmlpolling = '\
				<label for="althue-RefreshPeriod">Polling in sec</label>			\
				<div><input type="number" min="1" max="600" class="form-control" id="althue-RefreshPeriod" placeholder="5"></div>'	
			var htmlpairstatus = '\
				<label for="althue-linkstatus">Link Status</label>		\
				<div class="form-row"> \
					<div id="althue-linkstatus" class="col-6 '+map[linkok].bgColor+'"> \
						<div id="althue-linkstatus-txt">'+map[linkok].txtHelp+'</div>	\
					</div> \
					<div class="col-6"> \
						<button type="button" id="althue-linkaction" class="btn btn-sm btn-secondary">'+map[linkok].btnText+'</button>	\
					</div> \
				</div>'
			var prefix = get_device_state(deviceID,  ALTHUE.ALTHUE_Svs, "NamePrefix",1);
			var htmlprefix = '\
				<label for="althue-NamePrefix">Prefix for names</label>		\
				<div><input type="text" class="form-control" id="althue-NamePrefix" placeholder="Prefix or empty" value="{0}"></div>'.format(prefix)
			var html = '<style>.bg-success { background-color: #28a745!important; } .bg-danger { background-color: #dc3545!important; }</style>'
			html +='<table class="table">'
			html += '<thead><tr><td></td><td></td></tr><thead>'
			html += '<tbody>'
			html += '<tr>'
			html += '<td>{0}</td>'.format(htmlip)
			html += '<td>{0}</td>'.format(htmlpolling)
			html += '</tr>'
			html += '<tr>'
			html += '<td>{0}</td>'.format(htmlpairstatus)
			html += '<td>{0}</td>'.format(htmlprefix)
			html += '</tr>'
			html += '</tbody>'
			html += '</table>'
	
			set_panel_html(html);
			jQuery.get("https://www.meethue.com/api/nupnp").done( function(data) {
				var dropdown = jQuery("#althue-discovery-btn").parent().find("div.dropdown-menu")
				jQuery.each(data, function(idx,item) {
					jQuery(dropdown).append( '<a class="althue-ipselect dropdown-item" href="javascript:void(0);">{0} {1} {2}</a>'.format(item.internalipaddress,item.name||'', item.macaddress|| '') )
				})
				jQuery('.althue-ipselect').click(function(e) {
					var ip = jQuery(this).text();
					jQuery("#althue-ipaddr").val(ip).trigger('change');
				});
			})
			jQuery( "#althue-linkstatus").height(29);			// required in UI7 
			jQuery( "#althue-linkstatus").data('status',linkok); 
			jQuery( "#althue-ipaddr" ).val(ip_address).change( function(e) {
				var ip_address = jQuery( "#althue-ipaddr" ).val().trim()
				if (ALTHUE.goodip(ip_address)) {
					ALTHUE.saveVar( deviceID,  null , "ip", ip_address, 0 )
				}
			})
			jQuery( "#althue-RefreshPeriod" ).val(poll);
			jQuery( "#althue-linkaction").click( function(e) {
				ALTHUE.get_device_state_async(deviceID,  ALTHUE.ALTHUE_Svs, 'Credentials', function(credentials) {
					var action = (credentials!="") ? "UnpairWithHue" : "PairWithHue";
					var url = ALTHUE.buildUPnPActionUrl(deviceID,ALTHUE.ALTHUE_Svs,action)
					jQuery("#althue-linkaction").text("...")
					jQuery("#althue-linkaction").addClass("disabled")
					jQuery.ajax({
						type: "GET",
						url: url,
						cache: false,
					}).done( function(data) {
						// get real value
						ALTHUE.get_device_state_async(deviceID,  ALTHUE.ALTHUE_Svs, 'Credentials', function(credentials) {
							var oldlinkok = jQuery( "#althue-linkstatus").data('status'); 
							var linkok = ((credentials !="" ) && (credentials != null)) ? 1 : 0;
							if (oldlinkok==linkok) {
								// nochanges
								alert("The operation did not succeed");
							}
							jQuery( "#althue-linkstatus").removeClass("bg-danger bg-success").addClass(map[linkok].bgColor)
							jQuery( "#althue-linkstatus").data('status',linkok); 
							jQuery( "#althue-linkaction").text(map[linkok].btnText)
							jQuery( "#althue-linkstatus-txt").text(map[linkok].txtHelp)
						})
						jQuery("#althue-linkaction").removeClass("disabled")
					})
					.fail(function() {
						alert('Action Failed!');
						jQuery("#althue-linkaction").removeClass("disabled")
					});
				})
			});
			
			jQuery( "#althue-settings-form" ).on("submit", function(event) {
				var bReload = true;
				event.preventDefault();
				var ip_address = jQuery( "#althue-ipaddr" ).val();
				var poll = jQuery( "#althue-RefreshPeriod" ).val();

				if (ALTHUE.goodip(ip_address)) {
					ALTHUE.saveVar( deviceID,  ALTHUE.ALTHUE_Svs, "RefreshPeriod", poll, 0 )
					ALTHUE.saveVar( deviceID,  null , "ip", ip_address, 0 )
					jQuery.each( configs, function(idx,obj) {
						var val = jQuery("#althue-"+obj.name).val();
						bReload = bReload && ALTHUE.save( deviceID,  ALTHUE.ALTHUE_Svs, obj.name, val, jQuery.isFunction(obj.func) ? obj.func : null, 0 )
					});
				} else {
					alert("Invalid IP address")
					bReload = false;
				}
				
				if (bReload) {
					jQuery.get(data_request_url+"id=reload");
					alert("Now reloading Luup engine for the changes to be effective");
				}
				return false;
			})
		});
	};
	
	var myModule = {
		ALTHUE_Svs 	: ALTHUE_Svs,
		Dump 		: ALTHUE_Dump,
		Settings 	: ALTHUE_Settings,
		Information : ALTHUE_Information,
		Applications: ALTHUE_Applications,
		
		//-------------------------------------------------------------
		// Helper functions to build URLs to call VERA code from JS
		//-------------------------------------------------------------

		buildAttributeSetUrl : function( deviceID, varName, varValue){
			var urlHead = '' + data_request_url + 'id=variableset&DeviceNum='+deviceID+'&Variable='+varName+'&Value='+varValue;
			return urlHead;
		},

		buildUPnPActionUrl : function(deviceID,service,action,params)
		{
			var urlHead = data_request_url +'id=action&output_format=json&DeviceNum='+deviceID+'&serviceId='+service+'&action='+action;//'&newTargetValue=1';
			if (params != undefined) {
				jQuery.each(params, function(index,value) {
					urlHead = urlHead+"&"+index+"="+value;
				});
			}
			return urlHead;
		},

		buildHandlerUrl: function(deviceID,command,params)
		{
			//http://192.168.1.5:3480/data_request?id=lr_IPhone_Handler
			params = params || []
			var urlHead = data_request_url +'id=lr_ALTHUE_Handler&command='+command+'&DeviceNum='+deviceID;
			jQuery.each(params, function(index,value) {
				urlHead = urlHead+"&"+index+"="+encodeURIComponent(value);
			});
			return encodeURI(urlHead);
		},

		//-------------------------------------------------------------
		// Variable saving 
		//-------------------------------------------------------------
		saveVar : function(deviceID,  service, varName, varVal, reload) {
			if (service) {
				set_device_state(deviceID, service, varName, varVal, 0);	// lost in case of luup restart
			} else {
				jQuery.get( this.buildAttributeSetUrl( deviceID, varName, varVal) );
			}
		},
		save : function(deviceID, service, varName, varVal, func, reload) {
			// reload is optional parameter and defaulted to false
			if (typeof reload === "undefined" || reload === null) { 
				reload = false; 
			}

			if ((!func) || func(varVal)) {
				//set_device_state(deviceID,  ipx800_Svs, varName, varVal);
				this.saveVar(deviceID,  service, varName, varVal, reload)
				jQuery('#althue-' + varName).css('color', 'black');
				return true;
			} else {
				jQuery('#althue-' + varName).css('color', 'red');
				alert(varName+':'+varVal+' is not correct');
			}
			return false;
		},
		
		get_device_state_async: function(deviceID,  service, varName, func ) {
			// var dcu = data_request_url.sub("/data_request","")	// for UI5 as well as UI7
			var url = data_request_url+'id=variableget&DeviceNum='+deviceID+'&serviceId='+service+'&Variable='+varName;	
			jQuery.get(url)
			.done( function(data) {
				if (jQuery.isFunction(func)) {
					(func)(data)
				}
			})
		},
		
		findDeviceIdx:function(deviceID) 
		{
			//jsonp.ud.devices
			for(var i=0; i<jsonp.ud.devices.length; i++) {
				if (jsonp.ud.devices[i].id == deviceID) 
					return i;
			}
			return null;
		},
		
		goodip : function(ip) {
			// @duiffie contribution
			var reg = new RegExp('^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(:\\d{1,5})?$', 'i');
			return(reg.test(ip));
		},
		
		array2Table : function(arr,idcolumn,viscols,caption,cls,htmlid,bResponsive) {
			var html="";
			var idcolumn = idcolumn || 'id';
			var viscols = viscols || [idcolumn];
			var responsive = ((bResponsive==null) || (bResponsive==true)) ? 'table-responsive-OFF' : ''

			if ( (arr) && ($.isArray(arr) && (arr.length>0)) ) {
				var display_order = [];
				var keys= Object.keys(arr[0]);
				$.each(viscols,function(k,v) {
					if ($.inArray(v,keys)!=-1) {
						display_order.push(v);
					}
				});
				$.each(keys,function(k,v) {
					if ($.inArray(v,viscols)==-1) {
						display_order.push(v);
					}
				});

				var bFirst=true;
				html+="<table id='{1}' class='table {2} table-sm table-hover table-striped {0}'>".format(cls || '', htmlid || 'altui-grid' , responsive );
				if (caption)
					html += "<caption>{0}</caption>".format(caption)
				$.each(arr, function(idx,obj) {
					if (bFirst) {
						html+="<thead>"
						html+="<tr>"
						$.each(display_order,function(_k,k) {
							html+="<th style='text-transform: capitalize;' data-column-id='{0}' {1} {2}>".format(
								k,
								(k==idcolumn) ? "data-identifier='true'" : "",
								"data-visible='{0}'".format( $.inArray(k,viscols)!=-1 )
							)
							html+=k;
							html+="</th>"
						});
						html+="</tr>"
						html+="</thead>"
						html+="<tbody>"
						bFirst=false;
					}
					html+="<tr>"
					$.each(display_order,function(_k,k) {
						html+="<td>"
						html+=(obj[k]!=undefined) ? obj[k] : '';
						html+="</td>"
					});
					html+="</tr>"
				});
				html+="</tbody>"
				html+="</table>";
			}
			else
				html +="<div>{0}</div>".format("No data to display")

			return html;		
		}
	}
	return myModule;
})(myapi ,jQuery)

	
//-------------------------------------------------------------
// Device TAB : Donate
//-------------------------------------------------------------	
function ALTHUE_Donate(deviceID) {
	var htmlDonate='For those who really like this plugin and feel like it, you can donate what you want here on Paypal. It will not buy you more support not any garantee that this can be maintained or evolve in the future but if you want to show you are happy and would like my kids to transform some of the time I steal from them into some <i>concrete</i> returns, please feel very free ( and absolutely not forced to ) to donate whatever you want.  thank you ! ';
	htmlDonate+='<form action="https://www.paypal.com/cgi-bin/webscr" method="post" target="_blank"><input type="hidden" name="cmd" value="_donations"><input type="hidden" name="business" value="alexis.mermet@free.fr"><input type="hidden" name="lc" value="FR"><input type="hidden" name="item_name" value="Alexis Mermet"><input type="hidden" name="item_number" value="althue"><input type="hidden" name="no_note" value="0"><input type="hidden" name="currency_code" value="EUR"><input type="hidden" name="bn" value="PP-DonationsBF:btn_donateCC_LG.gif:NonHostedGuest"><input type="image" src="https://www.paypalobjects.com/en_US/FR/i/btn/btn_donateCC_LG.gif" border="0" name="submit" alt="PayPal - The safer, easier way to pay online!"><img alt="" border="0" src="https://www.paypalobjects.com/fr_FR/i/scr/pixel.gif" width="1" height="1"></form>';
	var html = '<div>'+htmlDonate+'</div>';
	set_panel_html(html);
}

//-------------------------------------------------------------
// UI5 helpers
//-------------------------------------------------------------	
function ALTHUE_Dump(deviceID) { 
	return ALTHUE.Dump(deviceID)
}

function ALTHUE_Settings(deviceID) {
	return ALTHUE.Settings(deviceID)
}

function ALTHUE_Information(deviceID) {
	return ALTHUE.Information(deviceID)
}

function ALTHUE_Applications(deviceID) {
	return ALTHUE.Applications(deviceID)
}




