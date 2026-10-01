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
