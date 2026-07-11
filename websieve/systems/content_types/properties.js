  function propertyListingNodes() {
    return structuredDataNodes().filter(function(node) {
      var types = nodeTypes(node).join(" ");
      return /(?:^|\s|\/)(Apartment|House|SingleFamilyResidence|Residence|Accommodation|RealEstateListing)(?:\s|$)/i.test(types);
    });
  }

  function propertyFirstEntityText(values) {
    for (var i = 0; i < values.length; i += 1) {
      var text = entityText(values[i]) || entityName(values[i]);
      if (text) return text;
    }
    return "";
  }

  function propertyAddressText(value) {
    return structuredPostalAddressText(value) || "";
  }

  function propertyOfferPrice(node) {
    var offer = node && (node.offers || node.offer);
    if (Array.isArray(offer)) offer = offer[0];
    var priceSpec = offer && offer.priceSpecification;
    return normalizedCommercePrice(
      offer && (offer.price || offer.lowPrice || (priceSpec && priceSpec.price)),
      offer && (offer.priceCurrency || (priceSpec && priceSpec.priceCurrency))
    );
  }

  function propertyNumber(value) {
    if (value === null || value === undefined) return null;
    if (Array.isArray(value)) return propertyNumber(value[0]);
    if (typeof value === "object") return propertyNumber(value.value || value.amount || value.name || value.text);
    var match = String(value).replace(/,/g, "").match(/\d+(?:\.\d+)?/);
    if (!match) return null;
    return Number(match[0]);
  }

  function propertyAreaSqft(value) {
    if (!value) return null;
    if (Array.isArray(value)) return propertyAreaSqft(value[0]);
    if (typeof value === "object") {
      var unit = normalizeText(value.unitCode || value.unitText || value.name || "").toLowerCase();
      var amount = propertyNumber(value.value || value.amount || value.minValue || value.maxValue || value.text);
      if (!amount) return null;
      if (/sq\s*ft|square\s*feet|ft2|ft²|sqft|ftk|sqf|sft|ft$/i.test(unit) || /FTK/i.test(value.unitCode || "")) return Math.round(amount);
      if (/sqm|sq\s*m|m2|m²|square\s*met/i.test(unit)) return Math.round(amount * 10.7639);
      return Math.round(amount);
    }
    return propertyNumber(value);
  }

  function visiblePropertyPrice(entity) {
    var selectors = [
      "[data-testid*='price' i]",
      "[class*='price' i]",
      "[id*='price' i]",
      "[aria-label*='price' i]"
    ];

    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = entity.querySelectorAll(selectors[i]);
      for (var n = 0; n < nodes.length; n += 1) {
        var node = nodes[n];
        if (node.closest && node.closest("nav, footer, aside, [hidden], [aria-hidden='true']")) continue;
        var price = normalizedCommercePrice(node.getAttribute("content") || node.getAttribute("aria-label") || node.textContent, "");
        if (price) return price;
      }
    }

    var text = normalizeText(entity.innerText || "");
    var match = text.match(/(?:[$£€]\s?\d[\d,]*(?:\.\d{2})?|\d[\d,]*\s?(?:USD|GBP|EUR))(?:\s*(?:pcm|pm|per month|monthly|pw|per week))?/i);
    return match ? normalizeText(match[0]).replace(/([$£€])\s+/g, "$1") : "";
  }

  function visiblePropertyNumber(entity, patterns) {
    var text = normalizeText(entity.innerText || "");
    for (var i = 0; i < patterns.length; i += 1) {
      var match = text.match(patterns[i]);
      if (match) return Number(match[1]);
    }
    return null;
  }

  function visiblePropertyLocation(entity, metadata) {
    var selectors = [
      "[data-testid*='address' i]",
      "[data-testid*='location' i]",
      "[class*='address' i]",
      "[class*='location' i]",
      "[itemprop='address']"
    ];

    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = entity.querySelectorAll(selectors[i]);
      for (var n = 0; n < nodes.length; n += 1) {
        var node = nodes[n];
        if (node.closest && node.closest("nav, footer, aside, [hidden], [aria-hidden='true']")) continue;
        var text = normalizeText(node.getAttribute("content") || node.getAttribute("aria-label") || node.textContent);
        if (text && text.length <= 220 && !/^<</.test(text) && !/[{}]/.test(text) && !/^(for sale|for rent|to rent|sold|let agreed|est\.)$/i.test(text) && !/[$£€]|\bsq\s*ft\b|\b\d+\s*(?:bd|ba)\b/i.test(text)) return text;
      }
    }

    var title = normalizeText((metadata && metadata.title) || document.title || "");
    var titleLocation = title.match(/\b(?:for sale|to rent|for rent)\s+in\s+([^|]+)/i);
    if (!titleLocation && /,\s*(?:[A-Z]{2}\b|[A-Z][a-z]+,)/.test(title) && !/[$£€]/.test(title)) titleLocation = title.match(/^([^|]+?)\s*(?:\||$)/);
    return titleLocation ? normalizeText(titleLocation[1]) : "";
  }

  function visiblePropertyAreaSqft(entity) {
    var text = normalizeText(entity.innerText || "");
    var match = text.match(/\b([\d,]+(?:\.\d+)?)\s*(?:sq\.?\s*ft|square\s*feet|sqft|ft²)\b/i);
    return match ? Math.round(Number(match[1].replace(/,/g, ""))) : null;
  }

  function propertyListingEvidence(content, metadata) {
    var nodes = propertyListingNodes();
    var node = nodes.find(function(item) {
      return entityName(item) || entityText(item.description) || propertyAddressText(item.address) || propertyOfferPrice(item);
    }) || null;

    var context = normalizeText([
      location.pathname,
      document.title,
      metadata && metadata.title,
      metadata && metadata.excerpt,
      metadataValue("og:type", "property")
    ].join(" ")).toLowerCase();
    var text = normalizeText((document.body && document.body.innerText) || "");
    var realEstateContext = /\b(property|properties|real[ -]?estate|house|apartment|condo|flat|bedrooms?|bathrooms?|sq\.?\s*ft|rightmove|redfin|zillow|realtor)\b/i.test(context + " " + text.slice(0, 3000));

    function focalPropertyEntity(item) {
      if (!item) return false;
      var name = normalizeText(entityName(item) || "").toLowerCase();
      var title = normalizeText(firstText(["main h1", "article h1", "h1"]) || metadata.title || document.title).toLowerCase();
      if (name && title && (name === title || name.indexOf(title) !== -1 || title.indexOf(name) !== -1)) return true;

      var itemUrl = item.url || item.mainEntityOfPage;
      if (!itemUrl) return false;
      try {
        var parsed = new URL(typeof itemUrl === "object" ? itemUrl.url : itemUrl, location.href);
        return parsed.origin === location.origin && parsed.pathname === location.pathname;
      } catch (_error) {
        return false;
      }
    }

    function visiblePropertyEntity(item) {
      var title = normalizeText(firstText(["main h1", "article h1", "h1"]) || "");
      var name = normalizeText(item && entityName(item) || "");
      if (!title || (name && title.toLowerCase() !== name.toLowerCase())) return null;
      var heading = document.querySelector("main h1, article h1, h1");
      if (!heading) return null;
      var entity = heading.closest("main, article, [itemscope], [data-testid*='property' i], [class*='property-detail' i]") || heading.parentElement;
      var text = normalizeText(entity && entity.innerText || "");
      return /\b(home|house|apartment|condo|flat|bedrooms?|bathrooms?|sq\.?\s*ft)\b/i.test(text) ? entity : null;
    }

    if (node && !focalPropertyEntity(node)) return null;
    if (!node && !/(\/property|\/properties|\/listing|for[-_]sale|for[-_]rent)/i.test(location.pathname)) return null;

    var visibleEntity = visiblePropertyEntity(node);
    if (!visibleEntity) return null;

    var price = (node && propertyOfferPrice(node)) || visiblePropertyPrice(visibleEntity);
    var locationText = (node && propertyAddressText(node.address || node.location)) || visiblePropertyLocation(visibleEntity, metadata);
    var bedrooms = propertyNumber(node && (node.numberOfBedrooms || node.bedrooms)) || visiblePropertyNumber(visibleEntity, [/\b(\d+(?:\.\d+)?)\s*(?:beds?|bedrooms?|bd)\b/i, /\b(\d+(?:\.\d+)?)\s*bed(?:room)?\s+(?:house|home|flat|apartment|property)\b/i]);
    var bathrooms = propertyNumber(node && (node.numberOfBathroomsTotal || node.numberOfBathrooms || node.bathrooms)) || visiblePropertyNumber(visibleEntity, [/\b(\d+(?:\.\d+)?)\s*(?:baths?|bathrooms?|ba)\b/i]);
    var areaSqft = propertyAreaSqft(node && (node.floorSize || node.area || node.size)) || visiblePropertyAreaSqft(visibleEntity);
    var evidenceCount = [node, price, locationText, bedrooms, bathrooms, areaSqft].filter(function(value) { return value !== null && value !== "" && value !== undefined; }).length;

    if (!node && !realEstateContext) return null;
    if (!price && evidenceCount < 3) return null;
    if (nodes.length > 3 && !/\b(property|listing|for sale|for rent|to rent)\b/i.test(context)) return null;

    return {
      title: entityName(node) || firstText(["main h1", "article h1", "h1"]) || metadata.title || document.title,
      excerpt: entityText(node && node.description) || metadata.excerpt,
      price: price || "",
      location: locationText || "",
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      areaSqft: areaSqft
    };
  }

  function applyPropertyListingContent(content, metadata) {
    if (!content || content.contentType === "job" || content.contentType === "search" || content.contentType === "interstitial" || content.docsLike || content.legalProvision) return content;
    if (typeof likelyLodgingDetailPage === "function" && typeof lodgingStructuredNode === "function" && likelyLodgingDetailPage(metadata, lodgingStructuredNode())) return content;

    var evidence = propertyListingEvidence(content, metadata);
    if (!evidence) return content;

    content.contentType = "property";
    if (evidence.title && (!content.title || normalizeText(content.title).length < normalizeText(evidence.title).length)) content.title = evidence.title;
    if (evidence.excerpt && !content.excerpt) content.excerpt = evidence.excerpt;
    if (evidence.price) content.price = evidence.price;
    if (evidence.location) content.location = evidence.location;
    if (evidence.bedrooms !== null && evidence.bedrooms !== undefined) content.bedrooms = evidence.bedrooms;
    if (evidence.bathrooms !== null && evidence.bathrooms !== undefined) content.bathrooms = evidence.bathrooms;
    if (evidence.areaSqft !== null && evidence.areaSqft !== undefined) content.areaSqft = evidence.areaSqft;

    var details = [];
    if (content.price) details.push("Price: " + content.price);
    if (content.location) details.push("Location: " + content.location);
    if (content.bedrooms !== null && content.bedrooms !== undefined) details.push("Bedrooms: " + content.bedrooms);
    if (content.bathrooms !== null && content.bathrooms !== undefined) details.push("Bathrooms: " + content.bathrooms);
    if (content.areaSqft !== null && content.areaSqft !== undefined) details.push("Area: " + content.areaSqft + " sqft");

    var body = cleanupMarkdownNoise(content.markdown || content.textContent || "");
    var detailMarkdown = details.map(function(detail) { return "- " + detail; }).join("\n");
    if (details.length && body.indexOf(details[0]) === -1) {
      content.markdown = ["# " + (content.title || metadata.title || document.title), detailMarkdown, body].filter(Boolean).join("\n\n");
      content.textContent = normalizeText(content.markdown);
    }

    return content;
  }
