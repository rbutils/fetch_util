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
    return lineLower === titleLower || lineLower.indexOf(titleLower) === 0;
  });
}

function compactReferenceText(text) {
  return normalizeText(text || "")
    .replace(/([a-z0-9])((?:Default:|Can be one of:|For more information:|Example:|Required))/g, "$1 $2")
    .replace(/([a-z])([A-Z][a-z])/g, "$1 $2");
}
