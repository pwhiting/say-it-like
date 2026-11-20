import { randomPrompt, direction, KIND_LABELS } from './prompts.js';
import { WIN_PHRASES as PHRASES, TOP_SCORE_TAGS, LOW_SCORE_TAGS } from './phrases.js';

const $ = (id) => document.getElementById(id);
const MAX_SECONDS = 12;
const MAX_PLAYERS = 12;
const COLORS = ['#e8590c', '#1c7ed6', '#7048e8', '#0c8599', '#d6336c', '#2f9e44',
  '#c2255c', '#1971c2', '#9c36b5', '#e67700', '#3b5bdb', '#087f5b'];

let players = [];      // { name, score, wins, lastWin, color }
let totalRounds = 5;
let difficulty = 'medium';
let round = 0;
let prompt = null;     // { line, manner: {kind, text} | null, character, direction, difficulty }
let order = [];        // player indexes in this round's turn order
let turn = 0;          // position in `order`
let takes = [];        // by player index, this round: { blob, mime, url, prompt, result, error }
let tallied = false;
let outcome = null;    // { winners: [playerIndex], text, kind }
let reveal = 'hidden'; // 'hidden' | 'suspense' | 'shown' for this round's results
let celebrated = '';   // winners already celebrated this round, so a re-render doesn't repeat it

let stream, audioCtx, analyser, source, recorder, chunks, tickTimer, meterRaf, recStart;

// ---------- helpers ----------

function show(id) {
  stopReplay();
  for (const s of ['setup', 'round', 'results']) $(s).hidden = s !== id;
  window.scrollTo({ top: 0 });
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

const pickOne = (list) => list[Math.floor(Math.random() * list.length)];
const calm = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

function joinNames(names) {
  return names.length < 2 ? names.join('') : `${names.slice(0, -1).join(', ')} and ${names.at(-1)}`;
}

function avatar(i, size = '') {
  const p = players[i];
  return `<span class="avatar ${size}" style="--c:${p.color}"><span>${esc([...p.name][0].toUpperCase())}</span></span>`;
}

function trophies(n) {
  if (!n) return '';
  return n <= 4 ? '🏆'.repeat(n) : `🏆×${n}`;
}

// Restarts a CSS entrance animation on an element.
function replay(el, cls = 'fresh') {
  el.classList.remove(cls);
  void el.offsetWidth;
  el.classList.add(cls);
}

const store = {
  get: (k) => { try { return localStorage.getItem(k); } catch { return null; } },
  set: (k, v) => { try { localStorage.setItem(k, v); } catch { /* private mode */ } },
};

// ---------- sound and confetti ----------

let soundOn = store.get('sayitlike.sound') !== 'off';
function renderSound() {
  $('sound').textContent = soundOn ? '🔊' : '🔈';
  $('sound').setAttribute('aria-pressed', String(soundOn));
  $('sound').title = soundOn ? 'Sound effects on' : 'Sound effects off';
}
$('sound').onclick = () => {
  soundOn = !soundOn;
  store.set('sayitlike.sound', soundOn ? 'on' : 'off');
  renderSound();
};
renderSound();

// A short synthesized fanfare. Played only on the results screen, never while recording.
function fanfare(big = false) {
  if (!soundOn || !audioCtx) return;
  audioCtx.resume();
  const notes = big
    ? [[523.25, 0], [659.25, .12], [783.99, .24], [1046.5, .36], [783.99, .56], [1046.5, .68]]
    : [[523.25, 0], [659.25, .1], [783.99, .2], [1046.5, .3]];
  const t0 = audioCtx.currentTime + .03;
  notes.forEach(([freq, at], k) => {
    const last = k === notes.length - 1;
    const len = last ? .7 : .16;
    for (const [type, vol, mult] of [['triangle', .16, 1], ['sine', .05, 2]]) {
      const o = audioCtx.createOscillator();
      const g = audioCtx.createGain();
      o.type = type;
      o.frequency.value = freq * mult;
      const t = t0 + at;
      g.gain.setValueAtTime(.0001, t);
      g.gain.exponentialRampToValueAtTime(vol, t + .02);
      g.gain.exponentialRampToValueAtTime(.0001, t + len);
      o.connect(g).connect(audioCtx.destination);
      o.start(t);
      o.stop(t + len + .05);
    }
  });
}

// Confetti fired from both bottom corners. Draws on a temporary canvas, then removes it.
function confetti(power = 1) {
  if (calm()) return;
  const c = document.createElement('canvas');
  c.className = 'confetti';
  document.body.appendChild(c);
  const W = innerWidth, H = innerHeight, dpr = devicePixelRatio || 1;
  c.width = W * dpr;
  c.height = H * dpr;
  const ctx = c.getContext('2d');
  ctx.scale(dpr, dpr);
  const colors = ['#f5b301', '#ffd76a', '#e8590c', '#f76707', '#1c7ed6', '#d6336c', '#2f9e44', '#7048e8'];
  const n = Math.round(Math.min(220, (W / 4)) * power);
  const parts = Array.from({ length: n }, (_, k) => {
    const left = k % 2 === 0;
    const speed = 11 + Math.random() * 11;
    const angle = (left ? -1 : 1) * (Math.PI / 2 - (.25 + Math.random() * .55));
    return {
      x: left ? -10 : W + 10, y: H * .95,
      vx: Math.sin(angle) * speed * (W / 900 + .4), vy: -Math.cos(angle) * speed * (H / 800 + .3),
      w: 6 + Math.random() * 6, h: 9 + Math.random() * 8,
      r: Math.random() * Math.PI, vr: (Math.random() - .5) * .35,
      flip: Math.random() * Math.PI, vf: .1 + Math.random() * .2,
      color: colors[k % colors.length], delay: Math.random() * 180,
    };
  });
  const start = performance.now();
  const LIFE = 3200;
  function frame(now) {
    const t = now - start;
    ctx.clearRect(0, 0, W, H);
    ctx.globalAlpha = Math.max(0, Math.min(1, (LIFE - t) / 700));
    for (const p of parts) {
      if (t < p.delay) continue;
      p.vy += .32;
      p.vx *= .985;
      p.vy *= .985;
      p.x += p.vx;
      p.y += p.vy;
      p.r += p.vr;
      p.flip += p.vf;
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate(p.r);
      ctx.scale(1, Math.cos(p.flip));
      ctx.fillStyle = p.color;
      ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
      ctx.restore();
    }
    if (t < LIFE) requestAnimationFrame(frame);
    else c.remove();
  }
  requestAnimationFrame(frame);
}

// Counts a number up from 0 for the reveal.
function countUp(el, to, delay) {
  if (calm()) { el.textContent = to; return; }
  el.textContent = '0';
  const dur = 900;
  setTimeout(() => {
    const start = performance.now();
    const step = (now) => {
      const k = Math.min(1, (now - start) / dur);
      el.textContent = Math.round(to * (1 - Math.pow(1 - k, 3)));
      if (k < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }, delay);
}

// ---------- microphone ----------

const MIC_KEY = 'sayitlike.mic';

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
  const level = Math.min(1, (peak / 128) * 1.6);
  $('level').style.width = `${level * 100}%`;
  if (recorder?.state === 'recording') $('rec').style.setProperty('--lvl', level.toFixed(3));
  meterRaf = requestAnimationFrame(meter);
}

$('mic').onchange = async () => {
  if (recorder?.state === 'recording') stopRecording();
  store.set(MIC_KEY, $('mic').value);
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
  const saved = store.get(MIC_KEY);
  await openMic(saved);
  if (!stream && saved) await openMic(null); // saved mic is gone
  await loadMics();                          // labels appear once permission is granted
})();

// ---------- setup ----------

const NAMES_KEY = 'sayitlike.names';
$('names').value = store.get(NAMES_KEY) || '';

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
  store.set(NAMES_KEY, $('names').value.trim());
  players = names.map((name, i) => ({ name, score: 0, wins: 0, lastWin: 0, color: COLORS[i % COLORS.length] }));
  totalRounds = Math.max(1, Math.min(20, parseInt($('rounds').value, 10) || 5));
  difficulty = document.querySelector('input[name=difficulty]:checked')?.value || 'medium';
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

// ---------- turn order ----------

// Round 1 goes in the order the names were typed. After that, most round wins goes first;
// among players tied on wins, the one who won most recently goes first. Anyone still tied
// (no wins yet, or they shared the same round) keeps the order the names were typed.
function turnOrder(stats) {
  return stats.map((_, i) => i).sort((a, b) =>
    stats[b].wins - stats[a].wins || stats[b].lastWin - stats[a].lastWin || a - b);
}

// ---------- round ----------

function startRound() {
  round += 1;
  prompt = randomPrompt(difficulty);
  order = turnOrder(players);
  turn = 0;
  takes = [];
  renderPrompt(true);
  renderTurn();
  show('round');
}

function renderPrompt(animate = false) {
  $('round-label').textContent = `Round ${round} of ${totalRounds}`;
  $('pips').innerHTML = totalRounds <= 20
    ? Array.from({ length: totalRounds }, (_, k) => `<i class="${k + 1 < round ? 'done' : k + 1 === round ? 'now' : ''}"></i>`).join('')
    : '';
  $('line').textContent = prompt.line;
  $('style').textContent = prompt.direction;
  if (animate) replay(document.querySelector('.prompt'));
  const locked = turn > 0;
  $('shuffle').disabled = locked;
  $('custom').hidden = locked;
}

function renderLineup() {
  const multi = players.length > 1;
  $('lineup-wrap').hidden = !multi;
  if (!multi) return;
  $('lineup-label').textContent = round === 1 ? 'Turn order' : 'Turn order · most wins goes first';
  $('lineup').innerHTML = order.map((i, pos) => {
    const state = pos < turn ? 'done' : pos === turn ? 'now' : '';
    const p = players[i];
    return `<li class="${state}"><span class="n">${pos + 1}</span>${avatar(i)}<span>${esc(p.name)}</span>`
      + (p.wins ? `<span class="trophies" title="${p.wins} round win${p.wins > 1 ? 's' : ''}">${trophies(p.wins)}</span>` : '')
      + '</li>';
  }).join('');
}

function renderTurn() {
  const i = order[turn];
  const h = $('turn');
  h.innerHTML = players.length > 1 ? `${esc(players[i].name)}, you're up!` : 'Your turn!';
  replay(h);
  renderLineup();
  setRecUI(false);
  $('timer').textContent = `Up to ${MAX_SECONDS} seconds · your first take counts`;
  $('round-msg').textContent = '';
}

function setRecUI(recording) {
  const btn = $('rec');
  btn.classList.toggle('recording', recording);
  $('rec-text').textContent = recording ? 'Stop' : 'Record';
  btn.setAttribute('aria-label', recording ? 'Stop recording' : 'Start recording');
  if (!recording) {
    btn.style.setProperty('--p', 0);
    btn.style.setProperty('--lvl', 0);
  }
}

$('shuffle').onclick = () => {
  prompt = randomPrompt(difficulty);
  renderPrompt(true);
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
  renderPrompt(true);
};

// ---------- recording ----------

function pickMime() {
  for (const t of ['audio/webm;codecs=opus', 'audio/mp4', 'audio/ogg;codecs=opus']) {
    if (MediaRecorder.isTypeSupported(t)) return t;
  }
  return '';
}

function startRecording() {
  if ($('round').hidden || turn >= order.length) return;
  if (!stream) {
    $('round-msg').textContent = 'No microphone. Pick one at the top.';
    return;
  }
  chunks = [];
  const mime = pickMime();
  recorder = new MediaRecorder(stream, mime ? { mimeType: mime } : undefined);
  recorder.ondataavailable = (e) => e.data.size && chunks.push(e.data);
  recorder.onstop = onRecorded;
  recorder.start();
  recStart = performance.now();
  setRecUI(true);
  $('timer').textContent = `0s / ${MAX_SECONDS}s`;
  tickTimer = setInterval(() => {
    const s = (performance.now() - recStart) / 1000;
    $('rec').style.setProperty('--p', Math.min(1, s / MAX_SECONDS).toFixed(3));
    $('timer').textContent = `${Math.floor(s)}s / ${MAX_SECONDS}s`;
    if (s >= MAX_SECONDS) stopRecording();
  }, 100);
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
  takes[order[turn]] = take;
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
  let text = pickOne(PHRASES[kind]).replaceAll('{n}', joinNames(leaders.map((s) => s.name)));
  if (top >= 90) text += ` ${pickOne(TOP_SCORE_TAGS)}`;
  else if (top < 30) text += ` ${pickOne(LOW_SCORE_TAGS)}`;
  return { winners: leaders.map((s) => s.i), text, kind };
}

// ---------- results ----------

function showResults() {
  tallied = false;
  outcome = null;
  reveal = 'hidden';
  celebrated = '';
  $('results-title').textContent = `Round ${round} of ${totalRounds} · results`;
  $('banner').hidden = true;
  $('suspense').hidden = true;
  show('results');
  renderResults();
}

// Replay a take with one button: "Hear it again" plays it, pressing again stops it.
// Only one take plays at a time.
const HEAR_LABEL = '<span aria-hidden="true">🔊</span> Hear it again';
let replayAudio = null;
let replayBtn = null;

function stopReplay() {
  replayAudio?.pause();
  replayAudio = null;
  if (replayBtn) {
    replayBtn.classList.remove('playing');
    replayBtn.innerHTML = HEAR_LABEL;
    replayBtn = null;
  }
}

function hearButton(url) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'hear';
  btn.innerHTML = HEAR_LABEL;
  btn.onclick = () => {
    const wasPlaying = replayBtn === btn;
    stopReplay();
    if (wasPlaying) return;
    const audio = new Audio(url);
    replayAudio = audio;
    replayBtn = btn;
    btn.classList.add('playing');
    btn.innerHTML = '<span class="eq" aria-hidden="true"><i></i><i></i><i></i></span> Stop';
    audio.onended = () => replayAudio === audio && stopReplay();
    audio.play().catch(() => replayAudio === audio && stopReplay());
  };
  return btn;
}

function bar(label, v) {
  if (v == null) return '';
  return `<span>${label}</span><div class="track"><div class="fill" style="--w:${v * 10}%"></div></div><span>${v}/10</span>`;
}

function renderResults(animate = false) {
  stopReplay(); // the cards are rebuilt, so their buttons are about to go away
  const settled = takes.every((t) => t.result || t.error);
  if (settled && !outcome) outcome = decideRound();

  // Once everyone is judged, hold a beat of suspense before the reveal.
  if (settled && reveal === 'hidden') {
    reveal = 'suspense';
    setTimeout(() => {
      reveal = 'shown';
      renderResults(true);
    }, calm() ? 500 : 1700);
  }
  const shown = reveal === 'shown' && settled; // a retried take hides results until it is judged again

  const cardOrder = [...order];
  if (shown) cardOrder.sort((a, b) => (takes[b].result?.total ?? -1) - (takes[a].result?.total ?? -1));

  const cards = $('result-cards');
  cards.innerHTML = '';
  cards.hidden = reveal === 'suspense';
  cardOrder.forEach((i, pos) => {
    const p = players[i];
    const t = takes[i];
    const r = t.result;
    const el = document.createElement('div');
    el.className = 'card result';
    if (animate) {
      el.classList.add('enter');
      el.style.setProperty('--d', `${pos * 140}ms`);
    }
    if (!shown) {
      // Nothing is revealed until every take has been judged.
      const done = r || t.error;
      el.innerHTML = `<div class="head">${avatar(i, 'lg')}<span class="pname">${esc(p.name)}</span>
        <span class="status ${done ? 'ok' : ''}">${done ? '✓ judged' : 'judging…'}</span></div>`;
    } else if (r) {
      const won = outcome.winners.includes(i);
      const showVerdict = won || (players.length === 1 && outcome.text);
      if (won) el.classList.add('win');
      const label = KIND_LABELS[t.prompt.manner?.kind] || 'Mood';
      el.innerHTML = `
        ${won ? `<span class="ribbon">${players.length > 1 ? '🏆 Round winner' : '🌟 Great take'}</span>` : ''}
        ${showVerdict ? `<p class="verdict">${esc(outcome.text)}</p>` : ''}
        <div class="head">${avatar(i, 'lg')}<span class="pname">${esc(p.name)}${won && players.length > 1 ? '<span class="trophy-pop">+1 🏆</span>' : ''}</span>
          <span class="total"><b>${r.total}</b><small>pts</small></span></div>
        <p class="sounded muted">Sounded like ${esc(r.soundedLike)}</p>
        <div class="bars">${bar(label, r.manner)}${bar('Character', r.character)}${bar('Line', r.line)}${bar('Flair', r.flair)}</div>
        <p>${esc(r.comment)}</p>
        <p class="muted">Tip: ${esc(r.tip)}</p>
        <p class="muted">Heard: “${esc(r.heard)}”</p>`;
      if (animate) countUp(el.querySelector('.total b'), r.total, pos * 140 + 150);
    } else {
      el.innerHTML = `<div class="head">${avatar(i, 'lg')}<span class="pname">${esc(p.name)}</span></div>
        <p class="msg">The judge had trouble: ${esc(t.error)}</p>
        <div class="row"><button data-act="retry">Try judging again</button></div>`;
      el.querySelector('[data-act=retry]').onclick = () => { t.error = null; outcome = null; renderResults(); judge(t); };
    }
    if (shown) el.appendChild(hearButton(t.url));
    cards.appendChild(el);
  });

  $('suspense').hidden = reveal !== 'suspense';
  $('waiting').hidden = settled;
  renderBoard(shown);
  renderNextOrder(shown);
  $('next').textContent = round >= totalRounds ? 'Final scores' : 'Next round';
  $('next').disabled = !shown;

  if (shown && outcome.winners.length) {
    const key = outcome.winners.join(',');
    if (key !== celebrated) {
      celebrated = key;
      setTimeout(() => {
        confetti(outcome.kind === 'blowout' ? 1.3 : 1);
        fanfare();
      }, animate ? 250 : 0);
    }
  }
}

// Each player's totals, including this round once it is revealed but not yet tallied.
function projected(includeRound) {
  const pending = includeRound && !tallied && outcome != null;
  return players.map((p, i) => {
    const won = pending && players.length > 1 && outcome.winners.includes(i);
    return {
      i,
      name: p.name,
      score: p.score + (pending ? takes[i]?.result?.total ?? 0 : 0),
      wins: p.wins + (won ? 1 : 0),
      lastWin: won ? round : p.lastWin,
    };
  });
}

// Ranked by total score, then wins.
function standings(includeRound = true) {
  return projected(includeRound).sort((a, b) => b.score - a.score || b.wins - a.wins);
}

function renderBoard(includeRound = true, final = false) {
  const multi = players.length > 1;
  const ranked = standings(includeRound);
  const medals = ['🥇', '🥈', '🥉'];
  let rank = 0;
  const rows = ranked.map((r, k) => {
    if (k === 0 || r.score !== ranked[k - 1].score) rank = k + 1;
    const lead = multi && r.score > 0 && r.score === ranked[0].score;
    const mark = final && multi ? (medals[rank - 1] || rank) : rank;
    return `<tr class="${lead ? 'lead' : ''}"><td class="rank">${mark}</td>
      <td><span class="who">${avatar(r.i)}${esc(r.name)}</span></td>
      ${multi ? `<td class="trophies">${trophies(r.wins) || '<span class="muted">–</span>'}</td>` : ''}
      <td class="num">${r.score}</td></tr>`;
  });
  $('board').innerHTML = `<thead><tr><th></th><th>Player</th>${multi ? '<th>Round wins</th>' : ''}<th class="num">Score</th></tr></thead><tbody>${rows.join('')}</tbody>`;
}

function renderNextOrder(shown) {
  const el = $('next-order');
  el.hidden = !shown || players.length < 2 || round >= totalRounds;
  if (el.hidden) return;
  const next = turnOrder(projected(true)).map((i) => `<b>${esc(players[i].name)}</b>`);
  el.innerHTML = `Next round's order: ${next.join(' → ')}`;
}

$('next').onclick = () => {
  if ($('next').textContent === 'Play again') {
    show('setup');
    return;
  }
  if (!tallied) {
    players.forEach((p, i) => {
      p.score += takes[i]?.result?.total ?? 0;
      if (players.length > 1 && outcome?.winners.includes(i)) {
        p.wins += 1;
        p.lastWin = round;
      }
    });
    tallied = true;
  }
  if (round < totalRounds) {
    startRound();
    return;
  }
  showFinal();
};

function showFinal() {
  stopReplay();
  const ranked = standings(false);
  const champs = ranked.filter((r) => r.score === ranked[0].score);
  const mostWins = Math.max(...players.map((p) => p.wins));
  const winRecord = players.filter((p) => p.wins === mostWins).map((p) => p.name);
  $('results-title').textContent = 'Final scores';
  const banner = $('banner');
  let champ, sub = '';
  if (players.length === 1) {
    champ = `${ranked[0].score} points!`;
    sub = `across ${totalRounds} round${totalRounds > 1 ? 's' : ''}`;
  } else {
    champ = champs.length > 1
      ? `${joinNames(champs.map((c) => c.name))} share the crown!`
      : `${champs[0].name} is the champion!`;
    sub = `${ranked[0].score} points`;
    if (mostWins > 0) sub += ` · Most round wins: ${joinNames(winRecord)} (${mostWins})`;
  }
  banner.innerHTML = `<span class="crown" aria-hidden="true">👑</span>
    <div class="champ">${esc(champ)}</div><p class="sub">${esc(sub)}</p>`;
  banner.hidden = false;
  replay(banner, 'show');
  $('waiting').hidden = true;
  $('suspense').hidden = true;
  $('result-cards').innerHTML = '';
  $('next-order').hidden = true;
  renderBoard(false, true);
  $('next').textContent = 'Play again';
  $('next').disabled = false;
  window.scrollTo({ top: 0 });
  setTimeout(() => { confetti(1.6); fanfare(true); }, 200);
  setTimeout(() => confetti(1), 1300);
}
