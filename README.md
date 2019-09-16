# ALTHUE
ALTHue Philips Hue plugin

yet another Hue plugin for Vera UI7 and ALTUI
- Alternate implementation of Philips Hue plugin
- Supports v2 bridges
- Manage Hue devices exactly like VERA devices
- Supports all lamps, Support Hue Motion sensor
- UI7 and ALTUI support ( no UI5 )

Why another one in addition to Vera's one
- More reliable
- Supports motion sensor, temp sensor, lux sensor & battery
- Code less ugly and messy
- All devices appear strictly as standard vera devices, supporting same service/variable, same Upnp actions

### Versions
- v 1.44 : fix strange Tadfridi lamp behavior reporting xy mode and only ct data
- v 1.45 : Hue Dimmer Switch support
- v 1.46 : Hue Zones support
- v 1.47 : fix for RGB devices
- v 1.48 : force light categories to be 2, sensor categories to be 4

 
### Installation instructions:
https://github.com/amg0/ALTHue/blob/master/Doc/ALTHue%20Philips%20Hue%20plugin.pdf

### Note:
.svg files from Icons folder must be uploaded on:
- UI7 => /www/cmh/skins/default/img/devices/device_states
- UI5 => /www/cmh/skins/default/icons

### Philips Hue Dimmer Switch
Philips Hue Dimmer Switch is supported and will appear as a scene controller on vera

VERA LastSceneID | VERA sl_SceneActivated | Action | Dimmer Button
-----------------| ------------- | ---------- | -----------
1000 | 1 | INITIAL_PRESS | Button 1 (ON)
1001 | 2 | HOLD | 
1002 | 3 | SHORT_RELEASED | 
1003 | 4 | LONG_RELEASED | 
2000 | 5 | INITIAL_PRESS | Button 2 (DIM UP)
2001 | 6 | HOLD | 
2002 | 7 | SHORT_RELEASED | 
2003 | 8 | LONG_RELEASED | 
3000 | 9 | INITIAL_PRESS | Button 3 (DIM DOWN)
3001 | 10 | HOLD | 
3002 | 11 | SHORT_RELEASED | 
3003 | 12 | LONG_RELEASED | 
4000 | 13 | INITIAL_PRESS | Button 4 (OFF)
4001 | 14 | HOLD | 
4002 | 15 | SHORT_RELEASED | 
4003 | 16 | LONG_RELEASED | 

