  function listHtmlWithoutUnsafeDestinations(root) {
    var clone = safeDeepClone(root, document);
    clone.querySelectorAll("a[href]").forEach(function(link) {
      if (!materializedHttpUrl(link.getAttribute("href"))) link.removeAttribute("href");
    });
    return clone.innerHTML;
  }

  function buildListExtraction(node, pageTitles, options) {
    options = options || {};
    var repeatedCollection = options.repeatedRecordCollection;
    var primaryMainSourceNode = repeatedCollection && repeatedCollection.primaryMain;
    var collectionOwnerSourceNode = repeatedCollection && repeatedCollection.owner;
    var renderOwnerSourceNode = repeatedCollection && repeatedCollection.renderOwner;
    var cloneSource = primaryMainSourceNode &&
      (node === document.body || node === primaryMainSourceNode || primaryMainSourceNode.contains(node)) ?
      primaryMainSourceNode : (renderOwnerSourceNode && renderOwnerSourceNode.contains(node) ? renderOwnerSourceNode : node);
    var elementMap = repeatedCollection || options.institutionalCaseIndex || options.materialResultsOwner ? new Map() : null;
    var clonedSourceRoot = visibleListClone(cloneSource, options.preservedRoots, elementMap);
    var clonedPrimaryMain = elementMap && primaryMainSourceNode && elementMap.get(primaryMainSourceNode);
    var clonedCollectionOwner = elementMap && collectionOwnerSourceNode && elementMap.get(collectionOwnerSourceNode);
    var clonedRenderOwner = elementMap && renderOwnerSourceNode && elementMap.get(renderOwnerSourceNode);
    var clonedCandidate = elementMap && node !== document.body && node !== primaryMainSourceNode && elementMap.get(node);
    var candidateMapped = node === document.body || node === primaryMainSourceNode ||
      (clonedCandidate && clonedSourceRoot.contains(clonedCandidate));
    var candidateSourceOwned = node === document.body || node === primaryMainSourceNode ||
      (renderOwnerSourceNode && renderOwnerSourceNode.contains(node));
    var primaryMainMapped = !!(primaryMainSourceNode && clonedPrimaryMain && clonedRenderOwner &&
      (clonedPrimaryMain === clonedSourceRoot || clonedSourceRoot.contains(clonedPrimaryMain)) &&
      clonedPrimaryMain.contains(clonedRenderOwner) && candidateMapped && candidateSourceOwned);
    var collectionOwnerMapped = !!(repeatedCollection && collectionOwnerSourceNode && clonedCollectionOwner && clonedRenderOwner &&
      clonedSourceRoot.contains(clonedCollectionOwner) && clonedSourceRoot.contains(clonedRenderOwner) &&
      clonedRenderOwner.contains(clonedCollectionOwner) && candidateMapped && candidateSourceOwned &&
      (!primaryMainSourceNode || (primaryMainMapped && clonedPrimaryMain.contains(clonedCollectionOwner))));
    var root = primaryMainMapped ? clonedPrimaryMain : clonedSourceRoot;
    var extractionRoot = collectionOwnerMapped && !primaryMainMapped ? clonedCollectionOwner : root;
    var materialResultsProof = options.materialResultsOwner && node === options.materialResultsOwner.owner ?
      materialResultsCloneProof(options.materialResultsOwner, elementMap, root) : null;
    var clonedRenderNodes = repeatedCollection && elementMap ?
      (repeatedCollection.renderNodes || []).map(function(sourceNode) { return elementMap.get(sourceNode); }) : [];
    var sourceOwnedDescriptionSources = [];
    (repeatedCollection && repeatedCollection.contextNodes || []).forEach(function(sourceNode) {
      var paragraphs = sourceNode.matches("p") ? [sourceNode] :
        (pageOwnedOverviewSection(sourceNode) ? Array.from(sourceNode.querySelectorAll("p")) : []);
      paragraphs.forEach(function(paragraph) {
        if (!elementSubtreeHidden(paragraph) && !paragraph.querySelector("a[href]")) {
          sourceOwnedDescriptionSources.push(paragraph);
        }
      });
    });
    var clonedSourceOwnedDescriptionNodes = elementMap ? sourceOwnedDescriptionSources.map(function(sourceNode) {
      return elementMap.get(sourceNode);
    }).filter(Boolean) : [];
    var producerProvenCardNodes = options.institutionalCaseIndex && elementMap ?
      options.institutionalCaseIndex.cardNodes.map(function(card) { return elementMap.get(card); }).filter(Boolean) : null;
    if (materialResultsProof) producerProvenCardNodes = (producerProvenCardNodes || []).concat(materialResultsProof.cardNodes);
    cleanupListRoot(root, producerProvenCardNodes,
      collectionOwnerMapped && !primaryMainMapped ? clonedRenderNodes : null);
    if (collectionOwnerMapped && !primaryMainMapped) {
      var renderNodesMapped = clonedRenderNodes.length === (repeatedCollection.renderNodes || []).length &&
        clonedRenderNodes.every(function(renderNode) {
          return renderNode && root.contains(renderNode) &&
            (renderNode === clonedRenderOwner || renderNode.parentElement === clonedRenderOwner);
        });
      if (!renderNodesMapped) {
        collectionOwnerMapped = false;
        root = clonedSourceRoot;
        extractionRoot = root;
      } else if (clonedRenderOwner !== clonedCollectionOwner) {
        var boundedRoot = document.createElement("div");
        clonedRenderNodes.forEach(function(renderNode) { boundedRoot.appendChild(renderNode); });
        root = boundedRoot;
      } else {
        root = clonedCollectionOwner;
      }
    }
    var sourceOwnedResultStatusNodes = sourceOwnedResultStatusClones(repeatedCollection, elementMap);
    if (collectionOwnerMapped) {
      root = sourceOwnedResultStatusRoot(root, repeatedCollection, clonedCollectionOwner,
        clonedRenderNodes, sourceOwnedResultStatusNodes, elementMap);
    }
    var sourceOwnedResultCountNodeSet = collectionOwnerMapped ?
      sourceOwnedResultCountDescriptionNodes(sourceOwnedResultStatusNodes, root) : null;
    var sourceOwnedStatusDescriptions = sourceOwnedResultStatusDescriptionParts(sourceOwnedResultStatusNodes, root);
    var extractionOptions = options;
    if (repeatedCollection && elementMap) {
      var mappedRecords = repeatedCollection.records.map(function(record) {
        var mappedNode = elementMap.get(record.node);
        return mappedNode ? Object.assign({}, record, { node: mappedNode }) : null;
      });
      if (mappedRecords.every(Boolean)) {
        extractionOptions = Object.assign({}, options, {
          repeatedRecordCollection: Object.assign({}, repeatedCollection, { records: mappedRecords })
        });
      }
    }
    if (options.institutionalCaseIndex && elementMap) {
      var producerTitleLinks = options.institutionalCaseIndex.titleLinks.map(function(link) {
        return elementMap.get(link);
      }).filter(Boolean);
      extractionOptions = Object.assign({}, extractionOptions, {
        producerProvenCardTitles: preserveStructuredCardLinks(root, {
          producerProvenTitleLinks: producerTitleLinks,
          proofOnly: true
        })
      });
    }
    if (materialResultsProof) {
      extractionOptions = Object.assign({}, extractionOptions, {
        producerProvenCardTitles: materialResultsProof.titleLinks
      });
    }
    if (primaryMainMapped && clonedCandidate && !root.contains(clonedCandidate)) {
      primaryMainMapped = false;
      root = clonedSourceRoot;
      extractionRoot = root;
    }
    var sourceOwnedDescriptionNodes = new Set(clonedSourceOwnedDescriptionNodes.filter(function(node) {
      return collectionOwnerMapped && root.contains(node);
    }));
    var sectioned = sectionedListExtraction(extractionRoot);

    var items = materialResultsRetainProvenItems(extractListItems(extractionRoot, extractionOptions), materialResultsProof);
    mergeDuplicateRecordAuthorContext(root, items);
    var itemQuality = listItemsQualityScore(items);
    var descText = collectionOwnerMapped ? listDescriptionMarkdown(root, items, {
      sourceOwnedDescriptionNodes: sourceOwnedDescriptionNodes,
      sourceOwnedResultCountNodes: sourceOwnedResultCountNodeSet
    }) : listDescriptionMarkdown(root);
    var fallbackItems = materialResultsRetainProvenItems(
      extractFallbackHeadlineItems(extractionRoot, items.__fetchUtilSupportingLinks), materialResultsProof);
    mergeDuplicateRecordAuthorContext(root, fallbackItems);
    var fallbackQuality = listItemsQualityScore(fallbackItems);
    if ((items.length < 3 && fallbackItems.length > items.length) || fallbackQuality > itemQuality + 180) {
      items = fallbackWithEditorialAsideItems(items, fallbackItems);
      itemQuality = listItemsQualityScore(items);
    }

    var flatCoverage = sameRootFlatSectionCoverage(sectioned, items) ||
      supplementalSameRootSectionCoverage(sectioned, items, fallbackItems, extractionRoot, pageTitles);
    if (sectioned && !flatCoverage) {
      var sectionDescriptionParts = listDescriptionParts(root, sectioned.items, {
        excludeRecordCards: true,
        includeInlineProse: true,
        pageTitles: pageTitles,
        preserveTextLengths: true,
        sectionLabels: sectioned.regions.map(function(region) { return region.label; }),
        suppressRepresentedText: true,
        sourceOwnedDescriptionNodes: sourceOwnedDescriptionNodes,
        sourceOwnedResultCountNodes: sourceOwnedResultCountNodeSet
      });
      sectionDescriptionParts = sectionDescriptionParts.concat(sourceOwnedStatusDescriptions);
      var sectionMarkdownWithDescription = sectionedListMarkdownWithDescriptions(sectioned, sectionDescriptionParts);

      return {
        sourceNode: node,
        root: root,
        sourceOwnedDescriptionNodes: sourceOwnedDescriptionNodes,
        primaryMainMapped: primaryMainMapped,
        primaryMainSourceNode: primaryMainMapped ? primaryMainSourceNode : null,
        collectionOwnerMapped: collectionOwnerMapped,
        collectionOwnerSourceNode: collectionOwnerMapped ? collectionOwnerSourceNode : null,
        renderOwnerSourceNode: collectionOwnerMapped ? renderOwnerSourceNode : null,
        items: sectioned.items,
        descText: "",
        sectionMarkdownWithDescription: sectionMarkdownWithDescription,
        sourceOwnedResultStatusNodes: sourceOwnedResultStatusNodes,
        sourceOwnedResultCountNodeSet: sourceOwnedResultCountNodeSet,
        renderedSections: sectioned,
        renderedDescriptions: sectionDescriptionParts,
        markdown: sectioned.markdown,
        score: sectioned.score,
        sectionCount: sectioned.regions.length,
        sectionRank: (sectioned.regions.length * 100000) - root.querySelectorAll("a[href]").length
      };
    }
    if (flatCoverage) items = flatCoverage.items;
    if (flatCoverage) mergeDuplicateRecordAuthorContext(root, items);
    if (flatCoverage && !flatCoverage.markdown) {
      var flatDescriptions = listDescriptionParts(root, items, {
        includeInlineProse: true, preserveTextLengths: true,
        pageTitles: pageTitles, preserveUnrepresentedText: true,
        sectionLabels: sectioned.regions.map(function(region) { return region.label; }),
        suppressRepresentedText: true,
        sourceOwnedDescriptionNodes: sourceOwnedDescriptionNodes,
        sourceOwnedResultCountNodes: sourceOwnedResultCountNodeSet
      });
      flatDescriptions = (flatCoverage.headingParts || []).concat(flatDescriptions);
      flatDescriptions = flatDescriptions.concat(sourceOwnedStatusDescriptions);
      flatCoverage.renderedSections = {
        regions: [{ node: root, label: "", cards: items }]
      };
      flatCoverage.renderedDescriptions = flatDescriptions;
      flatCoverage.markdown = sectionedListMarkdownWithDescriptions(flatCoverage.renderedSections, flatDescriptions);
    }

    var itemMarkdown = flatCoverage ? sameRootFlatListMarkdown(items, flatCoverage.headings) : listMarkdown(items);
    var markdown = descText ? descText + (itemMarkdown ? "\n\n" + itemMarkdown : "") : itemMarkdown;
    if (flatCoverage && flatCoverage.markdown) markdown = flatCoverage.markdown;
    if (!flatCoverage && normalizeText(markdown).length < 120 &&
        (fallbackItems.length > items.length || fallbackQuality > itemQuality)) {
      items = fallbackWithEditorialAsideItems(items, fallbackItems);
      itemQuality = listItemsQualityScore(items);
      markdown = listMarkdownWithDescription(descText, items);
    }

    return {
      sourceNode: node,
      root: root,
      sourceOwnedDescriptionNodes: sourceOwnedDescriptionNodes,
      primaryMainMapped: primaryMainMapped,
      primaryMainSourceNode: primaryMainMapped ? primaryMainSourceNode : null,
      collectionOwnerMapped: collectionOwnerMapped,
      collectionOwnerSourceNode: collectionOwnerMapped ? collectionOwnerSourceNode : null,
      renderOwnerSourceNode: collectionOwnerMapped ? renderOwnerSourceNode : null,
      items: items,
      descText: descText,
      markdown: markdown,
      sourceOwnedResultStatusNodes: sourceOwnedResultStatusNodes,
      sourceOwnedResultCountNodeSet: sourceOwnedResultCountNodeSet,
      renderedSections: flatCoverage && flatCoverage.renderedSections,
      renderedDescriptions: flatCoverage && flatCoverage.renderedDescriptions,
      score: flatCoverage ? sectioned.score :
        itemQuality + (items.length * 80) + Math.min(descText.length, 4000),
      sectionCount: flatCoverage ? sectioned.regions.length : 0,
      sectionRank: flatCoverage ?
        (sectioned.regions.length * 100000) - root.querySelectorAll("a[href]").length : 0,
      portalEvidenceItemCount: flatCoverage ? sectioned.items.length : null,
      portalEvidenceMaterializedItemCount: flatCoverage ? materializedListItemCount(sectioned.items) : null
    };
  }

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
    if (structuredListTables(best.root).length) {
      best.sourceTableMarkdown = markdownFor(best.root.innerHTML);
      best.markdown = best.sourceTableMarkdown;
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
    var portalEvidenceItemCount = best.portalEvidenceItemCount == null ? best.items.length : best.portalEvidenceItemCount;
    var materializedItemCount = best.portalEvidenceMaterializedItemCount == null ? best.items.filter(function(item) {
      return !!materializedHttpUrl(item && item.url);
    }).length : best.portalEvidenceMaterializedItemCount;

    var result = listItemsContentResult(metadata, {
      title: metadata.title || document.title,
      excerpt: best.items[0] ? best.items[0].text : metadata.excerpt,
      html: listHtmlWithoutUnsafeDestinations(best.root),
      textContent: best.markdown,
      markdown: best.markdown,
      items: best.items,
      portalRootEvidence: options.portalRoot && portalSectionCount >= 2 && portalEvidenceItemCount >= 4 && materializedItemCount >= 2 ? {
        namedSectionCount: portalSectionCount,
        canonicalCardCount: portalEvidenceItemCount
      } : null
    });
    result.listExtraction = best;
    result.listArbitrationMarkdown = rankedMarkdown;
    if (best.sectionMarkdownWithDescription) result.sectionMarkdownWithDescription = best.sectionMarkdownWithDescription;
    return result;
  }
