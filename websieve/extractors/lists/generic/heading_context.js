  function listOwnedHeadingContainer(node) {
    if (!homepageRootPath() || !node.parentElement || !node.matches("div, section")) return false;
    if (node.closest("nav, header, footer, form, menu, [role='navigation'], [role='menu'], [role='toolbar'], [role='banner'], [role='contentinfo']")) return false;
    var hints = [node.id, node.className].join(" ").replace(/([a-z\d])([A-Z])/g, "$1 $2");
    if (!/(?:^|[\s_-])header(?:$|[\s_-])/i.test(hints)) return false;
    var headings = node.querySelectorAll("h1, h2, h3, h4, h5, h6");
    if (headings.length !== 1 || !normalizeText(headings[0].textContent) ||
        normalizeText(node.textContent) !== normalizeText(headings[0].textContent)) return false;

    var destinations = new Set();
    function admit(link, text, media) {
      if (!link || node.contains(link)) return;
      var href = link.getAttribute("href");
      var url = materializedHttpUrl(href);
      if (!url || !text || url.split("#")[0] === location.href.split("#")[0]) return;
      if (!media && text.length < minimumListTitleLength(text)) return;
      if (genericListControlText(text) || looksLikeFooterLink(text, href)) return;
      destinations.add(url);
    }
    node.parentElement.querySelectorAll("h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href] h1, a[href] h2, a[href] h3, a[href] h4").forEach(function(heading) {
      admit(heading.closest("a[href]"), normalizeText(heading.textContent), false);
    });
    node.parentElement.querySelectorAll("a[href] img").forEach(function(image) {
      var link = image.closest("a[href]");
      var text = normalizeText(link.textContent) || normalizeText(link.getAttribute("aria-label")) || normalizeText(image.getAttribute("alt"));
      admit(link, text, true);
    });
    return destinations.size >= 2;
  }
