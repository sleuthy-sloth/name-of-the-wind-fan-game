// report.mjs — Generate build reports for sprite factory runs

import fs from "fs";
import path from "path";

// Generate a build report
export function generateReport(options) {
  const {
    characterName,
    bodyType,
    animations,
    itemCount,
    totalImages,
    outputFiles,
    creditsCount,
    authorCount,
    licenseCount,
    duration,
    success,
    errors,
    warnings,
  } = options;

  const report = {
    timestamp: new Date().toISOString(),
    character: characterName,
    bodyType,
    success,
    summary: {
      animationsBuilt: animations.length,
      animations: animations,
      itemsUsed: itemCount,
      totalImagesComposed: totalImages,
      outputFiles: outputFiles,
      creditsEntries: creditsCount,
      uniqueAuthors: authorCount,
      uniqueLicenses: licenseCount,
      durationMs: duration,
    },
    errors: errors || [],
    warnings: warnings || [],
  };

  return report;
}

// Write report to JSON file
export function writeReport(outputPath, report) {
  fs.writeFileSync(outputPath, JSON.stringify(report, null, 2), "utf8");
  return outputPath;
}

// Format a brief console summary
export function formatConsoleSummary(report) {
  const status = report.success ? "PASS" : "FAIL";
  const lines = [
    `${report.character}: ${status}`,
    `  Body: ${report.bodyType}`,
    `  Animations: ${report.summary.animationsBuilt} (${report.summary.animations.join(", ")})`,
    `  Items: ${report.summary.itemsUsed}`,
    `  Images composed: ${report.summary.totalImagesComposed}`,
    `  Output files: ${report.summary.outputFiles.length}`,
    `  Credits: ${report.summary.creditsEntries} entries, ${report.summary.uniqueAuthors} authors`,
    `  Duration: ${(report.summary.durationMs / 1000).toFixed(1)}s`,
  ];
  if (report.errors.length > 0) {
    lines.push(`  Errors: ${report.errors.length}`);
    report.errors.forEach(e => lines.push(`    - ${e}`));
  }
  if (report.warnings.length > 0) {
    lines.push(`  Warnings: ${report.warnings.length}`);
    report.warnings.slice(0, 5).forEach(w => lines.push(`    - ${w}`));
  }
  return lines.join("\n");
}
