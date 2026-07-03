  function pushUniqueListCandidate(candidates, seen, candidate) {
    if (!candidate) return false;

    var key = candidate.text + "|" + candidate.url;
    if (seen[key] || seen["url:" + candidate.url]) return false;
    seen[key] = true;
    seen["url:" + candidate.url] = true;
    candidates.push(candidate);
    return true;
  }

  function listCandidateRank(a, b) {
    return b.score - a.score || b.text.length - a.text.length;
  }

  function listCandidateScoreRank(a, b) {
    return b.score - a.score;
  }

  function extractListItems(root) {
    var itemNodes = Array.prototype.slice.call(root.querySelectorAll("tr.athing, article, li, section, .item, .story, .post, .entry, .news, .headline, .feed-item, [class*='card'], [class*='result'], [class*='teaser'], [class*='news'], [class*='headline'], [class*='feed'], [class*='thread'], [class*='topic-list'], .structItem, .discussionListItem"));
    var seen = {};
    var candidates = [];
    var context = listPageContext();

    function looksLikeMetaLink(text, href) {
      return text.length < 18 ||
        /^(comments?|discuss|hide|more|abonneren|subscribe|newsletter|login|log in|sign in|register|create account|maak een account|instellingen|settings|account|last post|first unread|go to last post|mark read|mark forum read|watch forum|new thread|post new thread|post reply|quick reply|forum rules|forum actions|forum tools)$/i.test(text) ||
        /^[\w.-]+\.[a-z]{2,}$/i.test(text) ||
        /(?:^|[?&])(user|from|site|goto)=/i.test(href) ||
        looksLikeFooterLink(text, href) ||
        listNoiseText(text);
    }

    function pushLink(link, container) {
      var candidate = listLinkCandidate(link, container, context);
      if (!candidate) return;
      if (looksLikeMetaLink(candidate.text, candidate.url)) return;

      pushUniqueListCandidate(candidates, seen, candidate);
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

    candidates.sort(listCandidateRank);

    return candidates;
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

      pushUniqueListCandidate(ranked, seen, candidate);
    });

    ranked.sort(listCandidateScoreRank);

    return ranked;
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

  var productStructuredDataCache = null;

  function productStructuredDataItems() {
    if (productStructuredDataCache) return productStructuredDataCache;

    var items = [];

    function pushEntity(entity) {
      if (!entity || typeof entity !== "object") return;
      if (Array.isArray(entity)) {
        entity.forEach(pushEntity);
        return;
      }

      var type = entity["@type"] || entity.type;
      var types = Array.isArray(type) ? type : [type];
      if (types.some(function(value) { return /^(product|book)$/i.test(normalizeText(value)); })) items.push(entity);
      if (entity["@graph"]) pushEntity(entity["@graph"]);
      if (entity.itemListElement) pushEntity(entity.itemListElement);
      if (entity.item) pushEntity(entity.item);
    }

    structuredDataNodes().forEach(pushEntity);

    productStructuredDataCache = items;
    return items;
  }

  function commerceEntityText(value) {
    if (value === null || value === undefined) return "";
    if (Array.isArray(value)) return commerceEntityText(value[0]);
    if (typeof value === "object") return normalizeText(value.name || value.value || value["@id"] || value.url || "");
    return normalizeText(String(value));
  }

  function productOffer(product) {
    var offer = product && product.offers;
    if (Array.isArray(offer)) offer = offer[0];
    return offer || null;
  }

  function normalizedCommercePrice(price, currency) {
    price = commerceEntityText(price).replace(/\s+/g, "");
    currency = commerceEntityText(currency).toUpperCase();
    if (!price) return "";
    var symbolPrice = price.match(/[$€£]\s?\d[\d,]*(?:\.\d{2})?/);
    if (symbolPrice) return symbolPrice[0].replace(/([$€£])\s+/g, "$1");
    if (!/^\d[\d,.]*$/.test(price)) return "";
    if (currency === "USD") return "$" + price;
    if (currency === "EUR") return "€" + price;
    if (currency === "GBP") return "£" + price;
    return currency ? price + " " + currency : price;
  }

  function humanizeCommerceAvailability(value) {
    return humanizeValue(value).replace(/([a-z])([A-Z])/g, "$1 $2");
  }

  function productMatchesCard(product, title, url) {
    var name = commerceEntityText(product && product.name).toLowerCase();
    var titleText = normalizeText(title || "").toLowerCase();
    var offer = productOffer(product);
    var productUrl = commerceEntityText((product && product.url) || (offer && offer.url));
    var absoluteProductUrl = productUrl ? absoluteUrl(productUrl) : "";

    if (url && absoluteProductUrl && absoluteProductUrl.replace(/[#?].*$/, "") === url.replace(/[#?].*$/, "")) return true;
    if (name && titleText && (name === titleText || name.indexOf(titleText) !== -1 || titleText.indexOf(name) !== -1)) return true;
    return false;
  }

  function productStructuredDetail(title, url) {
    var product = productStructuredDataItems().find(function(item) {
      return productMatchesCard(item, title, url);
    });
    if (!product) return [];

    var offer = productOffer(product);
    var rating = product.aggregateRating || product.reviewRating;
    var details = [];
    var price = normalizedCommercePrice(offer && (offer.price || (offer.priceSpecification && offer.priceSpecification.price)), offer && (offer.priceCurrency || (offer.priceSpecification && offer.priceSpecification.priceCurrency)));
    var availability = commerceEntityText(offer && offer.availability);
    var ratingValue = commerceEntityText(rating && rating.ratingValue);
    var ratingCount = commerceEntityText(rating && (rating.reviewCount || rating.ratingCount));

    if (price) details.push(price);
    if (ratingValue) details.push(productRatingDetail(ratingValue, ratingCount));
    if (availability) details.push(humanizeCommerceAvailability(availability));
    return details;
  }

  function productRatingDetail(ratingValue, ratingCount) {
    return "Rating: " + ratingValue + "/5" + (ratingCount ? " from " + ratingCount + " reviews" : "");
  }

  function productCardDetail(node, title, url) {
    if (!node) return "";

    var text = normalizeText(node.textContent || "");
    var details = productStructuredDetail(title, url);

    function pushDetail(value) {
      value = normalizeText(value);
      if (value && details.indexOf(value) === -1) details.push(value);
    }

    function textFromSelector(selector) {
      var el = node.querySelector(selector);
      return normalizeText(el && (el.getAttribute("content") || el.getAttribute("href") || el.getAttribute("aria-label") || el.textContent));
    }

    var domPrice = normalizedCommercePrice(textFromSelector("[itemprop='price'], meta[itemprop='price'][content], [class*='price' i], [data-testid*='price' i], [aria-label*='price' i]"), textFromSelector("[itemprop='priceCurrency'], meta[itemprop='priceCurrency'][content]"));
    if (domPrice) pushDetail(domPrice);

    var matches = text.match(/([$€£]\s?\d[\d,.]*(?:\.\d{2})?)/g) || [];
    matches.slice(0, 2).forEach(function(price) {
      if (details.indexOf(price) === -1) details.push(price);
    });

    var ratingValue = textFromSelector("[itemprop='ratingValue'], meta[itemprop='ratingValue'][content]");
    var ratingCount = textFromSelector("[itemprop='reviewCount'], [itemprop='ratingCount'], meta[itemprop='reviewCount'][content], meta[itemprop='ratingCount'][content]");
    if (ratingValue && /^\d(?:\.\d+)?$/.test(ratingValue)) pushDetail(productRatingDetail(ratingValue, ratingCount));

    var ratingNode = node.querySelector("[aria-label*='out of 5' i], [class*='rating' i], [class*='stars' i]");
    var ratingText = normalizeText(ratingNode && (ratingNode.getAttribute("aria-label") || ratingNode.textContent));
    var ratingMatch = ratingText.match(/\b(\d(?:\.\d+)?)\s*(?:out of|\/)\s*5\b/i) || text.match(/\b(\d(?:\.\d+)?)\s*out of\s*5\s*stars?\b/i);
    if (ratingMatch) {
      var reviewMatch = (ratingText + " " + text).match(/\b([\d,]+)\s*(?:reviews?|ratings?)\b/i);
      pushDetail(productRatingDetail(ratingMatch[1], reviewMatch && reviewMatch[1]));
    }

    var availability = textFromSelector("[itemprop='availability'], link[itemprop='availability'][href], meta[itemprop='availability'][content], [class*='stock' i], [class*='availability' i], [data-testid*='availability' i]");
    if (!availability) {
      var availabilityMatch = text.match(/\b(in stock|out of stock|sold out|available now|currently unavailable|unavailable|pre-?order|backordered|request it)\b/i);
      availability = availabilityMatch && availabilityMatch[0];
    }
    if (availability) pushDetail(humanizeCommerceAvailability(availability));

    [/\bfree shipping\b/i].forEach(function(pattern) {
      var match = text.match(pattern);
      if (match) pushDetail(match[0]);
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

    var pageTerms = safeDecodeURI([location.pathname || "", location.search || "", (metadata && metadata.title) || document.title].join(" ")).toLowerCase().replace(/[^a-z0-9]+/g, " ").split(/\s+/).filter(function(term) {
      return term.length >= 3 && !/^(shop|store|products?|items?|brand|brands|category|categories|search|results|sale|gift|sets|perfume|perfumes|fragrance|fragrances|cologne|women|men|unisex)$/i.test(term);
    });
    var queryTerms = [];

    new URLSearchParams(location.search || "").forEach(function(value, key) {
      if (!/^(q|query|search|searchtext|keyword|k|d)$/i.test(key || "")) return;
      safeDecodeURI(value || "").toLowerCase().replace(/[^a-z0-9]+/g, " ").split(/\s+/).forEach(function(term) {
        if (term.length >= 3 && queryTerms.indexOf(term) === -1) queryTerms.push(term);
      });
    });

    function rejectedProductTitle(text) {
      return /^\(\d+\)\s+/.test(text) || /^(top sellers|new arrivals|product|brand name|review count|star rating|sort by|view all|more options(?: from .*)?|privacy policy|my privacy choices|sign in|order status|shipping info|fragrances|see all fragrances|perfume|bath & body|gift sets|unboxed\/testers|perfume samples|cologne|samples|cologne samples|women'?s perfume|men'?s cologne|0 items in your bag|0 0 items in your bag|request it|become a fragrancenet\.com vip|powered by onetrust opens in a new tab)$/i.test(text) || /\(designer\)$/i.test(text);
    }

    function productUrlKey(url) {
      try {
        var parsed = new URL(url, location.href);
        return (parsed.origin + parsed.pathname).toLowerCase();
      } catch (_error) {
        return String(url || "").toLowerCase();
      }
    }

    function titleMatchesPageTerms(text) {
      text = text.toLowerCase();
      return pageTerms.some(function(term) {
        return text.indexOf(term) !== -1;
      });
    }

    function titleMatchesQueryTerms(text) {
      text = text.toLowerCase();
      return queryTerms.some(function(term) {
        return text.indexOf(term) !== -1;
      });
    }

    function candidateInfo(link) {
      var image = link.querySelector("img[alt], img[title]");
      var url = absoluteUrl(link.getAttribute("href"));
      var card = link.closest("article, li, [class*='product'], [class*='item'], [class*='card'], div, section") || link.parentElement;
      if (card === link && link.parentElement) card = link.parentElement.closest("article, li, [class*='product'], [class*='item'], [class*='card'], div, section") || link.parentElement;
      var titleLinkOptions = [];
      var titleOptions = [
        normalizeText(link.textContent || ""),
        normalizeText(link.getAttribute("aria-label") || ""),
        normalizeText(image && (image.getAttribute("alt") || image.getAttribute("title")))
      ];

      if (card && url) {
        Array.prototype.forEach.call(card.querySelectorAll("a[href][class*='title' i], [class*='title' i] a[href]"), function(titleLink) {
          var titleUrl = absoluteUrl(titleLink.getAttribute("href"));
          if (productUrlKey(titleUrl) === productUrlKey(url)) titleLinkOptions.push(normalizeText(titleLink.textContent || titleLink.getAttribute("aria-label") || ""));
        });
      }

      if (titleLinkOptions.length) titleOptions = titleLinkOptions;
      titleOptions.sort(function(a, b) { return b.length - a.length; });
      var title = titleOptions[0] || "";
      if (!url || !title || title.length < 6 || title.length > 140) return null;
      if (rejectedProductTitle(title)) return null;
      if (/(sort|filter|review|rating|privacy|cookie|onetrust)/i.test(url) && title.length < 32) return null;
      if (url === location.href || /^(javascript:|mailto:)/i.test(url)) return null;

      var productPath = "";
      try {
        productPath = new URL(url, location.href).pathname;
      } catch (_error) {
        return null;
      }

      var productUrl = /(\/product|\/perfume|\/cologne|\/dp\/|\/itm\/|\/pdp\/|\/shop\/products\/|\/p\/(?!pl(?:\/|$)))/i.test(productPath);
      var cardAttrs = normalizeText(card && [
        card.getAttribute("id"),
        card.getAttribute("class"),
        card.getAttribute("data-testid"),
        card.getAttribute("data-hb-id"),
        card.getAttribute("itemtype")
      ].join(" "));
      var productCard = /(product|item-cell|item-container|schema\.org\/Product)/i.test(cardAttrs);
      if (!productUrl && !productCard) return null;
      if (queryTerms.length && !titleMatchesQueryTerms(title)) return null;
      if (pageTerms.length && queryOrCategoryPage() && !titleMatchesPageTerms(title)) return null;

      var detail = productCardDetail(card, title, url);
      if (!titleMatchesPageTerms(title) && !productUrl && !productCard) return null;

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
      var urlKey = productUrlKey(info.url);
      if (seen[key] || seen["url:" + info.url] || seen["product:" + urlKey]) return;
      seen[key] = true;
      seen["url:" + info.url] = true;
      seen["product:" + urlKey] = true;
      items.push(info);
    });

    if (items.length < 4) return null;

    var markdown = listMarkdown(items);
    var result = listContentResult({
      title: (metadata && metadata.title) || document.title,
      excerpt: items[0].text,
      siteName: (metadata && metadata.siteName) || location.hostname,
      textContent: markdown,
      markdown: markdown
    });
    result.itemCount = items.length;
    return result;
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

    return listContentResult({
      title: metadata.title || document.title,
      excerpt: best.items[0] ? best.items[0].text : metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      html: best.root.innerHTML,
      textContent: best.markdown,
      markdown: best.markdown
    });
  }
