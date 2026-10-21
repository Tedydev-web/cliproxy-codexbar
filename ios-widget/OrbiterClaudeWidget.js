// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: orange; icon-glyph: bolt;
/**
 * Orbiter iOS Widget - Claude Pool Quota (Large Size)
 * 100% Matching Pattern & Style of ClaudeFullCardView in Orbiter Menubar & CodexBar macOS
 * Supports Large (4x4) Multi-Account Display with 30-Day Lifecycle Telemetry
 * Full-width Segmented Progress Bars (Không bị hụt lề phải)
 * Hiển thị toàn diện 3 tài khoản trong Pool + Cảnh báo hết hạn OAuth 30 ngày + Fallback API
 */

const CONFIG = {
  REFRESH_MIN: 1,
  CACHE_KEY: "orbiter_claude_large_v13"
};

// ==========================================
// DESIGN TOKENS (CODEXBAR & ORBITER MACOS 1:1)
// ==========================================
const TOKENS = {
  bgTop: new Color("#161A1D"),
  bgBtm: new Color("#0E1114"),
  cardBorder: new Color("#FFFFFF", 0.08),

  textPrimary: new Color("#FFFFFF", 0.95),
  textSecondary: new Color("#9CA3AF"),
  textMuted: new Color("#6B7280"),

  orangeFill: new Color("#DA7756"),   // Cam Đất Terracotta Claude (Đồng bộ 100% macOS Orbiter #DA7756)
  trackGray: new Color("#272D34"),    // Rãnh segmented bar đồng bộ Orbiter macOS
  greenPace: new Color("#22C55E"),    // Vạch nhịp độ an toàn / Online
  amberWarn: new Color("#F59E0B"),    // Cảnh báo 429 / Sắp hết hạn 30 ngày
  redAlert: new Color("#EF4444"),     // Hết hạn / Lỗi 401
  blueCapi: new Color("#38BDF8")      // Xanh dương CAPI Fallback
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
// DATA ENGINE
// ==========================================
async function fetchPoolData() {
  const fm = FileManager.local();
  const path = fm.joinPath(orbiter.cacheDir, `${CONFIG.CACHE_KEY}.json`);
  let cache = null;
  if (fm.fileExists(path)) {
    try { cache = JSON.parse(fm.readString(path)); } catch (_) {}
  }

  try {
    const pool = await orbiter.api("/v1/pool-status");
    if (pool && pool.accounts) {
      const data = { pool, time: Date.now(), online: true };
      try { fm.writeString(path, JSON.stringify(data)); } catch (_) {}
      return data;
    }
  } catch (err) {
    console.log("[Orbiter Claude] Lỗi kết nối HTTP qua Tailscale: " + err);
  }

  if (cache) {
    cache.online = false;
    return cache;
  }
  return { pool: null, time: null, online: false };
}

// ==========================================
// DRAWING: FULL-WIDTH SEGMENTED BAR
// ==========================================
function drawSegmentedBar(width, height, percent, fillColor, pacePercent) {
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

  // 1. Rãnh xám nền
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

  // 3. Vạch nhịp độ an toàn (Safe Pace Line)
  if (pacePercent !== undefined && pacePercent !== null) {
    const clampedPace = Math.max(0, Math.min(100, pacePercent));
    const targetPx = (totalFillable * clampedPace) / 100;
    let segIdx = Math.floor(targetPx / segW);
    segIdx = Math.max(0, Math.min(numSegments - 1, segIdx));
    const localX = targetPx - (segIdx * segW);
    const lineX = (segIdx * (segW + gap)) + localX;

    const linePath = new Path();
    linePath.addRoundedRect(new Rect(Math.max(0, lineX - 0.75), 0, 1.5, height), 0.75, 0.75);
    dc.addPath(linePath);
    dc.setFillColor(TOKENS.greenPace);
    dc.fillPath();
  }

  return dc.getImage();
}

function getWidgetContentWidth(family, hPadding) {
  const sw = Math.min(Device.screenSize().width, Device.screenSize().height);
  let totalW = 344;
  if (sw <= 375) totalW = 321;
  else if (sw <= 393) totalW = 338;
  else if (sw <= 402) totalW = 344;
  else if (sw <= 414) totalW = 360;
  else totalW = 364; // Pro Max / Plus
  return Math.round(totalW - (hPadding * 2));
}

// ==========================================
// LARGE WIDGET BUILDER (4X4 - FULL POOL)
// ==========================================
function buildLargeWidget(w, data) {
  const hPadding = 14;
  w.setPadding(13, hPadding, 12, hPadding);

  const isOnline = data.online !== false;
  const rawAccounts = data.pool?.accounts || [];
  const accounts = rawAccounts.length > 0 ? rawAccounts : [
    { name: "trthuhuyen2712@gmail.com", email: "trthuhuyen2712@gmail.com", plan: "Max 5x", used_5h: 8, remaining_5h: 92, reset_5h: "4h 54m", used_weekly: 82, remaining_weekly: 18, reset_weekly: "1d 8h", is_available: true, lifecycle_status: "critical", lifecycle_label: "Hết hạn sau 2d 7h" },
    { name: "projecttoncorporation@gmail.com", email: "projecttoncorporation@gmail.com", plan: "Max 20x", used_5h: 0, remaining_5h: 100, reset_5h: "3h 4m", used_weekly: 67, remaining_weekly: 33, reset_weekly: "2d 11h", is_available: true, lifecycle_status: "warning", lifecycle_label: "Hết hạn sau 5d" },
    { name: "projectplayground2025@gmail.com", email: "projectplayground2025@gmail.com", plan: "Paused", used_5h: 100, remaining_5h: 0, reset_5h: "", used_weekly: 100, remaining_weekly: 0, reset_weekly: "Cần login lại", is_available: false, lifecycle_status: "expired", lifecycle_label: "Đã quá hạn 30 ngày" }
  ];
  const contentW = getWidgetContentWidth("large", hPadding);

  // --- 1. WIDGET HEADER (100% ORBITER MACOS DESKTOP) ---
  const firstAcc = accounts[0] || {};

  const hRow1 = w.addStack();
  hRow1.layoutHorizontally();
  hRow1.centerAlignContent();

  const titleStack = hRow1.addStack();
  titleStack.layoutHorizontally();
  titleStack.centerAlignContent();
  titleStack.spacing = 6;

  const icon = titleStack.addImage(getClaudeIcon());
  icon.imageSize = new Size(16, 16);
  icon.tintColor = TOKENS.orangeFill;

  const title = titleStack.addText("Claude");
  title.font = Font.boldSystemFont(16);
  title.textColor = TOKENS.textPrimary;

  hRow1.addSpacer();

  const hEmail = hRow1.addText(firstAcc.email || firstAcc.name || "");
  hEmail.font = Font.systemFont(12);
  hEmail.textColor = TOKENS.textSecondary;
  hEmail.lineLimit = 1;

  w.addSpacer(2.5);

  const hRow2 = w.addStack();
  hRow2.layoutHorizontally();
  hRow2.centerAlignContent();

  addSyncTimeElement(hRow2, data.time, isOnline);

  hRow2.addSpacer();

  const hPlan = hRow2.addText(`Gói ${firstAcc.plan || "Max 5x"}`);
  hPlan.font = Font.systemFont(11);
  hPlan.textColor = TOKENS.textSecondary;

  w.addSpacer(7);

  // Hairline Divider sau Header
  const headerDiv = w.addStack();
  headerDiv.size = new Size(0, 0.5);
  headerDiv.backgroundColor = TOKENS.cardBorder;

  w.addSpacer(8);

  // --- 2. HIỂN THỊ CẢ 3 TÀI KHOẢN (ĐỒNG BỘ 100% ORBITER MACOS) ---
  const displayAccounts = accounts.slice(0, 3);

  displayAccounts.forEach((acc, idx) => {
    const isFirst = idx === 0;
    const realNum = idx + 1;
    const isPaused = acc.is_available === false;

    const accStack = w.addStack();
    accStack.layoutVertically();

    // --- A. ACCOUNT HEADER ROW ---
    const accHead = accStack.addStack();
    accHead.layoutHorizontally();
    accHead.centerAlignContent();

    // Priority badge (star cho #1)
    if (isFirst) {
      try {
        const starSym = SFSymbol.named("star.fill");
        starSym.applyFont(Font.systemFont(11.5));
        const starImg = accHead.addImage(starSym.image);
        starImg.imageSize = new Size(11.5, 11.5);
        starImg.tintColor = TOKENS.orangeFill;
        accHead.addSpacer(3.5);
      } catch (_) {}
    }

    const idBadge = accHead.addText(isFirst ? "#1 " : `#${realNum} `);
    idBadge.font = Font.boldMonospacedSystemFont(isFirst ? 13 : 12);
    idBadge.textColor = isFirst ? TOKENS.orangeFill : TOKENS.textSecondary;

    const displayEmail = (acc.email || acc.name || "").replace("@gmail.com", "");
    const emailTxt = accHead.addText(displayEmail);
    emailTxt.font = Font.boldSystemFont(isFirst ? 12.5 : 12);
    emailTxt.textColor = isPaused ? TOKENS.textMuted : TOKENS.textPrimary;
    emailTxt.lineLimit = 1;

    accHead.addSpacer(4);

    const planTxt = accHead.addText(`· ${acc.plan || "Max"}`);
    planTxt.font = Font.systemFont(10.5);
    planTxt.textColor = TOKENS.textMuted;

    accHead.addSpacer();

    // Status Badge & 30-Day Lifecycle Alert
    const statusStack = accHead.addStack();
    statusStack.layoutHorizontally();
    statusStack.centerAlignContent();
    statusStack.spacing = 3.5;

    if (acc.lifecycle_status === "critical") {
      const warnTxt = statusStack.addText(`⚠️ ${acc.lifecycle_label || "Sắp hết hạn"}`);
      warnTxt.font = Font.boldSystemFont(10);
      warnTxt.textColor = TOKENS.amberWarn;
    } else if (acc.lifecycle_status === "warning") {
      const warnTxt = statusStack.addText(`ℹ️ ${acc.lifecycle_label || "Còn 5d"}`);
      warnTxt.font = Font.systemFont(9.5);
      warnTxt.textColor = TOKENS.textSecondary;
    } else if (isPaused) {
      try {
        const errSym = SFSymbol.named("xmark.circle.fill");
        errSym.applyFont(Font.systemFont(9.5));
        const errImg = statusStack.addImage(errSym.image);
        errImg.imageSize = new Size(9.5, 9.5);
        errImg.tintColor = TOKENS.redAlert;
      } catch (_) {}
      const s = statusStack.addText("Tạm dừng");
      s.font = Font.boldSystemFont(10);
      s.textColor = TOKENS.redAlert;
    } else {
      try {
        const okSym = SFSymbol.named("checkmark.circle.fill");
        okSym.applyFont(Font.systemFont(9.5));
        const okImg = statusStack.addImage(okSym.image);
        okImg.imageSize = new Size(9.5, 9.5);
        okImg.tintColor = TOKENS.greenPace;
      } catch (_) {}
      const s = statusStack.addText(isFirst ? "Đang dùng" : "Sẵn sàng");
      s.font = Font.boldSystemFont(10);
      s.textColor = TOKENS.greenPace;
    }

    accStack.addSpacer(isFirst ? 5 : 4);

    if (isPaused) {
      // Dòng tóm tắt cho tài khoản bị cách ly
      const noticeRow = accStack.addStack();
      noticeRow.layoutHorizontally();
      noticeRow.centerAlignContent();
      noticeRow.spacing = 4;

      try {
        const lockSym = SFSymbol.named("lock.fill");
        lockSym.applyFont(Font.systemFont(9.5));
        const lockImg = noticeRow.addImage(lockSym.image);
        lockImg.imageSize = new Size(9.5, 9.5);
        lockImg.tintColor = TOKENS.amberWarn;
      } catch (_) {}

      const pausedNotice = noticeRow.addText("OAuth token hết hạn 30 ngày · Cần re-auth trên Ubuntu");
      pausedNotice.font = Font.systemFont(9.5);
      pausedNotice.textColor = TOKENS.textMuted;
      accStack.addSpacer(2);
    } else {
      // --- B. METRIC 1: PHIÊN 5H ---
      const p5Row = accStack.addStack();
      p5Row.layoutHorizontally();
      p5Row.centerAlignContent();

      const p5Label = p5Row.addText(`Phiên 5h: ${acc.used_5h ?? 0}% đã dùng`);
      p5Label.font = Font.boldSystemFont(isFirst ? 12 : 11);
      p5Label.textColor = TOKENS.textPrimary;

      p5Row.addSpacer();

      const r5Est = formatResetWithEst(acc.reset_5h);
      const p5Reset = p5Row.addText(r5Est || (acc.reset_5h ? `Đặt lại: ${acc.reset_5h}` : ""));
      p5Reset.font = Font.systemFont(isFirst ? 10 : 9.5);
      p5Reset.textColor = TOKENS.textSecondary;

      accStack.addSpacer(3.5);

      const bar5Height = isFirst ? 5.5 : 4.5;
      const bar5 = drawSegmentedBar(contentW, bar5Height, acc.used_5h ?? 0, TOKENS.orangeFill, isFirst ? acc.remaining_5h : null);
      const v5 = accStack.addImage(bar5);
      v5.imageSize = new Size(contentW, bar5Height);
      v5.leftAlignImage();

      // DÒNG NHỊP ĐỘ AN TOÀN (ĐỒNG BỘ 100% ORBITER MACOS DESKTOP: "90% dự trữ nhịp độ")
      if (isFirst && acc.remaining_5h !== undefined && acc.remaining_5h !== null) {
        accStack.addSpacer(2.5);
        const paceSub = accStack.addText(`${acc.remaining_5h}% dự trữ nhịp độ`);
        paceSub.font = Font.systemFont(9.5);
        paceSub.textColor = TOKENS.textMuted;
        accStack.addSpacer(5.5);
      } else {
        accStack.addSpacer(5);
      }

      // --- C. METRIC 2: HÀNG TUẦN ---
      const pWkRow = accStack.addStack();
      pWkRow.layoutHorizontally();
      pWkRow.centerAlignContent();

      const pWkLabel = pWkRow.addText(`Hàng tuần: ${acc.used_weekly ?? 0}% đã dùng`);
      pWkLabel.font = Font.boldSystemFont(isFirst ? 12 : 11);
      pWkLabel.textColor = TOKENS.textPrimary;

      pWkRow.addSpacer();

      const rWkEst = formatResetWithEst(acc.reset_weekly);
      const pWkReset = pWkRow.addText(rWkEst || (acc.reset_weekly ? `Đặt lại: ${acc.reset_weekly}` : ""));
      pWkReset.font = Font.systemFont(isFirst ? 10 : 9.5);
      pWkReset.textColor = TOKENS.textSecondary;

      accStack.addSpacer(3.5);

      const barWkHeight = isFirst ? 5.5 : 4.5;
      const barWk = drawSegmentedBar(contentW, barWkHeight, acc.used_weekly ?? 0, TOKENS.orangeFill, null);
      const vWk = accStack.addImage(barWk);
      vWk.imageSize = new Size(contentW, barWkHeight);
      vWk.leftAlignImage();
    }

    // Hairline Divider giữa các tài khoản
    if (idx < displayAccounts.length - 1) {
      w.addSpacer(7);
      const accDiv = w.addStack();
      accDiv.size = new Size(0, 0.5);
      accDiv.backgroundColor = TOKENS.cardBorder;
      w.addSpacer(7);
    }
  });

  w.addSpacer(); // Flexible spring spacer phân bổ đều khoảng trống

  // Hairline Divider trước Footer
  const footerDiv = w.addStack();
  footerDiv.size = new Size(0, 0.5);
  footerDiv.backgroundColor = TOKENS.cardBorder;

  w.addSpacer(6);

  // --- 3. FOOTER: CHỐT CHẶN DỰ PHÒNG CONSOLE API (CAPI) ---
  const footerRow = w.addStack();
  footerRow.layoutHorizontally();
  footerRow.centerAlignContent();

  try {
    const keySym = SFSymbol.named("key.fill");
    keySym.applyFont(Font.systemFont(9.5));
    const keyImg = footerRow.addImage(keySym.image);
    keyImg.imageSize = new Size(9.5, 9.5);
    keyImg.tintColor = TOKENS.blueCapi;
    footerRow.addSpacer(3.5);
  } catch (_) {}

  const fTitle = footerRow.addText("Console API Fallback (capi)");
  fTitle.font = Font.systemFont(9.5);
  fTitle.textColor = TOKENS.textSecondary;

  footerRow.addSpacer();

  const gw = data.pool?.gateway || {};
  const isCapiOnline = gw.is_active_now !== false;
  let capiText = "Sẵn sàng trực tuyến";
  if (gw.last_active_human) {
    capiText = gw.last_active_human;
  }

  const fStatus = footerRow.addText(capiText);
  fStatus.font = Font.boldSystemFont(9.5);
  fStatus.textColor = isCapiOnline ? TOKENS.blueCapi : TOKENS.redAlert;
}

// ==========================================
// MAIN ENTRY
// ==========================================
function drawRing(percent) {
  const size = 58;
  const line = 6;
  const r = (size - line) / 2;
  const c = size / 2;
  const ctx = new DrawContext();
  ctx.size = new Size(size, size);
  ctx.opaque = false;
  ctx.respectScreenScale = true;
  const arc = (from, to, color) => {
    const path = new Path();
    const steps = Math.max(2, Math.ceil((to - from) * 90));
    for (let i = 0; i <= steps; i++) {
      const t = (-0.25 + from + ((to - from) * i) / steps) * 2 * Math.PI;
      const p = new Point(c + r * Math.cos(t), c + r * Math.sin(t));
      if (i === 0) path.move(p);
      else path.addLine(p);
    }
    ctx.addPath(path);
    ctx.setStrokeColor(color);
    ctx.setLineWidth(line);
    ctx.strokePath();
  };
  arc(0, 1, new Color("#FFFFFF", 0.25));
  const p = Math.min(1, Math.max(0, (percent || 0) / 100));
  if (p > 0) arc(0, p, Color.white());
  return ctx.getImage();
}

function buildAccessoryWidget(w, data, Control) {
  const act = data.pool ? Control.activeAccount(data.pool) : null;
  const online = data.online !== false;
  if (orbiter.family === "accessoryInline") {
    w.addText(act ? `Claude 5h ${Control.pct(act.used_5h)} · tuần ${Control.pct(act.used_weekly)}` : "Claude: không có dữ liệu");
    return;
  }
  w.addAccessoryWidgetBackground = true;
  if (orbiter.family === "accessoryCircular") {
    const stack = w.addStack();
    stack.layoutVertically();
    stack.centerAlignContent();
    const img = stack.addImage(drawRing(act ? act.used_5h : 0));
    img.imageSize = new Size(44, 44);
    const t = w.addText(act ? `${act.used_5h}%` : "-");
    t.font = Font.boldSystemFont(11);
    t.centerAlignText();
    return;
  }
  const title = w.addText(act ? `${Control.shortName(act)}${online ? "" : " · offline"}` : "Claude pool");
  title.font = Font.boldSystemFont(13);
  title.lineLimit = 1;
  const quota = w.addText(act ? `5h ${Control.pct(act.used_5h)} · tuần ${Control.pct(act.used_weekly)}` : "Không có account đang bật");
  quota.font = Font.systemFont(13);
  const detail = w.addText(act ? formatResetWithEst(act.reset_5h) || act.lifecycle_label || "" : "");
  detail.font = Font.systemFont(11);
  detail.lineLimit = 1;
}

async function buildWidget(data, Control) {
  const w = new ListWidget();
  if (String(orbiter.family || "").startsWith("accessory")) {
    buildAccessoryWidget(w, data, Control);
  } else {
    const grad = new LinearGradient();
    grad.locations = [0.0, 1.0];
    grad.colors = [TOKENS.bgTop, TOKENS.bgBtm];
    w.backgroundGradient = grad;
    buildLargeWidget(w, data);
  }
  w.url = Control.withQuery(orbiter.runURL, "action=control");
  w.refreshAfterDate = new Date(Date.now() + CONFIG.REFRESH_MIN * 60 * 1000);
  return w;
}

async function main() {
  const Control = await orbiter.load("OrbiterControl.js");
  if (orbiter.mode === "shortcut" || orbiter.mode === "siri") {
    await Control.shortcut(orbiter.input);
    return;
  }
  const preview = async () => (await buildWidget(await fetchPoolData(), Control)).presentLarge();
  if (orbiter.mode === "app") {
    if (orbiter.params.action === "preview") await preview();
    else await Control.controlPanel({ preview });
    return;
  }
  const data = await fetchPoolData();
  Script.setWidget(await buildWidget(data, Control));
  if (data.online && data.pool) {
    try {
      await Control.notify(data.pool);
    } catch (e) {
      console.log(`[Orbiter Claude] notify: ${e}`);
    }
  }
}

await main();
