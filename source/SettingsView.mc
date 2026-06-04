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
    var bg = Application.Properties.getValue("BackgroundColor") as Number;
    addItem(
      new WatchUi.MenuItem(
        "Background",
        bg == 0x000000 ? "black" : "white",
        :background,
        null
      )
    );
    var gn = Application.Properties.getValue("GraphNumberColor") as Number;
    var gnLabel;
    if (gn == -2) {
      gnLabel = "default";
    } else if (gn == -3) {
      gnLabel = "hidden";
    } else {
      gnLabel = "gray";
    }
    addItem(
      new WatchUi.MenuItem(
        "Graph Numbers",
        gnLabel,
        :graphNumbers,
        null
      )
    );

    var tc = Application.Properties.getValue("TimeColor") as Number;
    addItem(
      new WatchUi.MenuItem(
        "Time & Date",
        tc == -2 ? "default" : "gray",
        :timeColor,
        null
      )
    );

    var palettes = getPalettes();
    var idx = Application.Properties.getValue("PaletteIndex") as Number;
    if (idx < 0 || idx >= palettes.size()) {
      idx = 0;
    }
    addItem(
      new WatchUi.IconMenuItem(
        "Palette",
        palettes[idx][:name],
        :palette,
        new PaletteStrip(palettes[idx][:colors]),
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
    var minutes = Application.Properties.getValue("HeartGraphMinutes") as Number;
    getItem(0).setSubLabel(minutes + " min");

    var bandPx = Application.Properties.getValue("GraphBandPixels") as Number;
    getItem(1).setSubLabel(bandPx == 20 ? "double" : "normal");

    var bg = Application.Properties.getValue("BackgroundColor") as Number;
    getItem(2).setSubLabel(bg == 0x000000 ? "black" : "white");

    var gn = Application.Properties.getValue("GraphNumberColor") as Number;
    var gnLabel;
    if (gn == -2) {
      gnLabel = "default";
    } else if (gn == -3) {
      gnLabel = "hidden";
    } else {
      gnLabel = "gray";
    }
    getItem(3).setSubLabel(gnLabel);

    var tc = Application.Properties.getValue("TimeColor") as Number;
    getItem(4).setSubLabel(tc == -2 ? "default" : "gray");

    var palettes = getPalettes();
    var idx = Application.Properties.getValue("PaletteIndex") as Number;
    if (idx < 0 || idx >= palettes.size()) {
      idx = 0;
    }
    var p = palettes[idx];
    getItem(5).setSubLabel(p[:name]);
    (getItem(5) as WatchUi.IconMenuItem).setIcon(new PaletteStrip(p[:colors]));

    var hrMin = Application.Properties.getValue("HRMin") as Number;
    var hrStep = Application.Properties.getValue("HRStep") as Number;
    var hrMax = Application.Properties.getValue("HRMax") as Number;
    getItem(6).setSubLabel(hrMin + " / " + hrStep + " / " + hrMax);
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
    } else if (id == :background) {
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
    } else if (id == :reset) {
      WatchUi.pushView(
        new WatchUi.Confirmation("Reset all settings?"),
        new ResetConfirmDelegate(),
        WatchUi.SLIDE_LEFT
      );
    }
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
