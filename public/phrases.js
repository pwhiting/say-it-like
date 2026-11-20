// What the game says when a round is decided. {n} is replaced with the winner's name (or
// names, for a tie). Keep these warm and over-the-top: they cheer the winner, never put
// anyone else down.

export const WIN_PHRASES = {
  // Won by 25 points or more.
  blowout: [
    '{n} nailed it!!!', '{n} absolutely crushed it!', 'Standing ovation for {n}! 👏👏👏',
    '{n} stole the show!', 'Somebody give {n} a trophy! 🏆', '{n} brought the house down!',
    'Nobody was even close. {n} wins!!', '{n} is a natural!',
    '{n} absolutely owned that stage!', '{n} just knocked it out of the park!',
    'Roll out the red carpet for {n}!', '{n} made the judge forget to blink!',
    'That was a masterpiece, {n}!', '{n} left everyone in the dust!',
    'Ladies and gentlemen, {n} has entered the building!', '{n} turned it all the way up to eleven!',
    'Someone call Hollywood. {n} is ready!', '{n} just raised the bar to the ceiling!',
    'Encore! Encore! {n}, take another bow!', '{n} was on fire! 🔥',
    'The crowd goes wild for {n}!', '{n} absolutely smashed it!',
    'That performance should be in a museum, {n}!', '{n} delivered the goods and then some!',
    '{n} just gave the performance of a lifetime!', 'Mic drop! {n} wins! 🎤',
    'Bow down to the legend, {n}!', '{n} came, {n} spoke, {n} conquered!',
    '{n} made that look easy!', 'Somebody frame that take. Bravo, {n}!',
    '{n} is in a league of their own!', 'Unstoppable! {n} wins big!',
    '{n} left the judge speechless!', 'Ten out of ten would listen again. {n} wins!',
    '{n} just won by a country mile!', 'That was legendary, {n}!',
    '{n} has star power! ⭐', 'Clear the trophy shelf. {n} is coming through!',
    '{n} just stole the spotlight and kept it!', 'Pure gold from {n}! 🥇',
    '{n} could sell sand at the beach with that voice!', 'Break out the confetti for {n}! 🎉',
    '{n} was born for the stage!', '{n} blew the roof off the place!',
    'Hats off to {n}. That was brilliant!', '{n} went full superstar!',
    'The judge needs a minute to recover. {n} wins!', '{n} made it look like magic! ✨',
  ],
  // Won by 12 to 24 points.
  clear: [
    '{n} wins, no contest!', '{n} takes the round in style!', 'That round belongs to {n}!',
    '{n} wins it clearly!', 'Take a bow, {n}!',
    '{n} wins with flying colors!', '{n} takes the crown this round! 👑',
    'Nicely done, {n}. That one was all yours!', '{n} sold it like a pro!',
    '{n} had the judge hooked from the first word!', '{n} rises to the top!',
    'Big applause for {n}! 👏', '{n} wins and makes it look easy!',
    '{n} was the real deal that round!', 'Gold star for {n}! ⭐',
    '{n} grabs the win with a grin!', "That's how it's done, {n}!",
    '{n} wins by a mile!', 'The judge is a big fan of {n}!',
    '{n} turned up the drama and took the round!', 'Strong stuff, {n}. Round is yours!',
    '{n} brought the energy and the win!', 'Round winner: the one and only {n}!',
    '{n} wins it with confidence!', 'Trophy time for {n}! 🏆',
  ],
  // Won by 4 to 11 points.
  solid: [
    '{n} wins!', '{n} takes it!', 'Round goes to {n}!', 'Point for {n}!', '{n} gets this one!',
    'Well played, {n}!', '{n} comes out on top!', 'Nice work, {n}. The round is yours!',
    '{n} pulls ahead for the win!', 'Victory for {n}!', '{n} wins this round fair and square!',
    'And the winner is… {n}!', '{n} claims the round!', '{n} gets the nod from the judge!',
    'This one goes in the book for {n}!', '{n} does it!', 'Way to go, {n}!',
    '{n} takes home the trophy!', 'The judge picks {n}!', 'Hooray for {n}! 🎉',
  ],
  // Won by 3 points or fewer.
  close: [
    '{n} wins by a whisker!', 'Photo finish! {n} squeaks it out!', '{n} wins by a hair!',
    'Phew! {n} by a nose!', 'So close! {n} edges it!',
    'Down to the wire, and {n} takes it!', '{n} wins by the skin of their teeth!',
    'Nail-biter! {n} just barely wins!', '{n} sneaks past at the finish line!',
    'That was tight! {n} wins!', 'By the slimmest of margins: {n}!',
    'Heart-stopper! {n} pulls it off!', '{n} wins by a single breath!',
    'Squeaker! {n} gets the round!', 'Closest round yet, and {n} wins it!',
  ],
  // Two or more players share the top score.
  tie: [
    "It's a tie! {n} share the round!", 'Dead heat between {n}!', 'Great minds! {n} tie!',
    'Twins! {n} score the same!', 'Nobody blinks! {n} share the win!',
    "Can't split 'em! {n} both win!", 'Double trouble! {n} tie for the top!',
    'The judge loves {n} equally!', 'Everybody wins! Well, {n} do!',
    "It's a draw! Trophies for {n}!", 'Neck and neck! {n} share the glory!',
    'Too close to call! {n} tie!', 'Same score, same glory: {n}!',
  ],
  // Playing alone: by score.
  soloGreat: [
    'Bravo! Encore! 🎭', 'Oscar-worthy!', 'You nailed it!!!', 'You absolutely crushed it!',
    'Standing ovation! 👏👏👏', 'Somebody give you a trophy! 🏆', 'That was legendary!',
    'Hollywood is calling!', 'You were born for this!', 'Mic drop! 🎤',
  ],
  soloGood: [
    'Nicely done!', 'That was convincing!', 'The judge believed you!', 'Great take!',
    'You sold it!', 'Big applause! 👏', 'Now that was fun to hear!', 'Solid performance!',
  ],
  soloOk: [
    'Not bad! Turn it up next time!', 'Getting there! Ham it up a bit more!',
    'Good start! Go bigger!', "Warming up nicely! Don't hold back!",
  ],
  soloLow: [
    'Warm-up round! Really go for it next time!', 'The judge wants more drama!',
    'Give it everything next time!', 'Louder feelings, please! (Not louder voice!)',
  ],
};

// Added after the winner's phrase when the top score is 90 or more.
export const TOP_SCORE_TAGS = [
  '🎭 Oscar-worthy!', '🎭 Hollywood is calling!', '🏆 Hall of fame stuff!',
  '⭐ Pure star power!', '🎬 That belongs in a movie!', '🎭 Give that voice an award!',
  '🌟 Simply legendary!', '🎤 Mic drop!', '🎭 Broadway, here we come!',
  '👑 Royalty-level acting!', '🎬 And… cut! Perfect take!', '🏅 Gold medal performance!',
  '🎭 The critics are weeping!', '✨ Absolute magic!', '🎭 Somebody call the talent scouts!',
  '🎬 First take, best take!', '🌟 That one goes down in history!', '🎭 Take a bow. A long one.',
  '🏆 Trophy-case worthy!', '🎭 Chef\'s kiss!',
];

// Added when even the top score is under 30.
export const LOW_SCORE_TAGS = [
  '(The judge is still waiting for someone to really ham it up!)',
  '(Next round, everybody go bigger!)',
  '(The judge wants more drama from all of you!)',
  '(Warm-up round. Time to really commit!)',
];
