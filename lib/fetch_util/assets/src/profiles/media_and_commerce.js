  function mediaPlayerProfileData() {
    var video = structuredDataNode(["VideoObject", "Clip", "Movie", "TVEpisode"]);
    var data = {
      title: video && (video.name || video.headline),
      description: video && video.description,
      byline: video && (video.author || video.publisher),
      publishedTime: video && (video.uploadDate || video.datePublished),
      duration: video && video.duration,
      views: null
    };

    var yt = global.ytInitialPlayerResponse;
    var details = yt && yt.videoDetails;
    var microformat = yt && yt.microformat && yt.microformat.playerMicroformatRenderer;
    if (details) {
      data.title = data.title || details.title;
      data.description = data.description || details.shortDescription;
      data.byline = data.byline || details.author;
      data.views = data.views || details.viewCount;
    }
    if (microformat) {
      data.byline = data.byline || microformat.ownerChannelName;
      data.publishedTime = data.publishedTime || microformat.publishDate || microformat.uploadDate;
    }

    return data;
  }

  function mediaPageTitle(metadata, profile) {
    var title = normalizeText(profile.title || "");
    var headings = manyTexts(["main h1", "article h1", "h1"], 6).filter(function(text) {
      return !/^(loading|this video is processing|verify to continue|checking if the site connection is secure)/i.test(text);
    });

    if (!title && headings.length) title = headings[0];
    if (!title) title = normalizeText(metadata.title || document.title);

    return title.replace(/\s*[-|]\s*(YouTube|Vimeo|Videos & Movies on Vimeo)$/i, "");
  }

  function mediaPageDescription(metadata, profile) {
    var description = normalizeText(profile.description || metadata.excerpt || "");
    if (description) return description;

    var candidates = manyTexts([
      "#description-inline-expander",
      "ytd-expandable-video-description-body-renderer",
      "#description.ytd-watch-metadata",
      "#description",
      "[data-testid='vd-wrapper'] p",
      "main article p",
      "main p"
    ], 12);

    return candidates.find(function(text) {
      if (text.length < 30) return false;
      return !/^(loading|you'll be able to view it as soon as it's done|verify to continue|checking if the site connection is secure)/i.test(text);
    }) || null;
  }

  function mediaWatchContent(metadata) {
    var profile = mediaPlayerProfileData();
    var ogType = normalizeText(metadataValue("og:type", "property") || "").toLowerCase();
    var playerData = !!(global.ytInitialPlayerResponse && global.ytInitialPlayerResponse.videoDetails);
    var videoEmbed = !!(metadata.video || /^video\b/.test(ogType));
    var videoPath = /\/(watch|shorts|live|videos?|player|clip|replay)\b/i.test(location.pathname || "");
    var visiblePlayer = !!document.querySelector("video, iframe[src*='youtube'], iframe[src*='youtu.be'], iframe[src*='vimeo'], [data-video-id], [data-video], [data-player]");
    var videoSignal = !!(
      playerData ||
      videoEmbed ||
      (videoPath && visiblePlayer)
    );
    var watchShape = videoPath || playerData || videoEmbed;

    if (!videoSignal || !watchShape) return null;

    var title = mediaPageTitle(metadata, profile);
    var description = mediaPageDescription(metadata, profile);
    var byline = entityName(profile.byline) || metadata.byline;
    var publishedTime = entityText(profile.publishedTime) || firstText(["time[datetime]"], "datetime") || metadata.publishedTime;
    var details = [];
    var duration = entityText(profile.duration);
    var views = entityText(profile.views);

    if (duration) details.push("Duration: " + duration);
    if (views) details.push("Views: " + views);
    if (!title || !description) return null;

    return articleContentFromParts({
      title: title,
      byline: byline,
      publishedTime: publishedTime,
      description: description,
      details: details,
      siteName: metadata.siteName || location.hostname,
      hostAware: true
    });
  }

  function youtubeContent(metadata) {
    if (!hostMatches(/(^|\.)(youtube\.com|youtu\.be)$/)) return null;
    if (!(queryParam("v") || /^\/(watch|shorts|live)\b/.test(location.pathname))) return null;

    var media = mediaWatchContent(metadata);
    if (media) return media;

    var video = structuredDataNode(["VideoObject"]);
    var title = normalizeText((video && (video.name || video.headline)) || metadata.title).replace(/\s*[-|]\s*YouTube$/i, "");
    var description = firstText([
      "#description-inline-expander",
      "ytd-expandable-video-description-body-renderer",
      "#description.ytd-watch-metadata",
      "#description"
    ]) || entityText(video && video.description) || metadata.excerpt;
    var byline = entityName(video && (video.author || video.publisher)) || metadata.byline;
    var publishedTime = entityText(video && (video.uploadDate || video.datePublished)) || metadata.publishedTime;
    var details = [];
    var chapters = manyTexts([
      "ytd-macro-markers-list-item-renderer h4",
      "ytd-macro-markers-list-item-renderer #title"
    ], 12);

    if (entityText(video && video.duration)) details.push("Duration: " + entityText(video.duration));
    if (chapters.length) details.push("Chapters: " + chapters.slice(0, 6).join(" | "));

    if (!title || !description) return null;

    return articleContentFromParts({
      title: title,
      byline: byline,
      publishedTime: publishedTime,
      description: description,
      details: details,
      siteName: metadata.siteName || "YouTube",
      hostAware: true
    });
  }

  function amazonSearchContent(metadata) {
    if (!hostMatches(/(^|\.)amazon\./)) return null;
    if (!(location.pathname === "/s" || queryParam("k"))) return null;

    var seen = {};
    var items = [];

    document.querySelectorAll("[data-component-type='s-search-result'], .s-result-item[data-asin]").forEach(function(node) {
      if (items.length >= 15) return;

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

    return listContentResult({
      title: metadata.title || document.title,
      excerpt: items[0].text,
      siteName: metadata.siteName || location.hostname,
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
    ], 10).filter(function(item) {
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
    var sections = manyTexts(["main h2"], 8).filter(function(text) {
      return text.length >= 5 && !/^(offers?)$/i.test(text);
    });
    var seen = {};
    var items = [];

    document.querySelectorAll("main a[href*='/searchresults.html'], main a[href*='/hotel/'], main a[href*='/apartments/'], main a[href*='/resorts/'], main a[href*='/villas/'], main a[href*='/homes/']").forEach(function(link) {
      if (items.length >= 10) return;

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
    if (sections.length) markdownParts.push(sections.slice(0, 6).map(function(text) { return "- " + text; }).join("\n"));
    if (items.length >= 3) markdownParts.push(listMarkdown(items));

    var markdown = markdownParts.filter(Boolean).join("\n\n").trim();

    return {
      title: title || metadata.title,
      byline: null,
      excerpt: description,
      siteName: metadata.siteName || "Booking.com",
      publishedTime: null,
      html: "",
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: items.length >= 3 ? "list" : "article"
    };
  }
