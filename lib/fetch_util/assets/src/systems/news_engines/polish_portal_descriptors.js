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
      headingBuilder: function(region) {
        var labels = ["WIADOMOŚCI", "SPORT", "BIZNES", "KULTURA I STYL ŻYCIA", "TECHNOLOGIE I GRY"];
        var headings = Array.prototype.map.call(region.querySelectorAll("h1, h2, h3, h4"), function(heading) {
          return normalizeText(heading.textContent || "");
        });
        return headings.filter(function(label) { return labels.indexOf(label.toUpperCase()) !== -1; })[0] || "";
      },
      regionFilter: function(region) {
        return !!region.querySelector("h1, h2, h3, h4");
      }
    }
  };

  function polishPortalDescriptor(host) {
    return window.polishPortalDescriptors[host] || null;
  }
