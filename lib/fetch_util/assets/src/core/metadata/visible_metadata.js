function platformSignature(metadata, extraSelectors) {
  var generator = normalizeText(firstText(["meta[name='generator']"], "content") || "");
  var appName = normalizeText(firstText(["meta[name='application-name']", "meta[property='og:site_name']"], "content") || "");
  var signatureParts = (Array.isArray(extraSelectors) ? extraSelectors : extraSelectors ? [extraSelectors] : []).map(function(selector) {
    if (typeof selector === "function") return selector(metadata, generator, appName);
    return firstText([selector]);
  });

  if (signatureParts.length === 0) {
    signatureParts = [metadata && metadata.title, metadata && metadata.siteName, generator, appName, document.title];
  }

  return {
    generator: generator,
    appName: appName,
    signature: normalizeText(signatureParts.join(" "))
  };
}

function firstText(selectors, attr) {
  for (var i = 0; i < selectors.length; i += 1) {
    var node = document.querySelector(selectors[i]);
    if (!node) continue;

    var value = attr ? node.getAttribute(attr) : node.textContent;
    value = normalizeText(value);
    if (value) return value;
  }

  return null;
}

function visibleMetadataRoots() {
  var roots = [];
  [
    "article[itemtype*='NewsArticle']",
    "article[itemtype*='Article']",
    "article",
    "main article",
    "main"
  ].forEach(function(selector) {
    document.querySelectorAll(selector).forEach(function(node) {
      if (roots.indexOf(node) === -1 && textLength(node) >= 80) roots.push(node);
    });
  });

  return roots.length ? roots : [document];
}

function firstScopedText(roots, selectors, attr) {
  for (var r = 0; r < roots.length; r += 1) {
    for (var i = 0; i < selectors.length; i += 1) {
      var node = roots[r].querySelector(selectors[i]);
      if (!node || node.closest("nav, footer, aside")) continue;

      var value = attr ? node.getAttribute(attr) : node.textContent;
      value = normalizeText(value);
      if (value) return value;
    }
  }

  return null;
}

function visibleByline() {
  var value = firstScopedText(visibleMetadataRoots(), [
    "[rel='author']",
    "[itemprop='author'] [itemprop='name']",
    "[itemprop='author']",
    "[class*='byline' i]",
    "[class*='author' i]",
    "[class*='autor' i]",
    "[class*='auteur' i]",
    "[class*='verfasser' i]",
    "[class*='redakteur' i]",
    "[class*='penulis' i]",
    "[class*='tac-gia' i]",
    "[class*='tacgia' i]",
    "[class*='writer' i]",
    "[class*='reporter' i]",
    "[data-testid*='author' i]"
  ]);

  return normalizeText(value || "").replace(/^(?:by|por|par|von|di|da|door|av|af|de|autor(?:a)?|auteur|redactie|redacción|redacao|redação|penulis|oleh|tác giả|tac gia|بقلم|כתבת?|מאת)\s*:?\s+/i, "") || null;
}

function visiblePublishedTime() {
  return firstScopedText(visibleMetadataRoots(), ["time[datetime]"], "datetime") ||
    firstScopedText(visibleMetadataRoots(), [
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
    ]);
}

function manyTexts(selectors, limit) {
  var seen = {};
  var items = [];

  selectors.forEach(function(selector) {
    document.querySelectorAll(selector).forEach(function(node) {
      if (limit && items.length >= limit) return;

      var text = normalizeText(node.textContent);
      if (!text || seen[text]) return;
      seen[text] = true;
      items.push(text);
    });
  });

  return items;
}
