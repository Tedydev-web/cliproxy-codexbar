// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: green; icon-glyph: server;
//
// ==============================================================================
// ORBITER SERVER MONITOR WIDGET (UBUNTU HOST & HARDWARE TELEMETRY)
// Phiên bản: 1.0.0
// Tác giả: TedyDev (Orbiter / CodexBar Ecosystem)
// Thiết kế: 100% Đồng bộ Pixel-Perfect với Orbiter macOS Menubar (Apple Dark Mode)
// Hỗ trợ: Widget Medium (2x4) và Small (2x2)
// Tần số làm mới: 2 phút (chỉ tiêu thụ pin khi mở màn hình trang widget)
// ==============================================================================

// Cấu hình URL Bridge (Tailscale Ubuntu Host)
const BRIDGE_URL = "http://100.127.1.234:8318/v1/system-telemetry";
const CACHE_FILE = "orbiter_server_telemetry.json";
const TIMEOUT_MS = 4000;

// Hệ màu Apple HIG Dark Mode đồng bộ CodexBar & Orbiter macOS
const TOKENS = {
  bg: new Color("#16181C"),
  cardBorder: new Color("#2C2C2E"),
  textPrimary: new Color("#FFFFFF"),
  textSecondary: new Color("#8E8E93"),
  textMuted: new Color("#636366"),
  trackGray: new Color("#2C2C2E"),
  greenOnline: new Color("#34C759"),
  redAlert: new Color("#FF3B30"),
  emeraldRam: new Color("#00C389"),
  orangeWarning: new Color("#FF9500"),
  purpleDisk: new Color("#AF52DE")
};

// ==========================================
// TÍNH TOÁN BỀ RỘNG WIDGET THEO MÀN HÌNH
// ==========================================
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
// VẼ THANH TIẾN TRÌNH 3 ĐOẠN (SEGMENTED BAR)
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

  // 1. Rãnh xám nền (3 đoạn bo góc đồng đều)
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

// ==========================================
// VẼ ICON SERVER / UBUNTU CHUẨN VÉCTƠ
// ==========================================
function getServerIcon() {
  try {
    const sym = SFSymbol.named("server.rack");
    if (sym) {
      sym.applyFont(Font.systemFont(14));
      return sym.image;
    }
  } catch (e) {}

  // Fallback vẽ icon máy chủ bằng DrawContext
  const dc = new DrawContext();
  dc.size = new Size(24, 24);
  dc.opaque = false;
  dc.respectScreenScale = true;

  // Rack 1
  const p1 = new Path();
  p1.addRoundedRect(new Rect(2, 4, 20, 6.5), 1.5, 1.5);
  dc.addPath(p1);
  dc.setFillColor(new Color("#FFFFFF", 0.9));
  dc.fillPath();

  // LED 1
  const l1 = new Path();
  l1.addEllipse(new Rect(4.5, 6.2, 2, 2));
  dc.addPath(l1);
  dc.setFillColor(TOKENS.greenOnline);
  dc.fillPath();

  // Rack 2
  const p2 = new Path();
  p2.addRoundedRect(new Rect(2, 13.5, 20, 6.5), 1.5, 1.5);
  dc.addPath(p2);
  dc.setFillColor(new Color("#FFFFFF", 0.9));
  dc.fillPath();

  // LED 2
  const l2 = new Path();
  l2.addEllipse(new Rect(4.5, 15.7, 2, 2));
  dc.addPath(l2);
  dc.setFillColor(TOKENS.greenOnline);
  dc.fillPath();

  return dc.getImage();
}

// ==========================================
// FETCH DỮ LIỆU TELEMETRY & CACHE
// ==========================================
async function fetchTelemetryData() {
  const fm = FileManager.local();
  const cachePath = fm.joinPath(fm.documentsDirectory(), CACHE_FILE);

  try {
    const req = new Request(BRIDGE_URL);
    req.timeoutInterval = TIMEOUT_MS / 1000;
    const res = await req.loadJSON();

    if (res && res.metrics) {
      res.is_online = true;
      res.fetched_at = Date.now();
      fm.writeString(cachePath, JSON.stringify(res));
      return res;
    }
  } catch (err) {
    console.warn("Lỗi kết nối máy chủ telemetry: " + err);
  }

  // Đọc từ Cache nếu mạng gián đoạn
  if (fm.fileExists(cachePath)) {
    try {
      const cached = JSON.parse(fm.readString(cachePath));
      cached.is_online = false;
      return cached;
    } catch (e) {}
  }

  // Dữ liệu mẫu ban đầu nếu chưa từng có cache
  return {
    is_online: false,
    metrics: {
      cpu_percent: 1.9,
      cpu_count: 12,
      load_avg: [0.83, 0.68, 0.67],
      ram_total_gb: 30.7,
      ram_used_gb: 14.2,
      ram_percent: 46.0,
      disk_total_gb: 233.0,
      disk_used_gb: 146.0,
      disk_free_gb: 87.0,
      disk_percent: 62.0,
      disk_free_percent: 38.0,
      uptime: "11d 21h"
    },
    ports: [],
    services: [],
    tunnels: []
  };
}

// ==========================================
// MEDIUM WIDGET: 100% ĐỒNG BỘ ORBITER MACOS
// ==========================================
function buildMediumWidget(w, data) {
  const hPadding = 14;
  w.setPadding(14, hPadding, 14, hPadding);

  const m = data.metrics || {};
  const isOnline = data.is_online !== false;
  const contentW = getWidgetContentWidth("medium", hPadding);

  // 1. HEADER (Ubuntu Host Identity & IP)
  const row1 = w.addStack();
  row1.layoutHorizontally();
  row1.centerAlignContent();

  const titleStack = row1.addStack();
  titleStack.layoutHorizontally();
  titleStack.centerAlignContent();
  titleStack.spacing = 6;

  const icon = titleStack.addImage(getServerIcon());
  icon.imageSize = new Size(15, 15);
  icon.tintColor = TOKENS.textPrimary;

  const title = titleStack.addText("Ubuntu Host");
  title.font = Font.boldSystemFont(16);
  title.textColor = TOKENS.textPrimary;

  row1.addSpacer();

  const ipTxt = row1.addText("100.127.1.234");
  ipTxt.font = Font.systemFont(12);
  ipTxt.textColor = TOKENS.textSecondary;

  w.addSpacer(2);

  // 2. SUB-HEADER: Uptime & Trạng thái Online
  const row2 = w.addStack();
  row2.layoutHorizontally();
  row2.centerAlignContent();

  const uptimeTxt = row2.addText(`Uptime: ${m.uptime || "11d 21h"}`);
  uptimeTxt.font = Font.systemFont(11);
  uptimeTxt.textColor = TOKENS.textSecondary;

  row2.addSpacer();

  const statusStack = row2.addStack();
  statusStack.layoutHorizontally();
  statusStack.centerAlignContent();
  statusStack.spacing = 4;

  const dot = statusStack.addText("●");
  dot.font = Font.systemFont(9);
  dot.textColor = isOnline ? TOKENS.greenOnline : TOKENS.redAlert;

  const statusTxt = statusStack.addText(isOnline ? "Online" : "Offline");
  statusTxt.font = Font.systemFont(11);
  statusTxt.textColor = isOnline ? TOKENS.greenOnline : TOKENS.redAlert;

  w.addSpacer(6);

  // Hairline Divider
  const div = w.addStack();
  div.size = new Size(0, 0.5);
  div.backgroundColor = TOKENS.cardBorder;

  w.addSpacer(8);

  // --- METRIC 1: CPU ---
  const cpuVal = m.cpu_percent || 0;
  const cpuStr = cpuVal < 10.0 ? cpuVal.toFixed(1) : Math.round(cpuVal).toString();
  const loadStr = (m.load_avg || [0, 0, 0]).map(v => v.toFixed(2)).join(" ");
  const cpuColor = cpuVal > 80 ? TOKENS.redAlert : TOKENS.greenOnline;

  const cpuHead = w.addStack();
  cpuHead.layoutHorizontally();
  cpuHead.centerAlignContent();

  const cpuTitle = cpuHead.addText(`CPU: ${cpuStr}% · ${m.cpu_count || 12} Cores`);
  cpuTitle.font = Font.boldSystemFont(12.5);
  cpuTitle.textColor = TOKENS.textPrimary;

  cpuHead.addSpacer();

  const cpuLoad = cpuHead.addText(`Load: ${loadStr}`);
  cpuLoad.font = Font.systemFont(10.5);
  cpuLoad.textColor = TOKENS.textSecondary;

  w.addSpacer(4);

  const barCpu = drawSegmentedBar(contentW, 5.5, cpuVal, cpuColor);
  const vCpu = w.addImage(barCpu);
  vCpu.imageSize = new Size(contentW, 5.5);
  vCpu.leftAlignImage();

  w.addSpacer(7);

  // --- METRIC 2: RAM ---
  const ramVal = m.ram_percent || 0;
  const ramColor = ramVal > 85 ? TOKENS.orangeWarning : TOKENS.emeraldRam;
  const ramUsed = (m.ram_used_gb || 0).toFixed(1);
  const ramTotal = (m.ram_total_gb || 0).toFixed(1);

  const ramHead = w.addStack();
  ramHead.layoutHorizontally();
  ramHead.centerAlignContent();

  const ramTitle = ramHead.addText(`RAM: ${Math.round(ramVal)}% đã dùng`);
  ramTitle.font = Font.boldSystemFont(12.5);
  ramTitle.textColor = TOKENS.textPrimary;

  ramHead.addSpacer();

  const ramSub = ramHead.addText(`${ramUsed} / ${ramTotal} GB`);
  ramSub.font = Font.systemFont(10.5);
  ramSub.textColor = TOKENS.textSecondary;

  w.addSpacer(4);

  const barRam = drawSegmentedBar(contentW, 5.5, ramVal, ramColor);
  const vRam = w.addImage(barRam);
  vRam.imageSize = new Size(contentW, 5.5);
  vRam.leftAlignImage();

  w.addSpacer(7);

  // --- METRIC 3: DISK (Ổ CỨNG) ---
  const diskVal = m.disk_percent || 0;
  const diskFree = Math.round(m.disk_free_gb || 0);
  const diskUsed = Math.round(m.disk_used_gb || 0);
  const diskTotal = Math.round(m.disk_total_gb || 0);

  const diskHead = w.addStack();
  diskHead.layoutHorizontally();
  diskHead.centerAlignContent();

  const diskTitle = diskHead.addText(`Ổ cứng (/): ${Math.round(diskVal)}% đã dùng`);
  diskTitle.font = Font.boldSystemFont(12.5);
  diskTitle.textColor = TOKENS.textPrimary;

  diskHead.addSpacer();

  const diskSub = diskHead.addText(`Trống ${diskFree} GiB · ${diskUsed} / ${diskTotal} GiB`);
  diskSub.font = Font.systemFont(10.5);
  diskSub.textColor = TOKENS.textSecondary;

  w.addSpacer(4);

  const barDisk = drawSegmentedBar(contentW, 5.5, diskVal, TOKENS.purpleDisk);
  const vDisk = w.addImage(barDisk);
  vDisk.imageSize = new Size(contentW, 5.5);
  vDisk.leftAlignImage();
}

// ==========================================
// SMALL WIDGET (2X2)
// ==========================================
function buildSmallWidget(w, data) {
  const hPadding = 12;
  w.setPadding(12, hPadding, 12, hPadding);

  const m = data.metrics || {};
  const isOnline = data.is_online !== false;
  const contentW = getWidgetContentWidth("small", hPadding);

  // Header: Host & Status
  const h = w.addStack();
  h.layoutHorizontally();
  h.centerAlignContent();

  const titleStack = h.addStack();
  titleStack.layoutHorizontally();
  titleStack.centerAlignContent();
  titleStack.spacing = 5;

  const icon = titleStack.addImage(getServerIcon());
  icon.imageSize = new Size(13, 13);
  icon.tintColor = TOKENS.textPrimary;

  const t = titleStack.addText("Ubuntu");
  t.font = Font.boldSystemFont(14);
  t.textColor = TOKENS.textPrimary;

  h.addSpacer();

  const statusStack = h.addStack();
  statusStack.layoutHorizontally();
  statusStack.centerAlignContent();
  statusStack.spacing = 3;

  const dot = statusStack.addText("●");
  dot.font = Font.systemFont(8);
  dot.textColor = isOnline ? TOKENS.greenOnline : TOKENS.redAlert;

  const st = statusStack.addText(isOnline ? "Online" : "Off");
  st.font = Font.systemFont(9.5);
  st.textColor = isOnline ? TOKENS.greenOnline : TOKENS.redAlert;

  w.addSpacer(6);

  // 1. CPU
  const cpuVal = m.cpu_percent || 0;
  const cpuStr = cpuVal < 10.0 ? cpuVal.toFixed(1) : Math.round(cpuVal).toString();
  const cpuColor = cpuVal > 80 ? TOKENS.redAlert : TOKENS.greenOnline;

  const cpuHead = w.addStack();
  cpuHead.layoutHorizontally();
  cpuHead.centerAlignContent();
  const cpuTitle = cpuHead.addText(`CPU: ${cpuStr}%`);
  cpuTitle.font = Font.boldSystemFont(11);
  cpuTitle.textColor = TOKENS.textPrimary;
  cpuHead.addSpacer();
  const cpuCores = cpuHead.addText(`${m.cpu_count || 12} Cores`);
  cpuCores.font = Font.systemFont(9.5);
  cpuCores.textColor = TOKENS.textMuted;

  w.addSpacer(3);
  const bCpu = drawSegmentedBar(contentW, 4.5, cpuVal, cpuColor);
  const vCpu = w.addImage(bCpu);
  vCpu.imageSize = new Size(contentW, 4.5);
  vCpu.leftAlignImage();

  w.addSpacer(7);

  // 2. RAM
  const ramVal = m.ram_percent || 0;
  const ramColor = ramVal > 85 ? TOKENS.orangeWarning : TOKENS.emeraldRam;
  const ramHead = w.addStack();
  ramHead.layoutHorizontally();
  ramHead.centerAlignContent();
  const ramTitle = ramHead.addText(`RAM: ${Math.round(ramVal)}%`);
  ramTitle.font = Font.boldSystemFont(11);
  ramTitle.textColor = TOKENS.textPrimary;
  ramHead.addSpacer();
  const ramSub = ramHead.addText(`${(m.ram_used_gb || 0).toFixed(1)}/${(m.ram_total_gb || 0).toFixed(1)}G`);
  ramSub.font = Font.systemFont(9.5);
  ramSub.textColor = TOKENS.textMuted;

  w.addSpacer(3);
  const bRam = drawSegmentedBar(contentW, 4.5, ramVal, ramColor);
  const vRam = w.addImage(bRam);
  vRam.imageSize = new Size(contentW, 4.5);
  vRam.leftAlignImage();

  w.addSpacer(7);

  // 3. Disk
  const diskVal = m.disk_percent || 0;
  const diskHead = w.addStack();
  diskHead.layoutHorizontally();
  diskHead.centerAlignContent();
  const diskTitle = diskHead.addText(`Ổ cứng: ${Math.round(diskVal)}%`);
  diskTitle.font = Font.boldSystemFont(11);
  diskTitle.textColor = TOKENS.textPrimary;
  diskHead.addSpacer();
  const diskSub = diskHead.addText(`Trống ${Math.round(m.disk_free_gb || 0)}G`);
  diskSub.font = Font.systemFont(9.5);
  diskSub.textColor = TOKENS.textMuted;

  w.addSpacer(3);
  const bDisk = drawSegmentedBar(contentW, 4.5, diskVal, TOKENS.purpleDisk);
  const vDisk = w.addImage(bDisk);
  vDisk.imageSize = new Size(contentW, 4.5);
  vDisk.leftAlignImage();
}

// ==========================================
// MODAL CHI TIẾT KHI MỞ TRONG SCRIPTABLE APP
// ==========================================
async function showServerDetailModal(data) {
  const m = data.metrics || {};
  const alert = new Alert();
  alert.title = "🖥️ Ubuntu Server Telemetry";
  
  const devPorts = (data.ports || []).filter(p => !p.is_internal);
  const portsList = devPorts.map(p => `• Port ${p.port}: ${p.process} (${p.project})`).join("\n");
  
  const servicesList = (data.services || []).map(s => `• ${s.name}: ${s.active ? "Đang chạy" : "Dừng"}`).join("\n");

  alert.message = 
    `IP: 100.127.1.234\n` +
    `Uptime: ${m.uptime || "N/A"}\n` +
    `Trạng thái: ${data.is_online ? "Đang kết nối (Online)" : "Ngoại tuyến (Offline)"}\n\n` +
    `CPU: ${m.cpu_percent}% (${m.cpu_count} Cores)\n` +
    `Load Average: ${(m.load_avg || []).join(", ")}\n` +
    `RAM: ${m.ram_percent}% (${m.ram_used_gb} / ${m.ram_total_gb} GB)\n` +
    `Ổ cứng: ${m.disk_percent}% (Trống ${m.disk_free_gb} / ${m.disk_total_gb} GB)\n\n` +
    (portsList ? `Cổng Dev Đang Mở:\n${portsList}\n\n` : "") +
    (servicesList ? `Dịch Vụ:\n${servicesList}` : "");

  alert.addAction("Đóng");
  await alert.presentAlert();
}

// ==========================================
// HÀM CHÍNH ENTRY POINT
// ==========================================
async function main() {
  const data = await fetchTelemetryData();

  if (config.runsInApp) {
    await showServerDetailModal(data);
  }

  const widget = new ListWidget();
  widget.backgroundColor = TOKENS.bg;

  // Lên lịch làm mới tối ưu: 2 phút
  widget.refreshAfterDate = new Date(Date.now() + 120 * 1000);

  const family = config.widgetFamily || "medium";

  if (family === "small") {
    buildSmallWidget(widget, data);
  } else {
    buildMediumWidget(widget, data);
  }

  Script.setWidget(widget);

  if (config.runsInApp) {
    if (family === "small") {
      await widget.presentSmall();
    } else {
      await widget.presentMedium();
    }
  }

  Script.complete();
}

await main();
