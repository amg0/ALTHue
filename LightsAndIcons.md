# Category

corresponds to the "type" field of the json data in the plugin DATA settings page.

1. On/off light (ZigBee Device ID: 0x0000), supports groups, scenes and on/off control
2. Dimmable light (ZigBee Device ID: 0x0100), which supports groups, scenes, on/off and dimming.
3. Color temperature light (ZigBee Device ID: 0x0220), which supports groups, scenes, on/off, dimming, and setting of a color temperature.
4. Color light (ZigBee Device ID: 0x0200), which supports groups, scenes, on/off, dimming and color control (hue/saturation, enhanced hue, color loop and XY)
5. Extended Color light (ZigBee Device ID: 0x0210), same as Color light, but which supports additional setting of color temperature

OSRAM may have some different categories like
6. On/Off plug-in unit 

# Category maps to .JSON file

type | xml & json file
--- | ---
On/off light | D_BinaryLight1
Dimmable light | D_DimmableALTHue1
Color temperature light | D_DimmableALTHue1
Color light | D_DimmableRGBALTHue1
Extended Color light Color dimmable light | D_DimmableRGBALTHue1
Color dimmable light | D_DimmableRGBALTHue1
On/Off plug-in unit | D_BinaryLight1



