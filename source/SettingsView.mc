import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Top-level settings menu. Add new rows here.
class SettingsMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "Settings" });
    var minutes =
      Application.Properties.getValue("HeartGraphMinutes") as Number;
    addItem(
      new WatchUi.MenuItem(
        "Graph Duration",
        minutes + " min",
        :graphDuration,
        null
      )
    );
    var bandPx =
      Application.Properties.getValue("GraphBandPixels") as Number;
    addItem(
      new WatchUi.MenuItem(
        "Graph Size",
        bandPx == 20 ? "double" : "normal",
        :graphSize,
        null
      )
    );

    addItem(new WatchUi.MenuItem("Colours", null, :colours, null));

    var minimal = Application.Properties.getValue("MinimalMode") as Boolean;
    addItem(
      new WatchUi.ToggleMenuItem(
        "Minimal",
        "graph only",
        :minimal,
        minimal,
        null
      )
    );

    var hrMin = Application.Properties.getValue("HRMin") as Number;
    var hrStep = Application.Properties.getValue("HRStep") as Number;
    var hrMax = Application.Properties.getValue("HRMax") as Number;
    addItem(
      new WatchUi.MenuItem(
        "HR Range",
        hrMin + " / " + hrStep + " / " + hrMax,
        :hrRange,
        null
      )
    );

    var testMode = Application.Properties.getValue("TestMode") as Boolean;
    addItem(
      new WatchUi.ToggleMenuItem(
        "Test Mode",
        "synthetic ramp",
        :testMode,
        testMode,
        null
      )
    );

    addItem(new WatchUi.MenuItem("Presets", null, :presets, null));
    addItem(new WatchUi.MenuItem("Reset", "to defaults", :reset, null));
  }

  // Called by the framework when this menu returns to the foreground after
  // a sub-menu pops — refresh sub-labels so they reflect any changes made
  // in the sub-menu.
  function onShow() as Void {
    Menu2.onShow();
    refreshLabels();
  }

  function refreshLabels() as Void {
    // Top-level layout: Graph Duration, Graph Size, Colours, Minimal, HR Range, Test Mode, Reset.
    var minutes = Application.Properties.getValue("HeartGraphMinutes") as Number;
    getItem(0).setSubLabel(minutes + " min");

    var bandPx = Application.Properties.getValue("GraphBandPixels") as Number;
    getItem(1).setSubLabel(bandPx == 20 ? "double" : "normal");

    // index 2 (Colours) opens a submenu — no sub-label
    // index 3 (Minimal) is a toggle — self-manages
    var hrMin = Application.Properties.getValue("HRMin") as Number;
    var hrStep = Application.Properties.getValue("HRStep") as Number;
    var hrMax = Application.Properties.getValue("HRMax") as Number;
    getItem(4).setSubLabel(hrMin + " / " + hrStep + " / " + hrMax);
  }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    var id = item.getId();
    if (id == :graphDuration) {
      WatchUi.pushView(
        new GraphDurationMenu(),
        new GraphDurationDelegate(),
        WatchUi.SLIDE_LEFT
      );
    } else if (id == :graphSize) {
      WatchUi.pushView(
        new GraphSizeMenu(),
        new GraphSizeDelegate(),
        WatchUi.SLIDE_LEFT
      );
    } else if (id == :colours) {
      WatchUi.pushView(
        new ColoursMenu(),
        new ColoursMenuDelegate(),
        WatchUi.SLIDE_LEFT
      );
    } else if (id == :hrRange) {
      WatchUi.pushView(
        new HRRangeMenu(),
        new HRRangeDelegate(),
        WatchUi.SLIDE_LEFT
      );
    } else if (id == :testMode) {
      // ToggleMenuItem flips its own state on tap; persist the new value.
      var t = item as WatchUi.ToggleMenuItem;
      Application.Properties.setValue("TestMode", t.isEnabled());
    } else if (id == :minimal) {
      var t = item as WatchUi.ToggleMenuItem;
      Application.Properties.setValue("MinimalMode", t.isEnabled());
    } else if (id == :presets) {
      WatchUi.pushView(
        new PresetsMenu(),
        new PresetsMenuDelegate(),
        WatchUi.SLIDE_LEFT
      );
    } else if (id == :reset) {
      WatchUi.pushView(
        new WatchUi.Confirmation("Reset all settings?"),
        new ResetConfirmDelegate(),
        WatchUi.SLIDE_LEFT
      );
    }
  }
}

// Sub-menu grouping all color/palette settings.
class ColoursMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "Colours" });
    addItem(new WatchUi.MenuItem("Background", "", :background, null));
    addItem(new WatchUi.MenuItem("Graph Numbers", "", :graphNumbers, null));
    addItem(new WatchUi.MenuItem("Time & Date", "", :timeColor, null));
    addItem(
      new WatchUi.IconMenuItem(
        "Palette",
        "",
        :palette,
        new PaletteStrip([0x000000] as Array<Number>),
        null
      )
    );
    refreshLabels();
  }

  function onShow() as Void {
    Menu2.onShow();
    refreshLabels();
  }

  function refreshLabels() as Void {
    var bg = Application.Properties.getValue("BackgroundColor") as Number;
    getItem(0).setSubLabel(bg == 0x000000 ? "black" : "white");

    var gn = Application.Properties.getValue("GraphNumberColor") as Number;
    var gnLabel;
    if (gn == -2) {
      gnLabel = "default";
    } else if (gn == -3) {
      gnLabel = "hidden";
    } else {
      gnLabel = "gray";
    }
    getItem(1).setSubLabel(gnLabel);

    var tc = Application.Properties.getValue("TimeColor") as Number;
    getItem(2).setSubLabel(tc == -2 ? "default" : "gray");

    var palettes = getPalettes();
    var idx = Application.Properties.getValue("PaletteIndex") as Number;
    if (idx < 0 || idx >= palettes.size()) {
      idx = 0;
    }
    var p = palettes[idx];
    getItem(3).setSubLabel(p[:name]);
    (getItem(3) as WatchUi.IconMenuItem).setIcon(new PaletteStrip(p[:colors]));
  }
}

class ColoursMenuDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    var id = item.getId();
    if (id == :background) {
      WatchUi.pushView(
        new BackgroundColorMenu(),
        new BackgroundColorDelegate(),
        WatchUi.SLIDE_LEFT
      );
    } else if (id == :graphNumbers) {
      WatchUi.pushView(
        new GraphNumberColorMenu(),
        new GraphNumberColorDelegate(),
        WatchUi.SLIDE_LEFT
      );
    } else if (id == :timeColor) {
      WatchUi.pushView(
        new TimeColorMenu(),
        new TimeColorDelegate(),
        WatchUi.SLIDE_LEFT
      );
    } else if (id == :palette) {
      WatchUi.pushView(
        new PaletteMenu(),
        new PaletteDelegate(),
        WatchUi.SLIDE_LEFT
      );
    }
  }
}

// Presets: snapshots of all user-tunable settings that can be saved,
// re-applied, and deleted. "Default" is a built-in entry; user-created
// presets persist in Application.Storage.
class PresetsMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "Presets" });
    buildItems();
  }

  function onShow() as Void {
    Menu2.onShow();
    rebuild();
  }

  function rebuild() as Void {
    // Drain all items, then re-add from current storage. deleteItem(0)
    // returns true while items remain, null/false once empty.
    while (deleteItem(0) == true) {}
    buildItems();
  }

  function buildItems() as Void {
    addItem(new WatchUi.MenuItem("Default", "built-in", "Default", null));
    var presets = getUserPresets();
    for (var i = 0; i < presets.size(); i++) {
      var p = presets[i] as Dictionary;
      var name = p["name"] as String;
      addItem(new WatchUi.MenuItem(name, null, name, null));
    }
    addItem(new WatchUi.MenuItem("+ Save current", null, :saveCurrent, null));
  }
}

class PresetsMenuDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    var id = item.getId();
    if (id == :saveCurrent) {
      WatchUi.pushView(
        new WatchUi.TextPicker(""),
        new SavePresetTextDelegate(),
        WatchUi.SLIDE_LEFT
      );
    } else {
      // Preset row tapped — open Apply/Delete sub-menu for that preset.
      WatchUi.pushView(
        new PresetActionsMenu(id as String),
        new PresetActionsDelegate(id as String),
        WatchUi.SLIDE_LEFT
      );
    }
  }
}

class PresetActionsMenu extends WatchUi.Menu2 {
  var presetName as String;

  function initialize(name as String) {
    Menu2.initialize({ :title => name });
    presetName = name;
    addItem(new WatchUi.MenuItem("Apply", null, :apply, null));
    if (!name.equals("Default")) {
      addItem(new WatchUi.MenuItem("Delete", null, :delete, null));
    }
  }
}

class PresetActionsDelegate extends WatchUi.Menu2InputDelegate {
  var presetName as String;

  function initialize(name as String) {
    Menu2InputDelegate.initialize();
    presetName = name;
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    var id = item.getId();
    if (id == :apply) {
      var values = lookupPresetValues(presetName);
      if (values != null) {
        applyPresetValues(values);
      }
      WatchUi.popView(WatchUi.SLIDE_RIGHT);
    } else if (id == :delete) {
      WatchUi.pushView(
        new WatchUi.Confirmation("Delete preset?"),
        new DeletePresetConfirmDelegate(presetName),
        WatchUi.SLIDE_LEFT
      );
    }
  }

  function lookupPresetValues(name as String) as Dictionary or Null {
    if (name.equals("Default")) {
      return getDefaultPresetValues();
    }
    var presets = getUserPresets();
    for (var i = 0; i < presets.size(); i++) {
      var p = presets[i] as Dictionary;
      if ((p["name"] as String).equals(name)) {
        return p["values"] as Dictionary;
      }
    }
    return null;
  }
}

class DeletePresetConfirmDelegate extends WatchUi.ConfirmationDelegate {
  var presetName as String;

  function initialize(name as String) {
    ConfirmationDelegate.initialize();
    presetName = name;
  }

  function onResponse(response as WatchUi.Confirm) as Boolean {
    if (response == WatchUi.CONFIRM_YES) {
      deletePresetByName(presetName);
      // Pop the PresetActionsMenu so the user lands back on PresetsMenu,
      // which will rebuild via its onShow() and reflect the deletion.
      WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
    return true;
  }
}

class SavePresetTextDelegate extends WatchUi.TextPickerDelegate {
  function initialize() {
    TextPickerDelegate.initialize();
  }

  function onTextEntered(text as String, changed as Boolean) as Boolean {
    if (text != null && text.length() > 0) {
      savePresetWithName(text);
    }
    return true;
  }

  function onCancel() as Boolean {
    return true;
  }
}

// Writes the documented default for every setting.
class ResetConfirmDelegate extends WatchUi.ConfirmationDelegate {
  function initialize() {
    ConfirmationDelegate.initialize();
  }

  function onResponse(response as WatchUi.Confirm) as Boolean {
    if (response == WatchUi.CONFIRM_YES) {
      Application.Properties.setValue("BackgroundColor", 0x000000);
      Application.Properties.setValue("TimeColor", 0x555555);
      Application.Properties.setValue("GraphNumberColor", -3); // hidden
      Application.Properties.setValue("HRMin", 40);
      Application.Properties.setValue("HRMax", 100);
      Application.Properties.setValue("HRStep", 10);
      Application.Properties.setValue("PaletteIndex", 0);
      Application.Properties.setValue("GraphBandPixels", 10);
      Application.Properties.setValue("HeartGraphMinutes", 3);
      Application.Properties.setValue("TestMode", false);
    }
    return true;
  }
}

class GraphDurationMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "Graph Duration" });
    var current =
      Application.Properties.getValue("HeartGraphMinutes") as Number;
    addOption(3, current);
    addOption(5, current);
    addOption(10, current);
  }

  function addOption(minutes as Number, current as Number) as Void {
    var sub = minutes == current ? "current" : null;
    addItem(new WatchUi.MenuItem(minutes + " minutes", sub, minutes, null));
  }
}

class GraphDurationDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    Application.Properties.setValue(
      "HeartGraphMinutes",
      item.getId() as Number
    );
    WatchUi.popView(WatchUi.SLIDE_RIGHT);
  }
}

class GraphSizeMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "Graph Size" });
    var current =
      Application.Properties.getValue("GraphBandPixels") as Number;
    addOption("Normal", 10, current);
    addOption("Double", 20, current);
  }

  function addOption(
    label as String,
    value as Number,
    current as Number
  ) as Void {
    var sub = value == current ? "current" : null;
    addItem(new WatchUi.MenuItem(label, sub, value, null));
  }
}

class GraphSizeDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    Application.Properties.setValue(
      "GraphBandPixels",
      item.getId() as Number
    );
    WatchUi.popView(WatchUi.SLIDE_RIGHT);
  }
}

class ColorSwatch extends WatchUi.Drawable {
  var swatchColor as Number;

  function initialize(color as Number) {
    Drawable.initialize({});
    swatchColor = color;
  }

  function draw(dc as Dc) as Void {
    var w = dc.getWidth();
    var h = dc.getHeight();
    var r = (w < h ? w : h) / 2 - 1;
    // dark ring so light swatches stay visible on light menu backgrounds
    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
    dc.fillCircle(w / 2, h / 2, r);
    dc.setColor(swatchColor, Graphics.COLOR_TRANSPARENT);
    dc.fillCircle(w / 2, h / 2, r - 1);
  }
}

class BackgroundColorMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "Background" });
    var current =
      Application.Properties.getValue("BackgroundColor") as Number;
    addOption("Black", 0x000000, current);
    addOption("White", 0xFFFFFF, current);
  }

  function addOption(
    label as String,
    color as Number,
    current as Number
  ) as Void {
    var sub = color == current ? "current" : null;
    addItem(
      new WatchUi.IconMenuItem(label, sub, color, new ColorSwatch(color), null)
    );
  }
}

class BackgroundColorDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    Application.Properties.setValue(
      "BackgroundColor",
      item.getId() as Number
    );
    WatchUi.popView(WatchUi.SLIDE_RIGHT);
  }
}

class GraphNumberColorMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "Graph Numbers" });
    var current =
      Application.Properties.getValue("GraphNumberColor") as Number;
    // Sentinels: -2 = follow foreground (auto-contrast). -3 = match background (invisible).
    var bg = Application.Properties.getValue("BackgroundColor") as Number;
    var autoColor = bg == 0x000000 ? 0xFFFFFF : 0x000000;
    addOption("Default", -2, autoColor, current);
    addOption("Gray", 0xAAAAAA, 0xAAAAAA, current);
    addOption("Hidden", -3, bg, current);
  }

  function addOption(
    label as String,
    id as Number,
    swatchColor as Number,
    current as Number
  ) as Void {
    var sub = id == current ? "current" : null;
    addItem(
      new WatchUi.IconMenuItem(label, sub, id, new ColorSwatch(swatchColor), null)
    );
  }
}

class GraphNumberColorDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    Application.Properties.setValue(
      "GraphNumberColor",
      item.getId() as Number
    );
    WatchUi.popView(WatchUi.SLIDE_RIGHT);
  }
}

class TimeColorMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "Time & Date" });
    var current = Application.Properties.getValue("TimeColor") as Number;
    // Default: follows the auto-contrast foreground. Gray: matches the
    // alarm and battery icons (Graphics.COLOR_DK_GRAY = 0x555555).
    var bg = Application.Properties.getValue("BackgroundColor") as Number;
    var autoColor = bg == 0x000000 ? 0xFFFFFF : 0x000000;
    addOption("Default", -2, autoColor, current);
    addOption("Gray", 0x555555, 0x555555, current);
  }

  function addOption(
    label as String,
    id as Number,
    swatchColor as Number,
    current as Number
  ) as Void {
    var sub = id == current ? "current" : null;
    addItem(
      new WatchUi.IconMenuItem(label, sub, id, new ColorSwatch(swatchColor), null)
    );
  }
}

class TimeColorDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    Application.Properties.setValue("TimeColor", item.getId() as Number);
    WatchUi.popView(WatchUi.SLIDE_RIGHT);
  }
}

// Horizontal strip of colored bands — used as the icon for palette rows.
class PaletteStrip extends WatchUi.Drawable {
  var colors;

  function initialize(colors) {
    Drawable.initialize({});
    self.colors = colors;
  }

  function draw(dc as Dc) as Void {
    var w = dc.getWidth();
    var h = dc.getHeight();
    var bandWidth = w / colors.size();
    for (var i = 0; i < colors.size(); i++) {
      dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
      dc.fillRectangle(i * bandWidth, 0, bandWidth + 1, h);
    }
  }
}

class PaletteMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "Palette" });
    var palettes = getPalettes();
    var current =
      Application.Properties.getValue("PaletteIndex") as Number;
    for (var i = 0; i < palettes.size(); i++) {
      var p = palettes[i];
      var sub = i == current ? "current" : null;
      addItem(
        new WatchUi.IconMenuItem(
          p[:name],
          sub,
          i,
          new PaletteStrip(p[:colors]),
          null
        )
      );
    }
  }
}

class PaletteDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    Application.Properties.setValue("PaletteIndex", item.getId() as Number);
    WatchUi.popView(WatchUi.SLIDE_RIGHT);
  }
}

// HR Range — sub-menu lets the user pick Min/Step/Max from presets.
class HRRangeMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => "HR Range" });
    addItem(new WatchUi.MenuItem("Min", "", :hrMin, null));
    addItem(new WatchUi.MenuItem("Step", "", :hrStep, null));
    addItem(new WatchUi.MenuItem("Max", "", :hrMax, null));
    refreshLabels();
  }

  function onShow() as Void {
    Menu2.onShow();
    refreshLabels();
  }

  function refreshLabels() as Void {
    getItem(0).setSubLabel(
      (Application.Properties.getValue("HRMin") as Number) + ""
    );
    getItem(1).setSubLabel(
      (Application.Properties.getValue("HRStep") as Number) + ""
    );
    getItem(2).setSubLabel(
      (Application.Properties.getValue("HRMax") as Number) + ""
    );
  }
}

class HRRangeDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    var id = item.getId();
    if (id == :hrMin) {
      WatchUi.pushView(
        new HRPresetMenu(
          "Min",
          "HRMin",
          [30, 35, 40, 45, 50, 55, 60] as Array<Number>
        ),
        new HRPresetDelegate("HRMin"),
        WatchUi.SLIDE_LEFT
      );
    } else if (id == :hrStep) {
      WatchUi.pushView(
        new HRPresetMenu(
          "Step",
          "HRStep",
          [5, 10, 15, 20] as Array<Number>
        ),
        new HRPresetDelegate("HRStep"),
        WatchUi.SLIDE_LEFT
      );
    } else if (id == :hrMax) {
      // Max options start at HRMin + 20 and step by 10 up to 220 BPM (a
      // sensible practical ceiling). Computed live so changing Min reshapes
      // the Max list on the next visit.
      var hrMin = Application.Properties.getValue("HRMin") as Number;
      var presets = [] as Array<Number>;
      for (var v = hrMin + 20; v <= 220; v += 10) {
        presets.add(v);
      }
      WatchUi.pushView(
        new HRPresetMenu("Max", "HRMax", presets),
        new HRPresetDelegate("HRMax"),
        WatchUi.SLIDE_LEFT
      );
    }
  }
}

// One presets list, parameterized by which property it edits.
class HRPresetMenu extends WatchUi.Menu2 {
  function initialize(
    title as String,
    propKey as String,
    values as Array<Number>
  ) {
    Menu2.initialize({ :title => title });
    var current = Application.Properties.getValue(propKey) as Number;
    for (var i = 0; i < values.size(); i++) {
      var v = values[i];
      var sub = v == current ? "current" : null;
      addItem(new WatchUi.MenuItem(v + "", sub, v, null));
    }
  }
}

class HRPresetDelegate extends WatchUi.Menu2InputDelegate {
  var propKey;

  function initialize(propKey as String) {
    Menu2InputDelegate.initialize();
    self.propKey = propKey;
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    var value = item.getId() as Number;
    Application.Properties.setValue(propKey, value);
    // Safety: raising Min above (Max - 20) would put the range out of sync
    // with what the Max picker offers. Auto-bump Max to value + 20.
    if (propKey.equals("HRMin")) {
      var hrMax = Application.Properties.getValue("HRMax") as Number;
      if (hrMax < value + 20) {
        Application.Properties.setValue("HRMax", value + 20);
      }
    }
    WatchUi.popView(WatchUi.SLIDE_RIGHT);
  }
}
