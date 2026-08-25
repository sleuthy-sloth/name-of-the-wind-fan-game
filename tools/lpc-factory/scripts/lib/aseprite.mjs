import { execFileSync } from "child_process";
import fs from "fs";
import path from "path";

export function findAseprite(factoryRoot) {
  const localConfig = path.join(factoryRoot, "config", "local.json");
  if (fs.existsSync(localConfig)) {
    const cfg = JSON.parse(fs.readFileSync(localConfig, "utf8"));
    if (cfg.asepritePath && fs.existsSync(cfg.asepritePath)) {
      return cfg.asepritePath;
    }
  }
  const wrapper = path.join(factoryRoot, "bin", "aseprite");
  if (fs.existsSync(wrapper)) return wrapper;
  const common = [
    "/opt/homebrew/bin/aseprite",
    "/Applications/Aseprite.app/Contents/MacOS/aseprite",
    "/usr/local/bin/aseprite",
  ];
  for (const p of common) {
    if (fs.existsSync(p)) return p;
  }
  throw new Error("Aseprite binary not found. Set asepritePath in config/local.json");
}

export function runAseprite(asepritePath, args, options = {}) {
  const opts = {
    cwd: options.cwd || process.cwd(),
    timeout: options.timeout || 120000,
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
    ...options,
  };
  try {
    const output = execFileSync(asepritePath, args, opts);
    return { success: true, output: output || "", stderr: "" };
  } catch (err) {
    return {
      success: false,
      output: err.stdout || "",
      stderr: err.stderr || err.message,
      code: err.status,
    };
  }
}

export function runLuaWithGlobals(asepritePath, scriptPath, globals, options = {}) {
  const wrapperDir = path.dirname(scriptPath);
  const wrapperPath = path.join(wrapperDir, "_wrapper_" + Date.now() + ".lua");
  let wrapper = "";
  for (const [name, value] of Object.entries(globals)) {
    if (typeof value === "string") {
      if (value.startsWith("{") || value.startsWith("dofile")) {
        wrapper += name + " = " + value + "\n";
      } else {
        wrapper += name + " = \"" + value + "\"\n";
      }
    } else if (typeof value === "number") {
      wrapper += name + " = " + value + "\n";
    } else if (typeof value === "boolean") {
      wrapper += name + " = " + value + "\n";
    } else {
      wrapper += name + " = " + value + "\n";
    }
  }
  wrapper += "dofile(\"" + scriptPath + "\")\n";
  fs.writeFileSync(wrapperPath, wrapper, "utf8");
  const args = ["-b", "--script", wrapperPath];
  const result = runAseprite(asepritePath, args, options);
  try { fs.unlinkSync(wrapperPath); } catch (e) { }
  return result;
}

export function getVersion(asepritePath) {
  const result = runAseprite(asepritePath, ["--version"], { timeout: 10000 });
  if (result.success) return result.output.trim();
  return "unknown";
}
