  var sourceOwnedFooterContactResults = new WeakMap();

  function hasSourceOwnedFooterContactInformation(content) {
    return !!content && content.contentType === "list" && sourceOwnedFooterContactResults.has(content) &&
      sourceOwnedFooterContactResults.get(content) === content.html;
  }

  function footerContactRegion(node) {
    if (!node || !node.matches("footer, div, section, address") || elementSubtreeHidden(node)) return false;
    if (node.matches("footer, [role~='contentinfo' i]")) return true;
    return /(?:^|[\s_-])footer(?:$|[\s_-])/i.test([node.id || "", node.className || ""].join(" "));
  }

  function footerContactControlOwner(node, collection) {
    for (var ancestor = node; ancestor && !ancestor.contains(collection.owner); ancestor = ancestor.parentElement) {
      if (!ancestor.querySelector("input, button, select, textarea, [role~='button' i], [role~='textbox' i]")) continue;
      var otherHeading = Array.from(ancestor.querySelectorAll("h1, h2, h3, h4, h5, h6")).some(function(heading) {
        return !node.contains(heading) && !elementSubtreeHidden(heading);
      });
      if (!otherHeading) return true;
    }
    return false;
  }

  function footerContactInformationGroup(node, heading, collection) {
    if (!node.matches("div, section, footer, address") || node.contains(collection.owner)) return false;
    var interfaceSelector = "article, [itemprop~='articleBody' i], header, nav, aside, pre, code, details:not([open]), " +
      "[role~='navigation' i], [role~='menu' i], [role~='menubar' i], [role~='toolbar' i], [role~='dialog' i], " +
      "[role~='alertdialog' i], [role~='complementary' i], [role~='button' i], [role~='textbox' i], [onclick]";
    if (node.closest(interfaceSelector)) return false;
    var form = node.closest("form");
    if (form && !form.contains(collection.owner)) return false;
    var headings = Array.from(node.querySelectorAll("h1, h2, h3, h4, h5, h6"));
    if (headings.length !== 1 || headings[0] !== heading || heading.closest("a[href]")) return false;
    var elements = Array.from(node.querySelectorAll("*"));
    if (elementSubtreeHidden(node) || elements.some(function(element) {
      return !element.matches("div, section, address, span, p, br, strong, em, b, i, a, h2, h3, h4, h5, h6") ||
        elementSubtreeHidden(element) || element.matches(interfaceSelector);
    })) return false;
    var links = Array.from(node.querySelectorAll("a[href]"));
    if (!links.length || !links.some(function(link) { return /^(?:mailto|tel):/i.test(link.getAttribute("href")); })) return false;
    if (links.some(function(link) {
      return !materializedTextAnchor(link) || !materializedLinkUrl(link.getAttribute("href"), true);
    })) return false;
    var description = safeDeepClone(node, document);
    description.querySelectorAll("h1, h2, h3, h4, h5, h6, a").forEach(function(element) { element.remove(); });
    return !!normalizeText(description.textContent || "") && !footerContactControlOwner(node, collection);
  }

  function sourceFooterContactGroups(collection) {
    var owner = collection && collection.renderOwner;
    if (!owner || !collection.owner || collection.articleOwnershipConflict) return [];
    var regions = Array.from(document.querySelectorAll("footer, [role~='contentinfo' i], [id*='footer' i], [class*='footer' i]"))
      .filter(footerContactRegion);
    var groups = [];
    var seen = new Set();
    regions.forEach(function(region) {
      if (region.contains(owner) || owner.contains(region) ||
          !(owner.compareDocumentPosition(region) & Node.DOCUMENT_POSITION_FOLLOWING)) return;
      Array.from(region.querySelectorAll("h2, h3, h4, h5, h6")).forEach(function(heading) {
        if (elementSubtreeHidden(heading)) return;
        for (var node = heading.parentElement; node && region.contains(node); node = node.parentElement) {
          if (!footerContactInformationGroup(node, heading, collection)) continue;
          if (!seen.has(node)) {
            groups.push(node);
            seen.add(node);
          }
          break;
        }
      });
    });
    return groups.filter(function(group) {
      return !groups.some(function(other) { return other !== group && group.contains(other); });
    }).sort(function(left, right) {
      return left.compareDocumentPosition(right) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1;
    });
  }

  function appendListFooterContactInformation(best, collection) {
    if (!collection || !best.collectionOwnerMapped || best.collectionOwnerSourceNode !== collection.owner ||
        best.renderOwnerSourceNode !== collection.renderOwner) return;
    var sources = sourceFooterContactGroups(collection);
    if (!sources.length) return;
    var groups = sources.map(function(source) {
      return materializeHttpAttributes(visibilityPrunedClone(source, document));
    });
    var inline = best.sectionCount ? listMarkdownWithMetadataReferences(best) : listMarkdownWithInlineDescriptions(best);
    var previous = best.sourceTableMarkdown || best.sourceBodyMarkdown || inline || best.sectionMarkdownWithDescription || best.markdown;
    previous = materializedMarkdown(cleanupMarkdownNoise(previous), false);
    var suffix = groups.map(function(group) { return markdownFor(group.innerHTML, false, true, true).trim(); }).join("\n\n");
    if (!suffix) return;
    best.sourceBodyMarkdown = [previous, suffix].filter(Boolean).join("\n\n");
    if (best.sourceTableMarkdown) best.sourceTableMarkdown = best.sourceBodyMarkdown;
    best.markdown = best.sourceBodyMarkdown;
    best.sourceFooterContactGroups = groups;
    groups.forEach(function(group) { best.root.appendChild(group); });
  }
