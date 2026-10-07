import { build } from "esbuild";
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
const result = await build({
  entryPoints: [fileURLToPath(new URL("src/scene.js", import.meta.url))],
  bundle: true,
  minify: true,
  format: "esm",
  target: "es2022",
  write: false,
  legalComments: "eof",
});
const target = new URL("../assets/homepage/scene.js", import.meta.url);
const bytes = result.outputFiles[0].contents;
if (process.argv.includes("--check")) {
  if (!Buffer.from(await readFile(target)).equals(Buffer.from(bytes)))
    throw new Error("Homepage bundle differs from source");
  console.log("Homepage bundle matches source");
} else {
  await writeFile(target, bytes);
  console.log(`Built homepage: ${bytes.length} bytes`);
}
