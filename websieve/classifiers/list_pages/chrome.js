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

  function listChromeOrNavigationNode(node, includeSocial) {
    if (!node || node.nodeType !== 1) return false;
    if (node.matches("nav, header, footer, menu, [role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='banner'], [role='contentinfo']")) return true;

    var ariaLabel = node.getAttribute("aria-label");
    if (ariaLabel && node.matches("a[href]")) {
      var record = closestGenericListCard(node.parentElement);
      if (record && genericListStructuredCardLink(record) === node) ariaLabel = "";
    }
    var attrs = normalizeText([
      node.getAttribute("id"),
      node.getAttribute("class"),
      node.getAttribute("role"),
      ariaLabel,
      node.getAttribute("data-testid")
    ].join(" ")).toLowerCase();

    if (!attrs) return false;
    if (/(news|headline|story|article|post|feed|stream|content|result|listing|archive|topic|thread|discussion|feature)/.test(attrs)) return false;
    if (includeSocial && /(?:^|[\s_-])meta(?:data)?(?:$|[\s_-])/.test(attrs)) {
      var card = closestGenericListCard(node.parentElement);
      var primaryLink = card && genericListStructuredCardLink(card);
      if (primaryLink && node.contains(primaryLink)) return false;
    }
    if (includeSocial) return /(nav|menu|menubar|navbar|breadcrumb|breadcrumbs|pager|pagination|footer|header|toolbar|sidebar|drawer|utility|meta|social|share|follow|account|login|signup|register)/.test(attrs);
    return /(nav|menu|menubar|navbar|breadcrumb|breadcrumbs|pager|pagination|footer|header|toolbar|sidebar|drawer)/.test(attrs);
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
