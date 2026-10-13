// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: teal; icon-glyph: brain;
/**
 * Orbiter iOS Widget - Antigravity (AGY) Gemini Models Quota
 * 100% Matching Pattern & Style of AntigravityFullCardView (GEMINI MODELS) in Orbiter Menubar
 * Supports Medium (2x4) & Small (2x2) Widget Families
 * Full-width Segmented Progress Bars (Teal Green cho 5h & Amber Yellow cho Tuần)
 * Tối ưu Pin & Hiệu năng: 5 phút refresh & On-demand caching
 */

const CONFIG = {
  HOST: "100.127.1.234", // IP Tailscale Ubuntu Host
  PORT: "8318",
  TIMEOUT: 4,
  REFRESH_MIN: 2, // Chu kỳ refresh đề xuất cho iOS (2 phút)
  CACHE_KEY: "orbiter_agy_gemini_v10"
};

const URLS = {
  AGY: `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/antigravity-quota`
};

// ==========================================
// DESIGN TOKENS (ANTIGRAVITY MACOS 1:1)
// ==========================================
const TOKENS = {
  bgTop: new Color("#161A1D"),
  bgBtm: new Color("#0E1114"),
  cardBorder: new Color("#FFFFFF", 0.08),

  textPrimary: new Color("#FFFFFF", 0.95),
  textSecondary: new Color("#9CA3AF"),
  textMuted: new Color("#6B7280"),

  // Màu sắc chính xác từ OrbiterMenuBar.swift cho Gemini Models:
  geminiTeal: new Color("#00C389"),    // Teal Green (5h)
  geminiAmber: new Color("#F5C542"),   // Amber Yellow (Tuần)
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
function drawSegmentedBar(width, height, percent, fillColor, showPace) {
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
  const clamped = Math.max(0, Math.min(100, percent));
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

  // 3. Hairline Pace Indicator (Optional)
  if (showPace) {
    const markerW = 2.5;
    const markerX = width - segW + (segW * 0.7);
    const mp = new Path();
    mp.addRoundedRect(new Rect(markerX, 0, markerW, height), 1, 1);
    dc.addPath(mp);
    dc.setFillColor(TOKENS.greenPace);
    dc.fillPath();
  }

  return dc.getImage();
}

// ==========================================
// MEDIUM WIDGET (FULL WIDTH 330PT, 1:1 ORBITER)
// ==========================================
function buildMediumWidget(w, data) {
  w.setPadding(14, 14, 14, 14);

  const agy = data.agy || {
    email: "hieudat2310.bh@gmail.com",
    tier: "Pro",
    gemini: {
      five_hour_remaining: 96,
      five_hour_refresh: "4h 44m",
      weekly_remaining: 32,
      weekly_refresh: "2d 2h"
    }
  };

  const g5Rem = agy.gemini?.five_hour_remaining ?? 96;
  const g5Used = 100 - g5Rem;
  const g5Reset = agy.gemini?.five_hour_refresh || "4h 44m";

  const gWkRem = agy.gemini?.weekly_remaining ?? 32;
  const gWkUsed = 100 - gWkRem;
  const gWkReset = agy.gemini?.weekly_refresh || "2d 2h";

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

  // Header Line 2: Section Title & Tier
  const row2 = w.addStack();
  row2.layoutHorizontally();

  const sectionTitle = row2.addText("GEMINI MODELS (Flash, Pro)");
  sectionTitle.font = Font.semiboldSystemFont(10.5);
  sectionTitle.textColor = TOKENS.textMuted;

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

  // METRIC 1: GIỚI HẠN 5H CÒN LẠI (TEAL GREEN)
  const g5Head = w.addStack();
  g5Head.layoutHorizontally();
  g5Head.centerAlignContent();

  const g5Title = g5Head.addText(`Giới hạn 5h còn lại: ${g5Rem}%`);
  g5Title.font = Font.boldSystemFont(13);
  g5Title.textColor = TOKENS.textPrimary;

  g5Head.addSpacer();

  const g5Rst = g5Head.addText(`Đặt lại sau ${g5Reset}`);
  g5Rst.font = Font.systemFont(11);
  g5Rst.textColor = TOKENS.textSecondary;

  w.addSpacer(4);

  // Thanh tiến trình 5h (Teal Green, 330pt)
  const bar5 = drawSegmentedBar(330, 5.5, g5Rem, TOKENS.geminiTeal, false);
  const v5 = w.addImage(bar5);
  v5.imageSize = new Size(330, 5.5);

  w.addSpacer(3);

  const sub5 = w.addText(`Đã dùng ${g5Used}%`);
  sub5.font = Font.systemFont(9.5);
  sub5.textColor = TOKENS.textMuted;

  w.addSpacer(8);

  // METRIC 2: GIỚI HẠN TUẦN CÒN LẠI (AMBER YELLOW)
  const gWkHead = w.addStack();
  gWkHead.layoutHorizontally();
  gWkHead.centerAlignContent();

  const gWkTitle = gWkHead.addText(`Giới hạn tuần còn lại: ${gWkRem}%`);
  gWkTitle.font = Font.boldSystemFont(13);
  gWkTitle.textColor = TOKENS.textPrimary;

  gWkHead.addSpacer();

  const gWkRst = gWkHead.addText(`Đặt lại sau ${gWkReset}`);
  gWkRst.font = Font.systemFont(11);
  gWkRst.textColor = TOKENS.textSecondary;

  w.addSpacer(4);

  // Thanh tiến trình Tuần (Amber Yellow, 330pt)
  const barWk = drawSegmentedBar(330, 5.5, gWkRem, TOKENS.geminiAmber, false);
  const vWk = w.addImage(barWk);
  vWk.imageSize = new Size(330, 5.5);

  w.addSpacer(3);

  const subWk = w.addText(`Đã dùng ${gWkUsed}%`);
  subWk.font = Font.systemFont(9.5);
  subWk.textColor = TOKENS.textMuted;
}

// ==========================================
// SMALL WIDGET (2X2)
// ==========================================
function buildSmallWidget(w, data) {
  w.setPadding(12, 12, 12, 12);
  const agy = data.agy || {};
  const g5Rem = agy.gemini?.five_hour_remaining ?? 96;
  const gWkRem = agy.gemini?.weekly_remaining ?? 32;

  const h = w.addStack();
  h.layoutHorizontally();
  h.centerAlignContent();
  const t = h.addText("Gemini");
  t.font = Font.boldSystemFont(14);
  t.textColor = TOKENS.textPrimary;
  h.addSpacer();
  const p = h.addText(agy.tier || "Pro");
  p.font = Font.boldSystemFont(10);
  p.textColor = TOKENS.textSecondary;

  w.addSpacer(6);

  // 5h Quota (Teal Green)
  const u5Head = w.addStack();
  u5Head.layoutHorizontally();
  const u5 = u5Head.addText(`5h: còn ${g5Rem}%`);
  u5.font = Font.boldSystemFont(11);
  u5.textColor = TOKENS.textPrimary;
  u5Head.addSpacer();
  const r5 = u5Head.addText(agy.gemini?.five_hour_refresh || "");
  r5.font = Font.systemFont(9);
  r5.textColor = TOKENS.textMuted;

  w.addSpacer(3);
  const b5 = drawSegmentedBar(132, 4.5, g5Rem, TOKENS.geminiTeal, false);
  const v5 = w.addImage(b5);
  v5.imageSize = new Size(132, 4.5);

  w.addSpacer(8);

  // Weekly Quota (Amber Yellow)
  const uwHead = w.addStack();
  uwHead.layoutHorizontally();
  const uw = uwHead.addText(`Tuần: còn ${gWkRem}%`);
  uw.font = Font.boldSystemFont(11);
  uw.textColor = TOKENS.textPrimary;
  uwHead.addSpacer();
  const rw = uwHead.addText(agy.gemini?.weekly_refresh || "");
  rw.font = Font.systemFont(9);
  rw.textColor = TOKENS.textMuted;

  w.addSpacer(3);
  const bw = drawSegmentedBar(132, 4.5, gWkRem, TOKENS.geminiAmber, false);
  const vw = w.addImage(bw);
  vw.imageSize = new Size(132, 4.5);
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
