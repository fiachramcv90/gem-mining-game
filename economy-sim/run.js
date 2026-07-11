// Node runner for the economy sim (ticket 0006, PROTOTYPE).
//   node economy-sim/run.js
const M = require('./economy-model.js');
const P = M.DEFAULTS;

const pad = (s, n) => String(s).padStart(n);
const padr = (s, n) => String(s).padEnd(n);

console.log('\n=== DRILL-TIME BAND CONTRACT (0005: baseline rock must stay 0.3–1.5s; frontier ~1.0–1.3s) ===');
console.log('   power divisor per level:', P.drillPower.join('  '));
console.log(padr('drillLvl', 9) + P.bands.map(b => padr(b.name, 11)).join(''));
P.drillPower.forEach((pw, lvl) => {
  const cells = P.bands.map(b => {
    const t = M.drillTime(b.hardness, lvl, P);
    const mark = t < 0.3 ? '·' : t > 1.5 ? '!' : (t >= 1.0 && t <= 1.3 ? '◆' : ' ');
    return padr(t.toFixed(2) + mark, 11);
  });
  console.log(padr('L' + lvl, 9) + cells.join(''));
});
console.log('   ◆ = frontier band (1.0–1.3s)   ! = over 1.5s ceiling   · = under 0.3s floor');
console.log('   (halo +1 / prize +2 tiles are deliberate spikes ABOVE baseline — shown in the artifact)');

console.log('\n=== EXPECTED GEM VALUE PER DUG TILE, by depth (should rise GENTLY) ===');
const ev = M.evCurve(P);
let lastBand = '';
ev.forEach(p => {
  if (p.band !== lastBand) { console.log(`  -- ${p.band} --`); lastBand = p.band; }
  const bar = '█'.repeat(Math.round(p.ev * 6));
  console.log('  d=' + pad(p.depth, 3) + '  ' + pad(p.ev.toFixed(2), 5) + '  ' + bar);
});
const evTop = ev[1].ev, evBot = ev[ev.length - 1].ev;
console.log(`  Bedrock/Topsoil EV ratio = ${(evBot / evTop).toFixed(1)}x  (gentle target ~4–6x)`);

console.log('\n=== 20-RUN SESSION (greedy player, seed 12345) ===');
const sess = M.simulateSession(P, 20, 12345);
console.log(padr('#', 3) + padr('reach', 7) + padr('band', 11) + padr('limiter', 9) +
  padr('gems', 6) + padr('cargo$', 8) + padr('bank$', 8) + padr('wallet', 9) +
  padr('t(min)', 8) + 'bought');
sess.runs.forEach(r => {
  console.log(
    padr(r.n, 3) + padr(r.reach, 7) + padr(r.band, 11) +
    padr(r.limiter + (r.runLost ? '/LOST' : ''), 9) +
    padr(r.gemsCount + (r.prizeCount ? '+P' : ''), 6) +
    padr(r.cargoValue, 8) + padr(r.banked, 8) + padr(r.walletAfter, 9) +
    padr(r.clockMin, 8) + r.bought.join(' '));
});

console.log('\n=== FIRST-HOUR PACING ===');
const hour = sess.runs.filter(r => r.clockMin <= 60);
const lastHour = hour[hour.length - 1] || sess.runs[0];
console.log(`  runs completed in first 60 min: ${hour.length}`);
console.log(`  depth reached by 60 min: ${lastHour.reach} tiles (${lastHour.band})`);
console.log(`  wallet at 60 min: ${lastHour.walletAfter}`);
console.log(`  upgrades owned at 60 min:`, JSON.stringify(lastHour.up));
const firstBuy = sess.runs.find(r => r.bought.length);
console.log(`  first upgrade bought: run #${firstBuy ? firstBuy.n : '-'} (${firstBuy ? firstBuy.bought.join(',') : '-'}) at t=${firstBuy ? firstBuy.clockMin : '-'}min`);
console.log(`  reached Bedrock (450+) at run: ${(sess.runs.find(r => r.reach >= 450) || {}).n || 'not in 20'}`);
console.log(`  bottom (700) reached at run: ${(sess.runs.find(r => r.reach >= 700) || {}).n || 'not in 20'}`);
console.log('');
