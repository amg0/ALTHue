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

# Mapping product name <=> Icon

Product Name | Model ID | Icon
--- | --- | --- | ---
Hue bulb A19 |LCT001, LCT007 |
Hue bulb A19|LCT010, LCT014, LCT015, LCT016|
Hue Spot BR30|LCT002|
Hue Spot GU10|LCT003|
Hue BR30 Richer Colors|LCT011|
Hue BR30 White Ambience|LTW011|
Hue LightStrips|LST001|
Hue Living Colors Iris|LLC010|
Hue Living Colors Bloom|LLC011, LLC012|
Living Colors Gen3 Iris*|LLC006|
Living Colors Gen3 Bloom, Aura*|LLC005, LLC007, LLC014|
Disney Living Colors|LLC013|
Hue White|LWB004, LWB006, LWB007|
Hue White lamp|LWB010, LWB014|
Color Light Module|LLM001|
Color Temperature Module|LLM010, LLM011, LLM012|
Hue A19 White Ambiance|LTW001, LTW004, LTW010, LTW015|
Hue ambiance spot|LTW013, LTW014|
Hue Go|LLC020|
Hue LightStrips Plus|LST002|
Hue color candle|LCT012|
Hue ambiance candle|LTW012|
Hue ambiance pendant|LTP001, LTP002, LTP003, LTP004, LTP005, LTD003|
Hue ambiance ceiling|LTF001, LTF002, LTC001, LTC002, LTC003, LTC004, LTC011, LTC012, LTD001, LTD002|
Hue ambiance floor|LFF001|
Hue ambiance table|LTT001|
Hue ambiance downlight|LDT001|
Hue white wall washer|LDF002|
Hue white ceiling|LDF001|
Hue white floor|LDD002|
Hue white table|LDD001|
Hue white 1-10V|MWM001|
Hue Beyond Table|HBL001|
Hue Beyond Pendant|HBL002|
Hue Beyond Ceiling|HBL003|
Hue Entity Table|HEL001|
Hue Entity Pendant|HEL002|
Hue Impulse Table|HIL001|
Hue Impulse Pendant|HIL002|
Hue Phoenix Centerpiece|HML001|
Hue Phoenix Ceiling|HML002|
Hue Phoenix Pendant|HML003|
Hue Phoenix Wall|HML004|
Hue Phoenix Table|HML005|
Hue Phoenix Downlight|HML006|


