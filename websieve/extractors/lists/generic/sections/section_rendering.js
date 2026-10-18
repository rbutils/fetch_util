  function sectionedListMarkdownWithDescriptions(sectioned, descriptions) {
    if (!descriptions.length) return "";

    var sequence = 0;
    var blocks = [];
    var primaryUrls = new Set();
    sectioned.regions.forEach(function(region) {
      region.cards.forEach(function(item) {
        var url = materializedHttpUrl(item.url || "");
        if (url) primaryUrls.add(listCanonicalKey(url));
      });
    });
    var items = sectioned.regions.reduce(function(items, region) {
      return items.concat(region.cards);
    }, []);
    var primaryRecordKeys = listPrimaryRecordKeys(items);
    var context = primaryRecordKeys.recordContext;
    var mediaGroups = [];
    items.forEach(function(item) {
      if (!item.card) return;
      listSelectedReferenceContextOwner(item.card, context);
      if (context.mediaOwners.has(item.card) && mediaGroups.indexOf(item.card) === -1) mediaGroups.push(item.card);
    });
    function mediaGroupFor(node) {
      return node && mediaGroups.find(function(group) { return group === node || group.contains(node); });
    }
    var representedHeadings = new WeakSet();
    var headingSelector = "h1, h2, h3, h4, h5, h6";
    sectioned.regions.forEach(function(region) {
      if (region.label && region.headingNode && region.headingNode.matches(headingSelector)) representedHeadings.add(region.headingNode);
    });
    descriptions.forEach(function(description) {
      if (description.markdown && description.node && description.node.matches && description.node.matches(headingSelector)) representedHeadings.add(description.node);
    });
    primaryRecordKeys.recordContext.representedHeadings = representedHeadings;
    sectioned.regions.forEach(function(region, regionIndex) {
      if (region.label && !mediaGroupFor(region.headingNode || region.node)) {
        blocks.push({
          node: region.headingNode || region.node,
          markdown: "## " + sectionRegionMarkdown(region),
          kind: "heading",
          regionIndex: regionIndex,
          sequence: sequence++
        });
      }
      region.cards.forEach(function(item) {
        var mediaGroup = mediaGroups.indexOf(item.card) !== -1 && item.card;
        if (mediaGroup && context.mediaOwners.get(mediaGroup) !== item) return;
        blocks.push({
          node: mediaGroup || item.orderNode || item.sourceNode || item.card || region.node,
          markdown: listMarkdown([item], primaryUrls, primaryRecordKeys),
          kind: "item",
          regionIndex: regionIndex,
          sequence: sequence++
        });
      });
    });
    descriptions.forEach(function(description) {
      if (mediaGroupFor(description.node)) return;
      blocks.push({
        node: description.node,
        markdown: description.markdown,
        kind: "description",
        regionIndex: null,
        sequence: sequence++
      });
    });
    blocks.sort(function(left, right) {
      if (!left.node || !right.node || left.node === right.node) return left.sequence - right.sequence;
      var position = left.node.compareDocumentPosition(right.node);
      if (position & Node.DOCUMENT_POSITION_FOLLOWING) return -1;
      if (position & Node.DOCUMENT_POSITION_PRECEDING) return 1;
      return left.sequence - right.sequence;
    });

    return blocks.map(function(block, index) {
      if (!index) return block.markdown;
      var previous = blocks[index - 1];
      var separator = previous.kind === "item" && block.kind === "item" &&
        previous.regionIndex === block.regionIndex ? "\n" : "\n\n";
      return separator + block.markdown;
    }).join("");
  }
