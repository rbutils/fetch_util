  function listFooterDataSuffix(root, groups) {
    if (!groups.length) return null;
    var container = groups[0].parentElement;
    if (!container || container.children.length !== groups.length ||
        groups.some(function(group, index) { return container.children[index] !== group; })) return null;
    if (Array.from(container.childNodes).some(function(node) {
      return node.nodeType === Node.TEXT_NODE && !!normalizeText(node.textContent || "");
    })) return null;

    var position = container;
    while (position && position !== root) {
      var sibling = position.nextSibling;
      while (sibling) {
        if (sibling.nodeType === Node.ELEMENT_NODE ||
            (sibling.nodeType === Node.TEXT_NODE && normalizeText(sibling.textContent || ""))) return null;
        sibling = sibling.nextSibling;
      }
      position = position.parentElement;
    }
    if (position !== root) return null;
    return groups.map(function(group) { return markdownFor(group.outerHTML).trim(); }).join("\n\n");
  }

  function applyListTableMarkdown(best) {
    if (!structuredListTables(best.root).length) return;
    best.sourceTableMarkdown = markdownFor(best.root.innerHTML);
    best.markdown = best.sourceTableMarkdown;
  }

  function applyListFooterDataMarkdown(best) {
    var groups = ownedFooterDataGroups(best.root);
    // Existing complete-body/table renderers already include these groups.
    if (!groups.length || best.sourceTableMarkdown || best.sourceBodyMarkdown) return;
    var suffix = listFooterDataSuffix(best.root, groups);
    if (suffix !== null) {
      var inline = best.sectionCount ? listMarkdownWithMetadataReferences(best) : listMarkdownWithInlineDescriptions(best);
      var previous = inline || best.sectionMarkdownWithDescription || best.markdown;
      // Use the same collection presentation selected by deferred finalization,
      // then keep it authoritative while adding only its physical data suffix.
      previous = materializedMarkdown(cleanupMarkdownNoise(previous));
      best.sourceBodyMarkdown = [previous, suffix].filter(Boolean).join("\n\n");
    } else {
      best.sourceBodyMarkdown = markdownFor(listBodyMarkdownHtml(best.root), false, false, true, convertListBodyMarkdown);
    }
    best.markdown = best.sourceBodyMarkdown;
  }
