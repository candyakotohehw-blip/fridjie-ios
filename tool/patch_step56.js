const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const mainPath = path.join(root, 'lib', 'screens', 'open_fridge_setup_screen.dart');
const fragPath = path.join(root, 'lib', 'screens', '_step56_new.fragment.dart');

let t = fs.readFileSync(mainPath, 'utf8').replace(/\r\n/g, '\n');
const frag = fs.readFileSync(fragPath, 'utf8').replace(/\r\n/g, '\n').trimEnd();

const start =
  '  Widget _buildStepFive() {\n    const primaryBlue = Color(0xFF2D7DFF);\n    final slots = _computeLayoutSlots();';
const end = '  Widget _recentItemTile(String name, String meta) {';

const i = t.indexOf(start);
const j = t.indexOf(end);
if (i < 0 || j < 0 || i >= j) {
  console.error('patch_step56.js: markers not found', { i, j });
  process.exit(1);
}
t = t.slice(0, i) + frag + '\n' + t.slice(j);
fs.writeFileSync(mainPath, t);
console.log('patch_step56.js: ok, inserted', frag.length);
