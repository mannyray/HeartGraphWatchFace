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
    "ShowGraphAxis",
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
    "ShowGraphAxis" => true,
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

// On every launch, import any shipped preset whose name hasn't been
// imported before. After import, shipped presets are indistinguishable
// from user-saved ones — fully renameable and deletable. A deleted
// shipped preset is NOT re-imported because we track imports by name,
// not by current presence in user storage.
//
// This means: adding a new entry to presets/shipped.json and shipping
// an updated .prg WILL surface the new preset on existing installs.
//
// Migration from the previous global-boolean flag is handled below —
// existing users carry over without losing or duplicating their lists.
function maybeImportShippedPresets() as Void {
  var importedRaw = Storage.getValue("importedShippedPresetNames");
  var importedNames;
  if (importedRaw == null) {
    importedNames = [] as Array<String>;
    // Migration: old code stored a global boolean "shippedPresetsImported".
    // If it was set, the user has already seen every currently-shipped
    // preset name at least once — seed the name list so we don't resurrect
    // any they intentionally renamed or deleted.
    var oldFlag = Storage.getValue("shippedPresetsImported");
    if (oldFlag == true) {
      var seed = getShippedPresets();
      if (seed != null) {
        for (var i = 0; i < seed.size(); i++) {
          importedNames.add((seed[i] as Dictionary)["name"] as String);
        }
      }
      Storage.setValue("importedShippedPresetNames", importedNames);
      Storage.deleteValue("shippedPresetsImported");
      return;
    }
  } else {
    importedNames = importedRaw as Array<String>;
  }

  var shipped = getShippedPresets();
  if (shipped == null || shipped.size() == 0) { return; }

  var userPresets = getUserPresets();
  var userChanged = false;
  var importedChanged = false;

  for (var i = 0; i < shipped.size(); i++) {
    var sp = shipped[i] as Dictionary;
    var spName = sp["name"] as String;

    if (_containsName(importedNames, spName)) { continue; }

    // Collision with an existing user preset? Mark imported but don't
    // overwrite the user's data.
    var collision = false;
    for (var j = 0; j < userPresets.size(); j++) {
      if (((userPresets[j] as Dictionary)["name"] as String).equals(spName)) {
        collision = true;
        break;
      }
    }
    if (!collision) {
      userPresets.add(sp);
      userChanged = true;
    }
    importedNames.add(spName);
    importedChanged = true;
  }

  if (userChanged) { setUserPresets(userPresets); }
  if (importedChanged) {
    Storage.setValue("importedShippedPresetNames", importedNames);
  }
}

function _containsName(names as Array<String>, target as String) as Boolean {
  for (var i = 0; i < names.size(); i++) {
    if (names[i].equals(target)) { return true; }
  }
  return false;
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
  return savePresetWithNameAndValues(name, snapshotCurrentSettings());
}

// Same as savePresetWithName but takes an explicit values dict. Used by
// the "Enter code" flow which already has a decoded settings dict in hand.
function savePresetWithNameAndValues(
  name as String,
  values as Dictionary
) as Boolean {
  if (name.equals("Default") || name.equals("")) {
    return false;
  }
  var presets = getUserPresets();
  for (var i = 0; i < presets.size(); i++) {
    var p = presets[i] as Dictionary;
    if ((p["name"] as String).equals(name)) {
      p["values"] = values;
      setUserPresets(presets);
      return true;
    }
  }
  presets.add({ "name" => name, "values" => values });
  setUserPresets(presets);
  return true;
}

// Renames a user preset in place. Rejects "Default" as a target name (reserved
// for the built-in) and empty strings. Returns true on success.
function renamePreset(oldName as String, newName as String) as Boolean {
  if (newName.equals("Default") || newName.equals("") || newName.equals(oldName)) {
    return false;
  }
  var presets = getUserPresets();
  for (var i = 0; i < presets.size(); i++) {
    var p = presets[i] as Dictionary;
    if ((p["name"] as String).equals(oldName)) {
      p["name"] = newName;
      setUserPresets(presets);
      return true;
    }
  }
  return false;
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
