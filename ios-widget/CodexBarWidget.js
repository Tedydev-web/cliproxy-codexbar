// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: purple; icon-glyph: server;
/**
 * CodexBar iOS Widget - Pure Claude Pool Quota
 * Apple HIG Minimalist Design (Không hiển thị monitor hệ thống)
 * Rộng rãi, hiển thị đầy đủ chi tiết Quota của các tài khoản Claude
 */

const CONFIG = {
  HOST: "100.127.1.234",
  PORT: "8318",
  TIMEOUT: 4,
  REFRESH_MIN: 10,
  CACHE_KEY: "codexbar_pure_quota_v5"
};

const URL_POOL = `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/pool-status`;

// Bảng màu Apple Design System
const C_BG_TOP = new Color("#1C1C1E");
const C_BG_BTM = new Color("#0C0C0E");
const C_CARD = new Color("#2C2C2E", 0.65);

const C_TXT_PRIMARY = new Color("#FFFFFF", 0.95);
const C_TXT_MUTED = new Color("#8E8E93");
const C_GREEN = new Color("#30D158");
const C_ORANGE = new Color("#FF9F0A");
const C_BLUE = new Color("#0A84FF");
const C_RED = new Color("#FF453A");

async function fetchData() {
  const fm = FileManager.local();
  const path = fm.joinPath(fm.documentsDirectory(), `${CONFIG.CACHE_KEY}.json`);
  let cache = null;
  if (fm.fileExists(path)) {
    try { cache = JSON.parse(fm.readString(path)); } catch (_) {}
  }

  try {
    const r = new Request(URL_POOL);
    r.timeoutInterval = CONFIG.TIMEOUT;
    const pool = await r.loadJSON();
    if (pool) {
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

function getQuotaColor(pct) {
  if (pct > 40) return C_GREEN;
  if (pct > 15) return C_ORANGE;
  return C_RED;
}

// -------------------------------------------------------------
// 1. MEDIUM WIDGET (2 Cột Quota cho 2 Tài Khoản Ưu Tiên)
// -------------------------------------------------------------
function buildMedium(w, data) {
  w.setPadding(14, 16, 14, 16);

  // Header Bar
  const h = w.addStack();
  h.layoutHorizontally();
  h.centerAlignContent();

  const title = h.addText("CLAUDE QUOTA POOL");
  title.font = Font.boldSystemFont(11);
  title.textColor = C_TXT_PRIMARY;

  h.addSpacer(6);

  const status = h.addText(data.online ? "● SYNCED" : "○ OFFLINE");
  status.font = Font.systemFont(10);
  status.textColor = data.online ? C_GREEN : C_RED;

  h.addSpacer();

  const timeStr = data.time ? new Date(data.time).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" }) : "--:--";
  const syncTxt = h.addText(timeStr);
  syncTxt.font = Font.systemFont(10);
  syncTxt.textColor = C_TXT_MUTED;

  w.addSpacer(10);

  // Dual Account Cards Row
  const row = w.addStack();
  row.layoutHorizontally();
  row.spacing = 10;

  const accounts = data.pool?.accounts || [];
  const acc1 = accounts[0];
  const acc2 = accounts[1];

  const renderCard = (parent, acc, isPrimary) => {
    const card = parent.addStack();
    card.backgroundColor = C_CARD;
    card.cornerRadius = 10;
    card.setPadding(10, 12, 10, 12);

    if (!acc) {
      const empty = card.addText("Trống");
      empty.font = Font.systemFont(11);
      empty.textColor = C_TXT_MUTED;
      return;
    }

    // Title Row: Star/Badge + Name
    const top = card.addStack();
    top.layoutHorizontally();
    const prefix = isPrimary ? "★ " : "#2 ";
    const nameTxt = top.addText(`${prefix}${acc.name.split("@")[0]}`);
    nameTxt.font = Font.boldSystemFont(11);
    nameTxt.textColor = isPrimary ? C_ORANGE : C_TXT_PRIMARY;
    nameTxt.lineLimit = 1;
    top.addSpacer();
    const planTxt = top.addText(acc.plan || "Max");
    planTxt.font = Font.systemFont(9);
    planTxt.textColor = C_TXT_MUTED;

    card.addSpacer(6);

    // 5h Quota Row
    const q5Row = card.addStack();
    q5Row.layoutHorizontally();
    const q5L = q5Row.addText("5h Quota");
    q5L.font = Font.systemFont(11);
    q5L.textColor = C_TXT_MUTED;
    q5Row.addSpacer();
    const q5V = q5Row.addText(`${acc.remaining_5h}%`);
    q5V.font = Font.boldSystemFont(13);
    q5V.textColor = getQuotaColor(acc.remaining_5h);

    card.addSpacer(3);

    // Reset 5h
    const r5Row = card.addStack();
    r5Row.layoutHorizontally();
    const r5L = r5Row.addText("Reset trong");
    r5L.font = Font.systemFont(9);
    r5L.textColor = C_TXT_MUTED;
    r5Row.addSpacer();
    const r5V = r5Row.addText(acc.reset_5h || "--");
    r5V.font = Font.systemFont(9);
    r5V.textColor = C_TXT_MUTED;

    card.addSpacer(5);

    // Weekly Quota Row
    const wkRow = card.addStack();
    wkRow.layoutHorizontally();
    const wkL = wkRow.addText("Weekly");
    wkL.font = Font.systemFont(11);
    wkL.textColor = C_TXT_MUTED;
    wkRow.addSpacer();
    const wkV = wkRow.addText(`${acc.remaining_weekly}%`);
    wkV.font = Font.boldSystemFont(12);
    wkV.textColor = C_BLUE;
  };

  renderCard(row, acc1, true);
  renderCard(row, acc2, false);
}

// -------------------------------------------------------------
// 2. SMALL WIDGET (Tập trung toàn lực vào Quota Account #1)
// -------------------------------------------------------------
function buildSmall(w, data) {
  w.setPadding(14, 14, 14, 14);

  const h = w.addStack();
  h.layoutHorizontally();
  const t = h.addText("CLAUDE QUOTA");
  t.font = Font.boldSystemFont(10);
  t.textColor = C_TXT_MUTED;
  h.addSpacer();
  const st = h.addText(data.online ? "●" : "○");
  st.textColor = data.online ? C_GREEN : C_RED;
  st.font = Font.systemFont(10);

  w.addSpacer(10);

  const acc = data.pool?.accounts?.[0];
  if (acc) {
    const card = w.addStack();
    card.backgroundColor = C_CARD;
    card.cornerRadius = 8;
    card.setPadding(8, 10, 8, 10);

    const n = card.addText(`★ ${acc.name.split("@")[0]}`);
    n.font = Font.boldSystemFont(11);
    n.textColor = C_ORANGE;
    n.lineLimit = 1;

    card.addSpacer(6);

    const q5Row = card.addStack();
    q5Row.layoutHorizontally();
    const q5L = q5Row.addText("5h:");
    q5L.font = Font.systemFont(11);
    q5L.textColor = C_TXT_MUTED;
    q5Row.addSpacer();
    const q5V = q5Row.addText(`${acc.remaining_5h}%`);
    q5V.font = Font.boldSystemFont(13);
    q5V.textColor = getQuotaColor(acc.remaining_5h);

    card.addSpacer(2);

    const r5 = card.addText(`Reset trong ${acc.reset_5h || "--"}`);
    r5.font = Font.systemFont(9);
    r5.textColor = C_TXT_MUTED;

    card.addSpacer(6);

    const wkRow = card.addStack();
    wkRow.layoutHorizontally();
    const wkL = wkRow.addText("Weekly:");
    wkL.font = Font.systemFont(11);
    wkL.textColor = C_TXT_MUTED;
    wkRow.addSpacer();
    const wkV = wkRow.addText(`${acc.remaining_weekly}%`);
    wkV.font = Font.boldSystemFont(12);
    wkV.textColor = C_BLUE;
  } else {
    const empty = w.addText("Chưa có data");
    empty.font = Font.systemFont(11);
    empty.textColor = C_TXT_MUTED;
  }
}

// -------------------------------------------------------------
// 3. LARGE WIDGET (Hiển thị trọn vẹn cả 3 tài khoản trong Pool)
// -------------------------------------------------------------
function buildLarge(w, data) {
  w.setPadding(16, 16, 16, 16);

  const h = w.addStack();
  h.layoutHorizontally();
  const t = h.addText("CLAUDE QUOTA COMMAND");
  t.font = Font.boldSystemFont(12);
  t.textColor = C_TXT_PRIMARY;
  h.addSpacer();
  const st = h.addText(data.online ? "● ACTIVE" : "○ OFFLINE");
  st.textColor = data.online ? C_GREEN : C_RED;
  st.font = Font.boldSystemFont(10);

  w.addSpacer(12);

  const accounts = data.pool?.accounts?.slice(0, 3) || [];
  accounts.forEach((acc, idx) => {
    const card = w.addStack();
    card.backgroundColor = C_CARD;
    card.cornerRadius = 10;
    card.setPadding(10, 12, 10, 12);

    const top = card.addStack();
    top.layoutHorizontally();
    const nameTxt = top.addText(`${idx === 0 ? "★ " : `#${idx+1} `}${acc.name.split("@")[0]}`);
    nameTxt.font = Font.boldSystemFont(12);
    nameTxt.textColor = idx === 0 ? C_ORANGE : C_TXT_PRIMARY;
    nameTxt.lineLimit = 1;
    top.addSpacer();
    const badge = top.addText(acc.plan || "Max");
    badge.font = Font.systemFont(10);
    badge.textColor = C_TXT_MUTED;

    card.addSpacer(6);

    const row = card.addStack();
    row.layoutHorizontally();

    const q5 = row.addText(`5h: ${acc.remaining_5h}% (${acc.reset_5h})`);
    q5.font = Font.boldSystemFont(12);
    q5.textColor = getQuotaColor(acc.remaining_5h);

    row.addSpacer();

    const wk = row.addText(`Weekly: ${acc.remaining_weekly}% (${acc.reset_weekly})`);
    wk.font = Font.boldSystemFont(12);
    wk.textColor = C_BLUE;

    w.addSpacer(8);
  });

  w.addSpacer();
  const foot = w.addStack();
  foot.layoutHorizontally();
  const sync = foot.addText(`Đồng bộ: ${data.time ? new Date(data.time).toLocaleTimeString("vi-VN", {hour: "2-digit", minute: "2-digit"}) : "--"}`);
  sync.font = Font.systemFont(9);
  sync.textColor = C_TXT_MUTED;
}

// -------------------------------------------------------------
// MAIN ENTRY
// -------------------------------------------------------------
async function main() {
  const w = new ListWidget();
  const grad = new LinearGradient();
  grad.locations = [0.0, 1.0];
  grad.colors = [C_BG_TOP, C_BG_BTM];
  w.backgroundGradient = grad;

  const data = await fetchData();
  const family = config.widgetFamily || "medium";

  if (family === "small") {
    buildSmall(w, data);
  } else if (family === "large") {
    buildLarge(w, data);
  } else {
    buildMedium(w, data);
  }

  w.refreshAfterDate = new Date(Date.now() + CONFIG.REFRESH_MIN * 60 * 1000);
  return w;
}

const w = await main();
if (config.runsInWidget) {
  Script.setWidget(w);
} else {
  w.presentMedium();
}
Script.complete();
