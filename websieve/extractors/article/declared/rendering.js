function declaredArticleHttpUrl(value) {
  try {
    var url = new URL(value || "", document.baseURI || location.href);
    return value && /^https?:$/.test(url.protocol) ? url.href : "";
  } catch (_error) {
    return "";
  }
}

function declaredArticleReferenceRoot(context) {
  var root = visibilityPrunedClone(context.root);
  var references = new Map();
  var prefix = "fetch-util-declared-reference";
  while ((root.textContent || "").indexOf(prefix) !== -1 ||
      Array.from(root.querySelectorAll("[data-fetchutil-declared-reference]")).some(function(node) {
        return (node.getAttribute("data-fetchutil-declared-reference") || "").indexOf(prefix) === 0;
      })) prefix += "-";
  root.querySelectorAll("a[href]").forEach(function(anchor) {
    var label = normalizeText(anchor.textContent || "");
    var url = declaredArticleHttpUrl(anchor.getAttribute("href"));
    if (!label || !url || anchor.closest("form, button, nav, aside, footer, [role='button'], [role='menu'], [role='dialog']") ||
        anchor.querySelector("script, style, template, iframe, button, input, textarea, select")) return;
    var paragraph = anchor.closest("p");
    var declaredParagraph = paragraph && context.paragraphs.some(function(node) {
      return normalizeText(node.textContent || "") === normalizeText(paragraph.textContent || "");
    });
    if (!declaredParagraph && (UI_ACTION_TEXT_PATTERN.test(label) || ACCOUNT_ACTION_TEXT_PATTERN.test(label)) &&
        !authoredInlineActionReference(anchor)) return;
    anchor.setAttribute("href", url);
    var owner = anchor.parentElement;
    if (anchor.querySelector("p") && owner && owner.querySelectorAll("a[href]").length === 1 &&
        !owner.querySelector("button, input, form, textarea, select")) {
      owner.setAttribute("data-fetchutil-source-owned-primary", "true");
    }
    var slot = root.ownerDocument.createElement("span");
    var key = prefix + "-" + references.size;
    slot.setAttribute("data-fetchutil-declared-reference", key);
    slot.textContent = key;
    // Retain the paragraph structure used by the bounded primary-owner guard.
    if (anchor.querySelector("p")) {
      var holder = root.ownerDocument.createElement("p");
      holder.textContent = key;
      slot.replaceChildren(holder);
    }
    references.set(key, anchor.outerHTML);
    anchor.replaceWith(slot);
  });
  return { root: root, references: references };
}

function restoreDeclaredArticleReferences(root, references) {
  root.querySelectorAll("[data-fetchutil-declared-reference]").forEach(function(slot) {
    var value = references.get(slot.getAttribute("data-fetchutil-declared-reference"));
    if (!value) return;
    var fragment = root.ownerDocument.createElement("div");
    fragment.innerHTML = value;
    slot.replaceWith.apply(slot, Array.from(fragment.childNodes));
  });
}

function materializeDeclaredArticleMedia(root) {
  root.querySelectorAll("video, audio, img").forEach(function(media) {
    var values = media.matches("img") ? (!normalizeText(media.getAttribute("alt") || "") ? [media.getAttribute("src")] : []) :
      [media.getAttribute("src")].concat(Array.from(media.querySelectorAll("source[src]")).map(function(source) { return source.getAttribute("src"); }));
    var seen = new Set();
    var owner = media.closest("a, picture") || media;
    values.forEach(function(value) {
      var url = declaredArticleHttpUrl(value);
      if (!url || seen.has(url)) return;
      seen.add(url);
      var paragraph = root.ownerDocument.createElement("p");
      var link = root.ownerDocument.createElement("a");
      link.setAttribute("href", url);
      link.textContent = media.matches("img") ? "Image source" : (media.matches("video") ? "Video source" : "Audio source");
      paragraph.appendChild(link);
      owner.after(paragraph);
      owner = paragraph;
    });
  });
}
