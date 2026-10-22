  function collectionSectionInertContext(node) {
    if (node.nodeType === Node.TEXT_NODE) return !normalizeText(node.textContent || "");
    if (node.nodeType !== Node.ELEMENT_NODE) return true;
    if (node.matches("script, style, template, noscript") || elementSubtreeHidden(node)) return true;
    if (!node.matches("div, span")) return false;
    return Array.prototype.every.call(node.childNodes, collectionSectionInertContext);
  }

  function collectionSectionHeading(node) {
    var headings = [];
    function visit(child) {
      if (collectionSectionInertContext(child)) return true;
      if (child.nodeType !== Node.ELEMENT_NODE) return false;
      if (child.matches("h2, h3, h4, h5, h6")) {
        if (!normalizeText(child.textContent || "") ||
            child.querySelector("a, button, input, select, textarea, form, img, svg, video, audio, iframe, object, embed, canvas, pre, table")) return false;
        headings.push(child);
        return true;
      }
      return child.matches("div, span") && Array.prototype.every.call(child.childNodes, visit);
    }
    return visit(node) && headings.length === 1 ? headings[0] : null;
  }

  function pageOwnedCollectionSectionContext(owner) {
    var branch = owner;
    var parent = branch && branch.parentElement;
    while (parent && !parent.matches("body, html, main, form, [role='main']") &&
        !parent.closest("article, nav, header, footer, aside, [role='navigation'], [role='complementary']")) {
      var authoredText = Array.prototype.some.call(parent.childNodes, function(child) {
        return child.nodeType === Node.TEXT_NODE && !collectionSectionInertContext(child);
      });
      if (authoredText) return null;
      var children = Array.from(parent.children);
      var materialSiblings = children.filter(function(child) {
        return child !== branch && !collectionSectionInertContext(child);
      });
      if (materialSiblings.length) {
        var headingOwner = materialSiblings[0];
        if (materialSiblings.length !== 1 || !collectionSectionHeading(headingOwner) ||
            !(headingOwner.compareDocumentPosition(branch) & Node.DOCUMENT_POSITION_FOLLOWING)) return null;
        return {
          owner: parent,
          nodes: children.filter(function(child) {
            return !child.matches("script, style, template, noscript") && !elementSubtreeHidden(child);
          })
        };
      }
      branch = parent;
      parent = parent.parentElement;
    }
    return null;
  }
