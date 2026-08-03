// ============================================================================
// Gem Miner — CONSUMABLES ECONOMY RE-SIM  (ticket EP1-06 / #43, PROTOTYPE — throwaway)
// ----------------------------------------------------------------------------
//   node economy-sim/consumables-sim.js
//
// EP1-02 (#42) introduces the game's FIRST deliberate cash sink: consumable
// dig-tools bought as a pre-run loadout. 0006 validated the "no cash sink" economy
// with a 20-run sim; that validation must be redone now that money can leak out.
//
// WHAT THIS MODELS: the SINK only. The per-item BENEFITS (hauler cargo trips,
// scout leads, dynamite blasts, relief items) belong to #45/#46/#47 and are not
// designed yet — so consumables are modelled as PURE SPEND, ZERO GAMEPLAY UPSIDE.
// This is deliberately the worst case for both questions #43 asks:
//   * Spiral test  — if a spender can't spiral even with no upside, they can't
//     spiral once the tools actually help.
//   * Pacing test  — money diverted to a zero-benefit sink is an UPPER BOUND on
//     how much the sink can delay the 0006 upgrade milestones. Real tools also
//     help you earn/reach, so the true delay is no worse than this.
//
// It reuses economy-model.js unchanged for the run + upgrade-purchase logic
// (simulateRun, nextPurchase, reachLimits) so the core economy is identical to
// 0006's; only a consumable-spend layer is added between runs.
// ============================================================================
const M = require('./economy-model.js');
const P = M.DEFAULTS;

// --- EP1-02 (#42) consumable knobs — first-draft, validated here ------------
const CONSUMABLES = {
  flare:     { name: 'Flare',    unlockDepth: 120, unlockPrice: 150,  perCharge: 8,  maxCharges: 5, power: 1 },
  fuelCell:  { name: 'FuelCell', unlockDepth: 180, unlockPrice: 300,  perCharge: 25, maxCharges: 3, power: 2 },
  dynamite:  { name: 'Dynamite', unlockDepth: 260, unlockPrice: 600,  perCharge: 40, maxCharges: 4, power: 3 },
  repairKit: { name: 'RepairKit',unlockDepth: 340, unlockPrice: 500,  perCharge: 35, maxCharges: 3, power: 4 },
  scout:     { name: 'Scout',    unlockDepth: 450, unlockPrice: 2000, perCharge: 60, maxCharges: 2, power: 5 },
  hauler:    { name: 'Hauler',   unlockDepth: 550, unlockPrice: 3500, perCharge: 80, maxCharges: 2, power: 6 },
};
const TOOL_ORDER = ['flare', 'fuelCell', 'dynamite', 'repairKit', 'scout', 'hauler'];

// A spender's per-run recurring cost if they field their 3 most powerful unlocked
// tools at a full loadout and CONSUME EVERY CHARGE (worst-case recurring sink).
function activeLoadoutCost(owned) {
  const unlocked = TOOL_ORDER.filter(k => owned[k]);
  // 3 active slots, one type each — pick the 3 highest-power unlocked tools.
  const active = unlocked.sort((a, b) => CONSUMABLES[b].power - CONSUMABLES[a].power).slice(0, 3);
  let cost = 0;
  for (const k of active) cost += CONSUMABLES[k].perCharge * CONSUMABLES[k].maxCharges;
  return { cost, active: active.map(k => CONSUMABLES[k].name) };
}

// ============================================================================
// A session loop that mirrors economy-model.simulateSession but with a
// consumable-spend layer. `mode` picks the spending discipline.
//   'baseline'     — no consumables at all (the 0006 reference).
//   'sensible'     — upgrades FIRST (0006 policy), then unlock + field tools with
//                    whatever surplus remains. The realistic player.
//   'pathological' — drain the wallet on consumables FIRST every run, upgrades last.
//                    The stress case: "can an over-buyer spiral?"
//   'pathological-recover' — pathological for the first `recoverAt` runs, then
//                    STOP buying consumables entirely (models the player who
//                    realises and just drills). Shows recovery.
// ============================================================================
function session(mode, { nRuns = 40, seed = 12345, recoverAt = 20 } = {}) {
  const rng = M.makeRng(seed);
  const up = { drill: 0, fuel: 0, cargo: 0, hull: 0, light: 0, hoist: false };
  const owned = {}; // unlocked consumable types
  let wallet = 0, clock = 0, deepest = 0;
  let consumableTotalSpend = 0, walletMin = Infinity;
  const runs = [];

  for (let i = 0; i < nRuns; i++) {
    const run = M.simulateRun(up, rng, P);
    wallet += run.banked;
    clock += run.runSecs;
    deepest = Math.max(deepest, run.reach);

    const spending = mode !== 'baseline' &&
      !(mode === 'pathological-recover' && i >= recoverAt);

    const boughtC = [];
    let runConsumableSpend = 0;

    const buyConsumables = () => {
      // 1) unlock any depth-available tool we can afford (cheap-first via order)
      for (const k of TOOL_ORDER) {
        const c = CONSUMABLES[k];
        if (!owned[k] && deepest >= c.unlockDepth && wallet >= c.unlockPrice) {
          wallet -= c.unlockPrice; owned[k] = true;
          runConsumableSpend += c.unlockPrice; boughtC.push('unlock:' + c.name);
        }
      }
      // 2) field a full active loadout and consume it (recurring per-charge sink)
      const { cost, active } = activeLoadoutCost(owned);
      if (cost > 0 && wallet >= cost) {
        wallet -= cost; runConsumableSpend += cost;
        boughtC.push('charges:' + active.join('+') + '($' + cost + ')');
      } else if (cost > 0 && wallet > 0) {
        // partial: spend what we have (a broke spender fields fewer charges)
        const spend = Math.min(wallet, cost);
        wallet -= spend; runConsumableSpend += spend;
        boughtC.push('charges(partial):$' + spend);
      }
    };

    const buyUpgrades = () => {
      const bought = [];
      let guard = 0;
      while (guard++ < 8) {
        const buy = M.nextPurchase(up, wallet, run, P);
        if (!buy) break;
        wallet -= buy.cost;
        if (buy.track === 'hoist') up.hoist = true; else up[buy.track]++;
        bought.push(`${buy.label}${buy.track === 'hoist' ? '' : '→L' + up[buy.track]}`);
      }
      return bought;
    };

    let boughtU = [];
    if (spending && mode.startsWith('pathological')) {
      buyConsumables();   // drain first
      boughtU = buyUpgrades();
    } else if (spending) { // sensible
      boughtU = buyUpgrades(); // upgrades first
      buyConsumables();        // surplus to tools
    } else {
      boughtU = buyUpgrades();
    }

    consumableTotalSpend += runConsumableSpend;
    walletMin = Math.min(walletMin, wallet);

    runs.push({
      n: i + 1, reach: run.reach, band: run.band, limiter: run.limiter,
      runLost: run.runLost, banked: run.banked, walletAfter: Math.round(wallet),
      clockMin: +(clock / 60).toFixed(1), consumableSpend: runConsumableSpend,
      boughtU, boughtC, up: { ...up }, owned: Object.keys(owned).length,
    });
  }
  return { mode, runs, wallet: Math.round(wallet), up, owned,
    consumableTotalSpend, walletMin: Math.round(walletMin) };
}

// ---- milestone extraction --------------------------------------------------
function milestones(s) {
  const firstUpgrade = s.runs.find(r => r.boughtU.length);
  const bedrock = s.runs.find(r => r.reach >= 450);
  const bottom = s.runs.find(r => r.reach >= 700);
  const firstUnlock = s.runs.find(r => r.boughtC.some(b => b.startsWith('unlock')));
  const runsInHour = s.runs.filter(r => r.clockMin <= 60);
  const atHour = runsInHour[runsInHour.length - 1] || s.runs[0];
  return {
    firstUpgradeRun: firstUpgrade ? firstUpgrade.n : null,
    firstUpgradeMin: firstUpgrade ? firstUpgrade.clockMin : null,
    firstUnlockRun: firstUnlock ? firstUnlock.n : null,
    firstUnlockTool: firstUnlock ? firstUnlock.boughtC.find(b => b.startsWith('unlock')) : null,
    bedrockRun: bedrock ? bedrock.n : null,
    bottomRun: bottom ? bottom.n : null,
    runsInHour: runsInHour.length,
    depthAtHour: atHour.reach, bandAtHour: atHour.band,
    walletAtHour: atHour.walletAfter,
    lostRuns: s.runs.filter(r => r.runLost).length,
  };
}

const pad = (s, n) => String(s).padStart(n);
const padr = (s, n) => String(s).padEnd(n);

// ============================================================================
console.log('\n############################################################');
console.log('# EP1-06 (#43) — ECONOMY RE-SIM WITH A CONSUMABLE-SPENDING PLAYER');
console.log('# consumables modelled as PURE SINK, ZERO benefit = worst case');
console.log('############################################################');

console.log('\n=== CONSUMABLE KNOBS UNDER TEST (EP1-02 first-draft) ===');
console.log(padr('tool', 11) + pad('unlockDepth', 12) + pad('unlockPrice', 12) +
  pad('perCharge', 11) + pad('maxCharges', 11) + pad('loadout$', 10));
for (const k of TOOL_ORDER) {
  const c = CONSUMABLES[k];
  console.log(padr(c.name, 11) + pad(c.unlockDepth, 12) + pad(c.unlockPrice, 12) +
    pad(c.perCharge, 11) + pad(c.maxCharges, 11) + pad(c.perCharge * c.maxCharges, 10));
}

const base = session('baseline');
const sensible = session('sensible');
const patho = session('pathological');
const recover = session('pathological-recover', { recoverAt: 20 });

// ---- milestone comparison --------------------------------------------------
console.log('\n=== MILESTONE COMPARISON (seed 12345, 40 runs) ===');
const mb = milestones(base), ms = milestones(sensible), mp = milestones(patho);
const row = (label, b, s, p) => console.log(padr(label, 26) + padr(b, 14) + padr(s, 14) + padr(p, 14));
row('', 'BASELINE', 'SENSIBLE', 'PATHOLOGICAL');
row('first upgrade (run)', mb.firstUpgradeRun, ms.firstUpgradeRun, mp.firstUpgradeRun);
row('first upgrade (min)', mb.firstUpgradeMin, ms.firstUpgradeMin, mp.firstUpgradeMin);
row('first tool unlock (run)', mb.firstUnlockRun || '-', ms.firstUnlockRun || '-', mp.firstUnlockRun || '-');
row('reach Bedrock (run)', mb.bedrockRun || 'no', ms.bedrockRun || 'no', mp.bedrockRun || 'no');
row('reach bottom 700 (run)', mb.bottomRun || 'no', ms.bottomRun || 'no', mp.bottomRun || 'no');
row('runs in first hour', mb.runsInHour, ms.runsInHour, mp.runsInHour);
row('depth @ 60min', mb.depthAtHour, ms.depthAtHour, mp.depthAtHour);
row('band @ 60min', mb.bandAtHour, ms.bandAtHour, mp.bandAtHour);
row('wallet @ 60min', mb.walletAtHour, ms.walletAtHour, mp.walletAtHour);

// ---- the guardrail: can anyone spiral? -------------------------------------
console.log('\n=== GUARDRAIL — CAN A SPENDER SPIRAL? ===');
console.log('  A "spiral" = wallet trapped so the player can never progress. Test:');
console.log('  1) wallet never goes negative (purchases are affordability-gated):');
console.log('     baseline walletMin      = ' + base.walletMin);
console.log('     sensible walletMin      = ' + sensible.walletMin);
console.log('     pathological walletMin  = ' + patho.walletMin +
  (patho.walletMin >= 0 ? '   ✓ never negative' : '   ✗ NEGATIVE'));
console.log('  2) every surviving run still banks money — earning is independent of');
console.log('     spending (drilling is free). Banked per run, pathological over-buyer:');
const bankedSeq = patho.runs.map(r => r.banked);
console.log('     ' + bankedSeq.slice(0, 20).join(' ') + ' ...');
console.log('     runs that banked > 0: ' + patho.runs.filter(r => r.banked > 0).length + '/' + patho.runs.length);
console.log('  3) total consumable spend (pathological): $' + patho.consumableTotalSpend +
  '  — yet wallet stays solvent and runs keep completing.');

console.log('\n=== RECOVERY — over-buyer stops at run 20 and just drills ===');
console.log(padr('run', 5) + padr('mode', 16) + padr('banked', 9) + padr('consumable$', 13) + 'walletAfter');
recover.runs.forEach(r => {
  if (r.n >= 17 && r.n <= 26) {
    const m = r.n <= 20 ? 'over-buying' : 'DRILL-ONLY';
    console.log(padr(r.n, 5) + padr(m, 16) + padr(r.banked, 9) + padr(r.consumableSpend, 13) + r.walletAfter);
  }
});
const wRecStart = recover.runs[19].walletAfter, wRecEnd = recover.runs[recover.runs.length - 1].walletAfter;
console.log('  wallet at run 20 (stop): ' + wRecStart + '  →  run 40: ' + wRecEnd +
  (wRecEnd > wRecStart ? '   ✓ recovers by drilling' : '   ✗'));

// ---- full sensible-spender trajectory --------------------------------------
console.log('\n=== SENSIBLE-SPENDER TRAJECTORY (the realistic player) ===');
console.log(padr('#', 3) + padr('reach', 7) + padr('band', 11) + padr('bank$', 7) +
  padr('cons$', 7) + padr('wallet', 8) + padr('t(min)', 8) + 'upgrades / consumables');
sensible.runs.forEach(r => {
  const acts = [...r.boughtU, ...r.boughtC].join(' ') || '-';
  console.log(padr(r.n, 3) + padr(r.reach, 7) + padr(r.band, 11) + padr(r.banked, 7) +
    padr(r.consumableSpend, 7) + padr(r.walletAfter, 8) + padr(r.clockMin, 8) + acts);
});

// ---- verdict ---------------------------------------------------------------
const hourDelayRuns = (ms.firstUpgradeRun || 0) - (mb.firstUpgradeRun || 0);
const bedrockDelay = (ms.bedrockRun || 0) - (mb.bedrockRun || 0);
console.log('\n=== VERDICT ===');
console.log('  first-upgrade delay (sensible vs baseline): ' + hourDelayRuns + ' run(s)');
console.log('  Bedrock-reach delay (sensible vs baseline): ' + bedrockDelay + ' run(s)');
console.log('  first-hour unlocks available: only Flare(120)/FuelCell(180) — the');
console.log('  cheap relief items; drones (450/550, $2000/$3500) unlock 2nd/3rd session.');
console.log('  spiral: ' + (patho.walletMin >= 0 ? 'IMPOSSIBLE by construction (solvent + always earning)' : 'CHECK'));
console.log('');
