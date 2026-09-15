function firstMatchingNode(selectors) {
  for (var i = 0; i < selectors.length; i += 1) {
    var node = document.querySelector(selectors[i]);
    if (node) return node;
  }

  return null;
}

function docsHostSignature(metadata) {
  return normalizeText([location.hostname, metadata && metadata.siteName, metadata && metadata.title, document.title].join(" "));
}

function formatDocsTitle(title, formatter, metadata) {
  if (!title) return null;
  if (typeof formatter === "function") title = formatter(title, metadata);
  return cleanDocsHeadingText(title || "") || null;
}

function docsTitleText(metadata, selectors, fallbackTitle, formatter) {
  var title = firstText(selectors || []);
  if (!title && typeof fallbackTitle === "function") title = fallbackTitle(metadata);
  if (!title && typeof fallbackTitle === "string") title = fallbackTitle;
  return formatDocsTitle(title, formatter, metadata);
}

function cleanDocsHeadings(root, selector, formatter) {
  selector = selector || "h1, h2, h3, h4, h5, h6";
  formatter = formatter || function(text) { return cleanDocsHeadingText(text); };

  root.querySelectorAll(selector).forEach(function(el) {
    var text = formatter(el.textContent, el);
    if (text) el.textContent = text;
  });
}

function docsNamedAnchorTarget(name) {
  if (!name) return null;

  var anchors = document.querySelectorAll("a[name]");
  for (var i = 0; i < anchors.length; i += 1) {
    if ((anchors[i].getAttribute("name") || "") === name) return anchors[i];
  }

  return null;
}

function docsFragmentTarget(root) {
  var id = safeDecodeURI((location.hash || "").replace(/^#/, "")).trim();
  if (!id) return null;

  var target = document.getElementById(id) || docsNamedAnchorTarget(id);
  if (!target) return null;
  if (root !== target && !root.contains(target)) return null;
  return target;
}

function focusedDocsNode(root) {
  var target = docsFragmentTarget(root);
  if (!target) return root;

  var candidate = target;
  while (candidate && candidate !== root) {
    var text = normalizeText(candidate.textContent);
    if (/^(section|article|div|li|dt|dd|main)$/i.test(candidate.tagName || "") && text.length >= 20) return candidate;
    candidate = candidate.parentElement;
  }

  return target;
}

function docsFragmentTitle(root) {
  var target = docsFragmentTarget(root);
  if (!target) return null;

  var heading = target.matches && target.matches("h1, h2, h3, h4, h5, h6") ? target : target.querySelector("h1, h2, h3, h4, h5, h6");
  if (!heading && target.matches && target.matches("a[name]")) heading = target.nextElementSibling;
  var text = cleanDocsHeadingText((heading || target).textContent);
  return text || null;
}

function markdownStartsWithTitle(markdown, title) {
  title = normalizeText(title).replace(/[\`*_]/g, "");
  if (!title) return false;
  var titleLower = normalizeText(title).toLowerCase();
  var candidates = (markdown || "").split("\n").slice(0, 8).map(function(line) {
    return normalizeText(line).replace(/^#+\s*/, "").replace(/^\[([^\]]+)\]\([^)]*\)$/, "$1").replace(/[\`*_]/g, "");
  }).filter(Boolean);
  return candidates.some(function(line) {
    var lineLower = normalizeText(line).toLowerCase();
    if (lineLower === titleLower) return true;
    if (lineLower.indexOf(titleLower) !== 0) return false;

    var suffix = normalizeText(line.slice(title.length));
    return suffix.length <= 120 && /^(?:-|\||:|\u2013|\u2014)\s+\S/.test(suffix);
  });
}

function articleTitleHeading(root) {
  var headings = root.querySelectorAll("h1");
  if (headings.length) return headings.length === 1 ? headings[0] : null;
  var paragraphs = Array.prototype.map.call(root.querySelectorAll("p"), function(node) {
    return normalizeText(node.textContent || "");
  }).filter(function(text) { return text.length >= 40; });
  if (!paragraphs.length) return null;
  var candidates = Array.prototype.filter.call(document.querySelectorAll("article h1"), function(heading) {
    if (elementSubtreeHidden(heading)) return false;
    var owner = heading.closest("article");
    var ownerText = normalizeText(owner.textContent || "");
    return paragraphs.every(function(text) { return ownerText.indexOf(text) !== -1; });
  });
  return candidates.length === 1 ? candidates[0] : null;
}

function articleTitleFromOwnedHeading(html, title, siteName) {
  if (!html || !title || !siteName) return title;
  var brand = function(value) { return normalizeText(value).replace(/^www\./i, "").toLowerCase(); };
  var titleParts = title.split(/\s+(?:-|\||\u2013|\u2014)\s+/);
  if (titleParts.length < 2 || brand(titleParts[titleParts.length - 1]) !== brand(siteName)) return title;
  var root = document.implementation.createHTMLDocument("").createElement("div");
  root.innerHTML = html;
  var headingNode = articleTitleHeading(root);
  if (!headingNode) return title;
  var heading = normalizeText(headingNode.textContent || "");
  if (!heading || title.toLowerCase().indexOf(heading.toLowerCase()) !== 0) return title;
  var suffix = normalizeText(title.slice(heading.length));
  var match = suffix.match(/^(?:-|\||\u2013|\u2014)\s+(.+)$/);
  if (!match) return title;
  return brand(match[1]) === brand(siteName) ? heading : title;
}

function compactReferenceText(text) {
  return normalizeText(text || "")
    .replace(/([a-z0-9])((?:Default:|Can be one of:|For more information:|Example:|Required))/g, "$1 $2")
    .replace(/([a-z])([A-Z][a-z])/g, "$1 $2");
}
