  function genericListPairedMediaCard(link) {
    if (!link || !link.matches || !link.matches("a[href]") || listCardNodeHidden(link) ||
        link.closest("nav, header, footer, aside, menu, form, [role='navigation'], [role='menu'], [role='menubar'], [role='toolbar']")) return null;
    var url = materializedHttpUrl(link.getAttribute("href"));
    if (!url) return null;
    var parent = link.parentElement;
    while (parent && !parent.matches("main, body, html, article, li, tr, .post, .entry, .product, .product-tile, [itemtype$='/Product']")) {
      if (listCardNodeHidden(parent) || listChromeNode(parent)) return null;
      var links = Array.from(parent.querySelectorAll("a[href]")).filter(function(anchor) { return !listCardNodeHidden(anchor); });
      if (links.length > 2) return null;
      if (links.length === 2 && links.every(function(anchor) { return materializedHttpUrl(anchor.getAttribute("href")) === url; })) {
        var image = links.find(function(anchor) {
          return Array.from(anchor.querySelectorAll("img[src]")).some(function(node) {
            return !listCardNodeHidden(node) && materializedHttpUrl(node.getAttribute("src"));
          });
        });
        var name = links.find(function(anchor) {
          var text = normalizeText(anchor.textContent);
          return anchor !== image && !anchor.querySelector("img") && text.length >= minimumListTitleLength(text) &&
            !genericListControlText(text) && !looksLikeFooterLink(text, url);
        });
        var branches = Array.from(parent.children).filter(function(node) {
          return !node.matches("script, style, template") && !listCardNodeHidden(node);
        });
        if (image && name && branches.length === 2 && branches.every(function(branch) {
          return branch.contains(image) !== branch.contains(name);
        }) && !Array.from(parent.childNodes).some(function(node) { return node.nodeType === 3 && normalizeText(node.textContent); })) return parent;
      }
      parent = parent.parentElement;
    }
    return null;
  }

  function genericListImageTitleCard(link) {
    if (!link || !link.matches || !link.matches("a[href]") || listCardNodeHidden(link) ||
        link.closest("nav, header, footer, aside, menu, form, [role='navigation'], [role='menu'], [role='menubar'], [role='toolbar']")) return null;
    var url = materializedHttpUrl(link.getAttribute("href"));
    var destinationPath = "";
    var text = normalizeText(link.textContent);
    if (!url || !text || genericListControlText(text) || looksLikeFooterLink(text, url)) return null;
    try {
      var destination = new URL(url);
      destinationPath = destination.origin + destination.pathname;
    } catch (_error) {
      return null;
    }
    if (text.length >= minimumListTitleLength(text)) return null;
    if (!link.matches("[class*='title' i], [class*='name' i]") &&
        !link.closest("h1, h2, h3, h4, [class*='title' i], [class*='name' i]")) return null;

    var card = link.parentElement;
    while (card && card !== document.body) {
      if (!listCardNodeHidden(card) && !listChromeNode(card)) {
        var titleLinks = Array.from(card.querySelectorAll("a[href]")).filter(function(anchor) {
          if (listCardNodeHidden(anchor) || anchor.querySelector("img")) return false;
          var anchorText = normalizeText(anchor.textContent);
          return !!anchorText && !genericListControlText(anchorText) && !looksLikeFooterLink(anchorText, url) &&
            (anchor.matches("[class*='title' i], [class*='name' i]") ||
              !!anchor.closest("h1, h2, h3, h4, [class*='title' i], [class*='name' i]"));
        });
        var destinationLinks = Array.from(card.querySelectorAll("a[href]")).filter(function(anchor) {
          if (listCardNodeHidden(anchor)) return false;
          var anchorUrl = materializedHttpUrl(anchor.getAttribute("href"));
          if (!anchorUrl) return false;
          try {
            var anchorDestination = new URL(anchorUrl);
            return anchorDestination.origin + anchorDestination.pathname === destinationPath;
          } catch (_error) {
            return false;
          }
        });
        var hasImage = Array.from(card.querySelectorAll("img[src]")).some(function(image) {
          return !listCardNodeHidden(image) && materializedHttpUrl(image.getAttribute("src"));
        });
        var peers = card.parentElement && Array.from(card.parentElement.children).filter(function(peer) {
          if (peer.tagName !== card.tagName || listCardNodeHidden(peer)) return false;
          var sharedClass = Array.from(card.classList || []).some(function(className) {
            return className.length >= 4 && peer.classList.contains(className);
          });
          return sharedClass && !!peer.querySelector("img[src]") && !!peer.querySelector("a[href]");
        });
        if (titleLinks.length === 1 && titleLinks[0] === link && destinationLinks.length >= 2 &&
            hasImage && peers && peers.length >= 3) return card;
      }
      card = card.parentElement;
    }
    return null;
  }
