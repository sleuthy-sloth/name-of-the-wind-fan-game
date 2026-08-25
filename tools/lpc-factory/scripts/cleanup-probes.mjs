import fs from "fs";
const targets = [
  "scripts/_probe2.mjs", "config/.writeprobe",
  "aseprite/compose.lua", "aseprite/combine.lua",
];
let removed = 0;
for (const t of targets) { try { fs.unlinkSync(t); removed++; } catch (e) {} }
console.log("removed", removed);
