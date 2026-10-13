// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: purple; icon-glyph: server;
/**
 * CodexBar iOS Widget - Claude Active Account Quota
 * Tái tạo 1:1 chuẩn xác theo giao diện macOS CodexBar
 * Hỗ trợ hiển thị: Phiên 5h (Đã dùng, Đặt lại), Hàng tuần (Đã dùng, Đặt lại)
 * Kèm thanh tiến trình Segmented Bar chuẩn Apple
 */

const CONFIG = {
  HOST: "100.127.1.234",
  PORT: "8318",
  TIMEOUT: 4,
  REFRESH_MIN: 10,
  CACHE_KEY: "codexbar_claude_quota_v6"
};

const URL_POOL = `http://${CONFIG.HOST}:${CONFIG.PORT}/v1/pool-status`;

// Bảng màu chuẩn CodexBar macOS
const C_BG_TOP = new Color("#161A1D");
const C_BG_BTM = new Color("#0F1215");

const C_TXT_PRIMARY = new Color("#FFFFFF", 0.95);
const C_TXT_SECONDARY = new Color("#9CA3AF");
const C_TXT_MUTED = new Color("#6B7280");

const C_ACCENT_ORANGE = new Color("#F97316"); // Màu cam của thanh tiến trình đã dùng
const C_SEGMENT_TRACK = new Color("#272D34"); // Màu rãnh nền xám
const C_MARKER_GREEN = new Color("#22C55E");  // Vạch xanh lá dự trữ nhịp độ

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

/**
 * Vẽ thanh tiến trình 3 đoạn (3 segments) chuẩn xác như macOS CodexBar
 * @param {number} width Chiều rộng thanh
 * @param {number} height Chiều cao thanh
 * @param {number} usedPct Phần trăm đã dùng (0 - 100)
 */
function drawSegmentedBar(width, height, usedPct) {
  const dc = new DrawContext();
  dc.size = new Size(width, height);
  dc.opaque = false;
  dc.respectScreenScale = true;

  const numSegments = 3;
  const gap = 4;
  const segW = (width - gap * (numSegments - 1)) / numSegments;
  const r = height / 2;

  // 1. Vẽ 3 rãnh nền xám (Track)
  for (let i = 0; i < numSegments; i++) {
    const x = i * (segW + gap);
    const p = new Path();
    p.addRoundedRect(new Rect(x, 0, segW, height), r, r);
    dc.addPath(p);
    dc.setFillColor(C_SEGMENT_TRACK);
    dc.fillPath();
  }

  // 2. Vẽ thanh màu cam (Fill) theo tỉ lệ usedPct
  const totalFillW = (width * Math.min(100, Math.max(0, usedPct))) / 100;
  let remainingFill = totalFillW;

  for (let i = 0; i < numSegments; i++) {
    if (remainingFill <= 0) break;
    const x = i * (segW + gap);
    const curSegFill = Math.min(segW, remainingFill);

    const p = new Path();
    p.addRoundedRect(new Rect(x, 0, curSegFill, height), r, r);
    dc.addPath(p);
    dc.setFillColor(C_ACCENT_ORANGE);
    dc.fillPath();

    remainingFill -= segW;
  }

  // 3. Vạch dự trữ nhịp độ xanh lá ở đoạn cuối
  const markerW = 3;
  const markerX = width - segW + (segW * 0.7);
  const mp = new Path();
  mp.addRoundedRect(new Rect(markerX, 0, markerW, height), 1.5, 1.5);
  dc.addPath(mp);
  dc.setFillColor(C_MARKER_GREEN);
  dc.fillPath();

  return dc.getImage();
}

// -------------------------------------------------------------
// MEDIUM WIDGET: Tái tạo 1:1 theo ảnh Desktop
// -------------------------------------------------------------
function buildMedium(w, data) {
  w.setPadding(12, 16, 12, 16);

  const acc = data.pool?.accounts?.[0] || {
    name: "projectplayground2025@gmail.com",
    plan: "Max 20x",
    used_5h: 11,
    remaining_5h: 89,
    reset_5h: "3h 49m",
    used_weekly: 16,
    remaining_weekly: 84,
    reset_weekly: "6d 17h"
  };

  // 1. HEADER (Claude, Email, Sync time, Gói)
  const row1 = w.addStack();
  row1.layoutHorizontally();
  row1.centerAlignContent();

  const title = row1.addText("Claude");
  title.font = Font.boldSystemFont(16);
  title.textColor = C_TXT_PRIMARY;

  row1.addSpacer();

  const email = row1.addText(acc.name);
  email.font = Font.systemFont(11);
  email.textColor = C_TXT_SECONDARY;
  email.lineLimit = 1;

  w.addSpacer(2);

  const row2 = w.addStack();
  row2.layoutHorizontally();

  const timeStr = data.time ? new Date(data.time).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" }) : "Vừa xong";
  const syncTxt = row2.addText(`Cập nhật lúc ${timeStr}`);
  syncTxt.font = Font.systemFont(10);
  syncTxt.textColor = C_TXT_MUTED;

  row2.addSpacer();

  const planTxt = row2.addText(`Gói ${acc.plan || "Max 20x"}`);
  planTxt.font = Font.systemFont(11);
  planTxt.textColor = C_TXT_SECONDARY;

  w.addSpacer(6);

  // Đường kẻ phân cách mỏng
  const div = w.addStack();
  div.size = new Size(0, 0.5);
  div.backgroundColor = new Color("#FFFFFF", 0.08);

  w.addSpacer(8);

  // 2. PHẦN 1: PHIÊN 5H
  const p5Head = w.addStack();
  p5Head.layoutHorizontally();
  p5Head.centerAlignContent();

  const p5Title = p5Head.addText(`Phiên 5h: ${acc.used_5h}% đã dùng`);
  p5Title.font = Font.boldSystemFont(13);
  p5Title.textColor = C_TXT_PRIMARY;

  p5Head.addSpacer();

  const p5Reset = p5Head.addText(`Đặt lại sau ${acc.reset_5h}`);
  p5Reset.font = Font.systemFont(10);
  p5Reset.textColor = C_TXT_SECONDARY;

  w.addSpacer(4);

  // Thanh tiến trình 5h
  const bar5Img = drawSegmentedBar(300, 5, acc.used_5h);
  const bar5View = w.addImage(bar5Img);
  bar5View.imageSize = new Size(300, 5);

  w.addSpacer(3);

  const sub5 = w.addText(`${acc.remaining_5h}% dự trữ nhịp độ`);
  sub5.font = Font.systemFont(9);
  sub5.textColor = C_TXT_MUTED;

  w.addSpacer(8);

  // 3. PHẦN 2: HÀNG TUẦN
  const pWkHead = w.addStack();
  pWkHead.layoutHorizontally();
  pWkHead.centerAlignContent();

  const pWkTitle = pWkHead.addText(`Hàng tuần: ${acc.used_weekly}% đã dùng`);
  pWkTitle.font = Font.boldSystemFont(13);
  pWkTitle.textColor = C_TXT_PRIMARY;

  pWkHead.addSpacer();

  const pWkReset = pWkHead.addText(`Đặt lại sau ${acc.reset_weekly}`);
  pWkReset.font = Font.systemFont(10);
  pWkReset.textColor = C_TXT_SECONDARY;

  w.addSpacer(4);

  // Thanh tiến trình Tuần
  const barWkImg = drawSegmentedBar(300, 5, acc.used_weekly);
  const barWkView = w.addImage(barWkImg);
  barWkView.imageSize = new Size(300, 5);
}

// -------------------------------------------------------------
// SMALL WIDGET
// -------------------------------------------------------------
function buildSmall(w, data) {
  w.setPadding(12, 12, 12, 12);
  const acc = data.pool?.accounts?.[0] || {
    name: "projectplayground2025@gmail.com",
    plan: "Max 20x",
    used_5h: 11,
    remaining_5h: 89,
    reset_5h: "3h 49m",
    used_weekly: 16,
    remaining_weekly: 84,
    reset_weekly: "6d 17h"
  };

  const h = w.addStack();
  h.layoutHorizontally();
  const t = h.addText("Claude");
  t.font = Font.boldSystemFont(14);
  t.textColor = C_TXT_PRIMARY;
  h.addSpacer();
  const pl = h.addText("20x");
  pl.font = Font.boldSystemFont(10);
  pl.textColor = C_TXT_SECONDARY;

  w.addSpacer(6);

  const u5 = w.addText(`5h: ${acc.used_5h}% đã dùng`);
  u5.font = Font.boldSystemFont(11);
  u5.textColor = C_TXT_PRIMARY;

  w.addSpacer(2);
  const bar5 = drawSegmentedBar(125, 4, acc.used_5h);
  const v5 = w.addImage(bar5);
  v5.imageSize = new Size(125, 4);

  w.addSpacer(2);
  const r5 = w.addText(`Reset ${acc.reset_5h}`);
  r5.font = Font.systemFont(9);
  r5.textColor = C_TXT_MUTED;

  w.addSpacer(8);

  const uw = w.addText(`Tuần: ${acc.used_weekly}% đã dùng`);
  uw.font = Font.boldSystemFont(11);
  uw.textColor = C_TXT_PRIMARY;

  w.addSpacer(2);
  const barW = drawSegmentedBar(125, 4, acc.used_weekly);
  const vW = w.addImage(barW);
  vW.imageSize = new Size(125, 4);

  w.addSpacer(2);
  const rw = w.addText(`Reset ${acc.reset_weekly}`);
  rw.font = Font.systemFont(9);
  rw.textColor = C_TXT_MUTED;
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
