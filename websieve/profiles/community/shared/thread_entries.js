  function collectCommunityThreadEntries(nodes, buildEntry) {
    var seenIds = {};

    return Array.prototype.slice.call(nodes || []).map(function(node, sourceIndex) {
      if (elementSubtreeHidden(node)) return null;

      var entry = buildEntry(node, sourceIndex);
      if (!entry || !entry.body) return null;

      var id = normalizeText(String(entry.id || ""));
      if (id && seenIds[id]) return null;
      if (id) seenIds[id] = true;

      return Object.assign({}, entry, {
        id: id || null,
        sourceIndex: sourceIndex,
        sourceNode: node
      });
    }).filter(Boolean);
  }

  function communityThreadEntriesHtml(entries) {
    return communityThreadNodesHtml(entries.map(function(entry) { return entry.sourceNode; }));
  }

  function communityThreadNodesHtml(nodes) {
    nodes = nodes.filter(Boolean);
    var includedNodes = new Set(nodes);

    return nodes.filter(function(node) {
      for (var parent = node.parentElement; parent; parent = parent.parentElement) {
        if (includedNodes.has(parent)) return false;
      }
      return true;
    }).map(function(node) {
      return node.outerHTML;
    }).join("\n");
  }
