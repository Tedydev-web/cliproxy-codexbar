// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: purple; icon-glyph: server;
/**
 * CodexBar & CLIProxy Quota / Telemetry Widget for iOS
 * Designed according to Apple Human Interface Guidelines & Fluid Interface Principles
 * Supports: Small, Medium, Large widget sizes with auto-adaptation
 * Zero AI-slop, battery optimized, cached offline-resilient, Dark Glass aesthetics
 */

// ==========================================
// 1. CONFIGURATION & NETWORKING
// ==========================================
const CONFIG = {
  // Tailscale IP của máy Ubuntu Host (hoặc Cloudflare Tunnel URL nếu có)
  HOST: "100.127.1.234",
  PORT: "8318",
  TIMEOUT_SECONDS: 4,
  REFRESH_INTERVAL_MINUTES: 10,
  CACHE_KEY: "codexbar_telemetry_cache_v2"
};

const URLS = {
  POOL: `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/pool-status`,
  TELEMETRY: `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/system-telemetry`
};

// ==========================================
// 2. DESIGN TOKENS (Apple Dark Glass Palette)
// ==========================================
const THEME = {
  bgGradientStart: new Color("#161618"),
  bgGradientEnd: new Color("#0C0C0E"),
  cardBg: new Color("#242428", 0.55),
  cardBorder: new Color("#FFFFFF", 0.08),
  
  // Apple Dynamic Colors
  labelPrimary: new Color("#FFFFFF", 0.96),
  labelSecondary: new Color("#EBEBF5", 0.60),
  labelTertiary: new Color("#EBEBF5", 0.35),
  
  // Apple Semantic Accents
  systemGreen: new Color("#30D158"),
  systemOrange: new Color("#FF9F0A"),
  systemBlue: new Color("#0A84FF"),
  systemPurple: new Color("#BF5AF2"),
  systemRed: new Color("#FF453A"),
  systemTeal: new Color("#64D2FF")
};

// ==========================================
// 3. CACHING & ROBUST DATA FETCHING
// ==========================================
async function fetchWithCache() {
  const fm = FileManager.local();
  const cachePath = fm.joinPath(fm.documentsDirectory(), `${CONFIG.CACHE_KEY}.json`);

  let cachedData = null;
  if (fm.fileExists(cachePath)) {
    try {
      cachedData = JSON.parse(fm.readString(cachePath));
    } catch (_) {}
  }

  // Network Fetch with aggressive timeout (tiết kiệm pin & tránh đơ widget)
  const fetchEndpoint = async (url) => {
    try {
      const req = new Request(url);
      req.timeoutInterval = CONFIG.TIMEOUT_SECONDS;
      return await req.loadJSON();
    } catch (_) {
      return null;
    }
  };

  const [pool, sys] = await Promise.all([
    fetchEndpoint(URLS.POOL),
    fetchEndpoint(URLS.TELEMETRY)
  ]);

  if (pool || sys) {
    const freshPayload = {
      pool: pool || (cachedData ? cachedData.pool : null),
      sys: sys || (cachedData ? cachedData.sys : null),
      updatedAt: Date.now(),
      isOnline: true
    };
    try {
      fm.writeString(cachePath, JSON.stringify(freshPayload));
    } catch (_) {}
    return freshPayload;
  }

  // Fallback to cache if host unreachable (offline state)
  if (cachedData) {
    cachedData.isOnline = false;
    return cachedData;
  }

  return { pool: null, sys: null, updatedAt: null, isOnline: false };
}

// ==========================================
// 4. DRAWING UTILS: APPLE PROGRESS BARS
// ==========================================
function drawProgressCapsule(width, height, percent, fillColor, trackColor) {
  const dc = new DrawContext();
  dc.size = new Size(width, height);
  dc.opaque = false;
  dc.respectScreenScale = true;

  const radius = height / 2;
  const clampedPercent = Math.max(0, Math.min(100, percent));
  const fillWidth = Math.max(height, (width * clampedPercent) / 100);

  // Background Track
  const trackPath = new Path();
  trackPath.addRoundedRect(new Rect(0, 0, width, height), radius, radius);
  dc.addPath(trackPath);
  dc.setFillColor(trackColor);
  dc.fillPath();

  // Active Fill Bar
  if (clampedPercent > 0) {
    const fillPath = new Path();
    fillPath.addRoundedRect(new Rect(0, 0, fillWidth, height), radius, radius);
    dc.addPath(fillPath);
    dc.setFillColor(fillColor);
    dc.fillPath();
  }

  return dc.getImage();
}

function getQuotaColor(percent) {
  if (percent > 40) return THEME.systemGreen;
  if (percent > 15) return THEME.systemOrange;
  return THEME.systemRed;
}

// ==========================================
// 5. WIDGET BUILDERS PER SIZE
// ==========================================

/**
 * SMALL WIDGET (2x2): Minimalist Glance
 * Tập trung vào: CPU/RAM + Quota Account #1 Đang Active
 */
function buildSmallWidget(widget, data) {
  widget.setPadding(12, 12, 12, 12);

  // Header: App Glyphs + Status Dot
  const header = widget.addStack();
  header.layoutHorizontally();
  header.centerAlignContent();

  const title = header.addText("CODEXBAR");
  title.font = Font.semiboldSystemFont(10);
  title.textColor = THEME.labelSecondary;

  header.addSpacer();

  const dot = header.addText(data.isOnline ? "●" : "○");
  dot.font = Font.systemFont(9);
  dot.textColor = data.isOnline ? THEME.systemGreen : THEME.systemRed;

  widget.addSpacer(6);

  // System Metric Row (CPU & RAM)
  const metrics = data.sys?.metrics;
  const sysStack = widget.addStack();
  sysStack.layoutHorizontally();
  sysStack.centerAlignContent();

  const cpuText = sysStack.addText(`CPU ${metrics ? metrics.cpu_percent.toFixed(1) : "--"}%`);
  cpuText.font = Font.boldSystemFont(11);
  cpuText.textColor = THEME.labelPrimary;

  sysStack.addSpacer();

  const ramText = sysStack.addText(`RAM ${metrics ? metrics.ram_percent.toFixed(0) : "--"}%`);
  ramText.font = Font.boldSystemFont(11);
  ramText.textColor = THEME.systemTeal;

  widget.addSpacer(8);

  // Divider Line
  const divider = widget.addStack();
  divider.size = new Size(0, 0.5);
  divider.backgroundColor = THEME.cardBorder;

  widget.addSpacer(8);

  // Primary Account (#1) Quota
  const topAcc = data.pool?.accounts?.[0];
  if (topAcc) {
    const accLabel = widget.addText(topAcc.name.split("@")[0]);
    accLabel.font = Font.mediumSystemFont(11);
    accLabel.textColor = THEME.systemOrange;
    accLabel.lineLimit = 1;

    widget.addSpacer(3);

    // 5h Quota Bar
    const q5Row = widget.addStack();
    q5Row.layoutHorizontally();
    q5Row.centerAlignContent();

    const q5Val = q5Row.addText(`5h: ${topAcc.remaining_5h}%`);
    q5Val.font = Font.systemFont(10);
    q5Val.textColor = getQuotaColor(topAcc.remaining_5h);

    q5Row.addSpacer();

    const q5Reset = q5Row.addText(topAcc.reset_5h || "");
    q5Reset.font = Font.systemFont(9);
    q5Reset.textColor = THEME.labelTertiary;

    widget.addSpacer(3);
    const barImg = drawProgressCapsule(120, 4, topAcc.remaining_5h, getQuotaColor(topAcc.remaining_5h), new Color("#3A3A3C", 0.5));
    const barView = widget.addImage(barImg);
    barView.imageSize = new Size(120, 4);

    widget.addSpacer(4);

    // Weekly Quota Text
    const qWkRow = widget.addStack();
    qWkRow.layoutHorizontally();
    const qWkVal = qWkRow.addText(`Wk: ${topAcc.remaining_weekly}%`);
    qWkVal.font = Font.systemFont(10);
    qWkVal.textColor = THEME.systemBlue;

    qWkRow.addSpacer();
    const qWkReset = qWkRow.addText(topAcc.reset_weekly || "");
    qWkReset.font = Font.systemFont(9);
    qWkReset.textColor = THEME.labelTertiary;
  } else {
    const emptyText = widget.addText("Chưa có data quota");
    emptyText.font = Font.systemFont(10);
    emptyText.textColor = THEME.labelTertiary;
  }

  widget.addSpacer();
}

/**
 * MEDIUM WIDGET (2x4): Balanced Apple Glass Overview
 * Cột trái: Host Telemetry (CPU, RAM, Uptime, Cloudflare)
 * Cột phải: Top 2 Claude Pool Accounts + Quota Progress Bars
 */
function buildMediumWidget(widget, data) {
  widget.setPadding(14, 16, 14, 16);

  // Header Bar
  const header = widget.addStack();
  header.layoutHorizontally();
  header.centerAlignContent();

  const title = header.addText("CODEXBAR");
  title.font = Font.boldSystemFont(11);
  title.textColor = THEME.labelSecondary;

  header.addSpacer(6);

  const dot = header.addText(data.isOnline ? "● ON" : "○ OFFLINE");
  dot.font = Font.systemFont(9);
  dot.textColor = data.isOnline ? THEME.systemGreen : THEME.systemRed;

  header.addSpacer();

  const timeStr = data.updatedAt 
    ? new Date(data.updatedAt).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" }) 
    : "--:--";
  const updated = header.addText(`Sync ${timeStr}`);
  updated.font = Font.systemFont(9);
  updated.textColor = THEME.labelTertiary;

  widget.addSpacer(10);

  // Two Column Split
  const bodyStack = widget.addStack();
  bodyStack.layoutHorizontally();

  // --- CỘT TRÁI: TELEMETRY (Width: 120) ---
  const leftCol = bodyStack.addStack();
  leftCol.layoutVertical();
  leftCol.size = new Size(120, 0);

  const m = data.sys?.metrics;
  const leftTitle = leftCol.addText("HOST UBUNTU");
  leftTitle.font = Font.semiboldSystemFont(9);
  leftTitle.textColor = THEME.labelTertiary;

  leftCol.addSpacer(5);

  // CPU
  const cpuRow = leftCol.addStack();
  cpuRow.layoutHorizontally();
  const cpuLabel = cpuRow.addText("CPU");
  cpuLabel.font = Font.systemFont(11);
  cpuLabel.textColor = THEME.labelSecondary;
  cpuRow.addSpacer();
  const cpuVal = cpuRow.addText(`${m ? m.cpu_percent.toFixed(1) : "--"}%`);
  cpuVal.font = Font.boldSystemFont(11);
  cpuVal.textColor = THEME.labelPrimary;

  leftCol.addSpacer(4);

  // RAM
  const ramRow = leftCol.addStack();
  ramRow.layoutHorizontally();
  const ramLabel = ramRow.addText("RAM");
  ramLabel.font = Font.systemFont(11);
  ramLabel.textColor = THEME.labelSecondary;
  ramRow.addSpacer();
  const ramVal = ramRow.addText(`${m ? m.ram_percent.toFixed(0) : "--"}%`);
  ramVal.font = Font.boldSystemFont(11);
  ramVal.textColor = THEME.systemTeal;

  leftCol.addSpacer(4);

  // Uptime
  const upRow = leftCol.addStack();
  upRow.layoutHorizontally();
  const upLabel = upRow.addText("Uptime");
  upLabel.font = Font.systemFont(11);
  upLabel.textColor = THEME.labelSecondary;
  upRow.addSpacer();
  const upVal = upRow.addText(m?.uptime || "--");
  upVal.font = Font.systemFont(10);
  upVal.textColor = THEME.labelSecondary;

  bodyStack.addSpacer(12);

  // Vertical Separator
  const vLine = bodyStack.addStack();
  vLine.size = new Size(0.5, 75);
  vLine.backgroundColor = THEME.cardBorder;

  bodyStack.addSpacer(12);

  // --- CỘT PHẢI: POOL ACCOUNTS (Flex Width) ---
  const rightCol = bodyStack.addStack();
  rightCol.layoutVertical();

  const accounts = data.pool?.accounts?.slice(0, 2) || [];
  if (accounts.length === 0) {
    const noAcc = rightCol.addText("Không có dữ liệu pool tài khoản");
    noAcc.font = Font.systemFont(10);
    noAcc.textColor = THEME.labelTertiary;
  } else {
    accounts.forEach((acc, idx) => {
      const accStack = rightCol.addStack();
      accStack.layoutVertical();

      // Row Name
      const nameRow = accStack.addStack();
      nameRow.layoutHorizontally();
      nameRow.centerAlignContent();

      const emailPrefix = acc.name.split("@")[0];
      const nameText = nameRow.addText(`${idx === 0 ? "★ " : ""}${emailPrefix}`);
      nameText.font = Font.boldSystemFont(11);
      nameText.textColor = idx === 0 ? THEME.systemOrange : THEME.labelPrimary;
      nameText.lineLimit = 1;

      nameRow.addSpacer();

      const planText = nameRow.addText(acc.plan || "Max");
      planText.font = Font.systemFont(9);
      planText.textColor = THEME.labelTertiary;

      accStack.addSpacer(3);

      // Quota Stats Row
      const qRow = accStack.addStack();
      qRow.layoutHorizontally();
      qRow.centerAlignContent();

      const q5 = qRow.addText(`5h: ${acc.remaining_5h}%`);
      q5.font = Font.semiboldSystemFont(10);
      q5.textColor = getQuotaColor(acc.remaining_5h);

      qRow.addSpacer(8);

      const qWk = qRow.addText(`Wk: ${acc.remaining_weekly}%`);
      qWk.font = Font.semiboldSystemFont(10);
      qWk.textColor = THEME.systemBlue;

      qRow.addSpacer();

      const rTime = qRow.addText(acc.reset_5h || "");
      rTime.font = Font.systemFont(9);
      rTime.textColor = THEME.labelTertiary;

      if (idx === 0) {
        rightCol.addSpacer(6);
      }
    });
  }

  widget.addSpacer();
}

/**
 * LARGE WIDGET (4x4): Full High-Density Command Center
 * - Header: Host Status, Uptime, Ports open count
 * - System Gauges: CPU, RAM, Disk
 * - Claude Pool Accounts: 3 priority accounts with dual progress bars
 * - Gateway / Antigravity status footer
 */
function buildLargeWidget(widget, data) {
  widget.setPadding(16, 16, 16, 16);

  // Header: Brand & Live Status
  const header = widget.addStack();
  header.layoutHorizontally();
  header.centerAlignContent();

  const title = header.addText("CODEXBAR COMMAND");
  title.font = Font.boldSystemFont(12);
  title.textColor = THEME.labelSecondary;

  header.addSpacer();

  const dot = header.addText(data.isOnline ? "● SYSTEM ACTIVE" : "○ DISCONNECTED");
  dot.font = Font.boldSystemFont(10);
  dot.textColor = data.isOnline ? THEME.systemGreen : THEME.systemRed;

  widget.addSpacer(12);

  // Section 1: System Telemetry Cards (3-column)
  const m = data.sys?.metrics;
  const gaugeRow = widget.addStack();
  gaugeRow.layoutHorizontally();
  gaugeRow.spacing = 8;

  const addCard = (parent, label, value, subtext, color) => {
    const card = parent.addStack();
    card.layoutVertical();
    card.backgroundColor = THEME.cardBg;
    card.cornerRadius = 8;
    card.setPadding(8, 8, 8, 8);

    const lbl = card.addText(label);
    lbl.font = Font.systemFont(9);
    lbl.textColor = THEME.labelTertiary;

    card.addSpacer(2);

    const val = card.addText(value);
    val.font = Font.boldSystemFont(15);
    val.textColor = color;

    card.addSpacer(2);

    const sub = card.addText(subtext);
    sub.font = Font.systemFont(8);
    sub.textColor = THEME.labelSecondary;
  };

  addCard(gaugeRow, "CPU LOAD", `${m ? m.cpu_percent.toFixed(1) : "--"}%`, `${m?.cpu_count || 12} Cores`, THEME.labelPrimary);
  addCard(gaugeRow, "MEMORY", `${m ? m.ram_percent.toFixed(0) : "--"}%`, `${m?.ram_used_gb || "--"}GB Used`, THEME.systemTeal);
  addCard(gaugeRow, "STORAGE", `${m ? m.disk_percent.toFixed(0) : "--"}%`, `${m?.disk_free_gb || "--"}GB Free`, THEME.systemPurple);

  widget.addSpacer(12);

  // Section 2: Claude Pool Accounts Header
  const accHeader = widget.addStack();
  accHeader.layoutHorizontally();
  
  const poolTitle = accHeader.addText("CLAUDE MULTI-ACCOUNT POOL");
  poolTitle.font = Font.semiboldSystemFont(10);
  poolTitle.textColor = THEME.labelTertiary;

  accHeader.addSpacer();

  const portCount = data.sys?.ports?.length || 0;
  const portsBadge = accHeader.addText(`${portCount} Ports Active`);
  portsBadge.font = Font.systemFont(9);
  portsBadge.textColor = THEME.systemBlue;

  widget.addSpacer(6);

  // Section 3: Pool Accounts List (Top 3)
  const accounts = data.pool?.accounts?.slice(0, 3) || [];
  accounts.forEach((acc, idx) => {
    const accBox = widget.addStack();
    accBox.layoutVertical();
    accBox.backgroundColor = THEME.cardBg;
    accBox.cornerRadius = 8;
    accBox.setPadding(8, 10, 8, 10);

    // Title Row
    const topRow = accBox.addStack();
    topRow.layoutHorizontally();
    topRow.centerAlignContent();

    const emailPrefix = acc.name.split("@")[0];
    const nameTxt = topRow.addText(`${idx === 0 ? "★ " : `#${idx + 1} `}${emailPrefix}`);
    nameTxt.font = Font.boldSystemFont(11);
    nameTxt.textColor = idx === 0 ? THEME.systemOrange : THEME.labelPrimary;

    topRow.addSpacer();

    const planBadge = topRow.addText(`${acc.plan || "Max"} • ${acc.status_text || "Ready"}`);
    planBadge.font = Font.systemFont(9);
    planBadge.textColor = acc.is_available ? THEME.systemGreen : THEME.systemRed;

    accBox.addSpacer(4);

    // Dual Progress Bars (5h + Weekly)
    const progRow = accBox.addStack();
    progRow.layoutHorizontally();
    progRow.centerAlignContent();

    // 5h Quota
    const p5Label = progRow.addText(`5h: ${acc.remaining_5h}% (${acc.reset_5h})`);
    p5Label.font = Font.systemFont(9);
    p5Label.textColor = getQuotaColor(acc.remaining_5h);

    progRow.addSpacer();

    // Weekly Quota
    const pWkLabel = progRow.addText(`Wk: ${acc.remaining_weekly}% (${acc.reset_weekly})`);
    pWkLabel.font = Font.systemFont(9);
    pWkLabel.textColor = THEME.systemBlue;

    accBox.addSpacer(3);

    // Dual Bar Image
    const bar = drawProgressCapsule(290, 4, acc.remaining_5h, getQuotaColor(acc.remaining_5h), new Color("#3A3A3C", 0.5));
    const barV = accBox.addImage(bar);
    barV.imageSize = new Size(290, 4);

    widget.addSpacer(6);
  });

  // Footer: Last Sync
  widget.addSpacer();
  const footerRow = widget.addStack();
  footerRow.layoutHorizontally();

  const upText = footerRow.addText(`Server Uptime: ${m?.uptime || "--"}`);
  upText.font = Font.systemFont(9);
  upText.textColor = THEME.labelTertiary;

  footerRow.addSpacer();

  const timeStr = data.updatedAt 
    ? new Date(data.updatedAt).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" }) 
    : "--:--";
  const syncText = footerRow.addText(`Updated ${timeStr}`);
  syncText.font = Font.systemFont(9);
  syncText.textColor = THEME.labelTertiary;
}

// ==========================================
// 6. MAIN CONTROLLER
// ==========================================
async function render() {
  const widget = new ListWidget();
  
  // Apple Liquid Glass Background
  const gradient = new LinearGradient();
  gradient.locations = [0.0, 1.0];
  gradient.colors = [THEME.bgGradientStart, THEME.bgGradientEnd];
  widget.backgroundGradient = gradient;

  // Lấy dữ liệu với cache fallback
  const data = await fetchWithCache();

  // Xác định kích thước widget hiện tại (Small, Medium, Large)
  const widgetFamily = config.widgetFamily || "medium";

  switch (widgetFamily) {
    case "small":
      buildSmallWidget(widget, data);
      break;
    case "large":
      buildLargeWidget(widget, data);
      break;
    case "medium":
    default:
      buildMediumWidget(widget, data);
      break;
  }

  // Cấu hình thời gian iOS gọi refresh lại widget (10 phút tiết kiệm pin)
  const nextRefresh = new Date(Date.now() + CONFIG.REFRESH_INTERVAL_MINUTES * 60 * 1000);
  widget.refreshAfterDate = nextRefresh;

  return widget;
}

const widget = await render();

if (config.runsInWidget) {
  Script.setWidget(widget);
} else {
  // Test preview chế độ app: Tùy chọn test medium hoặc large
  widget.presentMedium();
}

Script.complete();
