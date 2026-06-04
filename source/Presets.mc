import Toybox.Application;
import Toybox.Lang;
using Toybox.Application.Storage;

// Property keys that a preset snapshot contains. Adding a new
// user-controllable setting? Add its key here too so it gets included in
// snapshots and applied on switch.
function presetKeys() as Array<String> {
  return [
    "BackgroundColor",
    "TimeColor",
    "GraphNumberColor",
    "HRMin",
    "HRMax",
    "HRStep",
    "PaletteIndex",
    "GraphBandPixels",
    "HeartGraphMinutes",
    "MinimalMode"
  ] as Array<String>;
}

// Values for the built-in Default preset (matches the Reset action).
function getDefaultPresetValues() as Dictionary {
  return {
    "BackgroundColor" => 0x000000,
    "TimeColor" => 0x555555,
    "GraphNumberColor" => -3,
    "HRMin" => 40,
    "HRMax" => 100,
    "HRStep" => 10,
    "PaletteIndex" => 0,
    "GraphBandPixels" => 10,
    "HeartGraphMinutes" => 3,
    "MinimalMode" => false
  };
}

function getUserPresets() as Array {
  var stored = Storage.getValue("userPresets");
  if (stored == null) {
    return [] as Array;
  }
  return stored as Array;
}

function setUserPresets(presets as Array) as Void {
  Storage.setValue("userPresets", presets);
}

function snapshotCurrentSettings() as Dictionary {
  var keys = presetKeys();
  var snap = {};
  for (var i = 0; i < keys.size(); i++) {
    snap[keys[i]] = Application.Properties.getValue(keys[i]);
  }
  return snap;
}

function applyPresetValues(values as Dictionary) as Void {
  var keys = presetKeys();
  for (var i = 0; i < keys.size(); i++) {
    var k = keys[i];
    if (values.hasKey(k)) {
      Application.Properties.setValue(k, values[k]);
    }
  }
}

// Adds a new user preset capturing the current settings, or replaces an
// existing one with the same name. "Default" is reserved for the built-in.
function savePresetWithName(name as String) as Boolean {
  if (name.equals("Default") || name.equals("")) {
    return false;
  }
  var snapshot = snapshotCurrentSettings();
  var presets = getUserPresets();
  for (var i = 0; i < presets.size(); i++) {
    var p = presets[i] as Dictionary;
    if ((p["name"] as String).equals(name)) {
      p["values"] = snapshot;
      setUserPresets(presets);
      return true;
    }
  }
  presets.add({ "name" => name, "values" => snapshot });
  setUserPresets(presets);
  return true;
}

function deletePresetByName(name as String) as Void {
  var presets = getUserPresets();
  for (var i = 0; i < presets.size(); i++) {
    var p = presets[i] as Dictionary;
    if ((p["name"] as String).equals(name)) {
      presets.remove(p);
      setUserPresets(presets);
      return;
    }
  }
}
