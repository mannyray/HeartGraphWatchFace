using Toybox.Test as Test;
import Toybox.System;
import Toybox.Lang;
using Toybox.Time;

function arrayToString(arr as Array<Number>) as String {
  var result = "";
  for (var i = 0; i < arr.size(); i++) {
    result = result + arr[i] + " ";
  }
  return result;
}

function assertArraysEqual(
  expected as Array<Number>,
  recieved as Array<Number>
) as Void {
  Test.assert(expected.size() == recieved.size());
  for (var i = 0; i < expected.size(); i++) {
    Test.assertMessage(
      expected[i] == recieved[i],
      "expected: " +
        arrayToString(expected) +
        ", received: " +
        arrayToString(recieved)
    );
  }
}

// Sparse history (gappy/non-uniform timestamps) gets resampled into uniform
// bin-spacing values. Bin spacing here is 360/12 = 30 sec.
(:test)
function testSeedFromSparseHistory(logger as Toybox.Test.Logger) as Boolean {
  var timeNow = Time.now();
  var sparse = new Array<DataPair>[4];
  sparse[0] = new DataPair(10, timeNow);
  sparse[1] = new DataPair(11, timeNow.add(new Time.Duration(61)));
  sparse[2] = new DataPair(
    12,
    timeNow.add(new Time.Duration(61)).add(new Time.Duration(61))
  );
  sparse[3] = new DataPair(
    13,
    timeNow
      .add(new Time.Duration(60))
      .add(new Time.Duration(60))
      .add(new Time.Duration(60))
  );

  var firstTime = timeNow.subtract(new Time.Duration(10));
  var buf = new CircularBuffer(6, 13, "file");
  buf.seedFromSparseHistory(sparse, firstTime);

  // Bins are at firstTime + k*30. For each bin, we pick the most recent
  // sparse entry with time <= binTime.
  //   bin 0 (firstTime, = timeNow - 10): sparse[0]@timeNow is > binTime, so
  //     we stay at sparse[0] (the initial floor) → 10.
  //   bin 1 (firstTime+30 = timeNow+20): still sparse[0] → 10.
  //   bin 2 (firstTime+60 = timeNow+50): still sparse[0] → 10.
  //   bin 3 (firstTime+90 = timeNow+80): sparse[1]@61 ≤ 80 → 11.
  //   bin 4 (firstTime+120 = timeNow+110): sparse[1] still (sparse[2]@122 > 110) → 11.
  //   bin 5 (firstTime+150 = timeNow+140): sparse[2]@122 ≤ 140 → 12.
  //   bin 6 (firstTime+180 = timeNow+170): sparse[2] still (sparse[3]@180 > 170) → 12.
  //   bin 7 (firstTime+210 = timeNow+200): sparse[3]@180 ≤ 200 → 13.
  //   bins 8..12: still sparse[3] → 13.
  var ordered = buf.getOrderedArray(
    firstTime.add(new Time.Duration(12 * 30))
  );
  assertArraysEqual(
    [10, 10, 10, 11, 11, 12, 12, 13, 13, 13, 13, 13, 13],
    ordered
  );

  return true;
}

// Constructor validates that durationInMinutes*60 is divisible by (binCount-1).
(:test)
function testInvalidBinDuration(logger as Toybox.Test.Logger) as Boolean {
  try {
    // 3 min = 180 sec; binCount=8 → spacing = 180/7, not an integer.
    new CircularBuffer(3, 8, "file");
  } catch (e instanceof InvalidStartingData) {
    Test.assertMessage(
      e.getErrorMessage().find("whole number in seconds") != null,
      "Expected divisibility error, got '" + e.getErrorMessage() + "'"
    );
    return true;
  }
  return false;
}

// Constructor rejects buffer sizes < 2.
(:test)
function testInvalidBinCount(logger as Toybox.Test.Logger) as Boolean {
  try {
    new CircularBuffer(3, 1, "file");
  } catch (e instanceof InvalidStartingData) {
    Test.assertMessage(
      e.getErrorMessage().find("too small") != null,
      "Expected too-small error, got '" + e.getErrorMessage() + "'"
    );
    return true;
  }
  return false;
}

// seedFromDataPairs validates spacing — preserves the pre-refactor
// constructor's check + identical error message text.
(:test)
function testSeedFromDataPairsSpacing(
  logger as Toybox.Test.Logger
) as Boolean {
  var startingData = new Array<DataPair>[4];
  var dur = new Time.Duration(60);
  var timeNow = Time.now();
  startingData[0] = new DataPair(10, timeNow);
  startingData[1] = new DataPair(11, timeNow.add(dur));
  startingData[2] = new DataPair(12, timeNow.add(dur).add(dur));
  startingData[3] = new DataPair(
    13,
    timeNow.add(dur).add(dur).add(dur).add(dur)
  );
  var buf = new CircularBuffer(3, 4, "file");
  try {
    buf.seedFromDataPairs(startingData);
  } catch (e instanceof InvalidStartingData) {
    var expected =
      "Entries should be spaced 60 seconds apart. startingData[2] and startingData[3] is spaced 120 seconds apart";
    Test.assertMessage(
      e.getErrorMessage().find(expected) != null,
      "Got '" + e.getErrorMessage() + "', expected to contain '" + expected + "'"
    );
    return true;
  }
  return false;
}

// seedFromDataPairs validates ordering.
(:test)
function testSeedFromDataPairsOrdering(
  logger as Toybox.Test.Logger
) as Boolean {
  var startingData = new Array<DataPair>[4];
  var dur = new Time.Duration(60);
  var timeNow = Time.now();
  startingData[1] = new DataPair(10, timeNow);
  startingData[0] = new DataPair(11, timeNow.add(dur));
  startingData[2] = new DataPair(12, timeNow.add(dur).add(dur));
  startingData[3] = new DataPair(13, timeNow.add(dur).add(dur).add(dur));
  var buf = new CircularBuffer(3, 4, "file");
  try {
    buf.seedFromDataPairs(startingData);
  } catch (e instanceof InvalidStartingData) {
    var myFormat =
      "Entries not ordered in increasing time startingData[0] at $1$ compared to startingData[1] at $2$.";
    var myParams = [timeNow.add(dur).value(), timeNow.value()];
    var expected = Lang.format(myFormat, myParams);
    Test.assertMessage(
      e.getErrorMessage().find(expected) != null,
      "Got '" + e.getErrorMessage() + "', expected '" + expected + "'"
    );
    return true;
  }
  return false;
}

// End-to-end: seed + addData + getOrderedArray, including stale bumping,
// missing-value padding, and circular wraparound. Same scenario as the
// pre-refactor testProperInitializationAndExtraction.
(:test)
function testFullLifecycle(logger as Toybox.Test.Logger) as Boolean {
  var startingData = new Array<DataPair>[4];
  var dur = new Time.Duration(60);
  var timeNow = Time.now();
  var lastTime = timeNow.add(dur).add(dur).add(dur); // dur*3
  startingData[0] = new DataPair(10, timeNow);
  startingData[1] = new DataPair(11, timeNow.add(dur));
  startingData[2] = new DataPair(12, timeNow.add(dur).add(dur));
  startingData[3] = new DataPair(13, lastTime);

  var buffer = new CircularBuffer(3, 4, "file");
  buffer.seedFromDataPairs(startingData);

  var arr = buffer.getOrderedArray(lastTime);
  assertArraysEqual([10, 11, 12, 13], arr);
  arr = buffer.getOrderedArray(lastTime.add(new Time.Duration(1)));
  assertArraysEqual([0, 11, 12, 13], arr);
  arr = buffer.getOrderedArray(lastTime.add(new Time.Duration(59)));
  assertArraysEqual([0, 11, 12, 13], arr);
  arr = buffer.getOrderedArray(lastTime.add(dur));
  assertArraysEqual([0, 11, 12, 13], arr);
  arr = buffer.getOrderedArray(lastTime.add(dur).add(new Time.Duration(1)));
  assertArraysEqual([0, 0, 12, 13], arr);

  lastTime = lastTime.add(dur).add(new Time.Duration(1));
  buffer.addData(14, lastTime);
  arr = buffer.getOrderedArray(lastTime);
  assertArraysEqual([12, 13, 0, 14], arr);

  lastTime = lastTime.add(new Time.Duration(1));
  buffer.addData(15, lastTime);
  arr = buffer.getOrderedArray(lastTime);
  assertArraysEqual([12, 13, 0, 14], arr);

  lastTime = lastTime.add(new Time.Duration(58));
  buffer.addData(15, lastTime);
  arr = buffer.getOrderedArray(lastTime);
  assertArraysEqual([12, 13, 0, 14], arr);

  lastTime = lastTime.add(new Time.Duration(1));
  buffer.addData(15, lastTime);
  arr = buffer.getOrderedArray(lastTime);
  assertArraysEqual([13, 0, 14, 15], arr);

  lastTime = lastTime.add(dur).add(dur).add(dur);
  buffer.addData(16, lastTime);
  arr = buffer.getOrderedArray(lastTime);
  assertArraysEqual([15, 0, 0, 16], arr);

  lastTime = lastTime.add(dur).add(dur).add(dur).add(dur).add(dur).add(dur);
  buffer.addData(17, lastTime);
  arr = buffer.getOrderedArray(lastTime);
  assertArraysEqual([0, 0, 0, 17], arr);

  return true;
}
