// Prompt pieces, by difficulty. Rules for adding entries:
// - No nationalities or ethnicities, no accents tied to them, and no real groups of people.
//   Regional types people imitate affectionately (a New Yorker) are fine; skip any that are
//   shorthand for being poor, rural or uneducated.
// - No drugs, alcohol, intoxication, flirting, cruelty, or anything a young child shouldn't say.
// - Characters are story archetypes, jobs, animals, or fantasy creatures.
// - Lines are short, everyday, and not quotes from movies or songs.
// - Easy = big, high-contrast choices a child can play and a judge can hear.
//   Actor = subtle states and subtext, where nuance decides the score.
//
// Phrasing: moods are adjectives ("a scared cowboy", "like you're scared"). Actions and
// situations read after "you're" and "who's" ("like a cowboy who's out of breath").
// Styles are complete phrases that follow "Say it".

import { LINES } from './lines.js';

export const MOODS = {
  easy: [
    'happy', 'sad', 'scared', 'excited', 'sleepy', 'grumpy', 'surprised', 'bored', 'silly',
    'proud', 'shy', 'giggly', 'cranky', 'worried', 'brave', 'sneaky', 'cheerful', 'impatient',
    'confused', 'exhausted', 'overjoyed', 'amazed', 'nervous', 'angry',
  ],
  // Medium moods all have a sound you can hear: a gasp, a sigh, a wail, a giggle, a growl.
  medium: [
    'terrified', 'jittery', 'panicked', 'frantic', 'timid', 'spooked', 'heartbroken', 'gloomy',
    'mopey', 'disappointed', 'ecstatic', 'gleeful', 'triumphant', 'relieved', 'delighted',
    'playful', 'bubbly', 'irritated', 'annoyed', 'frustrated', 'furious', 'exasperated', 'huffy',
    'sulky', 'astonished', 'shocked', 'flabbergasted', 'startled', 'awestruck', 'grossed-out',
    'snooty', 'offended', 'eager', 'embarrassed', 'bashful', 'boastful', 'flustered',
    'suspicious', 'puzzled', 'determined', 'mischievous', 'scheming', 'drowsy', 'lazy', 'hyper',
    'frazzled', 'bossy', 'dramatic', 'mysterious', 'heroic', 'bold',
  ],
  // Actor moods are subtle: close to a normal speaking voice, so nuance decides the score.
  actor: [
    'wistful', 'melancholy', 'bittersweet', 'nostalgic', 'mournful', 'sorrowful', 'serene',
    'content', 'blissful', 'smug', 'sarcastic', 'disdainful', 'scornful', 'indignant', 'bitter',
    'resigned', 'dread-filled', 'paranoid', 'incredulous', 'dumbfounded', 'uneasy', 'insecure',
    'self-important', 'vain', 'conspiratorial', 'devoted', 'adoring', 'sentimental', 'touched',
    'protective', 'compassionate', 'absent-minded', 'thoughtful', 'sly', 'theatrical', 'grand',
    'humble', 'resolute', 'valiant', 'swaggering', 'prissy', 'sluggish', 'revolted', 'jubilant',
    'giddy', 'outraged', 'unbothered', 'long-suffering', 'world-weary', 'starstruck',
    'anxious', 'lonely', 'homesick', 'tender', 'grateful', 'sympathetic', 'stubborn',
    'unimpressed', 'hopeful', 'curious', 'restless', 'sheepish', 'guilty', 'skeptical',
    'distracted', 'calm', 'peaceful', 'polite', 'pompous', 'fussy', 'apologetic', 'defiant',
    'confident',
  ],
};

export const CHARACTERS = {
  easy: [
    'cowboy', 'pirate captain', 'robot', 'superhero', 'ghost', 'dragon', 'giant', 'mouse', 'king',
    'queen', 'wizard', 'toddler who wants a cookie', 'talking dog', 'penguin', 'baby bird',
    'cartoon villain', 'grandma reading a bedtime story', 'sports announcer', 'astronaut',
    'fairy godmother', 'melting snowman', 'rooster at dawn', 'sleepy bear', 'scarecrow', 'monster under the bed',
    'Santa Claus', 'army sergeant',
  ],
  medium: [
    'news anchor', 'librarian', 'lifeguard', 'chef on a cooking show', 'coach at halftime',
    'flight attendant', 'tour guide', 'detective', 'secret agent', 'magician', 'cheerleader',
    'game show host', 'mad scientist', 'mermaid', 'troll under a bridge', 'alien visiting Earth',
    'knight', 'lighthouse keeper', 'farmer calling the cows home', 'weather reporter in a windstorm',
    'kindergarten teacher', 'substitute teacher', 'museum guard', 'castle butler',
    'college student during finals week', 'mountain climber at the summit', 'town crier',
    'circus ringmaster', 'puppet', 'toy soldier', 'grumpy gnome', 'owl professor',
    'sea captain in a storm', 'grim reaper', 'short-order cook', 'soccer announcer', 'surfer',
    'preacher', 'mob boss', 'New Yorker',
  ],
  actor: [
    'opera singer', 'auctioneer', 'movie trailer narrator', 'nature documentary narrator',
    'fortune teller', 'court jester', 'braggart soldier', 'miser counting coins',
    'night watchman', 'stage manager calling places', "queen's herald", 'retired sea captain',
    'ballet teacher', 'museum curator', 'radio play announcer', 'yoga instructor', 'golf announcer',
  ],
};

export const ACTIONS = {
  easy: [
    'trying to make someone laugh', 'begging for one more cookie', 'bragging about winning',
    'telling a secret', 'calming a crying baby', 'scolding a naughty puppy', 'cheering up a friend',
    'saying sorry',
  ],
  medium: [
    'trying to get out of trouble', 'selling it on TV', "convincing everyone it wasn't you",
    'warning everyone', 'teasing a friend', 'daring someone', 'rallying the troops',
    'bribing someone with candy', 'flattering the king', 'shushing a noisy crowd',
    'coaxing a cat down from a tree', 'announcing the king', 'challenging a rival',
  ],
  actor: [
    'breaking bad news gently', 'keeping a secret badly', 'trying to hypnotize someone',
    'confessing something', 'pleading with the judge', 'hiding hurt feelings',
    'pretending not to be scared', 'secretly thrilled but playing it cool',
    'politely furious', 'trying to sound confident but failing',
  ],
};

export const SITUATIONS = {
  easy: [
    'whispering in a library', 'shouting across a canyon', 'out of breath after a race',
    'trying not to laugh', 'freezing cold', 'just waking up', 'yawning',
    'trying not to wake the baby', 'holding back a sneeze',
  ],
  medium: [
    'on a bumpy wagon ride', 'talking through a walkie-talkie', 'at the bottom of a well',
    'stuffed up with a cold', 'melting in the desert heat', 'being tickled',
    'climbing a steep hill', 'running late',
  ],
  actor: [
    'trying not to cry', 'speaking to a huge crowd', 'on a crackly old radio',
    'talking in your sleep', 'saying goodbye at a train station',
  ],
};

export const STYLES = {
  easy: ['in slow motion', 'in fast-forward', 'like a nursery rhyme', 'like a spooky campfire story'],
  medium: [
    'like an epic movie trailer', 'like a soap opera cliffhanger', 'like a fairy-tale narrator',
    'like a TV commercial', 'like a sports replay', 'like an old radio drama', 'as an opera',
  ],
  actor: [
    'in grand Shakespearean style', 'as an over-the-top melodrama', 'like a film noir detective',
    'like an awards-show thank-you speech', 'as a dramatic poetry reading',
  ],
};

// The lines to perform live in lines.js.
export { LINES };

export const DIFFICULTIES = {
  easy: { label: 'Easy (kids)', tiers: ['easy'] },
  medium: { label: 'Medium', tiers: ['easy', 'medium'] },
  actor: { label: 'Actor', tiers: ['medium', 'actor'] },
};

export const KIND_LABELS = { mood: 'Mood', action: 'Action', situation: 'Situation', style: 'Style' };

const pick = (list) => list[Math.floor(Math.random() * list.length)];
const pool = (table, difficulty) => DIFFICULTIES[difficulty].tiers.flatMap((t) => table[t]);
// Characters who are one specific person take no article: "like Santa Claus".
const NAMED = new Set(['Santa Claus']);
const withArticle = (words) => (NAMED.has(words) ? words : `${/^[aeiou]/i.test(words) ? 'an' : 'a'} ${words}`);

// The direction shown to players, e.g. "like a scared cowboy" or "in slow motion".
export function direction(manner, character) {
  if (!manner) return `like ${withArticle(character)}`;
  if (manner.kind === 'style') return manner.text;
  if (manner.kind === 'mood') {
    return character ? `like ${withArticle(`${manner.text} ${character}`)}` : `like you're ${manner.text}`;
  }
  return character ? `like ${withArticle(character)} who's ${manner.text}` : `like you're ${manner.text}`;
}

export function randomPrompt(difficulty = 'medium') {
  const char = () => pick(pool(CHARACTERS, difficulty));
  const r = Math.random();
  let manner = null;
  let character = null;
  if (r < 0.35) {
    manner = { kind: 'mood', text: pick(pool(MOODS, difficulty)) };
    character = char();
  } else if (r < 0.5) {
    manner = { kind: 'mood', text: pick(pool(MOODS, difficulty)) };
  } else if (r < 0.62) {
    character = char();
  } else if (r < 0.8) {
    manner = { kind: 'action', text: pick(pool(ACTIONS, difficulty)) };
    if (Math.random() < 0.5) character = char();
  } else if (r < 0.93) {
    manner = { kind: 'situation', text: pick(pool(SITUATIONS, difficulty)) };
    if (Math.random() < 0.4) character = char();
  } else {
    manner = { kind: 'style', text: pick(pool(STYLES, difficulty)) };
  }
  return { line: pick(LINES), manner, character, direction: direction(manner, character), difficulty };
}
