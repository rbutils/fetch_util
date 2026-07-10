  function amazonSearchContent(metadata) {
    if (!hostMatches(/(^|\.)amazon\./)) return null;
    if (!(location.pathname === "/s" || queryParam("k"))) return null;

    var seen = {};
    var items = [];

    document.querySelectorAll("[data-component-type='s-search-result'], .s-result-item[data-asin]").forEach(function(node) {
      var link = node.querySelector("h2 a[href], a.a-link-normal.s-no-outline[href]");
      var titleNode = node.querySelector("h2 span, h2 a span");
      var title = normalizeText(titleNode ? titleNode.textContent : (link && link.textContent));
      var url = absoluteUrl(link && link.getAttribute("href"));
      var priceNode = node.querySelector(".a-price .a-offscreen");
      var price = normalizeText(priceNode && priceNode.textContent);
      var ratingNode = node.querySelector("[aria-label*='out of 5 stars'], .a-icon-alt");
      var rating = normalizeText(ratingNode && (ratingNode.getAttribute("aria-label") || ratingNode.textContent));
      var reviewsNode = node.querySelector("a[href*='#customerReviews'], .a-size-small .a-link-normal");
      var reviews = normalizeText(reviewsNode && reviewsNode.textContent);
      var detail = [price, rating, reviews].filter(Boolean).join(" - ");

      if (!title || !url || title.length < 8 || seen[url]) return;
      seen[url] = true;
      items.push({ text: title, url: url, detail: detail });
    });

    if (items.length < 3) return null;

    return listItemsContentResult(metadata, {
      title: metadata.title || document.title,
      excerpt: items[0].text,
      items: items
    });
  }

  function amazonProductContent(metadata) {
    if (!hostMatches(/(^|\.)amazon\./)) return null;
    if (!/(\/dp\/|\/gp\/product\/)/.test(location.pathname)) return null;

    var product = structuredDataNode(["Product", "Book"]);
    var title = firstText(["#productTitle", "#title span", "#ebooksProductTitle"]) || entityText(product && product.name) || metadata.title;
    var description = entityText(product && product.description) || metadata.excerpt || firstText([
      "#bookDescription_feature_div .a-expander-content",
      "#bookDescription_feature_div .a-expander-partial-collapse-content",
      "#productDescription p",
      "#productDescription"
    ]);
    var byline = firstText(["#bylineInfo", ".author a", "#brand"]);
    var highlights = manyTexts([
      "#feature-bullets li span",
      "#detailBullets_feature_div li span.a-list-item",
      "#productOverview_feature_div td"
    ]).filter(function(item) {
      return item.length >= 12 && item !== title && !/^see more$/i.test(item);
    });
    var details = [];
    var offer = product && product.offers;
    if (Array.isArray(offer)) offer = offer[0];
    var price = offer && offer.price ? normalizeText(offer.price + (offer.priceCurrency ? " " + offer.priceCurrency : "")) : null;
    if (price) details.push("Price: " + price);
    if (offer && offer.availability) details.push("Availability: " + humanizeValue(offer.availability));
    if (product && product.aggregateRating && product.aggregateRating.ratingValue) {
      var rating = normalizeText(product.aggregateRating.ratingValue + "/5");
      var reviews = product.aggregateRating.reviewCount || product.aggregateRating.ratingCount;
      details.push("Rating: " + rating + (reviews ? " from " + reviews + " reviews" : ""));
    }

    if (!title || !description) return null;

    return articleContentFromParts({
      title: normalizeText(title).replace(/: Amazon.*$/i, ""),
      byline: byline,
      description: description,
      details: details,
      highlights: highlights,
      siteName: metadata.siteName || location.hostname
    });
  }

  function bookingContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)booking\.com$/) && !/booking\.com/i.test(signature)) return null;
    if (location.pathname && location.pathname !== "/") return null;

    var title = firstText(["main h1", "h1"]) || normalizeText((metadata.title || document.title).replace(/^Booking\.com\s*[|:-]\s*/i, ""));
    var description = metadata.excerpt;
    var sections = manyTexts(["main h2"]).filter(function(text) {
      return text.length >= 5 && !/^(offers?)$/i.test(text);
    });
    var seen = {};
    var items = [];

    document.querySelectorAll("main a[href*='/searchresults.html'], main a[href*='/hotel/'], main a[href*='/apartments/'], main a[href*='/resorts/'], main a[href*='/villas/'], main a[href*='/homes/']").forEach(function(link) {
      var itemTitle = normalizeText(link.textContent);
      var url = absoluteUrl(link.getAttribute("href"));
      if (!itemTitle || !url || itemTitle.length < 3 || itemTitle.length > 80 || seen[url]) return;
      if (/^(learn more|search|sign in|register|list your property)$/i.test(itemTitle)) return;

      seen[url] = true;
      items.push({ text: itemTitle, url: url });
    });

    if (!title && !sections.length && items.length < 3) return null;

    var markdownParts = [];
    if (title) markdownParts.push("# " + title);
    if (description) markdownParts.push(description);
    if (sections.length) markdownParts.push(sections.map(function(text) { return "- " + text; }).join("\n"));
    if (items.length >= 3) markdownParts.push(listMarkdown(items));

    var markdown = markdownParts.filter(Boolean).join("\n\n").trim();

    return listItemsContentResult(metadata, {
      title: title || metadata.title,
      excerpt: description,
      siteName: metadata.siteName || "Booking.com",
      markdown: markdown,
      textContent: normalizeText(markdown),
      items: items.length >= 3 ? items : null,
      contentType: items.length >= 3 ? "list" : "article"
    });
  }

  function registerMediaCommerceLeadProfiles() {
    registerHostAwareProfile(true, mediaWatchContent);
    registerHostAwareProfile(true, youtubeContent);
    registerHostAwareProfile(true, amazonSearchContent);
    registerHostAwareProfile(true, amazonProductContent);
  }

  function registerBookingProfiles() {
    registerHostAwareProfile(true, bookingContent);
  }
