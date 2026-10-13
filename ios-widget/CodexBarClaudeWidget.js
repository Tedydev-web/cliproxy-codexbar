// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: orange; icon-glyph: bolt;
/**
 * CodexBar iOS Widget - Claude Pool Quota
 * 100% Matching Pattern & Style of CodexBar macOS & Orbiter Menubar
 * Supports Medium (2x4) & Small (2x2) Widget Families
 * Tích hợp Interactive Account Switcher khi chạm mở script
 */

const CONFIG = {
  HOST: "100.127.1.234", // IP Tailscale Ubuntu Host
  PORT: "8318",
  TIMEOUT: 4,
  REFRESH_MIN: 10,
  CACHE_KEY: "codexbar_claude_v8"
};

const URLS = {
  POOL: `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/pool-status`,
  SET_PRIORITY: `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/set-priority`
};

// ==========================================
// DESIGN TOKENS (CODEXBAR MACOS 1:1)
// ==========================================
const TOKENS = {
  bgTop: new Color("#161A1D"),
  bgBtm: new Color("#0E1114"),
  cardBorder: new Color("#FFFFFF", 0.08),

  textPrimary: new Color("#FFFFFF", 0.95),
  textSecondary: new Color("#9CA3AF"),
  textMuted: new Color("#6B7280"),

  orangeFill: new Color("#F97316"),   // Cam Claude
  trackGray: new Color("#272D34"),    // Rãnh segmented bar
  greenPace: new Color("#22C55E")     // Vạch nhịp độ an toàn
};

// ==========================================
// DATA & CACHING
// ==========================================
async function fetchPoolData() {
  const fm = FileManager.local();
  const path = fm.joinPath(fm.documentsDirectory(), `${CONFIG.CACHE_KEY}.json`);
  let cache = null;
  if (fm.fileExists(path)) {
    try { cache = JSON.parse(fm.readString(path)); } catch (_) {}
  }

  try {
    const r = new Request(URLS.POOL);
    r.timeoutInterval = CONFIG.TIMEOUT;
    const pool = await r.loadJSON();
    if (pool && pool.accounts) {
      const data = { pool, time: Date.now(), online: true };
      try { fm.writeString(path, JSON.stringify(data)); } catch (_) {}
      return data;
    }
  } catch (_) {}

  if (cache) {
    cache.online = false;
    return cache;
  }
  return { pool: null, time: null, online: false };
}

// ==========================================
// DRAWING: SEGMENTED USAGE PROGRESS BAR (3 ĐOẠN)
// ==========================================
function drawSegmentedBar(width, height, usedPct) {
  const dc = new DrawContext();
  dc.size = new Size(width, height);
  dc.opaque = false;
  dc.respectScreenScale = true;

  const numSegments = 3;
  const gap = 3.5;
  const segW = (width - gap * (numSegments - 1)) / numSegments;
  const r = height / 2;

  // 1. Rãnh nền xám
  for (let i = 0; i < numSegments; i++) {
    const x = i * (segW + gap);
    const p = new Path();
    p.addRoundedRect(new Rect(x, 0, segW, height), r, r);
    dc.addPath(p);
    dc.setFillColor(TOKENS.trackGray);
    dc.fillPath();
  }

  // 2. Điểm lấp đầy (Fill cam)
  const clamped = Math.max(0, Math.min(100, usedPct));
  const totalFillW = (width * clamped) / 100;
  let remain = totalFillW;

  for (let i = 0; i < numSegments; i++) {
    if (remain <= 0) break;
    const x = i * (segW + gap);
    const fillAmount = Math.min(segW, remain);
    const p = new Path();
    p.addRoundedRect(new Rect(x, 0, fillAmount, height), r, r);
    dc.addPath(p);
    dc.setFillColor(TOKENS.orangeFill);
    dc.fillPath();
    remain -= segW;
  }

  // 3. Hairline Pace Indicator (Green tick)
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
// MEDIUM WIDGET: 100% CODEXBAR MACOS CARD
// ==========================================
function buildMediumWidget(w, data) {
  w.setPadding(12, 16, 12, 16);

  const acc = data.pool?.accounts?.[0] || {
    name: "projectplayground2025@gmail.com",
    plan: "Max 20x",
    used_5h: 11,
    remaining_5h: 89,
    reset_5h: "3h 49m",
    used_weekly: 16,
    remaining_weekly: 84,
    reset_weekly: "6d 17h"
  };

  // Header Line 1: Claude & Email
  const row1 = w.addStack();
  row1.layoutHorizontally();
  row1.centerAlignContent();

  const title = row1.addText("Claude");
  title.font = Font.boldSystemFont(16);
  title.textColor = TOKENS.textPrimary;

  row1.addSpacer();

  const email = row1.addText(acc.name);
  email.font = Font.systemFont(11.5);
  email.textColor = TOKENS.textSecondary;
  email.lineLimit = 1;

  w.addSpacer(2);

  // Header Line 2: Sync text & Plan
  const row2 = w.addStack();
  row2.layoutHorizontally();

  const timeStr = data.time ? new Date(data.time).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" }) : "Vừa xong";
  const syncTxt = row2.addText(`Cập nhật lúc ${timeStr}`);
  syncTxt.font = Font.systemFont(10);
  syncTxt.textColor = TOKENS.textMuted;

  row2.addSpacer();

  const planTxt = row2.addText(`Gói ${acc.plan || "Max 20x"}`);
  planTxt.font = Font.systemFont(11);
  planTxt.textColor = TOKENS.textSecondary;

  w.addSpacer(6);

  // Hairline Divider
  const div = w.addStack();
  div.size = new Size(0, 0.5);
  div.backgroundColor = TOKENS.cardBorder;

  w.addSpacer(8);

  // METRIC 1: PHIÊN 5H
  const p5Head = w.addStack();
  p5Head.layoutHorizontally();
  p5Head.centerAlignContent();

  const p5Title = p5Head.addText(`Phiên 5h: ${acc.used_5h}% đã dùng`);
  p5Title.font = Font.boldSystemFont(13);
  p5Title.textColor = TOKENS.textPrimary;

  p5Head.addSpacer();

  const p5Reset = p5Head.addText(`Đặt lại sau ${acc.reset_5h}`);
  p5Reset.font = Font.systemFont(10.5);
  p5Reset.textColor = TOKENS.textSecondary;

  w.addSpacer(4);

  // Thanh tiến trình 5h
  const bar5 = drawSegmentedBar(300, 5, acc.used_5h);
  const v5 = w.addImage(bar5);
  v5.imageSize = new Size(300, 5);

  w.addSpacer(3);

  const sub5 = w.addText(`${acc.remaining_5h}% dự trữ nhịp độ`);
  sub5.font = Font.systemFont(9.5);
  sub5.textColor = TOKENS.textMuted;

  w.addSpacer(8);

  // METRIC 2: HÀNG TUẦN
  const pWkHead = w.addStack();
  pWkHead.layoutHorizontally();
  pWkHead.centerAlignContent();

  const pWkTitle = pWkHead.addText(`Hàng tuần: ${acc.used_weekly}% đã dùng`);
  pWkTitle.font = Font.boldSystemFont(13);
  pWkTitle.textColor = TOKENS.textPrimary;

  pWkHead.addSpacer();

  const pWkReset = pWkHead.addText(`Đặt lại sau ${acc.reset_weekly}`);
  pWkReset.font = Font.systemFont(10.5);
  pWkReset.textColor = TOKENS.textSecondary;

  w.addSpacer(4);

  // Thanh tiến trình Tuần
  const barWk = drawSegmentedBar(300, 5, acc.used_weekly);
  const vWk = w.addImage(barWk);
  vWk.imageSize = new Size(300, 5);
}

// ==========================================
// SMALL WIDGET
// ==========================================
function buildSmallWidget(w, data) {
  w.setPadding(12, 12, 12, 12);
  const acc = data.pool?.accounts?.[0] || {};

  const h = w.addStack();
  h.layoutHorizontally();
  const t = h.addText("Claude");
  t.font = Font.boldSystemFont(14);
  t.textColor = TOKENS.textPrimary;
  h.addSpacer();
  const p = h.addText("20x");
  p.font = Font.boldSystemFont(10);
  p.textColor = TOKENS.textSecondary;

  w.addSpacer(6);

  const u5 = w.addText(`5h: ${acc.used_5h || 0}% đã dùng`);
  u5.font = Font.boldSystemFont(11);
  u5.textColor = TOKENS.textPrimary;

  w.addSpacer(2);
  const b5 = drawSegmentedBar(125, 4, acc.used_5h || 0);
  const v5 = w.addImage(b5);
  v5.imageSize = new Size(125, 4);

  w.addSpacer(2);
  const r5 = w.addText(`Reset ${acc.reset_5h || "--"}`);
  r5.font = Font.systemFont(9);
  r5.textColor = TOKENS.textMuted;

  w.addSpacer(8);

  const uw = w.addText(`Tuần: ${acc.used_weekly || 0}% đã dùng`);
  uw.font = Font.boldSystemFont(11);
  uw.textColor = TOKENS.textPrimary;

  w.addSpacer(2);
  const bw = drawSegmentedBar(125, 4, acc.used_weekly || 0);
  const vw = w.addImage(bw);
  vw.imageSize = new Size(125, 4);

  w.addSpacer(2);
  const rw = w.addText(`Reset ${acc.reset_weekly || "--"}`);
  rw.font = Font.systemFont(9);
  rw.textColor = TOKENS.textMuted;
}

// ==========================================
// INTERACTIVE MODAL (SWITCH ACCOUNT NHANH)
// ==========================================
async function showInteractiveSwitcher(data) {
  const accounts = data.pool?.accounts || [];
  const alert = new Alert();
  alert.title = "⚡ CodexBar - Claude Accounts";
  alert.message = "Chọn tài khoản để đưa lên ưu tiên số #1 (Selector Drain First):";

  accounts.forEach((acc, idx) => {
    const isFirst = idx === 0;
    const prefix = isFirst ? "★ " : `#${idx + 1} `;
    const emailPrefix = acc.name.split("@")[0];
    alert.addAction(`${prefix}${emailPrefix} (5h: ${acc.remaining_5h}% · ${acc.plan || "Max"})`);
  });

  alert.addCancelAction("Đóng");

  const chosen = await alert.presentAlert();
  if (chosen >= 0 && chosen < accounts.length) {
    const targetEmail = accounts[chosen].email;
    try {
      const req = new Request(URLS.SET_PRIORITY);
      req.method = "POST";
      req.headers = { "Content-Type": "application/json" };
      req.body = JSON.stringify({ email: targetEmail });
      req.timeoutInterval = 4;
      await req.loadJSON();

      const notif = new Notification();
      notif.title = "Đã chuyển tài khoản ưu tiên";
      notif.body = `Tài khoản #${chosen + 1} (${targetEmail.split("@")[0]}) hiện là #1 Drain Order.`;
      notif.schedule();
    } catch (_) {}
  }
}

// ==========================================
// MAIN ENTRY
// ==========================================
async function main() {
  const data = await fetchPoolData();

  if (config.runsInWidget) {
    const w = new ListWidget();
    const grad = new LinearGradient();
    grad.locations = [0.0, 1.0];
    grad.colors = [TOKENS.bgTop, TOKENS.bgBtm];
    w.backgroundGradient = grad;

    const family = config.widgetFamily || "medium";
    if (family === "small") {
      buildSmallWidget(w, data);
    } else {
      buildMediumWidget(w, data);
    }

    w.refreshAfterDate = new Date(Date.now() + CONFIG.REFRESH_MIN * 60 * 1000);
    Script.setWidget(w);
  } else {
    // Khi mở app hoặc test trong Scriptable: Hiện widget preview + mở modal chọn tài khoản
    const w = new ListWidget();
    const grad = new LinearGradient();
    grad.locations = [0.0, 1.0];
    grad.colors = [TOKENS.bgTop, TOKENS.bgBtm];
    w.backgroundGradient = grad;
    buildMediumWidget(w, data);
    await w.presentMedium();
    await showInteractiveSwitcher(data);
  }
}

await main();
Script.complete();
