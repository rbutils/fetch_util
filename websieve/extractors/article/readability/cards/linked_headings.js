  function readabilityMappedHeadingCard(source, clone, root, sourceClones) {
    if (source.localName !== "a" || clone.localName !== "a" || !root.contains(clone) ||
        source.closest(readabilityCardSelectionExcluded()) || elementSubtreeHidden(source)) return false;
    var owner = source.closest("article, main, [role='main']");
    var mappedOwner = owner && sourceClones.get(owner);
    if (!mappedOwner || !root.contains(mappedOwner) || !mappedOwner.contains(clone)) return false;
    if (source.querySelector("a, p, blockquote, ul, ol, dl, table, pre, code, kbd, samp, " +
        "form, button, input, select, textarea, iframe, object, embed, video, audio, script, style")) return false;

    var headings = Array.from(source.querySelectorAll("h2, h3, h4, h5, h6"));
    if (headings.length !== 1 || headings[0].closest("a") !== source || elementSubtreeHidden(headings[0])) return false;
    var heading = headings[0];
    var mappedHeading = sourceClones.get(heading);
    var text = normalizeText(heading.textContent);
    if (!text || genericListControlText(text) || !mappedHeading || !clone.contains(mappedHeading) ||
        heading.localName !== mappedHeading.localName || normalizeText(mappedHeading.textContent) !== text ||
        normalizeText(source.textContent) !== text || normalizeText(clone.textContent) !== text) return false;

    var href = source.getAttribute("href") || "";
    var destination = materializedHttpUrl(href);
    if (!href.trim() || href.trim().charAt(0) === "#" || !destination ||
        materializedHttpUrl(clone.getAttribute("href")) !== destination) return false;
    var target = new URL(destination);
    var current = new URL(location.href);
    target.hash = "";
    current.hash = "";
    return target.href !== current.href && linkedNarrativeRouteKind(target.pathname) === "ordinary";
  }

  function readabilityMappedHeadingCardGroup(source, clone, root, sourceClones, cards) {
    if (source.localName !== "div" || clone.localName !== "div" || !root.contains(clone) ||
        source.closest(readabilityCardSelectionExcluded()) || elementSubtreeHidden(source)) return null;
    if (Array.from(source.childNodes).some(function(node) {
      return node.nodeType === Node.TEXT_NODE && !!normalizeText(node.nodeValue);
    })) return null;
    var children = Array.from(source.children).filter(function(child) { return !elementSubtreeHidden(child); });
    if (!children.length || children.length !== clone.children.length) return null;
    return children.every(function(child, index) {
      return cards.get(child) === clone.children[index];
    }) ? children : null;
  }

  function readabilityMappedHeadingParagraph(source, clone, root) {
    if (source.localName !== "p" || clone.localName !== "p" || !root.contains(clone) ||
        source.closest(readabilityCardSelectionExcluded()) || elementSubtreeHidden(source) ||
        normalizeText(source.textContent) !== normalizeText(clone.textContent)) return false;
    if (source.querySelector("img, picture, svg, h1, h2, h3, h4, h5, h6, ul, ol, dl, table, " +
        "pre, code, kbd, samp, form, button, input, select, textarea, iframe, object, embed, video, audio")) return false;
    return Array.from(source.querySelectorAll("a")).every(function(link) {
      return !!materializedHttpUrl(link.getAttribute("href"));
    });
  }

  function readabilityMappedHeadingRegion(source, root, sourceClones, cards, regions) {
    if (regions.has(source)) return regions.get(source);
    regions.set(source, null);
    var clone = sourceClones.get(source);
    if (!clone || source.localName !== "div" || clone.localName !== "div" || !root.contains(clone) ||
        source.closest(readabilityCardSelectionExcluded()) || elementSubtreeHidden(source)) return null;
    var children = readabilityMappedHeadingCardGroup(source, clone, root, sourceClones, cards);
    var selectedCards = children && children.map(function(card) { return cards.get(card); });
    if (!children) {
      if (Array.from(source.childNodes).some(function(node) {
        return node.nodeType === Node.TEXT_NODE && !!normalizeText(node.nodeValue);
      })) return null;
      children = Array.from(source.children).filter(function(child) { return !elementSubtreeHidden(child); });
      if (!children.length || children.length !== clone.children.length) return null;
      selectedCards = [];
      var complete = children.every(function(child, index) {
        var mapped = sourceClones.get(child);
        if (mapped !== clone.children[index]) return false;
        if (readabilityMappedHeadingParagraph(child, mapped, root)) return true;
        var nested = readabilityMappedHeadingRegion(child, root, sourceClones, cards, regions);
        if (!nested) return false;
        selectedCards = selectedCards.concat(nested.cards);
        return true;
      });
      if (!complete || !selectedCards.length) return null;
    }
    var region = { source: source, clone: clone, cards: selectedCards };
    regions.set(source, region);
    return region;
  }

  function preserveReadabilityLinkedHeadingCards(reader, root, sourceClones) {
    var cards = new Map();
    sourceClones.forEach(function(clone, source) {
      if (readabilityMappedHeadingCard(source, clone, root, sourceClones)) cards.set(source, clone);
    });
    if (!cards.size) return;

    var blocks = new WeakSet();
    var links = new WeakSet();
    var regions = new Map();
    var selected = [];
    sourceClones.forEach(function(clone, source) {
      var region = readabilityMappedHeadingRegion(source, root, sourceClones, cards, regions);
      if (region) selected.push(region);
    });
    selected = selected.filter(function(region) {
      for (var parent = region.source.parentElement; parent; parent = parent.parentElement) {
        if (regions.get(parent)) return false;
      }
      return true;
    });
    cards.forEach(function(clone) { links.add(clone); });
    selected.forEach(function(region) {
      blocks.add(region.clone);
      region.clone.querySelectorAll("div").forEach(function(part) { blocks.add(part); });
    });
    if (!selected.length) return null;
    var context = readabilityLinkedHeadingSnapshots(root, selected, blocks, links, cards);

    var setNodeTag = reader._setNodeTag;
    reader._setNodeTag = function(node, tag) {
      if (tag === "DIV" && readabilityRetainedHeadingCard(node, context)) return node;
      if (tag === "P" && node.localName === "div" && node.hasAttribute(context.attribute)) {
        var counts = readabilityLinkedHeadingIdentityCounts(node.getRootNode(), context);
        if (readabilityRetainedHeadingGroup(node, context, counts)) return node;
      }
      return setNodeTag.apply(this, arguments);
    };
    protectReadabilitySourceBlocks(reader, blocks, function(conditionalRoot) {
      return readabilityReparsedLinkedHeadingBlocks(conditionalRoot, context);
    });
    return context;
  }
