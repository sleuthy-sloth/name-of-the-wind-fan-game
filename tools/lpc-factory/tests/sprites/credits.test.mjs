// credits.test.mjs — Credit collection and aggregation helpers
import test from "node:test";
import assert from "node:assert/strict";

import {
  collectCredits, getUniqueAuthors, getUniqueLicenses,
} from "../../scripts/lib/credits.mjs";
import { formatCreditsMarkdown } from "../../scripts/lib/credits.mjs";

const syntheticIndex = {
  catalog: {
    "body.body_color": {
      name: "Body color",
      credits: [
        { file: "body/bodies/male/universal-light.png",
          authors: ["Jane Doe"], licenses: ["CC-BY-SA 3.0"], urls: ["https://example.com/jane"] },
        { file: "body/bodies/male/universal-light.png", // duplicate across layers
          authors: ["Jane Doe"], licenses: ["CC-BY-SA 3.0"], urls: [] },
      ],
    },
    "clothes.longsleeve": {
      name: "Longsleeve",
      credits: [
        { file: "clothes/longsleeve/male/shirt.png",
          authors: ["John Smith", "Jane Doe"],
          licenses: ["OGA-BY 3.0", "CC-BY-SA 3.0"], urls: [], notes: "v3 adaptation" },
      ],
    },
  },
};

test("collectCredits dedupes by item+file", () => {
  const def = {
    name: "x",
    layers: [
      { item: "body.body_color" },
      { item: "body.body_color" }, // same item twice
      { item: "clothes.longsleeve" },
    ],
  };
  const credits = collectCredits(def, syntheticIndex);
  assert.equal(credits.length, 2);
});

test("getUniqueAuthors merges per-author items and licenses", () => {
  const def = { name: "x", layers: [{ item: "body.body_color" }, { item: "clothes.longsleeve" }] };
  const authors = getUniqueAuthors(collectCredits(def, syntheticIndex));
  const jane = authors.find(a => a.name === "Jane Doe");
  assert.ok(jane);
  assert.equal(jane.items.length, 2);
  assert.ok(jane.licenses.includes("CC-BY-SA 3.0"));
});

test("getUniqueLicenses returns the union", () => {
  const def = { name: "x", layers: [{ item: "body.body_color" }, { item: "clothes.longsleeve" }] };
  const licenses = getUniqueLicenses(collectCredits(def, syntheticIndex)).sort();
  assert.deepEqual(licenses, ["CC-BY-SA 3.0", "OGA-BY 3.0"]);
});

test("markdown includes license, author, and asset sections", () => {
  const def = { name: "hero", layers: [{ item: "body.body_color" }] };
  const md = formatCreditsMarkdown("hero", collectCredits(def, syntheticIndex));
  assert.ok(md.includes("# Credits: hero"));
  assert.ok(md.includes("## Licenses"));
  assert.ok(md.includes("### Jane Doe"));
  assert.ok(md.includes("universal-light.png"));
});
