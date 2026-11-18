import { randomPrompt, direction, KIND_LABELS } from './prompts.js';

const $ = (id) => document.getElementById(id);
const MAX_SECONDS = 12;
const MAX_PLAYERS = 12;

let players = [];      // { name, score, wins }
let totalRounds = 5;
let difficulty = 'medium';
let round = 0;
let prompt = null;     // { line, manner: {kind, text} | null, character, direction, difficulty }
let turn = 0;
let takes = [];        // per player this round: { blob, mime, url, prompt, result, error }
let tallied = false;
let outcome = null;    // { winners: [playerIndex], text, kind }

let stream, audioCtx, analyser, source, recorder, chunks, tickTimer, meterRaf, recStart;

// ---------- helpers ----------

function show(id) {
  for (const s of ['setup', 'round', 'results']) $(s).hidden = s !== id;
}

function speak(text) {
  if (!('speechSynthesis' in window)) return;
  speechSynthesis.cancel();
  speechSynthesis.speak(new SpeechSynthesisUtterance(text));
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

const pickOne = (list) => list[Math.floor(Math.random() * list.length)];

function joinNames(names) {
  return names.length < 2 ? names.join('') : `${names.slice(0, -1).join(', ')} and ${names.at(-1)}`;
}

// ---------- microphone ----------

const MIC_KEY = 'sayitlike.mic';
const savedMic = () => { try { return localStorage.getItem(MIC_KEY); } catch { return null; } };
const saveMic = (id) => { try { localStorage.setItem(MIC_KEY, id); } catch { /* private mode */ } };

// One capture of the chosen device feeds both the meter and the recorder.
async function openMic(deviceId) {
  stream?.getTracks().forEach((t) => t.stop());
  stream = null;
  $('mic-msg').textContent = '';
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        deviceId: deviceId ? { exact: deviceId } : undefined,
        echoCancellation: false, noiseSuppression: false, autoGainControl: false,
      },
    });
  } catch (e) {
    $('mic-msg').textContent = `Microphone not available: ${e.message}`;
    return;
  }
  audioCtx ??= new AudioContext();
  if (!analyser) {
    analyser = audioCtx.createAnalyser();
    analyser.fftSize = 1024;
  }
  source?.disconnect();
  source = audioCtx.createMediaStreamSource(stream);
  source.connect(analyser);
  cancelAnimationFrame(meterRaf);
  meter();
}

async function loadMics() {
  const inputs = (await navigator.mediaDevices.enumerateDevices()).filter((d) => d.kind === 'audioinput');
  const sel = $('mic');
  sel.innerHTML = '';
  inputs.forEach((d, i) => sel.add(new Option(d.label || `Microphone ${i + 1}`, d.deviceId)));
  const current = stream?.getAudioTracks()[0]?.getSettings().deviceId;
  if (current && inputs.some((d) => d.deviceId === current)) sel.value = current;
}

function meter() {
  const buf = new Uint8Array(analyser.fftSize);
  analyser.getByteTimeDomainData(buf);
  let peak = 0;
  for (const v of buf) peak = Math.max(peak, Math.abs(v - 128));
  $('level').style.width = `${Math.min(100, (peak / 128) * 160)}%`;
  meterRaf = requestAnimationFrame(meter);
}

$('mic').onchange = async () => {
  if (recorder?.state === 'recording') stopRecording();
  saveMic($('mic').value);
  await openMic($('mic').value);
};

navigator.mediaDevices.addEventListener('devicechange', async () => {
  // If the open mic was unplugged, fall back to the system default.
  if (!stream || stream.getAudioTracks().every((t) => t.readyState === 'ended')) await openMic(null);
  await loadMics();
});

// Browsers start audio suspended until the page is clicked.
document.addEventListener('click', () => audioCtx?.state === 'suspended' && audioCtx.resume());

(async () => {
  const saved = savedMic();
  await openMic(saved);
  if (!stream && saved) await openMic(null); // saved mic is gone
  await loadMics();                          // labels appear once permission is granted
})();

// ---------- setup ----------

function parseNames(text) {
  const seen = new Map();
  return text.split('\n').map((s) => s.trim()).filter(Boolean).slice(0, MAX_PLAYERS).map((name) => {
    const key = name.toLowerCase();
    const n = (seen.get(key) || 0) + 1;
    seen.set(key, n);
    return n > 1 ? `${name} ${n}` : name;
  });
}

$('start').onclick = async () => {
  const names = parseNames($('names').value);
  if (!names.length) {
    $('setup-msg').textContent = 'Type at least one player name.';
    return;
  }
  players = names.map((name) => ({ name, score: 0, wins: 0 }));
  totalRounds = Math.max(1, Math.min(20, parseInt($('rounds').value, 10) || 5));
  difficulty = $('difficulty').value;
  $('setup-msg').textContent = '';
  if (!stream) await openMic($('mic').value || null);
  if (!stream) {
    $('setup-msg').textContent = 'Pick a working microphone first.';
    return;
  }
  audioCtx.resume();
  round = 0;
  startRound();
};

// ---------- round ----------

function startRound() {
  round += 1;
  prompt = randomPrompt(difficulty);
  turn = 0;
  takes = [];
  renderPrompt();
  renderTurn();
  show('round');
}

function renderPrompt() {
  $('round-label').textContent = `Round ${round} of ${totalRounds}`;
  $('line').textContent = prompt.line;
  $('style').textContent = prompt.direction;
  const locked = turn > 0;
  $('shuffle').disabled = locked;
  $('custom').hidden = locked;
}

function renderTurn() {
  $('turn').textContent = players.length > 1 ? `${players[turn].name}, your turn!` : 'Your turn!';
  $('rec').textContent = '● Record';
  $('timer').textContent = '';
  $('round-msg').textContent = '';
}

$('read').onclick = () => speak(`Say it ${prompt.direction}: ${prompt.line}`);

$('shuffle').onclick = () => {
  prompt = randomPrompt(difficulty);
  renderPrompt();
};

$('c-use').onclick = () => {
  const line = $('c-line').value.trim();
  const mood = $('c-mood').value.trim();
  const character = $('c-character').value.trim() || null;
  if (!line || (!mood && !character)) {
    $('round-msg').textContent = 'Write a line and a mood or a character.';
    return;
  }
  const manner = mood ? { kind: 'mood', text: mood } : null;
  prompt = { line, manner, character, direction: direction(manner, character), difficulty };
  $('custom').open = false;
  $('round-msg').textContent = '';
  renderPrompt();
};

// ---------- recording ----------

function pickMime() {
  for (const t of ['audio/webm;codecs=opus', 'audio/mp4', 'audio/ogg;codecs=opus']) {
    if (MediaRecorder.isTypeSupported(t)) return t;
  }
  return '';
}

function startRecording() {
  if (!stream) {
    $('round-msg').textContent = 'No microphone. Pick one at the top.';
    return;
  }
  speechSynthesis?.cancel();
  chunks = [];
  const mime = pickMime();
  recorder = new MediaRecorder(stream, mime ? { mimeType: mime } : undefined);
  recorder.ondataavailable = (e) => e.data.size && chunks.push(e.data);
  recorder.onstop = onRecorded;
  recorder.start();
  recStart = performance.now();
  $('rec').textContent = '■ Stop';
  tickTimer = setInterval(() => {
    const s = (performance.now() - recStart) / 1000;
    $('timer').textContent = `${s.toFixed(0)}s / ${MAX_SECONDS}s`;
    if (s >= MAX_SECONDS) stopRecording();
  }, 200);
}

function stopRecording() {
  clearInterval(tickTimer);
  if (recorder?.state === 'recording') recorder.stop();
}

// The first recording counts: it goes straight to the judge and the next player is up.
function onRecorded() {
  const mime = recorder.mimeType || 'audio/webm';
  const blob = new Blob(chunks, { type: mime });
  if (!blob.size) {
    renderTurn();
    $('round-msg').textContent = 'Nothing was recorded. Try again.';
    return;
  }
  const take = { blob, mime, url: URL.createObjectURL(blob), prompt: { ...prompt }, result: null, error: null };
  takes[turn] = take;
  judge(take);
  turn += 1;
  if (turn < players.length) {
    renderPrompt();
    renderTurn();
  } else {
    showResults();
  }
}

$('rec').onclick = () => (recorder?.state === 'recording' ? stopRecording() : startRecording());

// ---------- judging ----------

function blobToBase64(blob) {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(String(r.result).split(',')[1]);
    r.onerror = () => reject(r.error);
    r.readAsDataURL(blob);
  });
}

async function judge(take) {
  take.result = null;
  take.error = null;
  try {
    const audio = await blobToBase64(take.blob);
    const { line, manner, character, direction: dir, difficulty: diff } = take.prompt;
    const res = await fetch('/api/score', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ audio, mime: take.mime, line, manner, character, direction: dir, difficulty: diff }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
    take.result = data;
  } catch (e) {
    take.error = e.message;
  }
  outcome = null; // results changed; decide the round again
  if (!$('results').hidden) renderResults();
}

// ---------- round outcome ----------

const PHRASES = {
  blowout: [
    '{n} nailed it!!!', '{n} absolutely crushed it!', 'Standing ovation for {n}! 👏👏👏',
    '{n} stole the show!', 'Somebody give {n} a trophy! 🏆', '{n} brought the house down!',
    'Nobody was even close. {n} wins!!', '{n} is a natural!',
  ],
  clear: [
    '{n} wins, no contest!', '{n} takes the round in style!', 'That round belongs to {n}!',
    '{n} wins it clearly!', 'Take a bow, {n}!',
  ],
  solid: ['{n} wins!', '{n} takes it!', 'Round goes to {n}!', 'Point for {n}!', '{n} gets this one!'],
  close: [
    '{n} wins by a whisker!', 'Photo finish! {n} squeaks it out!', '{n} wins by a hair!',
    'Phew! {n} by a nose!', 'So close! {n} edges it!',
  ],
  tie: ["It's a tie! {n} share the round!", 'Dead heat between {n}!', 'Great minds! {n} tie!'],
  soloGreat: ['Bravo! Encore! 🎭', 'Oscar-worthy!', 'You nailed it!!!'],
  soloGood: ['Nicely done!', 'That was convincing!', 'The judge believed you!'],
  soloOk: ['Not bad! Turn it up next time!', 'Getting there! Ham it up a bit more!'],
  soloLow: ['Warm-up round! Really go for it next time!', 'The judge wants more drama!'],
};

// Decides who won the round and the phrase for the winning card. Ties share the win.
function decideRound() {
  const scored = players
    .map((p, i) => ({ i, name: p.name, total: takes[i]?.result?.total }))
    .filter((s) => s.total != null)
    .sort((a, b) => b.total - a.total);
  if (!scored.length) return { winners: [], text: '', kind: 'none' };

  const top = scored[0].total;
  if (players.length === 1) {
    const band = top >= 85 ? 'soloGreat' : top >= 60 ? 'soloGood' : top >= 35 ? 'soloOk' : 'soloLow';
    return { winners: top >= 60 ? [0] : [], text: pickOne(PHRASES[band]), kind: top >= 85 ? 'blowout' : 'solid' };
  }

  const leaders = scored.filter((s) => s.total === top);
  const margin = top - (scored[leaders.length]?.total ?? 0);
  const kind = leaders.length > 1 ? 'tie'
    : margin >= 25 ? 'blowout' : margin >= 12 ? 'clear' : margin >= 4 ? 'solid' : 'close';
  let text = pickOne(PHRASES[kind]).replace('{n}', joinNames(leaders.map((s) => s.name)));
  if (top >= 90) text += ' 🎭 Oscar-worthy!';
  else if (top < 30) text += ' (The judge is still waiting for someone to really ham it up!)';
  return { winners: leaders.map((s) => s.i), text, kind };
}

// ---------- results ----------

function showResults() {
  tallied = false;
  outcome = null;
  $('results-title').textContent = `Round ${round} results`;
  $('banner').hidden = true;
  show('results');
  renderResults();
}

function bar(label, v) {
  if (v == null) return '';
  return `<span>${label}</span><div class="track"><div class="fill" style="width:${v * 10}%"></div></div><span>${v}/10</span>`;
}

function renderResults() {
  const settled = takes.every((t) => t.result || t.error);
  if (settled && !outcome) outcome = decideRound();
  const order = players.map((p, i) => i);
  if (settled) order.sort((a, b) => (takes[b].result?.total ?? -1) - (takes[a].result?.total ?? -1));

  const cards = $('result-cards');
  cards.innerHTML = '';
  for (const i of order) {
    const p = players[i];
    const t = takes[i];
    const r = t.result;
    const el = document.createElement('div');
    el.className = 'card result';
    if (!settled) {
      // Nothing is revealed until every take has been judged.
      const status = r || t.error ? '✓ judged, waiting for the others' : 'judging…';
      el.innerHTML = `<h3><span>${esc(p.name)}</span><span class="muted">${status}</span></h3>`;
    } else if (r) {
      const won = outcome.winners.includes(i);
      const showVerdict = won || (players.length === 1 && outcome.text);
      if (won) el.classList.add('win');
      const label = KIND_LABELS[t.prompt.manner?.kind] || 'Mood';
      el.innerHTML = `
        ${showVerdict ? `<p class="verdict ${outcome.kind}">${esc(outcome.text)}</p>` : ''}
        <h3><span>${esc(p.name)}</span><span class="total">${r.total} pts</span></h3>
        <p class="muted">Sounded like ${esc(r.soundedLike)}</p>
        <div class="bars">${bar(label, r.manner)}${bar('Character', r.character)}${bar('Line', r.line)}${bar('Flair', r.flair)}</div>
        <p>${esc(r.comment)}</p>
        <p class="muted">Tip: ${esc(r.tip)}</p>
        <p class="muted">Heard: “${esc(r.heard)}”</p>
        <div class="row"><button data-act="say">🔊 Read</button></div>`;
      el.querySelector('[data-act=say]').onclick = () => speak(`${p.name}, ${r.total} points. ${r.comment}`);
    } else {
      el.innerHTML = `<h3><span>${esc(p.name)}</span></h3><p class="msg">The judge had trouble: ${esc(t.error)}</p>
        <div class="row"><button data-act="retry">Try judging again</button></div>`;
      el.querySelector('[data-act=retry]').onclick = () => { t.error = null; outcome = null; renderResults(); judge(t); };
    }
    const audio = document.createElement('audio');
    audio.controls = true;
    audio.src = t.url;
    el.appendChild(audio);
    cards.appendChild(el);
  }

  $('waiting').hidden = settled;
  renderBoard();
  $('next').textContent = round >= totalRounds ? 'Final scores' : 'Next round';
  $('next').disabled = !settled;
}

// Standings including this round once it is revealed. Ranked by total score, then wins.
function standings() {
  const pending = !tallied && outcome != null;
  return players
    .map((p, i) => ({
      name: p.name,
      score: p.score + (pending ? takes[i]?.result?.total ?? 0 : 0),
      wins: p.wins + (pending && players.length > 1 && outcome.winners.includes(i) ? 1 : 0),
    }))
    .sort((a, b) => b.score - a.score || b.wins - a.wins);
}

function renderBoard() {
  const multi = players.length > 1;
  const rows = standings().map((r) => `<tr><td>${esc(r.name)}</td>${multi ? `<td>${r.wins}</td>` : ''}<td>${r.score}</td></tr>`);
  $('board').innerHTML = `<thead><tr><th>Player</th>${multi ? '<th>Wins</th>' : ''}<th>Total score</th></tr></thead><tbody>${rows.join('')}</tbody>`;
}

$('next').onclick = () => {
  if ($('next').textContent === 'Play again') {
    show('setup');
    return;
  }
  if (!tallied) {
    players.forEach((p, i) => {
      p.score += takes[i]?.result?.total ?? 0;
      if (players.length > 1 && outcome?.winners.includes(i)) p.wins += 1;
    });
    tallied = true;
  }
  if (round < totalRounds) {
    startRound();
    return;
  }
  const ranked = standings();
  const champs = ranked.filter((r) => r.score === ranked[0].score);
  const mostWins = Math.max(...players.map((p) => p.wins));
  const winRecord = players.filter((p) => p.wins === mostWins).map((p) => p.name);
  $('results-title').textContent = 'Final scores';
  const banner = $('banner');
  banner.hidden = false;
  banner.className = 'banner blowout';
  if (players.length === 1) {
    banner.textContent = `${ranked[0].score} points in ${totalRounds} rounds!`;
  } else {
    banner.textContent = champs.length > 1
      ? `🏆 It's a tie! ${joinNames(champs.map((c) => c.name))} share the crown!`
      : `🏆 ${champs[0].name} is the champion!`;
    if (mostWins > 0) banner.textContent += ` Most round wins: ${joinNames(winRecord)} (${mostWins}).`;
  }
  $('waiting').hidden = true;
  $('result-cards').innerHTML = '';
  renderBoard();
  $('next').textContent = 'Play again';
  $('next').disabled = false;
};
