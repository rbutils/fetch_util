  function extractListItems(root) {
    var itemNodes = Array.prototype.slice.call(root.querySelectorAll("tr.athing, article, li, section, .item, .story, .post, .entry, .news, .headline, .feed-item, [class*='card'], [class*='result'], [class*='teaser'], [class*='news'], [class*='headline'], [class*='feed']"));
    var seen = {};
    var candidates = [];
    var context = listPageContext();

    function looksLikeMetaLink(text, href) {
      return text.length < 18 ||
        /^(comments?|discuss|hide|more|abonneren|subscribe|newsletter|login|log in|sign in|register|create account|maak een account|instellingen|settings|account)$/i.test(text) ||
        /^[\w.-]+\.[a-z]{2,}$/i.test(text) ||
        /(?:^|[?&])(user|from|site|goto)=/i.test(href) ||
        looksLikeFooterLink(text, href) ||
        listNoiseText(text);
    }

    function pushLink(link, container) {
      var candidate = listLinkCandidate(link, container, context);
      if (!candidate) return;
      if (looksLikeMetaLink(candidate.text, candidate.url)) return;

      var key = candidate.text + "|" + candidate.url;
      if (seen[key] || seen["url:" + candidate.url]) return;
      seen[key] = true;
      seen["url:" + candidate.url] = true;
      candidates.push(candidate);
    }

    function bestLink(node) {
      var headingLink = node.querySelector("h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href] h1, a[href] h2, a[href] h3, a[href] h4");
      if (headingLink) return headingLink.closest("a[href]") || headingLink;

      var links = Array.prototype.slice.call(node.querySelectorAll("a[href]"));
      links = links.filter(function(link) {
        var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        return text && !looksLikeFooterLink(text, link.getAttribute("href") || "") && !listChromeNode(link) && !listChromeNode(link.parentElement) && !listChromeAncestor(link);
      });
      links.sort(function(a, b) {
        var aText = normalizeText(a.textContent || a.getAttribute("aria-label") || "");
        var bText = normalizeText(b.textContent || b.getAttribute("aria-label") || "");
        return bText.length - aText.length;
      });
      return links[0] || null;
    }

    itemNodes.forEach(function(node) {
      pushLink(bestLink(node), node);
    });

    if (candidates.length < 5) {
      var anchors = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
        var text = normalizeText(link.textContent);
        var href = link.getAttribute("href");
        if (!href || href[0] === "#") return false;
        if (/^(javascript:|mailto:)/i.test(href)) return false;
        if (looksLikeMetaLink(text, href)) return false;
        return text.length >= minimumListTitleLength(text) && text.length <= 220;
      });

      anchors.forEach(function(link) {
        pushLink(link, link.closest("tr, li, article, section, div") || link.parentElement);
      });
    }

    candidates.sort(function(a, b) {
      return b.score - a.score || b.text.length - a.text.length;
    });

    return candidates.slice(0, 20);
  }

  function extractFallbackHeadlineItems(node) {
    if (!node || !node.querySelectorAll) return [];

    var seen = {};
    var ranked = [];
    var context = listPageContext();
    var selectors = [
      "h1 a[href]",
      "h2 a[href]",
      "h3 a[href]",
      "h4 a[href]",
      "article a[href]",
      "section a[href]",
      "[class*='headline'] a[href]",
      "[class*='story'] a[href]",
      "[class*='post'] a[href]",
      "[class*='news'] a[href]",
      "[class*='feed'] a[href]",
      "[class*='teaser'] a[href]",
      "[class*='result'] a[href]"
    ].join(", ");

    Array.prototype.forEach.call(node.querySelectorAll(selectors), function(link) {
      var container = link.closest("article, section, li, div") || link.parentElement;

      if (listNavigationNode(link) || listNavigationNode(link.parentElement) || listNavigationAncestor(link)) return;

      var candidate = listLinkCandidate(link, container, context);
      if (!candidate) return;

      var key = candidate.text + "|" + candidate.url;
      if (seen[key] || seen["url:" + candidate.url]) return;
      seen[key] = true;
      seen["url:" + candidate.url] = true;
      ranked.push(candidate);
    });

    ranked.sort(function(a, b) {
      return b.score - a.score;
    });

    return ranked.slice(0, 20);
  }

  function listItemsQualityScore(items) {
    return (items || []).reduce(function(total, item, index) {
      var value = Math.max(0, item && item.score ? item.score : textLength(item && item.text));
      value = Math.min(value, 1200);
      if (index >= 8) value = Math.round(value / 2);
      return total + value;
    }, 0);
  }

  function cleanupListRoot(root) {
    cleanupCookieChrome(root);
    stripTrackingPixels(root);
    resolveLazyImages(root);
    stripUIWidgets(root);
    stripNavigationLeaks(root);

    root.querySelectorAll("header, footer, nav, menu, [role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='banner'], [role='contentinfo']").forEach(function(el) {
      el.remove();
    });

    root.querySelectorAll("section, div, aside, form, ul, ol").forEach(function(el) {
      if (listChromeNode(el)) el.remove();
    });

    root.querySelectorAll('a[href^="#"]').forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (!text || /^skip\s+(to\s+)?/i.test(text)) el.remove();
    });

    root.querySelectorAll("a, button").forEach(function(el) {
      var text = normalizeText(el.textContent).toLowerCase();
      if (/^(sign in|log in|login|register|subscribe|newsletter|follow us|follow|join now|create account|my account|account|menu|search)$/i.test(text)) el.remove();
    });

    return root;
  }

  function listDescriptionMarkdown(root) {
    var descParts = [];
    root.querySelectorAll("h1, h2, h3, p").forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (text.length >= 30 && text.length <= 2000) {
        if (listNoiseText(text) || cookieNoticeText(text) || legalFooterText(text) || weatherModuleText(text)) return;
        var links = el.querySelectorAll("a[href]").length;
        var words = text.split(/\s+/).length;
        if (links <= 1 || (links / words) < 0.3) {
          var prefix = /^H[123]$/.test(el.tagName) ? "## " : "";
          descParts.push(prefix + text);
        }
      }
    });
    return descParts.slice(0, 8).join("\n\n");
  }

  function buildListExtraction(node) {
    var root = cleanClone(node);
    cleanupListRoot(root);
    var items = extractListItems(root);
    var itemQuality = listItemsQualityScore(items);
    var descText = listDescriptionMarkdown(root);
    var fallbackItems = extractFallbackHeadlineItems(node);
    var fallbackQuality = listItemsQualityScore(fallbackItems);
    if ((items.length < 3 && fallbackItems.length > items.length) || fallbackQuality > itemQuality + 180) {
      items = fallbackItems;
      itemQuality = fallbackQuality;
    }
    var linkMarkdown = listMarkdown(items);
    var markdown = descText ? descText + (linkMarkdown ? "\n\n" + linkMarkdown : "") : linkMarkdown;

    if (normalizeText(markdown).length < 120) {
      if (fallbackItems.length > items.length || fallbackQuality > itemQuality) {
        items = fallbackItems;
        itemQuality = fallbackQuality;
        linkMarkdown = listMarkdown(items);
        markdown = descText ? descText + (linkMarkdown ? "\n\n" + linkMarkdown : "") : linkMarkdown;
      }
    }

    return {
      root: root,
      items: items,
      descText: descText,
      markdown: markdown,
      score: itemQuality + (items.length * 80) + Math.min(descText.length, 4000)
    };
  }

  function listMarkdown(items) {
    return items.map(function(item) {
      var line = "- [" + item.text + "](" + item.url + ")";
      if (item.detail) line += " - " + item.detail;
      return line;
    }).join("\n");
  }

  function productCardDetail(node, title) {
    if (!node) return "";

    var text = normalizeText(node.textContent || "");
    var details = [];
    var matches = text.match(/([$€£]\s?\d[\d,.]*(?:\.\d{2})?)/g) || [];
    matches.slice(0, 2).forEach(function(price) {
      if (details.indexOf(price) === -1) details.push(price);
    });
    [
      /\b\d(?:\.\d)?\s*out of\s*5\s*stars?\b/i,
      /\bfree shipping\b/i,
      /\brequest it\b/i,
      /\bout of stock\b/i,
      /\bsold out\b/i,
      /\bin stock\b/i
    ].forEach(function(pattern) {
      var match = text.match(pattern);
      if (match && details.indexOf(match[0]) === -1) details.push(match[0]);
    });

    return details.filter(Boolean).join(" - ");
  }

  function genericProductListContent(metadata) {
    var seen = {};
    var items = [];
    var selectors = ["main", "[role='main']", ".products", ".product-grid", ".product-list", ".search-results", ".category", ".collection", "body"];
    var roots = [];

    selectors.forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(node) {
        if (roots.indexOf(node) === -1) roots.push(node);
      });
    });

    var pageTerms = safeDecodeURI([location.pathname || "", (metadata && metadata.title) || document.title].join(" ")).toLowerCase().replace(/[^a-z0-9]+/g, " ").split(/\s+/).filter(function(term) {
      return term.length >= 4 && !/^(shop|store|products?|items?|brand|brands|category|categories|search|results|sale|gift|sets|perfume|perfumes|fragrance|fragrances|cologne|women|men|unisex)$/i.test(term);
    });

    function rejectedProductTitle(text) {
      return /^\(\d+\)\s+/.test(text) || /^(top sellers|new arrivals|product|brand name|review count|star rating|sort by|view all|privacy policy|my privacy choices|sign in|order status|shipping info|fragrances|see all fragrances|perfume|bath & body|gift sets|unboxed\/testers|perfume samples|cologne|samples|cologne samples|women'?s perfume|men'?s cologne|0 items in your bag|0 0 items in your bag|request it|become a fragrancenet\.com vip|powered by onetrust opens in a new tab)$/i.test(text) || /\(designer\)$/i.test(text);
    }

    function titleMatchesPageTerms(text) {
      text = text.toLowerCase();
      return pageTerms.some(function(term) {
        return text.indexOf(term) !== -1;
      });
    }

    function candidateInfo(link) {
      var title = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      var url = absoluteUrl(link.getAttribute("href"));
      if (!url || !title || title.length < 6 || title.length > 140) return null;
      if (rejectedProductTitle(title)) return null;
      if (/(sort|filter|review|rating|privacy|cookie|onetrust)/i.test(url) && title.length < 32) return null;
      if (url === location.href || /^(javascript:|mailto:)/i.test(url)) return null;

      var card = link.closest("article, li, [class*='product'], [class*='item'], [class*='card'], div, section") || link.parentElement;
      var detail = productCardDetail(card, title);
      if (!titleMatchesPageTerms(title) && !/(\/product|\/perfume|\/cologne|\/dp\/|\/itm\/|\/p\/|\/shop\/products\/)/i.test(url)) return null;

      return { text: title, url: url, detail: detail };
    }

    function scoreRoot(root) {
      var count = 0;
      Array.prototype.forEach.call(root.querySelectorAll("a[href]"), function(link) {
        if (candidateInfo(link)) count += 1;
      });
      return count;
    }

    var bestRoot = roots.reduce(function(current, node) {
      var score = scoreRoot(node);
      if (!current || score > current.score) return { node: node, score: score };
      return current;
    }, null);

    if (!bestRoot || bestRoot.score < 4) return null;

    Array.prototype.forEach.call(bestRoot.node.querySelectorAll("a[href]"), function(link) {
      if (items.length >= 15) return;

      var info = candidateInfo(link);
      if (!info) return;

      var key = info.text + "|" + info.url;
      if (seen[key]) return;
      seen[key] = true;
      items.push(info);
    });

    if (items.length < 4) return null;

    return {
      title: (metadata && metadata.title) || document.title,
      byline: null,
      excerpt: items[0].text,
      siteName: (metadata && metadata.siteName) || location.hostname,
      publishedTime: null,
      html: "",
      textContent: listMarkdown(items),
      markdown: listMarkdown(items),
      readerMode: false,
      contentType: "list"
    };
  }

  function listContent(metadata) {
    var candidates = [];

    function pushCandidate(node) {
      if (!node || candidates.indexOf(node) !== -1) return;
      candidates.push(node);
    }

    pushCandidate(listCandidateRoot(metadata));
    contextualListCandidates(metadata).forEach(pushCandidate);
    pushCandidate(document.querySelector("main, [role='main']"));
    pushCandidate(document.body);

    var best = candidates.reduce(function(current, node) {
      var result = buildListExtraction(node);
      if (!current || result.score > current.score) return result;
      return current;
    }, null) || buildListExtraction(document.body);

    return {
      title: metadata.title || document.title,
      byline: null,
      excerpt: best.items[0] ? best.items[0].text : metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      publishedTime: null,
      html: best.root.innerHTML,
      textContent: best.markdown,
      markdown: best.markdown,
      readerMode: false,
      contentType: "list"
    };
  }
