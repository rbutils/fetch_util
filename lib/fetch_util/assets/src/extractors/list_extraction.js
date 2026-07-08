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

  function collectCardLinkCandidates(root, options) {
    options = options || {};
    root = root || document;

    var cards = [];
    var selectors = options.cardSelectors || [];
    var seenCards = [];
    var seenCandidates = {};
    var items = [];
    var maxItems = options.maxItems || Infinity;
    var minTitleLength = options.minTitleLength || 0;
    var maxTitleLength = options.maxTitleLength || Infinity;
    var dedupe = options.dedupe !== false;

    if (typeof selectors === "string") selectors = [selectors];

    function pushCard(node) {
      if (!node || seenCards.indexOf(node) !== -1) return;
      seenCards.push(node);
      cards.push(node);
    }

    function candidateKeys(candidate, card, link) {
      var keys;
      if (options.keyBuilder) keys = options.keyBuilder(candidate, card, link);
      if (keys === null || keys === undefined) keys = [candidate.text + "|" + (candidate.url || "")];
      if (!Array.isArray(keys)) keys = [keys];
      return keys.filter(Boolean);
    }

    selectors.forEach(function(selector) {
      Array.prototype.forEach.call(root.querySelectorAll(selector), pushCard);
    });

    if (!selectors.length && root.querySelectorAll) pushCard(root);

    cards.forEach(function(card) {
      if (items.length >= maxItems) return;

      var link = options.linkBuilder ? options.linkBuilder(card) : (options.linkSelector ? card.querySelector(options.linkSelector) : null);
      var candidate = options.candidateBuilder ? options.candidateBuilder(card, link) : null;
      var keys;

      if (!candidate) return;
      candidate.text = normalizeText(candidate.text || "");
      candidate.url = candidate.url || "";
      var candidateMinTitleLength = typeof minTitleLength === "function" ? minTitleLength(candidate.text) : minTitleLength;
      if (!candidate.text || candidate.text.length < candidateMinTitleLength || candidate.text.length > maxTitleLength) return;
      if (!options.allowMissingUrl && !candidate.url) return;
      if (options.rejectCandidate && options.rejectCandidate(candidate, card, link)) return;
      if (candidate.detail === undefined && options.detailBuilder) candidate.detail = options.detailBuilder(card, candidate, link);

      keys = candidateKeys(candidate, card, link);
      if (dedupe && keys.some(function(key) { return seenCandidates[key]; })) return;
      if (dedupe) keys.forEach(function(key) { seenCandidates[key] = true; });
      items.push(candidate);
    });

    return items;
  }

  function extractListItems(root) {
    var itemNodes = Array.prototype.slice.call(root.querySelectorAll("tr.athing, tr[data-id][data-url*='/remote-jobs/'], article, li, section, .item, .story, .post, .entry, .news, .headline, .feed-item, [class*='card'], [class*='result'], [class*='teaser'], [class*='news'], [class*='headline'], [class*='feed'], [class*='thread'], [class*='topic-list'], [class*='job-card' i], [data-testid='slider_container'], [data-test='jobListing'], [data-jobid], [data-url*='/remote-jobs/'], .structItem, .discussionListItem"));
    var seen = {};
    var candidates = [];
    var context = listPageContext();
    var caseRecordContext = /\b(?:cases?|defendants?|records?|dockets?|matters?)\b/i.test([location.pathname, document.title, (document.querySelector("h1") || {}).textContent].join(" "));

    function looksLikeMetaLink(text, href) {
      return text.length < (caseRecordContext ? 3 : 18) ||
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
      var line = item.url ? "- [" + item.text + "](" + item.url + ")" : "- " + item.text;
      if (item.detail) line += " - " + item.detail;
      return line;
    }).join("\n");
  }

  function genericJobListContent(metadata) {
    if (typeof jobResultsPage !== "function" || !jobResultsPage(document.body)) return null;

    var jobCardSelectors = "[data-testid='slider_container'], [data-test='jobListing'], [data-jobid], [data-testid*='job' i], [class*='job-card' i], [class*='jobCard'], tr[data-id][data-url*='/remote-jobs/'], [data-url*='/remote-jobs/']";

    function cardUrl(card, link) {
      var href = link && link.getAttribute("href");
      href = href || card.getAttribute("data-href") || card.getAttribute("data-url") || "";
      return href ? absoluteUrl(href) : "";
    }

    function titleLink(card) {
      return card.querySelector("a[data-test='job-title'], a[id*='job-title' i], a[href*='/job-listing/'], a[href*='/remote-jobs/'], a[href*='/viewjob'], a[href*='/rc/clk'], a[href*='jk='], a[href*='jl=']");
    }

    function cardTitle(card, link) {
      var company = normalizeText(card.getAttribute("data-company") || "");
      var search = normalizeText(card.getAttribute("data-search") || "").replace(/\s*\[.*$/i, "");
      if (company && search.indexOf(company) === 0) search = normalizeText(search.slice(company.length));

      var candidates = [
        search,
        normalizeText(link && (link.textContent || link.getAttribute("aria-label"))),
        normalizeText((card.querySelector("[data-test='job-title'], [data-testid*='jobTitle' i], h2, h3") || {}).textContent || "")
      ].map(function(value) {
        return normalizeText(value || "").replace(/\s*-?\s*\{\"@context\".*$/i, "");
      }).filter(Boolean);

      candidates.sort(function(a, b) { return b.length - a.length; });
      return candidates[0] || "";
    }

    function cardDetail(card, title) {
      var parts = [];
      ["[data-testid='company-name']", "[data-test='employer-name']", "[data-test='location']", "[data-testid*='location' i]", "[data-test='descSnippet']", "[data-testid='belowJobSnippet']"].forEach(function(selector) {
        var node = card.querySelector(selector);
        var text = normalizeText(node && node.textContent);
        if (text && parts.indexOf(text) === -1) parts.push(text);
      });

      if (!parts.length) {
        parts.push(normalizeText(card.textContent || "").replace(title, ""));
      }

      var detail = normalizeText(parts.join(" - ")).replace(title, "");
      detail = detail.replace(/\s*\{\"@context\".*$/i, "");
      if (detail.length > 220) detail = detail.slice(0, 217).replace(/\s+\S*$/, "") + "...";
      return detail;
    }

    var items = collectCardLinkCandidates(document, {
      cardSelectors: jobCardSelectors,
      linkBuilder: titleLink,
      allowMissingUrl: true,
      minTitleLength: minimumListTitleLength,
      maxTitleLength: 220,
      maxItems: 18,
      keyBuilder: function(candidate) {
        return candidate.text + "|" + candidate.url;
      },
      candidateBuilder: function(card, link) {
        var title = cardTitle(card, link);
        var url = cardUrl(card, link);

        return { text: title, url: url, detail: cardDetail(card, title) };
      }
    });

    if (items.length < 4) return null;

    var markdown = listMarkdown(items);

    return listItemsContentResult(metadata, {
      excerpt: items[0].text,
      textContent: markdown,
      markdown: markdown,
      items: items
    });
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

    function productCandidates(root, dedupe, maxItems) {
      return collectCardLinkCandidates(root, {
        cardSelectors: "a[href]",
        allowMissingUrl: false,
        dedupe: dedupe,
        maxItems: maxItems,
        keyBuilder: function(candidate) {
          return [candidate.text + "|" + candidate.url, "url:" + candidate.url, "product:" + productUrlKey(candidate.url)];
        },
        candidateBuilder: function(link) {
          return candidateInfo(link);
        }
      });
    }

    function scoreRoot(root) {
      return productCandidates(root, false).length;
    }

    var bestRoot = roots.reduce(function(current, node) {
      var score = scoreRoot(node);
      if (!current || score > current.score) return { node: node, score: score };
      return current;
    }, null);

    if (!bestRoot || bestRoot.score < 4) return null;

    items = productCandidates(bestRoot.node, true, 15);

    if (items.length < 4) return null;

    return listItemsContentResult(metadata, {
      excerpt: items[0].text,
      items: items
    });
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

    return listItemsContentResult(metadata, {
      title: metadata.title || document.title,
      excerpt: best.items[0] ? best.items[0].text : metadata.excerpt,
      html: best.root.innerHTML,
      textContent: best.markdown,
      markdown: best.markdown,
      items: best.items
    });
  }

  function searchItemTitle(link) {
    var heading = link.querySelector("h1, h2, h3, h4");
    return normalizeText(heading ? heading.textContent : link.textContent);
  }

  function cjkLikeText(text) {
    return /[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]/.test(text || "");
  }

  function minimumListTitleLength(text) {
    return cjkLikeText(text) ? 4 : 8;
  }

  function searchItemDetail(node, title) {
    var detail = normalizeText(node && node.textContent).replace(normalizeText(title), "").replace(/\s*[|·]\s*/g, " - ");
    detail = detail
      .replace(/Only include results for this site.*$/i, "")
      .replace(/This search result is provided by Google Learn more Report result/gi, "")
      .replace(/Learn more Report result/gi, "")
      .replace(/Report Ad/gi, "")
      .replace(/\bhttps?:\/\/\S+/gi, "")
      .replace(/\s{2,}/g, " ");
    return normalizeText(detail);
  }

  function newsHomepageListContent(metadata, config) {
    config = config || {};
    if (config.prepareMetadata) config.prepareMetadata(metadata);
    if (config.pathAllowed && !config.pathAllowed()) return null;

    var seen = {};
    var items = [];
    var maxItems = config.maxItems || 18;
    var minItems = config.minItems || 4;
    var minTitleLength = config.minTitleLength || 18;
    var maxTitleLength = config.maxTitleLength || 220;
    var detailMaxLength = config.detailMaxLength || 180;
    var linkSelector = config.linkSelector || "a[href]";
    var cardSelector = config.cardSelector || "article, section, li, div";

    function rejectedTitle(title) {
      if (!title || title.length < minTitleLength || title.length > maxTitleLength) return true;
      if (!config.rejectTitle) return false;
      if (typeof config.rejectTitle === "function") return config.rejectTitle(title);
      return config.rejectTitle.test(title);
    }

    document.querySelectorAll(linkSelector).forEach(function(link) {
      if (items.length >= maxItems) return;
      if (config.excludeClosest && link.closest(config.excludeClosest)) return;

      var href = link.getAttribute("href") || "";
      var url = absoluteUrl(href);
      if (!url || seen[url]) return;
      if (config.acceptLink && !config.acceptLink(href, url, link)) return;

      var title = config.titleBuilder ? config.titleBuilder(link) : searchItemTitle(link);
      if (config.transformTitle) title = config.transformTitle(title, link);
      title = normalizeText(title || "");
      if (rejectedTitle(title)) return;

      var container = link.closest(cardSelector) || link.parentElement;
      var detail = searchItemDetail(container, title);
      if (detail.length > detailMaxLength) detail = "";

      seen[url] = true;
      items.push({ text: title, url: url, detail: detail });
    });

    if (items.length < minItems) return null;

    var result = listContentResult({
      title: config.title || ((metadata && metadata.title) || document.title || config.defaultTitle),
      excerpt: metadata && metadata.excerpt,
      siteName: (metadata && metadata.siteName) || config.siteName || location.hostname,
      items: items
    });
    if (config.hostAware) result.hostAware = true;
    if (config.statusPage) result.statusPage = true;
    return result;
  }

  window.newsHomepageListProfiles = window.newsHomepageListProfiles || [];

  function newsHomepageListProfileMatches(condition, metadata) {
    if (condition === true) return true;
    if (condition === false) return false;
    if (typeof condition === "function") return condition(metadata);
    return hostMatches(condition);
  }

  window.registerNewsHomepageListProfile = function(condition, config) {
    newsHomepageListProfiles.push({ condition: condition, config: config });
  };

  window.hostAwareProfiles = window.hostAwareProfiles || [];
  window.hostAwareProfiles.push({
    condition: true,
    fn: function(metadata) {
      for (var i = 0; i < newsHomepageListProfiles.length; i += 1) {
        var profile = newsHomepageListProfiles[i];
        if (!newsHomepageListProfileMatches(profile.condition, metadata)) continue;

        var config = typeof profile.config === "function" ? profile.config(metadata) : profile.config;
        var result = newsHomepageListContent(metadata, config);
        if (result) return result;
      }
      return null;
    }
  });

  function isProbablyListPage(content) {
    if (!document.body) return false;

    function listSignals(root) {
      var links = root.querySelectorAll("a").length;
      var paragraphs = root.querySelectorAll("p").length;
      var rows = root.querySelectorAll("tr, li, article, section").length;
      var listItems = root.querySelectorAll("li").length;
      var listish = root.querySelectorAll("table, ul, ol, .itemlist, .items, .stories, .posts, .news, .headlines, .feed, .threads, .topic-list, .forumlist, .discussionList").length;
      var headings = root.querySelectorAll("h1, h2, h3, h4").length;
      var cards = root.querySelectorAll("article, section, [class*='card'], [class*='item'], [class*='story'], [class*='post'], [class*='news'], [class*='headline'], [class*='feed'], [class*='thread'], [class*='topic-list'], .structItem, .discussionListItem").length;
      var headlineLinks = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
        var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        return text.length >= minimumListTitleLength(text) && text.length <= 220 && !looksLikeFooterLink(text, link.getAttribute("href") || "");
      }).length;
      var text = normalizeText(root.textContent);
      var title = normalizeText(document.title).toLowerCase();
      var path = (location.pathname || "").toLowerCase();
      var homepage = path === "/" || path === "" || /^\/(index|default|home)\b/i.test(path) || /^\/\d+(,\d+)*\.html?$/i.test(path);

      return {
        links: links,
        paragraphs: paragraphs,
        rows: rows,
        listItems: listItems,
        listish: listish,
        headings: headings,
        cards: cards,
        headlineLinks: headlineLinks,
        text: text,
        title: title,
        homepage: homepage
      };
    }

    function homepageLike(signals) {
      // High-confidence portal detection: overwhelmingly list-like signals
      // bypass text length cap entirely (e.g. news portals with 40K-200K DOM text)
      if (signals.homepage && signals.headlineLinks >= 20 && signals.cards >= 15 && (signals.headings >= 8 || signals.cards >= 40)) return true;
      if (signals.headlineLinks >= 30 && signals.cards >= 20 && (signals.headings >= 10 || signals.cards >= 40)) return true;
      if (signals.homepage && signals.headlineLinks >= 16 && signals.headings >= 8 && signals.links >= 80 && signals.text.length <= 240000) return true;
      if (signals.headlineLinks >= 24 && signals.headings >= 10 && signals.links >= 120 && (signals.homepage || signals.rows >= 20 || signals.listish >= 2) && signals.text.length <= 240000) return true;

      return ((signals.links >= 8 && signals.rows >= 6) || (signals.listish > 0 && signals.links >= 6)) && signals.paragraphs <= 8 && signals.text.length <= 14000 ||
        ((signals.rows >= 6 && signals.headlineLinks >= 6 && signals.headings >= 6) && signals.text.length <= 36000) ||
        (signals.homepage && signals.headlineLinks >= 4 && signals.headings >= 3 && signals.text.length <= 36000 && (signals.listItems >= 4 || signals.cards >= 4 || /top stories|breaking news|latest news|headlines|ultime notizie|in evidenza|primo piano/.test(signals.title + " " + signals.text.slice(0, 400)))) ||
        (signals.cards >= 4 && signals.headlineLinks >= 4 && signals.headings >= 3 && signals.text.length <= 36000);
    }

    var pageRoot = document.createElement("div");
    pageRoot.innerHTML = document.body.innerHTML;
    var pageSignals = listSignals(pageRoot);

    if (homepageLike(pageSignals)) return true;

    var root = document.createElement("div");
    root.innerHTML = content && content.html ? content.html : document.body.innerHTML;
    return homepageLike(listSignals(root));
  }

  function dominantIndexListPage(content) {
    if (!document.body || articleLikePath()) return false;
    if (!likelyListPath() && !queryOrCategoryPage() && !jobResultsPage()) return false;

    var root = document.createElement("div");
    root.innerHTML = (content && content.html) || document.body.innerHTML;
    var links = root.querySelectorAll("a[href]").length;
    var cards = root.querySelectorAll("article, li, section, [class*='card'], [class*='item'], [class*='story'], [class*='product'], [class*='tile'], [class*='job'], [data-testid*='card'], [data-testid*='product'], [data-testid='slider_container'], [data-test='jobListing'], [data-jobid], [data-url*='/remote-jobs/']").length;
    var headings = root.querySelectorAll("h2, h3, h4").length;
    var headlineLinks = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      return text.length >= minimumListTitleLength(text) && text.length <= 220 && !looksLikeFooterLink(text, link.getAttribute("href") || "");
    }).length;
    var paragraphTexts = Array.prototype.map.call(root.querySelectorAll("p"), function(paragraph) {
      return normalizeText(paragraph.textContent || "");
    }).filter(Boolean);
    var longParagraphs = paragraphTexts.filter(function(text) { return text.length >= 180; }).length;
    var longParagraphText = paragraphTexts.filter(function(text) { return text.length >= 120; }).join(" ");
    var text = normalizeText(root.textContent || (content && (content.textContent || content.markdown)) || "");
    var linkText = Array.prototype.reduce.call(root.querySelectorAll("a[href]"), function(total, link) {
      return total + normalizeText(link.textContent || link.getAttribute("aria-label") || "").length;
    }, 0);
    var linkDensity = text.length > 0 ? linkText / text.length : 0;
    var pageRoot = document.createElement("div");
    pageRoot.innerHTML = document.body.innerHTML;
    var articleFeedLinks = Math.max(sectionFeedArticleLinks(root), sectionFeedArticleLinks(pageRoot));

    if (legalJudgmentArticleContent(root, text) || legalStatuteArticleContent(root, text)) return false;
    if (institutionalCaseRecordListPage(root, text) || institutionalCaseRecordListPage(pageRoot)) return true;
    if (longParagraphs >= 5 && longParagraphText.length >= 1200 && linkDensity < 0.35) return false;
    return headlineLinks >= 6 && cards >= 6 && links >= 8 && (headings >= 4 || linkDensity >= 0.22) || articleFeedLinks >= 6 || jobResultsPage(root);
  }

  function institutionalCaseRecordListPage(root, text) {
    root = root || document.body;
    text = normalizeText(text || (root && root.textContent) || "");
    if (!root || articleLikePath()) return false;

    var context = normalizeText([location.pathname, document.title, (document.querySelector("h1") || {}).textContent].join(" ")).toLowerCase();
    if (!/\b(?:cases?|defendants?|records?|dockets?|matters?)\b/.test(context)) return false;

    var caseCards = collectCardLinkCandidates(root, {
      cardSelectors: ".card, [class*='case-card' i], [class*='record-card' i], [class*='result-card' i], article, li",
      allowMissingUrl: true,
      dedupe: false,
      minTitleLength: 3,
      maxTitleLength: 180,
      linkBuilder: function(card) {
        return card.querySelector(".card-header, h2, h3, h4, a[href]");
      },
      candidateBuilder: function(card, titleNode) {
        var cardText = normalizeText(card.textContent || "");
        if (!/\b(?:case|defendant|prosecutor|trial|charges?|warrant|summons|custody|convicted|acquitted|closed|at large|court|record|docket|matter)\b/i.test(cardText)) return null;
        return { text: normalizeText((titleNode || {}).textContent || "") };
      }
    });
    var filterBlocks = root.querySelectorAll("form, [class*='filter' i], [class*='facet' i], [class*='exposed' i], [class*='search' i]").length;
    var countLabel = /\b\d{1,4}\s+(?:cases?|defendants?|records?|matters?|results?)\b/i.test(text);

    return caseCards.length >= 4 && (filterBlocks >= 1 || countLabel);
  }

  function jobResultsPage(root) {
    root = root || document.body;
    if (!root || articleLikePath()) return false;

    var context = normalizeText([location.pathname, location.search, document.title].join(" ")).toLowerCase();
    if (!/(\bjobs?\b|employment|careers?|jobsearch|job-list|job results?|hiring|remote-[a-z0-9+-]+-jobs|q-[a-z0-9-]+-jobs)/i.test(context)) return false;

    var jobCards = root.querySelectorAll("[data-testid='slider_container'], [data-test='jobListing'], [data-jobid], [data-testid*='job' i], [class*='job-card' i], [class*='jobCard'], tr[data-id][data-url*='/remote-jobs/'], [data-url*='/remote-jobs/']").length;
    var jobLinks = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
      var href = link.getAttribute("href") || "";
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      if (text.length < minimumListTitleLength(text) || text.length > 220) return false;
      return /(\/job-listing\/|\/remote-jobs\/|\/viewjob\b|\/rc\/clk\b|[?&](?:jk|jl)=)/i.test(href);
    }).length;

    return jobCards >= 4 || jobLinks >= 4;
  }

  function sectionFeedArticleLinks(root) {
    var currentUrl = currentListPageUrl();
    var seen = [];

    Array.prototype.forEach.call(root.querySelectorAll("a[href]"), function(link) {
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      var url = absoluteUrl(link.getAttribute("href"));
      var parsed;

      if (text.length < minimumListTitleLength(text) || text.length > 220 || looksLikeFooterLink(text, url || "")) return;
      if (!url) return;

      try {
        parsed = new URL(url, location.href);
      } catch (_error) {
        return;
      }

      if (parsed.origin !== location.origin || (parsed.origin + parsed.pathname) === currentUrl) return;
      if (!articleEntryPath(parsed.pathname)) return;
      if (seen.indexOf(parsed.origin + parsed.pathname) === -1) seen.push(parsed.origin + parsed.pathname);
    });

    return seen.length;
  }

  function thinSearchOrCategoryPage(content) {
    if (!content || content.contentType !== "article" || articleLikePath()) return false;
    if (!queryOrCategoryPage()) return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";
    var text = normalizeText(root.textContent || content.textContent || content.markdown || "");
    var paragraphs = root.querySelectorAll("p").length;
    var longParagraphs = Array.prototype.filter.call(root.querySelectorAll("p"), function(paragraph) {
      return normalizeText(paragraph.textContent || "").length >= 180;
    }).length;
    var byline = normalizeText(content.byline || "");
    var publishedTime = normalizeText(content.publishedTime || "");
    var heading = document.querySelector("main h1, [role='main'] h1, h1");
    var context = normalizeText([document.title, heading && heading.textContent].join(" ")).toLowerCase();

    if (publishedTime || byline) return false;
    if (typeof consentWallDominates === "function" && consentWallDominates(text.toLowerCase())) return false;
    if (!/(search|results?|shop|browse|categor|catalog|keyword|wholesale|products?|collections?|marketplace)/.test(context)) return false;
    if (longParagraphs >= 4 && text.length >= 1200) return false;
    return text.length < 2400 || paragraphs <= 4;
  }

  function markdownIndexListPage(markdown, content) {
    if (!markdown || articleLikePath()) return false;
    if (legalJudgmentArticleContent(null, markdown) || legalStatuteArticleContent(null, markdown)) return false;
    if (legalTableOfContentsMarkdown(markdown)) return true;
    if (!likelyListPath() && !queryOrCategoryPage()) return false;
    if (normalizeText(content && (content.byline || content.publishedTime))) return false;

    var lines = String(markdown).split(/\n+/);
    var linkedHeadlineLines = lines.filter(function(line) {
      return /^\s*(?:(?:\d+\.|[-*])\s+)?#{1,4}\s+\[[^\]]{8,220}\]\(/.test(line) ||
        /^\s*(?:\d+\.|[-*])\s+\[[^\]]{8,220}\]\(/.test(line);
    }).length;
    var linkedHeadlineMatches = (String(markdown).match(/(?:^|\s)(?:(?:\d+\.|[-*])\s+)?#{1,4}\s+\[[^\]]{8,220}\]\(/g) || []).length +
      (String(markdown).match(/(?:^|\s)(?:\d+\.|[-*])\s+\[[^\]]{8,220}\]\(/g) || []).length;
    var proseLines = lines.filter(function(line) {
      var text = normalizeText(line).replace(/^#+\s*/, "");
      if (!text || text.length < 160) return false;
      return !/^\s*(?:(?:\d+\.|[-*])\s+)?#{0,4}\s*\[[^\]]+\]\(/.test(line);
    }).length;

    if (markdownArticleEntryLinks(markdown) >= 6) return true;
    return Math.max(linkedHeadlineLines, linkedHeadlineMatches) >= 4 && proseLines < 5;
  }

  function searchResultsListPage(content, markdown) {
    if (!content || content.contentType !== "article" || articleLikePath()) return false;

    var path = (location.pathname || "").toLowerCase();
    var query = (location.search || "").toLowerCase();
    var searchUrl = /\/(?:search|results?)(?:\.html?)?$/i.test(path) || /(?:^|[?&])(?:q|query|search|searchtext|keyword|k|text)=/.test(query);
    if (!searchUrl) return false;

    var root = document.createElement("div");
    root.innerHTML = (content && content.html) || document.body.innerHTML;
    var text = normalizeText([root.textContent || "", markdown || "", document.title || ""].join(" "));
    var countText = text.replace(/[*_`]+/g, "");
    var resultCountText = /\bresults?\s*\d+\s*[-–]\s*\d+\s*(?:of|sur|von|de)\s*\d+\b/i.test(countText) || /\b\d+\s+results?\b/i.test(countText);
    var resultLinks = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
      var href = link.getAttribute("href") || "";
      var label = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      if (label.length < minimumListTitleLength(label) || label.length > 280 || looksLikeFooterLink(label, href)) return false;
      return /\/(?:legal-content|eli|LexUriServ|resource|document|doc|case-law|summary)\b|[?&](?:uri|celex|qid|docid)=/i.test(href);
    }).length;
    var resultContainers = root.querySelectorAll("[class*='result' i], [id*='result' i], article, li, tr").length;
    var markdownResultLinks = (String(markdown || "").match(/^\s*#{1,4}\s+\[[^\]]{8,280}\]\(/gm) || []).length;

    return resultCountText && (resultLinks >= 3 || markdownResultLinks >= 3) && (resultContainers >= 3 || markdownResultLinks >= 3);
  }

  function markdownArticleEntryLinks(markdown) {
    var seen = [];
    var pattern = /\[[^\]]{8,220}\]\(([^\s)]+)\)|https?:\/\/[^\s)]+/g;
    var match;

    while ((match = pattern.exec(String(markdown || "")))) {
      var raw = match[1] || match[0];
      var parsed;

      try {
        parsed = new URL(raw, location.href);
      } catch (_error) {
        continue;
      }

      if (parsed.origin !== location.origin || (parsed.origin + parsed.pathname) === currentListPageUrl()) continue;
      if (!articleEntryPath(parsed.pathname)) continue;
      if (seen.indexOf(parsed.origin + parsed.pathname) === -1) seen.push(parsed.origin + parsed.pathname);
    }

    return seen.length;
  }

  function relabelAsListContent(content) {
    if (content) content.contentType = "list";
    return content;
  }

  function substantialArticleContent(content) {
    if (!content || content.contentType !== "article") return false;
    var homePath = (location.pathname || "").toLowerCase();
    if (homePath === "/" || homePath === "" || /^\/(index|default|home)\b/i.test(homePath) || /^\/\d+(,\d+)*\.html?$/i.test(homePath)) return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";

    var text = normalizeText(root.textContent || content.textContent || "");
    var paragraphs = root.querySelectorAll("p").length;
    var headings = root.querySelectorAll("h1, h2, h3").length;
    var listLinks = (content.markdown || "").match(/^\s*- \[/gm) || [];
    var linkText = Array.prototype.reduce.call(root.querySelectorAll("a[href]"), function(total, link) {
      return total + normalizeText(link.textContent || link.getAttribute("aria-label") || "").length;
    }, 0);
    var linkDensity = text.length > 0 ? linkText / text.length : 0;
    var articlePath = articleLikePath();

    if (legalTableOfContentsPage(root, text)) return false;
    if (legalJudgmentArticleContent(root, text) || legalStatuteArticleContent(root, text)) return true;
    if (!likelyListPath() && text.length >= 280 && linkDensity < 0.5) return true;
    if (likelyListPath() && linkDensity > 0.5) return false;
    if (likelyListPath() && headings >= 5 && headings >= paragraphs * 0.6) return false;

    if (text.length < 280) return false;
    if (paragraphs < 3 && headings < 1 && !articlePath) return false;
    if (listLinks.length >= 8 && paragraphs < 5) return false;
    if (linkDensity > 0.33 && paragraphs < 6) return false;

    return (articlePath && text.length >= 280 && linkDensity < 0.5) || paragraphs >= 5 || (content.readerMode && paragraphs >= 3 && linkDensity < 0.28);
  }

  function referenceTableArticleMarkdown(markdown) {
    markdown = String(markdown || "");
    var text = normalizeText(markdown);
    if (text.length < 700 || !/^\|\s*[-: ]+\|/m.test(markdown)) return false;
    if ((markdown.match(/^\s*- \[/gm) || []).length >= 3) return false;

    var proseBlocks = markdown.split(/\n{2,}/).filter(function(block) {
      var trimmed = block.trim();
      if (!trimmed || /^\|/.test(trimmed) || /^#/.test(trimmed)) return false;
      return normalizeText(trimmed).length >= 80 && /[.!?)]$/.test(normalizeText(trimmed));
    }).length;
    var tableRows = (markdown.match(/^\|/gm) || []).length;
    var headings = (markdown.match(/^#{1,3}\s+/gm) || []).length;

    return headings >= 1 && proseBlocks >= 2 && tableRows >= 4 && tableRows <= 40;
  }

  function legalJudgmentArticleContent(root, text) {
    text = normalizeText(text || "");
    if (text.length < 5000) return false;

    if (/\bresults?\s+\d+\s*[-–]\s*\d+\s+(?:of|sur|von|de)\s+\d+\b/i.test(text)) return false;
    if (root && root.querySelector("[class*='result' i], [id*='result' i]")) return false;

    var signals = 0;
    if (/\b(?:high court|supreme court|court of appeal|federal court|district court|court of justice|tribunal)\b/i.test(text)) signals += 1;
    if (/\b(?:judg(?:e)?ment|opinion of the court|reasons for judgment|delivered by|per curiam)\b/i.test(text)) signals += 1;
    if (/\b(?:appellant|respondent|plaintiff|defendant|petitioner|counsel|solicitor|amicus|certiorari)\b/i.test(text)) signals += 1;
    if (/\b[A-Z][A-Za-z'.-]+\s+v\.?\s+[A-Z][A-Za-z'.-]+\b/.test(text)) signals += 1;
    if (/\[[12][0-9]{3}\]\s+[A-Z][A-Z0-9.]{1,12}\s+\d+|\([12][0-9]{3}\)\s+\d+\s+[A-Z][A-Z0-9.]{1,12}\s+\d+/i.test(text)) signals += 1;
    if (signals < 3) return false;

    var longBlocks = root ? Array.prototype.filter.call(root.querySelectorAll("p, div, section, article, pre, blockquote"), function(node) {
      return normalizeText(node.textContent || "").length >= 180;
    }).length : 0;
    var sentenceRuns = (text.match(/[.;:]\s+[A-Z][a-z]{2,}/g) || []).length;

    return longBlocks >= 5 || sentenceRuns >= 35 || text.length >= 20000;
  }

  function legalStatuteArticleContent(root, text) {
    text = normalizeText(text || "");
    if (text.length < 5000) return false;

    if (/\bresults?\s+\d+\s*[-–]\s*\d+\s+(?:of|sur|von|de)\s+\d+\b/i.test(text)) return false;
    if (root && root.querySelector("[class*='result' i], [id*='result' i]")) return false;

    var legalContext = legalProvisionContext({
      root: root,
      text: text,
      title: document.title || "",
      path: location.pathname || ""
    });

    if (!legalContext.legalTitle || legalContext.provisionMarkers < 8) return false;

    var longBlocks = root ? Array.prototype.filter.call(root.querySelectorAll("p, div, section, article, td, pre, blockquote"), function(node) {
      return normalizeText(node.textContent || "").length >= 180;
    }).length : 0;

    return legalContext.structuralMarkers >= 3 || legalContext.legalTerms || longBlocks >= 8 || text.length >= 20000;
  }

  function legalTableOfContentsPage(root, text) {
    root = root || document.body;
    text = normalizeText(text || (root && root.textContent) || "");
    if (!root || text.length < 200) return false;

    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    var title = normalizeText([document.title || "", (document.querySelector("h1") || {}).textContent || ""].join(" "));
    var context = normalizeText([path, title, text.slice(0, 1200)].join(" ")).toLowerCase();
    var tocRoute = /\/(?:contents?|table-of-contents|toc)(?:\/)?$/i.test(path);
    var tocRoot = root.querySelector(".LegContents, .LegContentsEntry, [class*='contents' i], [id*='contents' i], [aria-label*='contents' i]");
    var sectionLinks = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
      var href = link.getAttribute("href") || "";
      var label = normalizeText(link.textContent || "");
      return /\/(?:section|article|schedule|part|chapter)\/[^\s#?]+/i.test(href) ||
        /\b(?:section|article|schedule|part|chapter)\s+(?:\d+[a-z]?|[ivxlcdm]+)\b/i.test(label);
    }).length;
    var proseBlocks = Array.prototype.filter.call(root.querySelectorAll("p"), function(paragraph) {
      return normalizeText(paragraph.textContent || "").length >= 160;
    }).length;

    if (!tocRoute && !tocRoot && !/\b(?:table of contents|contents|collapse all)\b/i.test(context)) return false;
    if (!/\b(?:act|code|law|regulation|ordinance|statute|legislation|convention|treaty|schedule)\b/i.test(context)) return false;

    return sectionLinks >= 6 && proseBlocks < 4;
  }

  function legalTableOfContentsMarkdown(markdown) {
    var text = normalizeText(markdown || "");
    if (text.length < 200) return false;

    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    var tocRoute = /\/(?:contents?|table-of-contents|toc)(?:\/)?$/i.test(path);
    var linkedItems = (String(markdown || "").match(/^\s*[-*]\s+(?:\[[^\]]+\]\([^)]*\)|(?:\d+[A-Z]?\.|Article\s+\d+|Schedule\s+\d+))/gim) || []).length;
    var proseLines = String(markdown || "").split(/\n+/).filter(function(line) {
      var lineText = normalizeText(line).replace(/^[-*#\s]+/, "");
      return lineText.length >= 160 && !/^\[[^\]]+\]\(/.test(lineText);
    }).length;

    return tocRoute && linkedItems >= 6 && proseLines < 4;
  }

  function strongArticleMetadata(metadata, content) {
    metadata = metadata || {};
    content = content || {};

    var title = normalizeText(content.title || metadata.title || "");
    var excerpt = normalizeText(content.excerpt || metadata.excerpt || "");
    var publishedTime = normalizeText(content.publishedTime || metadata.publishedTime || "");
    var byline = normalizeText(content.byline || metadata.byline || "");
    var text = normalizeText(content.textContent || content.markdown || "");

    if (title.length < minimumListTitleLength(title) || text.length < 220) return false;
    if (publishedTime && excerpt.length >= 40) return true;
    if (publishedTime && byline) return true;
    return !!(publishedTime && text.length >= 320);
  }

  function likelyListPath() {
    var path = (location.pathname || "").toLowerCase();
    var segments = path.split("/").filter(Boolean);
    var last = segments[segments.length - 1] || "";

    if (!segments.length) return true;
    if (/^\/(index|default|home)\b/i.test(path) || /^\/\d+(,\d+)*\.html?$/i.test(path)) return true;
    if (/\/(search|category|categories|tag|tags|topics?|collections?|archive|archives|latest|headlines|news|notizie|calciomercato|mercato|forums?|boards?|community|discussions?|threads)\/?$/.test(path)) return true;
    if (segments.length <= 2 && !/\d{4}[-/]\d{2}[-/]\d{2}/.test(path) && !/-/.test(last) && !/\.(html?|php|aspx?|jsp|shtml)$/i.test(last)) return true;
    return false;
  }

  function opaqueDetailPath() {
    return opaqueDetailIdPath((location.pathname || "").toLowerCase().split("/").filter(Boolean));
  }

  function opaqueDetailIdPath(segments) {
    if (!segments || segments.length !== 2) return false;

    var first = segments[0] || "";
    var last = segments[1] || "";
    if (/^(search|category|categories|tag|tags|topics?|collections?|archive|archives|latest|headlines|news|forums?|boards?|community|discussions?|threads)$/.test(first)) return false;
    return last.length >= 6 && /[a-z]/i.test(last) && /\d/.test(last) && /^[a-z0-9_-]+$/.test(last);
  }

  function queryOrCategoryPage() {
    var path = (location.pathname || "").toLowerCase();
    var query = (location.search || "").toLowerCase();
    return /(?:^|[?&])(q|query|search|searchtext|keyword|k)=/.test(query) ||
      /\/(search|s|shop|browse|category|categories|collections?|catalog|keyword|wholesale|products?|jobs?)\b/.test(path) ||
      /\b(category|categories|collection|catalog|search results?|shop|jobs?\s+(?:in|matching|for)|job results?)\b/i.test(document.title || "");
  }

  function articleLikePath() {
    return /\/(20\d{2}|\d{4}\/\d{2}\/\d{2}|article|articles|blog|blogs|column|columns|archive|archives|news\/[\w-]+|entry|entries|post|posts|view\/[A-Z]{3}\d{15,}|\d{5,}[\w-]*\.html?)\b/i.test(location.pathname || "");
  }

  function articleEntryPath(path) {
    return /\/(?:20\d{2}|\d{4}\/\d{2}|[a-z0-9-]+\/\d{5,}(?:\/|$)|\d{5,}(?:\/|$)|[^\/]+-[^\/]+-[^\/]+)/i.test(path || "");
  }

  function looksLikeFooterLink(text, href) {
    return /^(privacy|cookies?|terms|chi siamo|about us|contact|contatti|redazione|advertising|newsletter|subscribe|login|sign in|register|cookie settings|manage preferences)$/i.test(text) ||
      /\/(privacy|cookie|cookies|terms|about|contatti|contact|redazione|login|register)\b/i.test(href || "");
  }

  function currentListPageUrl() {
    return location.origin + location.pathname;
  }

  function tokenizeListText(text) {
    return safeDecodeURI(text || "").toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").split(/\s+/).filter(Boolean);
  }

  function listPageContext(metadata) {
    metadata = metadata || {};

    var heading = document.querySelector("main h1, [role='main'] h1, h1");
    var siteTokens = tokenizeListText((metadata.siteName || location.hostname || "").replace(/^www\./i, ""));
    var generic = /^(latest|news|article|articles|articlelist|story|stories|home|homepage|index|default|today|more|page|pages|section|sections|category|categories|topic|topics|read|view|photo|photos|video|videos|gallery|galleries|live|blog|blogs|web|english|telugu|samayam|newsweb|edition)$/;
    var tokens = tokenizeListText([
      location.pathname || "",
      metadata.title || "",
      document.title || "",
      heading ? heading.textContent : ""
    ].join(" ")).filter(function(token) {
      return token.length >= 3 && !/^\d+$/.test(token) && !generic.test(token) && siteTokens.indexOf(token) === -1;
    });

    var keywords = [];
    tokens.forEach(function(token) {
      if (keywords.indexOf(token) === -1 && keywords.length < 12) keywords.push(token);
    });

    var sectionFragments = [];
    (location.pathname || "").split("/").filter(Boolean).forEach(function(segment) {
      var value = safeDecodeURI(segment || "").toLowerCase();
      if (!value || /^\d/.test(value) || /\.(html?|php|aspx?|jsp|cms)$/i.test(value)) return;
      if (/^(news|latest-news|latest|articlelist|articles?|read|view|topic|topics|section|sections|home|index|default|world|india-news|international-news|english|telugu)$/.test(value)) return;
      if (sectionFragments.indexOf(value) === -1) sectionFragments.push(value);
    });

    return {
      currentUrl: currentListPageUrl(),
      keywords: keywords,
      sectionFragments: sectionFragments.slice(0, 4)
    };
  }

  function listNoiseText(text) {
    text = normalizeText(text || "").toLowerCase();
    if (!text) return false;

    return /(trending topics|latest videos|latest photos|లేటెస్ట్ వీడియోలు|లేటెస్ట్ ఫోటోలు|video gallery|photo gallery|web stories|most read|best gelezen|newsletter|subscribe|abonneren|log in|login|sign in|register|create account|maak een account|u bent niet|settings|instellingen|tip ons|nieuwstip|belangrijke informatie delen|copyright|all rights reserved|privacy preference center|manage cookie preferences|manage consent preferences|manage privacy preferences|your privacy settings|your privacy choices|cookie list|cookie information|list of partners \(vendors\)|this website uses cookies|by accepting cookies|cookie declaration last updated|consent id|change your consent|your current state|vsak dan|poglej več|mark forums? read|forum statistics|members online|who is online|users browsing|forum rules|new posts since last visit|currently active users|forum contains no new|board statistics|mark all forums? read|what's going on|users online|active threads|active users)/i.test(text) || (/\b\d{1,2}\.\d{2}\b/.test(text) && /(vsak dan|sezona|oddaja|epizoda|premiera)/i.test(text));
  }

  function weatherModuleText(text) {
    var normalized = normalizeText(text || "");
    if (!normalized) return false;
    if (!/(ve[ðd]ursp[áa]( næsta s[óo]larhring)?|weather forecast|uppl[ýy]singar um ve[ðd]ur)/i.test(normalized)) return false;
    var hits = normalized.match(/\b(ve[ðd]ursp[áa]|hiti|[úu]rkoma|vindur|frost|rigning|sk[ýy]ja[ðd]|temperature|precipitation|wind|rain|snow|storm)\b/ig) || [];
    return hits.length >= 3;
  }

  function listNoiseNode(node) {
    if (!node || node.nodeType !== 1) return false;

    var attrs = normalizeText([
      node.getAttribute("id"),
      node.getAttribute("class"),
      node.getAttribute("role"),
      node.getAttribute("aria-label"),
      node.getAttribute("data-testid")
    ].join(" ")).toLowerCase();
    var text = normalizeText(node.textContent || "").slice(0, 280);

    return /(trending|popular|most-read|mostread|video|videos|photo|photos|gallery|galleries|web.?stor|newsletter|subscribe|social|share|follow|language|edition|top[_-]?nav|secondary-navbar|first-level-menu|second-level-menu|header-menu|side-nav|top-trending|wdt-trending|recommended|related|login|signup|register|account|forum[_-]?stats|online[_-]?users|who[_-]?is[_-]?online|board[_-]?stats|members[_-]?online|active[_-]?users|forum[_-]?rules|quick[_-]?reply|new[_-]?thread|moderator[_-]?panel|subforum[_-]?list)/.test(attrs) || listNoiseText(text);
  }

  function listContextMatchInfo(text, url, detail, context) {
    var path = "";
    var combined = (text + " " + (detail || "")).toLowerCase();
    var keywordMatches = 0;
    var sectionMatches = 0;

    try {
      path = new URL(url, location.href).pathname.toLowerCase();
    } catch (_error) {
      path = "";
    }

    context.keywords.forEach(function(token) {
      if ((combined + " " + path).indexOf(token) !== -1) keywordMatches += 1;
    });

    context.sectionFragments.forEach(function(fragment) {
      if (path.indexOf(fragment) !== -1) sectionMatches += 1;
    });

    return {
      path: path,
      keywordMatches: keywordMatches,
      sectionMatches: sectionMatches
    };
  }

  function listCandidateScore(text, url, detail, container, context) {
    if (!url) return -Infinity;

    var score = text.length;
    var matchInfo = listContextMatchInfo(text, url, detail, context);
    var path = matchInfo.path;

    if ((location.origin + path) === context.currentUrl) return -Infinity;
    if (container && container.matches("article, section, li")) score += 120;

    var heading = container && container.querySelector("h1, h2, h3, h4");
    if (heading && normalizeText(heading.textContent || "") === text) score += 180;

    score += matchInfo.keywordMatches * 70;
    score += matchInfo.sectionMatches * 220;

    if (listNoiseNode(container) || listNoiseNode(container && container.parentElement)) score -= 260;
    if (listNoiseText(text) || listNoiseText(detail)) score -= 220;

    return score;
  }

  function listLinkCandidate(link, container, context) {
    if (!link) return null;

    var href = link.getAttribute("href");
    var heading = link.querySelector("h1, h2, h3, h4");
    var text = normalizeText((heading && heading.textContent) || link.textContent || link.getAttribute("aria-label") || "");
    var resolvedPath = "";
    var weatherPage = /(weather|forecast|ve[ðd]ur|vedur|meteo)/i.test((location.pathname || "") + " " + document.title);
    if (!href || href[0] === "#" || /^(javascript:|mailto:)/i.test(href)) return null;
    if (text.length < minimumListTitleLength(text) || text.length > 220) return null;

    var url = absoluteUrl(href);
    if (!url) return null;
    try {
      resolvedPath = new URL(url, location.href).pathname;
    } catch (_error) {
      return null;
    }
    if ((location.origin + resolvedPath) === context.currentUrl) return null;
    if (/^(comments?|discuss|hide|more|abonneren|subscribe|newsletter|login|log in|sign in|register|create account|maak een account|instellingen|settings|account|last post|first unread|go to last post|mark read|mark forum read|watch forum|new thread|post new thread|post reply|quick reply|forum rules|forum actions|forum tools)$/i.test(text)) return null;
    if (/\/(subscribe|subscription|abonnement|login|register|newsletter|account|instellingen|settings)\b/i.test(url)) return null;
    if (/\/(privacycontrols?|privacy|cookies?|consent)\b/i.test(url) && text.length < 80) return null;
    if (looksLikeFooterLink(text, href) || listChromeNode(link) || listChromeNode(link.parentElement) || listChromeAncestor(link)) return null;

    var detailSource = link.querySelector("h1, h2, h3, h4, p") ? link : container;
    var detail = normalizeText(((detailSource && detailSource.textContent) || "")).replace(text, "").replace(/\s*[|·]\s*/g, " - ");
    detail = detail.replace(/\b(last post|first unread|go to last post|mark read|mark forum read|watch forum|new thread|post new thread|post reply|quick reply|forum rules|forum actions|forum tools)\b/gi, "").replace(/\s{2,}/g, " ").trim();
    if (detail.length > 420) detail = detail.slice(0, 417).replace(/\s+\S*$/, "") + "...";
    if (!weatherPage && /\/(ve[ðd]ur|vedur|forecast|weather|spastod)\b/i.test(url) && weatherModuleText(text + " " + detail)) return null;
    if (/\/(tv|spored)\//i.test(url) && (/(vsak dan|poglej več|sezona|epizoda|oddaja)/i.test(text + " " + detail) || /\b\d{1,2}\.\d{2}\b/.test(text + " " + detail))) return null;
    var score = listCandidateScore(text, url, detail, container || link.parentElement, context);
    if (score === -Infinity) return null;

    return { text: text, url: url, detail: detail, score: score };
  }

  function listAncestorOfType(link, nodeChecker) {
    var node = link && link.parentElement;

    while (node && node !== document.body) {
      if (node.matches && node.matches("article, li, main, [role='main']")) return null;
      if (node.matches && node.matches("header") && link.closest("article, section, main, [role='main']")) {
        node = node.parentElement;
        continue;
      }
      if (nodeChecker(node)) return node;
      node = node.parentElement;
    }

    return null;
  }

  function listChromeAncestor(link) {
    return listAncestorOfType(link, listChromeNode);
  }

  function listNavigationAncestor(link) {
    return listAncestorOfType(link, listNavigationNode);
  }

  function listChromeOrNavigationNode(node, includeSocial) {
    if (!node || node.nodeType !== 1) return false;
    if (node.matches("nav, header, footer, menu, [role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='banner'], [role='contentinfo']")) return true;

    var attrs = normalizeText([
      node.getAttribute("id"),
      node.getAttribute("class"),
      node.getAttribute("role"),
      node.getAttribute("aria-label"),
      node.getAttribute("data-testid")
    ].join(" ")).toLowerCase();

    if (!attrs) return false;
    if (/(news|headline|story|article|post|feed|stream|content|result|listing|archive|topic|thread|discussion|feature)/.test(attrs)) return false;
    if (includeSocial) return /(nav|menu|menubar|navbar|breadcrumb|breadcrumbs|pager|pagination|footer|header|toolbar|sidebar|drawer|utility|meta|social|share|follow|account|login|signup|register)/.test(attrs);
    return /(nav|menu|menubar|navbar|breadcrumb|breadcrumbs|pager|pagination|footer|header|toolbar|sidebar|drawer)/.test(attrs);
  }

  function listChromeNode(node) {
    return listChromeOrNavigationNode(node, true);
  }

  function listNavigationNode(node) {
    return listChromeOrNavigationNode(node, false);
  }

  function scoreListContainer(node, context) {
    if (listChromeNode(node) || listNoiseNode(node)) return -Infinity;

    var links = node.querySelectorAll("a[href]").length;
    var items = node.querySelectorAll("li, tr, article, section").length;
    var cards = node.querySelectorAll("article, section, [class*='card'], [class*='item'], [class*='story'], [class*='post'], [class*='news'], [class*='headline'], [class*='feed'], [class*='thread'], [class*='topic'], .structItem, .discussionListItem").length;
    var headings = node.querySelectorAll("h2, h3, h4").length;
    var headlineLinks = Array.prototype.filter.call(node.querySelectorAll("a[href]"), function(link) {
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      return text.length >= minimumListTitleLength(text) && !looksLikeFooterLink(text, link.getAttribute("href") || "") && !listChromeNode(link.parentElement) && !listChromeNode(link.closest("div, section, article, li"));
    }).length;
    var text = textLength(node);
    if (headlineLinks < 4 || text < 120) return -Infinity;
    if (/copyright|all rights reserved|privacy policy|terms of use/i.test(normalizeText(node.textContent || "")) && headings < 2) return -Infinity;

    var contextBonus = 0;
    if (context && (context.sectionFragments.length || context.keywords.length)) {
      Array.prototype.slice.call(node.querySelectorAll("a[href]"), 0, 80).forEach(function(link) {
        var title = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        if (title.length < minimumListTitleLength(title)) return;

        var url = absoluteUrl(link.getAttribute("href"));
        if (!url) return;

        var matchInfo = listContextMatchInfo(title, url, "", context);
        contextBonus += (matchInfo.sectionMatches * 140) + (matchInfo.keywordMatches * 30);
      });
    }

    return (links * 10) + (headlineLinks * 30) + (items * 20) + (cards * 45) + (headings * 20) + contextBonus - Math.round(text / 40);
  }

  function listCandidateRoot(metadata) {
    var context = listPageContext(metadata);
    var selectors = ["main", "[role='main']", ".itemlist", "table", "ol", "ul", ".posts", ".stories", ".items", ".news", ".feed", ".headlines", ".view-case-listing", "[class*='case-listing' i]", "[class*='record-listing' i]", "[class*='news']", "[class*='feed']", "[class*='headline']", ".threads", ".topic-list", ".forumlist", ".discussionList", "[class*='threadlist']", "[class*='thread-list']", "[class*='topic-list']", "body"];
    var candidates = [];

    selectors.forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(node) {
        candidates.push(node);
      });
    });

    var best = candidates.reduce(function(current, node) {
      var score = scoreListContainer(node, context);
      if (!current || score > current.score) return { node: node, score: score };
      return current;
    }, null);

    return best && best.score > -Infinity ? best.node : document.body;
  }

  function contextualListCandidates(metadata) {
    var context = listPageContext(metadata);
    var candidates = [];

    if (!context.sectionFragments.length && !context.keywords.length) return candidates;

    function push(node) {
      if (!node || node === document.body || node === document.documentElement || candidates.indexOf(node) !== -1) return;
      if (listChromeNode(node) || listNoiseNode(node)) return;

      var links = node.querySelectorAll("a[href]").length;
      if (links < 3 || links > 250) return;
      if (textLength(node) < 140) return;

      candidates.push(node);
    }

    Array.prototype.forEach.call(document.querySelectorAll("a[href]"), function(link) {
      var container = link.closest("article, section, div, li, ul, ol, main") || link.parentElement;
      var candidate = listLinkCandidate(link, container, context);
      if (!candidate) return;
      if (candidate.score < 260) return;

      var node = container;
      var depth = 0;
      while (node && depth < 4) {
        push(node);
        if (node.matches && node.matches("main, [role='main']")) break;
        node = node.parentElement;
        depth += 1;
      }
    });

    return candidates;
  }
