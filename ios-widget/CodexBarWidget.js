// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: purple; icon-glyph: server;
/**
 * CodexBar iOS Widget - Minimal Apple Design
 * Chạy ổn định trên Scriptable iOS
 */

const CONFIG = {
  HOST: "100.127.1.234",
  PORT: "8318",
  TIMEOUT: 4,
  REFRESH_MIN: 10,
  CACHE_KEY: "codexbar_stable_v4"
};

const URL_POOL = `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/pool-status`;
const URL_SYS = `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/system-telemetry`;

// Màu chuẩn Apple
const C_BG_TOP = new Color("#1C1C1E");
const C_BG_BTM = new Color("#0C0C0E");
const C_CARD = new Color("#2C2C2E", 0.7);

const C_TXT_PRIMARY = new Color("#FFFFFF", 0.95);
const C_TXT_MUTED = new Color("#8E8E93");
const C_GREEN = new Color("#30D158");
const C_ORANGE = new Color("#FF9F0A");
const C_BLUE = new Color("#0A84FF");
const C_RED = new Color("#FF453A");
const C_TEAL = new Color("#64D2FF");

async function fetchData() {
  const fm = FileManager.local();
  const path = fm.joinPath(fm.documentsDirectory(), `${CONFIG.CACHE_KEY}.json`);
  let cache = null;
  if (fm.fileExists(path)) {
    try { cache = JSON.parse(fm.readString(path)); } catch (_) {}
  }

  const req = async (u) => {
    try {
      const r = new Request(u);
      r.timeoutInterval = CONFIG.TIMEOUT;
      return await r.loadJSON();
    } catch (_) { return null; }
  };

  const [pool, sys] = await Promise.all([req(URL_POOL), req(URL_SYS)]);
  if (pool || sys) {
    const data = {
      pool: pool || cache?.pool,
      sys: sys || cache?.sys,
      time: Date.now(),
      online: true
    };
    try { fm.writeString(path, JSON.stringify(data)); } catch (_) {}
    return data;
  }

  if (cache) {
    cache.online = false;
    return cache;
  }
  return { pool: null, sys: null, time: null, online: false };
}

function getQuotaColor(pct) {
  if (pct > 40) return C_GREEN;
  if (pct > 15) return C_ORANGE;
  return C_RED;
}

// -------------------------------------------------------------
// MEDIUM WIDGET (Kích thước chữ nhật ngang mặc định)
// -------------------------------------------------------------
function buildMedium(w, data) {
  w.setPadding(14, 16, 14, 16);

  // 1. HEADER ROW
  const h = w.addStack();
  h.layoutHorizontally();
  h.centerAlignContent();

  const title = h.addText("⚡ CODEXBAR");
  title.font = Font.boldSystemFont(11);
  title.textColor = C_TXT_PRIMARY;

  h.addSpacer(6);

  const status = h.addText(data.online ? "● ON" : "○ OFF");
  status.font = Font.systemFont(10);
  status.textColor = data.online ? C_GREEN : C_RED;

  h.addSpacer();

  const timeStr = data.time ? new Date(data.time).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" }) : "--:--";
  const syncTxt = h.addText(`Sync ${timeStr}`);
  syncTxt.font = Font.systemFont(10);
  syncTxt.textColor = C_TXT_MUTED;

  w.addSpacer(10);

  // 2. DUAL CARDS ROW
  const row = w.addStack();
  row.layoutHorizontally();
  row.spacing = 10;

  const m = data.sys?.metrics;
  const acc1 = data.pool?.accounts?.[0];
  const acc2 = data.pool?.accounts?.[1];

  // CARD 1: HOST TELEMETRY
  const card1 = row.addStack();
  card1.backgroundColor = C_CARD;
  card1.cornerRadius = 10;
  card1.setPadding(10, 12, 10, 12);

  const c1Top = card1.addStack();
  c1Top.layoutHorizontally();
  const c1T = c1Top.addText("UBUNTU");
  c1T.font = Font.boldSystemFont(10);
  c1T.textColor = C_TXT_MUTED;
  c1Top.addSpacer();
  const upT = c1Top.addText(m?.uptime || "11d");
  upT.font = Font.systemFont(9);
  upT.textColor = C_TXT_MUTED;

  card1.addSpacer(6);

  const cpuRow = card1.addStack();
  cpuRow.layoutHorizontally();
  const cpuL = cpuRow.addText("CPU");
  cpuL.font = Font.systemFont(12);
  cpuL.textColor = C_TXT_MUTED;
  cpuRow.addSpacer();
  const cpuV = cpuRow.addText(`${m ? m.cpu_percent.toFixed(1) : "--"}%`);
  cpuV.font = Font.boldSystemFont(13);
  cpuV.textColor = C_TXT_PRIMARY;

  card1.addSpacer(4);

  const ramRow = card1.addStack();
  ramRow.layoutHorizontally();
  const ramL = ramRow.addText("RAM");
  ramL.font = Font.systemFont(12);
  ramL.textColor = C_TXT_MUTED;
  ramRow.addSpacer();
  const ramV = ramRow.addText(`${m ? m.ram_percent.toFixed(0) : "--"}%`);
  ramV.font = Font.boldSystemFont(13);
  ramV.textColor = C_TEAL;

  // CARD 2: CLAUDE QUOTA
  const card2 = row.addStack();
  card2.backgroundColor = C_CARD;
  card2.cornerRadius = 10;
  card2.setPadding(10, 12, 10, 12);

  if (acc1) {
    const a1Row = card2.addStack();
    a1Row.layoutHorizontally();
    const a1Name = a1Row.addText(`★ ${acc1.name.split("@")[0]}`);
    a1Name.font = Font.boldSystemFont(11);
    a1Name.textColor = C_ORANGE;
    a1Name.lineLimit = 1;
    a1Row.addSpacer();
    const a1Plan = a1Row.addText(acc1.plan || "Max 20x");
    a1Plan.font = Font.systemFont(9);
    a1Plan.textColor = C_TXT_MUTED;

    card2.addSpacer(6);

    const q1Row = card2.addStack();
    q1Row.layoutHorizontally();
    const q1Val = q1Row.addText(`5h: ${acc1.remaining_5h}%`);
    q1Val.font = Font.boldSystemFont(12);
    q1Val.textColor = getQuotaColor(acc1.remaining_5h);
    q1Row.addSpacer();
    const q1Reset = q1Row.addText(`Reset ${acc1.reset_5h || ""}`);
    q1Reset.font = Font.systemFont(10);
    q1Reset.textColor = C_TXT_MUTED;

    card2.addSpacer(4);

    const q2Row = card2.addStack();
    q2Row.layoutHorizontally();
    const q2Val = q2Row.addText(`Wk: ${acc1.remaining_weekly}%`);
    q2Val.font = Font.semiboldSystemFont(11);
    q2Val.textColor = C_BLUE;
    q2Row.addSpacer();
    if (acc2) {
      const a2Hint = q2Row.addText(`#2: ${acc2.remaining_5h}% (5h)`);
      a2Hint.font = Font.systemFont(9);
      a2Hint.textColor = C_TXT_MUTED;
    } else {
      const q2Reset = q2Row.addText(`Reset ${acc1.reset_weekly || ""}`);
      q2Reset.font = Font.systemFont(9);
      q2Reset.textColor = C_TXT_MUTED;
    }
  } else {
    const empty = card2.addText("Chưa có dữ liệu Quota");
    empty.font = Font.systemFont(11);
    empty.textColor = C_TXT_MUTED;
  }
}

// -------------------------------------------------------------
// SMALL WIDGET (2x2)
// -------------------------------------------------------------
function buildSmall(w, data) {
  w.setPadding(12, 12, 12, 12);
  const m = data.sys?.metrics;
  const acc = data.pool?.accounts?.[0];

  const h = w.addStack();
  h.layoutHorizontally();
  const t = h.addText("CODEXBAR");
  t.font = Font.boldSystemFont(10);
  t.textColor = C_TXT_MUTED;
  h.addSpacer();
  const st = h.addText(data.online ? "●" : "○");
  st.textColor = data.online ? C_GREEN : C_RED;
  st.font = Font.systemFont(10);

  w.addSpacer(8);

  const sys = w.addStack();
  sys.layoutHorizontally();
  sys.backgroundColor = C_CARD;
  sys.cornerRadius = 6;
  sys.setPadding(4, 6, 4, 6);
  const cT = sys.addText(`CPU ${m ? m.cpu_percent.toFixed(1) : "--"}%`);
  cT.font = Font.boldSystemFont(10);
  cT.textColor = C_TXT_PRIMARY;
  sys.addSpacer();
  const rT = sys.addText(`RAM ${m ? m.ram_percent.toFixed(0) : "--"}%`);
  rT.font = Font.boldSystemFont(10);
  rT.textColor = C_TEAL;

  w.addSpacer(8);

  if (acc) {
    const n = w.addText(`★ ${acc.name.split("@")[0]}`);
    n.font = Font.boldSystemFont(11);
    n.textColor = C_ORANGE;
    n.lineLimit = 1;

    w.addSpacer(3);

    const q5 = w.addText(`5h: ${acc.remaining_5h}% (${acc.reset_5h})`);
    q5.font = Font.systemFont(11);
    q5.textColor = getQuotaColor(acc.remaining_5h);

    w.addSpacer(2);

    const qw = w.addText(`Wk: ${acc.remaining_weekly}% (${acc.reset_weekly})`);
    qw.font = Font.systemFont(10);
    qw.textColor = C_BLUE;
  }
}

// -------------------------------------------------------------
// LARGE WIDGET (4x4)
// -------------------------------------------------------------
function buildLarge(w, data) {
  w.setPadding(16, 16, 16, 16);
  const m = data.sys?.metrics;
  const accounts = data.pool?.accounts?.slice(0, 3) || [];

  const h = w.addStack();
  h.layoutHorizontally();
  const t = h.addText("CODEXBAR COMMAND");
  t.font = Font.boldSystemFont(12);
  t.textColor = C_TXT_PRIMARY;
  h.addSpacer();
  const st = h.addText(data.online ? "● ACTIVE" : "○ OFFLINE");
  st.textColor = data.online ? C_GREEN : C_RED;
  st.font = Font.boldSystemFont(10);

  w.addSpacer(12);

  // Gauges
  const g = w.addStack();
  g.layoutHorizontally();
  g.spacing = 8;
  const addG = (label, val, sub, col) => {
    const c = g.addStack();
    c.backgroundColor = C_CARD;
    c.cornerRadius = 8;
    c.setPadding(8, 8, 8, 8);
    const lb = c.addText(label);
    lb.font = Font.systemFont(9);
    lb.textColor = C_TXT_MUTED;
    c.addSpacer(2);
    const v = c.addText(val);
    v.font = Font.boldSystemFont(14);
    v.textColor = col;
    c.addSpacer(2);
    const sb = c.addText(sub);
    sb.font = Font.systemFont(8);
    sb.textColor = C_TXT_MUTED;
  };

  addG("CPU", `${m ? m.cpu_percent.toFixed(1) : "--"}%`, `${m?.cpu_count || 12}C`, C_TXT_PRIMARY);
  addG("RAM", `${m ? m.ram_percent.toFixed(0) : "--"}%`, `${m?.ram_used_gb || "--"}G`, C_TEAL);
  addG("DISK", `${m ? m.disk_percent.toFixed(0) : "--"}%`, `${m?.disk_free_gb || "--"}G Free`, C_ORANGE);

  w.addSpacer(12);

  const accH = w.addStack();
  accH.layoutHorizontally();
  const ahT = accH.addText("CLAUDE QUOTA POOL");
  ahT.font = Font.boldSystemFont(10);
  ahT.textColor = C_TXT_MUTED;
  accH.addSpacer();
  const pCount = accH.addText(`${data.sys?.ports?.length || 0} Ports`);
  pCount.font = Font.systemFont(9);
  pCount.textColor = C_BLUE;

  w.addSpacer(6);

  accounts.forEach((acc, idx) => {
    const row = w.addStack();
    row.backgroundColor = C_CARD;
    row.cornerRadius = 8;
    row.setPadding(8, 10, 8, 10);

    const left = row.addStack();
    const nm = left.addText(`${idx === 0 ? "★ " : `#${idx+1} `}${acc.name.split("@")[0]}`);
    nm.font = Font.boldSystemFont(11);
    nm.textColor = idx === 0 ? C_ORANGE : C_TXT_PRIMARY;
    nm.lineLimit = 1;

    row.addSpacer();

    const right = row.addStack();
    right.layoutHorizontally();
    const q5 = right.addText(`5h: ${acc.remaining_5h}% `);
    q5.font = Font.semiboldSystemFont(10);
    q5.textColor = getQuotaColor(acc.remaining_5h);

    const qw = right.addText(`Wk: ${acc.remaining_weekly}%`);
    qw.font = Font.semiboldSystemFont(10);
    qw.textColor = C_BLUE;

    w.addSpacer(6);
  });

  w.addSpacer();
  const f = w.addStack();
  f.layoutHorizontally();
  const up = f.addText(`Uptime: ${m?.uptime || "--"}`);
  up.font = Font.systemFont(9);
  up.textColor = C_TXT_MUTED;
  f.addSpacer();
  const s = f.addText(`Sync: ${data.time ? new Date(data.time).toLocaleTimeString("vi-VN", {hour: "2-digit", minute: "2-digit"}) : "--"}`);
  s.font = Font.systemFont(9);
  s.textColor = C_TXT_MUTED;
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
