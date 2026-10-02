  function focalOwnershipVisibleMedia(root) {
    var mediaNodes = Array.prototype.filter.call(root.querySelectorAll("iframe[src], video"), function(media) {
      if (elementSubtreeHidden(media) || media.closest("nav, aside, footer, [role~='navigation' i], [role~='complementary' i], [role~='comment' i], [class*='comment' i], [id*='comment' i]")) return false;
      var rect = media.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0 && focalOwnershipMediaPrimaryUrl(media);
    });
    return mediaNodes.filter(function(media) {
      if (media.tagName === "VIDEO") return true;
      var source = focalOwnershipMediaPrimaryUrl(media);
      return /(?:video|embed)/i.test(new URL(source).pathname);
    });
  }

  function focalOwnershipMediaOwner(root, heading, media) {
    var owner = heading.parentElement;
    while (owner && owner !== root) {
      if (owner.contains(media)) return owner;
      owner = owner.parentElement;
    }
    return null;
  }

  function focalOwnershipMediaUrls(media) {
    var urls = [];
    function append(value) {
      var url = materializedHttpUrl(value || "");
      if (url) urls.push(url);
    }
    append(media.getAttribute("src"));
    if (media.tagName === "VIDEO") {
      append(media.getAttribute("poster"));
      Array.prototype.forEach.call(media.querySelectorAll("source[src], track[src], a[href]"), function(node) {
        append(node.getAttribute(node.matches("a[href]") ? "href" : "src"));
      });
    }
    return urls;
  }

  function focalOwnershipMediaPrimaryUrl(media) {
    var direct = materializedHttpUrl(media.getAttribute("src") || "");
    if (direct) return direct;
    var source = media.querySelector("source[src]");
    return source ? materializedHttpUrl(source.getAttribute("src") || "") : "";
  }

  function focalOwnershipMediaIdentityTokens(value) {
    var generic = new Set([
      "a", "an", "and", "at", "for", "from", "in", "of", "on", "the", "to", "vs",
      "article", "clip", "film", "game", "highlight", "live", "match", "news", "recap", "report", "replay", "story", "video", "watch",
      "dien", "lai", "ngay", "ra", "tran", "vua", "xem"
    ]);
    var unaccented = normalizeText(value || "").toLowerCase().normalize("NFD").replace(/\p{M}/gu, "");
    return Array.from(new Set((unaccented.match(/[\p{L}\p{N}]+/gu) || []).filter(function(token) {
      return token.length > 2 && !generic.has(token);
    })));
  }

  function focalOwnershipDateKey(value) {
    var text = normalizeText(value || "");
    var iso = text.match(/\b(\d{4})[./-](\d{1,2})[./-](\d{1,2})\b/);
    if (iso) return iso[1] + "-" + iso[2].padStart(2, "0") + "-" + iso[3].padStart(2, "0");
    var dmy = text.match(/\b(\d{1,2})[./-](\d{1,2})[./-](\d{4})\b/);
    return dmy ? dmy[3] + "-" + dmy[2].padStart(2, "0") + "-" + dmy[1].padStart(2, "0") : "";
  }

  function focalOwnershipHeadlineIdentityMatches(metadataHeadline, sourceHeadline, datePublished) {
    var metadataText = normalizeText(metadataHeadline || "");
    var sourceText = normalizeText(sourceHeadline || "");
    if (!metadataText || !sourceText) return false;
    if (metadataText === sourceText) return true;

    var metadataDates = metadataText.match(/\b(?:\d{4}[./-]\d{1,2}[./-]\d{1,2}|\d{1,2}[./-]\d{1,2}[./-]\d{4})\b/g) || [];
    var sourceDates = sourceText.match(/\b(?:\d{4}[./-]\d{1,2}[./-]\d{1,2}|\d{1,2}[./-]\d{1,2}[./-]\d{4})\b/g) || [];
    if ((metadataDates.length || sourceDates.length) &&
        (!metadataDates.length || !sourceDates.length || !metadataDates.some(function(date) { return sourceDates.indexOf(date) !== -1; }))) return false;
    var sourceDate = focalOwnershipDateKey(sourceText);
    var typedDate = focalOwnershipDateKey(datePublished);
    if (typedDate && sourceDate && typedDate !== sourceDate) return false;

    var left = focalOwnershipMediaIdentityTokens(metadataText);
    var right = focalOwnershipMediaIdentityTokens(sourceText);
    var shared = new Set(left.filter(function(token) { return right.indexOf(token) !== -1; }));
    return shared.size >= 4 && shared.size / left.length >= 0.75 && shared.size === right.length;
  }

  function focalOwnershipMediaArticle(metadata) {
    var typedArticles = metadata.typedArticles || [];
    if (typedArticles.length !== 1 || !typedArticles[0].headline) return null;
    var mains = Array.prototype.filter.call(document.querySelectorAll("main, [role~='main' i]"), function(main) {
      return !elementSubtreeHidden(main) && !main.closest("nav, aside, footer, [role~='navigation' i], [role~='complementary' i]");
    });
    mains = mains.filter(function(main) {
      return !mains.some(function(other) { return main !== other && other.contains(main); });
    });
    if (mains.length !== 1) return null;
    var main = mains[0];
    var visibleHeadings = Array.prototype.filter.call(document.querySelectorAll("h1"), function(heading) {
      return !elementVisuallyHidden(heading);
    });
    if (visibleHeadings.length !== 1 || !main.contains(visibleHeadings[0])) return null;
    var heading = visibleHeadings[0];
    var headingText = normalizeText(heading.textContent || "");
    if (!focalOwnershipHeadlineIdentityMatches(typedArticles[0].headline, headingText, typedArticles[0].datePublished)) return null;

    var owners = focalOwnershipVisibleMedia(main).map(function(media) {
      var owner = focalOwnershipMediaOwner(main, heading, media);
      if (!owner || owner === main || focalOwnershipVisibleMedia(owner).length !== 1 ||
          independentLinkedArticleCollection(owner)) return null;
      var ownerHeadings = Array.prototype.filter.call(owner.querySelectorAll("h1"), function(candidate) {
        return !elementVisuallyHidden(candidate);
      });
      if (ownerHeadings.length !== 1 || ownerHeadings[0] !== heading) return null;
      return { node: owner, media: media };
    }).filter(Boolean);
    if (owners.length !== 1) return null;

    var focalOwner = owners[0];
    var relatedCollection = focalOwnershipRelatedCollection(main, focalOwner.node);
    if (independentLinkedArticleCollection(main) && !relatedCollection) return null;
    if (!focalOwnershipPageMaterialIsAccountedFor(main, focalOwner.node, relatedCollection)) return null;
    return {
      node: focalOwner.node,
      pageRoot: main,
      heading: heading,
      title: typedArticles[0].headline,
      media: focalOwner.media,
      mediaUrl: focalOwnershipMediaPrimaryUrl(focalOwner.media),
      mediaUrls: focalOwnershipMediaUrls(focalOwner.media),
      relatedCollection: relatedCollection,
      proof: "same-owner-source-headline-and-media"
    };
  }

  function focalOwnershipPreserveMediaResources(root, sourceMedia) {
    if (!root || !sourceMedia) return;
    var sourceUrl = focalOwnershipMediaPrimaryUrl(sourceMedia);
    if (!sourceUrl) return;
    var media = Array.prototype.find.call(root.querySelectorAll("iframe[src], video"), function(node) {
      return focalOwnershipMediaPrimaryUrl(node) === sourceUrl;
    });
    if (media && sourceMedia.tagName === "VIDEO") {
      Array.prototype.slice.call(media.attributes || []).forEach(function(attribute) {
        if (!sourceMedia.hasAttribute(attribute.name)) media.removeAttribute(attribute.name);
      });
      Array.prototype.slice.call(sourceMedia.attributes || []).forEach(function(attribute) {
        if (!/^on/i.test(attribute.name)) media.setAttribute(attribute.name, attribute.value);
      });
      while (media.firstChild) media.removeChild(media.firstChild);
      Array.prototype.forEach.call(sourceMedia.childNodes, function(child) {
        if (child.nodeType === Node.TEXT_NODE) {
          media.appendChild(document.createTextNode(child.nodeValue || ""));
          return;
        }
        if (child.nodeType !== Node.ELEMENT_NODE || child.matches("script, style, iframe, object, embed, form, button, input, select, textarea")) return;
        if (!child.matches("source, track") && elementSubtreeHidden(child)) return;
        var url = child.matches("source[src], track[src]") ? materializedHttpUrl(child.getAttribute("src") || "") : "";
        if (child.matches("source, track") && !url) return;
        if (child.matches("a[href]") && !materializedHttpUrl(child.getAttribute("href") || "")) return;
        media.appendChild(child.matches("source, track") ? safeDeepClone(child, document) : visibilityPrunedClone(child, document));
      });

      var sourceFigure = sourceMedia.closest("figure");
      var outputFigure = media.closest("figure");
      if (sourceFigure && outputFigure) {
        var sourceCaptions = Array.prototype.filter.call(sourceFigure.querySelectorAll("figcaption, caption"), function(caption) {
          return !elementSubtreeHidden(caption) && caption.closest("figure") === sourceFigure;
        });
        var outputCaptions = Array.prototype.filter.call(outputFigure.querySelectorAll("figcaption, caption"), function(caption) {
          return caption.closest("figure") === outputFigure;
        });
        if (sourceCaptions.map(function(caption) { return normalizeText(caption.textContent || ""); }).join(" ") !==
            outputCaptions.map(function(caption) { return normalizeText(caption.textContent || ""); }).join(" ")) {
          outputCaptions.forEach(function(caption) { caption.remove(); });
          sourceCaptions.forEach(function(caption) { outputFigure.appendChild(visibilityPrunedClone(caption, document)); });
        }
      }
    }

    var references = [];
    function add(node, url, authoredLabel) {
      if (!url) return;
      var label = normalizeText(authoredLabel || (node && (node.getAttribute("title") || node.getAttribute("aria-label") || node.getAttribute("label") || node.getAttribute("alt"))) || "");
      references.push({ url: url, label: label || url });
    }
    add(sourceMedia, focalOwnershipMediaPrimaryUrl(sourceMedia));
    if (sourceMedia.tagName === "VIDEO") {
      add(null, materializedHttpUrl(sourceMedia.getAttribute("poster")), "");
      Array.prototype.forEach.call(sourceMedia.querySelectorAll("source[src], track[src], a[href]"), function(node) {
        var attribute = node.matches("a[href]") ? "href" : "src";
        var label = node.matches("a[href]") ? normalizeText(node.textContent || "") :
          normalizeText(node.getAttribute("label") || node.getAttribute("title") || node.getAttribute("aria-label") || "");
        add(node, materializedHttpUrl(node.getAttribute(attribute) || ""), label);
      });
    }
    references = references.filter(function(item) { return !!item.url; });
    if (!references.length) return;
    materializeHttpAttributes(root, true);

    var links = document.createElement("p");
    references.forEach(function(item, index) {
      if (index) links.appendChild(document.createTextNode(" "));
      var link = document.createElement("a");
      link.href = item.url;
      link.textContent = item.label;
      links.appendChild(link);
    });
    var figure = media && media.closest("figure");
    var referenceOwner = figure && figure.contains(media) ? figure : (media || root.querySelector("h1") || root);
    var parent = referenceOwner.parentNode || root;
    parent.insertBefore(links, referenceOwner.nextSibling && referenceOwner.nextSibling.parentNode === parent ? referenceOwner.nextSibling : null);
  }
