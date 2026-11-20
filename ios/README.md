# Say It Like for iPhone and iPad

The same game as the web version, built for passing one phone (or iPad) around the room.
It talks to OpenAI directly, so there's no server to run.

## How a turn works

1. The prompt fills the screen in large type so everyone can read it from arm's length.
2. The player taps **I'm ready!** The announcer says *"Get ready, Ava!"* and then
   *"Lights! Camera! Action!"*, with each word lighting up on screen.
3. Recording starts on "Action!" and a countdown ring runs. It stops by itself when time
   runs out, or the player taps **Done**.
4. The player can **Hear it back**, then taps **Pass to Leo →**. The judge scores the take
   in the background while the next player performs.
5. After the last player, the results are revealed together with a drumroll, the
   winner's card turns gold, the announcer calls the winner, and confetti flies.

The rules, prompts, judge and scoring match the web game: same rubric, same 0-100 total,
and the same turn order (most round wins goes first).

### The countdown

The recording time is about 1.3× as long as the line takes to say. The app finds that
length by having the on-device voice render the line silently into memory (it is never
played). Easy rounds get an extra second, and directions that slow speech down
("in slow motion", "as an opera", "yawning") get more. Every turn also gets a second to
take a breath. The result is rounded up and kept between 5 and 20 seconds. **Settings →
Recording time** switches between Snug (1.15×), Standard (1.3×) and Relaxed (1.6×).

### The announcer

The announcer uses OpenAI's text-to-speech voices (not the device voice). When a game
starts, the app makes "Get ready, *name*!" for each player plus the shared "Lights!",
"Camera!" and "Action!" clips, so turns start without a wait. Round winners and the
champion are announced with lines made on the fly. Pick a voice, with a sample of each,
in **Settings → Announcer → Voice**. If the announcer is off or a clip can't be made,
the same cues appear on screen with ticks instead.

## Privacy

- Each take is kept **in memory only**, for replay, until the round's results have been
  shown. It is released when the next round starts (or the game ends). The temporary
  recording file is deleted as soon as recording stops.
- Recordings are sent to OpenAI for scoring under your OpenAI account's data terms.
  Get a parent's OK before recording children.
- The API key is stored in the iOS Keychain (this device only) and is sent only to
  `api.openai.com`.
- Player names, the voice, and game settings are kept in UserDefaults. Announcer clips
  contain player names and are kept in memory only, never on disk.

## Building

Requirements: Xcode 26 or later; runs on iOS 18 or later. There are no dependencies.

1. Open `ios/SayItLike.xcodeproj`.
2. In **Signing & Capabilities**, choose your team. Change the bundle identifier
   (`in.dugg.sayitlike`) if you need to.
3. Run on a device or simulator. In the app, open **Settings** (gear icon) and paste an
   OpenAI API key.

The project uses a folder-synced group: any file added under `ios/SayItLike/` is part of
the app automatically.

### Models

| Setting | Default | Notes |
|---|---|---|
| Judge model | `gpt-6-astra` | Must accept `input_audio` in the Responses API and support function calling (same as `JUDGE_MODEL` for the web server). |
| Voice model | `gpt-4o-mini-tts` | Supports delivery instructions and every voice in the list. `tts-1` models work but ignore instructions and some voices. |

Both can be changed under **Settings → Advanced**.

## Keeping prompts in sync with the web game

Prompts, lines and winner phrases come from `public/*.js`. After editing them, regenerate
the app's copy:

```bash
node ios/scripts/export-game-data.mjs
```

The judge's instructions and rubric are in `ios/SayItLike/Services/Judge.swift`, ported
from `server.mjs`. Change both when you change one.

## App icon

The icon (and the in-app logo) is drawn in code, so it can be tweaked and redrawn:

```bash
swift ios/scripts/make-icon.swift
```

## Project layout

```
SayItLike/
  SayItLikeApp.swift     App entry and root view (phase switching, alerts, confetti layer)
  Model/
    GameModel.swift      Game flow: turns, background judging, reveal, scoring, turn order
    Prompt.swift         Prompt generation and "like a scared cowboy" phrasing
    GameData.swift       Loads Resources/GameData.json
    AppSettings.swift    Preferences and the Keychain-stored API key
    DemoState.swift      Debug-only sample screens (see below)
  Services/
    Judge.swift          The judge prompt, scoring tool and 0-100 total
    OpenAI.swift         Responses, speech and key-check requests
    Announcer.swift      OpenAI-voiced announcer clips, plus synthesized sound effects
    Audio.swift          Audio session, recorder, take playback, line-length estimate
  Screens/               Setup, Preparing, Round, Results, Final, Settings
  UI/                    Theme, buttons, cards, avatars, confetti
  Resources/GameData.json
```

### Checking layouts without playing

Debug builds accept `-demo <screen>` as a launch argument (Edit Scheme → Run → Arguments),
where screen is `preparing`, `ready`, `announcing`, `recording`, `review`, `judging`,
`results` or `final`. It fills in sample players and scores. Add `-autoturn` with `ready`
to run a full turn automatically.
