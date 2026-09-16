  function focalOwnershipCandidateSelector() {
    return [
      "article",
      "[itemprop~='articleBody' i]",
      "[role~='main' i]",
      "[class*='article' i]",
      "[class*='content' i]",
      "[class*='post' i]",
      "[class*='story' i]"
    ].join(", ");
  }

  function focalOwnershipCandidate(node) {
    if (!node || !node.matches || node.closest("header, nav, footer, aside, [role~='navigation' i], [role~='complementary' i], [role~='comment' i], [class*='comment' i], [id*='comment' i]")) return false;

    var heading = node.querySelector("h1, h2, [itemprop~='headline' i]");
    var headingText = normalizeText((heading && heading.textContent) || "");
    var pageTitle = normalizeText(document.title || "");
    if (headingText.length < 12 || pageTitle.length < 12) return false;
    if (pageTitle.toLowerCase().indexOf(headingText.toLowerCase()) === -1 && headingText.toLowerCase().indexOf(pageTitle.toLowerCase()) === -1) return false;

    var text = normalizeText(node.textContent || "");
    var paragraphs = Array.prototype.filter.call(node.querySelectorAll("p"), function(paragraph) {
      return !paragraph.closest("[role~='comment' i], [class*='comment' i], [id*='comment' i]");
    });
    return text.length >= 450 && paragraphs.length >= 3;
  }

  function focalOwnershipNamedRailOwner(node) {
    return Array.prototype.some.call(node.classList || [], function(token) {
      return /(?:^|[-_])(card|item|teaser)(?:$|[-_])/i.test(token);
    });
  }

  function focalOwnershipNamedRailGroup(node) {
    if (node.matches("aside, [role~='complementary' i]")) return true;
    return Array.prototype.some.call(node.classList || [], function(token) {
      return /(?:^|[-_])(rail|related|recommend(?:ed|ation|ations)?|teasers?)(?:$|[-_])/i.test(token);
    });
  }

  function focalOwnershipTextOutsideNodes(root, ownedNodes) {
    var text = [];
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      var parent = walker.currentNode.parentElement;
      if (!parent || ownedNodes.some(function(node) { return node.contains(parent); })) continue;
      if (parent.closest("script, style, noscript, template")) continue;
      text.push(walker.currentNode.nodeValue || "");
    }
    return normalizeText(text.join(" "));
  }

  function focalOwnershipRailRecord(link, wrapper, focal) {
    var heading = link.closest("h1, h2, h3, h4") || link.querySelector("h1, h2, h3, h4");
    if (!heading || focal.contains(link)) return null;

    var owner = heading.parentElement;
    while (owner && owner !== wrapper && !owner.matches("article, li") && !focalOwnershipNamedRailOwner(owner)) {
      owner = owner.parentElement;
    }
    if (!owner || owner === wrapper) return null;
    if (!owner || owner === wrapper || owner.contains(focal)) return null;
    if (owner.closest("header, nav, footer, [role~='navigation' i], [role~='comment' i], [class*='comment' i], [id*='comment' i]")) return null;
    var paragraphs = Array.prototype.slice.call(owner.querySelectorAll("p"));
    if (paragraphs.length !== 1 || owner.querySelectorAll("h1, h2, h3, h4").length !== 1) return null;
    if (normalizeText(owner.textContent || "").length > 700) return null;
    if (scoreNode(owner) > -Infinity) return null;
    if (focalOwnershipTextOutsideNodes(owner, [heading].concat(paragraphs)).length > 0) return null;
    var headingLinks = Array.prototype.filter.call(owner.querySelectorAll("a[href]"), function(candidate) {
      return (candidate.closest("h1, h2, h3, h4") || candidate.querySelector("h1, h2, h3, h4")) === heading;
    });
    if (headingLinks.length !== 1 || headingLinks[0] !== link) return null;
    var primaryKey = listCanonicalKey(materializedHttpUrl(link.getAttribute("href")));
    var competingLink = Array.prototype.some.call(owner.querySelectorAll("a[href]"), function(candidate) {
      if (candidate === link) return false;
      var destination = materializedHttpUrl(candidate.getAttribute("href"));
      return destination && listCanonicalKey(destination) !== primaryKey;
    });
    if (competingLink) return null;
    return owner;
  }

  function focalOwnershipRailGroup(records, wrapper, focal) {
    var groups = [];
    records.forEach(function(record) {
      var node = record.owner.parentElement;
      if (!node || node === wrapper || node.contains(focal) || !focalOwnershipNamedRailGroup(node)) return;
      var group = groups.find(function(candidate) { return candidate.node === node; });
      if (!group) {
        group = { node: node, owners: [], destinations: new Set() };
        groups.push(group);
      }
      if (group.owners.indexOf(record.owner) === -1) group.owners.push(record.owner);
      group.destinations.add(listCanonicalKey(record.destination));
    });

    var qualified = groups.filter(function(group) {
      return group.owners.length >= 3 && group.destinations.size >= 3;
    });
    return qualified.length === 1 ? qualified[0] : null;
  }

  function focalOwnershipOutsideIsRail(wrapper, focal) {
    var records = [];

    wrapper.querySelectorAll("a[href]").forEach(function(link) {
      if (focal.contains(link)) return;
      var destination = materializedHttpUrl(link.getAttribute("href"));
      var owner = destination && focalOwnershipRailRecord(link, wrapper, focal);
      if (!owner) return;
      records.push({ owner: owner, destination: destination });
    });
    var group = focalOwnershipRailGroup(records, wrapper, focal);
    if (!group) return false;
    var owners = group.owners;
    var ownerHasMaterialControls = owners.some(function(owner) {
      return !!owner.querySelector([
        "iframe", "object", "embed", "video", "audio", "canvas", "table", "form", "input", "button",
        "select", "textarea", "details", "dialog", "meter", "progress", "pre", "code", "kbd", "samp", "tt",
        "[contenteditable]:not([contenteditable='false' i])",
        "[role~='button' i]", "[role~='checkbox' i]", "[role~='combobox' i]", "[role~='listbox' i]",
        "[role~='menuitem' i]", "[role~='option' i]", "[role~='radio' i]", "[role~='searchbox' i]",
        "[role~='slider' i]", "[role~='spinbutton' i]", "[role~='switch' i]", "[role~='tab' i]",
        "[role~='textbox' i]", "[role~='treeitem' i]"
      ].join(", "));
    });
    if (ownerHasMaterialControls) return false;
    var groupHeadings = Array.prototype.filter.call(group.node.querySelectorAll("h1, h2, h3, h4"), function(heading) {
      return !owners.some(function(owner) { return owner.contains(heading); });
    });
    if (groupHeadings.length !== 1) return false;
    var groupHeading = groupHeadings[0];
    if (groupHeading.parentElement !== group.node) return false;
    var precedesEveryOwner = owners.every(function(owner) {
      return !!(groupHeading.compareDocumentPosition(owner) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    if (!precedesEveryOwner) return false;

    var commentOrUpdate = Array.prototype.some.call(wrapper.querySelectorAll("[role~='comment' i], [role~='feed' i], [aria-live], [data-liveblog], [class*='comment' i], [id*='comment' i], [class*='reply' i], [id*='reply' i], [class*='liveblog' i], [class*='live-update' i]"), function(node) {
      return !focal.contains(node);
    });
    if (commentOrUpdate) return false;

    var blocked = Array.prototype.some.call(wrapper.querySelectorAll([
      "table", "figure", "blockquote", "pre", "code", "kbd", "samp", "tt", "time", "img", "picture", "video", "audio",
      "iframe", "object", "embed", "source", "track", "canvas", "svg", "form", "input",
      "button", "select", "textarea", "details", "dialog", "meter", "progress"
    ].join(", ")), function(node) {
      if (focal.contains(node)) return false;
      return !owners.some(function(owner) { return owner.contains(node); });
    });
    if (blocked) return false;

    var unownedParagraph = Array.prototype.some.call(wrapper.querySelectorAll("p, li"), function(node) {
      if (focal.contains(node)) return false;
      return !owners.some(function(owner) { return owner.contains(node); });
    });
    if (unownedParagraph) return false;

    var unownedLink = Array.prototype.some.call(wrapper.querySelectorAll("a[href]"), function(link) {
      if (focal.contains(link) || groupHeading.contains(link)) return false;
      return !owners.some(function(owner) { return owner.contains(link); });
    });
    if (unownedLink) return false;

    var residual = [];
    var walker = document.createTreeWalker(wrapper, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      var parent = walker.currentNode.parentElement;
      if (!parent || focal.contains(parent)) continue;
      if (owners.some(function(owner) { return owner.contains(parent); })) continue;
      if (groupHeading.contains(parent)) continue;
      if (parent.closest("script, style, noscript, template")) continue;
      residual.push(walker.currentNode.nodeValue || "");
    }
    return normalizeText(residual.join(" ")).length === 0;
  }

  function focalOwnershipInnermostCandidates(node) {
    var candidates = Array.prototype.filter.call(node.querySelectorAll(focalOwnershipCandidateSelector()), focalOwnershipCandidate);
    var candidateSet = new Set(candidates);
    var outerCandidates = new Set();

    candidates.forEach(function(candidate) {
      for (var parent = candidate.parentElement; parent && parent !== node; parent = parent.parentElement) {
        if (candidateSet.has(parent)) outerCandidates.add(parent);
      }
    });
    return candidates.filter(function(candidate) { return !outerCandidates.has(candidate); });
  }

  function broadMixedArticleFocal(node) {
    if (!node || !node.querySelectorAll) return null;
    var candidates = focalOwnershipInnermostCandidates(node);
    if (candidates.length !== 1) return null;
    if (likelyListPath() && !candidates[0].matches("article[role~='main' i], [itemprop~='articleBody' i]")) return null;
    if (!articleLikePath() && !candidates[0].matches("article[role~='main' i], [itemprop~='articleBody' i]")) return null;
    return focalOwnershipOutsideIsRail(node, candidates[0]) ? candidates[0] : null;
  }
