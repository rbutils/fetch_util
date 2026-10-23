function pruneClosedContentDisclosures(root) {
  root.querySelectorAll("details:not([open])").forEach(function(disclosure) {
    if (disclosure.closest("pre, code")) return;
    var summary = Array.prototype.find.call(disclosure.children, function(child) { return child.tagName === "SUMMARY"; });
    Array.prototype.slice.call(disclosure.childNodes).forEach(function(child) {
      if (child !== summary) child.remove();
    });
  });
}

function plainTextWithoutClosedDisclosures(html, text) {
  if (typeof html !== "string" || typeof text !== "string" || !/<details\b/i.test(html)) return text;
  var template = document.createElement("template");
  template.innerHTML = html;
  if (!template.content.querySelector("details:not([open])")) return text;
  var original = template.content.textContent || "";
  var rawText = text === original;
  if (!rawText && text !== normalizeText(original)) return text;
  pruneClosedContentDisclosures(template.content);
  var projected = template.content.textContent || "";
  return rawText ? projected : normalizeText(projected);
}
