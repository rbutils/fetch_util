  function listAncestorOfType(link, nodeChecker) {
    var node = link && link.parentElement;

    while (node && node !== document.body) {
      if (node.matches && node.matches("article, li, main, [role='main']")) return null;
      if (node.matches && node.matches("header") && link.closest("article, section, main, [role='main']")) {
        node = node.parentElement;
        continue;
      }
      if (nodeChecker(node)) return node;
      node = node.parentElement;
    }

    return null;
  }

  function listChromeAncestor(link) {
    return listAncestorOfType(link, listChromeNode);
  }

  function listNavigationAncestor(link) {
    return listAncestorOfType(link, listNavigationNode);
  }

  function listHeaderVisibleRecordEvidence(card) {
    var selector = "picture, video, img[src], img[alt]:not([alt='']), p, time, [datetime], [class*='summary' i], [class*='description' i], [class*='excerpt' i], [class*='date' i], [class*='duration' i], [class*='count' i], [class*='view' i], [class*='pages' i]";
    return Array.prototype.some.call(card.querySelectorAll(selector), function(node) {
      if (elementVisuallyHidden(node) || closestGenericListCard(node) !== card) return false;
      if (node.matches("img")) return !!(node.getAttribute("src") || normalizeText(node.getAttribute("alt") || ""));
      if (node.matches("picture")) return Array.prototype.some.call(node.querySelectorAll("img[src], source[srcset]"), function(media) {
        return !elementVisuallyHidden(media) && !!(media.getAttribute("src") || media.getAttribute("srcset"));
      });
      if (node.matches("video")) return !!(node.getAttribute("src") || node.getAttribute("poster") ||
        Array.prototype.some.call(node.querySelectorAll("source[src]"), function(source) { return !elementVisuallyHidden(source); }));
      return !!(normalizeText(node.textContent || "") || node.getAttribute("datetime"));
    });
  }

  function listHeaderPrimaryLink(card) {
    if (!card || !card.querySelectorAll || elementVisuallyHidden(card) ||
        card.closest("nav, [role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='banner']")) return null;
    var headingLinks = Array.prototype.filter.call(card.querySelectorAll("h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href] h1, a[href] h2, a[href] h3, a[href] h4"), function(node) {
      var link = node.matches("a[href]") ? node : node.closest("a[href]");
      var heading = node.matches("h1, h2, h3, h4") ? node : link && link.querySelector("h1, h2, h3, h4");
      var titleNode = heading || link;
      var title = normalizeText(titleNode && titleNode.textContent || "");
      return link && titleNode && !elementVisuallyHidden(link) && !elementVisuallyHidden(titleNode) &&
        !link.matches("[rel~='author'], [itemprop~='author']") &&
        materializedHttpUrl(link.getAttribute("href")) && title.length >= minimumListTitleLength(title) &&
        !genericListControlText(title);
    }).map(function(node) { return node.matches("a[href]") ? node : node.closest("a[href]"); });
    var structuredTitleLinks = Array.prototype.filter.call(card.querySelectorAll("a[href]"), function(link) {
      var titleFields = Array.prototype.filter.call(link.querySelectorAll("[class*='title' i], [class$='-name' i]"), function(field) {
        return !elementVisuallyHidden(field);
      });
      var title = normalizeText(titleFields.length === 1 && titleFields[0].textContent || "");
      return !elementVisuallyHidden(link) && !!link.querySelector("header") && titleFields.length === 1 &&
        title.length >= minimumListTitleLength(title) && materializedHttpUrl(link.getAttribute("href")) &&
        !genericListControlText(title);
    });
    var links = headingLinks.concat(structuredTitleLinks);
    var uniqueLinks = Array.from(new Set(links));
    return uniqueLinks.length === 1 && (headingLinks.length > 0 || listHeaderVisibleRecordEvidence(card)) ? uniqueLinks[0] : null;
  }

  function listHeaderOwnedRecordLink(card) {
    var primaryLink = listHeaderPrimaryLink(card);
    if (!primaryLink) return null;
    var parent = card.parentElement;
    while (parent && !parent.matches("body, html")) {
      var destinations = new Set();
      var recordLinks = [];
      Array.prototype.forEach.call(parent.children, function(sibling) {
        if (elementVisuallyHidden(sibling)) return;
        var link = listHeaderPrimaryLink(sibling);
        var url = materializedHttpUrl(link && link.getAttribute("href"));
        if (!url) return;
        var destination = listCanonicalKey(url);
        if (destinations.has(destination)) return;
        destinations.add(destination);
        recordLinks.push(link);
      });
      if (recordLinks.length >= 4 && recordLinks.indexOf(primaryLink) >= 0) return primaryLink;
      if (parent.matches("main, [role='main']")) break;
      parent = parent.parentElement;
    }
    return null;
  }

  function listExplicitAdvertisementNode(node) {
    if (!node || node.nodeType !== 1 || node.matches("main, body, html")) return false;
    return [node.getAttribute("id")].concat(Array.from(node.classList || [])).some(function(name) {
      return /^(?:ad|ads|advert|advertisement)(?:[-_](?:banner|card|container|module|slot|unit|wrapper))?$/i.test(name || "");
    });
  }

  function listExplicitAdvertisementOwner(node) {
    var current = node;
    while (current && !current.matches("main, body, html")) {
      if (listExplicitAdvertisementNode(current)) return current;
      current = composedDomParent(current);
    }
    return null;
  }

  function listNamedSectionLinksNode(node) {
    return [node.id, node.getAttribute("class"), node.getAttribute("data-testid")].some(function(value) {
      return String(value || "").split(/\s+/).some(function(token) {
        var normalized = token.replace(/([a-z\d])([A-Z])/g, "$1-$2").toLowerCase();
        var parts = normalized.split("__");
        if (parts.length > 2) return false;
        if (!/^named[-_]section[-_]links?(?:[_-]+(?:items?|list|menu|more|nav|title|wrapper|named[-_]section[-_]links?))?$/.test(parts[0])) return false;
        return parts.length === 1 || !/^(?:article|card|content|record|story)(?:[-_]|$)/.test(parts[1]);
      });
    });
  }

  function listChromeOrNavigationNode(node, includeSocial) {
    if (!node || node.nodeType !== 1) return false;
    if (node.matches("header") || Array.from(node.classList || []).some(function(name) {
      return /(?:^|[-_])header(?:$|[-_])/i.test(name);
    })) {
      var card = closestGenericListCard(node);
      var explicitNavigation = node.closest("nav, [role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='banner']");
      var primaryLink = null;
      if (card && !explicitNavigation) {
        var genericLink = genericListStructuredCardLink(card);
        var visiblePrimaryLink = listHeaderPrimaryLink(card);
        primaryLink = genericLink && genericLink === visiblePrimaryLink ? genericLink : listHeaderOwnedRecordLink(card);
      }
      if (primaryLink && (node.contains(primaryLink) || primaryLink.contains(node))) return false;
    }
    if (node.matches("nav, header, footer, menu, [role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='banner'], [role='contentinfo']")) return true;
    if (node.matches("html, body")) return false;

    var ariaLabel = node.getAttribute("aria-label");
    if (ariaLabel && node.matches("a[href]")) {
      var record = closestGenericListCard(node.parentElement);
      if (record && genericListStructuredCardLink(record) === node) ariaLabel = "";
    }
    var ownershipClasses = Array.from(node.classList || []).filter(function(name) {
      // A page can hide its sticky footer without becoming footer chrome itself.
      return !/^(?:hide|hidden|no)[-_](?:sticky[-_])?(?:footer|header|sidebar|nav(?:igation)?)$/i.test(name);
    });
    var attrs = normalizeText([
      node.getAttribute("id"),
      ownershipClasses.join(" "),
      node.getAttribute("role"),
      ariaLabel,
      node.getAttribute("data-testid")
    ].join(" ")).replace(/([a-z\d])([A-Z])/g, "$1 $2").toLowerCase();
    attrs = listEditorialAsideHints(node, attrs);

    if (!attrs) return false;
    if (/(news|headline|story|article|post|feed|stream|content|result|listing|archive|topic|thread|discussion|feature)/.test(attrs)) return false;
    if (includeSocial && /(?:^|[\s_-])meta(?:data)?(?:$|[\s_-])/.test(attrs)) {
      var card = closestGenericListCard(node.parentElement);
      var primaryLink = card && genericListStructuredCardLink(card);
      if (primaryLink && node.contains(primaryLink)) return false;
    }
    var navigation = listNamedSectionLinksNode(node) || /(?:^|[\s_-])(?:site|nav)[-_ ]links?(?:$|[\s_-])/.test(attrs) ||
      /nav(?:igation|bar|menu|links?|items?|list|container)?(?:$|[\s_-])|(?:^|[\s_-])pager(?:$|[\s_-])/.test(attrs);
    if (includeSocial) return navigation || /(menu|menubar|breadcrumb|breadcrumbs|pagination|footer|header|toolbar|sidebar|drawer|utility|meta|social|share|follow|account|login|signup|register)/.test(attrs);
    return navigation || /(menu|menubar|breadcrumb|breadcrumbs|pagination|footer|header|toolbar|sidebar|drawer)/.test(attrs);
  }

  function listChromeNode(node) {
    return listChromeOrNavigationNode(node, true);
  }

  function listNavigationNode(node) {
    return listChromeOrNavigationNode(node, false);
  }

  function genericListChromeOwnedRecordRoots(node) {
    if (!node || !node.querySelectorAll) return [];

    var selector = "ul, ol, [role='list'], [class*='listing' i], [class*='grid' i], [class*='feed' i], [class*='results' i]";
    var collections = Array.prototype.slice.call(node.querySelectorAll(selector));
    if (homepageRootPath()) node.querySelectorAll(genericListCardSelector()).forEach(function(card) {
      if (genericListStructuredCardLink(card) && collections.indexOf(card.parentElement) < 0) collections.push(card.parentElement);
    });
    var roots = [];
    collections.forEach(function(collection) {
      if (listChromeNode(collection) || (!homepageRootPath() && scoreListContainer(collection, listPageContext()) === -Infinity)) return;
      var records = Array.prototype.filter.call(collection.querySelectorAll(genericListCardSelector()), function(card) {
        return !!genericListStructuredCardLink(card);
      });
      var recordRoots = [];
      records.forEach(function(record) {
        var root = record.parentElement;
        if (recordRoots.indexOf(root) < 0) recordRoots.push(root);
      });
      recordRoots.forEach(function(root) {
        if (roots.indexOf(root) >= 0) return;
        var peers = Array.prototype.filter.call(root.children, function(sibling) {
          return !!genericListStructuredCardLink(sibling);
        });
        if (peers.length >= 4) roots.push(root);
      });
    });
    return roots.filter(function(root) {
      return !roots.some(function(other) {
        return other !== root && other.contains(root);
      });
    }).sort(function(a, b) {
      return a === b ? 0 : (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1);
    });
  }

  function genericListChromeOwnsCollection(node) {
    return genericListChromeOwnedRecordRoots(node).length > 0;
  }
