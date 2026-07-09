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
  function productOfferPrice(offer) {
    return normalizedCommercePrice(offer && (offer.price || (offer.priceSpecification && offer.priceSpecification.price)), offer && (offer.priceCurrency || (offer.priceSpecification && offer.priceSpecification.priceCurrency)));
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
    var price = productOfferPrice(offer);
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

  function productMetaPrice() {
    return normalizedCommercePrice(
      firstText([
        "meta[property='product:price:amount']",
        "meta[property='og:price:amount']",
        "meta[name='twitter:data1']",
        "meta[itemprop='price']"
      ], "content"),
      firstText([
        "meta[property='product:price:currency']",
        "meta[property='og:price:currency']",
        "meta[itemprop='priceCurrency']"
      ], "content")
    );
  }

  function visibleProductPrice() {
    var selectors = [
      "[itemprop='price']",
      "meta[itemprop='price'][content]",
      "[data-testid*='price' i]",
      "[class*='price' i]",
      "[id*='price' i]",
      "[aria-label*='price' i]"
    ];
    var currency = firstText(["[itemprop='priceCurrency']", "meta[itemprop='priceCurrency'][content]"], "content");

    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = document.querySelectorAll(selectors[i]);
      for (var n = 0; n < nodes.length; n += 1) {
        var node = nodes[n];
        if (node.closest && node.closest("nav, footer, aside, [hidden], [aria-hidden='true']")) continue;
        var value = node.getAttribute("content") || node.getAttribute("aria-label") || node.textContent;
        var price = normalizedCommercePrice(value, currency);
        if (price) return price;
      }
    }

    return "";
  }

  function productPageStructuredData() {
    return productStructuredDataItems().find(function(product) {
      var offer = productOffer(product);
      return commerceEntityText(product && product.name) || productOfferPrice(offer) || commerceEntityText(product && product.sku);
    }) || null;
  }

  function productPageEvidence() {
    var structuredProduct = productPageStructuredData();
    var offer = productOffer(structuredProduct);
    var price = productOfferPrice(offer) || productMetaPrice() || visibleProductPrice();
    var ogType = normalizeText(metadataValue("og:type", "property") || "").toLowerCase();
    var productMarkup = !!document.querySelector("[itemtype*='schema.org/Product' i], [typeof*='Product' i], [itemprop='sku'], [itemprop='gtin'], [itemprop='mpn']");
    var addToCart = !!document.querySelector("button[name*='add' i], button[id*='add-to-cart' i], button[class*='add-to-cart' i], button[data-testid*='add-to-cart' i], [aria-label*='add to cart' i], [aria-label*='add to bag' i]");
    var sku = firstText(["[itemprop='sku']", "[class*='sku' i]", "[data-testid*='sku' i]"]);
    var productOgType = /\bproduct\b/.test(ogType);
    var evidenceCount = [structuredProduct, productOgType, productMarkup, addToCart, sku, price].filter(Boolean).length;

    if (productStructuredDataItems().length > 1 && !productOgType && !addToCart && !sku) return null;
    if (!structuredProduct && !productOgType && !productMarkup && evidenceCount < 2) return null;
    if (!price && !addToCart && !sku && !productMarkup && !structuredProduct) return null;

    return {
      title: commerceEntityText(structuredProduct && structuredProduct.name),
      excerpt: commerceEntityText(structuredProduct && structuredProduct.description),
      price: price,
      availability: commerceEntityText(offer && offer.availability),
      sku: commerceEntityText((structuredProduct && (structuredProduct.sku || structuredProduct.mpn || structuredProduct.gtin13)) || sku)
    };
  }

  function applyProductPageContent(content, metadata) {
    if (!content || content.contentType === "list" || content.contentType === "search" || content.contentType === "interstitial" || content.docsLike || content.legalProvision) return content;

    var evidence = productPageEvidence();
    if (!evidence) return content;

    content.contentType = "product";
    if (evidence.title && (!content.title || normalizeText(content.title).length < evidence.title.length)) content.title = evidence.title;
    if (evidence.excerpt && !content.excerpt) content.excerpt = evidence.excerpt;
    if (evidence.price) content.price = evidence.price;
    if (evidence.availability) content.availability = humanizeCommerceAvailability(evidence.availability);
    if (evidence.sku) content.sku = evidence.sku;

    var details = [];
    if (content.price) details.push("Price: " + content.price);
    if (content.availability) details.push("Availability: " + content.availability);
    if (content.sku) details.push("SKU: " + content.sku);
    if (details.length && normalizeText(content.markdown || content.textContent || "").indexOf(details[0]) === -1) {
      var title = content.title || (metadata && metadata.title) || document.title;
      var body = normalizeText(content.markdown || content.textContent || "");
      content.markdown = ["# " + title, details.map(function(detail) { return "- " + detail; }).join("\n"), body].filter(Boolean).join("\n\n");
      content.textContent = normalizeText(content.markdown);
    }

    return content;
  }
