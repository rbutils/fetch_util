function gerritDiffHeaderLines(diff) {
  if (Array.isArray(diff.diff_header)) return diff.diff_header.map(String);
  return diff.diff_header ? String(diff.diff_header).split("\n") : [];
}

function gerritDiffSkipLine(skip) {
  if (!skip || typeof skip !== "object") return "@@ " + skip + " unchanged lines omitted @@";
  var counts = [];
  if (skip.left != null) counts.push("base " + skip.left);
  if (skip.right != null) counts.push("target " + skip.right);
  return "@@ " + (counts.length ? counts.join(", ") : JSON.stringify(skip)) + " unchanged lines omitted @@";
}

function gerritDiffTextLines(diff) {
  var lines = gerritDiffHeaderLines(diff);
  (Array.isArray(diff.content) ? diff.content : []).forEach(function(block) {
    if (block.common != null) lines.push("Common block: " + (block.common ? "yes" : "no"));
    if (block.due_to_rebase != null) lines.push("Due to rebase: " + (block.due_to_rebase ? "yes" : "no"));
    if (block.move_details) lines.push("Move details: " + JSON.stringify(block.move_details));
    if (Array.isArray(block.edit_a)) lines.push("Base intraline edits: " + JSON.stringify(block.edit_a));
    if (Array.isArray(block.edit_b)) lines.push("Target intraline edits: " + JSON.stringify(block.edit_b));
    if (block.skip != null) {
      lines.push(gerritDiffSkipLine(block.skip));
      return;
    }
    ["ab", "a", "b"].forEach(function(kind) {
      if (!Array.isArray(block[kind])) return;
      var prefix = kind === "ab" ? " " : (kind === "a" ? "-" : "+");
      block[kind].forEach(function(line) { lines.push(prefix + String(line)); });
    });
  });
  return lines;
}

function gerritDiffFieldLabel(field) {
  return field.split("_").map(function(part) {
    return part.charAt(0).toUpperCase() + part.slice(1);
  }).join(" ");
}

function gerritDiffFieldValue(value) {
  return value && typeof value === "object" ? JSON.stringify(value) : String(value);
}

function gerritDiffObjectSections(prefix, value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return [];
  return Object.keys(value).map(function(field) {
    return "- " + prefix + " " + gerritDiffFieldLabel(field) + ": " + gerritDiffFieldValue(value[field]);
  });
}

function gerritDiffMetadataSections(prepared) {
  var file = prepared.file || {};
  var diff = prepared.diff || {};
  var route = prepared.route;
  var sections = [
    "- Project: " + prepared.detail.project,
    "- Change: " + route.number,
    "- Comparison: " + gerritFileComparisonLabel(route),
    "- File: " + prepared.filePath
  ];
  if (prepared.requestedFilePath !== prepared.filePath) sections.push("- Requested path: " + prepared.requestedFilePath);
  if (file.status) sections.push("- Status: " + file.status);
  if (file.old_path) sections.push("- Previous path: " + file.old_path);
  if (diff.change_type) sections.push("- Change type: " + diff.change_type);
  if (file.lines_inserted != null) sections.push("- Lines inserted: " + file.lines_inserted);
  if (file.lines_deleted != null) sections.push("- Lines deleted: " + file.lines_deleted);
  if (file.size_delta != null) sections.push("- Size delta: " + file.size_delta);
  if (file.size != null) sections.push("- Size: " + file.size);
  if (file.binary || diff.binary) sections.push("- Binary: yes");
  sections = sections.concat(gerritDiffObjectSections("Base", diff.meta_a));
  sections = sections.concat(gerritDiffObjectSections("Target", diff.meta_b));
  Object.keys(diff).forEach(function(field) {
    if (["binary", "change_type", "content", "diff_header", "meta_a", "meta_b"].includes(field)) return;
    if (diff[field] != null) sections.push("- Diff " + gerritDiffFieldLabel(field) + ": " + gerritDiffFieldValue(diff[field]));
  });
  return sections;
}

function gerritFileCommentRecords(prepared) {
  var filePaths = new Set([
    prepared.filePath,
    prepared.requestedFilePath,
    prepared.file && prepared.file.old_path,
    prepared.diff && prepared.diff.meta_a && prepared.diff.meta_a.name,
    prepared.diff && prepared.diff.meta_b && prepared.diff.meta_b.name
  ].filter(Boolean));
  var selected = {};
  Object.keys(prepared.comments || {}).forEach(function(filePath) {
    if (filePaths.has(filePath)) selected[filePath] = prepared.comments[filePath];
  });
  return gerritInlineComments(selected, "Inline comment", 0).sort(function(left, right) {
    var leftTime = Date.parse(left.timestamp);
    var rightTime = Date.parse(right.timestamp);
    if (!isNaN(leftTime) && !isNaN(rightTime) && leftTime !== rightTime) return leftTime - rightTime;
    if (!isNaN(leftTime) && isNaN(rightTime)) return -1;
    if (isNaN(leftTime) && !isNaN(rightTime)) return 1;
    return left.sourceOrder - right.sourceOrder;
  });
}

function gerritDiffMarkdown(prepared, diff) {
  diff = diff || prepared.diff || {};
  var lines = gerritDiffTextLines(diff);
  if (lines.length) return fencedCodeBlock("diff", lines.join("\n")).trim();
  if (prepared.file.binary || diff.binary) return "Binary file; Gerrit returned no textual diff.";
  if (/^DELETED$/i.test(normalizeText(diff.change_type))) {
    return "Deleted file; Gerrit returned no textual diff.";
  }
  return "Gerrit returned no textual diff for this file comparison.";
}
