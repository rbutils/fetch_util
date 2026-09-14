  function genericListOverlayCardLink(card) {
    if (!card || !card.querySelector || !card.querySelector("a[href][aria-label]")) return null;
    var headings = Array.from(card.querySelectorAll("h1, h2, h3, h4")).filter(function(heading) {
      return !heading.closest("a[href]") && !listCardNodeHidden(heading) && closestGenericListCard(heading.parentElement) === card;
    });
    if (!headings.length || !Array.from(card.querySelectorAll("img, picture, p, time")).some(function(node) {
      return !listCardNodeHidden(node) && closestGenericListCard(node.parentElement) === card;
    })) return null;

    var candidates = Array.from(card.querySelectorAll("a[href][aria-label]")).filter(function(link) {
      if (normalizeText(link.textContent) || listCardNodeHidden(link) || closestGenericListCard(link.parentElement) !== card) return false;
      var label = normalizeText(link.getAttribute("aria-label"));
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (!url || label.length < minimumListTitleLength(label) || genericListControlText(label) || looksLikeFooterLink(label, url)) return false;
      return headings.some(function(heading) {
        return normalizeText(heading.textContent) === label || Array.from(heading.children).some(function(part) {
          return normalizeText(part.textContent) === label;
        });
      });
    });
    if (!candidates.length || new Set(candidates.map(function(link) {
      return materializedHttpUrl(link.getAttribute("href"));
    })).size !== 1) return null;
    return candidates[0];
  }
