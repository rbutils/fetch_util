function disclosureCatalogFragment(value) {
  var absolute = materializedHttpUrl(value);
  if (!absolute) return "";
  try {
    var url = new URL(absolute);
    return datedReferenceDocumentUrl(url.href) === datedReferenceDocumentUrl(location.href) ? safeDecodeFragment(url.hash) : "";
  } catch (_error) { return ""; }
}

function disclosureCatalogChrome(node) {
  if (node.matches("nav, header, footer, menu, [role='navigation'], [role='menubar'], [role='menu']")) return true;
  var signal = normalizeText((node.id || "") + " " + (node.getAttribute("class") || ""));
  return /(?:^|[\s_-])(?:nav|navigation|menu)(?:$|[\s_-])/i.test(signal) &&
    !node.querySelector("p, h1, h2, h3, h4, h5, h6, pre, table, article, main, img, video, audio, iframe, input, textarea, select") &&
    !!node.querySelector("ul ul, ol ol, ul ol, ol ul");
}

function disclosureCatalogOutsideMaterial(root) {
  function outside(node) {
    if (node === root || node.nodeType === 8) return false;
    if (node.nodeType === 3) return !!normalizeText(node.nodeValue || "");
    if (node.nodeType !== 1 || node.matches("script, style, noscript, template") || disclosureCatalogChrome(node)) return false;
    if (node.contains(root)) return Array.from(node.childNodes).some(outside);
    var clone = visibilityPrunedClone(node, document);
    if (!clone) return false;
    clone.querySelectorAll("script, style, noscript, template").forEach(function(inert) { inert.remove(); });
    var material = !!normalizeText(clone.textContent || "") || !!clone.querySelector("a[href], img, pre, table, video, audio, iframe, input, textarea, select");
    clone.replaceChildren();
    return material;
  }
  return Array.from(document.body.childNodes).some(outside);
}

function disclosureCatalogGroups(root) {
  var groups = [];
  Array.from(root.children).forEach(function(anchor) {
    if (anchor.tagName !== "A" || anchor.children.length || normalizeText(anchor.textContent || "") ||
        !(anchor.id || anchor.getAttribute("name"))) return;
    var button = anchor.nextElementSibling;
    var panel = button && button.nextElementSibling;
    if (!button || button.tagName !== "BUTTON" || !panel || !panel.matches("div, section") ||
        !normalizeText(button.textContent || "") || elementVisuallyHidden(button)) return;
    if (button.querySelector("a, input, textarea, select, button, img, video, audio, iframe")) return;
    if (!panel.querySelector("h2, h3, h4, h5, h6") || !panel.querySelector("ul, ol, dl, table")) return;
    var destinations = new Set(Array.from(panel.querySelectorAll("a[href]")).filter(function(link) {
      return !!normalizeText(link.textContent || "");
    }).map(function(link) { return materializedHttpUrl(link.getAttribute("href")); }).filter(Boolean));
    if (destinations.size < 2) return;
    groups.push({ anchor: anchor, button: button, panel: panel, indexed: false });
  });
  var buttons = Array.from(root.children).filter(function(node) { return node.tagName === "BUTTON"; });
  return groups.length > 1 && buttons.length === groups.length ? groups : [];
}

function disclosureCatalogIndexOwned(root, groups) {
  var targets = new Map();
  root.querySelectorAll("[id], a[name]").forEach(function(node) {
    [node.id, node.getAttribute("name")].filter(Boolean).forEach(function(key) {
      if (!targets.has(key)) targets.set(key, node);
      else if (targets.get(key) !== node) targets.set(key, null);
    });
  });
  var owners = new Map();
  groups.forEach(function(group) { owners.set(group.anchor, group); owners.set(group.panel, group); });
  var indexed = new Set();
  root.querySelectorAll("a[href]").forEach(function(link) {
    if (!(link.compareDocumentPosition(groups[0].anchor) & Node.DOCUMENT_POSITION_FOLLOWING)) return;
    var fragment = disclosureCatalogFragment(link.getAttribute("href"));
    if (!fragment || !normalizeText(link.textContent || "") || elementVisuallyHidden(link)) return;
    var target = targets.get(fragment);
    if (!target) return;
    var current = target;
    while (current && current !== root && !owners.has(current)) current = current.parentElement;
    var group = owners.get(current);
    if (!group) return;
    group.indexed = true;
    indexed.add(fragment);
  });
  return indexed.size > 1 && groups.every(function(group) { return group.indexed; });
}

function disclosureCatalogContext() {
  return withSourceVisibilityRead(function() {
    if (!document.body || document.querySelector("article, [role='article'], [itemprop~='articleBody'], script[type='application/ld+json'], [itemscope][itemtype]")) return null;
    var headings = Array.from(document.querySelectorAll("h1"));
    if (headings.length !== 1 || elementVisuallyHidden(headings[0])) return null;
    var heading = headings[0];
    var root = heading.parentElement;
    if (!root || !root.matches("div, section, main, [role='main']") || root === document.body ||
        elementVisuallyHidden(root) || nodeHasShadowContent(root) || root.querySelector("form, input, textarea, select, [role='feed']")) return null;
    var title = normalizeText(heading.textContent || "");
    if (!title || !normalizeText(document.title || "")) return null;
    var current = datedReferenceDocumentUrl(location.href);
    if (!current || Array.from(document.querySelectorAll("meta[property='og:url'], link[rel~='canonical']")).some(function(node) {
      return datedReferenceDocumentUrl(node.getAttribute("content") || node.getAttribute("href")) !== current;
    }) || Array.from(document.querySelectorAll("meta[property='og:type']")).some(function(node) {
      return !/^(?:website|summary)$/i.test(normalizeText(node.content || ""));
    })) return null;
    if (Array.from(document.querySelectorAll("h1, h2, h3, h4, h5, h6")).some(function(node) {
      return !root.contains(node) && !elementVisuallyHidden(node);
    }) || disclosureCatalogOutsideMaterial(root)) return null;
    var groups = disclosureCatalogGroups(root);
    if (!groups.length || !disclosureCatalogIndexOwned(root, groups)) return null;
    return { root: root, title: title };
  });
}
