import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.Application.Storage;
using Toybox.Time;

class MannyrayWatchFaceApp extends Application.AppBase {
  var minutesToTrackHeartBeat;
  var dataDensityForHeartTrack;
  var graphTicks;

  var allDataStaleLimit = 2;

  var heartData;
  var variableForHeartData;
  var xAxisTitle;

  function initialize() {
    AppBase.initialize();

    // One-shot: copy shipped presets into user storage on first launch.
    maybeImportShippedPresets();

    // Single buffer covering the longest display window (10 min) at
    // 1-second resolution = 601 entries. CircularBuffer stores values
    // and timestamps in two flat Array<Number> (~8 bytes/entry) instead
    // of an Array<DataPair> with nested Time.Moment objects, so 601
    // entries fit comfortably in the watchFace memory budget.
    minutesToTrackHeartBeat = 10;
    dataDensityForHeartTrack = 601;
    variableForHeartData = "heartData";

    // Initial xAxisTitle / graphTicks are based on the user's stored
    // setting just so the first paint looks right; the view re-derives
    // them per tick from the current property value.
    var displayMinutes =
      Application.Properties.getValue("HeartGraphMinutes") as Number;
    if (displayMinutes != 3 && displayMinutes != 5 && displayMinutes != 10) {
      displayMinutes = 3;
    }
    xAxisTitle = "last " + displayMinutes + " minutes";
    graphTicks = displayMinutes;
  }

  // Build the heart-rate buffer at boot. Allocates an empty buffer of the
  // configured capacity (no per-entry DataPair allocations), then seeds it
  // — first trying the persisted storage and falling back to the system
  // sensor history if storage is missing/stale/incompatible.
  function buildHeartBuffer() as CircularBuffer {
    var buffer = new CircularBuffer(
      minutesToTrackHeartBeat,
      dataDensityForHeartTrack,
      variableForHeartData
    );
    var currentTime = Time.now();
    var loaded = false;
    if (!buffer.isPersistedDataStale(currentTime, allDataStaleLimit * 60)) {
      loaded = buffer.seedFromStorage();
    }
    if (!loaded) {
      // Sparse sensor history is typically 30-50 entries — small enough
      // that the DataPair allocation here is negligible vs. the 601-entry
      // buffer.
      var sparse = getHeartHistory(minutesToTrackHeartBeat);
      var firstTime =
        currentTime.subtract(new Time.Duration(minutesToTrackHeartBeat * 60));
      buffer.seedFromSparseHistory(sparse, firstTime);
    }
    return buffer;
  }

  // onStart() is called on application start up
  function onStart(state as Dictionary?) as Void {}

  // onStop() is called when your application is exiting
  function onStop(state as Dictionary?) as Void {}

  // Return the initial view of your application here
  function getInitialView() {
    var buffer = buildHeartBuffer();
    if (Toybox.WatchUi.WatchFace has :onPartialUpdate) {
      return [
        new MannyrayWatchFaceView(buffer, xAxisTitle, graphTicks),
        new MannyrayWatchDelegate(),
      ];
    } else {
      return [
        new MannyrayWatchFaceView(buffer, xAxisTitle, graphTicks),
      ];
    }
  }

  // New app settings have been received so trigger a UI update
  function onSettingsChanged() as Void {
    WatchUi.requestUpdate();
  }

  function getSettingsView() {
    return [new SettingsMenu(), new SettingsMenuDelegate()];
  }
}

function getApp() as MannyrayWatchFaceApp {
  return Application.getApp() as MannyrayWatchFaceApp;
}
