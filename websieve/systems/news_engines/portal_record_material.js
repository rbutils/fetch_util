  function homepageLeadOwnsUnlinkedArticleHeading(item) {
    var card = item.card;
    var link = item.sourceNode;
    if (!card || card.localName !== "article" || !link || !card.contains(link)) return false;
    var headings = cardOwnedNodes(card, "h1, h2, h3, h4, h5, h6").filter(function(heading) {
      return !elementSubtreeHidden(heading) &&
        !heading.closest("pre, code, kbd, samp, blockquote, nav, aside, button, details, [role='navigation'], [role='toolbar'], [role='button'], [role='menuitem']");
    });
    if (headings.length !== 1 || headings[0].closest("a[href]") ||
        headings[0].querySelector("a[href]") || !normalizeText(headings[0].textContent)) return false;
    var destination = materializedHttpUrl(item.url || "");
    if (!destination) return false;
    var links = cardOwnedNodes(card, "a[href]").filter(function(other) { return !elementSubtreeHidden(other); });
    return links.indexOf(link) !== -1 && links.every(function(other) {
      var url = materializedHttpUrl(other.getAttribute("href"));
      return url && listCanonicalKey(url) === listCanonicalKey(destination);
    });
  }

  function homepageLeadMatchesSelectedRecords(lead, selected) {
    var extraction = selected && selected.listExtraction;
    var items = extraction && extraction.items;
    var clones = extraction && extraction.sourceClones;
    return clones && items && items.length === lead.items.length && lead.items.every(function(item, index) {
      return homepageLeadOwnsUnlinkedArticleHeading(item) &&
        clones.get(item.sourceNode) === items[index].sourceNode &&
        clones.get(item.card) === items[index].card;
    });
  }

  function homepageLeadRetainingSelectedMaterial(lead, selected, markdown) {
    if (!homepageLeadMatchesSelectedRecords(lead, selected)) return null;
    selected.markdown = markdown;
    selected.textContent = normalizeText(markdown);
    selected.listArbitrationMarkdown = markdown;
    if (selected.sectionMarkdownWithDescription) selected.sectionMarkdownWithDescription = markdown;
    return selected;
  }

  function homepageLeadForSelectedMaterial(lead, selected) {
    if (!homepageLeadMatchesSelectedRecords(lead, selected)) return lead;
    return Object.assign({}, lead, {
      items: lead.items.map(function(item) {
        return Object.assign({}, item, { sourceOrderedRepeatedRecord: true });
      })
    });
  }
