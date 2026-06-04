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
    var bg = Application.Properties.getValue("BackgroundColor") as Number;
    addItem(
      new WatchUi.MenuItem(
        "Background",
        bg == 0x000000 ? "black" : "white",
        :background,
        null
      )
    );
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
    } else if (id == :background) {
      WatchUi.pushView(
        new BackgroundColorMenu(),
        new BackgroundColorDelegate(),
        WatchUi.SLIDE_LEFT
      );
    }
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
