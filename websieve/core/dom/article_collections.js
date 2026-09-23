  var TERMINAL_ARTICLE_RECOMMENDATION_HEADING_PATTERN = /^(?:related (?:articles?|content|news|posts?|stories)|recommended articles?|you (?:may|might) also like|latest news|trending now|popular posts?|most read|read more|also read|further reading|see also|more stories|don't miss|polecane|przeczytaj (?:też|również)|podobne (?:artykuły|wpisy)|leia (?:também|mais)|artigos? relacionados?|também pode gostar|ähnliche (?:beiträge|artikel)|das könnte sie auch interessieren|weiterlesen|mehr zum thema|artículos? relacionados?|también te puede interesar|te puede interesar|lee también|noticias relacionadas|articles? (?:connexes?|similaires?|associée?s?)|à lire aussi|sur le même (?:sujet|thème)|vous aimerez aussi|najnovije (?:vesti|vijesti))$/i;
  var terminalArticleCollectionMarkers = new Set();

  function terminalArticleCollectionMarked(node) {
    return !!(node && terminalArticleCollectionMarkers.has(
      node.getAttribute("data-fetchutil-terminal-article-links") || ""
    ));
  }

  function resetTerminalArticleCollectionMarker() {
    terminalArticleCollectionMarkers.clear();
  }

  function terminalArticleDecodedPath(pathname) {
    var decoded = pathname;
    for (var pass = 0; pass < 4; pass += 1) {
      if (decoded.indexOf("%") === -1) return decoded;
      decoded = decodeURIComponent(decoded);
    }
    return decoded.indexOf("%") === -1 ? decoded : null;
  }

  function terminalArticleCollectionCandidates(root) {
    return Array.from(root.querySelectorAll("[class~='news-box' i]"));
  }

  function terminalArticleTrackingQueryName(name) {
    return /^(?:utm_.+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)$/i.test(name);
  }

  function terminalArticleComparableUrl(url) {
    var comparable = new URL(url.href);
    Array.from(comparable.searchParams.keys()).forEach(function(name) {
      if (terminalArticleTrackingQueryName(name)) comparable.searchParams.delete(name);
    });
    comparable.hash = "";
    return comparable;
  }

  function terminalArticleStoryDestination(link, currentUrl) {
    var text = normalizeText(link.textContent || "");
    var destination = materializedHttpUrl(link.getAttribute("href") || "");
    if (!destination || rejectedHomepageLeadText(text, destination)) return null;
    if (link.hasAttribute("download") || link.matches("[rel~='author' i], [rel~='tag' i], [rel~='cite' i]")) return null;
    var relationTokens = (link.getAttribute("rel") || "").toLowerCase().split(/\s+/).filter(Boolean);
    if (relationTokens.some(function(relation) {
      return /^(?:alternate|canonical|enclosure|external|icon|license|manifest|next|prev|search|stylesheet)$/.test(relation);
    })) return null;
    var type = normalizeText(link.getAttribute("type") || "").toLowerCase();
    if (type && type !== "text/html" && type !== "application/xhtml+xml") return null;

    try {
      var parsed = new URL(destination);
      if (parsed.origin !== currentUrl.origin) return null;
      var uncertainQuery = Array.from(parsed.searchParams.keys()).some(function(name) {
        return !terminalArticleTrackingQueryName(name);
      });
      if (uncertainQuery) return null;
      var comparableDestination = terminalArticleComparableUrl(parsed);
      var comparableCurrent = terminalArticleComparableUrl(currentUrl);
      if (comparableDestination.pathname === comparableCurrent.pathname &&
          comparableDestination.search === comparableCurrent.search) return null;
      var decodedPath = terminalArticleDecodedPath(parsed.pathname);
      if (!decodedPath) return null;
      var basename = decodedPath.split("/").filter(Boolean).pop() || "";
      var extensionStart = basename.lastIndexOf(".");
      if (extensionStart >= 0 && !/^(?:html?|xhtml|shtml|php|asp|aspx)$/i.test(basename.slice(extensionStart + 1))) return null;
      var pathSegments = decodedPath.split("/").filter(Boolean);
      if (pathSegments.some(function(segment) {
        return /^(?:account|api|assets?|attachments?|careers?|contact|documents?|downloads?|exports?|feeds?|files?|help|login|media|newsletter|privacy|register|resources?|rss|search|settings|signin|subscribe|support|terms|uploads?)$/i.test(segment);
      })) return null;
      if (/^(?:about|account|advertise|careers?|contact|documents?|downloads?|files?|help|login|newsletter|privacy|register|resources?|search|signin|subscribe|support|terms)$/i.test(basename)) return null;
      return destination;
    } catch (_error) {
      return null;
    }
  }

  function terminalArticleFocalParagraph(paragraph, article) {
    var text = normalizeText(paragraph.textContent || "");
    if (text.length < 40) return false;

    var owner = paragraph.parentElement;
    while (owner && owner !== article) {
      var tag = (owner.tagName || "").toLowerCase();
      var role = (owner.getAttribute("role") || "").toLowerCase();
      var tokens = ((owner.getAttribute("class") || "") + " " + (owner.id || ""))
        .toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
      if (/^(?:aside|nav|header|footer|form)$/.test(tag)) return false;
      if (/^(?:complementary|navigation|search)$/.test(role)) return false;
      if (tokens.some(function(token) {
        return /^(?:ad|ads|advert|banner|byline|comment|comments|market|newsletter|promo|rail|recommend|related|share|sidebar|social|subscribe|weather|widget)$/.test(token);
      })) return false;
      owner = owner.parentElement;
    }
    return owner === article;
  }

  function terminalArticleTrailingNodeHidden(node) {
    if (!node || node.nodeType !== 1) return false;
    return node.matches("script, style, noscript, template, [hidden], [inert], [aria-hidden='true']") ||
      /(?:^|;)\s*(?:display\s*:\s*none|visibility\s*:\s*(?:hidden|collapse))(?:\s*!important)?\s*(?:;|$)/i.test(node.getAttribute("style") || "");
  }

  function terminalArticleHasFollowingMaterial(node, article) {
    var current = node;
    while (current && current !== article) {
      var following = current.nextSibling;
      while (following) {
        if (following.nodeType === 3 && normalizeText(following.textContent || "")) return true;
        if (following.nodeType === 1 && !terminalArticleTrailingNodeHidden(following)) return true;
        following = following.nextSibling;
      }
      current = current.parentNode;
    }
    return false;
  }

  function terminalArticleLinkCollection(node) {
    if (!node || !node.matches("section, div, aside")) return false;
    if (!node.matches("[class~='news-box' i]")) return false;
    if (node.closest("[data-fetchutil-page-overview], [data-fetchutil-editorial-aside]")) return false;
    var article = node.closest("article");
    if (!article) return false;
    if (article.parentElement && article.parentElement.closest("article")) return false;
    if (terminalArticleHasFollowingMaterial(node, article)) return false;
    if (article.closest("[class*='related' i], [class*='recommend' i], [data-component*='related' i]")) return false;
    if (node.querySelector("p, article, main, figure, picture, img, video, audio, iframe, object, embed, blockquote, pre, code, table, dl, form, input, textarea, select, button, details, svg, canvas, math")) return false;

    var articleWithoutCollection = article.cloneNode(true);
    var clonedCollection = terminalArticleCollectionCandidates(article).indexOf(node);
    var clonedCollections = terminalArticleCollectionCandidates(articleWithoutCollection);
    if (clonedCollection < 0 || !clonedCollections[clonedCollection]) return false;
    clonedCollections[clonedCollection].remove();
    articleWithoutCollection.querySelectorAll("article").forEach(function(nestedArticle) {
      nestedArticle.remove();
    });
    var bodyParagraphs = Array.from(articleWithoutCollection.querySelectorAll("p")).filter(function(paragraph) {
      return terminalArticleFocalParagraph(paragraph, articleWithoutCollection);
    });
    var bodyText = bodyParagraphs.map(function(paragraph) {
      return normalizeText(paragraph.textContent || "");
    }).join(" ");
    if (bodyParagraphs.length < 2 || bodyText.length < 250) return false;

    var headings = Array.prototype.filter.call(node.children, function(child) {
      return child.matches("h2, h3, h4");
    });
    var links = Array.from(node.querySelectorAll("a[href]"));
    if (headings.length !== 1 || node.querySelectorAll("h1, h2, h3, h4, h5, h6").length !== 1 ||
        headings[0] !== node.firstElementChild || links.length < 1 || links.length > 8) return false;
    if (!TERMINAL_ARTICLE_RECOMMENDATION_HEADING_PATTERN.test(normalizeText(headings[0].textContent || ""))) return false;

    var currentUrl = new URL(location.href);
    var destinations = links.map(function(link) {
      return terminalArticleStoryDestination(link, currentUrl);
    });
    if (destinations.some(function(destination) { return !destination; })) return false;

    var remainder = node.cloneNode(true);
    var clonedHeading = Array.from(remainder.children).filter(function(child) {
      return child.matches("h2, h3, h4");
    })[0];
    if (clonedHeading) clonedHeading.remove();
    remainder.querySelectorAll("a[href]").forEach(function(child) { child.remove(); });
    return !normalizeText(remainder.textContent || "");
  }

  function stripTerminalArticleLinkCollections(root) {
    if (!root || !root.querySelectorAll || !terminalArticleCollectionMarkers.size) return root;
    root.querySelectorAll("[data-fetchutil-terminal-article-links]").forEach(function(node) {
      if (terminalArticleCollectionMarked(node)) node.remove();
    });
    return root;
  }

  function markTerminalArticleLinkCollections(root) {
    if (!root || !root.querySelectorAll) return root;
    var values = new Uint32Array(4);
    crypto.getRandomValues(values);
    var marker = Array.from(values).map(function(value) {
      return value.toString(16).padStart(8, "0");
    }).join("");
    terminalArticleCollectionMarkers.add(marker);
    root.querySelectorAll("[class~='news-box' i]").forEach(function(node) {
      if (terminalArticleLinkCollection(node)) {
        node.setAttribute("data-fetchutil-terminal-article-links", marker);
      }
    });
    return root;
  }

  function stripTerminalArticleCollectionMarkers(root) {
    if (!root || !root.querySelectorAll || !terminalArticleCollectionMarkers.size) return root;
    root.querySelectorAll("[data-fetchutil-terminal-article-links]").forEach(function(node) {
      if (terminalArticleCollectionMarked(node)) node.removeAttribute("data-fetchutil-terminal-article-links");
    });
    return root;
  }

  function shortRelatedArticleTeaser(node) {
    var description = normalizeText(node.lastElementChild && node.lastElementChild.textContent || "");
    if (!node.matches("section, aside") || node.children.length !== 2 ||
        !node.firstElementChild.matches("h2, h3, h4") ||
        !RELATED_SECTION_HEADING_PATTERN.test(normalizeText(node.firstElementChild.textContent || "")) ||
        !node.lastElementChild.matches("p") || !description || description.length >= 110) return false;
    return !node.querySelector("a[href], img, figure, video, audio, blockquote, ul, ol");
  }

  function stripShortRelatedArticleTeasers(root) {
    if (!document.body) return root;
    var candidates = Array.prototype.filter.call(root.querySelectorAll("section, aside"), shortRelatedArticleTeaser);
    if (!candidates.length) return root;
    var owners = new Map();
    document.body.querySelectorAll("article section, article aside, main section, main aside").forEach(function(source) {
      if (elementSubtreeHidden(source) || !shortRelatedArticleTeaser(source)) return;
      var text = normalizeText(source.textContent || "");
      owners.set(text, (owners.get(text) || 0) + 1);
    });
    candidates.forEach(function(node) {
      if (owners.get(normalizeText(node.textContent || "")) === 1) node.remove();
    });
    return root;
  }

  function contentWithoutTerminalArticleFurniture(content) {
    if (!content || !content.html || Object.prototype.hasOwnProperty.call(content, "markdown") ||
        !/^(?:article|medical)$/i.test(content.contentType || "")) return content;
    var root = document.createElement("div");
    root.innerHTML = content.html;
    var originalHtml = root.innerHTML;
    stripTerminalArticleLinkCollections(root);
    stripShortRelatedArticleTeasers(root);
    if (root.innerHTML === originalHtml) return content;

    return Object.assign({}, content, {
      html: root.innerHTML,
      textContent: normalizeText(root.textContent || "")
    });
  }
