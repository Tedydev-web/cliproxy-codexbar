// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: teal; icon-glyph: brain;
/**
 * Orbiter iOS Widget - Antigravity (AGY) Gemini Models Quota
 * 100% Matching Pattern & Style of AntigravityFullCardView in Orbiter Menubar macOS
 * Supports Medium (2x4) & Small (2x2) Widget Families
 * Full-width Segmented Progress Bars (Teal Green cho 5h & Amber Yellow cho Tuần)
 * Đồng bộ chuẩn xác Header: Cập nhật lúc HH:mm:ss · Xs trước, formatResetWithEst, v.v.
 */

const CONFIG = {
  REFRESH_MIN: 1,
  CACHE_KEY: "orbiter_agy_gemini_v13"
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
  greenPace: new Color("#22C55E"),     // Vạch nhịp độ an toàn
  amberWarn: new Color("#F59E0B"),     // Cảnh báo / Ngoại tuyến
  purpleGpt: new Color("#8B5CF6")      // Tím Claude/GPT
};

// Official Antigravity Flying Shuttle Brand Logo Icon (Base64 PNG Template)
const AGY_LOGO_B64 = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAJKADAAQAAAABAAAAJAAAAAAJxsHGAAACaUlEQVRYCe2XwUtVQRTGfSphQmBqIRhtkmgjESL4SjCIQMKIai2Em6BlC2lfEQiiixYtIvoHWuXahS7ColVGkVAthAjUTSqo4Os3oL7HuWdmzni5DwQHPt6dc77vO+fOXObe19BwPI7YCpTy9lupVAbwuAKawBcwXyqVdvmt76CRHvAZyPGdgGuwfoOCl8CK7KRmvs51uS4dUagFfK0p7rtcJtFeeFMUGfd1oMSnCm2Igq1gTSnsC22R6EppqjGFDHcUnE7QnID7MIGfRuVuF3xLEYj/Jpf7eMl0iumFQNFY6mrG0BNI2bJ7Hg9L+L6F5DgpDd22mio8s9a0t+xHG0VWgHs9HHZc5JWyFBNbV+gmRnmacX0Mx5pxeWtDJrNIQZOHdcuWKdYdKRhLb0JoZ9u2QsToCvH89GKQtxnXQysYchehEW0I8YjHwH3zvAXXwRnQCdx58xLsAG34vDSuHmOFPiin3gYx7zNBbgCsKrqfehVjFMNzYFcxvhuzQDMIdhRtX0zrzWP2WDF84xWIBNrnin5C0OxTzBaF4V/m5rc9XPcx90N4/GHebO9ij4nomjBy07FUIzS3FB/zu+2gHibvhdFH5qZz68CkenMzwuuT5ATniPuFwTbzy0FRIIn2PPgnPG0vXERNQP69eRqoZ0rh+Ug09Iu5OyzDA9IzIZxjnv4QKmXweSe8Xyu0agjyAyH4xryjysh3hZf7kyAP2ieqK8QyqD3I3LadVck5gnieArNgf7iDN3vqE5zeYzjCK3AyR92gFO9m8ALsL8BkRkCyDdwBPZlkQQFqdYMboLCbL6j1Y9vqCvwHoDyc53bTRvcAAAAASUVORK5CYII=";

function getAgyIcon() {
  try {
    let cleanB64 = AGY_LOGO_B64.trim();
    if (cleanB64.length % 4 !== 0) {
      cleanB64 += "=".repeat(4 - (cleanB64.length % 4));
    }
    const data = Data.fromBase64String(cleanB64);
    if (data) {
      const img = Image.fromData(data);
      if (img) return img;
    }
  } catch (_) {}
  const sym = SFSymbol.named("airplane");
  return sym.image;
}

function addSyncTimeElement(stack, timestamp, isOnline) {
  const d = new Date(timestamp || Date.now());
  const pad = (n) => String(n).padStart(2, "0");
  const timeStr = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;

  const syncStack = stack.addStack();
  syncStack.layoutHorizontally();
  syncStack.centerAlignContent();
  syncStack.spacing = 3;

  if (isOnline === false) {
    try {
      const dotSym = SFSymbol.named("exclamationmark.circle.fill");
      dotSym.applyFont(Font.systemFont(9));
      const dotImg = syncStack.addImage(dotSym.image);
      dotImg.imageSize = new Size(9.5, 9.5);
      dotImg.tintColor = TOKENS.amberWarn;
    } catch (_) {}
  }

  const t = syncStack.addText(`${timeStr} · `);
  t.font = Font.systemFont(10);
  t.textColor = isOnline === false ? TOKENS.amberWarn : TOKENS.textMuted;

  const rel = syncStack.addDate(d);
  rel.applyRelativeStyle();
  rel.font = Font.systemFont(10);
  rel.textColor = isOnline === false ? TOKENS.amberWarn : TOKENS.textMuted;
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
// DATA & CACHING (BULLETPROOF RETRIEVAL)
// ==========================================
async function fetchAgyData() {
  const fm = FileManager.local();
  const path = fm.joinPath(orbiter.cacheDir, `${CONFIG.CACHE_KEY}.json`);
  let cache = null;
  if (fm.fileExists(path)) {
    try { cache = JSON.parse(fm.readString(path)); } catch (_) {}
  }

  try {
    const agy = await orbiter.api("/v1/antigravity-quota");
    if (agy && (agy.email || agy.gemini)) {
      const data = { agy, time: Date.now(), online: true };
      try { fm.writeString(path, JSON.stringify(data)); } catch (_) {}
      return data;
    }
  } catch (err) {
    console.log("[Orbiter AGY] Lỗi kết nối HTTP qua Tailscale: " + err);
  }

  if (cache) {
    cache.online = false;
    return cache;
  }
  return { agy: null, time: null, online: false };
}

// ==========================================
// DRAWING: FULL-WIDTH SEGMENTED BAR (3 ĐOẠN)
// ==========================================
function drawSegmentedBar(width, height, percent, fillColor) {
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
  const clamped = Math.max(0, Math.min(100, percent));
  let remain = (totalFillable * clamped) / 100;

  for (let i = 0; i < numSegments; i++) {
    if (remain <= 0) break;
    const x = i * (segW + gap);
    const fillAmount = Math.max(0, Math.min(segW, remain));
    if (fillAmount > 0) {
      const p = new Path();
      p.addRoundedRect(new Rect(x, 0, fillAmount, height), r, r);
      dc.addPath(p);
      dc.setFillColor(fillColor);
      dc.fillPath();
    }
    remain -= fillAmount;
  }

  return dc.getImage();
}

function getWidgetContentWidth(family, hPadding) {
  const sw = Math.min(Device.screenSize().width, Device.screenSize().height);
  let totalW = 158;
  if (family === "medium") {
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
// MEDIUM WIDGET: 100% ĐỒNG BỘ VỚI ORBITER MACOS
// ==========================================
function buildMediumWidget(w, data) {
  const hPadding = 14;
  w.setPadding(13, hPadding, 13, hPadding);

  const isOnline = data.online !== false;
  const agy = data.agy || {
    email: "dat.donghieu@gmail.com",
    tier: "Pro",
    gemini: {
      five_hour_remaining: 97,
      five_hour_refresh: "4h 56m",
      weekly_remaining: 92,
      weekly_refresh: "6d 21h"
    },
    claude_gpt: {
      five_hour_remaining: 100,
      weekly_remaining: 100
    }
  };

  const g5Rem = agy.gemini?.five_hour_remaining ?? 97;

  const gWkRem = agy.gemini?.weekly_remaining ?? 92;

  const cg5Rem = agy.claude_gpt?.five_hour_remaining ?? 100;
  const cgWkRem = agy.claude_gpt?.weekly_remaining ?? 100;

  // --- HEADER: 100% NHƯ ORBITER MACOS ---
  const row1 = w.addStack();
  row1.layoutHorizontally();
  row1.centerAlignContent();

  const titleStack = row1.addStack();
  titleStack.layoutHorizontally();
  titleStack.centerAlignContent();
  titleStack.spacing = 5;

  const icon = titleStack.addImage(getAgyIcon());
  icon.imageSize = new Size(15, 15);
  icon.tintColor = TOKENS.geminiTeal;

  const title = titleStack.addText("Antigravity");
  title.font = Font.boldSystemFont(15.5);
  title.textColor = TOKENS.textPrimary;

  row1.addSpacer();

  const email = row1.addText(agy.email || "dat.donghieu@gmail.com");
  email.font = Font.systemFont(12);
  email.textColor = TOKENS.textSecondary;
  email.lineLimit = 1;

  w.addSpacer(2);

  const row2 = w.addStack();
  row2.layoutHorizontally();
  row2.centerAlignContent();

  // Mốc thời gian đồng bộ và relative live date cập nhật tự động
  addSyncTimeElement(row2, data.time, isOnline);

  row2.addSpacer();

  const planTxt = row2.addText(`Gói ${agy.tier || "Pro"}`);
  planTxt.font = Font.systemFont(11);
  planTxt.textColor = TOKENS.textSecondary;

  w.addSpacer(5);

  // Hairline Divider
  const div = w.addStack();
  div.size = new Size(0, 0.5);
  div.backgroundColor = TOKENS.cardBorder;

  w.addSpacer(6);

  const barW = getWidgetContentWidth("medium", hPadding);
  const gap = 14;
  const colW = Math.floor((barW - gap) / 2);

  const body = w.addStack();
  body.layoutHorizontally();
  body.topAlignContent();

  const addGroup = (parent, caption, five, week) => {
    const col = parent.addStack();
    col.layoutVertically();
    col.size = new Size(colW, 0);
    const cap = col.addText(caption);
    cap.font = Font.boldSystemFont(9);
    cap.textColor = TOKENS.textMuted;
    cap.lineLimit = 1;
    col.addSpacer(4);
    [["5h", five, TOKENS.geminiTeal], ["Tuần", week, TOKENS.geminiAmber]].forEach(([label, m, color], i) => {
      const used = Math.max(0, Math.min(100, 100 - (m.remaining ?? 100)));
      const head = col.addStack();
      head.layoutHorizontally();
      head.centerAlignContent();
      const t = head.addText(`${label}: ${used}% đã dùng`);
      t.font = Font.boldSystemFont(10.5);
      t.textColor = used >= 90 ? TOKENS.amberWarn : TOKENS.textPrimary;
      t.lineLimit = 1;
      head.addSpacer();
      const r = head.addText(m.refresh || "");
      r.font = Font.systemFont(9);
      r.textColor = TOKENS.textSecondary;
      r.lineLimit = 1;
      col.addSpacer(3);
      const img = col.addImage(drawSegmentedBar(colW, 5, used, color));
      img.imageSize = new Size(colW, 5);
      img.leftAlignImage();
      if (i === 0) col.addSpacer(7);
    });
  };

  addGroup(body, "GEMINI (Flash, Pro)", { remaining: g5Rem, refresh: agy.gemini?.five_hour_refresh }, { remaining: gWkRem, refresh: agy.gemini?.weekly_refresh });
  body.addSpacer(gap);
  addGroup(body, "CLAUDE & GPT (Opus, Sonnet)", { remaining: cg5Rem, refresh: agy.claude_gpt?.five_hour_refresh }, { remaining: cgWkRem, refresh: agy.claude_gpt?.weekly_refresh });
}

// ==========================================
// SMALL WIDGET (2X2 - FALLBACK CHUẨN)
// ==========================================
function buildSmallWidget(w, data) {
  const hPadding = 12;
  w.setPadding(12, hPadding, 12, hPadding);
  const agy = data.agy || {};
  const g5Rem = agy.gemini?.five_hour_remaining ?? 97;
  const g5Used = 100 - g5Rem;
  const gWkRem = agy.gemini?.weekly_remaining ?? 92;
  const gWkUsed = 100 - gWkRem;
  const smallW = getWidgetContentWidth("small", hPadding);

  const h = w.addStack();
  h.layoutHorizontally();
  h.centerAlignContent();
  const titleStack = h.addStack();
  titleStack.layoutHorizontally();
  titleStack.centerAlignContent();
  titleStack.spacing = 4;

  const icon = titleStack.addImage(getAgyIcon());
  icon.imageSize = new Size(13, 13);
  icon.tintColor = TOKENS.geminiTeal;

  const t = titleStack.addText("Gemini");
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
  u5Head.centerAlignContent();
  const u5 = u5Head.addText(`5h: ${g5Used}% đã dùng`);
  u5.font = Font.boldSystemFont(11);
  u5.textColor = TOKENS.textPrimary;
  u5Head.addSpacer();
  const r5 = u5Head.addText(agy.gemini?.five_hour_refresh || "");
  r5.font = Font.systemFont(9.5);
  r5.textColor = TOKENS.textMuted;

  w.addSpacer(3);
  const b5 = drawSegmentedBar(smallW, 4.5, g5Used, TOKENS.geminiTeal);
  const v5 = w.addImage(b5);
  v5.imageSize = new Size(smallW, 4.5);
  v5.leftAlignImage();

  w.addSpacer(8);

  // Weekly Quota (Amber Yellow)
  const uwHead = w.addStack();
  uwHead.layoutHorizontally();
  uwHead.centerAlignContent();
  const uw = uwHead.addText(`Tuần: ${gWkUsed}% đã dùng`);
  uw.font = Font.boldSystemFont(11);
  uw.textColor = TOKENS.textPrimary;
  uwHead.addSpacer();
  const rw = uwHead.addText(agy.gemini?.weekly_refresh || "");
  rw.font = Font.systemFont(9.5);
  rw.textColor = TOKENS.textMuted;

  w.addSpacer(3);
  const bw = drawSegmentedBar(smallW, 4.5, gWkUsed, TOKENS.geminiAmber);
  const vw = w.addImage(bw);
  vw.imageSize = new Size(smallW, 4.5);
  vw.leftAlignImage();
}

// ==========================================
// MAIN ENTRY
// ==========================================
function agySummary(agy) {
  const s = (agy && agy.summary) || {};
  return [
    `Antigravity ${agy && agy.email ? agy.email : ""}`.trim(),
    `Gemini 5h: đã dùng ${s.gemini_5h ?? "-"}% (reset ${s.gemini_5h_reset || "-"})`,
    `Gemini tuần: đã dùng ${s.gemini_weekly ?? "-"}% (reset ${s.gemini_weekly_reset || "-"})`,
    `Claude/GPT: đã dùng ${s.claude_used ?? "-"}% (reset ${s.claude_reset || "-"})`
  ].join("\n");
}

async function main() {
  const data = await fetchAgyData();
  if (orbiter.mode === "shortcut" || orbiter.mode === "siri") {
    Script.setShortcutOutput(data.agy ? agySummary(data.agy) : "Antigravity: không có dữ liệu");
    return;
  }
  const w = new ListWidget();
  w.url = orbiter.runURL;
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

  if (orbiter.mode === "widget") {
    Script.setWidget(w);
  } else {
    await w.presentMedium();
  }
}

await main();
