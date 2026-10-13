// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: purple; icon-glyph: brain;
/**
 * Orbiter iOS Widget - Antigravity (AGY) Quota
 * 100% Matching Pattern & Style of AntigravityFullCardView in Orbiter Menubar
 * Supports Medium (2x4) & Small (2x2) Widget Families
 * Full-width Segmented Progress Bars (Không bị hụt lề phải)
 * Tối ưu Pin & Hiệu năng: 5 phút refresh & On-demand caching
 */

const CONFIG = {
  HOST: "100.127.1.234", // IP Tailscale Ubuntu Host
  PORT: "8318",
  TIMEOUT: 4,
  REFRESH_MIN: 5,
  CACHE_KEY: "orbiter_agy_v9"
};

const URLS = {
  AGY: `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/antigravity-quota`
};

// ==========================================
// DESIGN TOKENS (ANTIGRAVITY MENUBAR 1:1)
// ==========================================
const TOKENS = {
  bgTop: new Color("#161A1D"),
  bgBtm: new Color("#0E1114"),
  cardBorder: new Color("#FFFFFF", 0.08),

  textPrimary: new Color("#FFFFFF", 0.95),
  textSecondary: new Color("#9CA3AF"),
  textMuted: new Color("#6B7280"),

  geminiTeal: new Color("#00C389"),    // Teal Green của Gemini
  claudePurple: new Color("#8B5CF6"),  // Purple của Claude/GPT Models
  trackGray: new Color("#272D34"),     // Rãnh segmented bar
  greenPace: new Color("#22C55E")      // Vạch nhịp độ an toàn
};

// ==========================================
// DATA & CACHING
// ==========================================
async function fetchAgyData() {
  const fm = FileManager.local();
  const path = fm.joinPath(fm.documentsDirectory(), `${CONFIG.CACHE_KEY}.json`);
  let cache = null;
  if (fm.fileExists(path)) {
    try { cache = JSON.parse(fm.readString(path)); } catch (_) {}
  }

  try {
    const r = new Request(URLS.AGY);
    r.timeoutInterval = CONFIG.TIMEOUT;
    const agy = await r.loadJSON();
    if (agy && agy.email) {
      const data = { agy, time: Date.now(), online: true };
      try { fm.writeString(path, JSON.stringify(data)); } catch (_) {}
      return data;
    }
  } catch (_) {}

  if (cache) {
    cache.online = false;
    return cache;
  }
  return { agy: null, time: null, online: false };
}

// ==========================================
// DRAWING: FULL-WIDTH SEGMENTED BAR (3 ĐOẠN)
// ==========================================
function drawSegmentedBar(width, height, usedPct, fillColor) {
  const dc = new DrawContext();
  dc.size = new Size(width, height);
  dc.opaque = false;
  dc.respectScreenScale = true;

  const numSegments = 3;
  const gap = 4;
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

  // 2. Điểm lấp đầy (Fill)
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
    dc.setFillColor(fillColor);
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
// MEDIUM WIDGET (FULL WIDTH 330PT)
// ==========================================
function buildMediumWidget(w, data) {
  w.setPadding(14, 14, 14, 14);

  const agy = data.agy || {
    email: "hieudat2310.bh@gmail.com",
    tier: "Pro",
    gemini: { five_hour_remaining: 100, five_hour_refresh: "4h 59m" },
    claude_gpt: { weekly_remaining: 43, weekly_refresh: "2d 15h" }
  };

  const gemUsed = 100 - (agy.gemini?.five_hour_remaining || 100);
  const gemReset = agy.gemini?.five_hour_refresh || "4h 59m";

  const claudeUsed = 100 - (agy.claude_gpt?.weekly_remaining || 43);
  const claudeReset = agy.claude_gpt?.weekly_refresh || "2d 15h";

  // Header Line 1: Antigravity & Email
  const row1 = w.addStack();
  row1.layoutHorizontally();
  row1.centerAlignContent();

  const title = row1.addText("Antigravity");
  title.font = Font.boldSystemFont(16);
  title.textColor = TOKENS.textPrimary;

  row1.addSpacer();

  const email = row1.addText(agy.email || "");
  email.font = Font.systemFont(12);
  email.textColor = TOKENS.textSecondary;
  email.lineLimit = 1;

  w.addSpacer(2);

  // Header Line 2: Sync text & Tier
  const row2 = w.addStack();
  row2.layoutHorizontally();

  const timeStr = data.time ? new Date(data.time).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" }) : "Vừa xong";
  const syncTxt = row2.addText(`Cập nhật lúc ${timeStr}`);
  syncTxt.font = Font.systemFont(10);
  syncTxt.textColor = TOKENS.textMuted;

  row2.addSpacer();

  const planTxt = row2.addText(`Gói ${agy.tier || "Pro"}`);
  planTxt.font = Font.systemFont(11);
  planTxt.textColor = TOKENS.textSecondary;

  w.addSpacer(6);

  // Hairline Divider
  const div = w.addStack();
  div.size = new Size(0, 0.5);
  div.backgroundColor = TOKENS.cardBorder;

  w.addSpacer(8);

  // GROUP 1: GEMINI MODELS (5H QUOTA)
  const gHead = w.addStack();
  gHead.layoutHorizontally();
  gHead.centerAlignContent();

  const gTitle = gHead.addText(`Gemini 5h: ${gemUsed}% đã dùng`);
  gTitle.font = Font.boldSystemFont(13);
  gTitle.textColor = TOKENS.textPrimary;

  gHead.addSpacer();

  const gReset = gHead.addText(`Đặt lại sau ${gemReset}`);
  gReset.font = Font.systemFont(11);
  gReset.textColor = TOKENS.textSecondary;

  w.addSpacer(4);

  // Thanh tiến trình Gemini (Full-width 330pt)
  const gBar = drawSegmentedBar(330, 5.5, gemUsed, TOKENS.geminiTeal);
  const gView = w.addImage(gBar);
  gView.imageSize = new Size(330, 5.5);

  w.addSpacer(3);

  const gSub = w.addText(`${100 - gemUsed}% nhịp độ Flash & Pro`);
  gSub.font = Font.systemFont(9.5);
  gSub.textColor = TOKENS.textMuted;

  w.addSpacer(8);

  // GROUP 2: CLAUDE & GPT MODELS (WEEKLY QUOTA)
  const cHead = w.addStack();
  cHead.layoutHorizontally();
  cHead.centerAlignContent();

  const cTitle = cHead.addText(`Claude/GPT: ${claudeUsed}% đã dùng`);
  cTitle.font = Font.boldSystemFont(13);
  cTitle.textColor = TOKENS.textPrimary;

  cHead.addSpacer();

  const cReset = cHead.addText(`Đặt lại sau ${claudeReset}`);
  cReset.font = Font.systemFont(11);
  cReset.textColor = TOKENS.textSecondary;

  w.addSpacer(4);

  // Thanh tiến trình Claude/GPT (Full-width 330pt)
  const cBar = drawSegmentedBar(330, 5.5, claudeUsed, TOKENS.claudePurple);
  const cView = w.addImage(cBar);
  cView.imageSize = new Size(330, 5.5);
}

// ==========================================
// SMALL WIDGET (2X2)
// ==========================================
function buildSmallWidget(w, data) {
  w.setPadding(12, 12, 12, 12);
  const agy = data.agy || {};
  const gemUsed = 100 - (agy.gemini?.five_hour_remaining || 100);
  const claudeUsed = 100 - (agy.claude_gpt?.weekly_remaining || 43);

  const h = w.addStack();
  h.layoutHorizontally();
  h.centerAlignContent();
  const t = h.addText("AGY");
  t.font = Font.boldSystemFont(14);
  t.textColor = TOKENS.textPrimary;
  h.addSpacer();
  const p = h.addText(agy.tier || "Pro");
  p.font = Font.boldSystemFont(10);
  p.textColor = TOKENS.textSecondary;

  w.addSpacer(6);

  // Gemini
  const gHead = w.addStack();
  gHead.layoutHorizontally();
  const uG = gHead.addText(`Gemini: ${gemUsed}% dùng`);
  uG.font = Font.boldSystemFont(11);
  uG.textColor = TOKENS.textPrimary;
  gHead.addSpacer();
  const rg = gHead.addText(agy.gemini?.five_hour_refresh || "");
  rg.font = Font.systemFont(9);
  rg.textColor = TOKENS.textMuted;

  w.addSpacer(3);
  const bg = drawSegmentedBar(132, 4.5, gemUsed, TOKENS.geminiTeal);
  const vg = w.addImage(bg);
  vg.imageSize = new Size(132, 4.5);

  w.addSpacer(8);

  // Claude
  const cHead = w.addStack();
  cHead.layoutHorizontally();
  const uC = cHead.addText(`Claude: ${claudeUsed}% dùng`);
  uC.font = Font.boldSystemFont(11);
  uC.textColor = TOKENS.textPrimary;
  cHead.addSpacer();
  const rc = cHead.addText(agy.claude_gpt?.weekly_refresh || "");
  rc.font = Font.systemFont(9);
  rc.textColor = TOKENS.textMuted;

  w.addSpacer(3);
  const bc = drawSegmentedBar(132, 4.5, claudeUsed, TOKENS.claudePurple);
  const vc = w.addImage(bc);
  vc.imageSize = new Size(132, 4.5);
}

// ==========================================
// MAIN ENTRY
// ==========================================
async function main() {
  const data = await fetchAgyData();
  const w = new ListWidget();
  const grad = new LinearGradient();
  grad.locations = [0.0, 1.0];
  grad.colors = [TOKENS.bgTop, TOKENS.bgBtm];
  w.backgroundGradient = grad;

  w.url = "scriptable:///run?scriptName=" + encodeURIComponent(Script.name());

  const family = config.widgetFamily || "medium";
  if (family === "small") {
    buildSmallWidget(w, data);
  } else {
    buildMediumWidget(w, data);
  }

  w.refreshAfterDate = new Date(Date.now() + CONFIG.REFRESH_MIN * 60 * 1000);

  if (config.runsInWidget) {
    Script.setWidget(w);
  } else {
    await w.presentMedium();
  }
}

await main();
Script.complete();
