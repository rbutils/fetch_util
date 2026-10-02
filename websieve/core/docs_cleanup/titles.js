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
  var currentPageUrl = sourceOwnershipPageUrl(materializedCanonicalUrl() || location.href);
  if (sourceOwnedSelfLinkedArticleHasConflictingRecord(headingNode, heading, currentPageUrl)) return title;
  if (!heading || title.toLowerCase().indexOf(heading.toLowerCase()) !== 0) return title;
  var suffix = normalizeText(title.slice(heading.length));
  var match = suffix.match(/^(?:-|\||\u2013|\u2014)\s+(.+)$/);
  if (!match) return title;
  return brand(match[1]) === brand(siteName) ? heading : title;
}

function articleTitleFromVisibleArticleHeading(html, title, siteName) {
  if (!document.body || !html || !title) return title;
  var selected = document.createElement("div");
  selected.innerHTML = html;
  var selectedArticles = selected.querySelectorAll("article");
  if (selectedArticles.length > 1) return title;
  var article = selectedArticles.length === 1 ? selectedArticles[0] : selected;
  var fullTitle = normalizeText(title);
  var sourceArticles = Array.prototype.filter.call(document.querySelectorAll("article"), function(source) {
    return !elementSubtreeHidden(source) && !sourceOwnershipInChrome(source);
  });
  var owners = sourceArticles.map(function(source) {
    var headings = Array.prototype.filter.call(source.querySelectorAll("h1"), function(heading) {
      return heading.closest("article") === source && !elementSubtreeHidden(heading) && !sourceOwnershipInChrome(heading);
    });
    if (headings.length !== 1) return null;
    var heading = headings[0];
    var headline = normalizeText(heading.textContent || "");
    var suffix = normalizeText(fullTitle.slice(headline.length));
    if (headline.length < 8 || fullTitle.indexOf(headline) !== 0 ||
        !/^(?:-|\||\u2013|\u2014)\s+\S/.test(suffix) ||
        normalizeText(source.textContent || "").indexOf(suffix.slice(2)) >= 0) return null;

    var selectedH1s = article.querySelectorAll("h1");
    var selectedHeading = selectedH1s.length === 1 ? selectedH1s[0] : null;
    if (selectedHeading && !elementSubtreeHidden(selectedHeading) &&
        normalizeText(selectedHeading.textContent || "") === headline) {
      var proof = sourceOwnedSelfLinkedArticle(article, headline);
      if (proof ? proof.owner !== source :
          !sourceOwnedTitleSuffixMatchesPublisher(suffix, siteName) || sourceArticleForSelectedParagraphs(article) !== source) return null;
      return { source: source, heading: heading };
    }
    var linkedHeadings = Array.prototype.filter.call(article.querySelectorAll("h2"), function(candidate) {
      var links = candidate.querySelectorAll("a[href]");
      return normalizeText(candidate.textContent || "") === headline && links.length === 1 &&
        materializedHttpUrl(links[0].getAttribute("href")) === materializedHttpUrl(location.href);
    });
    if (selectedH1s.length || linkedHeadings.length !== 1) return null;
    var proof = sourceOwnedSelfLinkedArticle(article, headline);
    return proof && proof.owner === source ? { source: source, heading: heading } : null;
  }).filter(Boolean);
  return owners.length === 1 ? normalizeText(owners[0].heading.textContent || "") : title;
}

function sourceOwnedTitleSuffixMatchesPublisher(suffix, siteName) {
  if (!suffix || !siteName) return false;
  var match = normalizeText(suffix).match(/^(?:-|\||\u2013|\u2014)\s+(.+)$/);
  if (!match) return false;
  var publisher = normalizeText(siteName).replace(/^www\./i, "").toLowerCase();
  var hostParts = (location.hostname || "").replace(/^www\./i, "").toLowerCase().split(".").filter(function(part) {
    return part.length >= 3 && !/^(?:com|net|org|gov|edu|co)$/.test(part);
  });
  return match[1].split(/\s*[|·•]\s*/).some(function(part) {
    var component = normalizeText(part).replace(/^www\./i, "").toLowerCase();
    return component === publisher || hostParts.indexOf(component) !== -1;
  });
}

function sourceOwnedReaderHeadlineContent(content) {
  if (!content || !content.readerMode || content.hostAware || content.contentType !== "article" ||
      !content.html || content.markdown || !document.body) return content;
  var sourceArticles = Array.prototype.filter.call(document.querySelectorAll("main article, body > article"), function(article) {
    return !elementSubtreeHidden(article) && !article.parentElement.closest("article");
  });
  if (sourceArticles.length !== 1) return content;
  var source = sourceArticles[0];
  var sourceHeading = source.firstElementChild;
  if (!sourceHeading || !sourceHeading.matches("h1") || elementSubtreeHidden(sourceHeading) ||
      source.querySelectorAll("h1").length !== 1) return content;

  var root = document.createElement("div");
  root.innerHTML = content.html;
  var articles = root.querySelectorAll("article");
  if (articles.length !== 1) return content;
  var selected = articles[0];
  var heading = selected.firstElementChild;
  var title = normalizeText(sourceHeading.textContent || "");
  var contentTitle = normalizeText(content.title || document.title || "");
  var titleOwned = contentTitle === title;
  if (!titleOwned && contentTitle.indexOf(title) === 0) {
    var suffix = normalizeText(contentTitle.slice(title.length));
    var suffixMatch = suffix.match(/^(?:-|\||\u2013|\u2014)\s+(.+)$/);
    var suffixBrand = normalizeText(suffixMatch && suffixMatch[1] || "").toLowerCase();
    var siteBrand = normalizeText(content.siteName || "").replace(/^www\./i, "").toLowerCase();
    var hostBrands = (location.hostname || "").replace(/^www\./i, "").toLowerCase().split(".").filter(function(part) {
      return part.length >= 3 && !/^(?:com|net|org|gov|edu|co)$/.test(part);
    });
    titleOwned = !!suffixBrand && (suffixBrand === siteBrand || hostBrands.indexOf(suffixBrand) >= 0);
  }
  if (!heading || !heading.matches("h2") || selected.querySelectorAll("h1, h2").length !== 1 ||
      title.length < 8 || normalizeText(heading.textContent || "") !== title ||
      !titleOwned) return content;
  var paragraphs = Array.prototype.map.call(selected.querySelectorAll("p"), function(node) {
    return normalizeText(node.textContent || "");
  }).filter(Boolean);
  if (paragraphs.length < 2 || sourceArticleForSelectedParagraphs(selected) !== source) return content;

  var restored = document.createElement("h1");
  Array.prototype.forEach.call(heading.attributes, function(attribute) {
    restored.setAttribute(attribute.name, attribute.value);
  });
  while (heading.firstChild) restored.appendChild(heading.firstChild);
  heading.replaceWith(restored);
  return Object.assign({}, content, { title: title, html: root.innerHTML });
}

function articleTitleFromSelfLinkedHeading(html, title) {
  if (!document.body || !html || !title) return title;
  var root = document.createElement("div");
  root.innerHTML = html;
  var articles = root.querySelectorAll("article");
  if (articles.length !== 1) return title;
  var owner = sourceArticleForSelectedParagraphs(articles[0]);
  var sourceHeadings = owner && owner.querySelectorAll("h1");
  var heading = normalizeText(sourceHeadings && sourceHeadings.length === 1 && sourceHeadings[0].textContent || "");
  if (!heading || !normalizeText(title).startsWith(heading)) return title;
  var proof = sourceOwnedSelfLinkedArticle(articles[0], heading);
  if (!proof) return title;
  var suffix = normalizeText(normalizeText(title).slice(heading.length));
  return /^(?:-|\||\u2013|\u2014)\s+\S/.test(suffix) ? heading : title;
}

function compactReferenceText(text) {
  return normalizeText(text || "")
    .replace(/([a-z0-9])((?:Default:|Can be one of:|For more information:|Example:|Required))/g, "$1 $2")
    .replace(/([a-z])([A-Z][a-z])/g, "$1 $2");
}

function preserveUnprovenSourceTitleExtension(markdown, sourceTitle, documentTitle) {
  var heading = normalizeText(sourceTitle || "");
  var title = normalizeText(documentTitle || "");
  if (!heading || !title || title.indexOf(heading) !== 0) return markdown;
  var suffix = normalizeText(title.slice(heading.length));
  if (!/^(?:-|\||:|\u2013|\u2014)\s+\S/.test(suffix)) return markdown;
  var lines = (markdown || "").split("\n");
  var headingIndex = lines.findIndex(function(line) {
    var match = normalizeText(line).match(/^(#{1,6})\s+(.*)/);
    return normalizeText(match && match[2]) === heading;
  });
  if (headingIndex < 0) return markdown;
  var marker = lines[headingIndex].match(/^(#{1,6}\s+)/);
  lines[headingIndex] = marker[1] + title;
  return lines.join("\n");
}
