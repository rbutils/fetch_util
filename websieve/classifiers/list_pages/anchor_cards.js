  function genericListAnchorCardSelector() {
    return "a[href]:has([class$='-name' i]:not(:empty)):has([class$='-desc' i]:not(:empty))";
  }

  function genericListAnchorRecordEvidence(link) {
    var name = link.querySelector("[class$='-name' i]");
    var description = link.querySelector("[class$='-desc' i]");
    if (name && description && normalizeText(name.textContent) && normalizeText(description.textContent)) return true;
    var recordEvidence = "picture, video, img[alt]:not([alt='']), time, [datetime], [class*='title' i], [class*='summary' i], [class*='description' i], [class*='excerpt' i], [class*='date' i], [class*='duration' i], [class*='count' i], [class*='view' i]";
    if (link.querySelector(recordEvidence)) return true;
    var heading = link.querySelector("h1, h2, h3, h4");
    return !!(heading && normalizeText(heading.textContent) &&
      Array.prototype.some.call(link.querySelectorAll("p"), function(paragraph) {
        return !!normalizeText(paragraph.textContent);
      }));
  }

  function genericListDirectAnchorCard(link, container) {
    if (!link || !container || link.parentElement !== container || !link.matches("a[href]")) return false;
    if (!genericListAnchorRecordEvidence(link)) return false;

    var peers = Array.prototype.filter.call(container.children, function(child) {
      return child.matches && child.matches("a[href]") &&
        materializedHttpUrl(child.getAttribute("href")) && genericListAnchorRecordEvidence(child);
    });
    return peers.length >= 2;
  }

  function genericListDirectAnchorTitle(link, container) {
    if (!genericListDirectAnchorCard(link, container === link ? link.parentElement : container)) return "";

    var titleNode = link.querySelector("[class*='title' i], [class$='-name' i]");
    var title = normalizeText((titleNode && titleNode.textContent) || link.getAttribute("title") || "");
    return title.length >= 6 && title.length <= 220 ? title : "";
  }
