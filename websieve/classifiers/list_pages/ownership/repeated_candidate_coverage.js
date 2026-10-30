  function repeatedRecordCandidatePreservesExistingList(current, candidate) {
    if (!current || current.contentType !== "list" || !candidate || candidate.contentType !== "list") return false;
    var currentMarkdown = current.markdown || "";
    var candidateMarkdown = candidate.markdown || "";
    if (!currentMarkdown || !candidateMarkdown || !wordsRemainInOrder(currentMarkdown, candidateMarkdown)) return false;

    function renderedWords(markdown) {
      return normalizeText((markdown || "")
        .replace(/!\[([^\]]*)\]\((?:\\.|[^)])+\)/g, "$1")
        .replace(/\[([^\]]+)\]\((?:\\.|[^)])+\)/g, "$1")
        .replace(/<[^>]+>/g, " "))
        .toLowerCase().match(/[\p{L}\p{N}]+/gu) || [];
    }

    function wordsRemainInOrder(previous, replacement) {
      var replacementWords = renderedWords(replacement);
      var nextPosition = 0;
      return renderedWords(previous).every(function(word) {
        var position = replacementWords.indexOf(word, nextPosition);
        if (position < 0) return false;
        nextPosition = position + 1;
        return true;
      });
    }

    function renderedLinks(markdown) {
      return Array.from((markdown || "").matchAll(/!?(?:\[([^\]]+)\])\((https?:\/\/(?:\\.|[^\\)\s])+)/g), function(match) {
        return { label: normalizeText(match[1]), destination: materializedHttpUrl(match[2]) };
      }).filter(function(link) { return !!link.destination; });
    }

    var currentLinks = renderedLinks(currentMarkdown);
    var candidateLinks = renderedLinks(candidateMarkdown);
    var nextCandidateLink = 0;
    return currentLinks.every(function(currentLink) {
      var matchedIndex = candidateLinks.findIndex(function(candidateLink, index) {
        return index >= nextCandidateLink &&
          listCanonicalKey(candidateLink.destination) === listCanonicalKey(currentLink.destination) &&
          wordsRemainInOrder(currentLink.label, candidateLink.label);
      });
      if (matchedIndex < 0) return false;
      nextCandidateLink = matchedIndex + 1;
      return true;
    });
  }

  function repeatedRecordListCandidate(current, metadata, collection) {
    if (!current || current.contentType !== "list" || !collection) return null;
    var candidate = listContent(metadata, { repeatedRecordCollection: collection });
    if (!repeatedRecordCandidateCoversOwner(candidate, collection) ||
        !repeatedRecordCandidatePreservesExistingList(current, candidate)) return null;
    return candidate;
  }

  function repeatedRecordCandidateCoversOwner(candidate, collection) {
    var items = candidate && candidate.listExtraction && candidate.listExtraction.items;
    var extraction = candidate && candidate.listExtraction;
    var mappedOwner = extraction && extraction.collectionOwnerMapped &&
      extraction.collectionOwnerSourceNode === collection.owner && extraction.renderOwnerSourceNode === collection.renderOwner;
    var mappedMain = collection && collection.primaryMain && extraction && extraction.primaryMainMapped &&
      extraction.primaryMainSourceNode === collection.primaryMain;
    if (!items || !collection || !collection.records.length || !collection.owner || !collection.renderOwner ||
        !mappedOwner || (collection.primaryMain ? !mappedMain : extraction.primaryMainMapped)) return false;
    var ownsNarrativeRoutes = items.some(function(item) { return item.sourceOwnedNarrativeRoute; });
    var matched = new Set();
    return collection.records.every(function(record) {
      // Only the proved route repair may treat complete action cards as context rather than authored records.
      if (ownsNarrativeRoutes && linkedNarrativeActionCard(record.node)) return true;
      var itemIndex = items.findIndex(function(item, index) {
        if (matched.has(index) || listCanonicalKey(materializedHttpUrl(item.url) || "") !== record.destination) return false;
        return item.repeatedRecordIdentity === record.identity ||
          normalizeText(item.text || "").toLowerCase().indexOf(record.title.toLowerCase()) !== -1;
      });
      if (itemIndex < 0) return false;
      matched.add(itemIndex);
      return true;
    });
  }
