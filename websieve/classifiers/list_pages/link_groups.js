  function genericListLinkGroup(link) {
    if (!link || !materializedHttpUrl(link.getAttribute("href")) || elementSubtreeHidden(link)) return null;
    if (listChromeNode(link) || listChromeNode(link.parentElement) || listChromeAncestor(link)) return null;

    var collection = genericListContextCard(closestGenericListCard(link));
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
