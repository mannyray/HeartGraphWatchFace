import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class Background extends WatchUi.Drawable {
  function initialize() {
    var dictionary = {
      :identifier => "Background",
    };

    Drawable.initialize(dictionary);
  }

  function draw(dc as Dc) as Void {
    var bg = Application.Properties.getValue("BackgroundColor") as Number;
    dc.setColor(Graphics.COLOR_TRANSPARENT, bg);
    dc.clear();
  }
}
