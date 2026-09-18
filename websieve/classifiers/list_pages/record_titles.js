  function genericListDirectAnchorTitle(link, container) {
    if (!genericListDirectAnchorCard(link, container === link ? link.parentElement : container)) return "";
    var titleNode = link.querySelector("[class*='title' i], [class$='-name' i]");
    var title = normalizeText((titleNode && titleNode.textContent) || link.getAttribute("title") || "");
    return title.length >= Math.min(6, minimumListTitleLength(title)) && title.length <= 220 ? title : "";
  }

  function genericListAuthorFieldAmbiguous(node) {
    return Array.from(node.querySelectorAll("*")).some(function(descendant) {
      if (!normalizeText(descendant.textContent || "")) return false;
      return listCardNodeHidden(descendant) || !!genericListInteractionOwner(descendant);
    });
  }

  function genericListOwnedAnchorTitle(link) {
    if (!link || !link.matches || !link.matches("a[href]") ||
        !materializedHttpUrl(link.getAttribute("href"))) return "";
    var record = link.closest("article, li, tr");
    if (!record || genericListPrimaryHeadingLink(record) !== link) return "";

    var headings = Array.from(link.querySelectorAll("h1, h2, h3, h4"));
    if (headings.length !== 1) return "";
    var heading = headings[0];
    var titleFields = Array.from(heading.querySelectorAll(
      "[itemprop~='headline'], [class~='title'], [class*='__title'], [class$='-title']"
    )).filter(function(node) {
      return !listCardNodeHidden(node) && !genericListAuthorMetadataNode(node);
    });
    if (titleFields.length !== 1) return "";

    var title = normalizeText(titleFields[0].textContent || "");
    var declaredTitle = normalizeText(link.getAttribute("title") || "");
    if (!title || declaredTitle !== title || title.length > 220) return "";

    var authorFields = Array.from(heading.querySelectorAll("*"))
      .filter(function(node) {
        return genericListAuthorMetadataNode(node) && !genericListInteractionOwner(node) &&
          !listCardNodeHidden(node) && !genericListAuthorFieldAmbiguous(node);
      })
      .filter(function(node, _index, fields) {
        return !fields.some(function(owner) { return owner !== node && owner.contains(node); });
      });
    if (authorFields.length !== 1) return "";

    var author = normalizeText(authorFields[0].textContent || "");
    var headingText = normalizeText(heading.textContent || "");
    if (!author || (headingText !== normalizeText(title + " " + author) &&
        headingText !== normalizeText(author + " " + title))) return "";
    return title;
  }

  function genericLinkedCollectionHeading(link, card) {
    if (!homepageRootPath() || !link || !card || !card.contains(link)) return false;
    var heading = link.closest("h1, h2, h3");
    if (!heading || heading.closest("article, li, tr") ||
        heading.closest("nav, header, footer, form, menu, [role='navigation'], [role='menu'], [role='toolbar']")) return false;
    var links = Array.from(heading.querySelectorAll("a[href]"));
    var url = links.length === 1 && materializedHttpUrl(link.getAttribute("href"));
    if (!url || links[0] !== link || url.split("#")[0] === location.href.split("#")[0]) return false;

    var hints = [heading.id, heading.className, link.id, link.className].join(" ").replace(/([a-z\d])([A-Z])/g, "$1 $2");
    if (!/(?:^|[\s_-])(?:section|category|topic|desk|collection|widget)(?:$|[\s_-])/i.test(hints) ||
        !/(?:^|[\s_-])(?:title|heading)(?:$|[\s_-])/i.test(hints)) return false;

    var records = Array.from(card.querySelectorAll("article, li, tr")).filter(function(record) {
      if (record.parentElement && record.parentElement.closest("article, li, tr")) return false;
      if (record.closest("nav, header, footer, form, menu, [role='navigation'], [role='menu'], [role='toolbar']")) return false;
      return !listCardNodeHidden(record) && !!genericListPrimaryHeadingLink(record);
    });
    return records.length >= 2;
  }
