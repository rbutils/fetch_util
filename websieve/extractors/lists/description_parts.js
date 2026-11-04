  function listDescriptionCardNode(node, items, options, itemValues, primaryReferences, primaryUrls) {
    if (!items) return closestGenericListCard(node);

    var completeRecord = items.find(function(item) {
      return (item.sourceOrderedRepeatedRecord || item.sourceOrderedStructuredCard || item.sourceOrderedHeadingCard) &&
        item.card && item.card.contains(node);
    });
    if (completeRecord) return completeRecord.card;

    var heading = /^H[1-6]$/.test(node.tagName || "");
    var text = heading ? listHeadingText(node) : normalizeText(node.textContent || "");
    var unlinkedHeading = heading && !node.closest("a[href]") && !node.querySelector("a[href]");
    var headingOwner = unlinkedHeading && closestGenericListFieldCard(node);
    var represented = text && items.find(function(item, index) {
      if (unlinkedHeading && (!headingOwner || item.card !== headingOwner)) return false;
      var values = itemValues[index];
      return values.some(function(value) {
        return value === text || (!heading && value.indexOf(text) >= 0);
      }) && listDescriptionReferencesRepresented(node, values, primaryReferences, primaryUrls);
    });
    var recordCard;
    var sectionLabels;

    if (represented) {
      if (represented.card) return represented.card;
      if (options && options.suppressRepresentedText) return node;
    }

    if (options && options.excludeRecordCards) {
      recordCard = closestGenericListCard(node);
      if (recordCard && (recordCard !== node || listDescriptionRecordClass(node))) return recordCard;
    }

    if (options && options.sectionLabels && heading) {
      sectionLabels = options.sectionLabels.map(function(label) {
        return normalizeText(label).toLowerCase();
      });
      if (sectionLabels.indexOf(text.toLowerCase()) !== -1) return node;
      if (itemValues.some(function(values, index) {
        if (unlinkedHeading && (!headingOwner || items[index].card !== headingOwner)) return false;
        return values.some(function(value) {
          return value.length >= 12 && text.indexOf(value) !== -1;
        });
      })) return node;
    }

    if (options && options.preserveUnrepresentedText) return null;
    return listDescriptionDuplicateCard(node, items);
  }

  function listDescriptionRecordHeading(node, text, primaryReferences, primaryUrls) {
    if (!/^H[1-6]$/.test(node.tagName || "") || !closestGenericListFieldCard(node)) return "";
    var links = [];
    var ancestor = node.closest("a[href]");
    if (ancestor) links.push(ancestor);
    Array.prototype.forEach.call(node.querySelectorAll("a[href]"), function(link) {
      if (links.indexOf(link) === -1) links.push(link);
    });
    var destinations = links.map(function(link) {
      return materializedHttpUrl(link.getAttribute("href"));
    }).filter(Boolean).filter(function(url, index, urls) { return urls.indexOf(url) === index; });
    if (destinations.length !== 1 ||
        (!primaryReferences.has(destinations[0]) &&
         !(primaryUrls && primaryUrls.has(listCanonicalKey(destinations[0]))))) return "";
    if (text.length < minimumListTitleLength(text) || genericListControlText(text) || looksLikeFooterLink(text, destinations[0])) return "";
    return "- " + markdownLink(text, destinations[0]);
  }

  function listDescriptionFigureParts(root, items) {
    if (!items || !items.length) return [];
    var figures = Array.from(root.querySelectorAll("figure")).filter(function(figure) {
      if (figure.closest("a[href], nav, header, footer, form, menu, [role='navigation'], [role='menu'], [role='toolbar'], [role='dialog']") ||
          listCardNodeHidden(figure) || listNodeWithinClosedDisclosure(figure)) return false;
      var caption = figure.querySelector("figcaption");
      if (!caption || caption.closest("figure") !== figure) return false;
      var heading = Array.from(caption.querySelectorAll("h1, h2, h3, h4, h5, h6")).some(function(node) {
        return node.closest("figure") === figure && normalizeText(node.textContent);
      });
      var image = Array.from(figure.querySelectorAll("img")).some(function(node) {
        var source = node.getAttribute("src") || node.getAttribute("data-src") || node.getAttribute("data-lazy-src");
        return node.closest("figure") === figure && !node.closest("a[href]") && !listCardNodeHidden(node) && materializedHttpUrl(source);
      });
      if (!heading || !image) return false;
      return !items.some(function(item) {
        var source = item.sourceNode || item.orderNode || item.card;
        return source && figure.contains(source);
      });
    });
    return figures.filter(function(figure) {
      return !figures.some(function(owner) { return owner !== figure && owner.contains(figure); });
    }).map(function(figure) {
      var clone = figure.cloneNode(true);
      pruneListCardVisibility(figure, clone);
      clone.querySelectorAll("h1 br, h2 br, h3 br, h4 br, h5 br, h6 br").forEach(function(lineBreak) {
        lineBreak.replaceWith(document.createTextNode(" "));
      });
      return { node: figure, markdown: markdownFor(clone.outerHTML).trim(), descriptiveFigure: true };
    }).filter(function(part) { return part.markdown; });
  }

  function listDescriptionImageParts(root, items, figures) {
    if (!items || !items.length) return [];
    return Array.from(root.querySelectorAll("img[src]")).filter(function(image) {
      if (!materializedHttpUrl(image.getAttribute("src")) || listCardNodeHidden(image) ||
          listNodeWithinClosedDisclosure(image) ||
          image.closest("p, blockquote, h1, h2, h3, h4, h5, h6, pre, code, kbd, samp, nav, header, footer, aside, form, button, menu, [role='navigation'], [role='menu'], [role='toolbar'], [role='dialog'], [role='tab'], [role='menuitem']")) return false;
      if (figures.some(function(part) { return part.node.contains(image); }) || items.some(function(item) {
        return [item.card, item.contentCard, item.sourceNode].some(function(owner) {
          return owner && owner.contains(image);
        });
      })) return false;
      var link = image.closest("a[href]");
      var control = image.closest("[role='button']");
      if (control && (control !== link || materializedHttpUrl(link.getAttribute("href")) !==
          materializedHttpUrl(image.getAttribute("src")))) return false;
      if (!link) return true;
      if (!materializedHttpUrl(link.getAttribute("href")) || link.querySelectorAll("img").length !== 1) return false;
      var remainder = link.cloneNode(true);
      remainder.querySelector("img").remove();
      return !normalizeText(remainder.textContent) &&
        !remainder.querySelector("svg, picture, video, audio, iframe, input, button, select, textarea");
    }).map(function(image) {
      var link = image.closest("a[href]");
      return { node: image, markdown: markdownFor((link || image).outerHTML).trim(), descriptiveImage: true };
    }).filter(function(part) { return part.markdown; });
  }

  function listDescriptionProgramPart(program, items) {
    if (program.closest("a[href], table, nav, form, button, menu, dialog, [role='navigation'], [role='menu'], [role='toolbar'], [role='dialog'], [role='button'], [role='tab'], [role='menuitem']")) return null;
    if ((items || []).some(function(item) {
      return [item.card, item.contentCard, item.sourceNode].some(function(owner) {
        return owner && owner.contains(program);
      });
    })) return null;
    var sourceClones = new Map();
    var clone = visibilityPrunedClone(program, document, sourceClones);
    restorePrunedNamedCodeTargets(program, sourceClones);
    var markdown = markdownFor(clone.outerHTML).trim();
    return markdown ? { node: program, markdown: markdown, descriptiveProgram: true } : null;
  }

  function listDescriptionParts(root, items, options) {
    var unselectedRecords = options && options.preserveUnselectedRecordMaterial ?
      listUnselectedArticleDescriptions(root, items) : { parts: [], covered: new WeakSet() };
    var outerArticles = listOuterArticleDescriptions(root, items);
    var figureParts = listDescriptionFigureParts(root, items).filter(function(part) {
      return !outerArticles.covered.has(part.node) && !unselectedRecords.covered.has(part.node);
    });
    var listParts = options && options.includeNarrativeLists === false ? [] : listDescriptionListParts(root, items).filter(function(part) {
      return !outerArticles.covered.has(part.node) && !unselectedRecords.covered.has(part.node) &&
        !figureParts.some(function(figure) { return figure.node.contains(part.node); });
    });
    var descParts = unselectedRecords.parts.concat(outerArticles.parts, figureParts, listParts);
    var hasItems = items && items.length > 0;
    var includeInlineProse = hasItems && options && options.includeInlineProse;
    var primaryUrls = new Set((items || []).map(function(item) {
      var url = materializedHttpUrl(item.url || "");
      return url && listCanonicalKey(url);
    }).filter(Boolean));
    var primaryRecordKeys = listPrimaryRecordKeys(items);
    var primaryReferences = new Set((items || []).map(function(item) {
      return materializedHttpUrl(item.url || "");
    }).filter(Boolean));
    var sourceOwnedResultCountNodes = options && options.sourceOwnedResultCountNodes;
    var readTableHeaders = tableIndexHeaderReader();
    var itemValues = items && items.map(function(item) {
      return listDescriptionItemValues(item, primaryUrls, primaryRecordKeys, readTableHeaders);
    });
    var preserveSourceTitle = (items || []).some(function(item) { return item.sourceOwnedNarrativeRoute; });
    var pageTitles = (options && options.pageTitles || []).map(function(title) {
      return normalizeText(title).toLowerCase();
    }).filter(Boolean);
    var selector = hasItems ? "h1, h2, h3, h4, h5, h6, p, blockquote, pre" : "h1, h2, h3, p, blockquote";
    root.querySelectorAll(selector + (includeInlineProse ? ", div" : "")).forEach(function(el) {
      if (listCardNodeHidden(el) || listNodeWithinClosedDisclosure(el)) return;
      if (outerArticles.covered.has(el) || unselectedRecords.covered.has(el)) return;
      if (figureParts.concat(listParts).some(function(part) { return part.node.contains(el); })) return;
      if (sourceOwnedResultCountNodes && sourceOwnedResultCountNodes.has(el)) {
        var resultCountMarkdown = markdownFor(el.outerHTML).trim();
        if (resultCountMarkdown) descParts.push({ node: el, markdown: resultCountMarkdown });
        return;
      }
      if (el.parentElement && el.parentElement.closest("blockquote, pre")) return;
      if (el.tagName === "PRE") {
        var programPart = listDescriptionProgramPart(el, items);
        if (programPart) descParts.push(programPart);
        return;
      }
      var quote = el.tagName === "BLOCKQUOTE";
      var inlineProse = el.tagName === "DIV";
      if (inlineProse && !listInlineDescriptionNode(el)) return;
      if (listDescriptionCardNode(el, items, options, itemValues, primaryReferences, primaryUrls)) return;
      var leadPart = options && options.includeOwnedShortLeads === false ? null : listDescriptionLeadPart(el, root, items);
      if (leadPart) {
        descParts.push(leadPart);
        return;
      }
      var heading = /^H[1-6]$/.test(el.tagName);
      var text = heading ? listHeadingText(el) : normalizeText(el.textContent);
      var recordHeading = listDescriptionRecordHeading(el, text, primaryReferences, primaryUrls);
      if (recordHeading) {
        descParts.push({ node: el, markdown: recordHeading });
        return;
      }
      if (quote) {
        var quotation = el.cloneNode(true);
        pruneListCardVisibility(el, quotation);
        var quoteMarkdown = markdownFor(quotation.outerHTML).trim();
        if (quoteMarkdown) descParts.push({ node: el, markdown: quoteMarkdown });
        return;
      }
      var linkedSectionHeading = heading && listLinkedSectionHeading(el, root, items, primaryUrls);
      var pageHeading = heading && !el.closest("a[href]") && !el.querySelector("a[href]");
      var weatherOwner = pageHeading && el.closest("[class*='weather' i], [id*='weather' i]");
      if (weatherOwner && weatherModuleText(weatherOwner.textContent)) pageHeading = false;
      var sourceOwnedDescription = options && options.sourceOwnedDescriptionNodes && options.sourceOwnedDescriptionNodes.has(el);
      // Linked record titles keep their existing admission, not page-label treatment.
      if (heading && !pageHeading && !/^H[1-3]$/.test(el.tagName)) return;
      if (heading && pageTitles.indexOf(text.toLowerCase()) !== -1 &&
          !(preserveSourceTitle && pageHeading && el.tagName === "H1")) return;
       if (!(hasItems && (pageHeading || linkedSectionHeading || inlineProse)) && !(options && options.preserveTextLengths) &&
           !sourceOwnedDescription && (text.length < 30 || text.length > 2000)) return;
      if (listNoiseText(text) || cookieNoticeText(text) || legalFooterText(text) || weatherModuleText(text)) return;
      var links = el.querySelectorAll("a[href]").length;
      var words = text.split(/\s+/).length;
      if (linkedSectionHeading || links <= 1 || (links / words) < 0.3) {
        var richPart = !heading && !(options && options.includeRichProse === false) && listDescriptionRichProsePart(el);
        if (richPart) {
          descParts.push(richPart);
          return;
        }
        var prefix = heading ? "#".repeat(Number(el.tagName.slice(1))) + " " : "";
        if (linkedSectionHeading) {
          text = markdownFor(el.innerHTML).trim();
        } else if (!heading && links) {
          var description = el.cloneNode(true);
          description.querySelectorAll("a[href]").forEach(function(link) {
            link.replaceWith(document.createTextNode(markdownLink(normalizeText(link.textContent), link.getAttribute("href"))));
          });
          text = normalizeText(description.textContent);
        }
        descParts.push({ node: el, markdown: prefix + text });
      }
    });
    var imageParts = listDescriptionImageParts(root, items, figureParts.concat(listParts)).filter(function(part) {
      return !outerArticles.covered.has(part.node) && !unselectedRecords.covered.has(part.node);
    });
    var creditParts = listPublicationCreditDescriptionParts(root, items, descParts);
    if (imageParts.length || creditParts.length || outerArticles.parts.length || unselectedRecords.parts.length || listParts.length) {
      descParts = descParts.concat(imageParts, creditParts).sort(function(left, right) {
        var position = left.node.compareDocumentPosition(right.node);
        return position & 4 ? -1 : position & 2 ? 1 : 0;
      });
    }
    return descParts;
  }

  function listDescriptionMarkdown(root, items, options) {
    // Typed blocks belong to structured serialization, not prose/scoring evidence.
    var proseOptions = Object.assign({}, options, {
      includeNarrativeLists: false, includeOwnedShortLeads: false, includeRichProse: false
    });
    return listDescriptionParts(root, items, proseOptions).map(function(part) {
      return part.markdown;
    }).join("\n\n");
  }

  function listMarkdownWithDescription(descText, items) {
    var linkMarkdown = listMarkdown(items);
    return descText ? descText + (linkMarkdown ? "\n\n" + linkMarkdown : "") : linkMarkdown;
  }
