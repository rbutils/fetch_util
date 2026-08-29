  function genericListCardSelector() {
    return "tr, article, li, .post, .entry, [class*='card'], [class*='story'], [class*='teaser'], [class*='item'], [class*='result'], [class*='news'], [class*='headline']";
  }

  function genericListPresentationCardNode(node) {
    var classes = ((node && node.getAttribute && node.getAttribute("class")) || "").split(/\s+/);
    return classes.some(function(name) {
      return /^(?:card|story|teaser|result|news|headline)[-_]+(?:body|content|meta(?:data)?|header|footer|details?)(?:[-_].*)?$/i.test(name) ||
        /^item[-_]+meta(?:data)?(?:[-_].*)?$/i.test(name);
    });
  }

  function genericListCardBoundary(node) {
    if (!node || !node.matches || !node.matches(genericListCardSelector())) return false;
    if (genericListPresentationCardNode(node)) return false;
    if (node.matches("main, [role='main']")) return false;
    if (!node.matches(".post, .entry")) return true;

    var links = node.matches("a[href]") ? [node] : Array.prototype.slice.call(node.querySelectorAll("a[href]"));
    var ownedLinks = links.filter(function(link) {
      return link.closest(".post, .entry") === node &&
        !link.matches("[rel='author'], [itemprop='author']") &&
        !link.closest("[class*='author' i], [class*='byline' i]");
    });
    if (!ownedLinks.length) return false;

    var hasNestedCard = Array.prototype.some.call(node.querySelectorAll(genericListCardSelector()), genericListNestedCard);
    if (!hasNestedCard) return true;
    return ownedLinks.some(function(link) {
      return link.parentElement === node || !!link.closest("h1, h2, h3, h4");
    });
  }

  function closestGenericListCard(node) {
    var current = node;
    while (current && current.closest) {
      var card = current.closest(genericListCardSelector());
      if (!card) return null;
      if (genericListCardBoundary(card)) return card;
      current = card.parentElement;
    }
    return null;
  }

  function genericListFieldBoundary(node) {
    if (!genericListCardBoundary(node)) return false;
    return !(node.matches && node.matches("li")) || genericListNestedCard(node);
  }

  function closestGenericListFieldCard(node) {
    var current = node;
    while (current && current.closest) {
      var card = current.closest(genericListCardSelector());
      if (!card) return null;
      if (genericListFieldBoundary(card)) return card;
      current = card.parentElement;
    }
    return null;
  }

  function genericListCardText(node) {
    if (!node || !node.cloneNode) return "";
    var clone = node.cloneNode(true);
    clone.querySelectorAll(genericListCardSelector()).forEach(function(nested) {
      if (genericListFieldBoundary(nested)) nested.remove();
    });
    return normalizeText(clone.textContent || "");
  }

  function genericListNestedCard(node) {
    if (!node || !node.querySelector || !genericListCardBoundary(node)) return false;
    var explicitCard = node.matches && node.matches("tr, article, li, .post, .entry");
    var linkSelector = explicitCard ? "a[href]" : "h1 a[href], h2 a[href], h3 a[href], h4 a[href]";
    return !!node.querySelector(linkSelector);
  }

  function genericListNestedCardReplaces(card, nested) {
    if (card && card.matches && card.matches("tr")) return false;
    return !(card && nested && card.matches && nested.matches &&
      card.matches(".post, .entry") && nested.matches(".post, .entry") &&
      genericListCardBoundary(card) && genericListCardBoundary(nested));
  }

  function genericListContextCard(card) {
    if (!card || !card.parentElement) return card;
    var outer = card.parentElement.closest && card.parentElement.closest(".post, .entry");

    while (outer && !genericListCardBoundary(outer)) {
      var materialCards = Array.prototype.filter.call(outer.querySelectorAll(genericListCardSelector()), function(nested) {
        if (!genericListNestedCard(nested)) return false;
        var ancestor = nested.parentElement;
        while (ancestor && ancestor !== outer) {
          if (genericListNestedCard(ancestor)) return false;
          ancestor = ancestor.parentElement;
        }
        return ancestor === outer;
      });
      if (materialCards.length !== 1 || materialCards[0] !== card) break;
      card = outer;
      outer = card.parentElement && card.parentElement.closest && card.parentElement.closest(".post, .entry");
    }
    return card;
  }

  function listCardRoot(link, fallback) {
    if (fallback && fallback.matches && fallback.matches("tr")) return fallback;
    var card = genericListContextCard(closestGenericListCard(link));
    return card || fallback || (link && link.parentElement);
  }
