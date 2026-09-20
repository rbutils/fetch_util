  function listOwnedHeadingContainer(node) {
    if (!homepageRootPath() || !node.parentElement) return false;
    var sectionHeader = node.matches("header") && node.parentElement.matches("section");
    if (!sectionHeader && !node.matches("div, section")) return false;
    if ((sectionHeader ? node.parentElement : node).closest("nav, header, footer, form, menu, [role='navigation'], [role='menu'], [role='toolbar'], [role='banner'], [role='contentinfo']")) return false;
    if (node.matches("[role='banner'], [role='navigation'], [role='menu'], [role='toolbar']")) return false;
    var hints = [node.id, node.className].join(" ").replace(/([a-z\d])([A-Z])/g, "$1 $2");
    if (!sectionHeader && !/(?:^|[\s_-])header(?:$|[\s_-])/i.test(hints)) return false;
    var headings = node.querySelectorAll("h1, h2, h3, h4, h5, h6");
    var content = node.cloneNode(true);
    if (sectionHeader) content.querySelectorAll("nav, menu, button, [role='navigation'], [role='menu'], [role='toolbar']").forEach(function(control) { control.remove(); });
    if (headings.length !== 1 || !normalizeText(headings[0].textContent) ||
        normalizeText(content.textContent) !== normalizeText(headings[0].textContent)) return false;

    var destinations = new Set();
    function admit(link, text, media) {
      if (!link || node.contains(link)) return;
      if (sectionHeader && link.closest("section") !== node.parentElement) return;
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

  function listLinkedSectionHeading(node, root, items, primaryUrls) {
    if (!items || !items.length || node.closest("a[href], nav, header, footer, form, menu, [role='navigation'], [role='menu'], [role='toolbar']")) return false;
    var links = Array.from(node.querySelectorAll("a[href]"));
    var destinations = new Set();
    if (!links.length || !links.every(function(link) {
      var text = normalizeText(link.textContent);
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (!text || !url || primaryUrls.has(listCanonicalKey(url)) || url.split("#")[0] === location.href.split("#")[0]) return false;
      if (genericListControlText(text) || looksLikeFooterLink(text, url)) return false;
      destinations.add(url);
      return true;
    }) || !destinations.size) return false;

    var remainder = node.cloneNode(true);
    remainder.querySelectorAll("a[href]").forEach(function(link) { link.remove(); });
    if (normalizeText(remainder.textContent).replace(/[\s\-–—|/·•&+,;:]+/g, "")) return false;

    for (var owner = node.parentElement; owner && !owner.matches("html, body"); owner = owner.parentElement) {
      var records = items.filter(function(item) {
        var source = item.sourceNode || item.card;
        return source && owner.contains(source) && !node.contains(source);
      });
      if (records.length >= 2) return true;
      if (owner === root || owner.matches("article, section, aside")) break;
    }
    return false;
  }

  function listCardHeaderTitles(root) {
    var titles = Array.from(root.querySelectorAll("h1, h2, h3, h4, [role='heading'], [itemprop~='headline'], [class*='title' i], [class*='headline' i]")).filter(function(node) {
      if (node.matches("h1, h2, h3, h4, [role='heading'], [itemprop~='headline']")) return true;
      var hints = (node.getAttribute("class") || "").replace(/([a-z\d])([A-Z])/g, "$1 $2");
      var text = normalizeText(node.textContent);
      return /(?:^|[\s_-])(?:title|headline)(?:$|[\s_-])/i.test(hints) && text.length >= minimumListTitleLength(text);
    });
    return titles.filter(function(node) {
      return !titles.some(function(other) { return other !== node && node.contains(other); });
    });
  }

  function unwrapListOwnedHeaders(root) {
    root.querySelectorAll("header").forEach(function(header) {
      if (header.matches("[role='banner'], [role='navigation'], [role='menu'], [role='toolbar']")) return;
      if (listOwnedHeadingContainer(header)) {
        header.replaceWith.apply(header, Array.from(header.childNodes));
        return;
      }
      var card = header.closest("article, li") || closestGenericListCard(header.parentElement);
      if (!card || card.contains(header) === false || card.closest("header, nav, footer, menu, [role='navigation'], [role='banner']")) return;
      var headings = listCardHeaderTitles(header);
      if (headings.length !== 1 || !normalizeText(headings[0].textContent)) return;
      var link = genericListStructuredCardLink(card);
      if (!link && card.matches("article, li") && !genericListPageContainer(card)) {
        var ownedHeadings = listCardHeaderTitles(card).filter(function(heading) {
          return heading.closest("article, li") === card;
        });
        if (ownedHeadings.length === 1) link = headings[0].closest("a[href]") || headings[0].querySelector("a[href]");
      }
      if (!link || !(header.contains(link) || link.contains(header))) return;
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (!url || url.split("#")[0] === location.href.split("#")[0]) return;
      header.replaceWith.apply(header, Array.from(header.childNodes));
    });
  }
