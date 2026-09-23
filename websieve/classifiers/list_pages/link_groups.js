  function genericListPlainLinkGroup(link, cache) {
    var visited = [];
    function finish(result) {
      if (cache) visited.forEach(function(node) { cache.set(node, result); });
      return result;
    }
    var group = link.parentElement;
    while (group && !group.matches("body, main, [role='main']")) {
      if (cache && cache.has(group)) return finish(cache.get(group));
      if (cache) visited.push(group);
      if (listChromeNode(group) || elementSubtreeHidden(group)) return finish(null);
      var anchors = Array.from(group.querySelectorAll("a[href]")).filter(function(anchor) {
        return !elementSubtreeHidden(anchor);
      });
      if (anchors.some(function(anchor) {
        return !materializedHttpUrl(anchor.getAttribute("href")) || genericListAnchorRecordEvidence(anchor);
      })) return finish(null);
      var clone = group.cloneNode(true);
      pruneHiddenClone(group, clone);
      clone.querySelectorAll("a").forEach(function(anchor) { anchor.remove(); });
      if (normalizeText(clone.textContent)) return finish(null);
      var destinations = new Set(anchors.map(function(anchor) { return materializedHttpUrl(anchor.getAttribute("href")); }));
      if (destinations.size >= 2) return finish({ card: group, label: "" });
      group = group.parentElement;
    }
    return finish(null);
  }

  function genericListDescribedLinkGroup(link) {
    if (!homepageRootPath()) return null;
    var group = link.parentElement;
    if (!group || !group.closest("main, [role='main']")) return null;
    var children = Array.from(group.children).filter(function(node) { return !elementSubtreeHidden(node); });
    if (children.some(function(node) { return !node.matches("h1, h2, h3, h4, p, a[href]"); })) return null;
    var headings = children.filter(function(node) { return node.matches("h1, h2, h3, h4"); });
    var prose = children.filter(function(node) { return node.matches("p") && normalizeText(node.textContent); });
    var links = children.filter(function(node) { return node.matches("a[href]"); });
    if (headings.length !== 1 || !normalizeText(headings[0].textContent) || !prose.length || links.indexOf(link) < 0) return null;
    if (headings[0].querySelector("a") || prose.some(function(node) { return node.querySelector("a, button, input"); })) return null;
    if (links.some(function(node) {
      return !materializedHttpUrl(node.getAttribute("href")) || !normalizeText(node.textContent) || genericListAnchorRecordEvidence(node);
    })) return null;
    var destinations = new Set(links.map(function(node) { return materializedHttpUrl(node.getAttribute("href")); }));
    return destinations.size >= 2 ? { card: group, label: normalizeText(headings[0].textContent) } : null;
  }

  function genericListSamePathQueryGroup(link) {
    var row = link.closest("li, [role='listitem']");
    var collection = row && row.parentElement;
    if (!collection || !collection.matches("ul, ol, [role='list']") ||
        !collection.previousElementSibling ||
        !collection.previousElementSibling.matches("h1, h2, h3, h4, [role='heading']") ||
        !normalizeText(collection.previousElementSibling.textContent) ||
        listChromeNode(collection) || listNoiseNode(collection)) return null;

    var rows = Array.from(collection.children).filter(function(child) {
      return child.matches("li, [role='listitem']") && !elementSubtreeHidden(child);
    });
    if (rows.length < 4 || rows.indexOf(row) < 0) return null;

    var destinations = new Set();
    var complete = rows.every(function(child) {
      if (listChromeNode(child) || child.querySelector("ul, ol, [role='list']")) return false;
      var links = Array.from(child.querySelectorAll("a[href]")).filter(function(anchor) {
        return !elementSubtreeHidden(anchor);
      });
      if (links.length !== 1 || !normalizeText(links[0].textContent) ||
          normalizeText(child.textContent) !== normalizeText(links[0].textContent)) return false;

      var url = materializedHttpUrl(links[0].getAttribute("href"));
      if (!url || listCanonicalKey(url) === listCanonicalKey(location.href)) return false;
      var parsed = new URL(url, location.href);
      if (parsed.origin !== location.origin || parsed.pathname !== location.pathname || !parsed.search) return false;
      var key = listCanonicalKey(url);
      if (destinations.has(key)) return false;
      destinations.add(key);
      return true;
    });
    return complete ? { card: row, label: "" } : null;
  }

  function genericListLinkGroup(link, cache) {
    if (!link || !materializedHttpUrl(link.getAttribute("href")) || elementSubtreeHidden(link)) return null;
    if (link.closest("header, footer, nav, aside, menu, [role='navigation'], [role='menu'], [role='menubar'], [role='toolbar'], [role='banner'], [role='complementary'], [role='contentinfo']")) return null;
    if (listChromeNode(link) || listChromeNode(link.parentElement) || listChromeAncestor(link)) return null;
    var described = genericListDescribedLinkGroup(link);
    if (described) return described;
    var queryCollection = genericListSamePathQueryGroup(link);
    if (queryCollection) return queryCollection;

    var collection = genericListContextCard(closestGenericListCard(link));
    if (!collection) return genericListPlainLinkGroup(link, cache);
    if (!collection || collection === link || collection.matches("tr") || !collection.contains(link)) return null;
    var branch = link;
    while (branch.parentElement && branch.parentElement !== collection) branch = branch.parentElement;
    var groups = Array.prototype.filter.call(collection.children, function(child) {
      return child.querySelector("a[href]") && !elementSubtreeHidden(child);
    });
    if (groups.length < 2 || groups.indexOf(branch) < 0) return null;

    var label = "";
    var grouped = groups.every(function(group) {
      if (listChromeNode(group)) return false;
      var destinations = new Set();
      var hasRecord = false;
      group.querySelectorAll("a[href]").forEach(function(anchor) {
        var url = materializedHttpUrl(anchor.getAttribute("href"));
        if (!url || elementSubtreeHidden(anchor)) return;
        destinations.add(url);
        if (genericListAnchorRecordEvidence(anchor)) hasRecord = true;
      });
      if (hasRecord || destinations.size < 2) return false;

      var clone = group.cloneNode(true);
      pruneHiddenClone(group, clone);
      clone.querySelectorAll("a").forEach(function(anchor) { anchor.remove(); });
      var labels = clone.querySelectorAll("h1, h2, h3, h4, h5, h6, [role='heading'], [class*='title' i]");
      if (labels.length !== 1 || !normalizeText(labels[0].textContent)) return false;
      if (group === branch) label = normalizeText(labels[0].textContent);
      labels[0].remove();
      return !normalizeText(clone.textContent);
    });
    return grouped ? { card: branch, label: label } : null;
  }

  function genericListNumberedCollectionLink(link, cache) {
    if (!link || !link.matches("a[href]") || elementSubtreeHidden(link) ||
        link.closest("nav, header, footer, aside, menu, form, [role='navigation'], [role='complementary']") ||
        listChromeAncestor(link)) return false;

    var record = link.closest("li, [role='listitem']");
    var collection = record && record.parentElement;
    if (!collection || !collection.matches("ul, ol, [role='list']") ||
        listChromeNode(collection) || listNoiseNode(collection)) return false;
    if (cache && cache.has(collection)) return cache.get(collection).has(link);

    var rows = Array.from(collection.children).filter(function(child) {
      return child.matches("li, [role='listitem']") && !elementSubtreeHidden(child);
    });
    var admitted = new Set();
    var destinations = new Set();
    var expectedLinks = null;
    var numberedRows = 0;
    var complete = rows.length >= 4;

    rows.forEach(function(row) {
      if (!complete || listChromeNode(row) || row.querySelector("ul, ol, [role='list']")) {
        complete = false;
        return;
      }
      var links = Array.from(row.querySelectorAll("a[href]")).filter(function(anchor) {
        return !elementSubtreeHidden(anchor);
      });
      if (!links.length || (expectedLinks !== null && links.length !== expectedLinks)) {
        complete = false;
        return;
      }
      expectedLinks = links.length;
      if (links.some(function(anchor) {
        return /\b(?:chapter|episode|part)\s*\d+[a-z]?\b|第\s*[\d〇一二三四五六七八九十百千]+\s*[章節节回話话]/i.test(normalizeText(anchor.textContent || ""));
      })) numberedRows += 1;

      links.forEach(function(anchor) {
        var url = materializedHttpUrl(anchor.getAttribute("href"));
        if (!normalizeText(anchor.textContent || anchor.getAttribute("aria-label") || "") ||
            !url || destinations.has(url)) {
          complete = false;
          return;
        }
        destinations.add(url);
        admitted.add(anchor);
      });
    });

    if (!complete || numberedRows * 2 < rows.length) admitted.clear();
    if (cache) cache.set(collection, admitted);
    return admitted.has(link);
  }
