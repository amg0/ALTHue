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


product name | model ID | Icon
--- | --- | ---
Hue bulb A19|LCT001, LCT007|tbd
Hue bulb A19|LCT010, LCT014, LCT015, LCT016|tbd
Hue Spot BR30|LCT002|tbd
Hue Spot GU10|LCT003|tbd
Hue BR30 Richer Colors|LCT011|tbd
Hue BR30 White Ambience|LTW011|tbd
Hue LightStrips|LST001|tbd
Hue Living Colors Iris|LLC010|tbd
Hue Living Colors Bloom|LLC011, LLC012|tbd
Living Colors Gen3 Iris*|LLC006|tbd
Living Colors Gen3 Bloom, Aura*|LLC005, LLC007, LLC014|tbd
Disney Living Colors|LLC013|tbd
Hue White|LWB004, LWB006, LWB007|icons_hue_a19.svg
Hue White lamp|LWB010, LWB014|tbd
Color Light Module|LLM001|tbd
Color Temperature Module|LLM010, LLM011, LLM012|tbd
Hue A19 White Ambiance|LTW001, LTW004, LTW010, LTW015|tbd
Hue ambiance spot|LTW013, LTW014|tbd
Hue Go|LLC020|tbd
Hue LightStrips Plus|LST002|tbd
Hue color candle|LCT012|tbd
Hue ambiance candle|LTW012|tbd
Hue ambiance pendant|LTP001, LTP002, LTP003, LTP004, LTP005, LTD003|tbd
Hue ambiance ceiling|LTF001, LTF002, LTC001, LTC002, LTC003, LTC004, LTC011, LTC012, LTD001, LTD002|tbd
Hue ambiance floor|LFF001|tbd
Hue ambiance table|LTT001|tbd
Hue ambiance downlight|LDT001|tbd
Hue white wall washer|LDF002|tbd
Hue white ceiling|LDF001|tbd
Hue white floor|LDD002|tbd
Hue white table|LDD001|tbd
Hue white 1-10V|MWM001|tbd
Hue Beyond Table|HBL001|tbd
Hue Beyond Pendant|HBL002|tbd
Hue Beyond Ceiling|HBL003|tbd
Hue Entity Table|HEL001|tbd
Hue Entity Pendant|HEL002|tbd
Hue Impulse Table|HIL001|tbd
Hue Impulse Pendant|HIL002|tbd
Hue Phoenix Centerpiece|HML001|tbd
Hue Phoenix Ceiling|HML002|tbd
Hue Phoenix Pendant|HML003|tbd
Hue Phoenix Wall|HML004|tbd
Hue Phoenix Table|HML005|tbd
Hue Phoenix Downlight|HML006|tbd
