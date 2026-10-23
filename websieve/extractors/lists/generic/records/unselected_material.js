  function listUnselectedRecordHeading(owner) {
    return Array.from(owner.querySelectorAll("h1, h2, h3, h4, h5, h6")).some(function(heading) {
      if (heading.closest("article, table") !== owner ||
          heading.closest("pre, code, kbd, samp, nav, button, [role='navigation'], [role='toolbar']") ||
          listCardNodeHidden(heading) || listNodeWithinClosedDisclosure(heading)) return false;
      var ancestor = heading.closest("a[href]");
      var links = ancestor && owner.contains(ancestor) ? [ancestor] : Array.from(heading.querySelectorAll("a[href]"));
      return links.length === 1 && !!materializedHttpUrl(links[0].getAttribute("href")) &&
        !!normalizeText(heading.textContent);
    });
  }

  function listUnselectedRecordMarkdown(owner) {
    var clone = safeDeepClone(owner, document);
    var sourceClones = new WeakMap();
    mapDomCloneElements(owner, clone, sourceClones);
    pruneListCardVisibility(owner, clone);
    restorePrunedNamedCodeTargets(owner, sourceClones);
    materializeListTimeDeclarations(owner, clone, sourceClones, Array.from(owner.querySelectorAll("time[datetime]")));
    pruneSourceOrderedRecordControls(clone);
    var holder = document.createElement("div");
    holder.appendChild(clone);
    var html = listHtmlWithoutUnsafeDestinations(holder);
    var richHeadingLink = Array.from(clone.querySelectorAll("a[href]")).some(function(link) {
      var headings = link.querySelectorAll("h1, h2, h3, h4, h5, h6");
      return headings.length === 1 && normalizeText(link.textContent) !== normalizeText(headings[0].textContent);
    });
    if (clone.localName === "table" || clone.querySelector("table") || richHeadingLink) {
      return singleBlockMaterializedHtml(sanitizedHtml(html));
    }
    return markdownFor(html).trim();
  }

  function listUnselectedArticleDescriptions(root, items) {
    var parts = [];
    var covered = new WeakSet();
    if (!root || !root.matches("main, [role='main']") || !items || !items.length) return { parts: parts, covered: covered };
    var selected = new WeakSet();
    var selectedAncestors = new WeakSet();
    var mapped = items.every(function(item) {
      var nodes = [item.card, item.contentCard, item.sourceNode].filter(Boolean);
      if (!nodes.length || !nodes.every(function(node) { return root.contains(node); })) return false;
      nodes.forEach(function(node) {
        selected.add(node);
        for (var parent = node; parent; parent = parent.parentElement) {
          selectedAncestors.add(parent);
          if (parent === root) break;
        }
      });
      return true;
    });
    if (!mapped) return { parts: parts, covered: covered };

    var candidates = Array.from(root.querySelectorAll("article, table")).filter(function(owner) {
      if (owner.closest("pre, code, kbd, samp, nav, aside, header, footer, button, menu, [role='navigation'], [role='menu'], [role='toolbar'], [role='dialog'], [role='button']") ||
          listCardNodeHidden(owner) || listNodeWithinClosedDisclosure(owner) || !listUnselectedRecordHeading(owner)) return false;
      if (selectedAncestors.has(owner)) return false;
      for (var parent = owner; parent; parent = parent.parentElement) {
        if (selected.has(parent)) return false;
        if (parent === root) break;
      }
      return true;
    });
    var candidateSet = new Set(candidates);
    candidates.filter(function(owner) {
      for (var parent = owner.parentElement; parent && parent !== root; parent = parent.parentElement) {
        if (candidateSet.has(parent)) return false;
      }
      return true;
    }).forEach(function(owner) {
      var markdown = listUnselectedRecordMarkdown(owner);
      if (!markdown) return;
      parts.push({ node: owner, markdown: markdown, sourceOwnedUnselectedRecord: true });
      covered.add(owner);
      owner.querySelectorAll("*").forEach(function(node) { covered.add(node); });
    });
    return { parts: parts, covered: covered };
  }
