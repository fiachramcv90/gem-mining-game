// ============================================================================
// Gem Miner — ECONOMY SIMULATION  (ticket 0006, PROTOTYPE — throwaway)
// ----------------------------------------------------------------------------
// A spreadsheet-in-code. Answers "does the money loop feel right?" by turning
// the FIRST-DRAFT knobs below into 20 simulated runs + curves you can react to.
// Not game code. Runs under node (run.js) AND inside the interactive artifact.
//
//   FIXED by ticket 0005 (worldgen): band edges, baseline hardness, gem tiers &
//   positions, ~8% density, dig_constant 0.34s, halo +1 / prize +2.  0006 only
//   assigns VALUES and the upgrade curves.
//   PLACEHOLDER, owned by 0007 (hazards): hull damage & the darkness/Light
//   benefit. Modelled crudely here only so hull/Light have a shape to price
//   against — the taste calls that matter are gems, drill, fuel, cargo, pricing.
// ============================================================================

// ---- seeded RNG (mulberry32) so 20 runs are reproducible ----
function makeRng(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ===========================================================================
// THE KNOBS.  Everything 0006 owns lives here. `// FIXED` = inherited, don't
// treat as a 0006 knob; everything else is a first-draft dial to react to.
// ===========================================================================
const DEFAULTS = {
  // --- geometry, FIXED by 0005 -------------------------------------------
  bands: [
    { name: 'Topsoil',   top: 0,   bottom: 40,  hardness: 1 },
    { name: 'Clay',      top: 40,  bottom: 120, hardness: 2 },
    { name: 'Sandstone', top: 120, bottom: 260, hardness: 3 },
    { name: 'Granite',   top: 260, bottom: 450, hardness: 4 },
    { name: 'Bedrock',   top: 450, bottom: 700, hardness: 5 },
  ],
  digConstant: 0.34,        // FIXED (0004): drill seconds per hardness point
  gemDensity: 0.08,         // FIXED (0005): fraction of dug tiles bearing a gem
  haloHardnessBonus: 1,     // FIXED (0005): vein-halo resistance spike
  prizeHardnessBonus: 2,    // FIXED (0005): prize nodule
  // tier weights per band, [T1,T2,T3,T4,T5] — moving peak w/ tails, FIXED shape
  tierWeights: {
    Topsoil:   [0.80, 0.18, 0.02, 0.00, 0.00],
    Clay:      [0.45, 0.42, 0.12, 0.01, 0.00],
    Sandstone: [0.12, 0.38, 0.38, 0.11, 0.01],
    Granite:   [0.02, 0.12, 0.38, 0.38, 0.10],
    Bedrock:   [0.00, 0.02, 0.12, 0.40, 0.46],
  },
  prizeChancePerTile: 0.0006, // base; scales up gently with depth (× prizeDepthGain)
  prizeDepthGain: 2.5,        // multiplier at the deepest tile vs surface

  // --- GEM VALUES (0006 owns) --------------------------------------------
  gemValues: { T1: 8, T2: 15, T3: 28, T4: 52, T5: 95, Prize: 900 },

  // --- DRILL track (0006 owns; must hold 0005's drill-time band) ----------
  // power is a DIVISOR: drill_time = hardness * digConstant / power.
  // Tuned so each band's baseline sits ~1.1s (frontier) at the matching level.
  drillPower: [0.31, 0.62, 0.93, 1.24, 1.55],
  drillPrices: [100, 280, 750, 1900],   // cost to buy L1..L4 (L0 is starting kit)

  // --- FUEL track (0006 owns) — the round-trip / depth-reach gate ---------
  fuelCap: [80, 180, 380, 650, 1050],
  fuelPrices: [80, 240, 640, 1600],
  fuelDescent: 0.4,      // fuel/tile descending (light thrust, gravity helps)
  fuelAscent: 1.0,       // fuel/tile ascending (full thrust vs gravity)
  fuelHover: 0.15,       // fuel/tile-dug (hovering while the drill bites)
  fuelReserveMargin: 0.12, // keep this fraction of the ascent bill spare

  // --- CARGO track (0006 owns) — the greed cap (slots) --------------------
  cargoCap: [12, 20, 32, 50, 75],
  cargoPrices: [120, 320, 800, 2000],

  // --- HULL track (0006 owns; damage model is 0007's PLACEHOLDER) ---------
  hullCap: [100, 150, 220, 320, 450],
  hullPrices: [90, 260, 700, 1750],
  hazardBasePerTile: 0.02,  // PLACEHOLDER expected hull dmg/tile at surface
  hazardDepthGain: 4.0,     // PLACEHOLDER: dmg/tile multiplies up to (1+gain) at bottom

  // --- LIGHT track (0006 owns; benefit is 0007's PLACEHOLDER) -------------
  // darkness multiplier on hull damage. L0 = no light (full darkness penalty).
  lightDarkness: [1.0, 0.68, 0.42, 0.25],
  lightPrices: [150, 450, 1200],

  // --- HOIST (0006 owns) — aspirational fast-travel luxury -----------------
  hoistPrice: 5000,      // one big-ticket sink; halves ascent fuel + time
  hoistAscentFactor: 0.5,

  // --- feel/time constants (for the "first hour" estimate) ----------------
  descendSpeed: 8.0,     // tiles/s falling+steering (0004 floaty)
  ascendSpeed: 5.0,      // tiles/s thrusting home
  lateralFactor: 1.35,   // gem-chasing detours inflate tiles-dug over pure shaft
  surfaceHubSeconds: 15, // sell/buy/descend menu time per run
};

// ---- geometry helpers (FIXED-worldgen side) -------------------------------
function bandAt(depth, P) {
  const b = P.bands;
  for (let i = 0; i < b.length; i++) if (depth < b[i].bottom) return b[i];
  return b[b.length - 1];
}
function baselineHardness(depth, P) { return bandAt(depth, P).hardness; }
function drillTime(hardness, powerLevel, P) {
  return hardness * P.digConstant / P.drillPower[powerLevel];
}
function depthFraction(depth, P) {
  const max = P.bands[P.bands.length - 1].bottom;
  return Math.min(1, depth / max);
}

// expected gem value on a single dug tile at `depth` (density folded in)
function evPerTile(depth, P) {
  const w = P.tierWeights[bandAt(depth, P).name];
  const v = P.gemValues;
  const tiers = [v.T1, v.T2, v.T3, v.T4, v.T5];
  let ev = 0;
  for (let i = 0; i < 5; i++) ev += w[i] * tiers[i];
  return ev * P.gemDensity;
}

// ---- placeholder hull damage per dug tile at depth (0007 will own this) ----
function hullDmgPerTile(depth, lightLevel, P) {
  const f = depthFraction(depth, P);
  const darkness = P.lightDarkness[lightLevel];
  return P.hazardBasePerTile * (1 + P.hazardDepthGain * f) * darkness;
}

// ===========================================================================
// Roll a single dug tile → { value, slots, isPrize }.  slots is cargo used.
// ===========================================================================
function rollTile(depth, rng, P) {
  const out = { value: 0, slots: 0, isPrize: false };
  // prize first (rare, depth-scaled)
  const pf = P.prizeChancePerTile * (1 + (P.prizeDepthGain - 1) * depthFraction(depth, P));
  if (rng() < pf) { out.value = P.gemValues.Prize; out.slots = 1; out.isPrize = true; return out; }
  if (rng() >= P.gemDensity) return out; // barren tile
  const w = P.tierWeights[bandAt(depth, P).name];
  let r = rng(), acc = 0, tier = 0;
  for (let i = 0; i < 5; i++) { acc += w[i]; if (r < acc) { tier = i; break; } tier = i; }
  const vals = [P.gemValues.T1, P.gemValues.T2, P.gemValues.T3, P.gemValues.T4, P.gemValues.T5];
  out.value = vals[tier]; out.slots = 1;
  return out;
}

// ===========================================================================
// LIMITERS — how deep this build can go, and WHY it turns back. The min of the
// three is the run's reach; the argmin is the story of the whole economy.
// ===========================================================================
function reachLimits(up, P) {
  const drillP = up.drill, fuelC = P.fuelCap[up.fuel];
  const hullC = P.hullCap[up.hull], hoist = up.hoist ? P.hoistAscentFactor : 1;

  // (1) drill limit: deepest baseline rock still under the 1.5s comfort ceiling
  let drillDepth = 0;
  for (const b of P.bands) {
    if (drillTime(b.hardness, drillP, P) <= 1.5) drillDepth = b.bottom; else break;
  }
  // (2) fuel limit: deepest D whose round trip fits capacity (+reserve margin)
  //     cost(D) = D*descent + D*lateral*hover + D*ascent*hoist, all ×(1+margin)
  const perTile = P.fuelDescent + P.lateralFactor * P.fuelHover + P.fuelAscent * hoist;
  const fuelDepth = Math.floor(fuelC / (perTile * (1 + P.fuelReserveMargin)));
  // (3) hull limit: deepest D whose expected round-trip damage stays < 80% hull.
  //     integrate dmg/tile over the dug shaft (approx, lateral-inflated).
  let hullDepth = 0;
  for (let d = 10; d <= 700; d += 10) {
    let dmg = 0;
    for (let t = 0; t < d; t += 10) dmg += hullDmgPerTile(t, up.light, P) * 10 * P.lateralFactor;
    if (dmg < hullC * 0.8) hullDepth = d; else break;
  }
  return {
    drill: drillDepth, fuel: fuelDepth, hull: hullDepth,
    reach: Math.min(drillDepth, fuelDepth, hullDepth, 700),
    limiter: null, // filled below
  };
}

// ===========================================================================
// Simulate ONE run with the given upgrades. Greedy: dig down to reach, chasing
// gems, until cargo fills OR the reserve line is hit. Returns a rich record.
// ===========================================================================
function simulateRun(up, rng, P) {
  const lim = reachLimits(up, P);
  const names = { drill: 'drill', fuel: 'fuel', hull: 'hull' };
  lim.limiter = ['drill', 'fuel', 'hull'].reduce((a, b) => lim[b] < lim[a] ? b : a, 'drill');
  const cargoSlots = P.cargoCap[up.cargo];

  let depth = 0, tilesDug = 0, cargoUsed = 0, cargoValue = 0, prizeCount = 0;
  let hullDmg = 0, gemsCount = 0;
  const targetDepth = lim.reach;
  let cargoFull = false;

  // descend a shaft to targetDepth, digging lateralFactor tiles per depth-step
  const step = 1;
  for (let d = 0; d < targetDepth && !cargoFull; d += step) {
    const tilesHere = P.lateralFactor; // fractional tiles dug per depth unit
    // roll the fractional tile as an expectation with occasional discrete hits
    const nRolls = Math.random; // unused; we roll ceil(tilesHere) and weight
    const whole = Math.floor(tilesHere);
    const frac = tilesHere - whole;
    const rolls = whole + (rng() < frac ? 1 : 0);
    for (let k = 0; k < rolls; k++) {
      tilesDug++;
      const tile = rollTile(d, rng, P);
      hullDmg += hullDmgPerTile(d, up.light, P);
      if (tile.slots > 0) {
        if (cargoUsed + tile.slots > cargoSlots) { cargoFull = true; break; }
        cargoUsed += tile.slots; cargoValue += tile.value; gemsCount++;
        if (tile.isPrize) prizeCount++;
      }
    }
    depth = d + step;
  }

  // did we survive? (placeholder hull check — variance can sink a run)
  const runLost = hullDmg >= P.hullCap[up.hull];
  const banked = runLost ? 0 : cargoValue;

  // time estimate for the run (seconds)
  const drillSecs = tilesDug * (baselineHardness(depth / 2, P) * P.digConstant / P.drillPower[up.drill]);
  const hoist = up.hoist ? P.hoistAscentFactor : 1;
  const travelSecs = depth / P.descendSpeed + (depth / P.ascendSpeed) * hoist;
  const runSecs = drillSecs + travelSecs + P.surfaceHubSeconds;

  return {
    reach: depth, targetDepth, limiter: cargoFull ? 'cargo' : lim.limiter,
    band: bandAt(Math.max(0, depth - 1), P).name,
    tilesDug, gemsCount, prizeCount, cargoUsed, cargoSlots,
    cargoValue: Math.round(cargoValue), banked: Math.round(banked), runLost,
    runSecs: Math.round(runSecs), limits: lim,
  };
}

// ===========================================================================
// PURCHASE POLICY — relieve the current limiter first, else deepen, else haul.
// Transparent + greedy so the ratchet's pace is the model's, not a clever AI's.
// ===========================================================================
function nextPurchase(up, wallet, lastRun, P) {
  const opts = [];
  const push = (track, level, prices, label) => {
    if (level < prices.length) opts.push({ track, cost: prices[level], label });
  };
  // candidate next level on each track
  push('drill', up.drill, P.drillPrices, 'Drill');
  push('fuel', up.fuel, P.fuelPrices, 'Fuel');
  push('cargo', up.cargo, P.cargoPrices, 'Cargo');
  push('hull', up.hull, P.hullPrices, 'Hull');
  push('light', up.light, P.lightPrices, 'Light');

  // priority: fix the thing that turned us back last run, then keep depth
  // (drill+fuel) balanced, then cargo if we keep filling up, then survival.
  const prio = {};
  const lim = lastRun ? lastRun.limiter : 'fuel';
  prio.drill = 5; prio.fuel = 5; prio.cargo = 3; prio.hull = 2; prio.light = 2;
  if (lim === 'drill') prio.drill = 10;
  if (lim === 'fuel') prio.fuel = 10;
  if (lim === 'cargo') prio.cargo = 10;
  if (lim === 'hull') { prio.hull = 9; prio.light = 8; }
  // keep drill & fuel roughly in step so depth actually advances
  if (up.drill < up.fuel) prio.drill += 3;
  if (up.fuel < up.drill) prio.fuel += 3;
  // hoist only once everything else is deep and wallet is fat (aspirational)
  const maxed = up.drill >= 4 && up.fuel >= 4 && up.cargo >= 4;
  if (maxed && !up.hoist) opts.push({ track: 'hoist', cost: P.hoistPrice, label: 'Hoist' });

  const affordable = opts.filter(o => o.cost <= wallet);
  if (!affordable.length) return null;
  affordable.sort((a, b) => (prio[b.track] || 1) - (prio[a.track] || 1) || a.cost - b.cost);
  return affordable[0];
}

// ===========================================================================
// SESSION — run N runs, buying between each. Returns the whole trajectory.
// ===========================================================================
function simulateSession(P, nRuns = 20, seed = 12345) {
  const rng = makeRng(seed);
  const up = { drill: 0, fuel: 0, cargo: 0, hull: 0, light: 0, hoist: false };
  let wallet = 0, clock = 0;
  const runs = [];
  for (let i = 0; i < nRuns; i++) {
    const run = simulateRun(up, rng, P);
    wallet += run.banked;
    clock += run.runSecs;
    const bought = [];
    // spend down: keep buying whatever policy picks while affordable
    let guard = 0;
    while (guard++ < 8) {
      const buy = nextPurchase(up, wallet, run, P);
      if (!buy) break;
      wallet -= buy.cost;
      if (buy.track === 'hoist') up.hoist = true; else up[buy.track]++;
      bought.push(`${buy.label}${buy.track === 'hoist' ? '' : '→L' + up[buy.track]}`);
    }
    runs.push({
      n: i + 1, ...run, walletAfter: Math.round(wallet),
      bought, clockMin: +(clock / 60).toFixed(1),
      up: { ...up },
    });
  }
  return { runs, finalWallet: Math.round(wallet), finalUp: up, params: P };
}

// ---- curve exports for charts ---------------------------------------------
function evCurve(P) {
  const pts = [];
  for (let d = 0; d <= 700; d += 20) pts.push({ depth: d, ev: +evPerTile(d, P).toFixed(3), band: bandAt(d, P).name });
  return pts;
}
function drillBandCurve(P) {
  // for each drill level, the drill time on each band's baseline + halo + prize
  const rows = [];
  P.drillPower.forEach((_, lvl) => {
    P.bands.forEach(b => {
      rows.push({
        level: lvl, band: b.name,
        base: +drillTime(b.hardness, lvl, P).toFixed(2),
        halo: +drillTime(b.hardness + P.haloHardnessBonus, lvl, P).toFixed(2),
        prize: +drillTime(b.hardness + P.prizeHardnessBonus, lvl, P).toFixed(2),
      });
    });
  });
  return rows;
}

const API = {
  DEFAULTS, makeRng, bandAt, baselineHardness, drillTime, evPerTile,
  reachLimits, simulateRun, simulateSession, evCurve, drillBandCurve, hullDmgPerTile,
};
if (typeof module !== 'undefined' && module.exports) module.exports = API;
if (typeof window !== 'undefined') window.EconomyModel = API;
