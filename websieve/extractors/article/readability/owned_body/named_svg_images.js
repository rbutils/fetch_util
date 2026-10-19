  function protectReadabilitySourceBlocks(reader, blocks, prepareBlocks) {
    var cleanConditionally = reader._cleanConditionally;
    reader._cleanConditionally = function(root, tag) {
      var protectedBlocks = prepareBlocks ? prepareBlocks(root) : blocks;
      var removeNodes = this._removeNodes;
      this._removeNodes = function(nodes, filter) {
        return removeNodes.call(this, nodes, function(node, index, list) {
          return !protectedBlocks.has(node) && (!filter || filter.call(this, node, index, list));
        });
      };
      try {
        return cleanConditionally.call(this, root, tag);
      } finally {
        this._removeNodes = removeNodes;
      }
    };
  }

  function reparsedReadabilitySourceBlocks(root, blocks, snapshots) {
    var attribute = "data-fetchutil-reader-source-paragraph";
    var counts = new Map();
    root.getRootNode().querySelectorAll("p[" + attribute + "]").forEach(function(paragraph) {
      var identity = paragraph.getAttribute(attribute);
      if (snapshots.has(identity)) counts.set(identity, (counts.get(identity) || 0) + 1);
    });
    return {
      has: function(node) {
        if (blocks.has(node)) return true;
        if (node.localName !== "div" || node.children.length !== 1 || node.children[0].localName !== "p") return false;
        var identity = node.children[0].getAttribute(attribute);
        return counts.get(identity) === 1 && snapshots.get(identity) === node.outerHTML;
      }
    };
  }

  function preserveReadabilityOwnedNamedSvgBlocks(reader, root, sourceClones, marker) {
    if (!reader || !root || !sourceClones) return;
    var blocks = new WeakSet();
    var snapshots = new Map();
    var found = false;
    var excludedOwner = "nav, header, footer, aside, form, button, pre, code, " +
      "[role='navigation'], [role='complementary'], [role='dialog'], [role='toolbar'], [role='menu']";
    var excludedContent = "p p, div, section, article, h1, h2, h3, h4, h5, h6, ul, ol, dl, table, " +
      "pre, code, kbd, samp, button, input, select, textarea, img, picture, video, audio, iframe, object, embed";

    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "div" || clone.localName !== "div" || !root.contains(clone)) return;
      if (source.children.length !== 1 || clone.children.length !== 1 || source.closest(excludedOwner)) return;
      var paragraph = source.children[0];
      var paragraphClone = sourceClones.get(paragraph);
      if (paragraph.localName !== "p" || clone.children[0] !== paragraphClone) return;
      if (paragraph.querySelector(excludedContent)) return;
      if (Array.from(source.childNodes).some(function(node) {
        return node.nodeType === Node.TEXT_NODE && !!normalizeText(node.textContent);
      })) return;

      var owner = source.closest("article, main, [role='main'], [itemprop~='articleBody']");
      var ownerClone = owner && sourceClones.get(owner);
      if (!ownerClone || !root.contains(ownerClone) || !ownerClone.contains(clone)) return;
      var hasImage = Array.from(paragraph.querySelectorAll("svg")).some(function(svg) {
        var name = svgDeclaredImageName(svg);
        var svgClone = sourceClones.get(svg);
        return !!name && !elementSubtreeHidden(svg) && svgClone && paragraphClone.contains(svgClone) &&
          svgDeclaredImageName(svgClone) === name && !svgMaterialTextNodes(svgClone).length;
      });
      if (!hasImage) return;
      blocks.add(clone);
      var identity = paragraphClone.getAttribute("data-fetchutil-reader-source-paragraph");
      if (marker && identity && identity.indexOf(marker + ":") === 0) snapshots.set(identity, clone.outerHTML);
      found = true;
    });
    if (found) {
      protectReadabilitySourceBlocks(reader, blocks, function(conditionalRoot) {
        return reparsedReadabilitySourceBlocks(conditionalRoot, blocks, snapshots);
      });
    }
  }
