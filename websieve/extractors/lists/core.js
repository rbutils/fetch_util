  function listCandidateRank(a, b) {
    return b.score - a.score || b.text.length - a.text.length;
  }

  function listCandidateScoreRank(a, b) {
    return b.score - a.score;
  }

  function buildListExtraction(node) {
    var root = cleanClone(node);
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
    var fallbackItems = extractFallbackHeadlineItems(node);
    var fallbackQuality = listItemsQualityScore(fallbackItems);

    if ((items.length < 3 && fallbackItems.length > items.length) || fallbackQuality > itemQuality + 180) {
      items = fallbackItems;
      itemQuality = fallbackQuality;
    }

    var linkMarkdown = listMarkdown(items);
    var markdown = descText ? descText + (linkMarkdown ? "\n\n" + linkMarkdown : "") : linkMarkdown;
    if (normalizeText(markdown).length < 120 && (fallbackItems.length > items.length || fallbackQuality > itemQuality)) {
      items = fallbackItems;
      itemQuality = fallbackQuality;
      linkMarkdown = listMarkdown(items);
      markdown = descText ? descText + (linkMarkdown ? "\n\n" + linkMarkdown : "") : linkMarkdown;
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

    var best = candidates.reduce(function(current, node) {
      var result = buildListExtraction(node);
      return listExtractionIsBetter(current, result) ? result : current;
    }, null) || buildListExtraction(document.body);

    return listItemsContentResult(metadata, {
      title: metadata.title || document.title,
      excerpt: best.items[0] ? best.items[0].text : metadata.excerpt,
      html: best.root.innerHTML,
      textContent: best.markdown,
      markdown: best.markdown,
      items: best.items,
      portalRootEvidence: options.portalRoot && best.sectionCount >= 2 && best.items.length >= 4 ? {
        namedSectionCount: best.sectionCount,
        canonicalCardCount: best.items.length
      } : null
    });
  }
