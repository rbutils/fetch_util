function pruneClosedMarkdownDisclosures(root) {
  root.querySelectorAll("details:not([open])").forEach(function(disclosure) {
    if (disclosure.closest("pre, code")) return;
    var summary = Array.prototype.find.call(disclosure.children, function(child) { return child.tagName === "SUMMARY"; });
    Array.prototype.slice.call(disclosure.childNodes).forEach(function(child) {
      if (child !== summary) child.remove();
    });
  });
}
