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

function linkedButtonResourceInlineChildren(owner, button) {
  return Array.from(owner.querySelectorAll("*")).every(function(node) {
    if (node === button) return true;
    if (node.namespaceURI && node.namespaceURI !== "http://www.w3.org/1999/xhtml") return false;
    if (!/^(span|strong|b|em|i|code|br|img)$/i.test(node.localName)) return false;
    if (elementSubtreeHidden(node) || node.matches("[role], [tabindex], [contenteditable], " +
        "[aria-controls], [aria-expanded], [aria-haspopup], [aria-pressed]")) return false;
    if (Array.from(node.attributes).some(function(attribute) { return /^on/i.test(attribute.name); })) return false;
    return node.localName !== "img" || !!materializedHttpUrl(node.getAttribute("src") || "");
  });
}

function linkedButtonResourceSourceBlock(button, owner, root, sourceClones, sourcesByClone) {
  var sourceButton = sourcesByClone.get(button);
  if (!sourceButton || !sourceButton.closest("main, article, [itemprop~='articleBody' i]")) return null;
  var sourceOwner = linkedResourceButtonOwner(sourceButton, sourceButton.ownerDocument);
  if (!sourceOwner || sourceClones.get(sourceOwner) !== owner) return null;
  if (!linkedButtonResourceInlineChildren(sourceOwner, sourceButton)) return null;
  if (normalizeText(sourceOwner.textContent) !== normalizeText(owner.textContent)) return null;
  var sourceParent = sourceOwner.parentElement;
  var parent = owner.parentElement;
  if (!sourceParent || sourceParent.localName !== "div" || !parent || parent.localName !== "div" ||
      sourceClones.get(sourceParent) !== parent || !root.contains(parent)) return null;
  if (sourceParent.children.length !== 1 || sourceParent.children[0] !== sourceOwner ||
      parent.children.length !== 1 || parent.children[0] !== owner) return null;
  if ([sourceParent, parent].some(function(node) {
    return Array.from(node.childNodes).some(function(child) {
      return child.nodeType === Node.TEXT_NODE && !!normalizeText(child.textContent);
    });
  })) return null;
  if (sourceParent.closest("[onclick], [onmousedown], [onpointerdown], [onkeydown], [tabindex], [contenteditable]")) return null;
  return parent;
}

function preserveLinkedResourceButtons(root, sourceClones) {
  var sourcesByClone = sourceClones && new Map();
  var resourceBlocks = sourceClones && new WeakSet();
  if (sourcesByClone) {
    sourceClones.forEach(function(clone, source) { sourcesByClone.set(clone, source); });
  }
  root.querySelectorAll("button").forEach(function(button) {
    var owner = linkedResourceButtonOwner(button, root);
    if (!owner) return;
    var resourceBlock = sourcesByClone && linkedButtonResourceSourceBlock(button, owner, root, sourceClones, sourcesByClone);
    var replacement = button.ownerDocument.createElement("span");
    Array.from(button.attributes).forEach(function(attribute) {
      if (/^on/i.test(attribute.name) || /^(type|form\w*|role|tabindex|disabled|autofocus)$/i.test(attribute.name)) return;
      replacement.setAttribute(attribute.name, attribute.value);
    });
    while (button.firstChild) replacement.appendChild(button.firstChild);
    button.replaceWith(replacement);
    if (sourcesByClone && sourcesByClone.has(button)) sourceClones.set(sourcesByClone.get(button), replacement);
    if (resourceBlock) resourceBlocks.add(resourceBlock);
  });
  return resourceBlocks;
}
