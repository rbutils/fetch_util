  function readabilityOwnedLinkedProgramBlocks(root, sourceClones) {
    var blocks = new WeakSet();
    var excluded = "nav, header, footer, aside, form, button, pre, code, details:not([open]), " +
      "[role='button'], [role='navigation'], [role='complementary'], [role='dialog'], " +
      "[role='toolbar'], [role='menu'], [role='banner'], [role='contentinfo']";
    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "div" || clone.localName !== "div" || !root.contains(clone) ||
          source.closest(excluded) || elementSubtreeHidden(source) || clone.children.length !== 1) return;
      var program = clone.firstElementChild;
      if (program.localName !== "pre" || !normalizeText(program.textContent) ||
          program.querySelector("button, input, select, textarea, img, svg, iframe, table, [role='button']")) return;
      if (Array.from(clone.childNodes).some(function(node) {
        return node.nodeType === Node.TEXT_NODE && !!normalizeText(node.nodeValue);
      })) return;
      var originals = Array.from(source.querySelectorAll("pre")).filter(function(node) {
        return sourceClones.get(node) === program;
      });
      if (originals.length !== 1 || elementSubtreeHidden(originals[0]) ||
          cleanCodeText(originals[0].textContent) !== cleanCodeText(program.textContent)) return;
      var sourceLinks = Array.from(originals[0].querySelectorAll("a[href]")).filter(function(link) {
        return !elementSubtreeHidden(link) && !!materializedHttpUrl(link.getAttribute("href"));
      });
      var links = Array.from(program.querySelectorAll("a[href]"));
      if (!links.length || sourceLinks.length !== links.length ||
          !links.some(function(link) { return !!normalizeText(link.textContent); })) return;
      if (!links.every(function(link, index) {
        var original = sourceLinks[index];
        return cleanCodeText(original.textContent) === cleanCodeText(link.textContent) &&
          materializedHttpUrl(original.getAttribute("href")) === materializedHttpUrl(link.getAttribute("href"));
      })) return;
      blocks.add(clone);
    });
    return blocks;
  }
