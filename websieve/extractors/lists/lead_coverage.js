  function supplementedHomepageLead(lead, content) {
    var extraction = content && content.listExtraction;
    if (!lead || !extraction || extraction.sourceNode !== lead.root || !extraction.items.length) return null;
    var root = extraction.root;
    var links = Array.from(root.querySelectorAll("a[href]"));
    var retained = new Set();
    var items = [];
    var representedDetails = [];
    for (var index = 0; index < lead.items.length; index += 1) {
      var item = lead.items[index];
      var counterparts = extraction.items.filter(function(candidate) { return candidate.url === item.url; });
      if (counterparts.length > 1) return null;
      var matches = links.filter(function(link) {
        return materializedHttpUrl(link.getAttribute("href")) === item.url &&
          normalizeText(link.textContent || link.getAttribute("aria-label")) === normalizeText(item.text);
      });
      if (!matches.length && counterparts.length && counterparts[0].text === item.text &&
          counterparts[0].sourceNode && root.contains(counterparts[0].sourceNode) &&
          materializedHttpUrl(counterparts[0].sourceNode.getAttribute("href")) === item.url) {
        matches = [counterparts[0].sourceNode];
      }
      if (matches.length !== 1 || retained.has(item.url)) return null;
      if (counterparts.length && counterparts[0].card && counterparts[0].card.contains(matches[0])) {
        representedDetails.push({ card: counterparts[0].card, text: normalizeText(item.detail) });
      }
      retained.add(item.url);
      items.push(Object.assign({}, item, { sourceNode: matches[0] }));
    }
    var additions = extraction.items.filter(function(item) { return !retained.has(item.url); });
    if (!additions.length) return null;
    for (var additionIndex = 0; additionIndex < additions.length; additionIndex += 1) {
      var addition = additions[additionIndex];
      var card = addition.card;
      if (!addition.sourceNode || addition.sourceNode.tagName !== "A" || !card || card === root ||
          !root.contains(card) || !card.contains(addition.sourceNode) || genericListPageContainer(card)) return null;
      var cardLinks = card.matches("a[href]") ? [card] : Array.from(card.querySelectorAll("a[href]"));
      var destinations = cardLinks.map(function(link) {
        return materializedHttpUrl(link.getAttribute("href"));
      });
      if (!destinations.length || destinations.some(function(url) { return !url || url !== addition.url; })) return null;
      items.push(addition);
    }
    var descriptions = listDescriptionParts(root, extraction.items, {
      includeInlineProse: true, preserveTextLengths: true, preserveUnrepresentedText: true
    }).filter(function(part) {
      var text = normalizeText(part.node.textContent);
      return !elementSubtreeHidden(part.node) && !items.some(function(item) {
        return normalizeText(item.text) === text &&
          (item.sourceNode.contains(part.node) || part.node.contains(item.sourceNode));
      }) && !representedDetails.some(function(detail) {
        return text && detail.card.contains(part.node) && detail.text.indexOf(text) !== -1;
      });
    });
    if (!descriptions.some(function(part) { return !/^#{1,6}\s/.test(part.markdown); })) return null;
    items.sort(function(left, right) {
      var position = left.sourceNode.compareDocumentPosition(right.sourceNode);
      return position & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : position & Node.DOCUMENT_POSITION_PRECEDING ? 1 : 0;
    });
    return { items: items, markdown: sectionedListMarkdownWithDescriptions({
      regions: [{ node: root, label: "", cards: items }]
    }, descriptions) };
  }
