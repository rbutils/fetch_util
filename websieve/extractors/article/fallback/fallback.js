  function fallbackContent(metadata) {
    var focalOwnership = fallbackFocalHeadlineOwnership();
    var sourceOwnedMedia = focalOwnership && focalOwnership.proof === "same-owner-source-headline-and-media";
    var highConfidence = highConfidenceFallbackContent(metadata);
    if (highConfidence && !sourceOwnedMedia) return highConfidence;
    if (metadata && metadata.contentsComponent) {
      var contentsContent = sourceOwnedContentsComponentContent(metadata, metadata.contentsComponent);
      if (contentsContent) return contentsContent;
    }
    var liveblog = resolveFallbackLiveblogOwnership();
    if (liveblog) return sourceOwnedLiveblogContent(metadata, liveblog);
    var sourceOwnedPage = sourceOwnedMedia ? null : genericSourceOwnedPageContent(metadata);
    if (sourceOwnedPage) return sourceOwnedPage;
    var selectors = genericArticleSelectors();
    var candidates = new Set();

    selectors.forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(node) {
        candidates.add(node);
      });
    });
    if (focalOwnership && focalOwnership.node && document.body.contains(focalOwnership.node)) candidates.add(focalOwnership.node);

    var sourceClones = new WeakMap();
    var visibleBody = visibilityPrunedClone(document.body, document, sourceClones);
    var records = Array.from(candidates).map(function(node) {
      if (elementSubtreeHidden(node) || sourceOwnershipInChrome(node)) return null;
      var visibleNode;
      if (document.body.contains(node)) {
        visibleNode = sourceClones.get(node);
        if (!visibleNode || !visibleBody.contains(visibleNode)) return null;
      } else {
        visibleNode = visibilityPrunedClone(node, document);
      }
      var scoringNode = cleanClone(visibleNode);
      cleanupGenericArticleRoot(scoringNode);
      return { node: node, visibleNode: visibleNode, score: scoreNode(scoringNode) };
    }).filter(Boolean);

    var dominated = new Set();
    var containment = fallbackContainedArticleRecords(records);
    records.forEach(function(wrapper) {
      if (!document.body.contains(wrapper.node)) return;
      var contained = containment.containedByNode.get(wrapper.node);
      if (!contained) return;
      var focalVisibleNode = broadMixedArticleFocal(wrapper.visibleNode);
      if (!focalVisibleNode) return;
      var focal = containment.recordsByVisibleNode.get(focalVisibleNode);
      if (!focal) return;

      contained.forEach(function(record) {
        if (record !== focal) dominated.add(record);
      });
      dominated.add(wrapper);
    });

    var best = records.reduce(function(current, record) {
      if (dominated.has(record)) return current;
      if (!current || record.score > current.score) return record;
      return current;
    }, null);

    if (focalOwnership) {
      var focalHeadlineRecord = records.find(function(record) { return record.node === focalOwnership.node; });
      var provedSparseMediaOwner = focalOwnership.proof === "same-owner-source-headline-and-media" &&
        focalOwnership.body.sourceMediaOnly;
      if (focalHeadlineRecord && !Number.isFinite(focalHeadlineRecord.score) &&
          ((focalOwnership.body.publicPreview && focalOwnership.body.text.length >= 120) || provedSparseMediaOwner)) {
        focalHeadlineRecord.score = 0;
      }
      if (focalHeadlineRecord && Number.isFinite(focalHeadlineRecord.score)) best = focalHeadlineRecord;
    }

    var selected = best && best.score > -Infinity ? best : null;
    var homepageLanding = homepageLandingOwnership();
    if (homepageLanding) {
      var homepageMainRecord = records.find(function(record) { return record.node === homepageLanding.main; });
      if (homepageMainRecord && Number.isFinite(homepageMainRecord.score)) {
        selected = homepageMainRecord;
        focalOwnership = null;
      }
    }
    var excerptArticleOwner = focalOwnership;
    if (!selected || !focalOwnership || selected.node !== focalOwnership.node) focalOwnership = null;
    var node = selected ? selected.node : document.body;
    var visibleNode = selected ? selected.visibleNode : visibleBody;
    var relatedCollectionMarker = null;
    var relatedSlotMarker = null;
    var renderVisibleNode = visibleNode;
    if (focalOwnership && focalOwnership.relatedCollection) {
      var relatedCollectionClone = sourceClones.get(focalOwnership.relatedCollection);
      var focalOwnerClone = sourceClones.get(focalOwnership.node);
      if (relatedCollectionClone && focalOwnerClone) {
        relatedCollectionMarker = "media-related-" + Math.random().toString(36).slice(2);
        relatedCollectionClone.setAttribute("data-fetchutil-page-overview", relatedCollectionMarker);
        if (focalOwnership.node.contains(focalOwnership.relatedCollection)) {
          relatedSlotMarker = "fetchutil-media-related-slot-" + Math.random().toString(36).slice(2);
        }
        if (!focalOwnership.node.contains(focalOwnership.relatedCollection)) {
          var ownedRoots = [
            { source: focalOwnership.node, clone: focalOwnerClone },
            { source: focalOwnership.relatedCollection, clone: relatedCollectionClone }
          ].sort(function(left, right) {
            return left.source.compareDocumentPosition(right.source) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1;
          });
          renderVisibleNode = document.createElement("div");
          ownedRoots.forEach(function(entry) { renderVisibleNode.appendChild(entry.clone.cloneNode(true)); });
        }
      } else {
        focalOwnership = null;
      }
    }
    stripSourceOwnedTerminalArticleFurniture(visibleNode, sourceClones);
    var markedVisibleNode = safeDeepClone(renderVisibleNode, document);
    markTerminalArticleLinkCollections(markedVisibleNode);
    var ownedMedia = focalOwnership ? (focalOwnership.media ? [focalOwnership.media] :
      Array.prototype.filter.call(focalOwnership.node.querySelectorAll("video"), function(media) {
        if (elementSubtreeHidden(media)) return false;
        var rect = media.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
      })) : [];
    var preservedRelatedCollection = focalOwnershipDetachRelatedCollection(markedVisibleNode, relatedCollectionMarker,
      relatedSlotMarker);
    if (relatedCollectionMarker && !preservedRelatedCollection) return null;
    var clone = cleanClone(markedVisibleNode);
    if (focalOwnership && focalOwnership.body.publicPreview) focalOwnershipRetainPublicPreview(clone);
    var comments = focalOwnership ? visibleCommentMarkup(document, focalOwnership) :
      (fallbackFocalArticleRoot(clone) ? visibleCommentMarkup(document) : "");
    prepareFallbackInlineProse(clone);
    cleanupGenericArticleRoot(clone);
    prepareFallbackInlineProse(clone);
    cleanupFallbackArticleChrome(clone);
    if (preservedRelatedCollection && focalOwnership) {
      if (!focalOwnershipRestoreRelatedCollection(clone, preservedRelatedCollection, focalOwnership.relatedCollection,
        focalOwnership.node, relatedSlotMarker)) return null;
    }
    ownedMedia.forEach(function(media) { focalOwnershipPreserveMediaResources(clone, media); });
    if (comments) clone.insertAdjacentHTML("beforeend", comments);
    var text = normalizeText(clone.textContent);
    var headerMetadata = sourceOwnedFallbackHeaderMetadata(node, document.title, metadata);
    var sourceOwnedPublication = sourceOwnedMedia ?
      sourceOwnedMediaPublication(focalOwnership, metadata) : sourceOwnedFallbackPublication(metadata, node, selected);
    var excerptOwnership = focalOwnership || resolveCanonicalArticleBodyOwnership() || excerptArticleOwner;

    return {
      title: focalOwnership ? focalOwnership.title : document.title,
      byline: null,
      excerpt: focalOwnership && focalOwnership.body.publicPreview ? focalOwnership.body.text :
        sourceOwnedMedia ? fallbackOwnedMediaExcerpt(visibleNode, text, focalOwnership, sourceClones) :
          fallbackArticleExcerpt(visibleNode, text, metadata, !!selected, excerptOwnership, sourceClones),
      sourceOwnedFocalArticle: !!focalOwnership,
      sourceOwnedMediaArticle: !!(focalOwnership && focalOwnership.proof === "same-owner-source-headline-and-media"),
      sourceOwnedMediaHeadline: focalOwnership && focalOwnership.proof === "same-owner-source-headline-and-media" ?
        normalizeText(focalOwnership.heading.textContent || "") : null,
      sourceOwnedMediaUrls: focalOwnership && focalOwnership.proof === "same-owner-source-headline-and-media" ?
        focalOwnership.mediaUrls : [],
      sourceOwnedHeaderMetadata: headerMetadata,
      focalPublicPreview: !!(focalOwnership && focalOwnership.body.publicPreview),
      siteName: (metadata && metadata.siteName) || location.hostname,
      publishedTime: sourceOwnedPublication ? sourceOwnedPublication.publishedTime : null,
      sourceOwnedArticlePublicationResolved: !!sourceOwnedPublication,
      html: clone.innerHTML,
      textContent: text,
      readerMode: false,
      mainContentRoot: homepageRootPath() && (node.matches("main, [role='main']") ||
        (node.matches("article") && genericListPageContainer(node))),
      instructionalContentRoot: instructionalArticleRoot(node, clone),
      contentType: "article"
    };
  }

  function nonArticleContent() {
    return {
      title: document.title,
      byline: null,
      excerpt: null,
      siteName: location.hostname,
      publishedTime: null,
      html: "",
      textContent: "",
      markdown: "",
      readerMode: false,
      contentType: "list",
      items: []
    };
  }

  function weatherWidgetText(text) {
    var normalized = normalizeText(text || "");
    if (!normalized) return false;
    if (!/(ve[ðd]ursp[áa]|weather forecast|forecast for the next|forecast for)/i.test(normalized)) return false;

    var weatherHits = normalized.match(/\b(ve[ðd]ursp[áa]|hiti|[úu]rkoma|vindur|frost|rigning|sk[ýy]ja[ðd]|temperature|precipitation|wind|rain|snow|storm)\b/ig) || [];
    return weatherHits.length >= 4;
  }

  function preferFallbackContent(primary, fallback) {
    if (primary && primary.contentType === "article" && fallback &&
        fallback.sourceOwnedHeaderMetadata &&
        sourceOwnedFallbackHeaderMatchesPrimary(primary, fallback.sourceOwnedHeaderMetadata)) {
      var headerMetadata = fallback.sourceOwnedHeaderMetadata;
      if (!primary.byline) primary.byline = headerMetadata.byline;
      if (!primary.publishedTime) primary.publishedTime = headerMetadata.publishedTime;
    }
    if (!primary) return fallback;
    if (fallback && (fallback.contentType === "notice" || fallback.sourceOwnedContentsComponent)) return fallback;
    if (fallback && fallback.sourceOwnedMediaArticle &&
        (!primary || primary.contentType === "article" || primary.contentType === "list")) return fallback;
    if (!fallback || !primary.readerMode) return primary;
    var mediaWikiLike = !!document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output");
    var primaryText = normalizeText(primary.markdown || primary.textContent || "");
    if (mediaWikiLike && primaryText.length >= 800) return primary;

    var fallbackText = normalizeText(fallback.markdown || fallback.textContent || "");
    var primaryRoot = document.createElement("div");
    var fallbackRoot = document.createElement("div");
    primaryRoot.innerHTML = primary.html || "";
    fallbackRoot.innerHTML = fallback.html || "";
    var primaryParagraphs = primaryRoot.querySelectorAll("p, li").length;
    var fallbackParagraphs = fallbackRoot.querySelectorAll("p, li").length;
    var fallbackLinkText = Array.prototype.reduce.call(fallbackRoot.querySelectorAll("a[href]"), function(total, link) {
      return total + textLength(link);
    }, 0);
    var fallbackLinkDensity = fallbackText.length > 0 ? fallbackLinkText / fallbackText.length : 0;
    var fallbackContainsPrimary = primaryText.length >= 600 && fallbackText.indexOf(primaryText) !== -1;
    var adLikePrimary = /\b(oglas|advertisement|sponsored|ad)\b/i.test(primaryText.slice(0, 160));
    var footerLikePrimary = legalFooterText(primaryText);
    var weatherLikePrimary = weatherWidgetText(primaryText);
    var weatherPage = /(weather|forecast|ve[ðd]ur|vedur|meteo)/i.test((location.pathname || "") + " " + document.title);

    if (!fallbackText) return primary;
    if (fallback.legalProvision) return fallback;
    var instructional = instructionalFallbackContent(primary, fallback, primaryRoot, fallbackRoot);
    if (instructional) return instructional;
    var ownedSections = sourceOwnedFallbackContent(primary, fallback, primaryRoot, fallbackRoot, primaryText, fallbackText);
    if (ownedSections) return ownedSections;
    if (primaryText.length < 4000 &&
        fallbackText.length >= Math.max(1800, primaryText.length * (fallbackContainsPrimary ? 2.5 : 3)) &&
        fallbackParagraphs >= Math.max(8, primaryParagraphs + 5) &&
        fallbackLinkDensity < 0.28) {
      return fallback;
    }
    if (substantialArticleContent(primary)) return primary;

    if (weatherLikePrimary && !weatherPage && fallbackText.length >= Math.max(900, primaryText.length * 2)) {
      return fallback;
    }

    if (promotionalRailContent(primary) && substantialArticleContent(fallback) && fallbackText.length >= 1200 && fallbackLinkDensity < 0.25) {
      return fallback;
    }

    if (footerLikePrimary && fallbackText.length >= Math.max(1000, primaryText.length * 2)) {
      return fallback;
    }

    if (substantialArticleContent(fallback) &&
        (primaryText.length < 240 || adLikePrimary) &&
        fallbackText.length >= Math.max(600, primaryText.length * 3)) {
      return fallback;
    }

    return primary;
  }

  function promotionalRailNode(node, text, linkDensity) {
    var hint = ((node.className || "") + " " + (node.id || "")).toLowerCase();
    if (!/(sidebar|rail|aside|promo|cta|recent|popular|related)/.test(hint) && !/\b(recent posts?|popular posts?|latest posts?|related posts?|get started for free|start (?:your )?free trial|try .* for free)\b/i.test(text)) return false;
    if (node.querySelectorAll("p").length >= 8 && linkDensity < 0.18 && !/(sidebar|rail|aside)/.test(hint)) return false;
    return linkDensity >= 0.18 || node.querySelectorAll("a[href]").length >= 4;
  }

  function mixedArticleRailWrapper(node, text) {
    if (!/\b(recent posts?|popular posts?|latest posts?|related posts?|get started for free|start (?:your )?free trial|try .* for free)\b/i.test(text)) return false;
    if (node.matches && node.matches("article, [itemprop='articleBody']")) return false;

    return Array.prototype.some.call(node.querySelectorAll("article, [itemprop='articleBody'], [class*='article' i], [class*='content' i], [class*='post' i]"), function(child) {
      if (child === node || child.querySelectorAll("a[href]").length >= 4) return false;
      return textLength(child) >= 1200 && child.querySelectorAll("p").length >= 5;
    });
  }

  function promotionalRailContent(content) {
    if (!content || content.contentType !== "article") return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";
    var text = normalizeText(root.textContent || content.textContent || content.markdown || "");
    var linkText = Array.prototype.reduce.call(root.querySelectorAll("a[href]"), function(total, link) {
      return total + normalizeText(link.textContent || link.getAttribute("aria-label") || "").length;
    }, 0);
    var linkDensity = text.length > 0 ? linkText / text.length : 0;

    return promotionalRailNode(root, text, linkDensity);
  }
