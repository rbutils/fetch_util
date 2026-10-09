  // Reader's prose scoring can omit small structured siblings. Use mapped source
  // ownership and complete material preservation, rather than a text-size ratio.
  function sourceOwnedReaderBodyOwner(content, sourceParagraphs) {
    if (!Array.isArray(sourceParagraphs) || sourceParagraphs.length < 2) return null;
    if (!Array.isArray(content.sourceOwnedReaderUnmappedHeaderParagraphs) ||
        content.sourceOwnedReaderUnmappedHeaderParagraphs.length ||
        !Array.isArray(content.sourceOwnedReaderUnmappedTrailingParagraphs) ||
        content.sourceOwnedReaderUnmappedTrailingParagraphs.length) return null;

    var previous = null;
    for (var index = 0; index < sourceParagraphs.length; index += 1) {
      var paragraph = sourceParagraphs[index];
      if (!paragraph || paragraph.localName !== "p" || !document.documentElement.contains(paragraph) ||
          elementVisuallyHidden(paragraph) || (previous &&
            !(previous.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING))) return null;
      previous = paragraph;
    }

    var candidates = sourceArticleBodyCandidates().filter(function(owner) {
      return !elementSubtreeHidden(owner) && !sourceOwnershipInChrome(owner) &&
        sourceParagraphs.every(function(paragraph) { return owner.contains(paragraph); });
    });
    candidates = candidates.filter(function(candidate) {
      return !candidates.some(function(other) { return other !== candidate && candidate.contains(other); });
    });
    if (candidates.length !== 1) return null;

    var owner = candidates[0];
    if (Array.prototype.some.call(owner.querySelectorAll("article"), function(article) {
      return !sourceParagraphs.every(function(paragraph) { return article.contains(paragraph); });
    })) return null;
    return owner;
  }

  function sourceOwnedReaderTableRows(table) {
    return Array.from(table.querySelectorAll("tr")).map(function(row) {
      return Array.from(row.querySelectorAll("th, td")).map(function(cell) {
        return normalizeText(cell.textContent || "");
      });
    }).filter(function(cells) {
      return cells.length > 0 && cells.some(Boolean);
    });
  }

  function sourceOwnedReaderMissingStructuredMaterial(primaryRoot, recoveredRoot) {
    var primaryCode = Array.from(primaryRoot.querySelectorAll("pre")).map(function(pre) {
      return articleCodeText(pre.textContent || "");
    }).filter(Boolean);
    var recoveredCode = Array.from(recoveredRoot.querySelectorAll("pre")).map(function(pre) {
      return articleCodeText(pre.textContent || "");
    }).filter(Boolean);
    var codePosition = 0;
    var missingCode = recoveredCode.some(function(example) {
      while (codePosition < primaryCode.length) {
        if (primaryCode[codePosition++] === example) return false;
      }
      return true;
    });

    var primaryTables = Array.from(primaryRoot.querySelectorAll("table")).map(sourceOwnedReaderTableRows).filter(function(rows) {
      return rows.length > 0;
    });
    var recoveredTables = Array.from(recoveredRoot.querySelectorAll("table")).map(sourceOwnedReaderTableRows).filter(function(rows) {
      return rows.length > 0;
    });
    var tablePosition = 0;
    var missingTable = recoveredTables.some(function(rows) {
      while (tablePosition < primaryTables.length) {
        if (JSON.stringify(primaryTables[tablePosition++]) === JSON.stringify(rows)) return false;
      }
      return true;
    });
    return missingCode || missingTable;
  }

  function supplementOwnedReaderStructuredMaterial(content) {
    if (!content || content.contentType !== "article" || !content.readerMode || content.markdown ||
        content.hostAware || content.docsLike || content.legalProvision || homepageRootPath() || !content.html) return content;

    var owner = sourceOwnedReaderBodyOwner(content, content.sourceOwnedReaderBodyParagraphSources);
    if (!owner) return content;
    var primaryRoot = document.createElement("div");
    primaryRoot.innerHTML = content.html;
    var visibleOwner = cleanClone(visibilityPrunedClone(owner, document));
    visibleOwner.querySelectorAll("[aria-hidden='true'], [inert]").forEach(function(node) { node.remove(); });
    stripInertCustomUiElements(visibleOwner);
    prepareFallbackInlineProse(visibleOwner);
    cleanupGenericArticleRoot(visibleOwner);
    prepareFallbackInlineProse(visibleOwner);
    cleanupFallbackArticleChrome(visibleOwner);
    if (!sourceOwnedReaderMissingStructuredMaterial(primaryRoot, visibleOwner) ||
        !articleMaterialPreserved(primaryRoot, visibleOwner)) return content;

    content.html = visibleOwner.innerHTML;
    content.textContent = normalizeText(visibleOwner.textContent || "");
    return content;
  }
