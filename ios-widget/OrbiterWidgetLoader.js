const KC_SECRET = "orbiter.bridge.secret";
const KC_HOST = "orbiter.bridge.host";
const DEFAULT_HOST = "http://100.127.1.234:8318";
const LOADER_VERSION = 2;

const fm = FileManager.local();
const cacheDir = fm.joinPath(fm.libraryDirectory(), "orbiter");
if (!fm.fileExists(cacheDir)) fm.createDirectory(cacheDir, true);
for (const f of fm.listContents(fm.documentsDirectory())) {
  if (f.startsWith("orbiter-loader-cache-")) fm.remove(fm.joinPath(fm.documentsDirectory(), f));
}

const selector = String(args.widgetParameter || Script.name()).toLowerCase();
const entry = selector.includes("agy") ? "OrbiterAGYWidget.js" : "OrbiterClaudeWidget.js";
const shortcutInput = args.shortcutParameter === undefined ? null : args.shortcutParameter;

const host = () => (Keychain.contains(KC_HOST) ? Keychain.get(KC_HOST) : DEFAULT_HOST);
const secret = () => (Keychain.contains(KC_SECRET) ? Keychain.get(KC_SECRET) : "");
const headerOf = (headers, name) => {
  const key = Object.keys(headers || {}).find((k) => k.toLowerCase() === name);
  return key ? headers[key] : null;
};

class OrbiterError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function settings(message) {
  const a = new Alert();
  a.title = "Orbiter";
  a.message = message || "Cấu hình kết nối tới bridge.";
  a.addSecureTextField("Bridge secret (CLIPROXY_MANAGEMENT_SECRET)", "");
  a.addTextField("Bridge URL", host());
  a.addAction("Lưu");
  a.addCancelAction("Huỷ");
  if ((await a.presentAlert()) === -1) return false;
  const s = a.textFieldValue(0).trim();
  const h = a.textFieldValue(1).trim().replace(/\/+$/, "");
  if (s) Keychain.set(KC_SECRET, s);
  if (h) Keychain.set(KC_HOST, h);
  return Boolean(s || secret());
}

async function send(path, { method = "GET", body, timeout = 8 } = {}) {
  const req = new Request(`${host()}${path}`);
  req.method = method;
  req.timeoutInterval = timeout;
  req.headers = { Authorization: `Bearer ${secret()}`, "Content-Type": "application/json" };
  if (body !== undefined) req.body = JSON.stringify(body);
  const text = await req.loadString();
  return { status: req.response.statusCode, headers: req.response.headers || {}, text };
}

async function api(path, opts = {}, retried = false) {
  const r = await send(path, opts);
  if (r.status === 401) {
    if (config.runsInApp && !retried && (await settings("Bridge từ chối secret (401). Nhập secret mới."))) {
      return api(path, opts, true);
    }
    throw new OrbiterError(401, "Bridge từ chối secret, mở script trong app để nhập lại");
  }
  let data = null;
  try {
    data = r.text ? JSON.parse(r.text) : null;
  } catch (_) {
    data = null;
  }
  if (r.status < 200 || r.status >= 300) {
    throw new OrbiterError(r.status, (data && data.error) || `HTTP ${r.status}`);
  }
  return data;
}

async function fetchCode(file, retried = false) {
  const codePath = fm.joinPath(cacheDir, file);
  const tagPath = `${codePath}.etag`;
  const cached = fm.fileExists(codePath) ? fm.readString(codePath) : null;
  const cachedTag = cached && fm.fileExists(tagPath) ? fm.readString(tagPath) : null;
  let status = null;
  let error = null;
  try {
    const head = await send(`/v1/widget/${file}`, { method: "HEAD", timeout: 4 });
    status = head.status;
    const tag = headerOf(head.headers, "etag");
    if (status === 200 && tag && tag === cachedTag) return { code: cached, stale: false };
  } catch (_) {
    status = null;
  }
  if (status !== 401) {
    try {
      const r = await send(`/v1/widget/${file}`, { timeout: 8 });
      status = r.status;
      if (status === 200 && r.text) {
        fm.writeString(codePath, r.text);
        fm.writeString(tagPath, headerOf(r.headers, "etag") || "");
        return { code: r.text, stale: false };
      }
    } catch (e) {
      error = e.message || String(e);
    }
  }
  if (status === 401) {
    if (!retried && config.runsInApp && (await settings("Bridge từ chối secret (401). Nhập secret mới."))) {
      return fetchCode(file, true);
    }
    error = "Bridge từ chối secret (401)";
  }
  return { code: cached, stale: true, error: error || `HTTP ${status}` };
}

const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const modules = {};

const orbiter = {
  version: LOADER_VERSION,
  entry,
  scriptName: Script.name(),
  mode: config.runsInWidget ? "widget" : config.runsWithSiri ? "siri" : shortcutInput !== null ? "shortcut" : "app",
  family: config.widgetFamily,
  params: args.queryParameters || {},
  input: shortcutInput,
  widgetParameter: args.widgetParameter === undefined ? null : args.widgetParameter,
  runURL: URLScheme.forRunningScript(),
  cacheDir,
  stale: false,
  errors: [],
  host,
  api,
  settings,
  OrbiterError,
  async load(file) {
    if (modules[file]) return modules[file];
    const res = await fetchCode(file);
    if (res.stale) {
      orbiter.stale = true;
      orbiter.errors.push(`${file}: ${res.error}`);
    }
    if (!res.code) throw new OrbiterError(503, `Không tải được ${file} (${res.error}) và chưa có cache`);
    modules[file] = (await new AsyncFunction("orbiter", res.code)(orbiter)) || {};
    return modules[file];
  },
  clearCache() {
    for (const f of fm.listContents(cacheDir)) fm.remove(fm.joinPath(cacheDir, f));
  }
};

async function fail(message) {
  if (config.runsInWidget) {
    const w = new ListWidget();
    w.url = orbiter.runURL;
    const t = w.addText(`Orbiter: ${message}`);
    t.font = Font.systemFont(12);
    Script.setWidget(w);
  } else if (orbiter.mode === "shortcut" || orbiter.mode === "siri") {
    Script.setShortcutOutput(`Orbiter: ${message}`);
  } else {
    const a = new Alert();
    a.title = "Orbiter";
    a.message = message;
    a.addAction("Cấu hình bridge");
    a.addAction("Xoá cache code");
    a.addCancelAction("Đóng");
    const choice = await a.presentAlert();
    if (choice === 0) await settings();
    if (choice === 1) orbiter.clearCache();
  }
}

try {
  if (!secret() && !(config.runsInApp && (await settings("Lần chạy đầu: nhập bridge secret.")))) {
    await fail("chưa có bridge secret, mở script trong app để nhập");
  } else {
    await orbiter.load(entry);
  }
} catch (e) {
  await fail(e.message || String(e));
}
Script.complete();
