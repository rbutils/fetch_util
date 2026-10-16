function softwareLandingControls(root) {
  root.querySelectorAll("input, select, textarea").forEach(function(control) {
    if (control.closest("pre, code, kbd, samp")) return;
    if (control.matches("textarea[readonly]")) {
      var program = control.ownerDocument.createElement("pre");
      if (control.id) program.id = control.id;
      program.textContent = control.value || control.textContent || "";
      control.replaceWith(program);
    } else control.remove();
  });
  root.querySelectorAll("button").forEach(function(button) {
    var label = button.ownerDocument.createElement("span");
    ["id", "class", "title", "aria-label", "aria-labelledby", "lang", "dir"].forEach(function(name) {
      if (button.hasAttribute(name)) label.setAttribute(name, button.getAttribute(name));
    });
    while (button.firstChild) label.appendChild(button.firstChild);
    button.replaceWith(label);
  });
  Array.from(root.querySelectorAll("form")).reverse().forEach(function(form) {
    form.replaceWith.apply(form, Array.from(form.childNodes));
  });
}

function softwareLandingContent(metadata) {
  var context = sourceOwnedSoftwareLandingContext(metadata);
  if (!context) return null;
  return withInertDomWork(function() {
    var clone = visibilityPrunedClone(context.root, document);
    if (!clone) return null;
    var holder = document.createElement("div");
    holder.appendChild(clone);
    try {
      removeAll(holder, "script, style, noscript, template");
      softwareLandingControls(holder);
      materializeHttpAttributes(holder, false, false);
      var html = holder.innerHTML;
      var markdown = markdownFromDisposableRoot(holder, false, true, true, turndownBlockUnits).trim();
      return {
        title: context.title,
        excerpt: metadata.declaredDescription || metadata.excerpt || "",
        byline: null, publishedTime: null, price: null,
        html: html, markdown: markdown, textContent: normalizeText(markdown),
        docsLike: false, readerMode: false, contentType: "product",
        sourceOwnedSoftwareLanding: true
      };
    } finally { holder.replaceChildren(); }
  })();
}
