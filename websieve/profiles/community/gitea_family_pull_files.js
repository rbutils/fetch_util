function giteaFamilyPullFileId(value) {
  var identity = String(value || "");
  if (!identity) return "";
  return identity.indexOf("diff-") === 0 ? identity : "diff-" + identity;
}

function giteaFamilyPullFileScope(route) {
  var suffix = route.surface === "commits"
    ? "/commits/" + route.surfaceDetail
    : "/files" + (route.surfaceDetail ? "/" + route.surfaceDetail : "");
  return giteaFamilyRouteUrl(route, suffix);
}

function giteaFamilyPullFileUrl(route, identity, file) {
  var canonical = materializedHttpUrl(file && (file.URL || file.Url || file.url));
  if (canonical) {
    try {
      if (new URL(canonical).origin === location.origin) return canonical;
    } catch (_error) {
      // Fall back to the product route.
    }
  }

  var onPage = Number(file && (file.OnPage === undefined ? file.onPage : file.OnPage));
  var query = Number.isInteger(onPage) && onPage > 1 ? "?diff-page=" + onPage : "";
  return giteaFamilyPullFileScope(route) + query + "#" + encodeURIComponent(identity);
}

function giteaFamilyPullFileTreeEntries(route) {
  var runtime = giteaFamilyRuntime();
  var pageData = runtime.pageData || {};
  var forgejoFiles = (((pageData.diffFileInfo || {}).files) || []);
  if (Array.isArray(forgejoFiles) && forgejoFiles.length) {
    return forgejoFiles.map(function(file) {
      var identity = giteaFamilyPullFileId(file.NameHash || file.nameHash);
      var label = normalizeText(file.Name || file.name || "");
      if (!identity || !label) return null;
      return {
        label: label,
        id: identity,
        url: giteaFamilyPullFileUrl(route, identity, file)
      };
    }).filter(Boolean);
  }
  var treeData = pageData.DiffFileTree || pageData.diffFileTree || [];
  var tree = treeData.TreeRoot || treeData.treeRoot || treeData;
  var entries = [];
  var visit = function(nodes) {
    (Array.isArray(nodes) ? nodes : [nodes]).filter(Boolean).forEach(function(node) {
      var children = node.Children || node.children || [];
      if (children.length) {
        visit(children);
        return;
      }
      var identity = giteaFamilyPullFileId(node.NameHash || node.nameHash);
      if (!identity) return;
      var label = normalizeText(node.FullName || node.fullName || node.NewFullName ||
        node.newFullName || node.OldFullName || node.oldFullName || identity);
      entries.push({ label: label, id: identity, url: giteaFamilyPullFileUrl(route, identity, node) });
    });
  };
  visit(tree);
  return entries;
}

function giteaFamilyPullFileBoxes(root) {
  return topLevelQualifiedDescendants(
    root,
    "#diff-file-boxes > .diff-file-box, .diff-file-box.file-content[id^='diff-']",
    function(node) {
      return node.id !== "diff-incomplete" && giteaFamilyPullVisibleMaterial(node);
    }
  );
}

function giteaFamilyPullFileLabel(box, fallback) {
  var header = box && box.querySelector(".diff-file-header, .file-header, .file-link");
  return normalizeText(
    (box && (box.getAttribute("data-new-filename") || box.getAttribute("data-old-filename"))) ||
    (header && (header.getAttribute("data-path") || header.textContent)) || fallback
  );
}

function giteaFamilyPullFileInventoryEntries(route, root, boxes) {
  var entries = giteaFamilyPullFileTreeEntries(route);
  var seen = new Set(entries.map(function(entry) { return entry.id; }).filter(Boolean));
  Array.prototype.slice.call(root.querySelectorAll(
    "#diff-file-tree a.item-file[href^='#diff-'], a.file-link[href^='#diff-']"
  )).forEach(function(link) {
    if (elementVisuallyHidden(link)) return;
    var identity = safeDecodeURI((link.getAttribute("href") || "").replace(/^#/, ""));
    if (!identity || seen.has(identity)) return;
    var url = giteaFamilyPullFileUrl(route, identity, null);
    seen.add(identity);
    entries.push({ label: normalizeText(link.textContent) || identity, id: identity, url: url });
  });
  boxes.forEach(function(box) {
    var identity = box.id;
    if (!identity || seen.has(identity)) return;
    var url = giteaFamilyPullFileUrl(route, identity, null);
    seen.add(identity);
    entries.push({ label: giteaFamilyPullFileLabel(box, identity), id: identity, url: url });
  });
  return entries;
}

function giteaFamilyPullDeferredEntries(root, boxes) {
  var entries = [];
  var seen = new Set();
  Array.prototype.slice.call(root.querySelectorAll(
    "#diff-show-more-files[data-href], .diff-load-button[data-href], " +
    "[data-global-click='diffLoadFileBody'][data-href]"
  )).forEach(function(node) {
    if (elementVisuallyHidden(node)) return;
    var url = materializedHttpUrl(node.getAttribute("data-href"));
    if (!url || seen.has(url)) return;
    try {
      if (new URL(url).origin !== location.origin) return;
    } catch (_error) {
      return;
    }
    seen.add(url);
    var box = node.closest(".diff-file-box");
    var label = box
      ? "Load deferred diff for " + giteaFamilyPullFileLabel(box, box.id)
      : "Load more changed files";
    entries.push({ label: label, url: url, fileId: box ? box.id : null });
  });
  return entries;
}

function giteaFamilyPullFileClone(box) {
  var clone = visibilityPrunedClone(box);
  removeAll(clone, [
    "button",
    "form",
    "input",
    "label",
    "[role='tooltip']",
    ".diff-file-actions",
    ".diff-file-header-actions",
    ".diff-file-options",
    ".diff-load-button",
    ".menu",
    ".dropdown"
  ].join(", "));
  return clone;
}

function giteaFamilyPullFileBodyMaterial(box) {
  var body = box.querySelector(".diff-file-body, .file-body, .diff-rendered, .image-diff, .binary");
  if (!body || elementSubtreeHidden(body)) return false;

  var deferred = Array.prototype.slice.call(box.querySelectorAll(
    ".diff-load-button[data-href], [data-global-click='diffLoadFileBody'][data-href]"
  )).some(function(node) { return !elementVisuallyHidden(node); });
  var clone = visibilityPrunedClone(body);
  removeAll(clone, "button, [role='button'], .diff-load-button, [data-global-click='diffLoadFileBody']");
  var structured = !!clone.querySelector("table, pre, code, img, ins, del, .diff-line");
  return structured || (!deferred && !!normalizeText(clone.textContent));
}

function giteaFamilyPullFilesContent(metadata, route, root) {
  var boxes = giteaFamilyPullFileBoxes(root);
  var files = giteaFamilyPullFileInventoryEntries(route, root, boxes);
  var deferred = giteaFamilyPullDeferredEntries(root, boxes);
  var selectedId = safeDecodeFragment(location.hash);
  var selected = selectedId ? boxes.find(function(box) { return box.id === selectedId; }) : null;
  var indexed = selectedId && files.some(function(entry) { return entry.id === selectedId; });
  var empty = giteaFamilyPullEmptyMarkdown(root);
  if (!files.length && !deferred.length && !empty) return null;

  var title = giteaFamilyPullResourceTitle(metadata, "Files changed");
  var sections = ["# " + title];
  var htmlNodes = [];
  if (selected) {
    var clone = giteaFamilyPullFileClone(selected);
    var markdown = giteaFamilyPullFileBodyMaterial(selected)
      ? cleanupMarkdownNoise(markdownFor(clone.innerHTML))
      : "";
    var selectedDeferred = deferred.filter(function(entry) { return entry.fileId === selectedId; });
    sections.push("## " + giteaFamilyPullFileLabel(selected, selected.id));
    if (markdown) sections.push(markdown);
    if (!markdown && selectedDeferred.length) {
      sections.push("Selected file body is deferred on this page.");
    } else if (!markdown) {
      sections.push("Selected file body is not loaded on this page.");
    }
    htmlNodes.push(clone);
  } else if (selectedId) {
    sections.push(indexed
      ? "Selected file is indexed but is not loaded on this page."
      : "Selected file is not present in the loaded file inventory.");
  } else if (empty) {
    sections.push(empty);
  } else {
    sections.push("- Changed files indexed: " + files.length);
    htmlNodes = boxes.map(function(box) {
      var header = box.querySelector(".diff-file-header, .file-header");
      return visibilityPrunedClone(header || box);
    });
  }

  var inventory = files.concat(deferred, giteaFamilyPullCoreInventoryEntries(route));
  sections.push(browsableInventory("Browse changed files", inventory));
  return giteaFamilyPullResourceResult(title, sections, htmlNodes, route);
}
