function sourcehutGitFileHeaders(diffRoot) {
  return Array.prototype.slice.call(diffRoot.querySelectorAll(":scope > pre.mb-0.bg-transparent.p-0")).filter(function(node) {
    return !elementSubtreeHidden(node) && normalizeText((visibilityPrunedClone(node) || {}).textContent || "");
  });
}

function sourcehutGitFileTitle(header, index) {
  var links = Array.prototype.slice.call(header.querySelectorAll("a[href]")).filter(function(link) {
    return !!sourcehutGitSameOriginUrl(link.getAttribute("href"));
  });
  return normalizeText((links[links.length - 1] || {}).textContent || "") || "Changed file " + (index + 1);
}

function sourcehutGitFileRecord(header, index) {
  var markdown = sourcehutGitNodeMarkdown(header);
  var htmlNodes = [visibilityPrunedClone(header)].filter(Boolean);
  var sibling = header.nextElementSibling;
  while (sibling && !sibling.matches("pre.mb-0.bg-transparent.p-0")) {
    if (sibling.matches(".event.diff") && !elementSubtreeHidden(sibling)) {
      var hunkMarkdown = sourcehutGitNodeMarkdown(sibling);
      if (hunkMarkdown) markdown += "\n\n" + hunkMarkdown;
      var clone = visibilityPrunedClone(sibling);
      if (clone) htmlNodes.push(clone);
    }
    sibling = sibling.nextElementSibling;
  }
  return {
    title: sourcehutGitFileTitle(header, index),
    markdown: markdown,
    htmlNodes: htmlNodes
  };
}

function sourcehutGitInventory(route, root, commitId, parents) {
  var entries = [];
  var summaryRow = sourcehutGitSummaryRow(root);
  var diffRoot = sourcehutGitDiffRoot();
  var links = Array.prototype.slice.call(document.querySelectorAll(".resource-nav > a[href]"));
  if (summaryRow) links = links.concat(Array.prototype.slice.call(summaryRow.querySelectorAll("a[href]")));
  if (diffRoot) links = links.concat(Array.prototype.slice.call(diffRoot.querySelectorAll(":scope > pre > a[href]")));
  links.forEach(function(link) {
    if (elementSubtreeHidden(link)) return;
    var url = sourcehutGitSameOriginUrl(link.getAttribute("href"));
    if (!url) return;
    var parsed = new URL(url);
    if (parsed.pathname.indexOf(route.repositoryPath) !== 0) return;
    var label = normalizeText(link.textContent) || "Related repository resource";
    if (parsed.pathname === route.repositoryPath + "/commit/" + commitId + ".patch") {
      label = parents.length > 1 ? "Raw patch (may not represent this merge commit)" : "Raw patch";
    }
    entries.push({ label: label, url: url });
  });
  return browsableInventory("Browse this SourceHut commit", entries);
}

function sourcehutGitMetadataSections(commitId, author, timestamp, parents, refs) {
  var sections = ["- Commit: `" + commitId + "`"];
  if (author) sections.push("- Author: " + author);
  if (timestamp) sections.push("- Authored: " + timestamp);
  if (!parents.length) {
    sections.push("- Diff basis: Empty tree (root commit)");
  } else {
    sections.push("- Diff basis: First parent " + markdownLink(parents[0].label || parents[0].id.slice(0, 8), parents[0].url));
    parents.forEach(function(parent, index) {
      sections.push("- Parent " + (index + 1) + ": " + markdownLink(parent.id, parent.url));
    });
  }
  refs.forEach(function(ref) {
    sections.push("- Ref: " + markdownLink(ref.label, ref.url));
  });
  return sections;
}

function sourcehutGitCommitContent(metadata) {
  var route = sourcehutGitCommitRoute();
  var root = sourcehutGitCommitRoot();
  var diffRoot = sourcehutGitDiffRoot();
  if (!sourcehutGitProductMatch(route, root, diffRoot)) return null;

  var commitId = sourcehutGitCommitId(root);
  var message = (root.querySelector(":scope > pre.commit").textContent || "").trim();
  var title = normalizeText(message.split(/\r?\n/)[0]) || normalizeText(metadata.title) || commitId;
  var author = sourcehutGitCommitAuthor(root, commitId);
  var timestamp = sourcehutGitCommitTimestamp(root);
  var parents = sourcehutGitCommitParents(root, route);
  var refs = sourcehutGitCommitRefs(root);
  var diffstat = sourcehutGitDiffstatNode(diffRoot);
  var large = sourcehutGitLargeDiffNode(diffstat);
  var files = sourcehutGitFileHeaders(diffRoot).map(sourcehutGitFileRecord);
  var sections = ["# " + title].concat(sourcehutGitMetadataSections(commitId, author, timestamp, parents, refs));

  sections.push("## Commit message", fencedCodeBlock("text", message).trim());
  var diffstatText = (diffstat.textContent || "").trim();
  if (diffstatText) sections.push("## Diffstat", fencedCodeBlock("text", diffstatText).trim());
  if (large) {
    sections.push("## Diff detail", "SourceHut did not render file details because this diff exceeds its 10,000 changed-line display boundary.");
    if (parents.length > 1) sections.push("This merge view represents only the first-parent diff; its raw patch may identify another commit.");
  } else if (files.length) {
    sections.push("## Changed files");
    files.forEach(function(file, index) {
      sections.push("### File " + (index + 1) + ": " + file.title, file.markdown);
    });
  } else {
    sections.push("## Changed files", "No file changes were rendered for this commit.");
  }
  sections.push(sourcehutGitInventory(route, root, commitId, parents));

  var markdown = sections.filter(Boolean).join("\n\n");
  var container = root.closest(".container");
  var htmlRoot = container && visibilityPrunedClone(container);
  var result = {
    title: title,
    byline: author || null,
    excerpt: normalizeText(message),
    siteName: "SourceHut git",
    publishedTime: timestamp || null,
    html: htmlRoot ? htmlRoot.innerHTML : "",
    markdown: markdown,
    textContent: normalizeText(markdown),
    hostAware: true,
    readerMode: false,
    contentType: "article"
  };
  if (large) result.warningReasons = ["sourcehut_git_commit_diff_incomplete"];
  return result;
}

function registerSourcehutGitCommitProfiles() {
  registerHostAwareProfile(true, sourcehutGitCommitContent);
}
