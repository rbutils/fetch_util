  function lodgingStructuredNode() {
    return structuredDataNodes().find(function(node) {
      return nodeTypes(node).some(function(type) {
        return /(?:^|\/)(?:LodgingBusiness|Hotel|Motel|BedAndBreakfast|Resort|VacationRental|Accommodation|LodgingReservation)$/i.test(type);
      });
    }) || null;
  }

  function lodgingEntityText(value) {
    if (!value) return "";
    if (typeof value === "string") return normalizeText(value);
    if (Array.isArray(value)) return normalizeText(value.map(lodgingEntityText).filter(Boolean).join(", "));
    if (typeof value !== "object") return normalizeText(String(value));
    return normalizeText(value.name || value.text || value.description || value.value || "");
  }

  function lodgingAddressText(value) {
    if (!value) return "";
    if (typeof value === "string") return normalizeText(value);
    if (Array.isArray(value)) return normalizeText(value.map(lodgingAddressText).filter(Boolean).join("; "));
    if (typeof value !== "object") return "";

    var address = value.address || value;
    if (typeof address === "string") return normalizeText(address);
    return normalizeText([
      address.streetAddress,
      address.addressLocality,
      address.addressRegion,
      address.postalCode,
      lodgingEntityText(address.addressCountry)
    ].filter(Boolean).join(", ")) || lodgingEntityText(value);
  }

  function lodgingOfferPrice(value) {
    var offer = value && (value.offers || value.potentialAction && value.potentialAction.result);
    if (Array.isArray(offer)) offer = offer[0];
    return normalizedCommercePrice(
      offer && (offer.price || offer.minPrice || (offer.priceSpecification && offer.priceSpecification.price)),
      offer && (offer.priceCurrency || (offer.priceSpecification && offer.priceSpecification.priceCurrency))
    );
  }

  function lodgingRatingText(value) {
    var rating = value && (value.aggregateRating || value.reviewRating || value.rating || value.starRating);
    if (Array.isArray(rating)) rating = rating[0];
    var ratingValue = lodgingEntityText(rating && (rating.ratingValue || rating.value));
    var bestRating = lodgingEntityText(rating && rating.bestRating) || "5";
    var count = lodgingEntityText(rating && (rating.reviewCount || rating.ratingCount));
    if (!ratingValue) return "";
    return "Rating: " + ratingValue + "/" + bestRating + (count ? " from " + count + " reviews" : "");
  }

  function visibleLodgingPrice() {
    var selectors = [
      "[data-testid*='price' i]",
      "[class*='price' i]",
      "[aria-label*='price' i]",
      "[itemprop='price']",
      "meta[itemprop='price'][content]"
    ];
    var currency = firstText(["[itemprop='priceCurrency']", "meta[itemprop='priceCurrency'][content]"], "content");

    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = document.querySelectorAll(selectors[i]);
      for (var n = 0; n < nodes.length; n += 1) {
        var node = nodes[n];
        if (node.closest && node.closest("nav, footer, aside, [hidden], [aria-hidden='true']")) continue;
        var price = normalizedCommercePrice(node.getAttribute("content") || node.getAttribute("aria-label") || node.textContent, currency);
        if (price) return price;
      }
    }

    return "";
  }

  function visibleLodgingRating() {
    var selectors = [
      "[data-testid*='review-score' i]",
      "[data-testid*='rating' i]",
      "[aria-label*='rating' i]",
      "[aria-label*='stars' i]",
      "[class*='review-score' i]",
      "[class*='rating' i]"
    ];

    for (var i = 0; i < selectors.length; i += 1) {
      var node = document.querySelector(selectors[i]);
      var text = normalizeText(node && (node.getAttribute("aria-label") || node.textContent));
      var match = text.match(/\b(\d(?:\.\d+)?)\s*(?:out of|\/)?\s*(10|5)\b/i) || text.match(/\b(\d(?:\.\d+)?)\b/);
      if (match) return match[2] ? "Rating: " + match[1] + "/" + match[2] : "Rating: " + match[1];
    }

    return "";
  }

  function lodgingAmenityItems(root) {
    var items = [];
    var seen = {};
    var selector = [
      "[data-testid*='amenity' i] li",
      "[data-testid*='facility' i] li",
      "[data-testid*='facilities' i] li",
      "[class*='amenity' i] li",
      "[class*='facility' i] li",
      "[aria-label*='amenit' i] li",
      "[aria-label*='facilit' i] li"
    ].join(", ");

    Array.prototype.forEach.call((root || document).querySelectorAll(selector), function(node) {
      var text = normalizeText(node.textContent || "").replace(/\s*(additional charge|extra fee)$/i, "");
      if (!text || text.length > 90 || seen[text.toLowerCase()]) return;
      seen[text.toLowerCase()] = true;
      items.push(text);
    });

    return items.slice(0, 24);
  }

  function lodgingDescriptionMarkdown(root, structured) {
    var structuredDescription = lodgingEntityText(structured && structured.description);
    var descriptionRoot = (root || document).querySelector([
      "[data-testid='property-description']",
      "[data-testid*='description' i]",
      "[class*='description' i]",
      "[itemprop='description']"
    ].join(", "));

    if (!descriptionRoot && structuredDescription) return structuredDescription;
    if (!descriptionRoot) return "";

    var clone = cleanClone(descriptionRoot);
    cleanupAgentRoot(clone);
    removeAll(clone, "nav, header, footer, aside, form, script, style, noscript, button, [role='button']");
    var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
    return normalizeText(markdown).length >= 40 ? markdown : structuredDescription;
  }

  function likelyLodgingDetailPage(metadata, structured) {
    var context = normalizeText([location.hostname, location.pathname, document.title, metadata && metadata.title, metadataValue("og:type", "property")].join(" ")).toLowerCase();
    if (/\b\d+\s+(?:properties|hotels|stays)\s+found\b/i.test(context)) return false;
    if (/\/(?:searchresults|city|region|destination)\b/i.test(location.pathname || "")) return false;
    if (structured) return true;
    if (!/\b(hotel|lodging|accommodation|booking|airbnb|rooms?|stays?|resort|guest\s?house|hostel|apartment|villa|vacation rental)\b/.test(context)) return false;
    if (/\b(search|results?|destination|city|things to do|flights?|cars?|restaurants?)\b/.test(context) && !/\/rooms?\/|\/hotel\//i.test(location.pathname)) return false;

    var cueCount = 0;
    if (document.querySelector("[data-testid*='amenity' i], [data-testid*='facility' i], [class*='amenity' i], [class*='facility' i]")) cueCount += 1;
    if (document.querySelector("[data-testid*='review-score' i], [data-testid*='rating' i], [class*='review-score' i], [class*='rating' i]")) cueCount += 1;
    if (document.querySelector("[data-testid*='address' i], [class*='address' i], [itemprop='address']")) cueCount += 1;
    if (visibleLodgingPrice()) cueCount += 1;
    if (/\b(amenities|facilities|guest reviews|property highlights|hosted by|check-in|check-out|night|nights|entire home|private room)\b/i.test(normalizeText(document.body && document.body.textContent))) cueCount += 1;

    return cueCount >= 2;
  }

  function lodgingDetailPath() {
    return /\/(?:rooms?|hotel)\//i.test(location.pathname || "");
  }

  function lodgingShellContent(metadata) {
    if (!lodgingDetailPath()) return null;

    var title = normalizeText(metadata.title || document.title || "");
    var text = normalizeText(document.body && document.body.textContent);
    var genericShell = /\b(?:airbnb|booking\.com)\b/i.test(title) &&
      /\b(?:vacation rentals|beach houses|unique homes|largest selection of hotels|homes, and vacation rentals)\b/i.test(title + " " + text);
    var hasDetailCue = document.querySelector("[data-testid*='amenity' i], [data-testid*='facility' i], [data-testid*='review-score' i], [data-testid='property-description'], [itemprop='address']");
    if (!genericShell || hasDetailCue) return null;

    var markdown = "# " + title + "\n\nClient-rendered lodging detail shell; no property details were reachable in the loaded document.";
    return {
      title: title,
      byline: null,
      excerpt: "Client-rendered lodging detail shell; no property details were reachable.",
      siteName: metadata.siteName || location.hostname,
      publishedTime: null,
      html: document.body ? document.body.innerHTML : "",
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "interstitial",
      lodgingShell: true
    };
  }

  function lodgingContent(metadata) {
    var structured = lodgingStructuredNode();
    if (!likelyLodgingDetailPage(metadata, structured)) return lodgingShellContent(metadata);

    var root = document.querySelector("main, article, [role='main'], [data-testid='property-page'], [data-testid='pdp-container'], #site-content") || document.body;
    var name = lodgingEntityText(structured && (structured.name || structured.underName)) ||
      firstText(["main h1", "article h1", "h1", "[data-testid*='title' i]"]) ||
      metadata.title || document.title;
    var price = lodgingOfferPrice(structured) || productMetaPrice() || visibleLodgingPrice();
    var rating = lodgingRatingText(structured) || visibleLodgingRating();
    var address = lodgingAddressText((structured && (structured.address || structured.location)) || firstText(["[itemprop='address']", "[data-testid*='address' i]", "[class*='address' i]"]));
    var description = lodgingDescriptionMarkdown(root, structured);
    var amenities = lodgingAmenityItems(root);

    if (!name || (!description && !amenities.length && !price && !rating && !address)) return null;

    var details = [];
    if (price) details.push("Price: " + price);
    if (rating) details.push(rating);
    if (address) details.push("Address: " + address);

    var amenityMarkdown = amenities.length ? ["## Amenities", amenities.map(function(item) { return "- " + item; }).join("\n")].join("\n\n") : "";
    var markdown = [
      "# " + name,
      details.length ? details.map(function(detail) { return "- " + detail; }).join("\n") : null,
      description,
      amenityMarkdown
    ].filter(Boolean).join("\n\n").trim();

    return {
      title: name,
      name: name,
      price: price || null,
      rating: rating || null,
      address: address || null,
      description: description || null,
      byline: null,
      excerpt: description ? normalizeText(description) : amenities.slice(0, 6).join(", "),
      siteName: metadata.siteName || location.hostname,
      publishedTime: null,
      html: root ? root.innerHTML : "",
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "hotel"
    };
  }
