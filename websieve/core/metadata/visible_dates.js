function visiblePublishedTimeRoots() {
  var path = location.pathname || "/";
  if (path !== "/" && !/^\/index\.(?:html?|php|aspx?)$/i.test(path)) return visibleMetadataRoots();

  var roots = [];
  document.querySelectorAll("[itemprop='articleBody'], article[role='main']").forEach(function(node) {
    var root = node.closest("article, [role='main'], main") || node;
    if (roots.indexOf(root) === -1 && textLength(root) >= 80) roots.push(root);
  });
  return roots;
}

function visiblePublishedTimeField(node) {
  var contentSelector = "article, main, [role='main'], [itemprop='articleBody'], .entry-content, .post-content";
  if (node.matches(contentSelector)) return false;
  return !node.querySelector(contentSelector + ", h1, h2, h3, h4, h5, h6, figure, blockquote, pre, table");
}

function visiblePublicationDateLike(value) {
  var text = normalizeText(value || "");
  if (!text || text.length > 120) return false;

  var digit = "[0-9\\u0660-\\u0669\\u06f0-\\u06f9]";
  var number = digit + "+";
  var monthName = "\\p{L}[\\p{L}\\p{M}.'’\\-]*";
  if (new RegExp(number + "年\\s*" + number + "月\\s*" + number + "日?", "u").test(text)) return true;
  if (new RegExp(number + "[./-]" + number + "(?:[./-]" + number + ")?").test(text)) return true;
  if (new RegExp("(?:^|\\s)" + number + "\\s+" + monthName + "(?:\\s*[,،]?\\s*" + digit + "{2,4})?(?:\\s|$)", "u").test(text)) return true;
  if (new RegExp("(?:^|\\s)" + monthName + "\\s+" + number + "(?:st|nd|rd|th)?(?:\\s*[,،]?\\s*" + digit + "{2,4})?(?:\\s|$)", "iu").test(text)) return true;
  if (/(?:\b(?:today|yesterday|tomorrow|now|just now|ago|hace|há|seit|vor|il y a)\b|\b\d+\s*(?:seconds?|minutes?|hours?|days?|weeks?|months?|years?)\s+ago\b|(?:前|前に|منذ))/i.test(text)) return true;
  return new RegExp("(?:^|\\s)" + number + ":" + number + "(?::" + number + ")?(?:\\s?(?:am|pm|a\\.m\\.|p\\.m\\.))?(?:\\s|$)", "i").test(text);
}

function visibleInlineHeaderDateFields(header) {
  if (!header || elementVisuallyHidden(header) || header.closest("aside, nav, [role='complementary']")) return [];
  return Array.from(header.querySelectorAll("strong, b, span, time")).map(function(node) {
    var previous = node.previousSibling;
    if (!previous || previous.nodeType !== Node.TEXT_NODE || elementVisuallyHidden(node)) return null;
    var label = normalizeText(previous.textContent || "");
    if (!/^(?:published|updated|last updated|atualizad[oa]|publicad[oa]|actualizado|aggiornato)(?:\s+(?:on|at|em|el|às))?\s*:?$/i.test(label)) return null;
    var value = normalizeText(node.textContent || "");
    if (!/^(?:\d{1,2}[./-]\d{1,2}[./-]\d{4}|\d{4}-\d{2}-\d{2})(?:\s+(?:(?:at|às)\s+)?\d{1,2}:\d{2}(?::\d{2})?)?$/i.test(value)) return null;
    return { node: node, label: label, value: value };
  }).filter(Boolean);
}

function visibleInlineDateHeader() {
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) { return !elementVisuallyHidden(node); });
  var headers = headings.map(function(heading) { return heading.closest("header, .entry-header, .post-header"); }).filter(function(header, index, all) {
    return header && all.indexOf(header) === index && visibleInlineHeaderDateFields(header).length;
  });
  if (headers.length !== 1) return null;
  var header = headers[0];
  var owner = header.closest("article");
  var headline = header.matches("h1") ? header : header.querySelector("h1");
  if (headings.some(function(heading) {
    return heading !== headline && (!owner || heading.closest("article") !== owner ||
      normalizeText(heading.textContent) !== normalizeText(headline.textContent));
  })) return null;
  return header;
}

function visibleInlinePublishedTime(roots) {
  var header = visibleInlineDateHeader();
  if (!header || !roots.some(function(root) { return root.contains(header); })) return null;
  var fields = visibleInlineHeaderDateFields(header);
  return fields.length ? fields[0].value : null;
}

function visiblePublishedTime() {
  var roots = visiblePublishedTimeRoots();
  var fields = [
      "[itemprop='datePublished']",
      "[itemprop='dateModified']",
      "[class*='pubdate' i]",
      "[class*='published-date' i]",
      "[class*='published_at' i]",
      "[class*='published-at' i]",
      "[class*='publication-date' i]",
      "[class*='fecha' i]",
      "[class*='data-publicacao' i]",
      "[class*='data-publicação' i]",
      "[class*='datum' i]",
      "[class*='tarih' i]",
      "[class*='date' i]",
      "[class*='time' i]",
      "[class*='publish' i]",
      "[class*='posted' i]",
      "[data-testid*='date' i]",
      "time"
    ];
  return firstScopedText(roots, ["time[datetime]"], "datetime", null, function(node) {
      return visiblePublishedTimeField(node) && visiblePublicationDateLike(node.getAttribute("datetime") || node.textContent || "");
    }) ||
    firstScopedText(roots, ["time[datetime]"], "datetime") ||
    firstScopedText(roots, fields, null, null, function(node) {
      if (!visiblePublishedTimeField(node)) return false;
      var value = node.getAttribute("datetime") || node.getAttribute("content") || node.textContent || "";
      return visiblePublicationDateLike(value);
    }) ||
    firstScopedText(roots, fields, null, null, visiblePublishedTimeField) || visibleInlinePublishedTime(roots);
}
