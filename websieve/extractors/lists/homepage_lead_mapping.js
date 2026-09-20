  function homepageLeadListOwnership(lead, extraction) {
    if (!lead || !extraction || !extraction.sourceNode || !extraction.root || !extraction.items.length) return null;
    if (extraction.sourceNode !== lead.root && !lead.root.contains(extraction.sourceNode)) return null;

    var root = extraction.root;
    var sourceRoot = extraction.sourceNode;
    var sourceLinks = Array.from(sourceRoot.querySelectorAll("a[href]"));
    var sourceLinkIndex = {};
    sourceLinks.forEach(function(link) {
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (!url || elementSubtreeHidden(link)) return;
      var visibleLink = visibilityPrunedClone(link, document);
      var heading = visibleLink && visibleLink.querySelector("h1, h2, h3, h4");
      var titles = [leadTitle(link), normalizeText(heading && heading.textContent || "")].filter(Boolean);
      titles.filter(function(title, index) { return titles.indexOf(title) === index; }).forEach(function(title) {
        var key = JSON.stringify([url, title]);
        if (!sourceLinkIndex[key]) sourceLinkIndex[key] = [];
        sourceLinkIndex[key].push(link);
      });
    });
    var leadLinks = [];
    var retained = new Set();
    for (var index = 0; index < lead.items.length; index += 1) {
      var item = lead.items[index];
      var url = materializedHttpUrl(item && item.url);
      var source = item && item.sourceNode;
      if (!url || retained.has(url)) return null;
      if (!source) {
        var matches = sourceLinkIndex[JSON.stringify([url, normalizeText(item && item.text || "")])] || [];
        if (matches.length !== 1) return null;
        source = matches[0];
      }
      if (source.tagName !== "A" || !sourceRoot.contains(source) ||
          materializedHttpUrl(source.getAttribute("href")) !== url) return null;
      retained.add(url);
      leadLinks.push(source);
    }

    var mappedItems = extraction.items.map(function(item) {
      if (item && item.sourceNode && sourceRoot.contains(item.sourceNode) &&
          materializedHttpUrl(item.sourceNode.getAttribute("href")) === materializedHttpUrl(item.url)) {
        return item.sourceNode;
      }
      var key = JSON.stringify([materializedHttpUrl(item && item.url) || "", normalizeText(item && item.text || "")]);
      var matches = sourceLinkIndex[key] || [];
      return matches.length === 1 ? matches[0] : null;
    });
    if (mappedItems.some(function(node) { return !node; })) return null;
    for (var itemIndex = 1; itemIndex < mappedItems.length; itemIndex += 1) {
      var position = mappedItems[itemIndex - 1].compareDocumentPosition(mappedItems[itemIndex]);
      if (!(position & Node.DOCUMENT_POSITION_FOLLOWING) || position & Node.DOCUMENT_POSITION_DISCONNECTED) return null;
    }
    return { leadLinks: leadLinks, mappedItems: mappedItems, sourceRoot: sourceRoot };
  }

  function homepageLeadDescriptionSourceNodes(sourceRoot, descriptions) {
    var tags = [];
    descriptions.forEach(function(part) {
      var tag = part.node && part.node.tagName;
      if (tag && tags.indexOf(tag) === -1) tags.push(tag);
    });
    if (!tags.length) return [];

    function signature(node) {
      var urls = Array.from(node.querySelectorAll("a[href]")).map(function(link) {
        return materializedHttpUrl(link.getAttribute("href")) || "";
      });
      return JSON.stringify([
        node.tagName,
        node.getAttribute("id") || "",
        node.getAttribute("class") || "",
        normalizeText(node.textContent || ""),
        urls
      ]);
    }

    var index = {};
    Array.from(sourceRoot.querySelectorAll(tags.join(","))).forEach(function(node) {
      if (elementSubtreeHidden(node)) return;
      var key = signature(node);
      if (!index[key]) index[key] = [];
      index[key].push(node);
    });
    return descriptions.map(function(part) {
      var matches = index[signature(part.node)] || [];
      return matches.length === 1 ? matches[0] : null;
    });
  }
