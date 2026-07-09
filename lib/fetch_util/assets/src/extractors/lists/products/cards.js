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
