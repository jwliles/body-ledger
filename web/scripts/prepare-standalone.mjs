import { cpSync, existsSync, mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const standaloneDir = join(root, ".next", "standalone");
const standaloneNextDir = join(standaloneDir, ".next");

if (!existsSync(standaloneDir)) {
  throw new Error("Missing .next/standalone. Run `next build` first.");
}

mkdirSync(standaloneNextDir, { recursive: true });

const copies = [
  [join(root, "public"), join(standaloneDir, "public")],
  [join(root, ".next", "static"), join(standaloneNextDir, "static")],
];

for (const [source, destination] of copies) {
  if (!existsSync(source)) {
    throw new Error(`Missing ${source}. Run \`next build\` first.`);
  }

  rmSync(destination, { recursive: true, force: true });
  cpSync(source, destination, { recursive: true });
}
