function gitlabDiffFileId(file) {
  return file.id ||
    file.getAttribute("data-diff-id") ||
    file.getAttribute("data-file-id") ||
    file.getAttribute("data-file-path") || "";
}

function gitlabDiffFileIds(files) {
  var reserved = new Set(files.map(gitlabDiffFileId).filter(Boolean));
  var assigned = new Set();
  return files.map(function(file, index) {
    var explicit = gitlabDiffFileId(file);
    if (explicit && !assigned.has(explicit)) {
      assigned.add(explicit);
      return explicit;
    }
    var identity = explicit
      ? explicit + "-fetch-util-" + (index + 1)
      : "fetch-util-diff-" + (index + 1);
    while (reserved.has(identity) || assigned.has(identity)) identity += "-";
    assigned.add(identity);
    return identity;
  });
}

function gitlabDiffFileVisible(file) {
  if (elementSubtreeHidden(file)) return false;
  if (!elementVisuallyHidden(file)) return true;
  return !!normalizeText(visibilityPrunedClone(file).textContent);
}

function gitlabDiffFileNodes(root) {
  var selector = "diff-file[data-testid='rd-diff-file'], .diff-file, .file-holder, [data-testid='diff-file']";
  return topLevelQualifiedDescendants(root, selector, gitlabDiffFileVisible);
}

function gitlabDiffFilePath(file, index, fileIds) {
  var header = file.querySelector("[data-path], .file-title-name, [data-testid='file-title'], .file-header");
  return normalizeText(
    file.getAttribute("data-path") ||
    file.getAttribute("data-file-path") ||
    (header && (header.getAttribute("data-path") || header.textContent)) ||
    fileIds[index] || ("Changed file " + (index + 1))
  );
}

function gitlabDiffInventoryEntries(route, files, fileIds) {
  var entries = files.map(function(file, index) {
    return {
      label: gitlabDiffFilePath(file, index, fileIds),
      url: gitlabRouteUrl(route, "/diffs") + "#" + encodeURIComponent(fileIds[index])
    };
  });
  var seen = new Set(entries.map(function(entry) { return entry.url; }));
  files.forEach(function(file, index) {
    Array.prototype.slice.call(file.querySelectorAll(
      "include-fragment[src], [data-diff-url], [data-endpoint], [data-url*='diffs_batch'], [data-src*='diff']"
    )).forEach(function(node) {
      var value = node.getAttribute("src") || node.getAttribute("data-diff-url") ||
        node.getAttribute("data-endpoint") || node.getAttribute("data-url") || node.getAttribute("data-src");
      var url = materializedHttpUrl(value);
      if (!url || seen.has(url)) return;
      try {
        if (new URL(url).origin !== location.origin) return;
      } catch (_error) {
        return;
      }
      seen.add(url);
      entries.push({ label: "Load deferred diff for " + gitlabDiffFilePath(file, index, fileIds), url: url });
    });
  });
  return entries;
}

function gitlabDiffFileMarkdown(file) {
  var clone = visibilityPrunedClone(file);
  removeAll(clone, "button, [role='tooltip']");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function gitlabDiffFileBodyLoaded(file) {
  var selector = [
    "[data-testid='rd-diff-file-body']",
    "[data-testid='diff-file-body']",
    ".diff-content",
    ".file-content",
    ".diff-table",
    "table.diff-table",
    ".diff-line",
    ".line_content"
  ].join(", ");
  return Array.prototype.slice.call(file.querySelectorAll(selector)).some(function(body) {
    return normalizeText(visibilityPrunedClone(body).textContent);
  });
}

function gitlabDiffResourceContent(metadata, route, root) {
  var files = gitlabDiffFileNodes(root);
  var fileIds = gitlabDiffFileIds(files);
  var rawSelectedId = (location.hash || "").replace(/^#/, "");
  var selectedId = safeDecodeURI(rawSelectedId);
  if (rawSelectedId.indexOf("%") >= 0 && selectedId === rawSelectedId) selectedId = "";
  var selectedIndex = selectedId
    ? fileIds.indexOf(selectedId)
    : -1;
  var selected = selectedIndex >= 0 ? files[selectedIndex] : null;
  var empty = gitlabResourceEmptyMarkdown(root);
  if (selectedId && !selected && !empty) return null;

  var title = gitlabResourceTitle(metadata, "Changes");
  var sections = ["# " + title];
  var htmlNodes = [];
  if (selected) {
    var fileMarkdown = gitlabDiffFileMarkdown(selected);
    sections.push("## " + gitlabDiffFilePath(selected, selectedIndex, fileIds));
    if (fileMarkdown) sections.push(fileMarkdown);
    if (!gitlabDiffFileBodyLoaded(selected)) {
      sections.push("- Selected diff body is not loaded on this page; use the deferred diff resource below.");
    }
    htmlNodes.push(visibilityPrunedClone(selected));
  } else if (empty) {
    sections.push(empty);
  } else {
    sections.push("- Changed files shown: " + files.length);
  }

  var inventoryEntries = gitlabDiffInventoryEntries(route, files, fileIds).concat(gitlabCoreInventoryEntries(route));
  sections.push(browsableInventory("Browse changed files", inventoryEntries));
  if (!selected) {
    htmlNodes = files.map(function(file) {
      var header = file.querySelector(".file-header, [data-testid='rd-diff-file-header'], [data-testid='file-header']");
      return visibilityPrunedClone(header || file);
    });
  }
  return gitlabResourceResult(title, sections, htmlNodes);
}
