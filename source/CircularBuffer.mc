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

class InvalidStartingData extends Lang.Exception {
  var errorMessage as String = "";
  function initialize(errorMessage as String) {
    self.errorMessage = errorMessage;
    Exception.initialize();
  }

  function getErrorMessage() {
    return errorMessage;
  }
}

// (value, time) pair. Used as the input type to seedFromDataPairs() in
// tests and to seedFromSparseHistory() (where it carries sparse sensor
// readings — typically only 30-50 entries, so the allocation cost is
// negligible compared to the 601-entry buffer itself).
class DataPair {
  public var value as Number;
  public var time as Time.Moment;
  public var stale as Boolean;
  public function initialize(value as Number, time as Time.Moment) {
    self.value = value;
    self.time = time;
    self.stale = false;
  }
}

// Fixed-capacity circular buffer of HR values at uniform time spacing.
// Stores only the values array + a single freshestTimeSec anchor — every
// other entry's nominal time is derivable as
//   freshestTimeSec - k * approxSecondsBetweenBins
// (k = index distance back from freshest).
class CircularBuffer {
  var saveName as String;
  const dataSuffixSaveName = "_data";
  const freshestTimeSuffixSaveName = "_freshestTime";
  const durationSuffixSaveName = "_durationSec";
  // Legacy persistence key (per-entry times array), kept only for migration
  // in seedFromStorage(). New writes don't touch it.

  var durationInSeconds as Number;
  var approxSecondsBetweenBins as Number;

  public const staleValue = 0;
  public const missingValue = 0;

  var values as Array<Number>;
  var freshestTimeSec as Number = 0;
  var dataLastPointer as Number = 0;

  // Allocates an empty buffer of `binCount` slots covering `durationInMinutes`.
  // Caller must seed via one of seedFromStorage / seedFromSparseHistory /
  // seedFromDataPairs before reading data.
  public function initialize(
    durationInMinutes as Number,
    binCount as Number,
    saveName as String
  ) {
    if (binCount < 2) {
      throw new InvalidStartingData("staringData is too small.");
    }
    if ((durationInMinutes * 60) % (binCount - 1) != 0) {
      throw new InvalidStartingData(
        "The duration of each bin has to be a whole number in seconds."
      );
    }
    self.saveName = saveName;
    self.durationInSeconds = durationInMinutes * 60;
    self.approxSecondsBetweenBins = self.durationInSeconds / (binCount - 1);
    self.values = new Array<Number>[binCount];
    self.freshestTimeSec = 0;
    self.dataLastPointer = 0;
  }

  // Seed from a validated DataPair sequence. Used by the unit tests; carries
  // the original ordering + spacing validation from the pre-refactor
  // constructor. Error message wording mirrors the originals so the tests'
  // substring matches continue to pass.
  public function seedFromDataPairs(
    startingData as Array<DataPair>
  ) as Void {
    var n = values.size();
    if (startingData.size() != n) {
      throw new InvalidStartingData(
        "startingData size " + startingData.size() + " != buffer size " + n
      );
    }
    var prevTimeSec = startingData[0].time.value();
    for (var i = 0; i < n; i++) {
      if (i < n - 1) {
        var nextTimeSec = startingData[i + 1].time.value();
        if (prevTimeSec > nextTimeSec) {
          var myFormat =
            "Entries not ordered in increasing time startingData[$1$] at $2$ compared to startingData[$3$] at $4$.";
          var myParams = [i, prevTimeSec, i + 1, nextTimeSec];
          throw new InvalidStartingData(Lang.format(myFormat, myParams));
        }
        if (nextTimeSec - prevTimeSec != approxSecondsBetweenBins) {
          var myFormat =
            "Entries should be spaced $1$ seconds apart. startingData[$2$] and startingData[$3$] is spaced $4$ seconds apart.";
          var myParams = [
            approxSecondsBetweenBins,
            i,
            i + 1,
            nextTimeSec - prevTimeSec,
          ];
          throw new InvalidStartingData(Lang.format(myFormat, myParams));
        }
        prevTimeSec = nextTimeSec;
      }
      values[i] = startingData[i].value;
    }
    self.freshestTimeSec = prevTimeSec;
    self.dataLastPointer = 0;
  }

  // Seed from a sparse sensor-history sequence (oldest-first), populating
  // every bin with the most recent sample whose timestamp <= the bin's
  // nominal time. firstTime is the time of the OLDEST bin (the first slot).
  // Writes directly into self.values — no transient per-entry allocations.
  public function seedFromSparseHistory(
    sparseHistory as Array<DataPair>,
    firstTime as Time.Moment
  ) as Void {
    var n = values.size();
    var firstSec = firstTime.value();
    self.freshestTimeSec = firstSec + (n - 1) * approxSecondsBetweenBins;
    self.dataLastPointer = 0;

    if (sparseHistory.size() == 0) {
      for (var i = 0; i < n; i++) {
        values[i] = 0;
      }
      return;
    }

    var srcIdx = 0;
    var srcMax = sparseHistory.size() - 1;
    for (var i = 0; i < n; i++) {
      var binTimeSec = firstSec + i * approxSecondsBetweenBins;
      while (
        srcIdx < srcMax &&
        sparseHistory[srcIdx + 1].time.value() <= binTimeSec
      ) {
        srcIdx += 1;
      }
      values[i] = sparseHistory[srcIdx].value;
    }
  }

  // Try to seed from persisted storage. Returns true on success.
  // Handles a legacy migration path: if the new freshestTime/durationSec
  // keys are absent, falls back to reading the old per-entry "_time" array
  // and reconstructing the anchor from its first + last elements.
  // Returns false if there's no usable data or it doesn't fit our buffer.
  public function seedFromStorage() as Boolean {
    var dataValue =
      Application.Storage.getValue(saveName + dataSuffixSaveName);
    if (dataValue == null) { return false; }
    var dataArr = dataValue as Array<Number>;
    if (dataArr.size() != values.size()) { return false; }

    var freshestSec =
      Application.Storage.getValue(saveName + freshestTimeSuffixSaveName);
    var durationSec =
      Application.Storage.getValue(saveName + durationSuffixSaveName);

    if (freshestSec == null || durationSec == null) {
      var legacyTimes = Application.Storage.getValue(saveName + "_time");
      if (legacyTimes == null) { return false; }
      var legacyArr = legacyTimes as Array<Number>;
      var lastIdx = legacyArr.size() - 1;
      if (lastIdx < 1) { return false; }
      freshestSec = legacyArr[lastIdx];
      durationSec = legacyArr[lastIdx] - legacyArr[0];
    }
    if ((durationSec as Number) != self.durationInSeconds) { return false; }

    for (var i = 0; i < values.size(); i++) {
      values[i] = dataArr[i];
    }
    self.freshestTimeSec = freshestSec as Number;
    self.dataLastPointer = 0;
    return true;
  }

  // True if the persisted data's freshest timestamp is more than maxStaleSec
  // before currentTime (or if there's no readable persistence at all). Lets
  // the App decide whether to fall back to seedFromSparseHistory without
  // doing a full read.
  public function isPersistedDataStale(
    currentTime as Time.Moment,
    maxStaleSec as Number
  ) as Boolean {
    var freshestSec =
      Application.Storage.getValue(saveName + freshestTimeSuffixSaveName);
    if (freshestSec == null) {
      var legacyTimes = Application.Storage.getValue(saveName + "_time");
      if (legacyTimes == null) { return true; }
      var legacyArr = legacyTimes as Array<Number>;
      if (legacyArr.size() == 0) { return true; }
      freshestSec = legacyArr[legacyArr.size() - 1];
    }
    return (currentTime.value() - (freshestSec as Number)) > maxStaleSec;
  }

  // O(1) closed-form: see the derivation comment that used to live here.
  private function markStaleSec(currentTimeSec as Number) as Number {
    var elapsed = currentTimeSec - freshestTimeSec;
    if (elapsed <= 0) { return 0; }
    var stale = (elapsed - 1) / approxSecondsBetweenBins + 1;
    var cap = values.size();
    if (stale > cap) { stale = cap; }
    return stale;
  }

  public function addData(value as Number, time as Time.Moment) as Void {
    // ideally staleCount is at most 1. If greater, the watch slept and we
    // missed ticks; fill the missed slots with missingValue and put the new
    // sample in the freshest slot.
    var staleCount = markStaleSec(time.value());
    while (staleCount > 0) {
      var replacementValue = self.missingValue;
      if (staleCount == 1) {
        replacementValue = value;
      }
      self.freshestTimeSec =
        self.freshestTimeSec + self.approxSecondsBetweenBins;
      values[self.dataLastPointer] = replacementValue;
      self.dataLastPointer = (self.dataLastPointer + 1) % values.size();
      staleCount = staleCount - 1;
    }
  }

  public function size() as Number {
    return values.size();
  }

  // Save data to persistent storage.
  public function backupData() as Void {
    var currentTime = Time.now();
    var dataValue = self.getOrderedArray(currentTime);
    Application.Storage.setValue(
      self.saveName + self.dataSuffixSaveName,
      dataValue
    );
    Application.Storage.setValue(
      self.saveName + self.freshestTimeSuffixSaveName,
      self.freshestTimeSec
    );
    Application.Storage.setValue(
      self.saveName + self.durationSuffixSaveName,
      self.durationInSeconds
    );
  }

  // Values in oldest→newest order. The first staleCount slots are stale
  // (replaced with staleValue); the rest are the real buffer contents
  // unwrapped from the circular index.
  public function getOrderedArray(currentTime as Time.Moment) as Array<Number> {
    var staleCount = markStaleSec(currentTime.value());
    var n = values.size();
    var returnArray = new Array<Number>[n];
    for (var i = 0; i < n; i++) {
      if (i < staleCount) {
        returnArray[i] = staleValue;
      } else {
        var src = (self.dataLastPointer + i) % n;
        returnArray[i] = self.values[src];
      }
    }
    return returnArray;
  }
}
