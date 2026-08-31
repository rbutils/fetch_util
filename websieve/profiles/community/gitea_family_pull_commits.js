function giteaFamilyPullCommitClone(row) {
  var clone = visibilityPrunedClone(row);
  var body = row.querySelector(".commit-body");
  if (body && !clone.querySelector(".commit-body") && normalizeText(body.textContent)) {
    var bodyClone = body.cloneNode(true);
    bodyClone.classList.remove("tw-hidden", "hidden");
    bodyClone.removeAttribute("hidden");
    bodyClone.removeAttribute("style");
    clone.appendChild(bodyClone);
  }
  removeAll(clone, "button, form, [role='tooltip'], .copy-commit-id, .menu, .dropdown");
  return clone;
}

function giteaFamilyPullCommitRecords(root) {
  var nodes = Array.prototype.slice.call(root.querySelectorAll(
    "#commits-table > tbody.commit-list > tr, .commit-group .commits .commit"
  ));
  return nodes.filter(function(row, index) {
    if (!giteaFamilyPullVisibleMaterial(row)) return false;
    return !nodes.some(function(other, otherIndex) {
      return otherIndex < index && other.contains(row);
    });
  }).map(function(row) {
    var clone = giteaFamilyPullCommitClone(row);
    return { node: clone, markdown: cleanupMarkdownNoise(markdownFor(clone.innerHTML)) };
  }).filter(function(record) {
    return !!normalizeText(record.markdown);
  });
}

function giteaFamilyPullCommitsContent(metadata, route, root) {
  var records = giteaFamilyPullCommitRecords(root);
  var empty = giteaFamilyPullEmptyMarkdown(root);
  if (!records.length && !empty) return null;

  var title = giteaFamilyPullResourceTitle(metadata, "Commits");
  var sections = ["# " + title];
  if (records.length) {
    sections.push("- Commits shown: " + records.length, "## Commits");
    records.forEach(function(record, index) {
      sections.push("### Commit " + (index + 1), record.markdown);
    });
  } else {
    sections.push(empty);
  }
  sections.push(browsableInventory(
    "Browse this " + giteaFamilyPlatform() + " pull request",
    giteaFamilyPullCoreInventoryEntries(route)
  ));
  return giteaFamilyPullResourceResult(title, sections, records.map(function(record) {
    return record.node;
  }), route);
}
