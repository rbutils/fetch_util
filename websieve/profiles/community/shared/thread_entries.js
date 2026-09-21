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
    return entries.map(function(entry) {
      return entry.sourceNode.outerHTML;
    }).join("\n");
  }
