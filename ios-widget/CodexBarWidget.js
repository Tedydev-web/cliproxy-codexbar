// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: purple; icon-glyph: server;
/**
 * CodexBar & CLIProxy Quota / Telemetry Widget for iOS
 * Refined Apple Design System (Dark Glassmorphism & High-Legibility Layout)
 * Supports: Small, Medium, Large
 */

// ==========================================
// 1. CẤU HÌNH & KẾT NỐI
// ==========================================
const CONFIG = {
  HOST: "100.127.1.234", // IP Tailscale Ubuntu Host
  PORT: "8318",
  TIMEOUT_SECONDS: 4,
  REFRESH_INTERVAL_MINUTES: 10,
  CACHE_KEY: "codexbar_ios_v3"
};

const URLS = {
  POOL: `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/pool-status`,
  TELEMETRY: `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/system-telemetry`
};

// ==========================================
// 2. DESIGN TOKENS (Apple Dark Palette)
// ==========================================
const THEME = {
  bgStart: new Color("#1C1C1E"),
  bgEnd: new Color("#0A0A0C"),
  cardBg: new Color("#2C2C2E", 0.65),
  hairline: new Color("#FFFFFF", 0.12),
  
  // Apple Dynamic Labels
  textPrimary: new Color("#FFFFFF", 0.95),
  textSecondary: new Color("#EBEBF5", 0.65),
  textTertiary: new Color("#EBEBF5", 0.40),
  
  // Apple Accents
  green: new Color("#30D158"),
  orange: new Color("#FF9F0A"),
  blue: new Color("#0A84FF"),
  red: new Color("#FF453A"),
  teal: new Color("#64D2FF"),
  trackGray: new Color("#3A3A3C", 0.7)
};

// ==========================================
// 3. FETCH & CACHE DỮ LIỆU
// ==========================================
async function loadData() {
  const fm = FileManager.local();
  const cacheFile = fm.joinPath(fm.documentsDirectory(), `${CONFIG.CACHE_KEY}.json`);

  let cached = null;
  if (fm.fileExists(cacheFile)) {
    try {
      cached = JSON.parse(fm.readString(cacheFile));
    } catch (_) {}
  }

  const fetchJson = async (url) => {
    try {
      const r = new Request(url);
      r.timeoutInterval = CONFIG.TIMEOUT_SECONDS;
      return await r.loadJSON();
    } catch (_) {
      return null;
    }
  };

  const [pool, sys] = await Promise.all([
    fetchJson(URLS.POOL),
    fetchJson(URLS.TELEMETRY)
  ]);

  if (pool || sys) {
    const data = {
      pool: pool || (cached ? cached.pool : null),
      sys: sys || (cached ? cached.sys : null),
      time: Date.now(),
      online: true
    };
    try { fm.writeString(cacheFile, JSON.stringify(data)); } catch (_) {}
    return data;
  }

  if (cached) {
    cached.online = false;
    return cached;
  }

  return { pool: null, sys: null, time: null, online: false };
}

// ==========================================
// 4. TIỆN ÍCH VẼ CAPSULE PROGRESS BAR
// ==========================================
function createProgressBar(width, height, percent, color) {
  const dc = new DrawContext();
  dc.size = new Size(width, height);
  dc.opaque = false;
  dc.respectScreenScale = true;

  const r = height / 2;
  const p = Math.max(0, Math.min(100, percent));
  const fillW = Math.max(height, (width * p) / 100);

  // Background Track
  const track = new Path();
  track.addRoundedRect(new Rect(0, 0, width, height), r, r);
  dc.addPath(track);
  dc.setFillColor(THEME.trackGray);
  dc.fillPath();

  // Active Fill
  if (p > 0) {
    const fill = new Path();
    fill.addRoundedRect(new Rect(0, 0, fillW, height), r, r);
    dc.addPath(fill);
    dc.setFillColor(color);
    dc.fillPath();
  }

  return dc.getImage();
}

function getQuotaColor(pct) {
  if (pct > 40) return THEME.green;
  if (pct > 15) return THEME.orange;
  return THEME.red;
}

// ==========================================
// 5. CÁC LAYOUT WIDGET (SMALL, MEDIUM, LARGE)
// ==========================================

/**
 * SMALL (2x2): Tinh gọn, rõ ràng, tập trung vào Account #1 & Metrics chính
 */
function renderSmall(w, d) {
  w.setPadding(14, 14, 14, 14);

  // Header
  const h = w.addStack();
  h.layoutHorizontally();
  h.centerAlignContent();
  const t = h.addText("CODEXBAR");
  t.font = Font.boldSystemFont(10);
  t.textColor = THEME.textTertiary;
  h.addSpacer();
  const st = h.addText(d.online ? "●" : "○");
  st.font = Font.systemFont(10);
  st.textColor = d.online ? THEME.green : THEME.red;

  w.addSpacer(8);

  // Metric Pill (CPU & RAM)
  const m = d.sys?.metrics;
  const sysCard = w.addStack();
  sysCard.layoutHorizontally();
  sysCard.backgroundColor = THEME.cardBg;
  sysCard.cornerRadius = 6;
  sysCard.setPadding(4, 8, 4, 8);
  
  const c = sysCard.addText(`CPU ${m ? m.cpu_percent.toFixed(1) : "--"}%`);
  c.font = Font.semiboldSystemFont(11);
  c.textColor = THEME.textPrimary;
  sysCard.addSpacer();
  const rm = sysCard.addText(`RAM ${m ? m.ram_percent.toFixed(0) : "--"}%`);
  rm.font = Font.semiboldSystemFont(11);
  rm.textColor = THEME.teal;

  w.addSpacer(10);

  // Account #1 Focus
  const acc = d.pool?.accounts?.[0];
  if (acc) {
    const name = w.addText(`★ ${acc.name.split("@")[0]}`);
    name.font = Font.boldSystemFont(12);
    name.textColor = THEME.orange;
    name.lineLimit = 1;

    w.addSpacer(4);

    const qRow = w.addStack();
    qRow.layoutHorizontally();
    const q5 = qRow.addText(`5h: ${acc.remaining_5h}%`);
    q5.font = Font.systemFont(10);
    q5.textColor = getQuotaColor(acc.remaining_5h);
    qRow.addSpacer();
    const qWk = qRow.addText(`Wk: ${acc.remaining_weekly}%`);
    qWk.font = Font.systemFont(10);
    qWk.textColor = THEME.blue;

    w.addSpacer(4);
    const bar = createProgressBar(125, 4, acc.remaining_5h, getQuotaColor(acc.remaining_5h));
    const img = w.addImage(bar);
    img.imageSize = new Size(125, 4);

    w.addSpacer(3);
    const rst = w.addText(`Reset trong ${acc.reset_5h || "--"}`);
    rst.font = Font.systemFont(9);
    rst.textColor = THEME.textTertiary;
  }
}

/**
 * MEDIUM (2x4): Layout Card phân chia rành mạch, hiển thị chuẩn xác
 */
function renderMedium(w, d) {
  w.setPadding(14, 16, 14, 16);

  // 1. Header Row
  const h = w.addStack();
  h.layoutHorizontally();
  h.centerAlignContent();

  const title = h.addText("CODEXBAR");
  title.font = Font.boldSystemFont(11);
  title.textColor = THEME.textSecondary;

  h.addSpacer(6);

  const dot = h.addText(d.online ? "● ACTIVE" : "○ OFFLINE");
  dot.font = Font.systemFont(9);
  dot.textColor = d.online ? THEME.green : THEME.red;

  h.addSpacer();

  const timeStr = d.time ? new Date(d.time).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" }) : "--:--";
  const sync = h.addText(`Sync ${timeStr}`);
  sync.font = Font.systemFont(10);
  sync.textColor = THEME.textTertiary;

  w.addSpacer(10);

  // 2. Main Row: Left (Host Telemetry) & Right (Claude Pool #1)
  const main = w.addStack();
  main.layoutHorizontally();
  main.spacing = 10;

  // --- CARD TRÁI: TELEMETRY (CPU / RAM / UPTIME) ---
  const m = d.sys?.metrics;
  const leftCard = main.addStack();
  leftCard.backgroundColor = THEME.cardBg;
  leftCard.cornerRadius = 10;
  leftCard.setPadding(8, 12, 8, 12);
  leftCard.size = new Size(130, 95);

  const lHead = leftCard.addStack();
  lHead.layoutHorizontally();
  const lTitle = lHead.addText("UBUNTU");
  lTitle.font = Font.boldSystemFont(10);
  lTitle.textColor = THEME.textTertiary;
  lHead.addSpacer();
  const upVal = lHead.addText(m?.uptime || "--");
  upVal.font = Font.systemFont(9);
  upVal.textColor = THEME.textTertiary;

  leftCard.addSpacer(6);

  // CPU Gauge
  const cpuRow = leftCard.addStack();
  cpuRow.layoutHorizontally();
  const cLbl = cpuRow.addText("CPU");
  cLbl.font = Font.systemFont(11);
  cLbl.textColor = THEME.textSecondary;
  cpuRow.addSpacer();
  const cVal = cpuRow.addText(`${m ? m.cpu_percent.toFixed(1) : "--"}%`);
  cVal.font = Font.boldSystemFont(11);
  cVal.textColor = THEME.textPrimary;

  leftCard.addSpacer(3);
  const cpuBar = createProgressBar(106, 3, m?.cpu_percent || 0, THEME.textPrimary);
  const cpuBarImg = leftCard.addImage(cpuBar);
  cpuBarImg.imageSize = new Size(106, 3);

  leftCard.addSpacer(6);

  // RAM Gauge
  const ramRow = leftCard.addStack();
  ramRow.layoutHorizontally();
  const rLbl = ramRow.addText("RAM");
  rLbl.font = Font.systemFont(11);
  rLbl.textColor = THEME.textSecondary;
  ramRow.addSpacer();
  const rVal = ramRow.addText(`${m ? m.ram_percent.toFixed(0) : "--"}%`);
  rVal.font = Font.boldSystemFont(11);
  rVal.textColor = THEME.teal;

  leftCard.addSpacer(3);
  const ramBar = createProgressBar(106, 3, m?.ram_percent || 0, THEME.teal);
  const ramBarImg = leftCard.addImage(ramBar);
  ramBarImg.imageSize = new Size(106, 3);

  // --- CARD PHẢI: TÀI KHOẢN CLAUDE ACTIVE #1 & #2 ---
  const rightCard = main.addStack();
  rightCard.backgroundColor = THEME.cardBg;
  rightCard.cornerRadius = 10;
  rightCard.setPadding(8, 12, 8, 12);

  const accounts = d.pool?.accounts || [];
  const acc1 = accounts[0];
  const acc2 = accounts[1];

  if (acc1) {
    // Row 1: Account Name & Badge
    const a1Row = rightCard.addStack();
    a1Row.layoutHorizontally();
    a1Row.centerAlignContent();
    const a1Name = a1Row.addText(`★ ${acc1.name.split("@")[0]}`);
    a1Name.font = Font.boldSystemFont(11);
    a1Name.textColor = THEME.orange;
    a1Name.lineLimit = 1;
    a1Row.addSpacer();
    const a1Badge = a1Row.addText(acc1.plan || "Max");
    a1Badge.font = Font.systemFont(9);
    a1Badge.textColor = THEME.textTertiary;

    rightCard.addSpacer(4);

    // Quota details
    const q1Row = rightCard.addStack();
    q1Row.layoutHorizontally();
    const q5Txt = q1Row.addText(`5h: ${acc1.remaining_5h}%`);
    q5Txt.font = Font.semiboldSystemFont(10);
    q5Txt.textColor = getQuotaColor(acc1.remaining_5h);
    q1Row.addSpacer();
    const rst5Txt = q1Row.addText(acc1.reset_5h || "");
    rst5Txt.font = Font.systemFont(9);
    rst5Txt.textColor = THEME.textTertiary;

    rightCard.addSpacer(3);
    const b1 = createProgressBar(160, 4, acc1.remaining_5h, getQuotaColor(acc1.remaining_5h));
    const b1Img = rightCard.addImage(b1);
    b1Img.imageSize = new Size(160, 4);

    rightCard.addSpacer(6);

    // Weekly or Account 2 preview
    if (acc2) {
      const a2Row = rightCard.addStack();
      a2Row.layoutHorizontally();
      const a2Name = a2Row.addText(`2. ${acc2.name.split("@")[0]}`);
      a2Name.font = Font.mediumSystemFont(10);
      a2Name.textColor = THEME.textSecondary;
      a2Name.lineLimit = 1;
      a2Row.addSpacer();
      const a2Q = a2Row.addText(`5h: ${acc2.remaining_5h}% • Wk: ${acc2.remaining_weekly}%`);
      a2Q.font = Font.systemFont(9);
      a2Q.textColor = THEME.blue;
    } else {
      const wRow = rightCard.addStack();
      wRow.layoutHorizontally();
      const wTxt = wRow.addText(`Weekly: ${acc1.remaining_weekly}%`);
      wTxt.font = Font.systemFont(10);
      wTxt.textColor = THEME.blue;
      wRow.addSpacer();
      const wRst = wRow.addText(acc1.reset_weekly || "");
      wRst.font = Font.systemFont(9);
      wRst.textColor = THEME.textTertiary;
    }
  } else {
    const empty = rightCard.addText("Chưa có dữ liệu Quota");
    empty.font = Font.systemFont(11);
    empty.textColor = THEME.textTertiary;
  }
}

/**
 * LARGE (4x4): Trung tâm điều khiển toàn diện
 */
function renderLarge(w, d) {
  w.setPadding(16, 16, 16, 16);

  // 1. Header
  const h = w.addStack();
  h.layoutHorizontally();
  h.centerAlignContent();
  const t = h.addText("CODEXBAR COMMAND");
  t.font = Font.boldSystemFont(12);
  t.textColor = THEME.textSecondary;
  h.addSpacer();
  const st = h.addText(d.online ? "● SYSTEM ONLINE" : "○ OFFLINE");
  st.font = Font.boldSystemFont(10);
  st.textColor = d.online ? THEME.green : THEME.red;

  w.addSpacer(12);

  // 2. Triple Metric Cards (CPU, RAM, DISK)
  const m = d.sys?.metrics;
  const gRow = w.addStack();
  gRow.layoutHorizontally();
  gRow.spacing = 8;

  const makeCard = (title, val, sub, color) => {
    const c = gRow.addStack();
    c.backgroundColor = THEME.cardBg;
    c.cornerRadius = 8;
    c.setPadding(8, 10, 8, 10);
    const ttl = c.addText(title);
    ttl.font = Font.systemFont(9);
    ttl.textColor = THEME.textTertiary;
    c.addSpacer(2);
    const v = c.addText(val);
    v.font = Font.boldSystemFont(15);
    v.textColor = color;
    c.addSpacer(2);
    const s = c.addText(sub);
    s.font = Font.systemFont(8);
    s.textColor = THEME.textSecondary;
  };

  makeCard("CPU", `${m ? m.cpu_percent.toFixed(1) : "--"}%`, `${m?.cpu_count || 12} Cores`, THEME.textPrimary);
  makeCard("RAM", `${m ? m.ram_percent.toFixed(0) : "--"}%`, `${m?.ram_used_gb || "--"}GB`, THEME.teal);
  makeCard("DISK", `${m ? m.disk_percent.toFixed(0) : "--"}%`, `${m?.disk_free_gb || "--"}GB Free`, THEME.orange);

  w.addSpacer(12);

  // 3. Pool Account List
  const pHeader = w.addStack();
  pHeader.layoutHorizontally();
  const pTitle = pHeader.addText("CLAUDE QUOTA POOL");
  pTitle.font = Font.semiboldSystemFont(10);
  pTitle.textColor = THEME.textTertiary;
  pHeader.addSpacer();
  const ports = pHeader.addText(`${d.sys?.ports?.length || 0} Ports Active`);
  ports.font = Font.systemFont(9);
  ports.textColor = THEME.blue;

  w.addSpacer(6);

  const accounts = d.pool?.accounts?.slice(0, 3) || [];
  accounts.forEach((acc, idx) => {
    const card = w.addStack();
    card.backgroundColor = THEME.cardBg;
    card.cornerRadius = 8;
    card.setPadding(8, 10, 8, 10);

    const r1 = card.addStack();
    r1.layoutHorizontally();
    const nm = r1.addText(`${idx === 0 ? "★ " : `#${idx+1} `}${acc.name.split("@")[0]}`);
    nm.font = Font.boldSystemFont(11);
    nm.textColor = idx === 0 ? THEME.orange : THEME.textPrimary;
    r1.addSpacer();
    const pl = r1.addText(`${acc.plan || "Max"} • 5h: ${acc.remaining_5h}% (${acc.reset_5h})`);
    pl.font = Font.systemFont(9);
    pl.textColor = getQuotaColor(acc.remaining_5h);

    card.addSpacer(4);
    const b = createProgressBar(295, 4, acc.remaining_5h, getQuotaColor(acc.remaining_5h));
    const bView = card.addImage(b);
    bView.imageSize = new Size(295, 4);

    w.addSpacer(6);
  });

  w.addSpacer();
  const foot = w.addStack();
  foot.layoutHorizontally();
  const up = foot.addText(`Uptime: ${m?.uptime || "--"}`);
  up.font = Font.systemFont(9);
  up.textColor = THEME.textTertiary;
  foot.addSpacer();
  const sync = foot.addText(`Cập nhật: ${d.time ? new Date(d.time).toLocaleTimeString("vi-VN", {hour: "2-digit", minute: "2-digit"}) : "--"}`);
  sync.font = Font.systemFont(9);
  sync.textColor = THEME.textTertiary;
}

// ==========================================
// 6. MAIN CONTROLLER
// ==========================================
async function main() {
  const widget = new ListWidget();
  
  // Background Gradient
  const grad = new LinearGradient();
  grad.locations = [0.0, 1.0];
  grad.colors = [THEME.bgStart, THEME.bgEnd];
  widget.backgroundGradient = grad;

  const data = await loadData();
  const family = config.widgetFamily || "medium";

  if (family === "small") {
    renderSmall(widget, data);
  } else if (family === "large") {
    renderLarge(widget, data);
  } else {
    renderMedium(widget, data);
  }

  // Refresh schedule 10 mins
  widget.refreshAfterDate = new Date(Date.now() + CONFIG.REFRESH_INTERVAL_MINUTES * 60 * 1000);
  return widget;
}

const widget = await main();

if (config.runsInWidget) {
  Script.setWidget(widget);
} else {
  widget.presentMedium();
}

Script.complete();
