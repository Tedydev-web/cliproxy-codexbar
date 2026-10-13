// Variables used by Scriptable.
// These must be at the very top of the file. Do not edit.
// icon-color: purple; icon-glyph: server;
/**
 * CLIProxy / CodexBar Quota & Server Telemetry Widget for iOS
 * Compatible with Scriptable (iOS Home Screen & Lock Screen)
 * 
 * Host: Tailscale IP or Local Network IP of Ubuntu Server
 */

// 1. CẤU HÌNH KẾT NỐI (Sử dụng IP Tailscale hoặc Domain Cloudflare Tunnel)
const SERVER_HOST = "100.127.1.234"; // Tailscale IP của Ubuntu Host
const SERVER_PORT = "8318";
const API_POOL_URL = `http://${SERVER_HOST}:${SERVER_PORT}/v1/pool-status`;
const API_TELEMETRY_URL = `http://${SERVER_HOST}:${SERVER_PORT}/v1/system-telemetry`;

// Timeout mạng (giây)
const TIMEOUT_SEC = 5;

async function fetchData(url) {
  try {
    const req = new Request(url);
    req.timeoutInterval = TIMEOUT_SEC;
    return await req.loadJSON();
  } catch (e) {
    return null;
  }
}

async function createWidget() {
  const widget = new ListWidget();
  widget.backgroundColor = new Color("#161618");
  widget.setPadding(14, 14, 14, 14);

  // Fetch song song pool status và system telemetry
  const [poolData, sysData] = await Promise.all([
    fetchData(API_POOL_URL),
    fetchData(API_TELEMETRY_URL)
  ]);

  // Header: Tiêu đề + Server Status Dot
  const headerStack = widget.addStack();
  headerStack.layoutHorizontally();
  headerStack.centerAlignContent();

  const title = headerStack.addText("⚡ CODEXBAR");
  title.textColor = new Color("#A1A1A6");
  title.font = Font.boldSystemFont(11);

  headerStack.addSpacer();

  const isOnline = poolData !== null || sysData !== null;
  const statusDot = headerStack.addText(isOnline ? "● ON" : "○ OFF");
  statusDot.textColor = isOnline ? new Color("#30D158") : new Color("#FF453A");
  statusDot.font = Font.systemFont(10);

  widget.addSpacer(8);

  if (!isOnline) {
    const errText = widget.addText("Không thể kết nối đến Host.\nVui lòng bật Tailscale trên iPhone.");
    errText.textColor = new Color("#8E8E93");
    errText.font = Font.systemFont(11);
    return widget;
  }

  // 1. Telemetry row (CPU & RAM) nếu có
  if (sysData && sysData.cpu) {
    const sysStack = widget.addStack();
    sysStack.layoutHorizontally();

    const cpuText = sysStack.addText(`CPU: ${sysData.cpu.current.toFixed(1)}%`);
    cpuText.textColor = new Color("#E5E5EA");
    cpuText.font = Font.mediumSystemFont(12);

    sysStack.addSpacer();

    const ramText = sysStack.addText(`RAM: ${sysData.memory.used_percent.toFixed(0)}%`);
    ramText.textColor = new Color("#E5E5EA");
    ramText.font = Font.mediumSystemFont(12);

    widget.addSpacer(8);
  }

  // 2. Claude Quota Accounts (Top #1 & #2 Account)
  if (poolData && poolData.accounts && poolData.accounts.length > 0) {
    const accounts = poolData.accounts.slice(0, 2); // Lấy 2 account ưu tiên hàng đầu

    accounts.forEach((acc, idx) => {
      const accStack = widget.addStack();
      accStack.layoutVertical();

      // Account name row
      const nameRow = accStack.addStack();
      nameRow.layoutHorizontally();
      
      const emailShort = acc.name.split("@")[0];
      const accName = nameRow.addText(`${idx === 0 ? "★ " : ""}${emailShort}`);
      accName.textColor = idx === 0 ? new Color("#FF9F0A") : new Color("#FFFFFF");
      accName.font = Font.boldSystemFont(11);
      accName.lineLimit = 1;

      nameRow.addSpacer();

      const planBadge = nameRow.addText(`${acc.plan || "Max"}`);
      planBadge.textColor = new Color("#8E8E93");
      planBadge.font = Font.systemFont(10);

      // Quota details row
      const quotaRow = accStack.addStack();
      quotaRow.layoutHorizontally();

      const q5h = quotaRow.addText(`5h: ${acc.remaining_5h}% (${acc.reset_5h})`);
      q5h.textColor = acc.remaining_5h > 20 ? new Color("#30D158") : new Color("#FF453A");
      q5h.font = Font.systemFont(10);

      quotaRow.addSpacer();

      const qWk = quotaRow.addText(`Wk: ${acc.remaining_weekly}%`);
      qWk.textColor = new Color("#0A84FF");
      qWk.font = Font.systemFont(10);

      widget.addSpacer(6);
    });
  }

  // Footer: Last updated time
  widget.addSpacer();
  const dateStr = new Date().toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" });
  const footer = widget.addText(`Cập nhật lúc ${dateStr}`);
  footer.textColor = new Color("#636366");
  footer.font = Font.systemFont(9);

  return widget;
}

const widget = await createWidget();
if (config.runsInWidget) {
  Script.setWidget(widget);
} else {
  widget.presentMedium();
}
Script.complete();
