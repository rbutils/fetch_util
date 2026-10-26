function linkedButtonInsideClosedBody(button) {
  var disclosure = button.closest("details:not([open])");
  while (disclosure) {
    var summary = Array.prototype.find.call(disclosure.children, function(child) {
      return child.tagName === "SUMMARY";
    });
    if (!summary || !summary.contains(button)) return true;
    disclosure = disclosure.parentElement && disclosure.parentElement.closest("details:not([open])");
  }
  return false;
}

function linkedResourceButtonText(button) {
  var label = button.cloneNode(true);
  label.querySelectorAll("svg, math, img, picture, video, audio, canvas, object, embed, script, style, noscript, template").forEach(function(node) {
    node.remove();
  });
  return normalizeText(label.textContent);
}

function linkedResourceButtonOwner(button, root) {
  if (button.closest("pre, code, kbd, samp, textarea, [inert]")) return null;
  if (linkedButtonInsideClosedBody(button) || elementVisuallyHiddenWithin(button, root)) return null;
  if (button.closest("nav, aside, dialog, [role~='navigation' i], [role~='menu' i], [role~='menubar' i], " +
      "[role~='toolbar' i], [role~='dialog' i], [role~='tablist' i]")) return null;
  if (/^(submit|reset)$/i.test(button.getAttribute("type") || "")) return null;
  if (button.matches("[form], [formaction], [formenctype], [formmethod], [formnovalidate], [formtarget], " +
      "[aria-controls], [aria-expanded], [aria-haspopup], [aria-pressed], [role~='tab' i], " +
      "[role~='menuitem' i], [role~='switch' i], [role~='checkbox' i], [role~='radio' i]")) return null;
  if (button.querySelector("a[href], button, input, select, textarea, [contenteditable='true']")) return null;

  var form = button.closest("form");
  var content = button.closest("article, main, [itemprop~='articleBody' i]");
  if (form && (!content || content.contains(form))) return null;

  var owner = button.closest("a[href]");
  if (!owner || owner.matches("[aria-controls], [aria-expanded], [aria-haspopup], [aria-pressed]")) return null;
  var href = (owner.getAttribute("href") || "").trim();
  if (!href || href === "#" || !materializedHttpUrl(href)) return null;
  if (!linkedResourceButtonText(button)) return null;
  return owner;
}

function preserveLinkedResourceButtons(root) {
  root.querySelectorAll("button").forEach(function(button) {
    if (!linkedResourceButtonOwner(button, root)) return;
    var replacement = button.ownerDocument.createElement("span");
    Array.from(button.attributes).forEach(function(attribute) {
      if (/^on/i.test(attribute.name) || /^(type|form\w*|role|tabindex|disabled|autofocus)$/i.test(attribute.name)) return;
      replacement.setAttribute(attribute.name, attribute.value);
    });
    while (button.firstChild) replacement.appendChild(button.firstChild);
    button.replaceWith(replacement);
  });
}
