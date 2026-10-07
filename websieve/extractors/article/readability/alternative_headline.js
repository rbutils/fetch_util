  function sourceOwnedReaderAlternativeHeadline(root, heading, owner, paragraphs, retainedHeading) {
    var summary = heading.nextElementSibling;
    if (!summary || !summary.matches("ul[itemprop~='alternativeHeadline' i], ol[itemprop~='alternativeHeadline' i]") ||
        elementSubtreeHidden(summary) || sourceOwnershipInChrome(summary) || !owner.contains(summary)) return false;
    var declared = Array.from(owner.querySelectorAll("[itemprop~='alternativeHeadline' i]")).filter(function(node) {
      return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node);
    });
    if (declared.length !== 1 || declared[0] !== summary || !paragraphs.every(function(paragraph) {
      return !!(summary.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING);
    })) return false;

    var items = Array.from(summary.children).filter(function(item) { return !elementSubtreeHidden(item); });
    if (!items.length || items.some(function(item) {
      return item.localName !== "li" || !normalizeText(item.textContent || "") ||
        item.querySelector("p, article, nav, aside, form, pre, table");
    })) return false;
    var selectedText = normalizeText(root.textContent || "");
    if (items.some(function(item) { return selectedText.includes(normalizeText(item.textContent || "")); })) return false;

    var restored = cleanClone(visibilityPrunedClone(summary));
    var retainedItems = Array.from(restored.children);
    if (retainedItems.length !== items.length || !items.every(function(item, index) {
      var retained = retainedItems[index];
      if (normalizeText(item.textContent || "") !== normalizeText(retained.textContent || "")) return false;
      var links = Array.from(item.querySelectorAll("a[href]"));
      var retainedLinks = Array.from(retained.querySelectorAll("a[href]"));
      return links.length === retainedLinks.length && links.every(function(link, position) {
        return materializedHttpUrl(link.getAttribute("href")) &&
          materializedHttpUrl(link.getAttribute("href")) === materializedHttpUrl(retainedLinks[position].getAttribute("href")) &&
          normalizeText(link.textContent || "") === normalizeText(retainedLinks[position].textContent || "");
      });
    })) return false;

    if (retainedHeading) retainedHeading.after(restored);
    else root.prepend(restored);
    return true;
  }
