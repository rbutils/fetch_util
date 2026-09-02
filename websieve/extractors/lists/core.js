  function listCandidateRank(a, b) {
    return b.rankScore - a.rankScore || b.text.length - a.text.length;
  }

  function listCandidateScoreRank(a, b) {
    return b.rankScore - a.rankScore;
  }

  function buildListExtraction(node) {
    var root = visibleListClone(node);
    cleanupListRoot(root);
    var sectioned = sectionedListExtraction(root);
    if (sectioned) {
      return {
        root: root,
        items: sectioned.items,
        descText: "",
        markdown: sectioned.markdown,
        score: sectioned.score,
        sectionCount: sectioned.regions.length,
        sectionRank: (sectioned.regions.length * 100000) - root.querySelectorAll("a[href]").length
      };
    }

    var items = extractListItems(root);
    var itemQuality = listItemsQualityScore(items);
    var descText = listDescriptionMarkdown(root);
    var fallbackItems = extractFallbackHeadlineItems(root);
    var fallbackQuality = listItemsQualityScore(fallbackItems);

    if ((items.length < 3 && fallbackItems.length > items.length) || fallbackQuality > itemQuality + 180) {
      items = fallbackItems;
      itemQuality = fallbackQuality;
    }

    var markdown = listMarkdownWithDescription(descText, items);
    if (normalizeText(markdown).length < 120 && (fallbackItems.length > items.length || fallbackQuality > itemQuality)) {
      items = fallbackItems;
      itemQuality = fallbackQuality;
      markdown = listMarkdownWithDescription(descText, items);
    }

    return {
      root: root,
      items: items,
      descText: descText,
      markdown: markdown,
      score: itemQuality + (items.length * 80) + Math.min(descText.length, 4000)
    };
  }

  function listContent(metadata, options) {
    options = options || {};
    var candidates = [];
    function pushCandidate(node) {
      if (!node || candidates.indexOf(node) !== -1) return;
      candidates.push(node);
    }

    pushCandidate(listCandidateRoot(metadata));
    contextualListCandidates(metadata).forEach(pushCandidate);
    pushCandidate(document.querySelector("main, [role='main']"));
    pushCandidate(document.body);

    var tableIndexRoot = linkedTableIndexRoot();
    var best = tableIndexRoot ? buildListExtraction(tableIndexRoot) : candidates.reduce(function(current, node) {
      var result = buildListExtraction(node);
      return listExtractionIsBetter(current, result) ? result : current;
    }, null) || buildListExtraction(document.body);
    var rankedMarkdown = best.markdown;
    if (!best.sectionCount) {
      best.descText = listDescriptionMarkdown(best.root, best.items);
      best.markdown = listMarkdownWithDescription(best.descText, best.items);
    }
    var namedHeadingCount = Array.prototype.filter.call(best.root.querySelectorAll("h2, h3, h4"), function(heading) {
      return !heading.closest("article, li, [class*='card' i], [class*='item' i]");
    }).length;
    var rootContext = normalizeText([location.pathname, document.title, metadata.title].join(" "));
    var docsRoot = /\b(?:docs?|documentation|api|library|libraries|reference|class|module|namespace|package)\b/i.test(rootContext);
    var substantialRoot = homepageRootPath() && !docsRoot && best.items.length >= 10 && normalizeText(rankedMarkdown).length >= 3000;
    var broadRootEvidence = substantialRoot ? 2 : 0;
    var headingRootEvidence = substantialRoot ? namedHeadingCount : 0;
    var portalSectionCount = Math.max(best.sectionCount || 0, headingRootEvidence, broadRootEvidence);
    var materializedItemCount = best.items.filter(function(item) {
      return !!materializedHttpUrl(item && item.url);
    }).length;

    return listItemsContentResult(metadata, {
      title: metadata.title || document.title,
      excerpt: best.items[0] ? best.items[0].text : metadata.excerpt,
      html: best.root.innerHTML,
      textContent: best.markdown,
      markdown: best.markdown,
      items: best.items,
      portalRootEvidence: options.portalRoot && portalSectionCount >= 2 && best.items.length >= 4 && materializedItemCount >= 2 ? {
        namedSectionCount: portalSectionCount,
        canonicalCardCount: best.items.length
      } : null
    });
  }
