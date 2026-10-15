  var articleRouteReadContext = null;

  function articleRouteOwnershipClone(node, sourceClones) {
    // Broad-list proofs also inspect presentation descendants for record-class
    // leaf ownership. Preserve their ordinary structure, not just their text.
    if (sourceClones || queryOrCategoryPage() || likelyListPath() && !articleLikePath()) {
      return visibilityPrunedClone(node, document, sourceClones);
    }
    return withIndexedPhysicalVisibility(node, function() {
      var sourceTreeHasNoShadow = !nodeHasShadowContent(node);
      return visibilityPrunedClone(node, document, null, false, function(source) {
        if (!source.matches("pre, div")) return null;
        var projection = physicalLiteralCodeProjection(source, true, sourceTreeHasNoShadow);
        // Ownership statistics use textContent, not rendered code formatting.
        // Even a legitimate newline renderer must keep the ordinary clone here
        // when its aggregate differs from the physical source.
        return projection && projection.textContent === source.textContent ? projection : null;
      });
    });
  }

  function withArticleRouteRead(extract) {
    var previous = articleRouteReadContext;
    articleRouteReadContext = {};
    try {
      return extract();
    } finally {
      articleRouteReadContext = previous;
    }
  }

  function articleRouteFocalContent(content, returnSourceOwner) {
    // Only source-only probes are immutable within this synchronous read. Rendered
    // content stays fresh, and its potentially large HTML is never retained here.
    if (!articleRouteReadContext || content) {
      return computeArticleRouteFocalContent(content, returnSourceOwner);
    }
    var record = articleRouteReadContext;
    var mode = returnSourceOwner ? "owner" : "matches";
    if (!Object.prototype.hasOwnProperty.call(record, mode)) {
      record[mode] = computeArticleRouteFocalContent(content, returnSourceOwner);
    }
    return record[mode];
  }

  function computeArticleRouteFocalContent(content, returnSourceOwner) {
    if (!document.body) return false;
    var homepageLanding = homepageLandingOwnership();
    var semanticCandidates = Array.prototype.filter.call(document.querySelectorAll("[itemprop~='articleBody' i], article[role~='main' i]"), function(node) {
      if (elementSubtreeHidden(node) || node.closest("nav, aside, footer, [role~='navigation' i], [role~='complementary' i]")) return false;
      return normalizeText(node.textContent || "").length >= 120;
    });
    var semanticAmbiguous = semanticCandidates.length > 1;
    var semanticFocal = semanticCandidates.length === 1 ? semanticCandidates[0] : null;
    var classFocal = document.querySelector([
      "article[class*='article-content' i]",
      "article[class*='article_content' i]",
      "article[class*='article-body' i]",
      "article[class*='article_body' i]"
    ].join(", "));
    var headlineOwnership = fallbackFocalHeadlineOwnership();
    var headlineFocal = headlineOwnership && headlineOwnership.node;
    var topLevelMainArticles = headlineFocal ? [headlineFocal] : Array.prototype.filter.call(document.querySelectorAll("main article"), function(article) {
      if (elementSubtreeHidden(article) || article.parentElement.closest("article")) return false;
      var visible = articleRouteOwnershipClone(article);
      try {
        return !!(normalizeText(visible.textContent || "") || visible.querySelector("img[src], picture, video, audio, svg"));
      } finally {
        visible.replaceChildren();
      }
    });
    var pageArticleTitle = normalizeText((content && content.title) || document.title || "");
    var matchingTitleArticles = topLevelMainArticles.filter(function(article) {
      return Array.prototype.some.call(article.querySelectorAll("h1, [itemprop~='headline' i]"), function(heading) {
        return !elementSubtreeHidden(heading) && heading.closest("article") === article &&
          normalizeText(heading.textContent || "") === pageArticleTitle;
      });
    });
    var exactTitleFocal = matchingTitleArticles.length === 1 ? matchingTitleArticles[0] : null;
    var mainFocal = exactTitleFocal || topLevelMainArticles[0] || null;
    if (semanticAmbiguous && !headlineFocal) return false;
    var focal = (homepageLanding && homepageLanding.main) || headlineFocal || semanticFocal || classFocal || exactTitleFocal || mainFocal;
    if (!articleLikePath() && !focal) return false;
    if (focal === classFocal && !articleLikePath() && focal !== headlineFocal && exactTitleFocal !== focal) return false;
    if (content && content.contentType !== "article" && content.contentType !== "medical" &&
        !(content.contentType === "list" && (focal === headlineFocal || (homepageLanding && focal === homepageLanding.main)))) return false;

    var externalPageTitleHeading = null;
    if (focal && focal === classFocal) {
      var pageTitleHeadings = Array.prototype.filter.call(document.querySelectorAll("h1, [role='heading'][aria-level='1']"), function(node) {
        return !elementSubtreeHidden(node) && normalizeText(node.textContent || "") === pageArticleTitle;
      });
      if (pageTitleHeadings.length === 1 && !pageTitleHeadings[0].closest("article") &&
          pageTitleHeadings[0].parentElement === focal.parentElement) {
        var intervening = true;
        var sibling = pageTitleHeadings[0].nextElementSibling;
        while (sibling && sibling !== focal) {
          if (!sibling.matches("time")) intervening = false;
          sibling = sibling.nextElementSibling;
        }
        if (sibling === focal && intervening) externalPageTitleHeading = pageTitleHeadings[0];
      }
    }

    var focalCloneMap = homepageLanding && focal === homepageLanding.main ? new WeakMap() : null;
    var root = focal ? articleRouteOwnershipClone(focal, focalCloneMap) : document.createElement("div");
    try {
      if (!focal && content && content.html) root.innerHTML = content.html;
      var heading = homepageLanding && focal === homepageLanding.main && focalCloneMap.get(homepageLanding.heading)
        ? focalCloneMap.get(homepageLanding.heading)
        : (focal === headlineFocal && headlineOwnership
        ? headlineOwnership.heading
        : Array.prototype.find.call(root.querySelectorAll("h1, h2[itemprop~='headline' i], [role='heading'][aria-level='1']"), function(node) {
          return !elementSubtreeHidden(node);
        }));
      var ownedTitle = heading && normalizeText(heading.textContent || "") ||
        (externalPageTitleHeading && pageArticleTitle) ||
        (focal === headlineFocal && headlineOwnership && headlineOwnership.title);
      var clonedLandingBody = homepageLanding && focal === homepageLanding.main
        ? focalCloneMap.get(homepageLanding.body)
        : null;
      var paragraphs = Array.prototype.filter.call(root.querySelectorAll("p"), function(paragraph) {
        var owner = paragraph.closest("article");
        return !owner || owner === root || (clonedLandingBody && owner === clonedLandingBody);
      });
      var text = normalizeText(paragraphs.map(function(paragraph) { return paragraph.textContent || ""; }).join(" "));
      if (!focal && content && content.html) text = normalizeText(root.textContent || "");
      var nestedArticles = root.querySelectorAll("article").length;
      var rootText = normalizeText(root.textContent || "");
      var rootLinks = root.querySelectorAll("a[href]");
      var bylineOrTime = document.querySelector("[rel='author'], [itemprop='author'], [itemprop='datePublished'], time, .byline, [class*='byline' i]");
      var linkText = Array.prototype.reduce.call(root.querySelectorAll("p a[href]"), function(total, link) {
        return total + normalizeText(link.textContent || "").length;
      }, 0);
      var linkDensity = text.length > 0 ? linkText / text.length : 1;

      var substantialProse = (paragraphs.length >= 2 && text.length >= 120) ||
        (focal === headlineFocal && headlineOwnership && text.length >= 120);
      var structuredLiveBody = nestedArticles >= 2 && normalizeText(root.textContent || "").length >= 280;
      var paragraphlessBody = articleLikePath() && root.matches && root.matches("article") &&
        paragraphs.length === 0 && nestedArticles === 0 && !root.querySelector("h1, h2, h3, h4") &&
        rootText.length >= 280 && rootLinks.length <= 2;
      var paragraphlessLinkText = Array.prototype.reduce.call(rootLinks, function(total, link) {
        return total + normalizeText(link.textContent || "").length;
      }, 0);
      var effectiveLinkDensity = paragraphlessBody ? paragraphlessLinkText / rootText.length : linkDensity;
      var requiresExclusiveMainOwnership = !!focal && (focal === classFocal || focal === mainFocal ||
        (homepageLanding && focal === homepageLanding.main)) && focal !== headlineFocal;
      var ownsMainBody = (topLevelMainArticles.length === 1 && topLevelMainArticles[0] === focal) || exactTitleFocal === focal;
      var bodyEvidence = homepageLanding && homepageLanding.main === focal
        ? text.length >= 280 && !semanticAmbiguous
        : (requiresExclusiveMainOwnership && !ownsMainBody
          ? paragraphlessBody
          : (substantialProse || structuredLiveBody || paragraphlessBody));
      var broadListRoute = queryOrCategoryPage() || (likelyListPath() && !articleLikePath());
      if (semanticFocal !== focal && ownsMainBody && broadListRoute) {
        var recordSelector = genericListCardSelector();
        var recordNodes = Array.prototype.filter.call(root.querySelectorAll(recordSelector), function(node) {
          return !node.querySelector(recordSelector) && normalizeText(node.textContent).length >= 40;
        });
        var linkedRecordNodes = [];
        Array.prototype.forEach.call(root.querySelectorAll("a[href]"), function(link) {
          var linkedHeading = link.closest("h1, h2, h3, h4") || link.querySelector("h1, h2, h3, h4");
          var title = normalizeText(linkedHeading && linkedHeading.textContent);
          if (title.length < minimumListTitleLength(title) || title.length > 220 ||
              !materializedHttpUrl(link.getAttribute("href"))) return;
          var recordNode = linkedHeading.closest(recordSelector);
          if (recordNodes.indexOf(recordNode) < 0 || linkedRecordNodes.indexOf(recordNode) >= 0) return;
          linkedRecordNodes.push(recordNode);
        });
        if (linkedRecordNodes.length >= 3) return false;
      }
      var ownsFocalArticle = !!ownedTitle && bodyEvidence && effectiveLinkDensity < 0.45 &&
        (!!focal || !!content) && (!!bylineOrTime || (content && (content.byline || content.publishedTime)) || !!focal);
      if (!ownsFocalArticle) return false;
      if (!returnSourceOwner) return true;
      return focal && (!homepageLanding || focal !== homepageLanding.main) ? focal : null;
    } finally {
      root.replaceChildren();
    }
  }
