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
using Toybox.Time.Gregorian as Tmg;
using Toybox.Application as App;

function getStressIterator() {
  if (Toybox has :SensorHistory && Toybox.SensorHistory has :getStressHistory) {
    return Toybox.SensorHistory.getStressHistory({});
  }
  return null;
}

function getHeartIterator() {
  if (
    Toybox has :SensorHistory &&
    Toybox.ActivityMonitor has :getHeartRateHistory
  ) {
    return ActivityMonitor.getHeartRateHistory(null, false);
  }
  return null;
}

function getStressHistory(minutes as Number) as Array<DataPair> {
  var durationInMinutes = new Time.Duration(minutes * 60);
  var resultArr = new Array<DataPair>[0];
  if (getStressIterator() != null) {
    var history_pointer = Toybox.SensorHistory.getStressHistory({
      :period => durationInMinutes,
      :order => Toybox.SensorHistory.ORDER_OLDEST_FIRST,
    });
    while (history_pointer != null) {
      var stress = history_pointer.next();
      if (stress != null) {
        var time = stress.when;
        resultArr.add(new DataPair(stress.data, time));
      } else {
        break;
      }
    }
  }
  return resultArr;
}

function getStressRate() as Number {
  var stressIterator = getStressIterator();
  if (stressIterator != null) {
    var previous = stressIterator.next();
    if (previous != null) {
      return previous.data.toNumber();
    } else {
      return 0;
    }
  }
  return 0;
}

function getHeartRate() as Number {
  // The sensor reports 255 when the watch is off-wrist or can't get a reading.
  // Treat it as 0 so the graph shows a clean ~1px bar instead of pegging the
  // max. Matches the filter already in getHeartHistory.
  var heartRate = Activity.getActivityInfo().currentHeartRate;
  if (heartRate != null && heartRate != 255) {
    return heartRate;
  }
  var heartIterator = ActivityMonitor.getHeartRateHistory(null, false);
  var previous = heartIterator.next();
  if (previous != null && previous.heartRate != 255) {
    return previous.heartRate;
  }
  return 0;
}

function getHeartHistory(minutes as Number) as Array<DataPair> {
  var durationInMinutes = new Time.Duration(minutes * 60);
  var resultArr = new Array<DataPair>[0];
  if (getHeartIterator() != null) {
    var history_pointer = ActivityMonitor.getHeartRateHistory(
      durationInMinutes,
      false
    );
    while (history_pointer != null) {
      var heart = history_pointer.next();
      if (heart != null) {
        var value = heart.heartRate;
        if (value == 255) {
          value = 0;
        }
        var time = heart.when;
        resultArr.add(new DataPair(value, time));
      } else {
        break;
      }
    }
  }
  return resultArr;
}
