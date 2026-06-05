import Toybox.Application;
import Toybox.Lang;

// Shareable settings codes — 12-char ASCII strings encoding all
// user-tunable settings so a screenshot caption or a forum post can
// communicate a complete look.
//
// Format: "v1.0-XXXXX-Y"
//   v1.0-     versioned prefix (lets us evolve the schema)
//   XXXXX     5 Crockford Base32 chars = 25 bits of packed settings
//   -         separator
//   Y         1 Base32 char = checksum (mod-32 sum of XXXXX char values)
//
// Bit layout (LSB = bit 0):
//   bit  0     reserved (v2 inline-palette flag) — always 0 in v1
//   bits 1-2   BackgroundColor   (0=black, 1=white)
//   bits 3-4   TimeColor         (0=default/-2, 1=gray/0x555555)
//   bits 5-6   GraphNumberColor  (0=default/-2, 1=hidden/-3, 2=gray/0xAAAAAA)
//   bits 7-9   HRMin             (0=30, 1=35, … 7=65)
//   bits 10-14 HRMax delta       (encoded as (HRMax-HRMin-20)/10; 0..31)
//   bits 15-16 HRStep            (0=5, 1=10, 2=15, 3=20)
//   bits 17-20 PaletteIndex      (0..15)
//   bit  21    GraphBandPixels   (0=10, 1=20)
//   bits 22-23 HeartGraphMinutes (0=3, 1=5, 2=10, 3=reserved)
//   bit  24    MinimalMode

const BASE32_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

function base32CharAt(idx as Number) as String {
  return BASE32_ALPHABET.substring(idx, idx + 1);
}

function base32CharToInt(s as String) as Number {
  var up = s.toUpper();
  // Crockford equivalences for typed input
  if (up.equals("I") || up.equals("L")) { return 1; }
  if (up.equals("O")) { return 0; }
  for (var i = 0; i < 32; i++) {
    if (BASE32_ALPHABET.substring(i, i + 1).equals(up)) {
      return i;
    }
  }
  return -1;
}

function base32Encode(value as Number, numChars as Number) as String {
  var result = "";
  for (var i = numChars - 1; i >= 0; i--) {
    result += base32CharAt((value >> (i * 5)) & 0x1F);
  }
  return result;
}

function base32Decode(s as String) as Number {
  var value = 0;
  for (var i = 0; i < s.length(); i++) {
    var v = base32CharToInt(s.substring(i, i + 1));
    if (v < 0) { return -1; }
    value = (value << 5) | v;
  }
  return value;
}

function computeChecksum(payload as String) as String {
  var sum = 0;
  for (var i = 0; i < payload.length(); i++) {
    sum += base32CharToInt(payload.substring(i, i + 1));
  }
  return base32CharAt(sum & 0x1F);
}

// --- per-field encoders / decoders ---

function _bgEnc(color as Number) as Number {
  return color == 0xFFFFFF ? 1 : 0;
}
function _bgDec(b as Number) as Number {
  return b == 1 ? 0xFFFFFF : 0x000000;
}

function _tcEnc(color as Number) as Number {
  return color == 0x555555 ? 1 : 0;
}
function _tcDec(b as Number) as Number {
  return b == 1 ? 0x555555 : -2;
}

function _gnEnc(color as Number) as Number {
  if (color == -3) { return 1; }      // hidden
  if (color == 0xAAAAAA) { return 2; } // gray
  return 0;                            // default (-2)
}
function _gnDec(b as Number) as Number {
  if (b == 1) { return -3; }
  if (b == 2) { return 0xAAAAAA; }
  return -2;
}

function _hrMinEnc(hr as Number) as Number {
  var v = (hr - 30) / 5;
  if (v < 0) { v = 0; }
  if (v > 7) { v = 7; }
  return v;
}
function _hrMinDec(b as Number) as Number {
  return 30 + b * 5;
}

function _hrMaxEnc(hrMax as Number, hrMin as Number) as Number {
  var delta = (hrMax - hrMin - 20) / 10;
  if (delta < 0) { delta = 0; }
  if (delta > 31) { delta = 31; }
  return delta;
}
function _hrMaxDec(b as Number, hrMin as Number) as Number {
  return hrMin + 20 + b * 10;
}

function _hrStepEnc(step as Number) as Number {
  if (step <= 5) { return 0; }
  if (step <= 10) { return 1; }
  if (step <= 15) { return 2; }
  return 3;
}
function _hrStepDec(b as Number) as Number {
  var steps = [5, 10, 15, 20] as Array<Number>;
  return steps[b];
}

function _bandEnc(px as Number) as Number {
  return px == 20 ? 1 : 0;
}
function _bandDec(b as Number) as Number {
  return b == 1 ? 20 : 10;
}

function _minutesEnc(m as Number) as Number {
  if (m == 3) { return 0; }
  if (m == 5) { return 1; }
  return 2;
}
function _minutesDec(b as Number) as Number {
  var mins = [3, 5, 10, 3] as Array<Number>;
  return mins[b];
}

// --- public API ---

function encodeSettings(values as Dictionary) as String {
  var hrMin = values["HRMin"] as Number;
  var packed = 0;
  // bit 0: v2 flag, always 0 in v1
  packed = packed | ((_bgEnc(values["BackgroundColor"] as Number) & 0x3) << 1);
  packed = packed | ((_tcEnc(values["TimeColor"] as Number) & 0x3) << 3);
  packed = packed | ((_gnEnc(values["GraphNumberColor"] as Number) & 0x3) << 5);
  packed = packed | ((_hrMinEnc(hrMin) & 0x7) << 7);
  packed = packed | ((_hrMaxEnc(values["HRMax"] as Number, hrMin) & 0x1F) << 10);
  packed = packed | ((_hrStepEnc(values["HRStep"] as Number) & 0x3) << 15);
  packed = packed | (((values["PaletteIndex"] as Number) & 0xF) << 17);
  packed = packed | ((_bandEnc(values["GraphBandPixels"] as Number) & 0x1) << 21);
  packed = packed | ((_minutesEnc(values["HeartGraphMinutes"] as Number) & 0x3) << 22);
  packed = packed | (((values["MinimalMode"] as Boolean) ? 1 : 0) << 24);

  var payload = base32Encode(packed, 5);
  return "v1.0-" + payload + "-" + computeChecksum(payload);
}

// Returns null if the code is malformed, has a bad checksum, or is from
// a future format version (flag bit 0 set).
function decodeSettings(code as String) as Dictionary or Null {
  if (code == null) { return null; }
  if (code.length() != 12) { return null; }
  if (!code.substring(0, 5).equals("v1.0-")) { return null; }
  if (!code.substring(10, 11).equals("-")) { return null; }

  var payload = code.substring(5, 10);
  var checksumChar = code.substring(11, 12);
  if (!computeChecksum(payload).equals(checksumChar)) { return null; }

  var packed = base32Decode(payload);
  if (packed < 0) { return null; }
  // Reject v2+ formats (bit 0 reserved for inline-palette flag).
  if ((packed & 0x1) != 0) { return null; }

  var hrMin = _hrMinDec((packed >> 7) & 0x7);
  return {
    "BackgroundColor" => _bgDec((packed >> 1) & 0x3),
    "TimeColor" => _tcDec((packed >> 3) & 0x3),
    "GraphNumberColor" => _gnDec((packed >> 5) & 0x3),
    "HRMin" => hrMin,
    "HRMax" => _hrMaxDec((packed >> 10) & 0x1F, hrMin),
    "HRStep" => _hrStepDec((packed >> 15) & 0x3),
    "PaletteIndex" => (packed >> 17) & 0xF,
    "GraphBandPixels" => _bandDec((packed >> 21) & 0x1),
    "HeartGraphMinutes" => _minutesDec((packed >> 22) & 0x3),
    "MinimalMode" => ((packed >> 24) & 0x1) == 1
  };
}
