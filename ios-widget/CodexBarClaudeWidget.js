// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: orange; icon-glyph: bolt;
/**
 * CodexBar iOS Widget - Claude Pool Quota
 * 100% Matching Pattern & Style of ClaudeFullCardView in Orbiter Menubar & CodexBar macOS
 * Supports Medium (2x4) & Small (2x2) Widget Families
 * Full-width Segmented Progress Bars (Không bị hụt lề phải)
 * Interactive Account Switcher (Khi mở app hoặc cấu hình Run Script)
 * Đồng bộ chuẩn xác Header: Cập nhật lúc HH:mm:ss · Xs trước, formatResetWithEst, v.v.
 */

const CONFIG = {
  HOST: "100.127.1.234", // IP Tailscale Ubuntu Host
  PORT: "8318",
  TIMEOUT: 4,
  REFRESH_MIN: 2, // Chu kỳ refresh đề xuất cho iOS (2 phút)
  CACHE_KEY: "codexbar_claude_v11"
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

// Official Claude Sparkle Brand Logo Icon (Base64 PNG Template)
const CLAUDE_LOGO_B64 = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAJKADAAQAAAABAAAAJAAAAAAJxsHGAAAD3klEQVRYCe2XW2iPYRzH95+Z04hGQuSUY84XWivEWDnkAheKckHRLpDCxS52JadyulDChuSGlaQcyiE0zFkjIYxtFCbMYcbr8333PNuz17t5/3+a0n71eX/H5/c8e97/+7zvkpJa5H/eAc/zZsEUiP3zv5NFLAYrq8IWRDIL7kJmWP6vxpjkCFgpxUgJTkDshik4FMxF9ZOjFlJ3zqntjT3X8ZNYiG7jCBN75OZkk+8FfYLxhH2apcJ9sFLsNiOYbhPoBYHcfGLV8BmGuLk/smk2FVyZZBsSHOokRjnxmcS/Oblcm4usGdwBiuE1LHUH4h8FK+dtjsBEE/yKbq04ehxUmbhUDYy0YyJrBnXXaEcOYLc3kwzA/uLkskxct0Vy3fjdsJ/5kfrL2siLCBbSY299H9+6w3WQmWyzkysysTUmthudAmeNb1VhcI64fTothPe2I/oDLIAu8AasTMfYbpwc9AabMPohulPcCwgbQKOBcMk0tqoAI9c66DNw0Pi70D+MLaXf1Niw3gnHaJgMK+ETWCm3BlpP0T3Hd80VYRNTEINfDtew2kZjNNBuXYCocovCVtAOMmE57IGr8BEqoOlziQL/kW1sVeS1W6tAh9zv5CYFep2455A75hVOF3euBm9tkpNJnobP8BYqHf0OW1RAOaTDFoj6+qmh9h7oWNApfwFKYrGYh66T4IJSyeyEodAR9GR0MLRFxyP6o3QkaGJxmcmr0E1KgwU1VcnuqbaNg3bzUBNjqslpJ1/BR9BOfIM3htfofBZZhk5cWFhPyIfvIHEf8dpI7VU/6Dw4C+7TiVsnOsv6JbQaBur9pgnsu+kt9jqohMYWtYOcHm99KWTAajgGGit5DmPiXhCDFkEZWNHH2mB4YALbjHbfcSbkH5gNnlwSWuQw0E8gujBAt+cEWHmJMUcd0IUmuA+9xNjL0DqZJafgom953kl0WvSZQyppMBzs1qpvAfhnBlrnkEQ7lAab5CAas963ai9zUPuNfwWtoyIxYfAE0IF2H7JtF+yJoLhuz2jF0XYXu2JrgU9BotusF3GeHKQEetpecWsGt3IH4fcC3TZJjs1h60OuGvxjBD0NrBSoDmc2aMefQA87NmFNEz0RSA5bBth9/MjnvfCxqSJ7TVxqRkm1hf7PIx3axOyabIVJJfA/3o0k8zzo553zW1MrCM8Dsu5dQnbNNb5cxs6u03wN4LkuBuXTSwDauBxMNeYH8/3iN5vlRz1HwLN7Pa/DMSTqNUt7k88OCZYWudHfVOreWnIYtTI/lP4sK6rY5hx+mpoHmEH2kA2xLPbzbO4llmaYwd+AqWYtWtPxbPfAAAAAElFTkSuQmCC=";
function getClaudeIcon() {
  try {
    let cleanB64 = CLAUDE_LOGO_B64.trim();
    if (cleanB64.length % 4 !== 0) {
      cleanB64 += "=".repeat(4 - (cleanB64.length % 4));
    }
    const data = Data.fromBase64String(cleanB64);
    if (data) {
      const img = Image.fromData(data);
      if (img) return img;
    }
  } catch (_) {}
  const sym = SFSymbol.named("sparkles");
  return sym.image;
}

// ==========================================
// TIME FORMATTERS (1:1 VỚI SWIFT ORBITERMENUBAR)
// ==========================================
function formatAgoText(timestamp) {
  if (!timestamp) return "Vừa xong";
  const now = Date.now();
  const deltaSec = Math.max(0, Math.floor((now - timestamp) / 1000));
  const timeStr = new Date(timestamp).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit", second: "2-digit" });

  let relStr = "Vừa xong";
  if (deltaSec < 15) {
    relStr = "Vừa xong";
  } else if (deltaSec < 60) {
    relStr = `${deltaSec}s trước`;
  } else if (deltaSec < 3600) {
    relStr = `${Math.floor(deltaSec / 60)}m trước`;
  } else if (deltaSec < 86400) {
    relStr = `${Math.floor(deltaSec / 3600)}h trước`;
  } else {
    relStr = "1d trước";
  }
  return `Cập nhật lúc ${timeStr} · ${relStr}`;
}

function formatResetWithEst(raw) {
  if (!raw || raw === "-") return "";
  let cleaned = raw.replace(/Đặt lại sau /g, "").replace(/Đặt lại: /g, "").replace(/Resets in /g, "").trim();
  if (!cleaned) return "";

  let totalSec = 0;
  const parts = cleaned.split(" ");
  for (const p of parts) {
    const s = p.trim();
    if (s.endsWith("d")) totalSec += parseFloat(s.slice(0, -1)) * 86400;
    else if (s.endsWith("h")) totalSec += parseFloat(s.slice(0, -1)) * 3600;
    else if (s.endsWith("m")) totalSec += parseFloat(s.slice(0, -1)) * 60;
    else if (s.endsWith("s")) totalSec += parseFloat(s.slice(0, -1));
  }

  if (totalSec <= 0) return `Đặt lại: ${cleaned}`;

  const target = new Date(Date.now() + totalSec * 1000);
  const now = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  const timeStr = `${pad(target.getHours())}:${pad(target.getMinutes())}:${pad(target.getSeconds())}`;

  const isToday = target.toDateString() === now.toDateString();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const isTomorrow = target.toDateString() === tomorrow.toDateString();

  if (totalSec < 86400 && isToday) {
    return `Đặt lại sau ${cleaned} · ${timeStr}`;
  } else if (isTomorrow) {
    return `Đặt lại sau ${cleaned} · Mai ${timeStr}`;
  } else {
    const dayStr = `${pad(target.getDate())}/${pad(target.getMonth() + 1)} ${pad(target.getHours())}:${pad(target.getMinutes())}`;
    return `Đặt lại sau ${cleaned} · ${dayStr}`;
  }
}

// ==========================================
// DATA & CACHING (ON-DEMAND + OFFLINE CACHE)
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
// DRAWING: FULL-WIDTH SEGMENTED BAR (3 ĐOẠN)
// ==========================================
function drawSegmentedBar(width, height, usedPct, fillColor, pacePct) {
  const dc = new DrawContext();
  dc.size = new Size(width, height);
  dc.opaque = false;
  dc.respectScreenScale = true;

  const numSegments = 3;
  const gap = 3;
  const totalGaps = gap * (numSegments - 1);
  const totalFillable = width - totalGaps;
  const segW = totalFillable / numSegments;
  const r = height / 2;

  // 1. Rãnh nền xám (3 đoạn bo góc hoàn chỉnh bằng nhau)
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
  let remain = (totalFillable * clamped) / 100;

  for (let i = 0; i < numSegments; i++) {
    if (remain <= 0) break;
    const x = i * (segW + gap);
    const fillAmount = Math.max(0, Math.min(segW, remain));
    if (fillAmount > 0) {
      const p = new Path();
      p.addRoundedRect(new Rect(x, 0, fillAmount, height), r, r);
      dc.addPath(p);
      dc.setFillColor(fillColor || TOKENS.orangeFill);
      dc.fillPath();
    }
    remain -= fillAmount;
  }

  // 3. Hairline Pace Indicator (Green tick)
  if (pacePct !== undefined && pacePct !== null && pacePct > 0) {
    const clampedPace = Math.max(0, Math.min(100, pacePct));
    let paceRemain = (totalFillable * clampedPace) / 100;
    let paceX = 0;
    for (let i = 0; i < numSegments; i++) {
      if (paceRemain <= segW) {
        paceX = i * (segW + gap) + paceRemain;
        break;
      }
      paceRemain -= segW;
      paceX = i * (segW + gap) + segW;
    }
    const markerW = 2;
    const mx = Math.max(0, Math.min(width - markerW, paceX - markerW / 2));
    const mp = new Path();
    mp.addRoundedRect(new Rect(mx, 0, markerW, height), 1, 1);
    dc.addPath(mp);
    dc.setFillColor(TOKENS.greenPace);
    dc.fillPath();
  }

  return dc.getImage();
}

function getWidgetContentWidth(family, hPadding) {
  const sw = Math.min(Device.screenSize().width, Device.screenSize().height);
  let totalW = 158;
  if (family === "medium" || family === "large") {
    if (sw <= 375) totalW = 321;
    else if (sw <= 393) totalW = 338;
    else if (sw <= 402) totalW = 344;
    else if (sw <= 414) totalW = 360;
    else totalW = 364; // Pro Max / Plus (428, 430, 440)
  } else {
    // small
    if (sw <= 375) totalW = 148;
    else if (sw <= 393) totalW = 158;
    else if (sw <= 402) totalW = 162;
    else if (sw <= 414) totalW = 169;
    else totalW = 170; // Pro Max / Plus (428, 430, 440)
  }
  return Math.round(totalW - (hPadding * 2));
}

// ==========================================
// MEDIUM WIDGET: 100% ĐỒNG BỘ VỚI CLAUDE MACOS
// ==========================================
function buildMediumWidget(w, data) {
  const hPadding = 14;
  w.setPadding(14, hPadding, 14, hPadding);

  const acc = data.pool?.accounts?.[0] || {
    name: "projectplayground2025@gmail.com",
    plan: "Max 20x",
    used_5h: 14,
    remaining_5h: 86,
    reset_5h: "1h 8m",
    used_weekly: 17,
    remaining_weekly: 83,
    reset_weekly: "6d 15h"
  };

  const reset5hFormatted = formatResetWithEst(acc.reset_5h);
  const resetWkFormatted = formatResetWithEst(acc.reset_weekly);

  // --- HEADER: 100% NHƯ ORBITER MACOS ---
  const row1 = w.addStack();
  row1.layoutHorizontally();
  row1.centerAlignContent();

  const titleStack = row1.addStack();
  titleStack.layoutHorizontally();
  titleStack.centerAlignContent();
  titleStack.spacing = 5;

  const icon = titleStack.addImage(getClaudeIcon());
  icon.imageSize = new Size(15, 15);
  icon.tintColor = TOKENS.orangeFill;

  const title = titleStack.addText("Claude");
  title.font = Font.boldSystemFont(16);
  title.textColor = TOKENS.textPrimary;

  row1.addSpacer();

  const email = row1.addText(acc.name);
  email.font = Font.systemFont(12);
  email.textColor = TOKENS.textSecondary;
  email.lineLimit = 1;

  w.addSpacer(2);

  const row2 = w.addStack();
  row2.layoutHorizontally();
  row2.centerAlignContent();

  // Dòng cập nhật chuẩn macOS: "Cập nhật lúc HH:mm:ss · Xs trước"
  const agoText = formatAgoText(data.time);
  const syncTxt = row2.addText(agoText);
  syncTxt.font = Font.systemFont(10.5);
  syncTxt.textColor = TOKENS.textSecondary;

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

  // --- METRIC 1: PHIÊN 5H ---
  const p5Head = w.addStack();
  p5Head.layoutHorizontally();
  p5Head.centerAlignContent();

  const p5Title = p5Head.addText(`Phiên 5h: ${acc.used_5h}% đã dùng`);
  p5Title.font = Font.boldSystemFont(13);
  p5Title.textColor = TOKENS.textPrimary;

  p5Head.addSpacer();

  const p5Reset = p5Head.addText(reset5hFormatted);
  p5Reset.font = Font.systemFont(10.5);
  p5Reset.textColor = TOKENS.textSecondary;

  w.addSpacer(4);

  // Thanh tiến trình 5h full-width
  const barW = getWidgetContentWidth("medium", hPadding);
  const bar5 = drawSegmentedBar(barW, 5.5, acc.used_5h, TOKENS.orangeFill, acc.remaining_5h);
  const v5 = w.addImage(bar5);
  v5.imageSize = new Size(barW, 5.5);
  v5.leftAlignImage();

  w.addSpacer(3);

  const sub5 = w.addText(`${acc.remaining_5h}% dự trữ nhịp độ`);
  sub5.font = Font.systemFont(9.5);
  sub5.textColor = TOKENS.textMuted;

  w.addSpacer(8);

  // --- METRIC 2: HÀNG TUẦN ---
  const pWkHead = w.addStack();
  pWkHead.layoutHorizontally();
  pWkHead.centerAlignContent();

  const pWkTitle = pWkHead.addText(`Hàng tuần: ${acc.used_weekly}% đã dùng`);
  pWkTitle.font = Font.boldSystemFont(13);
  pWkTitle.textColor = TOKENS.textPrimary;

  pWkHead.addSpacer();

  const pWkReset = pWkHead.addText(resetWkFormatted);
  pWkReset.font = Font.systemFont(10.5);
  pWkReset.textColor = TOKENS.textSecondary;

  w.addSpacer(4);

  // Thanh tiến trình Tuần full-width
  const barWk = drawSegmentedBar(barW, 5.5, acc.used_weekly, TOKENS.orangeFill);
  const vWk = w.addImage(barWk);
  vWk.imageSize = new Size(barW, 5.5);
  vWk.leftAlignImage();
}

// ==========================================
// SMALL WIDGET (2X2)
// ==========================================
function buildSmallWidget(w, data) {
  const hPadding = 12;
  w.setPadding(12, hPadding, 12, hPadding);
  const acc = data.pool?.accounts?.[0] || {};
  const smallW = getWidgetContentWidth("small", hPadding);

  const h = w.addStack();
  h.layoutHorizontally();
  h.centerAlignContent();
  const titleStack = h.addStack();
  titleStack.layoutHorizontally();
  titleStack.centerAlignContent();
  titleStack.spacing = 4;

  const icon = titleStack.addImage(getClaudeIcon());
  icon.imageSize = new Size(13, 13);
  icon.tintColor = TOKENS.orangeFill;

  const t = titleStack.addText("Claude");
  t.font = Font.boldSystemFont(14);
  t.textColor = TOKENS.textPrimary;
  h.addSpacer();
  const p = h.addText(acc.plan?.replace("Max ", "") || "20x");
  p.font = Font.boldSystemFont(10);
  p.textColor = TOKENS.textSecondary;

  w.addSpacer(6);

  // 5h Quota
  const u5Head = w.addStack();
  u5Head.layoutHorizontally();
  u5Head.centerAlignContent();
  const u5 = u5Head.addText(`5h: ${acc.used_5h || 0}% đã dùng`);
  u5.font = Font.boldSystemFont(11);
  u5.textColor = TOKENS.textPrimary;
  u5Head.addSpacer();
  const r5 = u5Head.addText(acc.reset_5h || "");
  r5.font = Font.systemFont(9.5);
  r5.textColor = TOKENS.textMuted;

  w.addSpacer(3);
  const b5 = drawSegmentedBar(smallW, 4.5, acc.used_5h || 0, TOKENS.orangeFill, acc.remaining_5h);
  const v5 = w.addImage(b5);
  v5.imageSize = new Size(smallW, 4.5);
  v5.leftAlignImage();

  w.addSpacer(8);

  // Weekly Quota
  const uwHead = w.addStack();
  uwHead.layoutHorizontally();
  uwHead.centerAlignContent();
  const uw = uwHead.addText(`Tuần: ${acc.used_weekly || 0}% đã dùng`);
  uw.font = Font.boldSystemFont(11);
  uw.textColor = TOKENS.textPrimary;
  uwHead.addSpacer();
  const rw = uwHead.addText(acc.reset_weekly || "");
  rw.font = Font.systemFont(9.5);
  rw.textColor = TOKENS.textMuted;

  w.addSpacer(3);
  const bw = drawSegmentedBar(smallW, 4.5, acc.used_weekly || 0, TOKENS.orangeFill);
  const vw = w.addImage(bw);
  vw.imageSize = new Size(smallW, 4.5);
  vw.leftAlignImage();
}

// ==========================================
// LARGE WIDGET (4X4): ĐẦY ĐỦ 3 TÀI KHOẢN & TRẠNG THÁI NHƯ DESKTOP
// ==========================================
function buildLargeWidget(w, data) {
  const hPadding = 14;
  w.setPadding(12, hPadding, 12, hPadding);

  const accounts = data.pool?.accounts || [];
  const acc0 = accounts[0] || {
    name: "projectplayground2025@gmail.com",
    plan: "Max 20x",
    used_5h: 14,
    remaining_5h: 86,
    reset_5h: "1h 8m",
    used_weekly: 17,
    remaining_weekly: 83,
    reset_weekly: "6d 15h",
    is_available: true,
    is_probe_error: false
  };

  const contentW = getWidgetContentWidth("large", hPadding);

  // --- 1. HEADER CHÍNH ---
  const row1 = w.addStack();
  row1.layoutHorizontally();
  row1.centerAlignContent();

  const titleStack = row1.addStack();
  titleStack.layoutHorizontally();
  titleStack.centerAlignContent();
  titleStack.spacing = 5;

  const icon = titleStack.addImage(getClaudeIcon());
  icon.imageSize = new Size(15, 15);
  icon.tintColor = TOKENS.orangeFill;

  const title = titleStack.addText("Claude");
  title.font = Font.boldSystemFont(16);
  title.textColor = TOKENS.textPrimary;

  row1.addSpacer();

  const emailStack = row1.addStack();
  emailStack.layoutHorizontally();
  emailStack.centerAlignContent();
  emailStack.spacing = 4;

  const star = emailStack.addText("★ #1");
  star.font = Font.boldSystemFont(11);
  star.textColor = TOKENS.orangeFill;

  const email = emailStack.addText(acc0.name);
  email.font = Font.systemFont(11.5);
  email.textColor = TOKENS.textSecondary;
  email.lineLimit = 1;

  w.addSpacer(2);

  const row2 = w.addStack();
  row2.layoutHorizontally();
  row2.centerAlignContent();

  const agoText = formatAgoText(data.time);
  const syncTxt = row2.addText(agoText);
  syncTxt.font = Font.systemFont(10);
  syncTxt.textColor = TOKENS.textSecondary;

  row2.addSpacer();

  const planTxt = row2.addText(`Gói ${acc0.plan || "Max 20x"}`);
  planTxt.font = Font.systemFont(10.5);
  planTxt.textColor = TOKENS.textSecondary;

  w.addSpacer(5);

  // Hairline Divider
  const div1 = w.addStack();
  div1.size = new Size(0, 0.5);
  div1.backgroundColor = TOKENS.cardBorder;

  w.addSpacer(6);

  // --- 2. QUOTA TÀI KHOẢN #1 (ĐANG ƯU TIÊN SỐ 1) ---
  const reset5hFormatted = formatResetWithEst(acc0.reset_5h);
  const resetWkFormatted = formatResetWithEst(acc0.reset_weekly);

  // Phiên 5h
  const p5Head = w.addStack();
  p5Head.layoutHorizontally();
  p5Head.centerAlignContent();

  const p5Title = p5Head.addText(`Phiên 5h: ${acc0.used_5h}% đã dùng`);
  p5Title.font = Font.boldSystemFont(12);
  p5Title.textColor = TOKENS.textPrimary;

  p5Head.addSpacer();

  const p5Reset = p5Head.addText(reset5hFormatted);
  p5Reset.font = Font.systemFont(10);
  p5Reset.textColor = TOKENS.textSecondary;

  w.addSpacer(3);

  const bar5 = drawSegmentedBar(contentW, 5, acc0.used_5h, TOKENS.orangeFill, acc0.remaining_5h);
  const v5 = w.addImage(bar5);
  v5.imageSize = new Size(contentW, 5);
  v5.leftAlignImage();

  w.addSpacer(2);

  const sub5 = w.addText(`${acc0.remaining_5h}% dự trữ nhịp độ`);
  sub5.font = Font.systemFont(9);
  sub5.textColor = TOKENS.textMuted;

  w.addSpacer(5);

  // Hàng tuần
  const pWkHead = w.addStack();
  pWkHead.layoutHorizontally();
  pWkHead.centerAlignContent();

  const pWkTitle = pWkHead.addText(`Hàng tuần: ${acc0.used_weekly}% đã dùng`);
  pWkTitle.font = Font.boldSystemFont(12);
  pWkTitle.textColor = TOKENS.textPrimary;

  pWkHead.addSpacer();

  const pWkReset = pWkHead.addText(resetWkFormatted);
  pWkReset.font = Font.systemFont(10);
  pWkReset.textColor = TOKENS.textSecondary;

  w.addSpacer(3);

  const barWk = drawSegmentedBar(contentW, 5, acc0.used_weekly, TOKENS.orangeFill);
  const vWk = w.addImage(barWk);
  vWk.imageSize = new Size(contentW, 5);
  vWk.leftAlignImage();

  w.addSpacer(7);

  // Hairline Divider
  const div2 = w.addStack();
  div2.size = new Size(0, 0.5);
  div2.backgroundColor = TOKENS.cardBorder;

  w.addSpacer(6);

  // --- 3. SECTION: POOL ACCOUNTS (2 TÀI KHOẢN CÒN LẠI) ---
  const poolHead = w.addStack();
  poolHead.layoutHorizontally();
  poolHead.centerAlignContent();

  const poolTitle = poolHead.addText("Pool Accounts (Dự phòng)");
  poolTitle.font = Font.boldSystemFont(11.5);
  poolTitle.textColor = TOKENS.textSecondary;

  poolHead.addSpacer();

  const poolHint = poolHead.addText("▲▼ Chạm để đổi ưu tiên");
  poolHint.font = Font.systemFont(10);
  poolHint.textColor = TOKENS.textMuted;

  w.addSpacer(5);

  const remainingAccounts = accounts.slice(1);
  const cardPadH = 9;
  const cardContentW = contentW - (cardPadH * 2);

  if (remainingAccounts.length === 0) {
    const emptyStack = w.addStack();
    const emptyTxt = emptyStack.addText("Không có tài khoản dự phòng nào trong Pool.");
    emptyTxt.font = Font.systemFont(11);
    emptyTxt.textColor = TOKENS.textMuted;
  }

  remainingAccounts.slice(0, 2).forEach((acc, idx) => {
    const realIdx = idx + 2; // #2, #3
    const card = w.addStack();
    card.layoutVertically();
    card.backgroundColor = new Color("#FFFFFF", 0.04);
    card.cornerRadius = 8;
    card.setPadding(6, cardPadH, 6, cardPadH);

    // Row 1: STT + Tên tài khoản + Gói + Trạng thái
    const r1 = card.addStack();
    r1.layoutHorizontally();
    r1.centerAlignContent();

    const idxTxt = r1.addText(`#${realIdx} `);
    idxTxt.font = Font.boldSystemFont(11);
    idxTxt.textColor = TOKENS.orangeFill;

    const nameTxt = r1.addText(acc.name);
    nameTxt.font = Font.boldSystemFont(11);
    nameTxt.textColor = TOKENS.textPrimary;
    nameTxt.lineLimit = 1;

    r1.addSpacer(4);

    const planBadge = r1.addText(`· ${acc.plan || "Max"}`);
    planBadge.font = Font.systemFont(9.5);
    planBadge.textColor = TOKENS.textMuted;

    r1.addSpacer();

    // Trạng thái (Online/Khả dụng, 429, Hết hạn)
    const statusStack = r1.addStack();
    statusStack.layoutHorizontally();
    statusStack.centerAlignContent();
    statusStack.spacing = 3;

    if (acc.is_probe_error) {
      const warnTxt = statusStack.addText("⚠️ 429 API");
      warnTxt.font = Font.boldSystemFont(9.5);
      warnTxt.textColor = new Color("#FF9500");
    } else if (acc.is_available === false) {
      const errTxt = statusStack.addText("⛔ Hết hạn");
      errTxt.font = Font.boldSystemFont(9.5);
      errTxt.textColor = new Color("#FF3B30");
    } else {
      const dot = statusStack.addText("●");
      dot.font = Font.systemFont(8);
      dot.textColor = new Color("#34C759");
      const okTxt = statusStack.addText("Khả dụng");
      okTxt.font = Font.systemFont(9.5);
      okTxt.textColor = new Color("#34C759");
    }

    card.addSpacer(3);

    // Row 2: 5h Quota & mini bar
    const r2 = card.addStack();
    r2.layoutHorizontally();
    r2.centerAlignContent();

    const u5Txt = r2.addText(`5h: ${acc.used_5h || 0}% đã dùng (còn ${acc.remaining_5h ?? (100 - (acc.used_5h || 0))}%)`);
    u5Txt.font = Font.systemFont(9.5);
    u5Txt.textColor = TOKENS.textSecondary;

    r2.addSpacer();

    const r5Txt = r2.addText(acc.reset_5h ? `Reset: ${acc.reset_5h}` : "");
    r5Txt.font = Font.systemFont(9);
    r5Txt.textColor = TOKENS.textMuted;

    card.addSpacer(2);

    const bar5Mini = drawSegmentedBar(cardContentW, 3.5, acc.used_5h || 0, TOKENS.orangeFill, acc.remaining_5h);
    const v5Mini = card.addImage(bar5Mini);
    v5Mini.imageSize = new Size(cardContentW, 3.5);
    v5Mini.leftAlignImage();

    card.addSpacer(4);

    // Row 3: Weekly Quota & mini bar
    const r3 = card.addStack();
    r3.layoutHorizontally();
    r3.centerAlignContent();

    const uwTxt = r3.addText(`Tuần: ${acc.used_weekly || 0}% đã dùng (còn ${acc.remaining_weekly ?? (100 - (acc.used_weekly || 0))}%)`);
    uwTxt.font = Font.systemFont(9.5);
    uwTxt.textColor = TOKENS.textSecondary;

    r3.addSpacer();

    const rwTxt = r3.addText(acc.reset_weekly ? `Reset: ${acc.reset_weekly}` : "");
    rwTxt.font = Font.systemFont(9);
    rwTxt.textColor = TOKENS.textMuted;

    card.addSpacer(2);

    const barWkMini = drawSegmentedBar(cardContentW, 3.5, acc.used_weekly || 0, TOKENS.orangeFill);
    const vWkMini = card.addImage(barWkMini);
    vWkMini.imageSize = new Size(cardContentW, 3.5);
    vWkMini.leftAlignImage();

    if (idx < remainingAccounts.length - 1) {
      w.addSpacer(5);
    }
  });

  w.addSpacer();
}

// ==========================================
// INTERACTIVE SWITCHER CHO 3 TÀI KHOẢN
// ==========================================
async function showInteractiveSwitcher(data) {
  const accounts = data.pool?.accounts || [];
  if (accounts.length === 0) return;

  const alert = new Alert();
  alert.title = "⚡ CodexBar - Claude Accounts";
  alert.message = "Chạm vào tài khoản để đưa lên ưu tiên số #1 (Selector Drain First):";

  accounts.forEach((acc, idx) => {
    const isFirst = idx === 0;
    const prefix = isFirst ? "★ [Đang dùng] " : `#${idx + 1} `;
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

    w.url = "scriptable:///run?scriptName=" + encodeURIComponent(Script.name());

    const family = config.widgetFamily || "medium";
    if (family === "small") {
      buildSmallWidget(w, data);
    } else if (family === "large") {
      buildLargeWidget(w, data);
    } else {
      buildMediumWidget(w, data);
    }

    w.refreshAfterDate = new Date(Date.now() + CONFIG.REFRESH_MIN * 60 * 1000);
    Script.setWidget(w);
  } else {
    await showInteractiveSwitcher(data);
    const updatedData = await fetchPoolData();

    const w = new ListWidget();
    const grad = new LinearGradient();
    grad.locations = [0.0, 1.0];
    grad.colors = [TOKENS.bgTop, TOKENS.bgBtm];
    w.backgroundGradient = grad;

    const family = config.widgetFamily || "medium";
    if (family === "small") {
      buildSmallWidget(w, updatedData);
      await w.presentSmall();
    } else if (family === "large") {
      buildLargeWidget(w, updatedData);
      await w.presentLarge();
    } else {
      buildMediumWidget(w, updatedData);
      await w.presentMedium();
    }
  }
}

await main();
Script.complete();
