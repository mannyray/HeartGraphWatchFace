import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SettingsMenu extends WatchUi.Menu2 {
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

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
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
