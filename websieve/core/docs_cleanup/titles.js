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

function articleTitleFromAdjacentHeading(html, title) {
  if (!document.body || !html || !title) return title;
  var articles = Array.prototype.filter.call(document.querySelectorAll("article"), function(article) {
    return !elementSubtreeHidden(article) && article.previousElementSibling &&
      article.previousElementSibling.matches("header") && article.querySelectorAll("p").length >= 2;
  });
  if (articles.length !== 1) return title;

  var article = articles[0];
  var header = article.previousElementSibling;
  var headings = header.querySelectorAll("h1");
  if (headings.length !== 1 || header.querySelector("nav, form, [role='navigation'], a[href]") ||
      elementSubtreeHidden(headings[0])) return title;

  function words(text) {
    return normalizeText(text || "").toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();
  }

  var shortTitle = words(title);
  var heading = normalizeText(headings[0].textContent || "");
  var fullTitle = words(heading);
  if (shortTitle.length < 35 || fullTitle.length < shortTitle.length + 12 ||
      fullTitle.indexOf(shortTitle) !== 0) return title;

  var finalWords = fullTitle.split(" ").slice(-4).join(" ");
  if (finalWords.length < 15 || words(article.textContent).indexOf(finalWords) < 0 ||
      words(html).indexOf(finalWords) < 0) return title;
  return heading;
}

function articleTitleFromSelfLinkedHeading(html, title) {
  if (!document.body || !html || !title) return title;
  var root = document.createElement("div");
  root.innerHTML = html;
  var articles = root.querySelectorAll("article");
  if (articles.length !== 1) return title;
  var article = articles[0];
  var firstHeading = article.querySelector("h1, h2");
  var link = firstHeading && firstHeading.querySelector("a[href]");
  if (!link || firstHeading !== article.firstElementChild) return title;
  var heading = normalizeText(link.textContent || "");
  var fullTitle = normalizeText(title);
  if (heading.length < 35 || fullTitle.indexOf(heading) !== 0) return title;
  var suffix = normalizeText(fullTitle.slice(heading.length));
  if (!/^(?:-|\||\u2013|\u2014)\s+\S/.test(suffix) ||
      normalizeText(article.textContent || "").indexOf(suffix.slice(2)) >= 0) return title;

  var ownerLinks = Array.prototype.filter.call(document.querySelectorAll("article h1 a[href], article h2 a[href]"), function(candidate) {
    if (elementSubtreeHidden(candidate) || normalizeText(candidate.textContent || "") !== heading) return false;
    var owner = candidate.closest("article");
    if (!owner || owner.querySelectorAll("p").length < 3 || owner.querySelector("h1, h2") !== candidate.parentElement) return false;
    var url = materializedHttpUrl(candidate.getAttribute("href"));
    if (!url) return false;
    var destination = new URL(url);
    return destination.origin === location.origin && destination.pathname === location.pathname &&
      destination.search === location.search;
  });
  return ownerLinks.length === 1 ? heading : title;
}

function articleSelfLinkedHeadlineMarkdown(markdown, html, title) {
  if (!markdown || !html || !title || !document.body) return markdown;
  var root = document.createElement("div");
  root.innerHTML = html;
  var articles = root.querySelectorAll("article");
  if (articles.length !== 1) return markdown;
  var heading = articles[0].firstElementChild;
  var link = heading && heading.matches("h2") && heading.querySelector("a[href]");
  if (!link || heading.querySelectorAll("a[href]").length !== 1 ||
      normalizeText(link.textContent || "") !== normalizeText(title)) return markdown;
  var source = Array.prototype.filter.call(document.querySelectorAll("main article h1 a[href]"), function(node) {
    return !elementSubtreeHidden(node) && normalizeText(node.textContent || "") === normalizeText(title);
  });
  if (source.length !== 1) return markdown;
  var selectedUrl = materializedHttpUrl(link.getAttribute("href"));
  var sourceUrl = materializedHttpUrl(source[0].getAttribute("href"));
  if (!selectedUrl || selectedUrl !== sourceUrl ||
      new URL(selectedUrl).origin !== location.origin ||
      new URL(selectedUrl).pathname !== location.pathname ||
      new URL(selectedUrl).search !== location.search) return markdown;

  var lines = markdown.split("\n");
  var first = lines.findIndex(function(line) { return !!normalizeText(line); });
  if (first < 0 || normalizeText(lines[first]) !== normalizeText(cleanupMarkdownNoise(markdownFor(heading.outerHTML)))) return markdown;
  lines[first] = "# " + title;
  return lines.join("\n");
}

function compactReferenceText(text) {
  return normalizeText(text || "")
    .replace(/([a-z0-9])((?:Default:|Can be one of:|For more information:|Example:|Required))/g, "$1 $2")
    .replace(/([a-z])([A-Z][a-z])/g, "$1 $2");
}
