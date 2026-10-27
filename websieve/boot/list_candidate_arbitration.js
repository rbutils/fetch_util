  function genericListMayReplace(candidate, focalArticleRoute) {
    var cachedFocal = candidate && (candidate.focalPermalinkContent || focalArticleRoute) &&
      (candidate.contentType === "article" || candidate.contentType === "medical");
    return candidate && !candidate.hostAware && !candidate.docsLike &&
      !cachedFocal && !articleRouteFocalContent(candidate);
  }

  function emptyListCandidateLosesContent(current, candidate) {
    if (!candidate || candidate.contentType !== "list") return false;
    var candidateText = normalizeText(candidate.markdown || candidate.textContent || "");
    var currentText = normalizeText(current && (current.markdown || current.textContent) || "");
    var itemCount = candidate.itemCount || 0;
    if (candidate.listExtraction && Array.isArray(candidate.listExtraction.items)) {
      itemCount = Math.max(itemCount, candidate.listExtraction.items.length);
    }
    if (Array.isArray(candidate.listSourceItems)) {
      itemCount = Math.max(itemCount, candidate.listSourceItems.length);
    }
    if (!itemCount && candidate.html) {
      var candidateRoot = document.createElement("div");
      candidateRoot.innerHTML = candidate.html;
      itemCount = Array.prototype.filter.call(candidateRoot.querySelectorAll("table a[href], .itemlist a[href]"), function(link) {
        return !!materializedHttpUrl(link.getAttribute("href"));
      }).length;
    }
    return !candidateText && itemCount === 0 && !!currentText;
  }

  function cachedFocalArticleContent(candidate, focalArticleRoute) {
    return !!(candidate && (candidate.focalPermalinkContent || focalArticleRoute) &&
      (candidate.contentType === "article" || candidate.contentType === "medical"));
  }

  function selectIndexListCandidate(content, metadata, options) {
    options = options || {};
    var readProbe = listPageProbeRead(content);
    var repeatedCollection = options.repeatedCollection;
    var materialResultsOwner = options.materialResultsOwner;
    var institutionalCaseIndex = options.institutionalCaseIndex;
    var indexListAllowed = indexListCandidateAllowed(content,
      !!(repeatedCollection && repeatedCollection.queryDirectoryOverride) || !!materialResultsOwner) &&
      !options.listArticleOwnershipConflict;
    var sourceOwnedIndex = indexListAllowed && options.strongArticle &&
      !cachedFocalArticleContent(content, options.focalArticleRoute) && sourceOwnedListAgainstReader(content, metadata);
    var candidate = null;

    if (indexListAllowed && materialResultsOwner) {
      candidate = listContent(metadata, {
        sourceOwner: materialResultsOwner.owner,
        materialResultsOwner: materialResultsOwner
      });
    } else if (indexListAllowed && dominantIndexListPage(content, readProbe)) {
      candidate = repeatedCollection ? listContent(metadata, {
        repeatedRecordCollection: repeatedCollection
      }) : listContent(metadata, institutionalCaseIndex ? {
        sourceOwner: institutionalCaseIndex.root,
        institutionalCaseIndex: institutionalCaseIndex
      } : undefined);
    } else if (indexListAllowed && (sourceOwnedIndex || isProbablyListPage(content, readProbe) || options.articleBodyCollection || repeatedCollection) &&
        (likelyListPath() || repeatedCollection ||
          (!cachedFocalArticleContent(content, options.focalArticleRoute) && !articleRouteFocalContent(content))) &&
        (!options.strongArticle || sourceOwnedIndex || repeatedCollection)) {
      candidate = repeatedCollection ? listContent(metadata, {
        repeatedRecordCollection: repeatedCollection
      }) : (sourceOwnedIndex || listContent(metadata, institutionalCaseIndex ? {
        sourceOwner: institutionalCaseIndex.root,
        institutionalCaseIndex: institutionalCaseIndex
      } : undefined));
    }

    var materialResultsCoverage = null;
    function materialResultsCandidateOwnershipProven(value) {
      if (materialResultsCoverage === null) {
        materialResultsCoverage = !!(materialResultsOwner && materialResultsCandidateCoversSource(materialResultsOwner, value));
      }
      return materialResultsCoverage;
    }

    if (candidate && !emptyListCandidateLosesContent(content, candidate) &&
        !(options.supportingProductCollection && content.contentType === "article") &&
        !sourceMaterialBlocksListCandidate(content, candidate, metadata) &&
        !sourceOwnedFallbackListLoss(content, candidate) &&
        (!repeatedCollection || repeatedRecordCandidateCoversOwner(candidate, repeatedCollection) ||
          materialResultsCandidateOwnershipProven(candidate)) &&
        !selectedArticleHasExplicitDetailOwnership(content, metadata, candidate) &&
        (!materialResultsOwner || materialResultsCandidateOwnershipProven(candidate))) {
      return { content: candidate, materialResultsCandidateAccepted: !!materialResultsOwner };
    }
    return { content: content, materialResultsCandidateAccepted: false };
  }
