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
    var primaryRecordKeys = listPrimaryRecordKeys(sectioned.regions.reduce(function(items, region) {
      return items.concat(region.cards);
    }, []));
    sectioned.regions.forEach(function(region, regionIndex) {
      if (region.label) {
        blocks.push({
          node: region.headingNode || region.node,
          markdown: "## " + sectionRegionMarkdown(region),
          kind: "heading",
          regionIndex: regionIndex,
          sequence: sequence++
        });
      }
      region.cards.forEach(function(item) {
        blocks.push({
          node: item.sourceNode || item.card || region.node,
          markdown: listMarkdown([item], primaryUrls, primaryRecordKeys),
          kind: "item",
          regionIndex: regionIndex,
          sequence: sequence++
        });
      });
    });
    descriptions.forEach(function(description) {
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
