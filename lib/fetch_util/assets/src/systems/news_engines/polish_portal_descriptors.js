  window.polishPortalDescriptors = {
    "wp.pl": {
      regionSelector: ".wp-section-grid, .wp-offers-section, .wp-section-stream, .wp-leaflets-section",
      skipEditorialGuard: true,
      allowEmptyRegions: true,
      cardSelector: "a.wp-teaser-tile, a.wp-teaser-regular, a.wp-leaflet-card",
      ancestorLink: true,
      directCard: true,
      headingBuilder: function(region) {
        var heading = region.querySelector(".wp-section-title-link, .wp-section-colored-header-title");
        if (!heading && region.matches(".wp-section-stream")) heading = region.querySelector("h1, h2");
        return normalizeText(heading && heading.textContent);
      },
      regionFilter: function(region) {
        if (region.matches(".wp-section-grid")) return !!region.querySelector(".wp-section-title-link");
        if (region.matches(".wp-offers-section, .wp-leaflets-section")) {
          return !!region.querySelector(".wp-section-colored-header-title");
        }
        return !!region.querySelector("h1, h2");
      }
    },
    "onet.pl": {
      regionSelector: "section[class*='Feed_']",
      skipEditorialGuard: true,
      cardSelector: "article[class*='Card_']",
      directCard: true,
      headingBuilder: onetRegionHeading,
      regionFilter: function(region) {
        return !onetUtilityRegion(region);
      }
    }
  };

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

  function polishPortalDescriptor(host) {
    return window.polishPortalDescriptors[host] || null;
  }
