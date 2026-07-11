  var onetHomepageDescriptor = {
    regionSelector: "section[class*='Feed_']",
    skipEditorialGuard: true,
    cardSelector: "article[class*='Card_']",
    directCard: true,
    headingBuilder: onetRegionHeading,
    additionalRegions: onetContinuationRegions,
    fallbackHeadingBuilder: function(region) {
      return region.matches("div[class*='DynamicRightFeed_']") ? "More from Onet" : "";
    },
    cardFilter: onetContinuationCard,
    regionFilter: function(region) {
      return !onetUtilityRegion(region);
    }
  };

  function onetHomepageContent(metadata) {
    var host = (location.hostname || "").replace(/^www\./i, "");
    if (host !== "onet.pl" || location.pathname !== "/") return null;

    var sectioned = sectionedListExtraction(document.body, onetHomepageDescriptor);
    if (!sectioned) return null;

    return listItemsContentResult(metadata, {
      title: metadata && metadata.title,
      excerpt: metadata && metadata.excerpt,
      markdown: sectioned.markdown,
      textContent: sectioned.markdown,
      items: sectioned.items,
      hostAware: true
    });
  }

  function onetRegionHeading(region) {
    var card = region.querySelector("article[class*='Card_']");
    var headings = Array.prototype.filter.call(region.querySelectorAll("h1, h2"), function(heading) {
      if (heading.closest("article[class*='Card_']")) return false;
      if (card && !(heading.compareDocumentPosition(card) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
      return true;
    });
    var label = normalizeText(headings[0] && headings[0].textContent);
    if (!label || label.length > 90 || onetUtilityLabel(label)) return "";
    return label;
  }

  function onetUtilityRegion(region) {
    return !!region.closest("aside, nav, header, footer, [role='navigation'], [role='complementary'], [role='banner'], [role='contentinfo']");
  }

  function onetUtilityLabel(label) {
    return /^(REDAKCJA POLECA|REKLAMA|REKLAMY|MENU|NAWIGACJA|WIĘCEJ|NEWSLETTER|PARTNERZY|STOPKA)$/i.test(label);
  }

  function onetContinuationRegions(root) {
    return Array.prototype.filter.call(root.querySelectorAll("div[class*='DynamicRightFeed_']"), function(region) {
      return region.closest("div[class*='PageGroup_right__']") &&
        !region.closest("section") &&
        region.querySelector("article[class*='Card_']") &&
        !onetUtilityRegion(region);
    });
  }

  function onetContinuationCard(candidate) {
    var card = candidate.card;
    return !onetUtilityRegion(card) &&
      !/(ad|advert|sponsor|promo|utility)/i.test(card.className || "");
  }

  function registerOnetHomepageProfile() {
    registerHostAwareProfile(["onet.pl"], onetHomepageContent);
  }
