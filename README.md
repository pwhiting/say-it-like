# Say It Like

A family voice-acting party game. Each round gives everyone the same line and a direction
for how to say it:

> Say **"I sure do hope the weather doesn't get worse."**
> *like a scared cowboy*

Players take turns recording themselves in the browser. An AI judge listens to each
recording and scores how well the **voice** delivered the direction: the mood, the
character, the words, and the flair. When everyone has been judged, the scores are revealed
together, the round winner's card lights up green, and a scoreboard keeps each player's
round wins and total score across the game.

It grew out of a game played with grandchildren ("say *hello, partner* like you're sad…
now like you're happy!"), with a judge that can put a number on it so people can compete.

## How it works

```
browser (public/)                 server.mjs (localhost only)          OpenAI
─────────────────                 ───────────────────────────          ──────
record mic → WebM/M4A  ──POST /api/score──►  adds the judge prompt  ──►  /v1/responses
show scores  ◄────────────────────────────  validates, totals 0-100 ◄──  submit_score tool call
```

- **`public/`** is a plain HTML/CSS/JS page with no build step and no dependencies. It records
  with `MediaRecorder` and lets you pick which microphone to use.
- **`server.mjs`** is a small Node server with no dependencies. It serves the page and
  forwards each recording to OpenAI's Responses API, so **your API key never reaches the
  browser**. It listens on `127.0.0.1` only.
- The judge is an audio-understanding model (`gpt-6-astra` by default) that receives the
  recording as `input_audio` and must reply by calling a `submit_score` function. The
  server turns its 0–10 sub-scores into a 0–100 total.

## Requirements

- **Node.js 20 or later** (`node --version`).
- **An OpenAI API key** whose account can send audio input to the judge model. If your
  account uses a different audio-capable model, set `JUDGE_MODEL` (see Configuration).
- **A browser with microphone access**: Chrome, Edge, Safari or Firefox on a computer.
  The page must be opened at `http://localhost`, because browsers only allow the
  microphone on secure origins and localhost counts as one.

## Getting started

```bash
git clone https://github.com/pwhiting/say-it-like.git
cd say-it-like
export OPENAI_API_KEY=sk-...        # or put it in your shell profile
npm start                           # same as: node server.mjs
```

Open <http://localhost:5173> and allow the microphone when asked.

There is nothing to install: `npm start` just runs `node server.mjs`.

## How to play

1. **Pick your microphone** from the 🎤 menu at the top and talk; the orange bar should
   move. (On a laptop with the lid closed, the default mic may be the built-in one, so
   choose your external mic. The choice is remembered.)
2. **Type the player names**, one per line. However many names you type is how many play.
3. **Choose a difficulty** and the number of rounds, then press **Start**.
4. Each round shows a line and a direction. Use **🔊 Read it** to hear the prompt (handy
   for kids who can't read yet), **🎲 New prompt** to reroll before anyone records, or
   **Write your own** to make one up.
5. Each player presses **● Record**, performs, and presses **■ Stop**. The first take
   counts, and recording stops by itself after 12 seconds.
6. While the next player records, the last take is judged in the background (about 7–12
   seconds each). Results stay hidden until everyone has been judged.
7. The results show each player's score, what they "sounded like", a comment, a tip, and
   a replay of their take. The winner's card turns green. Ties share the win.
8. After the last round, the player with the highest total score is crowned champion.

### Difficulty

| Level | Prompts drawn from | Judge |
|---|---|---|
| Easy (kids) | Easy lists only: big, high-contrast moods (happy, sad, scared, sleepy), simple characters, physical situations | Generous: an honest, recognizable attempt scores 6+ |
| Medium | Easy and Medium lists | Standard scale |
| Actor | Medium and Actor lists: subtle states (wistful, smug, bittersweet), subtext ("secretly thrilled but playing it cool"), theatrical styles | Strict: a broad, generic version scores about 5 |

### Scoring

The judge scores each part from 0 to 10:

| Part | Meaning |
|---|---|
| Manner | How clearly the requested mood, action, situation or style comes through |
| Character | How clearly the player sounds like the requested character |
| Line | Whether they said the given words |
| Flair | Commitment, creativity and fun |

The total out of 100 weights the direction (manner and character, split evenly when both
are asked for) at 70%, line at 15% and flair at 15%. The judge is told to score the
performance, never the person: not their natural voice, age, accent or microphone. It is
also told that louder is not better, and to ignore players who announce the score they
want.

## Configuration

Set these environment variables before `npm start`:

| Variable | Default | Purpose |
|---|---|---|
| `OPENAI_API_KEY` | (required) | Used only by the server, never sent to the browser |
| `JUDGE_MODEL` | `gpt-6-astra` | Any OpenAI model that accepts `input_audio` in the Responses API and supports function calling |
| `PORT` | `5173` | Local port |

## Project layout

```
server.mjs          Local server: static files, /api/score, the judge's instructions and scoring rubric
public/index.html   The page
public/app.js       Game flow: mic selection, recording, turns, judging, results, scoreboard
public/prompts.js   Every mood, character, action, situation, style and line, tagged by difficulty
public/styles.css   Styles (light and dark)
```

## Adding prompts

Edit `public/prompts.js`. Each list has `easy`, `medium` and `actor` tiers. The comment at
the top of the file explains how entries are phrased so they read naturally, e.g. "like a
*scared* cowboy" or "like a cowboy who's *out of breath after a race*".

The game is meant for families, so keep to these rules:

- No nationalities, ethnicities, regional accents, or real groups of people. Accent
  imitation turns into caricature, and a judge would reward the exaggeration.
- No drugs, alcohol, intoxication, flirting or cruelty.
- Characters are story archetypes, jobs, animals or fantasy creatures.
- Lines are short and everyday, not quotes from movies or songs.
- Put subtle states in the Actor tier. A voice judge, like a human audience, reliably hears
  big contrasts (happy vs sad) but not fine ones (wistful vs nostalgic).

To change how the judge scores, edit `JUDGE_INSTRUCTIONS` and `DIFFICULTY_NOTES` in
`server.mjs`.

## Privacy

- Recordings are sent to OpenAI for scoring and are subject to your OpenAI account's data
  terms. Only play with recordings you are comfortable sending, and get a parent's OK
  before recording children.
- The server does not save recordings. Takes live in the browser tab for replay and are
  gone when you close or reload it.
- The server logs each score with its OpenAI response ID, which is useful when reporting
  judge behavior.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Every score is 0 | The judge heard silence. Pick the right mic in the 🎤 menu and check that the orange bar moves when you talk. |
| "Microphone not available" | Allow the microphone for `localhost` in the browser's site settings, then reload. |
| "OPENAI_API_KEY is not set." on start | Export the key in the same terminal before `npm start`. |
| "The judge had trouble: …" | The message comes from OpenAI (bad key, no access to the model, rate limit). Press **Try judging again**, or set `JUDGE_MODEL`. |
| Port already in use | `PORT=5180 npm start`, then open that port. |
