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

var myapi = window.api || null
var ALTHUE = (function(api,$) {
	var ALTHUE_Svs = 'urn:upnp-org:serviceId:althue1';
	jQuery("body").prepend("<style>.ALTHue-cls { width:100%; }</style>")

	function format(str)
	{
	   var content = str;
	   for (var i=1; i < arguments.length; i++)
	   {
			var replacement = new RegExp('\\{' + (i-1) + '\\}', 'g');	// regex requires \ and assignment into string requires \\,
			// if ($.type(arguments[i]) === "string")
				// arguments[i] = arguments[i].replace(/\$/g,'$');
			content = content.replace(replacement, arguments[i]);  
	   }
	   return content;
	};

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
		function setHtml(deviceID) {
			var url = ALTHUE.buildHandlerUrl(deviceID,"config",{url:''})
			$.get(url).done(function(data) {
				var model = []
				var tblEffects = [ 'none', 'colorloop' ]
				jQuery.each( data.lights || [], function(idx,light) {
					var btnEffect = "";
					if (light.state.effect) {
						var idxeffect = tblEffects.indexOf(light.state.effect)
						if (idxeffect!=-1) {
							btnEffect = ALTHUE.format('<button data-uid="{0}" data-neweffect="{2}" class="btn btn-xs althue-chgeffect"> <i  class="fa fa-play" aria-hidden="true" title="{2}"></i> {2}</button>',light.uniqueid,light.state.effect,tblEffects[ 1-idxeffect ])
						}
					}
					model.push({
						id:idx,
						type: light.type,
						name: light.name,
						model: ALTHUE.format("{0} {1}",light.manufacturername,light.modelid),
						swversion:light.swversion,
						reachable:light.state.reachable,
						effect: btnEffect
					})
				})
				var html = ALTHUE.array2Table(model,'id',[],'My Hue Lights','ALTHue-cls','ALTHue-lightstbl',false)
				model = []
				jQuery.each( data.sensors || [], function(idx,item) {
					model.push({
						id:idx,
						type: item.type,
						name: item.name,
						model: ALTHUE.format("{0} {1}",item.manufacturername,item.modelid),
						swversion:item.swversion,
						lastupdated:item.state.lastupdated,
					})
				})
				html += ALTHUE.array2Table(model,'id',[],'My Hue Sensors','ALTHue-cls','ALTHue-sensorstbl',false)
				set_panel_html(html);
				jQuery(".althue-chgeffect").click(function(e){
					var uid = jQuery(this).data('uid');
					var url = ALTHUE.buildHandlerUrl(deviceID,"setColorEffect",{hueuid:uid, effect:$(this).text().trim()})
					$.get(url).done(function(data) {
						setHtml(deviceID);
					}) .fail( function() {
						alert("action did not complete successfully");
					})
				})
			})
		}
		setHtml(deviceID);
	};
	
	//-------------------------------------------------------------
	// Device TAB : Applications
	//-------------------------------------------------------------	
	function ALTHUE_Scenes(deviceID) {
		
		function formatLights(arr,lights) {
			var names=[]
			jQuery.map(arr, function(elem,idx) {
				names.push(lights[ elem ].name)
			});
			return names.join(",")
		};
		function sortByName(a,b) {
			return (a.elem.name < b.elem.name ) ? -1 : ( (a.elem.name == b.elem.name ) ? 0 : 1 )
		};
		ALTHUE.get_device_state_async(deviceID,  ALTHUE.ALTHUE_Svs, 'Credentials', function(credentials) {
			var url = ALTHUE.buildHandlerUrl(deviceID,"config",{url:''})
			$.get(url).done(function(data) {
				var model = []
				var arr = $.map(data.scenes || [] , function(elem,idx) {
					return {id:idx,elem:elem}
				});
				jQuery.each( arr.sort(sortByName), function(idx,scene) {
					model.push({
						name:ALTHUE.format("<span title='{1}'>{0}</span>",scene.elem.name,scene.id),
						lights: formatLights( scene.elem.lights, data.lights ),
						lastupdated:scene.elem.lastupdated,
						id:scene.id,
						run: ALTHUE.format('<button data-idx="{0}" class="btn btn-sm althue-runscene"> <i  class="fa fa-play" aria-hidden="true" title="Run"></i> Run</button>',scene.id)
					})
				})
				var html = ALTHUE.array2Table(model,'id',[],'My Hue Scenes','ALTHue-cls','ALTHue-scenestbl',false)
				set_panel_html(html);
				jQuery(".althue-runscene").click(function(e){
					
					var id = jQuery(this).data('idx');
					var that = jQuery(this);
					// var url = ALTHUE.buildHandlerUrl(deviceID,"runScene",{sceneid:id});
					var url = ALTHUE.buildUPnPActionUrl(deviceID,ALTHUE.ALTHUE_Svs,"RunHueScene",{hueSceneID:id})
					$.get(url).fail( function() {
						alert("action did not complete successfully")
					})
				})
			});
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
						name: ALTHUE.format('<span title="{1}">{0}</span>',app.name,idx),
						// key: idx,
						lastuse: app["last use date"],
						create: app["create date"],
						del: (idx==credentials) ? '' : ALTHUE.format('<button data-idx="{0}" class="btn btn-sm althue-delapp"> <i  class="fa fa-trash-o text-danger" aria-hidden="true" title="Delete"></i> Del</button>',idx)
					})
				})
				var html = ALTHUE.array2Table(model,'name',[],'My Hue Apps','ALTHue-cls','ALTHue-appstbl',false)
				set_panel_html(html);
				jQuery(".althue-delapp").click(function(e){
					var id = jQuery(this).data('idx');
					var that = jQuery(this)
					var url = ALTHUE.buildHandlerUrl(deviceID,"deleteUserID",{oldcredentials:id})
					$.get(url).done(function(data) {
						jQuery(that).closest("tr").remove()
					})
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
			var htmlprefix = ALTHUE.format('\
				<label for="althue-NamePrefix">Prefix for names</label>		\
				<div><input type="text" class="form-control" id="althue-NamePrefix" placeholder="Prefix or empty" value="{0}"></div>',prefix)
			var html = '<style>.bg-success { background-color: #28a745!important; } .bg-danger { background-color: #dc3545!important; }</style>'
			html +='<form id="althue-settings-form"><table class="table">'
			html += '<thead><tr><td></td><td></td></tr><thead>'
			html += '<tbody>'
			html += '<tr>'
			html += ALTHUE.format('<td>{0}</td>',htmlip)
			html += ALTHUE.format('<td>{0}</td>',htmlpolling)
			html += '</tr>'
			html += '<tr>'
			html += ALTHUE.format('<td>{0}</td>',htmlpairstatus)
			html += ALTHUE.format('<td>{0}</td>',htmlprefix)
			html += '</tr>'
			html += '</tbody>'
			html += '</table>'
			html += '<button class="btn btn-primary" type="submit">Save</button></form>'
			set_panel_html(html);
			jQuery.get("https://www.meethue.com/api/nupnp").done( function(data) {
				var dropdown = jQuery("#althue-discovery-btn").parent().find("div.dropdown-menu")
				jQuery.each(data, function(idx,item) {
					jQuery(dropdown).append( ALTHUE.format('<a class="althue-ipselect dropdown-item" href="javascript:void(0);">{0} {1} {2}</a>',item.internalipaddress,item.name||'', item.macaddress|| '') )
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
			
			jQuery( "#althue-settings-form" ).submit(function(event) {
				var bReload = true;
				event.preventDefault();
				var ip_address = jQuery( "#althue-ipaddr" ).val();
				var poll = jQuery( "#althue-RefreshPeriod" ).val();
				var prefix = jQuery( "#althue-NamePrefix" ).val();
				if (ALTHUE.goodip(ip_address)) {
					ALTHUE.saveVar( deviceID,  ALTHUE.ALTHUE_Svs, "RefreshPeriod", poll, 0 )
					ALTHUE.saveVar( deviceID,  ALTHUE.ALTHUE_Svs, "NamePrefix", prefix, 0 )
					ALTHUE.saveVar( deviceID,  null , "ip", ip_address, 0 )
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
		format		: format,
		Dump 		: ALTHUE_Dump,
		Settings 	: ALTHUE_Settings,
		Information : ALTHUE_Information,
		Applications: ALTHUE_Applications,
		Scenes		: ALTHUE_Scenes,
		
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
				html+=ALTHUE.format("<table id='{1}' class='table {2} table-sm table-hover table-striped {0}'>",cls || '', htmlid || 'altui-grid' , responsive );
				if (caption)
					html += ALTHUE.format("<caption>{0}</caption>",caption)
				$.each(arr, function(idx,obj) {
					if (bFirst) {
						html+="<thead>"
						html+="<tr>"
						$.each(display_order,function(_k,k) {
							html+=ALTHUE.format("<th style='text-transform: capitalize;' data-column-id='{0}' {1} {2}>",
								k,
								(k==idcolumn) ? "data-identifier='true'" : "",
								ALTHUE.format("data-visible='{0}'", $.inArray(k,viscols)!=-1 )
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
				html += ALTHUE.format("<div>{0}</div>","No data to display")

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

function ALTHUE_Scenes(deviceID) {
	return ALTHUE.Scenes(deviceID)
}


