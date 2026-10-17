function authoredDocsControlFragmentLink(link, sourceIds) {
  var label = link.closest("label[for]");
  var href = link.getAttribute("href");
  if (!label || !samePageFragmentLink(href) || !normalizeText(link.textContent)) return false;
  var targetId;
  try { targetId = decodeURIComponent(href.slice(href.indexOf("#") + 1)); } catch (_error) { return false; }
  if (targetId !== label.htmlFor || sourceIds.get(targetId) !== 1) return false;
  var input = document.getElementById(targetId);
  return !!(input && input.matches("input[type='radio'], input[type='checkbox']") &&
    Array.prototype.some.call(input.labels || [], function(sourceLabel) {
      return normalizeText(sourceLabel.textContent) === normalizeText(label.textContent);
    }));
}

function preserveDocsControlLabelReferences(root, sourceIds) {
  var references = { links: new WeakSet(), labels: new Set() };
  root.querySelectorAll("label[for] a[href]").forEach(function(link) {
    if (!authoredDocsControlFragmentLink(link, sourceIds)) return;
    references.links.add(link);
    references.labels.add(link.closest("label[for]"));
  });
  references.labels.forEach(function(label) {
    var previous = label.previousSibling;
    var next = label.nextSibling;
    if (previous && previous.nodeType === 1 && previous.tagName === "LABEL") {
      label.before(document.createTextNode(" "));
    }
    if (next && next.nodeType === 1 && next.tagName === "LABEL") {
      label.after(document.createTextNode(" "));
    }
  });
  return references;
}

function containsDocsControlLabel(node, references) {
  if (!references.labels.size) return false;
  return Array.from(references.labels).some(function(label) { return node.contains(label); });
}
