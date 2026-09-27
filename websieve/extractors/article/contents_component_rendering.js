function contentsComponentMetadataMarkdown(ownership) {
  var list = visibilityPrunedClone(ownership.metadataList, document);
  if (!list) return "";
  var lines = [];
  Array.prototype.forEach.call(list.querySelectorAll("dt"), function(term) {
    if (term.closest("dl") !== list) return;
    var values = [];
    var sibling = term.nextElementSibling;
    while (sibling && sibling.tagName === "DD" && sibling.closest("dl") === list) {
      var value = cleanupMarkdownNoise(markdownFor(sibling.innerHTML || ""));
      if (normalizeText(value)) values.push(normalizeText(value));
      sibling = sibling.nextElementSibling;
    }
    var label = normalizeText(visibleMetadataNodeText(term)).replace(/\s*:\s*$/, "");
    if (label && values.length) lines.push(label + ": " + values.join("; "));
  });
  return lines.join("\n\n");
}

function contentsComponentNavigationMarkdown(ownership) {
  var marker = ownership.nav.querySelector("ol") ? "1." : "-";
  var lines = ownership.entries.map(function(entry) {
    var label = entry.label.replace(/\\/g, "\\\\").replace(/([\[\]])/g, "\\$1");
    return marker + " [" + label + "](" + entry.href + ")";
  });
  return "## " + ownership.navTitle + "\n\n" + lines.join("\n");
}

function contentsComponentCommentClone(thread) {
  var clone = visibilityPrunedClone(thread, document);
  if (clone && clone.setAttribute) clone.setAttribute("data-fetchutil-social-comment", "true");
  return clone;
}

function contentsComponentUpdateHistoryClone(ownership) {
  var history = ownership && ownership.updateHistory;
  if (!history || !history.node) return null;
  if (history.controlledHidden) return safeDeepClone(history.node, document);
  return visibilityPrunedClone(history.node, document);
}

function sourceOwnedContentsComponentHtml(html, ownership) {
  if (!ownership) return html;
  var root = document.createElement("div");
  root.innerHTML = html || "";
  var heading = visibilityPrunedClone(ownership.headlineNode, document);
  var lead = visibilityPrunedClone(ownership.leadNode, document);
  var metadata = visibilityPrunedClone(ownership.metadataList, document);
  var nav = visibilityPrunedClone(ownership.nav, document);
  var nodes = [heading, lead, metadata, nav].filter(Boolean);
  nodes.reverse().forEach(function(node) { root.insertBefore(node, root.firstChild); });
  if (ownership.updateHistory && ownership.updateHistory.node &&
      !ownership.bodyBranch.contains(ownership.updateHistory.node)) {
    var history = contentsComponentUpdateHistoryClone(ownership);
    root.appendChild(history);
  }
  ownership.commentThreads.forEach(function(thread) {
    var comments = contentsComponentCommentClone(thread);
    if (comments) root.appendChild(comments);
  });
  return root.innerHTML;
}

function sourceOwnedContentsComponentMarkdown(markdown, ownership) {
  if (!ownership) return markdown;
  var lines = String(markdown || "").split("\n");
  var titleIndex = lines.findIndex(function(line) {
    return /^#\s+/.test(line) && normalizeText(line.replace(/^#\s+/, "")) === ownership.headline;
  });
  var titleLine = titleIndex >= 0 ? lines[titleIndex] : "# " + ownership.headline;
  var before = titleIndex >= 0 ? lines.slice(0, titleIndex).join("\n").trim() : "";
  var after = titleIndex >= 0 ? lines.slice(titleIndex + 1).join("\n").trim() : lines.join("\n").trim();
  var leadRoot = visibilityPrunedClone(ownership.leadNode, document);
  var lead = leadRoot ? cleanupMarkdownNoise(markdownFor(leadRoot.outerHTML)) : "";
  var metadata = contentsComponentMetadataMarkdown(ownership);
  var navigation = contentsComponentNavigationMarkdown(ownership);
  var historyNode = ownership.updateHistory && ownership.updateHistory.node &&
      !ownership.bodyBranch.contains(ownership.updateHistory.node) ? contentsComponentUpdateHistoryClone(ownership) : null;
  var updateHistory = historyNode ? cleanupMarkdownNoise(markdownFor(historyNode.outerHTML)) : "";
  var comments = ownership.commentThreads.map(function(thread) {
    var clone = contentsComponentCommentClone(thread);
    return clone ? cleanupMarkdownNoise(markdownFor(clone.outerHTML)) : "";
  });
  return [before, titleLine, lead, metadata, navigation, after, updateHistory].concat(comments).filter(function(part) {
    return normalizeText(part);
  }).join("\n\n");
}
