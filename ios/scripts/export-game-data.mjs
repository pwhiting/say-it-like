// Copies the web game's prompts, lines and winner phrases into the iOS app, so both
// versions play from the same lists. Run after editing anything in public/:
//
//   node ios/scripts/export-game-data.mjs

import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { MOODS, CHARACTERS, ACTIONS, SITUATIONS, STYLES, LINES } from '../../public/prompts.js';
import { WIN_PHRASES, TOP_SCORE_TAGS, LOW_SCORE_TAGS } from '../../public/phrases.js';

const out = fileURLToPath(new URL('../SayItLike/Resources/GameData.json', import.meta.url));
const data = {
  moods: MOODS,
  characters: CHARACTERS,
  actions: ACTIONS,
  situations: SITUATIONS,
  styles: STYLES,
  lines: LINES,
  winPhrases: WIN_PHRASES,
  topScoreTags: TOP_SCORE_TAGS,
  lowScoreTags: LOW_SCORE_TAGS,
};
writeFileSync(out, JSON.stringify(data, null, 1) + '\n');
console.log(`Wrote ${out} (${LINES.length} lines)`);
