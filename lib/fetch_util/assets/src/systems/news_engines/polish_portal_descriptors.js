  window.polishPortalDescriptors = {
    "wp.pl": {
      regionSelector: ".wp-section-grid",
      headingSelector: ".wp-section-title-link",
      skipEditorialGuard: true,
      cardSelector: "a.wp-teaser-tile, a.wp-teaser-regular",
      ancestorLink: true,
      directCard: true,
      regionFilter: function(region) {
        return !!region.querySelector(".wp-section-title-link");
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
