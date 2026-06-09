// Dev-only synthetic HR scenarios driving the Test Mode picker. The
// whole file is `(:dev_only)`-annotated so none of it links into the
// release binary (./build.sh --export passes `-r`).
//
// Each scenario builds a 601-entry array (one entry per second over a
// 10-min window). The view rotates this array so its tail corresponds
// to "now", then slices + resamples it like real heart-history data —
// the synthetic curve scrolls and loops at the displayed cadence.
//
// Realism notes
//   - All numeric ranges (baseline, noise, spikes, phase HRs) were
//     picked against published resting / orthostatic / parasympathetic-
//     dominant HR ranges (Task Force HRV review; orthostatic-response
//     literature; MIT-BIH Normal Sinus Rhythm characterisation of
//     healthy adults). Curves are NOT slices of real datasets — they
//     are physiologically-grounded synthesis. See README of
//     colour-variants/ for the licensing reasoning.
//   - PRNG is Math.srand-seeded per scenario so each curve is
//     deterministic across runs (a given scenario always looks the
//     same) while still appearing noisy at a glance.
//
import Toybox.Lang;
import Toybox.Math;

(:dev_only)
function getTestScenarioNames() as Array<String> {
  return ["Ramp", "Anxious Rest", "Active Burst", "Steady Calm"]
    as Array<String>;
}

// Build the full 601-entry data array for the given scenario.
// `hrMin`, `paletteSize`, `hrStep` only matter for the Ramp scenario —
// the others use fixed absolute HR values so a "low 50s resting" curve
// looks like 50s regardless of how the user has configured the bands.
(:dev_only)
function buildTestScenarioData(
  idx as Number,
  length as Number,
  hrMin as Number,
  paletteSize as Number,
  hrStep as Number
) as Array<Number> {
  if (idx == 0) {
    return _buildRamp(length, hrMin, paletteSize, hrStep);
  } else if (idx == 1) {
    return _buildAnxiousRest(length);
  } else if (idx == 2) {
    return _buildActiveBurst(length);
  } else if (idx == 3) {
    return _buildSteadyCalm(length);
  }
  return _buildRamp(length, hrMin, paletteSize, hrStep);
}

// --- per-scenario builders ---

// Linear ramp from hrMin to the top of the palette range. Useful for
// evaluating palette gradients across the full configured band space.
(:dev_only)
function _buildRamp(
  length as Number,
  hrMin as Number,
  paletteSize as Number,
  hrStep as Number
) as Array<Number> {
  var data = new Array<Number>[length];
  var top = hrMin + paletteSize * hrStep;
  for (var i = 0; i < length; i++) {
    data[i] = hrMin + (i * (top - hrMin)) / length;
  }
  return data;
}

// "Resting but slightly anxious." Baseline ~58 bpm with low-frequency
// drift (autonomic wander) and three brief sympathetic mini-arousals
// peaking 70–74 bpm. Calibration target: subjects whose baseline HR
// sits in the 50s–60s with occasional excursions into low 70s during
// rumination, matching WESAD baseline behavior for healthy adults.
(:dev_only)
function _buildAnxiousRest(length as Number) as Array<Number> {
  Math.srand(1009);
  var baseline = 58;
  var drift = _smoothRandomWalk(length, 2, 5);  // ±5 bpm, ~2 step
  var data = new Array<Number>[length];
  for (var t = 0; t < length; t++) {
    data[t] = baseline + drift[t] + _noiseInt(1);
  }
  // Each pulse's :offset is amplitude above baseline (peak ≈ 58+offset).
  _applyPulses(data, [
    { :start =>  95, :offset => 14, :rise => 4, :hold => 8, :fall => 18 },
    { :start => 280, :offset => 15, :rise => 5, :hold => 6, :fall => 20 },
    { :start => 470, :offset => 13, :rise => 3, :hold => 7, :fall => 16 }
  ] as Array<Dictionary>);
  return data;
}

// Sit-to-stand + brief walk + recovery. Five phases following the
// orthostatic-response literature: ~2.5 min seated rest, 30s ramp on
// standing, ~2.5 min walking plateau, ~1.5 min recovery decay, ~3 min
// slightly-elevated post-activity rest.
(:dev_only)
function _buildActiveBurst(length as Number) as Array<Number> {
  Math.srand(2017);
  var drift = _smoothRandomWalk(length, 1, 3);
  var data = new Array<Number>[length];
  for (var t = 0; t < length; t++) {
    var base;
    if (t < 150) {
      base = 62;
    } else if (t < 180) {
      // Linear ramp 62 → 90 over 30s
      base = 62 + ((t - 150) * 28) / 30;
    } else if (t < 330) {
      base = 90;
    } else if (t < 420) {
      // Exponential-ish decay 90 → 64 over 90s; approximated as
      // weighted linear blend so we stay in integer math.
      var k = t - 330;          // 0..89
      var remaining = 90 - k;   // 90..1
      base = 64 + (26 * remaining * remaining) / (90 * 90);
    } else {
      base = 64;
    }
    var noiseRange = (t >= 180 && t < 330) ? 3 : 2;
    data[t] = base + drift[t] + _noiseInt(noiseRange);
  }
  return data;
}

// Trained / parasympathetic-dominant resting: tight baseline ~48 with
// ~6 brief micro-rises to low 50s scattered through the window. Mirrors
// the look of overnight NSR data from athletic subjects.
(:dev_only)
function _buildSteadyCalm(length as Number) as Array<Number> {
  Math.srand(3023);
  var baseline = 48;
  var drift = _smoothRandomWalk(length, 1, 2);
  var data = new Array<Number>[length];
  for (var t = 0; t < length; t++) {
    data[t] = baseline + drift[t] + _noiseInt(1);
  }
  // Each pulse's :offset is amplitude above baseline (peak ≈ 48+offset).
  _applyPulses(data, [
    { :start =>  60, :offset => 4, :rise => 2, :hold => 4, :fall => 6 },
    { :start => 145, :offset => 3, :rise => 2, :hold => 3, :fall => 5 },
    { :start => 220, :offset => 5, :rise => 3, :hold => 4, :fall => 7 },
    { :start => 330, :offset => 4, :rise => 2, :hold => 5, :fall => 6 },
    { :start => 425, :offset => 3, :rise => 2, :hold => 3, :fall => 5 },
    { :start => 525, :offset => 4, :rise => 3, :hold => 4, :fall => 6 }
  ] as Array<Dictionary>);
  return data;
}

// --- helpers ---

(:dev_only)
function _noiseInt(range as Number) as Number {
  if (range <= 0) { return 0; }
  return (Math.rand() % (2 * range + 1)) - range;
}

// Bounded random walk: each step ±`stepRange`, clamped to ±`amplitude`.
// Produces a smooth low-frequency drift suitable for autonomic-like
// modulation around a baseline.
(:dev_only)
function _smoothRandomWalk(
  length as Number,
  stepRange as Number,
  amplitude as Number
) as Array<Number> {
  var buf = new Array<Number>[length];
  buf[0] = 0;
  for (var t = 1; t < length; t++) {
    var v = buf[t - 1] + _noiseInt(stepRange);
    if (v >  amplitude) { v =  amplitude; }
    if (v < -amplitude) { v = -amplitude; }
    buf[t] = v;
  }
  return buf;
}

// Add trapezoidal rise/hold/fall pulses INTO an existing data array in
// place. For each pulse, iterates only over its [start, start+span)
// window — O(pulses × maxSpan) instead of the previous O(pulses ×
// length) per-time-step check, which tripped the per-tick watchdog on
// the Steady Calm scenario (6 pulses × 601 samples = ~3.6k iterations).
//
// The caller is responsible for setting :offset = peak - baseline at
// definition so amplitudes stack additively on top of the existing
// baseline+drift+noise values already filled into `data`.
(:dev_only)
function _applyPulses(
  data as Array<Number>,
  pulses as Array<Dictionary>
) as Void {
  var length = data.size();
  for (var i = 0; i < pulses.size(); i++) {
    var p = pulses[i];
    var start  = p[:start]  as Number;
    var rise   = p[:rise]   as Number;
    var hold   = p[:hold]   as Number;
    var fall   = p[:fall]   as Number;
    var offset = p[:offset] as Number;
    var span = rise + hold + fall;
    for (var rel = 0; rel < span; rel++) {
      var t = start + rel;
      if (t < 0 || t >= length) { continue; }
      var amp;
      if (rel < rise) {
        amp = (offset * rel) / rise;
      } else if (rel < rise + hold) {
        amp = offset;
      } else {
        var dRel = rel - rise - hold;
        amp = (offset * (fall - dRel)) / fall;
      }
      data[t] = data[t] + amp;
    }
  }
}
