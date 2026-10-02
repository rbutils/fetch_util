  function sourceOwnedResultStatusClones(collection, elementMap) {
    return (collection && collection.resultCountNodes || []).map(function(entry) {
      var clone = elementMap && elementMap.get(entry.sourceNode);
      if (!clone) {
        var sourceClones = new Map();
        visibilityPrunedClone(entry.sourceNode, document, sourceClones);
        clone = sourceClones.get(entry.sourceNode);
      }
      return clone ? { kind: entry.kind, sourceNode: entry.sourceNode, node: clone } : null;
    }).filter(Boolean);
  }

  function sourceOwnedResultStatusRoot(root, collection, clonedCollectionOwner, clonedRenderNodes, statusNodes, elementMap) {
    if (!collection || !statusNodes.length) return root;
    if (collection.primaryMain) {
      if (!clonedCollectionOwner || !root.contains(clonedCollectionOwner)) return root;
      statusNodes.forEach(function(status) {
        if (root.contains(status.node)) return;
        var sourceParent = status.sourceNode.parentElement;
        var parent = elementMap && elementMap.get(sourceParent);
        if (!parent || !root.contains(parent)) return;
        var following = status.sourceNode.nextElementSibling;
        while (following && (!elementMap.get(following) || elementMap.get(following).parentElement !== parent)) {
          following = following.nextElementSibling;
        }
        parent.insertBefore(status.node, following ? elementMap.get(following) : null);
      });
      return root;
    }
    var sourceRenderNodes = collection.renderNodes || [];
    var entries = sourceRenderNodes.map(function(sourceNode, index) {
      return { sourceNode: sourceNode, node: clonedRenderNodes[index], after: false };
    }).filter(function(entry) { return entry.node && root.contains(entry.node); });
    statusNodes.forEach(function(status) {
      if (root.contains(status.node)) return;
      entries.push({ sourceNode: status.sourceNode, node: status.node, after: false });
    });
    if (entries.length === sourceRenderNodes.length && entries.every(function(entry, index) {
      return entry.sourceNode === sourceRenderNodes[index];
    })) return root;

    entries.sort(function(left, right) {
      if (left.sourceNode === right.sourceNode) return Number(left.after) - Number(right.after);
      var position = left.sourceNode.compareDocumentPosition(right.sourceNode);
      if (position & Node.DOCUMENT_POSITION_FOLLOWING) return -1;
      if (position & Node.DOCUMENT_POSITION_PRECEDING) return 1;
      return 0;
    });
    var combined = document.createElement("div");
    entries.forEach(function(entry) { combined.appendChild(entry.node); });
    return combined;
  }

  function sourceOwnedResultCountDescriptionNodes(statusNodes, root) {
    return new Set((statusNodes || []).filter(function(entry) {
      return entry.kind === "match-count" && root.contains(entry.node);
    }).map(function(entry) { return entry.node; }));
  }

  function sourceOwnedResultStatusDescriptionParts(statusNodes, root) {
    return (statusNodes || []).filter(function(entry) {
      return entry.kind === "more-found" && root.contains(entry.node);
    }).map(function(entry) {
      return { node: entry.node, markdown: markdownFor(entry.node.outerHTML).trim() };
    }).filter(function(entry) { return !!entry.markdown; });
  }
