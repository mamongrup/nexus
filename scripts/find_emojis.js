const fs = require('fs');
const path = require('path');

const dir = 'src/nexus';
const emojiRegex = /[\u{1F300}-\u{1F9FF}\u{2600}-\u{27BF}\u{1FA70}-\u{1FAFF}\u{200D}\u{23E9}-\u{23F3}]/u;

fs.readdirSync(dir).forEach(file => {
  if (!file.endsWith('.gleam')) return;
  const fullPath = path.join(dir, file);
  const content = fs.readFileSync(fullPath, 'utf8');
  const lines = content.split('\n');
  const hits = [];
  lines.forEach((line, idx) => {
    if (emojiRegex.test(line)) {
      hits.push({ line: idx + 1, text: line.trim() });
    }
  });
  if (hits.length > 0) {
    console.log(`=== ${file} (${hits.length} emojis) ===`);
    hits.forEach(h => console.log(`  L${h.line}: ${h.text}`));
  }
});
