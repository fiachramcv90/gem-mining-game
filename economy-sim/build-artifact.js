// Inline economy-model.js + ui.js into shell.html → economy-sim.html (the artifact).
// Keeps economy-model.js the single source of truth (no drift with the node runner).
//   node economy-sim/build-artifact.js
const fs = require('fs');
const path = require('path');
const dir = __dirname;
const read = f => fs.readFileSync(path.join(dir, f), 'utf8');

// strip the module.exports tail from the model so it runs bare in the browser
let model = read('economy-model.js')
  .replace(/if \(typeof module[\s\S]*$/, '')
  .trim() + '\nif (typeof window !== "undefined") window.EconomyModel = API;\n';

const ui = read('ui.js');
let html = read('shell.html')
  .replace('/*__MODEL__*/', () => model)
  .replace('/*__UI__*/', () => ui);

fs.writeFileSync(path.join(dir, 'economy-sim.html'), html);
console.log('wrote economy-sim.html (' + html.length + ' bytes)');
