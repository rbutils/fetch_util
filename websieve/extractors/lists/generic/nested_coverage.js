  function nestedListMaterialCoverage(current, candidate) {
    if (!current || !candidate || !current.sourceNode || !candidate.sourceNode ||
        current.sourceNode === candidate.sourceNode) return null;
    var outer = current.sourceNode.contains(candidate.sourceNode) ? current : candidate;
    var inner = outer === current ? candidate : current;
    if (!inner.sectionCount || !outer.sourceNode.contains(inner.sourceNode)) return null;
    var outerKeys = new Set(outer.items.map(function(item) { return materializedHttpUrl(item.url); }).filter(Boolean));
    var innerKeys = new Set(inner.items.map(function(item) { return materializedHttpUrl(item.url); }).filter(Boolean));
    if (outerKeys.size <= innerKeys.size || Array.from(innerKeys).some(function(url) { return !outerKeys.has(url); })) return null;

    var sources = outer.items.map(function(item) {
      var url = materializedHttpUrl(item.url);
      var card = item.card;
      if (!url || !card) return null;
      var anchors = card.matches("a[href]") ? [card] : Array.from(card.querySelectorAll("a[href]"));
      return { url: url, node: anchors.find(function(link) { return materializedHttpUrl(link.getAttribute("href")) === url; }) };
    }).filter(function(source) { return source && source.node; });
    if (outer.items.some(function(item) {
      var url = materializedHttpUrl(item.url);
      if (!url || innerKeys.has(url) || item.groupLabel != null) return false;
      return !item.card || item.card === outer.root || sources.some(function(source) {
        return source.url !== url && item.card.contains(source.node);
      });
    })) return null;

    var outerMarkdown = outer.sectionMarkdownWithDescription || outer.markdown;
    if (!outer.sectionCount) {
      var descriptions = listDescriptionParts(outer.root, outer.items, {
        includeInlineProse: true, preserveTextLengths: true, preserveUnrepresentedText: true,
        pageTitles: [document.title]
      });
      outerMarkdown = sectionedListMarkdownWithDescriptions({
        regions: [{ node: outer.root, label: "", cards: outer.items }]
      }, descriptions);
    }
    function linkTokens(markdown) {
      return Array.from((markdown || "").matchAll(/\]\((https?:\/\/(?:\\.|[^\\)\s])+)/g), function(match) { return match[1]; });
    }
    function containsText(rendered, value) {
      rendered = normalizeText(rendered).toLowerCase().replace(/\\([\\`*_{}\[\]()#+\-.!<>|~])/g, "$1");
      value = normalizeText(value).toLowerCase();
      if (!value) return true;
      var position = rendered.indexOf(value);
      while (position >= 0) {
        var before = rendered[position - 1] || "";
        var after = rendered[position + value.length] || "";
        if (!/[\p{L}\p{N}]/u.test(before) && !/[\p{L}\p{N}]/u.test(after)) return true;
        position = rendered.indexOf(value, position + 1);
      }
      return false;
    }
    function textUnits(node, rendered) {
      var units = [];
      var walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
      var textNode;
      while ((textNode = walker.nextNode())) {
        var text = normalizeText(textNode.textContent);
        if (text && containsText(rendered, text)) units.push(text);
      }
      return units;
    }
    var outerLinks = new Set(linkTokens(outerMarkdown));
    if (!inner.items.every(function(item) {
      var url = materializedHttpUrl(item.url);
      var source = listMarkdown([item]);
      if (!url) return containsText(outerMarkdown, item.text) && linkTokens(source).every(function(link) { return outerLinks.has(link); });
      var units = item.card ? textUnits(item.card, source) : [];
      if (!units.length) units.push(item.text);
      [item.author, item.time, item.category, item.summary, item.score, item.replyCount, item.caption].filter(Boolean).forEach(function(value) {
        if (containsText(source, value)) units.push(value);
      });
      return outer.items.some(function(counterpart) {
        if (materializedHttpUrl(counterpart.url) !== url) return false;
        var target = listMarkdown([counterpart]);
        var targetLinks = new Set(linkTokens(target));
        return units.every(function(value) { return containsText(target, value); }) &&
          linkTokens(source).every(function(link) { return targetLinks.has(link); });
      });
    })) return null;
    var innerMarkdown = inner.sectionMarkdownWithDescription || inner.markdown;
    if (textUnits(inner.root, innerMarkdown).some(function(value) { return !containsText(outerMarkdown, value); }) ||
        linkTokens(innerMarkdown).some(function(link) { return !outerLinks.has(link); })) return null;

    return Object.assign({}, outer, {
      markdown: outerMarkdown, sectionMarkdownWithDescription: outerMarkdown,
      sectionCount: Math.max(outer.sectionCount || 0, inner.sectionCount),
      sectionRank: Math.max(outer.sectionRank || 0, inner.sectionRank || 0),
      portalEvidenceItemCount: inner.items.length,
      portalEvidenceMaterializedItemCount: innerKeys.size
    });
  }
