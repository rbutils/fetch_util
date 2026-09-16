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

function visibleBylineRoots() {
  var roots = visibleMetadataRoots();
  var path = location.pathname || "/";
  if (path !== "/" && !/^\/index\.(?:html?|php|aspx?)$/i.test(path)) return roots;

  var focal = [];
  document.querySelectorAll("[itemprop='articleBody'], article[role='main']").forEach(function(node) {
    var root = node.closest("article, [role='main'], main") || node;
    if (focal.indexOf(root) === -1 && textLength(root) >= 80) focal.push(root);
  });
  if (focal.length) return focal;

  var articles = roots.filter(function(root) {
    return root.matches && root.matches("article") && !(root.parentElement && root.parentElement.closest("article"));
  });
  return articles.length >= 2 ? [] : roots;
}

function firstScopedText(roots, selectors, attr, rejectedValue) {
  for (var r = 0; r < roots.length; r += 1) {
    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = roots[r].querySelectorAll(selectors[i]);
      for (var n = 0; n < nodes.length; n += 1) {
        var node = nodes[n];
        if (elementVisuallyHidden(node) || node.closest("nav, footer, aside")) continue;

        var value = attr ? node.getAttribute(attr) : node.textContent;
        value = normalizeText(value);
        if (rejectedValue && rejectedValue.test(value)) continue;
        if (value) return value;
      }
    }
  }

  return null;
}

function localizedAuthorProfilePath(href) {
  try {
    var url = new URL(href, location.href);
    if (url.origin !== location.origin || url.username || url.password) return false;

    var segments = url.pathname.split("/").filter(Boolean).map(function(segment) {
      return decodeURIComponent(segment).toLowerCase();
    });
    var authorRoutes = ["author", "authors", "autoren", "autor", "autores", "auteur"];
    var routeIndex = segments.findIndex(function(segment) {
      return authorRoutes.indexOf(segment) !== -1;
    });
    if (routeIndex !== segments.length - 2) return false;

    var slug = segments[segments.length - 1];
    if (/[\u0000-\u001f\u007f/\\]/.test(slug)) return false;
    return !/^(?:archive|directory|index|login|register|search|signin|topics?)$/.test(slug);
  } catch (e) {
    return false;
  }
}

function visibleMetadataOwnerText(node) {
  return [
    node.getAttribute("id"),
    node.getAttribute("class"),
    node.getAttribute("itemprop"),
    node.getAttribute("data-testid"),
    node.getAttribute("aria-label")
  ].join(" ")
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .toLowerCase();
}

function relatedMetadataOwner(node) {
  if (!node || node.nodeType !== 1) return false;
  var attrs = visibleMetadataOwnerText(node);
  return /\b(?:related|recommended|recommendations?|trending|popular)\b|\bmore\s+stories\b/.test(attrs);
}

function localizedAuthorLinkContext(node, root) {
  if (!node || elementVisuallyHidden(node) || node.closest("nav, footer, aside")) return false;
  if (!localizedAuthorProfilePath(node.getAttribute("href") || "")) return false;

  var parent = node.parentElement;
  if (!parent) return false;
  var directArticleChild = parent === root && root.matches("article");
  var metadataOwner = false;
  var ancestor = parent;
  while (ancestor && ancestor !== root) {
    var attrs = visibleMetadataOwnerText(ancestor);
    if (relatedMetadataOwner(ancestor)) return false;
    if (/\b(?:author|byline|credit|contributor|reporter|writer|metadata|meta)\b/.test(attrs)) metadataOwner = true;
    ancestor = ancestor.parentElement;
  }

  ancestor = root;
  while (ancestor && ancestor !== document.body) {
    if (relatedMetadataOwner(ancestor)) return false;
    ancestor = ancestor.parentElement;
  }

  return directArticleChild || metadataOwner;
}

function visibleLocalizedAuthor(roots) {
  for (var r = 0; r < roots.length; r += 1) {
    var links = roots[r].querySelectorAll("a[href]");
    for (var i = 0; i < links.length; i += 1) {
      if (!localizedAuthorLinkContext(links[i], roots[r])) continue;
      var value = normalizeText(links[i].textContent || "");
      if (value) return value;
    }
  }

  return null;
}

function visibleByline() {
  var roots = visibleBylineRoots();
  var value = firstScopedText(roots, [
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
  ], null, /^(?:author information|authors? and affiliations?)$/i);
  if (!value) value = visibleLocalizedAuthor(roots);

  return normalizeText(value || "").replace(/^(?:by|por|par|von|di|da|door|av|af|de|autor(?:a)?|auteur|redactie|redacción|redacao|redação|penulis|oleh|tác giả|tac gia|بقلم|כתבת?|מאת)\s*:?\s+/i, "") || null;
}

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

function visiblePublishedTime() {
  var roots = visiblePublishedTimeRoots();
  return firstScopedText(roots, ["time[datetime]"], "datetime") ||
    firstScopedText(roots, [
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
