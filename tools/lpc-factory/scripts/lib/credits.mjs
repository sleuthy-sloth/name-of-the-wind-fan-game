// credits.mjs — Collect and format credits/attribution for built sprites
// Aggregates credit info from all catalog items used in a character definition.

import fs from "fs";
import path from "path";

// Collect all credits from items used in a character definition
export function collectCredits(characterDef, assetIndex) {
  const catalog = assetIndex.catalog;
  const allCredits = [];
  const seenFiles = new Set();

  for (const layer of characterDef.layers || []) {
    const item = catalog[layer.item];
    if (!item || !item.credits) continue;

    for (const credit of item.credits) {
      const key = `${layer.item}:${credit.file}`;
      if (seenFiles.has(key)) continue;
      seenFiles.add(key);

      allCredits.push({
        item: layer.item,
        itemName: item.name,
        file: credit.file,
        notes: credit.notes || "",
        authors: credit.authors || [],
        licenses: credit.licenses || [],
        urls: credit.urls || [],
      });
    }
  }

  return allCredits;
}

// Get unique authors across all credits
export function getUniqueAuthors(credits) {
  const authors = new Map();
  for (const c of credits) {
    for (const a of c.authors) {
      if (!authors.has(a)) {
        authors.set(a, { name: a, items: [], licenses: new Set(), urls: new Set() });
      }
      const entry = authors.get(a);
      entry.items.push(c.itemName);
      c.licenses.forEach(l => entry.licenses.add(l));
      c.urls.forEach(u => entry.urls.add(u));
    }
  }
  return Array.from(authors.values()).map(a => ({
    name: a.name,
    items: [...new Set(a.items)],
    licenses: [...a.licenses],
    urls: [...a.urls],
  }));
}

// Get unique licenses across all credits
export function getUniqueLicenses(credits) {
  const licenses = new Set();
  for (const c of credits) {
    c.licenses.forEach(l => licenses.add(l));
  }
  return [...licenses];
}

// Format credits as a markdown file
export function formatCreditsMarkdown(characterName, credits) {
  const authors = getUniqueAuthors(credits);
  const licenses = getUniqueLicenses(credits);

  let md = `# Credits: ${characterName}\n\n`;
  md += `## Licenses\n\n`;
  for (const lic of licenses) {
    md += `- ${lic}\n`;
  }
  md += `\n## Authors\n\n`;
  for (const a of authors) {
    md += `### ${a.name}\n`;
    md += `- **Items:** ${a.items.join(", ")}\n`;
    md += `- **Licenses:** ${a.licenses.join(", ")}\n`;
    if (a.urls.length > 0) {
      md += `- **URLs:**\n`;
      for (const u of a.urls) {
        md += `  - ${u}\n`;
      }
    }
    md += `\n`;
  }
  md += `## Detailed Credits\n\n`;
  for (const c of credits) {
    md += `### ${c.itemName} (${c.item})\n`;
    md += `- **File:** ${c.file}\n`;
    if (c.notes) md += `- **Notes:** ${c.notes}\n`;
    md += `- **Authors:** ${c.authors.join(", ")}\n`;
    md += `- **Licenses:** ${c.licenses.join(", ")}\n`;
    if (c.urls.length > 0) {
      md += `- **URLs:** ${c.urls.join(", ")}\n`;
    }
    md += `\n`;
  }

  return md;
}

// Write credits to a file
export function writeCredits(outputPath, characterName, credits) {
  const md = formatCreditsMarkdown(characterName, credits);
  fs.writeFileSync(outputPath, md, "utf8");
  return outputPath;
}
