const fm = FileManager.local();
const STATE_PATH = fm.joinPath(orbiter.cacheDir, "notify-state.json");
const STATE_TTL_MS = 8 * 86400 * 1000;
const WARN_PCT = 90;
const LIVE_REFRESH_MS = 10000;

const pct = (n) => (typeof n === "number" && Number.isFinite(n) ? `${n}%` : "-");
const shortName = (a) => String(a.name || a.email || "").replace(/@gmail\.com$/i, "");
const withQuery = (url, query) => `${url}${url.includes("?") ? "&" : "?"}${query}`;
const fiveHourBucket = () => Math.floor(Date.now() / (5 * 3600 * 1000));
const weekBucket = () => Math.floor(Date.now() / (7 * 86400 * 1000));

async function pool() {
  const p = await orbiter.api("/v1/pool-status");
  if (!p || !Array.isArray(p.accounts)) throw new orbiter.OrbiterError(502, "pool-status trả dữ liệu không hợp lệ");
  return p;
}

const keyStateLabel = (state) =>
  ({ ok: "còn credit", no_credit: "HẾT credit", invalid: "key không hợp lệ", rate_limited: "đang bị giới hạn", disabled: "đang tắt", unknown: "đang kiểm tra" })[state] || "chưa kiểm tra được";

const consoleAccount = (k) => ({
  email: k.id,
  name: k.id,
  is_console: true,
  is_paused: false,
  is_disabled: !k.enabled,
  is_available: k.enabled && (k.state === "ok" || k.state === "rate_limited" || k.state === "unknown"),
  console: k,
});

function routeRows(p) {
  const pool = new Map(liveAccounts(p).map((a) => [a.email, a]));
  const keys = new Map(((p.console && p.console.keys) || []).map((k) => [k.id, consoleAccount(k)]));
  const rows = [];
  for (const id of p.order || []) {
    const row = pool.get(id) || keys.get(id);
    if (row) rows.push(row);
  }
  for (const a of pool.values()) if (!rows.includes(a)) rows.push(a);
  return rows;
}

const liveAccounts = (p) => (p.accounts || []).filter((a) => !a.is_paused);
const activeAccount = (p) => liveAccounts(p).find((a) => !a.is_disabled) || null;

const rowTitle = (a) =>
  a.is_console
    ? `${a.console.org || a.email} [${a.email}]`
    : `${shortName(a)}${a.plan ? ` [${a.plan}]` : ""}`;

function clockAfter(rel) {
  const parts = String(rel || "").trim().split(/\s+/);
  let sec = 0;
  for (const part of parts) {
    const n = parseFloat(part);
    if (!Number.isFinite(n)) continue;
    if (part.endsWith("d")) sec += n * 86400;
    else if (part.endsWith("h")) sec += n * 3600;
    else if (part.endsWith("m")) sec += n * 60;
    else if (part.endsWith("s")) sec += n;
  }
  if (sec <= 0) return "";
  const t = new Date(Date.now() + sec * 1000);
  const hm = `${String(t.getHours()).padStart(2, "0")}:${String(t.getMinutes()).padStart(2, "0")}`;
  const now = new Date();
  if (t.toDateString() === now.toDateString()) return hm;
  const tomorrow = new Date(now.getTime() + 86400000);
  if (t.toDateString() === tomorrow.toDateString()) return `Mai ${hm}`;
  return `${String(t.getDate()).padStart(2, "0")}/${String(t.getMonth() + 1).padStart(2, "0")} ${hm}`;
}

function quotaLine(label, used, rel) {
  const when = rel ? `hồi ${rel}${clockAfter(rel) ? ` · ${clockAfter(rel)}` : ""}` : label === "5h" ? "chưa bắt đầu" : "chưa có mốc";
  const flag = typeof used === "number" && used >= 100 ? " ⛔" : "";
  return `${label} ${pct(used)}${flag} · ${when}`;
}

function rowDetail(a) {
  if (a.is_console) {
    const state = a.console.state;
    if (a.is_disabled) return "Đang tắt";
    if (state === "no_credit") return "Cần nạp thêm tại Console";
    if (state === "ok") return "Không xem được số dư";
    return keyStateLabel(state)[0].toUpperCase() + keyStateLabel(state).slice(1);
  }
  return `${quotaLine("5h", a.used_5h, a.reset_5h)}\n${quotaLine("Tuần", a.used_weekly, a.reset_weekly)}`;
}

function accountLine(a, index) {
  if (a.is_paused) return `${shortName(a)}: đã cách ly (${a.error_hint || "cần đăng nhập lại"})`;
  const flags = [];
  if (a.is_disabled) flags.push("đang tắt");
  if (a.is_available === false) flags.push("hết quota");
  if (a.lifecycle_status === "critical" || a.lifecycle_status === "expired") flags.push(a.lifecycle_label);
  return `#${index + 1} ${shortName(a)}: 5h ${pct(a.used_5h)} · tuần ${pct(a.used_weekly)}${flags.length ? ` (${flags.join(", ")})` : ""}`;
}

function summary(p) {
  const live = liveAccounts(p);
  const paused = (p.accounts || []).filter((a) => a.is_paused);
  const keyLines = ((p.console && p.console.keys) || []).map((k) => `${k.id}${k.org ? ` (${k.org})` : ""}: ${keyStateLabel(k.state)}`);
  const act = activeAccount(p);
  const lines = [act ? `Đang chạy: ${shortName(act)}, 5h ${pct(act.used_5h)}, tuần ${pct(act.used_weekly)}` : "Không có account nào đang bật"];
  live.forEach((a, i) => lines.push(accountLine(a, i)));
  paused.forEach((a) => lines.push(accountLine(a)));
  keyLines.forEach((l) => lines.push(l));
  return lines.join("\n");
}

function loadState() {
  try {
    return fm.fileExists(STATE_PATH) ? JSON.parse(fm.readString(STATE_PATH)) : {};
  } catch (_) {
    return {};
  }
}

function notificationRules(p) {
  const rules = [];
  const act = activeAccount(p);
  if (act && act.used_5h >= WARN_PCT) {
    rules.push([`${act.email}|5h|${act.reset_5h_ts || fiveHourBucket()}`, `Quota 5h của ${shortName(act)} đã ${act.used_5h}%`, act.reset_5h || "Sắp chạm giới hạn 5 giờ"]);
  }
  if (act && act.used_weekly >= WARN_PCT) {
    rules.push([`${act.email}|wk|${act.reset_weekly_ts || weekBucket()}`, `Quota tuần của ${shortName(act)} đã ${act.used_weekly}%`, act.reset_weekly || "Sắp chạm giới hạn tuần"]);
  }
  for (const a of p.accounts || []) {
    if (a.is_paused) {
      rules.push([`${a.email}|paused`, `${shortName(a)} đã bị cách ly`, a.error_hint || "Token hết hạn, cần đăng nhập lại"]);
    } else if (a.lifecycle_status === "critical" || a.lifecycle_status === "expired") {
      rules.push([`${a.email}|life|${a.expiry_30d_str || ""}`, `${shortName(a)}: ${a.lifecycle_label}`, a.expiry_30d_str ? `Hạn: ${a.expiry_30d_str}` : ""]);
    }
  }
  return rules;
}

async function sendNotification(identifier, title, body) {
  const n = new Notification();
  n.identifier = identifier;
  n.threadIdentifier = "orbiter";
  n.title = title;
  n.body = body;
  n.openURL = withQuery(orbiter.runURL, "action=control");
  await n.schedule();
}

async function notify(p) {
  const now = Date.now();
  const state = loadState();
  const fired = [];
  for (const [key, title, body] of notificationRules(p)) {
    if (state[key]) continue;
    try {
      await sendNotification(key, title, body);
      state[key] = now;
      fired.push(key);
    } catch (e) {
      console.log(`[Orbiter] notification failed: ${e}`);
    }
  }
  for (const key of Object.keys(state)) {
    if (now - state[key] > STATE_TTL_MS) delete state[key];
  }
  fm.writeString(STATE_PATH, JSON.stringify(state));
  return fired;
}

async function confirm(title, message, action) {
  const a = new Alert();
  a.title = title;
  a.message = message;
  a.addAction(action);
  a.addCancelAction("Huỷ");
  return (await a.presentAlert()) === 0;
}

async function info(title, message) {
  const a = new Alert();
  a.title = title;
  a.message = message;
  a.addAction("OK");
  await a.presentAlert();
}

async function setFirst(a) {
  return orbiter.api("/v1/set-priority", { method: "POST", body: { email: a.email } });
}

async function setBackup(body) {
  return orbiter.api("/v1/set-backup", { method: "POST", body });
}

function backupStatus(b) {
  if (!b.online) return "Ngoại tuyến";
  const usable = (b.models || []).some((m) => m.usable);
  return usable ? `Có thể dùng · ${(b.latency_ms / 1000).toFixed(1)}s` : "Model không khả dụng";
}

async function backupActions(b) {
  const enabled = Boolean(b.fallback && b.fallback.enabled);
  const sheet = new Alert();
  sheet.title = "Dự phòng · Aperture";
  sheet.message = `${backupStatus(b)}\n${enabled ? "Đang tự dùng khi hết quota Claude và capi" : "Đang tắt, chỉ dùng khi gọi đích danh aperture/…"}`;
  const actions = [];
  actions.push([enabled ? "Tắt tự dùng khi hết quota" : "Bật tự dùng khi hết quota", async () => {
    if (enabled || (await confirm("Bật dự phòng Aperture?", "Khi mọi account Claude và capi đều hết quota, request Claude sẽ tự chuyển sang model dự phòng. Mọi ứng dụng dùng chung proxy (kể cả production) cũng sẽ nhận câu trả lời từ model đó thay vì lỗi 429, chất lượng có thể thấp hơn Claude.", "Bật dự phòng"))) {
      await setBackup({ enabled: !enabled });
    }
  }]);
  for (const m of b.models || []) {
    actions.push([`${m.selected ? "● " : "○ "}${m.label}${m.usable ? "" : " (không khả dụng)"}`, async () => {
      if (!m.selected) await setBackup({ model: m.key });
    }]);
  }
  for (const [title] of actions) sheet.addAction(title);
  sheet.addCancelAction("Đóng");
  const choice = await sheet.presentSheet();
  if (choice < 0) return;
  try {
    await actions[choice][1]();
  } catch (e) {
    await info("Không thực hiện được", e.message || String(e));
  }
}

async function setEnabled(a, enabled) {
  return orbiter.api("/v1/set-enabled", { method: "POST", body: { email: a.email, enabled } });
}

async function accountActions(a, isFirst) {
  const actions = [];
  if (!a.is_paused && !a.is_disabled && !isFirst) {
    actions.push(["Đặt làm #1", async () => {
      if (await confirm(`Đặt ${shortName(a)} làm #1?`, "Request mới sẽ vào account này. Phiên đang chạy giữ credential cũ tới khi hết session affinity (1 giờ) hoặc khi failover.", "Đặt làm #1")) {
        await setFirst(a);
      }
    }]);
  }
  if (!a.is_paused) {
    actions.push([a.is_disabled ? "Bật account" : "Tắt account", async () => {
      const enabling = Boolean(a.is_disabled);
      const message = enabling ? "CLIProxy sẽ dùng lại account này theo thứ tự ưu tiên." : "CLIProxy sẽ không dùng account này cho tới khi bật lại.";
      if (await confirm(`${enabling ? "Bật" : "Tắt"} ${shortName(a)}?`, message, enabling ? "Bật" : "Tắt")) {
        await setEnabled(a, enabling);
      }
    }]);
  }
  actions.push(["Copy email", async () => Pasteboard.copy(a.email)]);

  const sheet = new Alert();
  sheet.title = shortName(a);
  sheet.message = a.is_console
    ? `Console API${a.console.org ? ` · ${a.console.org}` : ""}\n${keyStateLabel(a.console.state)}`
    : a.is_paused ? a.error_hint || "Đã cách ly" : `5h ${pct(a.used_5h)} · tuần ${pct(a.used_weekly)}\n${a.reset_5h || ""}\n${a.lifecycle_label || ""}`.trim();
  for (const [title] of actions) sheet.addAction(title);
  sheet.addCancelAction("Đóng");
  const choice = await sheet.presentSheet();
  if (choice < 0) return;
  try {
    await actions[choice][1]();
  } catch (e) {
    await info("Không thực hiện được", e.message || String(e));
  }
}

function addTextRow(table, title, subtitle, onSelect) {
  const row = new UITableRow();
  row.height = subtitle ? (String(subtitle).includes("\n") ? 78 : 60) : 44;
  row.addText(title, subtitle);
  if (onSelect) {
    row.dismissOnSelect = false;
    row.onSelect = onSelect;
  }
  table.addRow(row);
  return row;
}

async function controlPanel({ preview } = {}) {
  const table = new UITable();
  table.showSeparators = true;
  let p = await pool();
  let updatedAt = new Date();
  let offline = false;
  let busy = false;

  const refresh = async (silent = false) => {
    if (busy) return;
    busy = true;
    try {
      p = await pool();
      updatedAt = new Date();
      offline = false;
    } catch (e) {
      offline = true;
      if (!silent) await info("Không tải được pool", e.message || String(e));
    } finally {
      busy = false;
    }
    render();
    table.reload();
  };

  function render() {
    table.removeAllRows();
    const header = new UITableRow();
    header.isHeader = true;
    header.height = 60;
    header.addText("Orbiter · Thứ tự sử dụng", `Cập nhật ${updatedAt.toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" })} · tự làm mới mỗi ${LIVE_REFRESH_MS / 1000}s${offline ? " · mất kết nối" : ""}${orbiter.stale ? " · đang chạy code cache" : ""}`);
    table.addRow(header);

    const rows = routeRows(p);
    const act = rows.find((a) => !a.is_disabled && a.is_available !== false) || rows.find((a) => !a.is_disabled) || null;
    rows.forEach((a, i) => {
      const marker = a.is_disabled ? "○" : a === act ? "●" : "◦";
      addTextRow(table, `${marker} #${i + 1} ${rowTitle(a)}`, rowDetail(a), async () => {
        await accountActions(a, i === 0);
        await refresh();
      });
    });
    (p.accounts || []).filter((a) => a.is_paused).forEach((a) => {
      addTextRow(table, `× ${shortName(a)}`, a.error_hint || "Đã cách ly", async () => {
        await accountActions(a, false);
      });
    });

    if (p.backup) {
      const b = p.backup;
      const on = Boolean(b.fallback && b.fallback.enabled);
      const sel = (b.models || []).find((m) => m.selected);
      addTextRow(
        table,
        `${on ? "●" : "○"} Dự phòng khi hết quota [Aperture]`,
        `${backupStatus(b)}\n${on ? `Tự chuyển sang ${sel ? sel.label : "model dự phòng"}` : "Đang tắt"}`,
        async () => {
          await backupActions(b);
          await refresh();
        }
      );
    }

    addTextRow(table, "Làm mới", null, () => refresh(false));
    if (preview) addTextRow(table, "Xem trước widget", null, async () => preview());
    addTextRow(table, "Gửi thông báo thử", "Lần đầu iOS sẽ hỏi quyền thông báo", async () => {
      try {
        await sendNotification(`test-${Date.now()}`, "Orbiter", summary(p));
      } catch (e) {
        await info("Không gửi được thông báo", e.message || String(e));
      }
    });
    addTextRow(table, "Cấu hình bridge", "Đổi secret hoặc URL", async () => {
      await orbiter.settings();
      await refresh();
    });
    addTextRow(table, "Xoá cache code", "Lần chạy sau tải lại toàn bộ code", async () => {
      orbiter.clearCache();
      await info("Orbiter", "Đã xoá cache code.");
    });
  }

  render();
  const timer = Timer.schedule(LIVE_REFRESH_MS, true, () => refresh(true));
  try {
    await table.present(true);
  } finally {
    timer.invalidate();
  }
}

function findAccount(p, query) {
  const q = String(query || "").trim().toLowerCase();
  if (!q) return null;
  const matches = (p.accounts || []).filter((a) => `${a.email} ${a.name}`.toLowerCase().includes(q));
  return matches.length === 1 ? matches[0] : null;
}

function parseCommand(input) {
  if (input && typeof input === "object") return { action: String(input.action || "status").toLowerCase(), account: input.account || "" };
  const words = String(input || "status").trim().split(/\s+/);
  return { action: (words.shift() || "status").toLowerCase(), account: words.join(" ") };
}

async function shortcut(input) {
  const { action, account } = parseCommand(input);
  const p = await pool();
  let out;
  if (["status", "trạng", "trạng thái", "quota"].includes(action)) {
    out = summary(p);
  } else if (action === "json") {
    out = { active: activeAccount(p), accounts: p.accounts };
  } else if (["switch", "chuyển", "first"].includes(action)) {
    const a = findAccount(p, account);
    if (!a || a.is_paused) out = `Không tìm thấy đúng một account khớp "${account}"`;
    else if (a.is_disabled) out = `${shortName(a)} đang tắt, bật trước rồi mới đặt làm #1`;
    else {
      await setFirst(a);
      out = `Đã đặt ${shortName(a)} làm #1`;
    }
  } else if (["enable", "bật", "disable", "tắt"].includes(action)) {
    const enabling = action === "enable" || action === "bật";
    const a = findAccount(p, account);
    if (!a || a.is_paused) out = `Không tìm thấy đúng một account khớp "${account}"`;
    else {
      try {
        await setEnabled(a, enabling);
        out = `Đã ${enabling ? "bật" : "tắt"} ${shortName(a)}`;
      } catch (e) {
        out = `Không ${enabling ? "bật" : "tắt"} được ${shortName(a)}: ${e.message}`;
      }
    }
  } else {
    out = `Lệnh không hỗ trợ: "${action}". Dùng: status | json | switch <account> | enable <account> | disable <account>`;
  }
  Script.setShortcutOutput(out);
  return out;
}

return { pool, summary, activeAccount, liveAccounts, notify, controlPanel, shortcut, withQuery, pct, shortName };
