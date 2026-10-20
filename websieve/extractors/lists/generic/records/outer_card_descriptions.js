  function listOuterArticleDescriptions(root, items) {
    var parts = [];
    var covered = new WeakSet();
    var selected = new WeakSet();
    var paths = new WeakSet();
    var owners = new Set();
    (items || []).forEach(function(item) {
      if (!item.card) return;
      selected.add(item.card);
      for (var parent = item.card.parentElement; parent && root.contains(parent); parent = parent.parentElement) {
        paths.add(parent);
        if (item.card.matches("article") && parent.matches("article")) owners.add(parent);
        if (parent === root) break;
      }
    });
    var candidates = Array.from(owners).filter(function(owner) {
      return !selected.has(owner) && !listCardNodeHidden(owner) &&
        !owner.closest("nav, [role='navigation'], [role='menu'], [role='toolbar'], [role='button']");
    });

    function render(nodes) {
      if (!nodes.length) return;
      var clone = document.createElement("div");
      nodes.forEach(function(node) {
        if (node.nodeType === 1 && listCardNodeHidden(node)) return;
        var copy = node.cloneNode(true);
        if (node.nodeType === 1) pruneListCardVisibility(node, copy);
        clone.appendChild(copy);
      });
      var markdown = markdownFor(listHtmlWithoutUnsafeDestinations(clone)).trim();
      if (!markdown) return;
      parts.push({ node: nodes[0], sourceNodes: nodes.slice(), markdown: markdown });
      nodes.forEach(function(node) {
        covered.add(node);
        if (node.nodeType === 1) node.querySelectorAll("*").forEach(function(child) { covered.add(child); });
      });
    }

    function visit(owner) {
      var pending = [];
      Array.from(owner.childNodes).forEach(function(node) {
        if (selected.has(node)) {
          render(pending);
          pending = [];
        } else if (paths.has(node)) {
          render(pending);
          pending = [];
          visit(node);
        } else {
          pending.push(node);
        }
      });
      render(pending);
    }

    candidates.filter(function(owner) {
      return !candidates.some(function(other) { return other !== owner && other.contains(owner); });
    }).forEach(visit);
    return { parts: parts, covered: covered };
  }
