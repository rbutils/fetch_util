  function articleIntroExactTextPresent(root, text) {
    return Array.from(root.querySelectorAll("p, strong, b, [itemprop~='description']")).some(function(node) {
      return normalizeText(node.textContent || "") === text;
    });
  }

  function articleIntroContextNodes(root, boundary) {
    var selector = [
      "h1", "h2", "h3", "h4", "h5", "h6", "p", "time", "[role='heading']", "[itemprop~='headline']",
      "[class*='title' i]", "[class*='label' i]", "[class*='byline' i]", "[class*='author' i]", "[class*='date' i]"
    ].join(", ");
    return Array.from(root.querySelectorAll(selector)).filter(function(node) {
      return (!boundary || !!(node.compareDocumentPosition(boundary) & Node.DOCUMENT_POSITION_FOLLOWING)) &&
        normalizeText(node.textContent || "").length >= 3;
    });
  }

  function articleIntroUniqueContextNode(nodes, text) {
    var matches = nodes.filter(function(node) { return normalizeText(node.textContent || "") === text; });
    if (!matches.length) return null;
    return matches.find(function(node) {
      return matches.every(function(other) { return other === node || node.contains(other); });
    }) || null;
  }

  function articleIntroInsertionContext(root, owner, lead, sourceParagraph, primaryParagraph) {
    var sourceNodes = articleIntroContextNodes(owner, sourceParagraph).filter(function(node) {
      return node.closest("article") === owner && !elementSubtreeHidden(node) && !articleIntroFurniture(node, owner);
    });
    var selectedNodes = articleIntroContextNodes(root, primaryParagraph);
    var texts = Array.from(new Set(sourceNodes.map(function(node) { return normalizeText(node.textContent || ""); })));
    var pairs = texts.map(function(text) {
      var source = articleIntroUniqueContextNode(sourceNodes, text);
      var selected = articleIntroUniqueContextNode(selectedNodes, text);
      return { source: source, selected: selected, sourceIndex: sourceNodes.indexOf(source), selectedIndex: selectedNodes.indexOf(selected) };
    }).filter(function(pair) { return pair.source && pair.selected; });
    pairs.sort(function(left, right) { return left.sourceIndex - right.sourceIndex; });
    if (pairs.some(function(pair, index) { return index > 0 && pair.selectedIndex <= pairs[index - 1].selectedIndex; })) {
      return { node: null, before: false, mapped: [], sourceMapped: [] };
    }
    if (!pairs.length) return { node: null, before: false, mapped: [], sourceMapped: [] };

    var preceding = pairs.filter(function(pair) {
      return pair.source.compareDocumentPosition(lead) & Node.DOCUMENT_POSITION_FOLLOWING;
    });
    var following = pairs.filter(function(pair) {
      return lead.compareDocumentPosition(pair.source) & Node.DOCUMENT_POSITION_FOLLOWING;
    });
    var insertBefore = !preceding.length && following.length > 0;
    var insertion = insertBefore ? following[0].selected : (preceding.length ? preceding[preceding.length - 1].selected : null);
    if (!insertion) {
      return {
        node: null,
        before: false,
        mapped: pairs.map(function(pair) { return pair.selected; }),
        sourceMapped: pairs.map(function(pair) { return pair.source; })
      };
    }
    var insertionText = normalizeText(insertion.textContent || "");
    while (insertion.parentElement && insertion.parentElement !== root && !insertion.parentElement.contains(primaryParagraph) &&
           normalizeText(insertion.parentElement.textContent || "") === insertionText) {
      insertion = insertion.parentElement;
    }
    return {
      node: insertion,
      before: insertBefore,
      mapped: pairs.map(function(pair) { return pair.selected; }),
      sourceMapped: pairs.map(function(pair) { return pair.source; })
    };
  }

  function articleIntroMediaInsertionNode(root, media, primaryParagraph) {
    if (!media) return null;
    var mediaUrls = new Set(articleIntroResourceUrls(media));
    var matches = Array.from(root.querySelectorAll("img, picture, figure")).filter(function(node) {
      return (!primaryParagraph || !!(node.compareDocumentPosition(primaryParagraph) & Node.DOCUMENT_POSITION_FOLLOWING)) &&
        articleIntroResourceUrls(node).some(function(url) { return mediaUrls.has(url); });
    });
    if (!matches.length) return null;
    return matches.find(function(node) {
      return matches.every(function(other) { return other === node || node.contains(other); });
    }) || null;
  }

  function articleIntroSelectedPrefixOwned(root, primaryParagraph, mappedNodes, mediaInsertion) {
    if (!primaryParagraph) return false;
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      var textNode = walker.currentNode;
      if (!(textNode.compareDocumentPosition(primaryParagraph) & Node.DOCUMENT_POSITION_FOLLOWING) ||
          !normalizeText(textNode.textContent || "")) continue;
      var textOwned = mappedNodes.some(function(node) { return node.contains(textNode); }) ||
        (mediaInsertion && mediaInsertion.contains(textNode));
      if (!textOwned) return false;
    }

    var mediaNodes = Array.from(root.querySelectorAll("img, picture, figure, video, audio, iframe, object, embed")).filter(function(node) {
      return node.compareDocumentPosition(primaryParagraph) & Node.DOCUMENT_POSITION_FOLLOWING;
    });
    return mediaNodes.every(function(node) {
      return mediaInsertion && (node === mediaInsertion || mediaInsertion.contains(node) || node.contains(mediaInsertion));
    });
  }

  function articleIntroSourcePrefixOwned(owner, lead, mappedNodes, media) {
    var metadataSelector = [
      "h1", "h2", "h3", "h4", "h5", "h6", "time", "[role='heading']", "[itemprop~='headline']",
      "[class*='title' i]", "[class*='label' i]", "[class*='byline' i]", "[class*='author' i]", "[class*='date' i]"
    ].join(", ");
    var walker = document.createTreeWalker(owner, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      var textNode = walker.currentNode;
      if (!(textNode.compareDocumentPosition(lead) & Node.DOCUMENT_POSITION_FOLLOWING) ||
          !normalizeText(textNode.textContent || "")) continue;
      var element = textNode.parentElement;
      if (!element || element.closest("button, input, select, textarea") || articleIntroFurniture(element, owner)) continue;
      var metadata = element.closest(metadataSelector);
      if (metadata && owner.contains(metadata)) continue;
      if (mappedNodes.some(function(node) { return node.contains(textNode); }) || (media && media.contains(textNode))) continue;
      return false;
    }
    var mediaNodes = Array.from(owner.querySelectorAll("img, picture, figure, video, audio, iframe, object, embed")).filter(function(node) {
      return !!(node.compareDocumentPosition(lead) & Node.DOCUMENT_POSITION_FOLLOWING) &&
        !elementSubtreeHidden(node) && !articleIntroFurniture(node, owner) &&
        !node.closest("button, input, select, textarea");
    });
    return mediaNodes.every(function(node) {
      return media && (node === media || media.contains(node) || node.contains(media));
    });
  }
