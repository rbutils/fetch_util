  function listDescriptionCardNode(node, items, options, itemValues, primaryReferences) {
    if (!items) return closestGenericListCard(node);

    var text = normalizeText(node.textContent || "");
    var heading = /^H[1-6]$/.test(node.tagName || "");
    var unlinkedHeading = heading && !node.closest("a[href]") && !node.querySelector("a[href]");
    var headingOwner = unlinkedHeading && closestGenericListFieldCard(node);
    var represented = text && items.find(function(item, index) {
      if (unlinkedHeading && (!headingOwner || item.card !== headingOwner)) return false;
      var values = itemValues[index];
      return values.some(function(value) {
        return value === text || (!heading && value.indexOf(text) >= 0);
      }) && listDescriptionReferencesRepresented(node, values, primaryReferences);
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

  function listDescriptionRecordHeading(node, text, primaryReferences) {
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
    if (destinations.length !== 1 || !primaryReferences.has(destinations[0])) return "";
    if (text.length < minimumListTitleLength(text) || genericListControlText(text) || looksLikeFooterLink(text, destinations[0])) return "";
    return "- " + markdownLink(text, destinations[0]);
  }

  function listDescriptionParts(root, items, options) {
    var descParts = [];
    var hasItems = items && items.length > 0;
    var includeInlineProse = hasItems && options && options.includeInlineProse;
    var primaryUrls = new Set((items || []).map(function(item) {
      var url = materializedHttpUrl(item.url || "");
      return url && listCanonicalKey(url);
    }).filter(Boolean));
    var primaryReferences = new Set((items || []).map(function(item) {
      return materializedHttpUrl(item.url || "");
    }).filter(Boolean));
    var itemValues = items && items.map(function(item) {
      return listDescriptionItemValues(item, primaryUrls);
    });
    var pageTitles = (options && options.pageTitles || []).map(function(title) {
      return normalizeText(title).toLowerCase();
    }).filter(Boolean);
    var selector = hasItems ? "h1, h2, h3, h4, h5, h6, p, blockquote" : "h1, h2, h3, p, blockquote";
    root.querySelectorAll(selector + (includeInlineProse ? ", div" : "")).forEach(function(el) {
      if (el.parentElement && el.parentElement.closest("blockquote")) return;
      var quote = el.tagName === "BLOCKQUOTE";
      var inlineProse = el.tagName === "DIV";
      if (inlineProse && !listInlineDescriptionNode(el)) return;
      if (quote && listCardNodeHidden(el)) return;
      if (listDescriptionCardNode(el, items, options, itemValues, primaryReferences)) return;
      var text = normalizeText(el.textContent);
      var heading = /^H[1-6]$/.test(el.tagName);
      var recordHeading = listDescriptionRecordHeading(el, text, primaryReferences);
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
      // Linked record titles keep their existing admission, not page-label treatment.
      if (heading && !pageHeading && !/^H[1-3]$/.test(el.tagName)) return;
      if (heading && pageTitles.indexOf(text.toLowerCase()) !== -1) return;
      if (!(hasItems && (pageHeading || linkedSectionHeading || inlineProse)) && !(options && options.preserveTextLengths) && (text.length < 30 || text.length > 2000)) return;
      if (listNoiseText(text) || cookieNoticeText(text) || legalFooterText(text) || weatherModuleText(text)) return;
      var links = el.querySelectorAll("a[href]").length;
      var words = text.split(/\s+/).length;
      if (linkedSectionHeading || links <= 1 || (links / words) < 0.3) {
        var prefix = heading ? "## " : "";
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
    return descParts;
  }

  function listDescriptionMarkdown(root, items, options) {
    return listDescriptionParts(root, items, options).map(function(part) {
      return part.markdown;
    }).join("\n\n");
  }

  function listMarkdownWithDescription(descText, items) {
    var linkMarkdown = listMarkdown(items);
    return descText ? descText + (linkMarkdown ? "\n\n" + linkMarkdown : "") : linkMarkdown;
  }
