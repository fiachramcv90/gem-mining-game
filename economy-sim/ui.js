// Interactive layer for the economy artifact (ticket 0006, PROTOTYPE).
// Uses window.EconomyModel (inlined by build-artifact.js). Throwaway.
(function () {
  const M = window.EconomyModel;
  // deep-clone the defaults so sliders mutate a live copy, never the source
  const P = JSON.parse(JSON.stringify(M.DEFAULTS));
  const BAND_KEYS = ['topsoil', 'clay', 'sandstone', 'granite', 'bedrock'];
  let seed = 12345;

  const $ = sel => document.querySelector(sel);
  const el = (tag, cls, txt) => { const e = document.createElement(tag); if (cls) e.className = cls; if (txt != null) e.textContent = txt; return e; };
  const bandColor = name => getComputedStyle(document.documentElement)
    .getPropertyValue('--' + name.toLowerCase()).trim();
  const cssVar = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();

  // ---- knob definitions: [label, path-getter/setter, min, max, step, fmt] ----
  const knobGroups = [
    {
      title: 'Gem values', hint: 'money per gem, by tier · prize is off-curve',
      knobs: [
        ['Tier 1', () => P.gemValues.T1, v => P.gemValues.T1 = v, 1, 40, 1],
        ['Tier 2', () => P.gemValues.T2, v => P.gemValues.T2 = v, 2, 80, 1],
        ['Tier 3', () => P.gemValues.T3, v => P.gemValues.T3 = v, 5, 160, 1],
        ['Tier 4', () => P.gemValues.T4, v => P.gemValues.T4 = v, 10, 300, 2],
        ['Tier 5', () => P.gemValues.T5, v => P.gemValues.T5 = v, 20, 500, 5],
        ['Prize', () => P.gemValues.Prize, v => P.gemValues.Prize = v, 100, 4000, 50],
      ],
    },
    {
      title: 'Drill power', hint: 'divisor per level · higher = faster · holds 0005 band',
      knobs: [0, 1, 2, 3, 4].map(i => [
        'L' + i, () => P.drillPower[i], v => P.drillPower[i] = v, 0.15, 2.2, 0.01,
      ]),
    },
    {
      title: 'Capacity', hint: 'scale the whole upgrade ladder for each track',
      knobs: [
        ['Fuel ×', () => P._fuelScale || 1, v => scaleArr('fuelCap', '_fuelScale', v), 0.5, 2, 0.05],
        ['Cargo ×', () => P._cargoScale || 1, v => scaleArr('cargoCap', '_cargoScale', v), 0.5, 2, 0.05],
        ['Hull ×', () => P._hullScale || 1, v => scaleArr('hullCap', '_hullScale', v), 0.5, 2, 0.05],
      ],
    },
    {
      title: 'Pricing', hint: 'how fast the ratchet turns',
      knobs: [
        ['All prices ×', () => P._priceScale || 1, v => scalePrices(v), 0.4, 2.5, 0.05],
      ],
    },
  ];

  const BASE = JSON.parse(JSON.stringify(M.DEFAULTS));
  function scaleArr(capKey, scaleKey, v) {
    P[scaleKey] = v; P[capKey] = BASE[capKey].map(x => Math.round(x * v));
  }
  function scalePrices(v) {
    P._priceScale = v;
    for (const k of ['drillPrices', 'fuelPrices', 'cargoPrices', 'hullPrices', 'lightPrices']) {
      P[k] = BASE[k].map(x => Math.round(x * v));
    }
    P.hoistPrice = Math.round(BASE.hoistPrice * v);
  }

  // ======================= render pieces =======================
  function renderKnobs() {
    const host = $('#knobs'); host.innerHTML = '';
    knobGroups.forEach(g => {
      const card = el('div', 'knob-group');
      const h = el('div', 'kg-head');
      h.append(el('h3', null, g.title), el('span', 'hint', g.hint));
      card.append(h);
      const grid = el('div', 'kg-grid');
      g.knobs.forEach(([label, get, set, min, max, step]) => {
        const row = el('label', 'knob');
        const top = el('div', 'knob-top');
        top.append(el('span', 'knob-label', label));
        const val = el('span', 'knob-val', fmt(get(), step));
        top.append(val);
        const input = el('input');
        input.type = 'range'; input.min = min; input.max = max; input.step = step; input.value = get();
        input.addEventListener('input', () => {
          set(parseFloat(input.value)); val.textContent = fmt(get(), step); recompute();
        });
        row.append(top, input);
        grid.append(row);
      });
      card.append(grid);
      host.append(card);
    });
    // seed + reset controls
    const ctl = el('div', 'controls');
    const reroll = el('button', 'btn', 'Re-roll luck');
    reroll.onclick = () => { seed = (seed * 1103515245 + 12345) >>> 0; recompute(); };
    const reset = el('button', 'btn ghost', 'Reset knobs');
    reset.onclick = () => {
      Object.assign(P, JSON.parse(JSON.stringify(M.DEFAULTS))); seed = 12345;
      renderKnobs(); recompute();
    };
    ctl.append(reroll, reset);
    host.append(ctl);
  }
  const fmt = (v, step) => step < 1 ? (+v).toFixed(2) : String(Math.round(v));

  function renderKPIs(sess) {
    const ev = M.evCurve(P);
    const evRatio = (ev[ev.length - 1].ev / ev[1].ev);
    const hour = sess.runs.filter(r => r.clockMin <= 60);
    const last = hour[hour.length - 1] || sess.runs[0];
    const firstBuy = sess.runs.find(r => r.bought.length);
    const bottom = sess.runs.find(r => r.reach >= 700);
    const bedrock = sess.runs.find(r => r.reach >= 450);
    const lost = sess.runs.filter(r => r.runLost).length;
    const kpis = [
      ['EV ratio', evRatio.toFixed(1) + '×', 'Bedrock ÷ Topsoil per-tile', tone(evRatio, 4, 6)],
      ['Runs / hr', hour.length, 'completed in first 60 min', tone(hour.length, 6, 16, true)],
      ['Reach @1hr', last.reach + 't', last.band, 'neutral'],
      ['1st upgrade', firstBuy ? 'run ' + firstBuy.n : '—', firstBuy ? firstBuy.clockMin + ' min' : '', tone(firstBuy ? firstBuy.n : 9, 2, 4, true)],
      ['Bedrock', bedrock ? 'run ' + bedrock.n : 'not yet', bedrock ? '' : 'in 20 runs', 'neutral'],
      ['Bottom 700t', bottom ? 'run ' + bottom.n : 'not yet', bottom ? '' : 'goal remains', bottom ? 'warn' : 'good'],
    ];
    const host = $('#kpis'); host.innerHTML = '';
    kpis.forEach(([k, v, sub, t]) => {
      const c = el('div', 'kpi ' + t);
      c.append(el('div', 'kpi-k', k), el('div', 'kpi-v', String(v)), el('div', 'kpi-sub', sub));
      host.append(c);
    });
    if (lost) $('#kpis').append(Object.assign(el('div', 'kpi crit'),
      { innerHTML: '<div class="kpi-k">Runs lost</div><div class="kpi-v">' + lost + '</div><div class="kpi-sub">cargo forfeited</div>' }));
  }
  function tone(v, lo, hi, higherBetter) {
    if (higherBetter) return v < lo ? 'crit' : v > hi ? 'warn' : 'good';
    return v < lo ? 'warn' : v > hi ? 'crit' : 'good';
  }

  function renderContract() {
    const host = $('#contract'); host.innerHTML = '';
    const tbl = el('table', 'grid-tbl');
    const thead = el('tr');
    thead.append(el('th', null, 'drill'));
    P.bands.forEach(b => thead.append(el('th', null, b.name)));
    tbl.append(thead);
    P.drillPower.forEach((_, lvl) => {
      const tr = el('tr');
      tr.append(el('td', 'rowlab', 'L' + lvl));
      P.bands.forEach(b => {
        const t = M.drillTime(b.hardness, lvl, P);
        const td = el('td', 'cell');
        let cls = 'ok';
        if (t > 1.5) cls = 'over'; else if (t < 0.3) cls = 'under';
        else if (t >= 1.0 && t <= 1.3) cls = 'frontier';
        td.classList.add(cls);
        td.textContent = t.toFixed(2);
        td.title = `baseline ${t.toFixed(2)}s · halo ${M.drillTime(b.hardness + P.haloHardnessBonus, lvl, P).toFixed(2)}s · prize ${M.drillTime(b.hardness + P.prizeHardnessBonus, lvl, P).toFixed(2)}s`;
        tr.append(td);
      });
      tbl.append(tr);
    });
    host.append(tbl);
  }

  function renderEVChart() {
    const cv = $('#evchart'); const ctx = cv.getContext('2d');
    const W = cv.width = cv.clientWidth * devicePixelRatio;
    const H = cv.height = 220 * devicePixelRatio;
    ctx.clearRect(0, 0, W, H);
    const ev = M.evCurve(P);
    const pad = 34 * devicePixelRatio;
    const maxEV = Math.max(...ev.map(p => p.ev)) * 1.1;
    const x = d => pad + (d / 700) * (W - pad * 1.5);
    const y = v => H - pad - (v / maxEV) * (H - pad * 1.6);
    // band backgrounds
    P.bands.forEach(b => {
      ctx.fillStyle = hexA(bandColor(b.name), 0.12);
      ctx.fillRect(x(b.top), pad * 0.4, x(b.bottom) - x(b.top), H - pad * 1.4);
    });
    // grid
    ctx.strokeStyle = cssVar('--line'); ctx.lineWidth = devicePixelRatio;
    ctx.beginPath(); ctx.moveTo(pad, H - pad); ctx.lineTo(W - pad * 0.5, H - pad); ctx.stroke();
    // area under curve
    ctx.beginPath(); ctx.moveTo(x(0), y(0));
    ev.forEach(p => ctx.lineTo(x(p.depth), y(p.ev)));
    ctx.lineTo(x(700), y(0)); ctx.closePath();
    ctx.fillStyle = hexA(cssVar('--accent'), 0.15); ctx.fill();
    // line
    ctx.beginPath();
    ev.forEach((p, i) => { const fn = i ? 'lineTo' : 'moveTo'; ctx[fn](x(p.depth), y(p.ev)); });
    ctx.strokeStyle = cssVar('--accent'); ctx.lineWidth = 2.5 * devicePixelRatio; ctx.stroke();
    // endpoint dots per band midpoint label
    ctx.font = `${11 * devicePixelRatio}px ui-monospace, monospace`;
    ctx.fillStyle = cssVar('--ink-soft'); ctx.textAlign = 'center';
    P.bands.forEach(b => {
      const mid = (b.top + b.bottom) / 2;
      ctx.fillText(b.name[0], x(mid), H - pad + 16 * devicePixelRatio);
    });
    ctx.textAlign = 'left'; ctx.fillText('$/tile', pad - 26 * devicePixelRatio, pad * 0.9);
  }

  function renderPerMin(sess) {
    // money-per-minute achievable by farming each band (shallow-viability check)
    const host = $('#permin'); host.innerHTML = '';
    const rows = P.bands.map(b => {
      const mid = (b.top + b.bottom) / 2;
      const ev = M.evPerTile(mid, P);
      // rough: a farm run at this band's floor, time ≈ round-trip at that depth
      const D = b.bottom;
      const drillLvl = P.drillPower.findIndex((_, l) => M.drillTime(b.hardness, l, P) <= 1.3);
      const dl = drillLvl < 0 ? P.drillPower.length - 1 : drillLvl;
      const tilesPerRun = 40; // a comparable farming bite
      const value = ev * tilesPerRun;
      const drillSecs = tilesPerRun * b.hardness * P.digConstant / P.drillPower[dl];
      const travel = D / P.descendSpeed + D / P.ascendSpeed + P.surfaceHubSeconds;
      const perMin = value / ((drillSecs + travel) / 60);
      return { band: b.name, perMin };
    });
    const max = Math.max(...rows.map(r => r.perMin));
    rows.forEach(r => {
      const row = el('div', 'bar-row');
      row.append(el('span', 'bar-lab', r.band));
      const track = el('div', 'bar-track');
      const fill = el('div', 'bar-fill');
      fill.style.width = (r.perMin / max * 100) + '%';
      fill.style.background = bandColor(r.band);
      track.append(fill);
      row.append(track, el('span', 'bar-val', Math.round(r.perMin) + '/min'));
      host.append(row);
    });
  }

  function renderRuns(sess) {
    const host = $('#runs'); host.innerHTML = '';
    const tbl = el('table', 'run-tbl');
    const head = el('tr');
    ['#', 'reach', 'band', 'why home', 'gems', 'cargo $', 'banked', 'wallet', 'min', 'bought'].forEach(h => head.append(el('th', null, h)));
    tbl.append(head);
    sess.runs.forEach(r => {
      const tr = el('tr');
      if (r.runLost) tr.classList.add('lost');
      const cells = [
        r.n, r.reach + 't',
        r.band, r.limiter + (r.runLost ? ' ✗' : ''),
        r.gemsCount + (r.prizeCount ? ' ✦' : ''),
        '$' + r.cargoValue, '$' + r.banked, '$' + r.walletAfter, r.clockMin,
        r.bought.join('  '),
      ];
      cells.forEach((c, i) => {
        const td = el('td', null, String(c));
        if (i === 2) td.style.color = bandColor(r.band);
        if (i === 9) td.className = 'bought-cell';
        if (i === 4 && r.prizeCount) td.classList.add('prize');
        tr.append(td);
      });
      tbl.append(tr);
    });
    host.append(tbl);
  }

  // hex (#rrggbb or rgb) + alpha → rgba string
  function hexA(hex, a) {
    hex = hex.trim();
    if (hex.startsWith('#')) {
      const n = parseInt(hex.slice(1), 16);
      return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
    }
    return hex.replace(')', `,${a})`).replace('rgb', 'rgba');
  }

  function recompute() {
    const sess = M.simulateSession(P, 20, seed);
    renderKPIs(sess);
    renderContract();
    renderEVChart();
    renderPerMin(sess);
    renderRuns(sess);
  }

  window.addEventListener('resize', () => renderEVChart());
  document.addEventListener('DOMContentLoaded', () => { renderKnobs(); recompute(); });
  // themes: re-render charts (colors change) when the root theme attr flips
  new MutationObserver(() => recompute()).observe(document.documentElement,
    { attributes: true, attributeFilter: ['data-theme'] });
})();
