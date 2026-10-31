  function listContent(metadata, options) {
    options = options || {};
    var pageTitles = [metadata.title, document.title];
    var best = bestListExtraction(metadata, pageTitles, options);
    sourceOwnedRecordMediaForItems(options.repeatedRecordCollection, best);
    var rankedMarkdown = best.markdown;
    if (!best.sectionCount) {
      var descriptions = listDescriptionParts(best.root, best.items, {
        preserveUnrepresentedText: true,
        sourceOwnedDescriptionNodes: best.sourceOwnedDescriptionNodes,
        sourceOwnedResultCountNodes: best.sourceOwnedResultCountNodeSet
      });
      descriptions = descriptions.concat(sourceOwnedResultStatusDescriptionParts(best.sourceOwnedResultStatusNodes, best.root));
      best.descText = descriptions.map(function(part) { return part.markdown; }).join("\n\n");
      best.renderedSections = {
        regions: [{ node: best.root, label: "", cards: best.items }]
      };
      best.renderedDescriptions = descriptions;
      best.markdown = sectionedListMarkdownWithDescriptions(best.renderedSections, descriptions) || listMarkdown(best.items);
    }
    applyListTableMarkdown(best);
    if (best.items.length >= 2 && best.items.every(function(item) { return item.sourceOrderedStructuredCard; })) {
      best.markdown = markdownFor(best.root.innerHTML);
    }
    applyListSourceTableContext(best);
    preserveListBodyImageMarkdown(best);
    applyListFooterDataMarkdown(best);
    var namedHeadingCount = Array.prototype.filter.call(best.root.querySelectorAll("h2, h3, h4"), function(heading) {
      return !heading.closest("article, li, [class*='card' i], [class*='item' i]");
    }).length;
    var rootContext = normalizeText([location.pathname, document.title, metadata.title].join(" "));
    var docsRoot = /\b(?:docs?|documentation|api|library|libraries|reference|class|module|namespace|package)\b/i.test(rootContext);
    var substantialRoot = homepageRootPath() && !docsRoot && best.items.length >= 10 && normalizeText(rankedMarkdown).length >= 3000;
    var broadRootEvidence = substantialRoot ? 2 : 0;
    var headingRootEvidence = substantialRoot ? namedHeadingCount : 0;
    var portalSectionCount = Math.max(best.sectionCount || 0, headingRootEvidence, broadRootEvidence);
    var portalEvidenceItemCount = best.portalEvidenceItemCount == null ? best.items.length : best.portalEvidenceItemCount;
    var materializedItemCount = best.portalEvidenceMaterializedItemCount == null ? best.items.filter(function(item) {
      return !!materializedHttpUrl(item && item.url);
    }).length : best.portalEvidenceMaterializedItemCount;
    var portalEvidence = options.portalRoot && portalSectionCount >= 2 && portalEvidenceItemCount >= 4 && materializedItemCount >= 2 ? {
      namedSectionCount: portalSectionCount,
      canonicalCardCount: portalEvidenceItemCount
    } : null;
    var excerpt = portalEvidence && metadata.declaredDescription || (best.items[0] ? best.items[0].text : metadata.excerpt);
    appendListFooterContactInformation(best, options.repeatedRecordCollection);

    var result = listItemsContentResult(metadata, {
      title: metadata.title || document.title,
      excerpt: excerpt,
      html: listHtmlWithoutUnsafeDestinations(best.root, best.sourceFooterContactGroups),
      textContent: best.markdown,
      markdown: best.markdown,
      items: best.items,
      portalRootEvidence: portalEvidence
    });
    result.listExtraction = best;
    if (best.sourceFooterContactGroups) sourceOwnedFooterContactResults.set(result, result.html);
    result.listArbitrationMarkdown = rankedMarkdown;
    if (best.sectionMarkdownWithDescription) result.sectionMarkdownWithDescription = best.sectionMarkdownWithDescription;
    return result;
  }
