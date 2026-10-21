  function readabilityOwnedNestedResourceTables(root, sourceClones) {
    var blocks = new WeakSet();
    var interfaces = "nav, header, footer, aside, form, button, input, select, textarea, " +
      "[role='button'], [role='navigation'], [role='banner'], [role='complementary'], " +
      "[role='dialog'], [role='toolbar'], [role='menu']";
    var excluded = interfaces + ", pre, code, kbd, samp, details:not([open]), " +
      "iframe, object, embed, video, audio, canvas";
    function mappedInside(source, clone) {
      var mapped = sourceClones.get(source);
      return mapped && (mapped === clone || clone.contains(mapped)) ? mapped : null;
    }
    function sameRetainedText(source, clone) {
      var walker = source.ownerDocument.createTreeWalker(source, NodeFilter.SHOW_TEXT);
      var pieces = [];
      while (walker.nextNode()) {
        var mapped = mappedInside(walker.currentNode, clone);
        if (!mapped) continue;
        if (walker.currentNode.nodeValue !== mapped.nodeValue) return false;
        pieces.push(walker.currentNode.nodeValue);
      }
      return normalizeText(pieces.join("")) === normalizeText(clone.textContent);
    }
    function contentOwner(source) {
      for (var owner = source.parentElement; owner && owner !== source.ownerDocument.body;
          owner = owner.parentElement) {
        var clone = sourceClones.get(owner);
        if (!clone || !root.contains(clone) || owner.closest(excluded) ||
            clone.querySelector(interfaces) || elementSubtreeHidden(owner)) continue;
        var headings = Array.from(owner.querySelectorAll("h1")).filter(function(heading) {
          var mapped = mappedInside(heading, clone);
          return mapped && !heading.closest("table") && !elementSubtreeHidden(heading) &&
            !!normalizeText(mapped.textContent) && sameRetainedText(heading, mapped);
        });
        if (headings.length !== 1) continue;
        if (Array.from(owner.querySelectorAll("p")).some(function(paragraph) {
          var mapped = mappedInside(paragraph, clone);
          return mapped && !paragraph.closest("table") && !elementSubtreeHidden(paragraph) &&
            !!normalizeText(mapped.textContent) && sameRetainedText(paragraph, mapped);
        })) return owner;
      }
      return null;
    }
    function completeStructure(source, clone) {
      var originals = [source].concat(Array.from(source.querySelectorAll("*"))).filter(function(node) {
        return !!mappedInside(node, clone);
      });
      var elements = [clone].concat(Array.from(clone.querySelectorAll("*")));
      return originals.length === elements.length && originals.every(function(node, index) {
        var mapped = elements[index];
        if (sourceClones.get(node) !== mapped || node.localName !== mapped.localName ||
            node.namespaceURI !== mapped.namespaceURI) return false;
        if (node !== source && sourceClones.get(node.parentElement) !== mapped.parentElement) return false;
        if (!/^(th|td)$/.test(node.localName)) return true;
        return ["rowspan", "colspan", "scope", "headers"].every(function(attribute) {
          return node.getAttribute(attribute) === mapped.getAttribute(attribute);
        }) && sameRetainedText(node, mapped);
      }) && sameRetainedText(source, clone);
    }
    function completeResources(source, clone, selector, attribute) {
      var originals = Array.from(source.querySelectorAll(selector)).filter(function(node) {
        return !!mappedInside(node, clone);
      });
      var nodes = Array.from(clone.querySelectorAll(selector));
      return originals.length === nodes.length && originals.every(function(node, index) {
        var mapped = nodes[index];
        var destination = materializedHttpUrl(node.getAttribute(attribute));
        return sourceClones.get(node) === mapped && !!destination &&
          destination === materializedHttpUrl(mapped.getAttribute(attribute)) &&
          sameRetainedText(node, mapped) && (attribute !== "src" ||
            node.getAttribute("alt") === mapped.getAttribute("alt"));
      });
    }
    function outsideTextIsProse(clone) {
      var outside = clone.cloneNode(true);
      outside.querySelectorAll("table").forEach(function(table) { table.remove(); });
      var walker = outside.ownerDocument.createTreeWalker(outside, NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) {
        if (normalizeText(walker.currentNode.nodeValue) &&
            !walker.currentNode.parentElement.closest("p, span, strong, em, b, i, small")) return false;
      }
      return true;
    }
    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "table" || clone.localName !== "table" ||
          !root.contains(clone) || !clone.querySelector("table") ||
          source.parentElement.closest("table") || source.closest(excluded) ||
          clone.querySelector(excluded) || elementSubtreeHidden(source)) return;
      var owner = contentOwner(source);
      if (!owner) return;
      if (!clone.querySelector("td") || !clone.querySelector("a[href], img") ||
          !completeStructure(source, clone) ||
          !completeResources(source, clone, "a[href]", "href") ||
          !completeResources(source, clone, "img", "src")) return;
      blocks.add(clone);
      clone.querySelectorAll("table").forEach(function(table) { blocks.add(table); });
      for (var container = source.parentElement; container && container !== owner;
          container = container.parentElement) {
        var mapped = sourceClones.get(container);
        if (container.localName !== "div" || !mapped || !root.contains(mapped) ||
            container.closest(excluded) || mapped.querySelector(excluded)) break;
        if (!outsideTextIsProse(mapped) || !completeStructure(container, mapped) ||
            !completeResources(container, mapped, "a[href]", "href") ||
            !completeResources(container, mapped, "img", "src")) break;
        blocks.add(mapped);
      }
    });
    return blocks;
  }

  function preserveReadabilityOwnedTableCells(reader, blocks) {
    var hasSingleTag = reader._hasSingleTagInsideElement;
    reader._hasSingleTagInsideElement = function(element, tag) {
      if (tag === "TR" && element) {
        var table = element.localName === "tbody" ? element.parentElement : element;
        if (table && table.localName === "table" && blocks.has(table)) return false;
      }
      return hasSingleTag.apply(this, arguments);
    };
  }
