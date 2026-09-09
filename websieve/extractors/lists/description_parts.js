  function listDescriptionParts(root, items, options) {
    var descParts = [];
    var hasItems = items && items.length > 0;
    var includeInlineProse = hasItems && options && options.includeInlineProse;
    var itemValues = items && items.map(listDescriptionItemValues);
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
      if (listDescriptionCardNode(el, items, options, itemValues)) return;
      if (quote) {
        var quotation = el.cloneNode(true);
        pruneListCardVisibility(el, quotation);
        var quoteMarkdown = markdownFor(quotation.outerHTML).trim();
        if (quoteMarkdown) descParts.push({ node: el, markdown: quoteMarkdown });
        return;
      }
      var text = normalizeText(el.textContent);
      var heading = /^H[1-6]$/.test(el.tagName);
      var pageHeading = heading && !el.closest("a[href]") && !el.querySelector("a[href]");
      var weatherOwner = pageHeading && el.closest("[class*='weather' i], [id*='weather' i]");
      if (weatherOwner && weatherModuleText(weatherOwner.textContent)) pageHeading = false;
      // Linked record titles keep their existing admission, not page-label treatment.
      if (heading && !pageHeading && !/^H[1-3]$/.test(el.tagName)) return;
      if (heading && pageTitles.indexOf(text.toLowerCase()) !== -1) return;
      if (!(hasItems && (pageHeading || inlineProse)) && !(options && options.preserveTextLengths) && (text.length < 30 || text.length > 2000)) return;
      if (listNoiseText(text) || cookieNoticeText(text) || legalFooterText(text) || weatherModuleText(text)) return;
      var links = el.querySelectorAll("a[href]").length;
      var words = text.split(/\s+/).length;
      if (links <= 1 || (links / words) < 0.3) {
        var prefix = heading ? "## " : "";
        if (!heading && links) {
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
