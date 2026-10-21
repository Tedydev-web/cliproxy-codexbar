const BRIDGE = "http://100.127.1.234:8318";
const BRIDGE_SECRET = "PASTE_CLIPROXY_BRIDGE_SECRET_HERE";

const selector = String(args.widgetParameter || Script.name()).toLowerCase();
const file = selector.includes("agy") ? "OrbiterAGYWidget.js" : "OrbiterClaudeWidget.js";
const fm = FileManager.local();
const cachePath = fm.joinPath(fm.documentsDirectory(), `orbiter-loader-cache-${file}`);

let code = null;
try {
  const req = new Request(`${BRIDGE}/v1/widget/${file}`);
  req.headers = { Authorization: `Bearer ${BRIDGE_SECRET}` };
  req.timeoutInterval = 10;
  const body = await req.loadString();
  if (req.response.statusCode === 200) {
    code = body;
    fm.writeString(cachePath, code);
  } else {
    console.log(`[Orbiter Loader] ${file}: HTTP ${req.response.statusCode}, using cache`);
  }
} catch (e) {
  console.log(`[Orbiter Loader] ${file}: ${e}, using cache`);
}

if (!code && fm.fileExists(cachePath)) {
  code = fm.readString(cachePath);
}

if (code) {
  const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
  await new AsyncFunction(code)();
} else {
  const w = new ListWidget();
  w.addText(`Orbiter: không tải được ${file} và chưa có bản cache`);
  if (config.runsInWidget) {
    Script.setWidget(w);
  } else {
    await w.presentSmall();
  }
  Script.complete();
}
