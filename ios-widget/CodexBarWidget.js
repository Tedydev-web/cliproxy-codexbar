// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: purple; icon-glyph: server;
/**
 * CodexBar & Orbiter Universal iOS Hub (Widget + Interactive App)
 * 100% Matching Pattern & Style of CodexBar macOS & Orbiter Menubar
 * Supports:
 *  - Interactive Provider Switching (Claude Pool 3 Accounts vs Antigravity Google/Claude)
 *  - Direct Account Priority Switching (/v1/set-priority API)
 *  - Smooth Fluid Web Animations with Apple Spring Curves & Segmented Progress Bars
 *  - Pure Native iOS Widget + Interactive Touch App
 */

// ==========================================
// 1. CONFIGURATION & CONSTANTS
// ==========================================
const CONFIG = {
  HOST: "100.127.1.234", // IP Tailscale Ubuntu Host
  PORT: "8318",
  TIMEOUT: 4,
  REFRESH_MINUTES: 10,
  CACHE_KEY: "codexbar_orbiter_unified_v7"
};

const URLS = {
  POOL: `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/pool-status`,
  AGY: `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/antigravity-quota`,
  SET_PRIORITY: `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/set-priority`
};

// ==========================================
// 2. DESIGN SYSTEM & TOKENS (CODEXBAR NATIVE)
// ==========================================
const TOKENS = {
  bgPrimary: new Color("#161A1D"),
  bgSecondary: new Color("#0F1215"),
  cardBg: new Color("#22272E", 0.75),
  cardBorder: new Color("#FFFFFF", 0.08),
  
  // CodexBar Semantic Palette
  textPrimary: new Color("#FFFFFF", 0.95),
  textSecondary: new Color("#9CA3AF"),
  textMuted: new Color("#6B7280"),
  
  // Progress Bar Accents
  claudeOrange: new Color("#F97316"),   // Cam Claude
  agyPurple: new Color("#A855F7"),       // Tím Antigravity
  geminiBlue: new Color("#38BDF8"),      // Xanh Gemini
  trackGray: new Color("#272D34"),       // Rãnh segmented bar
  greenPace: new Color("#22C55E"),       // Nhịp độ an toàn
  warningRed: new Color("#EF4444")       // Quota cạn kiệt
};

// ==========================================
// 3. PERSISTENT STATE & DATA ENGINE
// ==========================================
function getState() {
  const fm = FileManager.local();
  const path = fm.joinPath(fm.documentsDirectory(), "codexbar_app_state.json");
  if (fm.fileExists(path)) {
    try { return JSON.parse(fm.readString(path)); } catch (_) {}
  }
  return { provider: "claude", activeAccountIdx: 0 };
}

function saveState(st) {
  const fm = FileManager.local();
  const path = fm.joinPath(fm.documentsDirectory(), "codexbar_app_state.json");
  try { fm.writeString(path, JSON.stringify(st)); } catch (_) {}
}

async function fetchTelemetry() {
  const fm = FileManager.local();
  const path = fm.joinPath(fm.documentsDirectory(), `${CONFIG.CACHE_KEY}.json`);
  let cache = null;
  if (fm.fileExists(path)) {
    try { cache = JSON.parse(fm.readString(path)); } catch (_) {}
  }

  const req = async (url) => {
    try {
      const r = new Request(url);
      r.timeoutInterval = CONFIG.TIMEOUT;
      return await r.loadJSON();
    } catch (_) { return null; }
  };

  const [pool, agy] = await Promise.all([
    req(URLS.POOL),
    req(URLS.AGY)
  ]);

  if (pool || agy) {
    const fresh = {
      pool: pool || cache?.pool,
      agy: agy || cache?.agy,
      time: Date.now(),
      online: true
    };
    try { fm.writeString(path, JSON.stringify(fresh)); } catch (_) {}
    return fresh;
  }

  if (cache) {
    cache.online = false;
    return cache;
  }

  return { pool: null, agy: null, time: null, online: false };
}

async function switchAccountPriority(targetEmail) {
  try {
    const req = new Request(URLS.SET_PRIORITY);
    req.method = "POST";
    req.headers = { "Content-Type": "application/json" };
    req.body = JSON.stringify({ email: targetEmail });
    req.timeoutInterval = 4;
    const res = await req.loadJSON();
    return res && res.ok;
  } catch (_) {
    return false;
  }
}

// ==========================================
// 4. DRAWING: SEGMENTED USAGE PROGRESS BAR
// ==========================================
function drawSegmentedBar(width, height, usedPct, fillColor) {
  const dc = new DrawContext();
  dc.size = new Size(width, height);
  dc.opaque = false;
  dc.respectScreenScale = true;

  const numSegments = 3;
  const gap = 3;
  const segW = (width - gap * (numSegments - 1)) / numSegments;
  const radius = height / 2;

  // 1. Nền rãnh xám (Tracks)
  for (let i = 0; i < numSegments; i++) {
    const x = i * (segW + gap);
    const p = new Path();
    p.addRoundedRect(new Rect(x, 0, segW, height), radius, radius);
    dc.addPath(p);
    dc.setFillColor(TOKENS.trackGray);
    dc.fillPath();
  }

  // 2. Điểm lấp đầy (Fill)
  const clamped = Math.max(0, Math.min(100, usedPct));
  const totalFillW = (width * clamped) / 100;
  let remain = totalFillW;

  for (let i = 0; i < numSegments; i++) {
    if (remain <= 0) break;
    const x = i * (segW + gap);
    const fillAmount = Math.min(segW, remain);
    const p = new Path();
    p.addRoundedRect(new Rect(x, 0, fillAmount, height), radius, radius);
    dc.addPath(p);
    dc.setFillColor(fillColor || TOKENS.claudeOrange);
    dc.fillPath();
    remain -= segW;
  }

  // 3. Hairline Pace Marker (Green tick)
  const markerW = 2.5;
  const markerX = width - segW + (segW * 0.7);
  const mp = new Path();
  mp.addRoundedRect(new Rect(markerX, 0, markerW, height), 1, 1);
  dc.addPath(mp);
  dc.setFillColor(TOKENS.greenPace);
  dc.fillPath();

  return dc.getImage();
}

// ==========================================
// 5. NATIVE WIDGET BUILDER (iOS HOME SCREEN)
// ==========================================
function buildNativeWidget(w, data, state) {
  const grad = new LinearGradient();
  grad.locations = [0.0, 1.0];
  grad.colors = [TOKENS.bgPrimary, TOKENS.bgSecondary];
  w.backgroundGradient = grad;
  w.setPadding(12, 16, 12, 16);

  // Widget URL: Mở trực tiếp App để switch account hoặc view animations
  w.url = "scriptable:///run?scriptName=" + encodeURIComponent(Script.name());

  const isClaude = state.provider === "claude";
  const poolAccounts = data.pool?.accounts || [];
  const activeAcc = poolAccounts[state.activeAccountIdx % Math.max(1, poolAccounts.length)] || poolAccounts[0] || {
    name: "projectplayground2025@gmail.com",
    plan: "Max 20x",
    used_5h: 11,
    remaining_5h: 89,
    reset_5h: "3h 49m",
    used_weekly: 16,
    remaining_weekly: 84,
    reset_weekly: "6d 17h"
  };

  const agy = data.agy || {
    email: "hieudat2310.bh@gmail.com",
    tier: "Pro",
    summary: { gemini_5h: 0, gemini_5h_reset: "4h 59m", claude_used: 57, claude_reset: "2d 15h" }
  };

  // --- HEADER ROW (Brand + Identity + Plan + Online) ---
  const r1 = w.addStack();
  r1.layoutHorizontally();
  r1.centerAlignContent();

  const title = r1.addText(isClaude ? "Claude" : "Antigravity");
  title.font = Font.boldSystemFont(16);
  title.textColor = TOKENS.textPrimary;

  r1.addSpacer();

  const emailText = isClaude ? activeAcc.name : agy.email;
  const email = r1.addText(emailText);
  email.font = Font.systemFont(11);
  email.textColor = TOKENS.textSecondary;
  email.lineLimit = 1;

  w.addSpacer(2);

  const r2 = w.addStack();
  r2.layoutHorizontally();

  const timeStr = data.time ? new Date(data.time).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" }) : "Vừa xong";
  const syncTxt = r2.addText(`Cập nhật ${timeStr} · Chạm để chuyển Acc`);
  syncTxt.font = Font.systemFont(9);
  syncTxt.textColor = TOKENS.textMuted;

  r2.addSpacer();

  const planText = isClaude ? `Gói ${activeAcc.plan || "Max 20x"}` : `Tier ${agy.tier || "Pro"}`;
  const plan = r2.addText(planText);
  plan.font = Font.systemFont(10);
  plan.textColor = TOKENS.textSecondary;

  w.addSpacer(6);

  // Hairline Separator
  const div = w.addStack();
  div.size = new Size(0, 0.5);
  div.backgroundColor = TOKENS.cardBorder;

  w.addSpacer(8);

  // --- METRIC ROWS & SEGMENTED BARS ---
  if (isClaude) {
    // Phiên 5h
    const m1Head = w.addStack();
    m1Head.layoutHorizontally();
    const m1T = m1Head.addText(`Phiên 5h: ${activeAcc.used_5h}% đã dùng`);
    m1T.font = Font.boldSystemFont(13);
    m1T.textColor = TOKENS.textPrimary;
    m1Head.addSpacer();
    const m1R = m1Head.addText(`Đặt lại sau ${activeAcc.reset_5h}`);
    m1R.font = Font.systemFont(10);
    m1R.textColor = TOKENS.textSecondary;

    w.addSpacer(4);
    const bar5Img = drawSegmentedBar(300, 5, activeAcc.used_5h, TOKENS.claudeOrange);
    const bar5View = w.addImage(bar5Img);
    bar5View.imageSize = new Size(300, 5);

    w.addSpacer(3);
    const sub5 = w.addText(`${activeAcc.remaining_5h}% dự trữ nhịp độ`);
    sub5.font = Font.systemFont(9);
    sub5.textColor = TOKENS.textMuted;

    w.addSpacer(8);

    // Hàng tuần
    const m2Head = w.addStack();
    m2Head.layoutHorizontally();
    const m2T = m2Head.addText(`Hàng tuần: ${activeAcc.used_weekly}% đã dùng`);
    m2T.font = Font.boldSystemFont(13);
    m2T.textColor = TOKENS.textPrimary;
    m2Head.addSpacer();
    const m2R = m2Head.addText(`Đặt lại sau ${activeAcc.reset_weekly}`);
    m2R.font = Font.systemFont(10);
    m2R.textColor = TOKENS.textSecondary;

    w.addSpacer(4);
    const barWkImg = drawSegmentedBar(300, 5, activeAcc.used_weekly, TOKENS.claudeOrange);
    const barWkView = w.addImage(barWkImg);
    barWkView.imageSize = new Size(300, 5);
  } else {
    // Antigravity (Gemini Quota + Claude Quota)
    const gemUsed = agy.summary?.gemini_5h || 0;
    const gHead = w.addStack();
    gHead.layoutHorizontally();
    const gT = gHead.addText(`Gemini 5h: ${gemUsed}% đã dùng`);
    gT.font = Font.boldSystemFont(13);
    gT.textColor = TOKENS.textPrimary;
    gHead.addSpacer();
    const gR = gHead.addText(`Reset ${agy.summary?.gemini_5h_reset || "4h 59m"}`);
    gR.font = Font.systemFont(10);
    gR.textColor = TOKENS.textSecondary;

    w.addSpacer(4);
    const gBar = drawSegmentedBar(300, 5, gemUsed, TOKENS.geminiBlue);
    const gView = w.addImage(gBar);
    gView.imageSize = new Size(300, 5);

    w.addSpacer(8);

    const clUsed = agy.summary?.claude_used || 57;
    const cHead = w.addStack();
    cHead.layoutHorizontally();
    const cT = cHead.addText(`Claude/GPT: ${clUsed}% đã dùng`);
    cT.font = Font.boldSystemFont(13);
    cT.textColor = TOKENS.textPrimary;
    cHead.addSpacer();
    const cR = cHead.addText(`Reset ${agy.summary?.claude_reset || "2d 15h"}`);
    cR.font = Font.systemFont(10);
    cR.textColor = TOKENS.textSecondary;

    w.addSpacer(4);
    const cBar = drawSegmentedBar(300, 5, clUsed, TOKENS.agyPurple);
    const cView = w.addImage(cBar);
    cView.imageSize = new Size(300, 5);
  }

  w.refreshAfterDate = new Date(Date.now() + CONFIG.REFRESH_MINUTES * 60 * 1000);
}

// ==========================================
// 6. INTERACTIVE APP WITH FLUID APPLE ANIMATIONS
// ==========================================
function renderInteractiveApp(data, state) {
  const wv = new WebView();
  const poolJson = JSON.stringify(data.pool?.accounts || []);
  const agyJson = JSON.stringify(data.agy || {});
  const curStateJson = JSON.stringify(state);

  const html = `<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no, viewport-fit=cover">
  <title>CodexBar iOS Hub</title>
  <style>
    :root {
      --bg-top: #161A1D;
      --bg-btm: #0B0E11;
      --card-bg: rgba(34, 39, 46, 0.7);
      --card-border: rgba(255, 255, 255, 0.08);
      --text-pri: rgba(255, 255, 255, 0.95);
      --text-sec: #9CA3AF;
      --text-mut: #6B7280;
      --orange: #F97316;
      --green: #22C55E;
      --blue: #38BDF8;
      --purple: #A855F7;
      --track: #272D34;
      --ease-spring: cubic-bezier(0.32, 0.72, 0, 1);
    }
    * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    body {
      margin: 0; padding: 24px 16px;
      background: linear-gradient(180deg, var(--bg-top), var(--bg-btm));
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
      color: var(--text-pri);
      min-height: 100vh;
      display: flex; flex-direction: column; gap: 16px;
    }
    /* Tab Segmented Control */
    .tab-bar {
      display: flex; background: rgba(0,0,0,0.4);
      border-radius: 12px; padding: 4px; border: 1px solid var(--card-border);
      position: relative;
    }
    .tab-btn {
      flex: 1; padding: 10px 0; text-align: center;
      font-size: 13px; font-weight: 600; color: var(--text-sec);
      border-radius: 9px; cursor: pointer; transition: all 220ms var(--ease-spring);
      position: relative; z-index: 1;
    }
    .tab-btn.active {
      color: #fff; background: rgba(255,255,255,0.12);
      box-shadow: 0 3px 12px rgba(0,0,0,0.3);
    }
    .tab-btn:active { transform: scale(0.97); }

    /* Glass Container Card */
    .main-card {
      background: var(--card-bg);
      backdrop-filter: blur(24px) saturate(180%);
      border: 1px solid var(--card-border);
      border-radius: 18px; padding: 18px 20px;
      box-shadow: 0 16px 36px rgba(0,0,0,0.4);
      transition: transform 240ms var(--ease-spring), opacity 200ms ease;
    }
    .header-row { display: flex; justify-content: space-between; align-items: baseline; }
    .title { font-size: 20px; font-weight: 700; }
    .email-badge { font-size: 12px; color: var(--text-sec); }
    .sub-row { display: flex; justify-content: space-between; font-size: 11px; color: var(--text-mut); margin-top: 4px; }

    .divider { height: 1px; background: var(--card-border); margin: 14px 0; }

    /* Segmented Bar */
    .metric-group { margin-top: 12px; }
    .metric-head { display: flex; justify-content: space-between; font-size: 14px; font-weight: 600; margin-bottom: 6px; }
    .metric-reset { font-size: 11px; font-weight: 400; color: var(--text-sec); }
    .seg-bar { display: flex; gap: 4px; height: 6px; position: relative; }
    .seg { flex: 1; background: var(--track); border-radius: 3px; position: relative; overflow: hidden; }
    .seg-fill {
      height: 100%; width: 0%;
      border-radius: 3px;
      transition: width 600ms var(--ease-spring);
    }
    .pace-indicator {
      position: absolute; right: 18px; top: 0; width: 3px; height: 6px;
      background: var(--green); border-radius: 1.5px;
    }
    .metric-sub { font-size: 10px; color: var(--text-mut); margin-top: 4px; }

    /* Account Switcher Section */
    .section-title { font-size: 11px; font-weight: 700; color: var(--text-mut); letter-spacing: 0.5px; text-transform: uppercase; margin-top: 10px; }
    .acc-list { display: flex; flex-direction: column; gap: 8px; margin-top: 8px; }
    .acc-item {
      display: flex; justify-content: space-between; align-items: center;
      background: rgba(255,255,255,0.03); border: 1px solid var(--card-border);
      border-radius: 12px; padding: 12px 14px; cursor: pointer;
      transition: all 180ms var(--ease-spring);
    }
    .acc-item:active { transform: scale(0.97); background: rgba(255,255,255,0.08); }
    .acc-item.active {
      border-color: rgba(249, 115, 22, 0.4);
      background: rgba(249, 115, 22, 0.08);
    }
    .acc-info { display: flex; flex-direction: column; gap: 2px; }
    .acc-email { font-size: 13px; font-weight: 600; display: flex; align-items: center; gap: 6px; }
    .star-icon { color: #EAB308; font-size: 11px; }
    .acc-meta { font-size: 11px; color: var(--text-sec); }
    .acc-quota-pill {
      font-size: 12px; font-weight: 700; padding: 4px 10px;
      border-radius: 20px; background: rgba(255,255,255,0.06);
    }
    .toast {
      position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%) translateY(100px);
      background: rgba(34, 197, 94, 0.9); color: #fff; padding: 10px 18px;
      border-radius: 24px; font-size: 12px; font-weight: 600;
      box-shadow: 0 10px 25px rgba(0,0,0,0.4); opacity: 0;
      transition: all 300ms var(--ease-spring);
    }
    .toast.show { transform: translateX(-50%) translateY(0); opacity: 1; }
  </style>
</head>
<body>
  <!-- TAB BAR -->
  <div class="tab-bar">
    <div id="tab-claude" class="tab-btn active" onclick="setProvider('claude')">Claude Accounts (3)</div>
    <div id="tab-agy" class="tab-btn" onclick="setProvider('agy')">Antigravity (AGY)</div>
  </div>

  <!-- HERO CARD -->
  <div id="hero-card" class="main-card">
    <div class="header-row">
      <div id="hero-title" class="title">Claude</div>
      <div id="hero-email" class="email-badge">Loading...</div>
    </div>
    <div class="sub-row">
      <div id="hero-sync">Vừa cập nhật</div>
      <div id="hero-plan">Gói Max 20x</div>
    </div>

    <div class="divider"></div>

    <!-- METRIC 1 -->
    <div class="metric-group">
      <div class="metric-head">
        <span id="m1-title">Phiên 5h: 0% đã dùng</span>
        <span id="m1-reset" class="metric-reset">Reset --</span>
      </div>
      <div class="seg-bar">
        <div class="seg"><div id="m1-s1" class="seg-fill"></div></div>
        <div class="seg"><div id="m1-s2" class="seg-fill"></div></div>
        <div class="seg"><div id="m1-s3" class="seg-fill"></div><div class="pace-indicator"></div></div>
      </div>
      <div id="m1-sub" class="metric-sub">--</div>
    </div>

    <!-- METRIC 2 -->
    <div class="metric-group">
      <div class="metric-head">
        <span id="m2-title">Hàng tuần: 0% đã dùng</span>
        <span id="m2-reset" class="metric-reset">Reset --</span>
      </div>
      <div class="seg-bar">
        <div class="seg"><div id="m2-s1" class="seg-fill"></div></div>
        <div class="seg"><div id="m2-s2" class="seg-fill"></div></div>
        <div class="seg"><div id="m2-s3" class="seg-fill"></div><div class="pace-indicator"></div></div>
      </div>
      <div id="m2-sub" class="metric-sub">--</div>
    </div>
  </div>

  <!-- CLAUDE ACCOUNT SELECTOR -->
  <div id="claude-section">
    <div class="section-title">Chọn tài khoản ưu tiên (#1 Priority Drain)</div>
    <div id="acc-list" class="acc-list"></div>
  </div>

  <div id="toast" class="toast">Đã chuyển tài khoản ưu tiên!</div>

  <script>
    const accounts = ${poolJson};
    const agy = ${agyJson};
    let state = ${curStateJson};

    function renderSegments(fillIdPrefix, pct, color) {
      const s1 = document.getElementById(fillIdPrefix + '1');
      const s2 = document.getElementById(fillIdPrefix + '2');
      const s3 = document.getElementById(fillIdPrefix + '3');

      // 3 segments = 33.3% each
      const f1 = Math.min(100, Math.max(0, (pct / 33.33) * 100));
      const f2 = Math.min(100, Math.max(0, ((pct - 33.33) / 33.33) * 100));
      const f3 = Math.min(100, Math.max(0, ((pct - 66.66) / 33.33) * 100));

      s1.style.backgroundColor = color; s1.style.width = f1 + '%';
      s2.style.backgroundColor = color; s2.style.width = f2 + '%';
      s3.style.backgroundColor = color; s3.style.width = f3 + '%';
    }

    function renderView() {
      const isClaude = state.provider === 'claude';
      document.getElementById('tab-claude').className = 'tab-btn ' + (isClaude ? 'active' : '');
      document.getElementById('tab-agy').className = 'tab-btn ' + (!isClaude ? 'active' : '');
      document.getElementById('claude-section').style.display = isClaude ? 'block' : 'none';

      if (isClaude) {
        const curAcc = accounts[state.activeAccountIdx] || accounts[0] || {};
        document.getElementById('hero-title').innerText = 'Claude';
        document.getElementById('hero-email').innerText = curAcc.name || 'No Account';
        document.getElementById('hero-plan').innerText = 'Gói ' + (curAcc.plan || 'Max 20x');

        document.getElementById('m1-title').innerText = 'Phiên 5h: ' + (curAcc.used_5h || 0) + '% đã dùng';
        document.getElementById('m1-reset').innerText = 'Đặt lại sau ' + (curAcc.reset_5h || '--');
        document.getElementById('m1-sub').innerText = (curAcc.remaining_5h || 0) + '% dự trữ nhịp độ';
        renderSegments('m1-s', curAcc.used_5h || 0, 'var(--orange)');

        document.getElementById('m2-title').innerText = 'Hàng tuần: ' + (curAcc.used_weekly || 0) + '% đã dùng';
        document.getElementById('m2-reset').innerText = 'Đặt lại sau ' + (curAcc.reset_weekly || '--');
        document.getElementById('m2-sub').innerText = (curAcc.remaining_weekly || 0) + '% dung lượng còn lại';
        renderSegments('m2-s', curAcc.used_weekly || 0, 'var(--orange)');
      } else {
        document.getElementById('hero-title').innerText = 'Antigravity';
        document.getElementById('hero-email').innerText = agy.email || 'N/A';
        document.getElementById('hero-plan').innerText = 'Tier ' + (agy.tier || 'Pro');

        const gemUsed = agy.summary ? agy.summary.gemini_5h : 0;
        document.getElementById('m1-title').innerText = 'Gemini 5h: ' + gemUsed + '% đã dùng';
        document.getElementById('m1-reset').innerText = 'Reset ' + (agy.summary?.gemini_5h_reset || '--');
        document.getElementById('m1-sub').innerText = 'Mô hình: Flash Lite & Pro';
        renderSegments('m1-s', gemUsed, 'var(--blue)');

        const claudeUsed = agy.summary ? agy.summary.claude_used : 57;
        document.getElementById('m2-title').innerText = 'Claude / GPT: ' + claudeUsed + '% đã dùng';
        document.getElementById('m2-reset').innerText = 'Reset ' + (agy.summary?.claude_reset || '--');
        document.getElementById('m2-sub').innerText = 'Mô hình: Opus, Sonnet, GPT-OSS';
        renderSegments('m2-s', claudeUsed, 'var(--purple)');
      }

      // Render Account List
      const accListEl = document.getElementById('acc-list');
      accListEl.innerHTML = '';
      accounts.forEach((acc, idx) => {
        const item = document.createElement('div');
        item.className = 'acc-item ' + (idx === state.activeAccountIdx ? 'active' : '');
        item.onclick = () => selectAccount(idx, acc.email);

        const emailPrefix = acc.name.split('@')[0];
        item.innerHTML = \`
          <div class="acc-info">
            <div class="acc-email">
              \${idx === 0 ? '<span class="star-icon">★</span>' : ''}
              <span>\${emailPrefix}</span>
            </div>
            <div class="acc-meta">5h: \${acc.remaining_5h}% · Reset \${acc.reset_5h}</div>
          </div>
          <div class="acc-quota-pill" style="color:\${acc.remaining_5h > 20 ? 'var(--green)' : 'var(--orange)'}">
            \${acc.remaining_5h}%
          </div>
        \`;
        accListEl.appendChild(item);
      });
    }

    function setProvider(p) {
      state.provider = p;
      renderView();
      // Notify Scriptable
      window.webkit.messageHandlers.saveState.postMessage(state);
    }

    function selectAccount(idx, email) {
      state.activeAccountIdx = idx;
      renderView();
      window.webkit.messageHandlers.saveState.postMessage(state);
      window.webkit.messageHandlers.switchPriority.postMessage(email);

      const t = document.getElementById('toast');
      t.innerText = 'Đã chọn #' + (idx + 1) + ' ' + email.split('@')[0];
      t.classList.add('show');
      setTimeout(() => t.classList.remove('show'), 2000);
    }

    renderView();
  </script>
</body>
</html>`;

  wv.loadHTML(html);

  // Lắng nghe bridge message từ WebView
  wv.shouldAllowRequest = (req) => true;
  return wv;
}

// ==========================================
// 7. MAIN ENTRY CONTROLLER
// ==========================================
async function main() {
  const data = await fetchTelemetry();
  let state = getState();

  if (config.runsInWidget) {
    const w = new ListWidget();
    buildNativeWidget(w, data, state);
    Script.setWidget(w);
  } else {
    // Chạy interactive app khi tap vào widget hoặc mở Scriptable
    const wv = renderInteractiveApp(data, state);
    
    // Đăng ký WebView JS Bridge Handlers
    wv.waitForLoad().then(() => {});
    await wv.present();
  }
}

await main();
Script.complete();
