import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.ActivityMonitor;
using Toybox.Time;
using Toybox.Activity;
using Toybox.Application as App;

class HeartGraphWatchFaceView extends WatchUi.WatchFace {
  var sleeping = true;

  // for heart graph
  var heartHistory;
  // The active palette + HR range are read from properties on each onUpdate
  // so settings changes take effect on the next paint.
  var palette;
  var hrMin = 40;
  var hrStep = 10;
  var hrMax = 110;
  var heartGraphLeftX;
  var heartGraphBottomY;
  var graphFont;
  var graphDivisions;
  var xAxisMessage;
  var numberOnGraphOffset;

  // from: https://github.com/fevieira27/MoveToBeActive/tree/main/resources/resource/fonts
  var iconFont;
  var heartSymbol = "3";
  var stressSymbol = "T";
  var alarmSymbol = ":";
  var connectedSymbol = "V";

  var width_screen, height_screen;

  // battery icon coords
  var background_color = Gfx.COLOR_BLACK;
  var foreground_color = Gfx.COLOR_WHITE;
  var batt_width_rect = 20;
  var batt_height_rect = 10;
  var batt_width_rect_small = 2;
  var batt_height_rect_small = 5;
  var batt_x, batt_y, batt_x_small, batt_y_small;
  var batteryWidth = batt_width_rect + batt_width_rect_small;

  // heart rates coords
  var heart_x, heart_y;

  // time coordinates
  var time_x, time_y;
  var date_x, date_y;

  function initialize(
    heartData as CircularBuffer,
    xAxisTitle as String,
    graphTicks as Number
  ) {
    xAxisMessage = xAxisTitle;
    heartHistory = heartData;
    graphDivisions = graphTicks;
    WatchFace.initialize();
  }

  function alarmCount() as Number {
    var mySettings = System.getDeviceSettings();
    return mySettings.alarmCount;
  }

  // Load resources here
  function onLayout(dc as Dc) as Void {
    graphFont = Application.loadResource(Rez.Fonts.pixeltiny);
    iconFont = Application.loadResource(Rez.Fonts.mtba);

    width_screen = dc.getWidth();
    height_screen = dc.getHeight();

    batt_x = width_screen / 2 - batt_width_rect / 2 - batt_width_rect_small / 2;
    batt_y = (height_screen / 10) * 1 - batt_height_rect / 2;
    batt_x_small = batt_x + batt_width_rect;
    batt_y_small = batt_y + (batt_height_rect - batt_height_rect_small) / 2;

    // Y positions designed against the 260px reference (Forerunner 955);
    // scale by height_screen so layout adapts to taller devices (e.g. Enduro 3 at 280px).
    heartGraphBottomY = (height_screen * 205 / 260).toNumber();

    heart_x = width_screen / 2;
    heart_y = (height_screen * 220 / 260).toNumber();

    time_x = width_screen / 2;
    time_y = (height_screen * 70 / 260).toNumber();

    date_x = time_x;
    date_y = time_y - 20;

    // heartGraphLeftX and numberOnGraphOffset depend on the visible bar
    // count, which now varies per tick based on HeartGraphMinutes — they
    // are recomputed in onUpdate.

    setLayout(Rez.Layouts.WatchFace(dc));
  }

  // Called when this View is brought to the foreground. Restore
  // the state of this View and prepare it to be shown. This includes
  // loading resources into memory.
  function onShow() as Void {}

  function onPartialUpdate(dc as Dc) as Void {
    // when the watch is in 'sleep' mode then
    // still record the latest heart beat
    heartHistory.addData(getHeartRate(), Time.now());
  }

  // Update the view
  function onUpdate(dc as Dc) as Void {
    var bg = Application.Properties.getValue("BackgroundColor") as Number;
    background_color = bg;
    foreground_color = bg == 0x000000 ? Gfx.COLOR_WHITE : Gfx.COLOR_BLACK;

    // Resolve palette + HR settings each tick so changes apply live.
    var palettes = getPalettes();
    var idx = Application.Properties.getValue("PaletteIndex") as Number;
    if (idx < 0 || idx >= palettes.size()) {
      idx = 0;
    }
    palette = palettes[idx][:colors] as Array<Number>;
    hrMin = Application.Properties.getValue("HRMin") as Number;
    hrStep = Application.Properties.getValue("HRStep") as Number;
    hrMax = Application.Properties.getValue("HRMax") as Number;

    // The buffer always holds 10 min at 1-sec resolution; the user's
    // chosen display mode just picks how much of the tail to show and
    // (for the wider modes) downsamples to the visual bar count.
    var displayMinutes =
      Application.Properties.getValue("HeartGraphMinutes") as Number;
    if (
      displayMinutes != 3 && displayMinutes != 5 && displayMinutes != 10
    ) {
      displayMinutes = 3;
    }
    var displayBars;
    if (displayMinutes == 3) {
      displayBars = 181;
    } else if (displayMinutes == 5) {
      displayBars = 151;
    } else {
      displayBars = 201;
    }
    xAxisMessage = "last " + displayMinutes + " minutes";
    graphDivisions = displayMinutes;
    heartGraphLeftX = width_screen / 2 - displayBars / 2;
    numberOnGraphOffset = (displayBars * 7) / 8;

    clearScreen(dc);
    var currentTime = Time.now();
    var currentHeartRate = getHeartRate();

    // Always record real HR so test mode doesn't lose history when toggled off.
    heartHistory.addData(currentHeartRate, currentTime);

    // maybeBuildSyntheticRamp is (:debug)-annotated — doesn't compile in
    // release builds, so the synthetic-ramp code path is entirely absent
    // from the store binary. In debug builds, it reads the TestMode
    // property and either returns a synthetic ramp array or null.
    var data = null;
    if (self has :maybeBuildSyntheticRamp) {
      data = maybeBuildSyntheticRamp(displayBars);
      if (data != null) {
        currentHeartRate = data[displayBars - 1];
      }
    }
    if (data == null) {
      var full = heartHistory.getOrderedArray(currentTime);
      // Buffer is 10 min at 1 sample / sec (601 entries). Take only the
      // tail that covers the user's chosen window, then downsample to
      // the visual bar count. All three modes downsample (3-min is ~1:1,
      // 5-min averages every 2, 10-min averages every 3) — no upsampling
      // needed because source samples ≥ target bars for every mode.
      var tailSize = displayMinutes * 60 + 1;
      if (tailSize > full.size()) { tailSize = full.size(); }
      var tail = full.slice(full.size() - tailSize, full.size());
      data = resampleToBars(tail, displayBars);
    }

    drawHeartRate(dc, currentHeartRate);
    drawGraph(dc, heartGraphLeftX, heartGraphBottomY, data.size(), data);

    // Minimal mode hides the top chrome (time, date, battery, alarm) so the
    // graph dominates the face. HR text + perimeter ring still render.
    var minimal = Application.Properties.getValue("MinimalMode") as Boolean;
    if (!minimal) {
      // draw alarm and battery icon at top
      drawIcons(dc);
      // draw the current time in the middle
      drawTime(dc);
      //draw the current date between current time and icons
      drawDate(dc);
    }

    heartHistory.backupData();
    dc.clearClip();
  }

  function drawIcons(dc as Dc) as Void {
    var batteryX = batt_x;
    var batteryY = batt_y;
    var alarmWidthSpace = 20; // hard code value to make spacing look nice
    var alarmWidth =
      dc.getTextDimensions(alarmSymbol, iconFont)[0] + alarmWidthSpace;

    // if we need to display alarm icon, displace the battery icon so that
    // both icons are centered about watch x axis center
    if (alarmCount() > 0) {
      batteryX = width_screen / 2 - (batteryWidth + alarmWidth) / 2;
      var alarmX = batteryX + batteryWidth + alarmWidthSpace / 2;

      drawAlarm(dc, alarmX, batteryY - 10);
    }
    drawBattery(dc, batteryX, batt_y);
  }

  // Called when this View is removed from the screen. Save the
  // state of this View here. This includes freeing resources from
  // memory.
  function onHide() as Void {
    heartHistory.backupData();
  }

  // The user has just looked at their watch. Timers and animations may be started here.
  function onExitSleep() as Void {
    self.sleeping = false;
  }

  // Terminate any active timers and prepare for slow updates.
  function onEnterSleep() as Void {
    self.sleeping = true;
  }

  function clearScreen(dc as Dc) as Void {
    dc.setColor(background_color, Gfx.COLOR_WHITE);
    dc.clear();
    dc.fillRectangle(0, 0, width_screen, height_screen);
  }

  // get string representing current time in military time
  function stringCurrentTime(includeSeconds as Boolean) as String {
    // Get the current time and format it correctly
    var timeFormat = "$1$ $2$";
    var clockTime = System.getClockTime();
    var h = clockTime.hour;
    var m = clockTime.min;
    var s = clockTime.sec;
    // In test mode (debug builds only) lock the displayed time to 13:37
    // so qc / colour-variants screenshots are visually consistent across
    // a multi-minute capture run.
    if (self has :testModeClockOverride) {
      var hm = testModeClockOverride();
      if (hm != null) { h = hm[0]; m = hm[1]; s = 0; }
    }
    var hours = h.format("%02d");
    var minutes = m.format("%02d");
    var formatStrings = [hours, minutes];
    if (includeSeconds) {
      timeFormat = timeFormat + " $3$";
      var seconds = s.format("%02d");
      formatStrings.add(seconds);
    }
    var timeString = Lang.format(timeFormat, formatStrings);
    return timeString;
  }

  // get string representation of current date (e.g. Wed Nov 22)
  function stringCurrentDate() as String {
    var timeFormat = "$1$ $2$ $3$";

    var now = Time.Gregorian.info(Time.now(), Time.FORMAT_LONG);

    var monthString = now.month;
    var day = now.day;

    var dayOfWeek =
      1 +
      ((Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT).day_of_week + 5) %
        7);
    var dayOfWeekString = "";
    switch (dayOfWeek) {
      case 1:
        dayOfWeekString = "Mon";
        break;
      case 2:
        dayOfWeekString = "Tues";
        break;
      case 3:
        dayOfWeekString = "Wed";
        break;
      case 4:
        dayOfWeekString = "Thur";
        break;
      case 5:
        dayOfWeekString = "Fri";
        break;
      case 6:
        dayOfWeekString = "Sat";
        break;
      case 7:
        dayOfWeekString = "Sun";
        break;
    }
    var formatStrings = [dayOfWeekString, monthString, day + ""];
    var timeString = Lang.format(timeFormat, formatStrings);
    return timeString;
  }

  // draw alarm icon
  function drawAlarm(dc as Dc, alarmX as Number, alarmY as Number) as Void {
    dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
    dc.drawText(alarmX, alarmY, iconFont, alarmSymbol, Gfx.TEXT_JUSTIFY_LEFT);
  }

  // draw current date — shares the Time Color setting so date and time match.
  function drawDate(dc as Dc) as Void {
    var configured = Application.Properties.getValue("TimeColor") as Number;
    var color = configured == -2 ? foreground_color : configured;
    dc.setColor(color, Gfx.COLOR_TRANSPARENT);
    dc.drawText(
      date_x,
      date_y,
      Gfx.FONT_TINY,
      stringCurrentDate(),
      Gfx.TEXT_JUSTIFY_CENTER
    );
  }

  // draw current time
  function drawTime(dc as Dc) as Void {
    var configured = Application.Properties.getValue("TimeColor") as Number;
    var color = configured == -2 ? foreground_color : configured;
    dc.setColor(color, Gfx.COLOR_TRANSPARENT);
    dc.drawText(
      time_x,
      time_y,
      Gfx.FONT_NUMBER_HOT,
      stringCurrentTime(false),
      Gfx.TEXT_JUSTIFY_CENTER
    );
  }

  // draw current heart rate. We colour code so user
  // knows if it is too high or not.
  function drawHeartRate(dc, heartRate as Number) as Void {
    var colourNumber = heartRateColour(heartRate);

    if (heartRate != null) {
      dc.setColor(colourNumber, Gfx.COLOR_TRANSPARENT);

      //we center the heart symbol and heart rate with respect to middle y
      // axis of watch
      var symbolDimensions = dc.getTextDimensions(heartSymbol, iconFont);
      var rateDimensions = dc.getTextDimensions(heartRate + "", Gfx.FONT_SMALL);
      var symbolDimensionsLength = symbolDimensions[0];
      var rateDimensionsLength = rateDimensions[0];

      var overallLength = symbolDimensionsLength + rateDimensionsLength;
      var x_start =
        (width_screen / 2).toNumber() - (overallLength / 2).toNumber();

      dc.drawText(
        x_start,
        heart_y + 4,
        iconFont,
        heartSymbol,
        Gfx.TEXT_JUSTIFY_LEFT
      );
      dc.drawText(
        x_start + symbolDimensionsLength,
        heart_y,
        Gfx.FONT_SMALL,
        heartRate + "",
        Gfx.TEXT_JUSTIFY_LEFT
      );

      // we arc around perimeter of the watch with same colour
      // as heart rate to emphasize heart rate to user
      dc.setPenWidth(10);
      dc.drawCircle(width_screen / 2, height_screen / 2, width_screen / 2);
      dc.setPenWidth(1);
    }
  }

  // Dev-only synthetic ramp generator. Reads the TestMode property; if
  // true, returns a `targetCount`-long array spanning the full palette
  // range (so the user can visually evaluate gradient transitions
  // without waiting for live HR data). Returns null if test mode is off.
  // (:debug) — excluded from release builds, so the Test Mode code path
  // never makes it into the store binary.
  // Dev-only clock override. Returns [hour, minute] (13:37) when TestMode
  // is on, else null. Paired with `(:debug)` so it's absent from release
  // builds — production reads the real clock unconditionally.
  (:debug)
  function testModeClockOverride() as Array<Number> or Null {
    var testMode = Application.Properties.getValue("TestMode") as Boolean;
    if (testMode != true) { return null; }
    return [13, 37];
  }

  (:debug)
  function maybeBuildSyntheticRamp(targetCount as Number) as Array<Number> or Null {
    var testMode = Application.Properties.getValue("TestMode") as Boolean;
    if (testMode != true) { return null; }
    var data = new Array<Number>[targetCount];
    var top = hrMin + palette.size() * hrStep;
    for (var i = 0; i < targetCount; i++) {
      data[i] = hrMin + (i * (top - hrMin)) / targetCount;
    }
    return data;
  }

  // Resample a 1-D series to a target bar count. Handles both downsampling
  // (averages each bar's group of source samples) and upsampling (each
  // output bar maps to a single source sample, producing visible "blocks"
  // when target > source). Zero-valued samples — the no-reading sentinel —
  // are skipped from averages so a single missing sample doesn't drag a
  // bar down; if every sample in a bar's slice is zero, the output is 0
  // (renders as a 1-px baseline bar = clean visible gap).
  function resampleToBars(
    source as Array<Number>,
    targetCount as Number
  ) as Array<Number> {
    var srcSize = source.size();
    if (srcSize == targetCount) { return source; }
    var result = new Array<Number>[targetCount];
    for (var i = 0; i < targetCount; i++) {
      var startIdx = (i * srcSize) / targetCount;
      var endIdx = ((i + 1) * srcSize) / targetCount;
      if (endIdx > srcSize) { endIdx = srcSize; }
      // Upsampling case: the [start, end) window collapses to a single
      // source index. Pick it as-is.
      if (endIdx <= startIdx) {
        result[i] = startIdx < srcSize ? source[startIdx] : 0;
      } else {
        var sum = 0;
        var count = 0;
        for (var j = startIdx; j < endIdx; j++) {
          if (source[j] > 0) {
            sum += source[j];
            count += 1;
          }
        }
        result[i] = count > 0 ? sum / count : 0;
      }
    }
    return result;
  }

  // Map an HR value into the active palette by dividing the range
  // [hrMin .. hrMin + len*hrStep) into len equal buckets. HR below
  // hrMin clamps to the first color; HR above the top bucket clamps
  // to the last color (so a higher-than-expected HR still gets a
  // sensible "top of scale" colour).
  function heartRateColour(heartRate as Number) as Number {
    var idx = (heartRate - hrMin) / hrStep;
    if (idx < 0) {
      idx = 0;
    }
    var last = palette.size() - 1;
    if (idx > last) {
      idx = last;
    }
    return palette[idx];
  }

  function drawGraph(
    dc as Dc,
    leftX as Number,
    upperY as Number,
    graphWidth as Number,
    data as Array<Number>
  ) {
    // Each palette band renders at GraphBandPixels of vertical space
    // regardless of hrStep, so finer color granularity (e.g. step=5)
    // doesn't squish labels and gridlines. Setting controls 10 vs 20.
    var bandPixels =
      Application.Properties.getValue("GraphBandPixels") as Number;
    var maxValDetected = hrMin;
    for (var i = 0; i < data.size(); i++) {
      var val = data[i];

      if (maxValDetected < val) {
        maxValDetected = val;
      }

      if (val < hrMin) {
        val = hrMin;
      }
      // Bars are NOT capped at hrMax — a high reading grows past the
      // palette range up toward (or into) the time/date chrome. That's
      // intentional: those elements render after drawGraph so they sit
      // on top of any overshoot, while the colour stays at the top
      // palette bucket via heartRateColour clamping.

      // colour code the heart rate in graph based on its value
      var colourNumber = heartRateColour(val);
      dc.setColor(colourNumber, colourNumber);
      var barPixels = ((val - hrMin) * bandPixels) / hrStep + 1;
      // draw a single 'bar in the bar graph'
      dc.fillRectangle(leftX + i, upperY - barPixels, 1, barPixels);
    }

    // Dash lines mark each palette bucket boundary, labeled by the
    // HR at the bottom of the bucket (i.e. hrMin, hrMin+step, ...).
    // Both lines + labels are gated by ShowGraphAxis — when off the
    // graph reduces to pure colored bars.
    var showAxis =
      Application.Properties.getValue("ShowGraphAxis") as Boolean;
    var lines = new Array<Number>[palette.size()];
    for (var i = 0; i < palette.size(); i++) {
      lines[i] = hrMin + (i + 1) * hrStep;
    }

    for (var i = 0; showAxis && i < lines.size(); i++) {
      if (lines[i] > maxValDetected) {
        break;
      }
      var val = (i + 1) * bandPixels;
      //draw horizontal dashed lines through graph
      drawDashedLine(dc, leftX, leftX + graphWidth, upperY - val);

      var configured =
        Application.Properties.getValue("GraphNumberColor") as Number;
      var numberColor;
      if (configured == -2) {
        numberColor = foreground_color;
      } else if (configured == -3) {
        numberColor = background_color;
      } else {
        numberColor = configured;
      }
      dc.setColor(numberColor, Gfx.COLOR_TRANSPARENT);

      // Labels alternate left/right around an invisible vertical "axis bar"
      // at numberOnGraphOffset. Even-index labels right-justify against the
      // bar from the left, odd-index labels left-justify against the bar
      // from the right — each side hugs tightly and extra width (e.g.
      // "100") just extends outward, never into the other column.
      var barX = leftX + numberOnGraphOffset;
      var gap = 1;
      var labelText = lines[i] - hrStep + "";
      if (i % 2 == 0) {
        dc.drawText(
          barX - gap,
          upperY - val - 13,
          graphFont,
          labelText,
          Gfx.TEXT_JUSTIFY_RIGHT
        );
      } else {
        dc.drawText(
          barX + gap,
          upperY - val - 13,
          graphFont,
          labelText,
          Gfx.TEXT_JUSTIFY_LEFT
        );
      }
    }
    // X-axis baseline, "last N minutes" label, and tick marks are part
    // of the same axis chrome as the dashed lines + numbers — they all
    // disappear together when the user turns the axis off.
    if (showAxis) {
      drawXAxis(dc, leftX, upperY, data.size(), graphDivisions);
    }
  }

  function drawXAxis(
    dc as Dc,
    leftX as Number,
    upperY as Number,
    width as Number,
    graphDivisions as Number
  ) as Void {
    dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);

    // draw x axis
    dc.drawLine(leftX, upperY, leftX + width, upperY);

    // draw x axis label
    dc.drawText(
      width_screen / 2,
      upperY - 8,
      graphFont,
      xAxisMessage,
      Gfx.TEXT_JUSTIFY_CENTER
    );

    // draw x axis ticks
    for (var i = 1; i < graphDivisions; i++) {
      var xCoord = leftX + i * (width / graphDivisions);
      var extensionLength = 2;
      dc.drawLine(xCoord, upperY, xCoord, upperY + extensionLength);
    }
  }

  function drawDashedLine(
    dc,
    graphLeft as Number,
    graphRight as Number,
    thresholdY as Number
  ) as Void {
    dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_DK_GRAY);
    var dashLen = 2;
    for (var x = graphLeft; x < graphRight; x += dashLen * 2) {
      var localDashLen = dashLen;
      if (x + dashLen > graphRight) {
        localDashLen = graphRight - x;
      }
      dc.drawLine(x, thresholdY, x + localDashLen, thresholdY);
    }
  }

  function drawBattery(dc as Dc, batteryX as Number, batteryY as Number) {
    var battery = Sys.getSystemStats().battery;

    batt_x_small = batteryX + batt_width_rect;
    batt_y_small = batteryY + (batt_height_rect - batt_height_rect_small) / 2;

    dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
    dc.drawRectangle(batteryX, batteryY, batt_width_rect, batt_height_rect);
    dc.setColor(background_color, Gfx.COLOR_TRANSPARENT);
    dc.drawLine(
      batt_x_small - 1,
      batt_y_small + 1,
      batt_x_small - 1,
      batt_y_small + batt_height_rect_small - 1
    );

    dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
    dc.drawRectangle(
      batt_x_small,
      batt_y_small,
      batt_width_rect_small,
      batt_height_rect_small
    );
    dc.setColor(background_color, Gfx.COLOR_TRANSPARENT);
    dc.drawLine(
      batt_x_small,
      batt_y_small + 1,
      batt_x_small,
      batt_y_small + batt_height_rect_small - 1
    );

    // fill the actual battery
    dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_TRANSPARENT);
    dc.fillRectangle(
      batteryX + 1,
      batteryY + 1,
      (batt_width_rect * battery) / 100 - 1,
      batt_height_rect - 1
    );
    dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
    if (battery == 100.0) {
      dc.fillRectangle(
        batt_x_small + 1,
        batt_y_small + 1,
        batt_width_rect_small - 1,
        batt_height_rect_small - 1
      );
    }
  }
}

class HeartGraphWatchDelegate extends WatchUi.WatchFaceDelegate {
  function initialize() {
    WatchFaceDelegate.initialize();
  }

  function onPowerBudgetExceeded(powerInfo) {
    Sys.println("Average execution time: " + powerInfo.executionTimeAverage);
    Sys.println("Allowed execution time: " + powerInfo.executionTimeLimit);
  }
}
