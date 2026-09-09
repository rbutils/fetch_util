  function genericListActionAnchor(node) {
    var explicitAction = node && Array.prototype.some.call(node.classList || [], function(name) {
      return /^(?:card|story|teaser|result|news)[-_](?:cta|action)(?:[-_].*)?$/i.test(name);
    });
    return !!(node && node.matches && node.matches("a[href]") &&
      Array.prototype.some.call(node.classList, function(name) {
        return /^(?:card|story|teaser|result|news)[-_](?:cta|link|action)(?:[-_].*)?$/i.test(name);
      }) && !genericListAnchorRecordEvidence(node, !explicitAction));
  }

  function genericListAnchorCardSelector() {
    return "a[href]:has([class$='-name' i]:not(:empty)):has([class$='-desc' i]:not(:empty)), " +
      "a[href]:has(h1, h2, h3, h4):has(p), a[href]:has([class$='-name' i]):has(time, [datetime], [class*='date' i]), " +
      "a[href]:has([class*='title' i]):has([class*='description' i])";
  }

  function genericListAnchorRecordEvidence(link, includeImages) {
    var name = link.querySelector("[class$='-name' i]");
    var description = link.querySelector("[class$='-desc' i]");
    if (name && description && !listCardNodeHidden(name) && !listCardNodeHidden(description) &&
        normalizeText(name.textContent) && normalizeText(description.textContent)) return true;
    var recordEvidence = "article, time, [datetime], [class*='title' i], [class*='summary' i], [class*='description' i], [class*='excerpt' i], [class*='date' i], [class*='duration' i], [class*='count' i], [class*='view' i]";
    if (includeImages !== false) recordEvidence += ", picture, video, img[alt]:not([alt=''])";
    if (Array.prototype.some.call(link.querySelectorAll(recordEvidence), function(node) {
      return !listCardNodeHidden(node) && (!node.matches("article") || !!normalizeText(node.textContent));
    })) return true;
    var text = normalizeText(link.textContent);
    if (includeImages !== false && text.length >= minimumListTitleLength(text) && !genericListControlText(text) &&
        Array.prototype.some.call(link.querySelectorAll("img[src]"), function(image) {
          return materializedHttpUrl(image.getAttribute("src")) && !elementSubtreeHidden(image);
        })) return true;
    var heading = link.querySelector("h1, h2, h3, h4");
    return !!(heading && normalizeText(heading.textContent) &&
      Array.prototype.some.call(link.querySelectorAll("p"), function(paragraph) {
        return !!normalizeText(paragraph.textContent);
      }));
  }

  function genericListWrappedAnchorCard(link) {
    if (!link || !link.matches || !link.matches("a[href]") ||
        !materializedHttpUrl(link.getAttribute("href")) || elementSubtreeHidden(link) ||
        !genericListAnchorRecordEvidence(link)) return false;
    var chromeSelector = "nav, header, footer, aside, [role='navigation'], [role='menu'], [role='menubar'], [role='complementary'], [hidden], [inert], [aria-hidden='true']";
    if (link.closest(chromeSelector)) return false;
    var knownCard = closestGenericListCard(link.parentElement);
    var wrapper = link.parentElement;
    if (!wrapper || wrapper.querySelectorAll("a[href]").length !== 1 || normalizeText(wrapper.textContent) !== normalizeText(link.textContent)) return false;
    var destination = materializedHttpUrl(link.getAttribute("href"));
    while (wrapper && wrapper.parentElement && !wrapper.matches("main, body, html")) {
      var hasIndependentPeer = Array.prototype.some.call(wrapper.parentElement.children, function(peer) {
        var links = peer.querySelectorAll("a[href]");
        var anchor = links.length === 1 && links[0];
        if (!anchor || anchor === link) return false;
        var url = materializedHttpUrl(anchor.getAttribute("href"));
        return !!(url && url !== destination && !anchor.closest(chromeSelector) && !elementSubtreeHidden(anchor) &&
          normalizeText(peer.textContent) === normalizeText(anchor.textContent) &&
          genericListAnchorRecordEvidence(anchor));
      });
      if (hasIndependentPeer) return true;
      if (wrapper === knownCard) break;
      wrapper = wrapper.parentElement;
    }
    return false;
  }

  function genericListDirectAnchorCard(link, container) {
    if (!link || !container || !link.matches("a[href]") || !genericListAnchorRecordEvidence(link)) return false;
    if (link.parentElement !== container) return genericListWrappedAnchorCard(link);
    var peers = Array.prototype.filter.call(container.children, function(child) {
      return child.matches && child.matches("a[href]") &&
        materializedHttpUrl(child.getAttribute("href")) && genericListAnchorRecordEvidence(child);
    });
    return peers.length >= 2 || genericListWrappedAnchorCard(link);
  }

  function genericListDirectAnchorTitle(link, container) {
    if (!genericListDirectAnchorCard(link, container === link ? link.parentElement : container)) return "";
    var titleNode = link.querySelector("[class*='title' i], [class$='-name' i]");
    var title = normalizeText((titleNode && titleNode.textContent) || link.getAttribute("title") || "");
    return title.length >= Math.min(6, minimumListTitleLength(title)) && title.length <= 220 ? title : "";
  }

  function genericListLinkedMediaRowSelector() {
    return ".row:has(> [class*='col-'])";
  }

  function genericListLinkedMediaRow(node) {
    function destination(row) {
      if (!row || !row.matches(genericListLinkedMediaRowSelector()) || elementSubtreeHidden(row) ||
          row.closest("nav, header, footer, aside, menu, form, [role='navigation'], [role='menu'], [role='menubar'], [role='toolbar']")) return null;
      var columns = Array.from(row.children).filter(function(child) { return !elementSubtreeHidden(child); });
      if (columns.length !== 2 || !columns.every(function(column) { return column.matches("[class*='col-']"); })) return null;
      var headings = Array.from(row.querySelectorAll("h1, h2, h3, h4")).filter(function(heading) {
        return !elementSubtreeHidden(heading) && normalizeText(heading.textContent) &&
          (heading.closest("a[href]") || heading.querySelector("a[href]"));
      });
      if (headings.length !== 1) return null;
      var headingLink = headings[0].closest("a[href]") || headings[0].querySelector("a[href]");
      var url = materializedHttpUrl(headingLink.getAttribute("href"));
      if (!url) return null;
      var headingColumn = columns.find(function(column) { return column.contains(headingLink); });
      var links = Array.from(row.querySelectorAll("a[href]")).filter(function(link) { return !elementSubtreeHidden(link); });
      if (!links.every(function(link) {
        var destinationUrl = materializedHttpUrl(link.getAttribute("href"));
        var prose = link.closest("p, figcaption, dd");
        return destinationUrl && (destinationUrl === url || (prose && headingColumn && headingColumn.contains(prose)));
      })) return null;
      var linkedImage = row.querySelectorAll("a[href] img[src]");
      return Array.from(linkedImage).some(function(image) {
        return !elementSubtreeHidden(image) && materializedHttpUrl(image.getAttribute("src")) &&
          materializedHttpUrl(image.closest("a[href]").getAttribute("href")) === url;
      }) ? url : null;
    }

    if (!node || !node.parentElement) return false;
    var url = destination(node);
    return !!url && Array.from(node.parentElement.children).some(function(peer) {
      if (peer === node) return false;
      var other = destination(peer);
      return other && other !== url;
    });
  }
