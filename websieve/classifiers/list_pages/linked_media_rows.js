  function genericListLinkedMediaRowSelector() {
    return ".row:has(> [class*='col-'])";
  }

  function genericListLinkedMediaRow(node) {
    function destination(row) {
      if (!row || !row.matches(genericListLinkedMediaRowSelector()) || elementSubtreeHidden(row) ||
          listExplicitAdvertisementOwner(row) ||
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
