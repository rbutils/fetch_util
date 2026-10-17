function referenceIndexNarrativeParagraph(paragraph) {
  if (!paragraph || paragraph.tagName !== "P" ||
      paragraph.querySelector("button, input, select, textarea, iframe, form")) return false;
  var walker = paragraph.ownerDocument.createTreeWalker(paragraph, NodeFilter.SHOW_TEXT);
  var prose = "";
  for (var node; (node = walker.nextNode());) {
    if (!node.parentElement.closest("a, button, input, select, textarea, script, style")) prose += node.nodeValue;
  }
  return normalizeText(prose).length >= 40;
}

function referenceIndexCategoryLabel(item) {
  return normalizeText(Array.prototype.filter.call(item.childNodes, function(node) {
    return !(node.nodeType === Node.ELEMENT_NODE && node.matches("ul, ol"));
  }).map(function(node) { return node.textContent || ""; }).join(""));
}

function authoredLocalReferenceIndexReader(root) {
  var targets = null;
  var page = new URL(location.href);

  function targetFor(fragment) {
    if (!targets) {
      targets = new Map();
      root.querySelectorAll("[id], a[name]").forEach(function(node) {
        [node.getAttribute("id"), node.getAttribute("name")].filter(Boolean).forEach(function(key) {
          if (!targets.has(key)) targets.set(key, node);
          else if (targets.get(key) !== node) targets.set(key, null);
        });
      });
    }
    var key = fragment.substring(1);
    try { key = decodeURIComponent(key); } catch (_error) { return null; }
    var target = targets.get(key);
    return target && root.contains(target) ? target : null;
  }

  return function(list) {
    if (!list || !list.matches("ul, ol") || !root.contains(list)) return false;
    var item = list.parentElement;
    var nested = item && item.tagName === "LI" && item.parentElement && item.parentElement.matches("ul, ol");
    if (!nested && !list.querySelector("li > ul, li > ol")) return false;
    if (list.closest("nav, header, footer, aside, menu, [role='navigation'], [role='menu'], [role='menubar'], [role='toolbar'], [role='complementary']")) return false;
    if (list.closest("button, form, dialog, [role='button'], [role='menuitem'], [role='tab'], [role='tablist'], [role='listbox'], [role='dialog']")) return false;
    if (list.querySelector("[role='navigation'], [role='menu'], [role='menubar'], [role='button'], [role='menuitem'], [role='tab'], [role='tablist'], [role='listbox'], [role='dialog']")) return false;
    if (list.querySelector("p, pre, table, h1, h2, h3, h4, h5, h6, button, input, select, textarea, form")) return false;
    if (!Array.prototype.every.call(list.children, function(child) { return child.tagName === "LI"; })) return false;
    if (nested && !referenceIndexCategoryLabel(item)) return false;

    var outer = nested ? item.parentElement : list;
    while (outer.parentElement && outer.parentElement.tagName === "LI" &&
        outer.parentElement.parentElement && outer.parentElement.parentElement.matches("ul, ol")) {
      outer = outer.parentElement.parentElement;
    }
    var introduction = outer.previousElementSibling;
    if (!introduction || introduction.tagName !== "P" || !normalizeText(introduction.textContent) ||
        introduction.querySelector("a, button, input, select, textarea, form")) return false;

    var links = Array.prototype.slice.call(list.querySelectorAll("a[href]"));
    if (!links.length || !Array.prototype.every.call(list.querySelectorAll("li"), function(child) {
      if (Array.prototype.some.call(child.children, function(node) { return node.matches("ul, ol"); })) {
        return !!referenceIndexCategoryLabel(child);
      }
      return child.querySelectorAll("a[href]").length === 1;
    })) return false;
    var headings = new Set();
    for (var index = 0; index < links.length; index += 1) {
      var href = materializedHttpUrl(links[index].getAttribute("href"));
      if (!href || !normalizeText(links[index].textContent)) return false;
      var url = new URL(href);
      if (url.origin !== page.origin || url.pathname !== page.pathname || url.search !== page.search || !url.hash) return false;
      var target = targetFor(url.hash);
      var heading = target && target.closest("h1, h2, h3, h4, h5, h6");
      if (!heading || !root.contains(heading) || elementSubtreeHidden(heading)) continue;
      var paragraph = heading.nextElementSibling;
      if (referenceIndexNarrativeParagraph(paragraph) && !elementSubtreeHidden(paragraph)) headings.add(heading);
    }
    return headings.size >= 2;
  };
}
