  function fazHomepageListConfig() {
    return {
      pathAllowed: function() {
        var path = (location.pathname || "").toLowerCase();
        return path === "" || path === "/" || path === "/aktuell" || path === "/aktuell/";
      },
      linkSelector: "main a[href]",
      cardSelector: "article, section, li, [data-selector*='teaser'], [data-external-selector*='teaser']",
      acceptLink: function(href) { return /\.html(?:$|[?#])/i.test(href); },
      transformTitle: function(title) { return title.replace(/^[A-ZÄÖÜ0-9.,:;!?\s-]{4,}\s*:\s*/u, ""); },
      maxTitleLength: 180,
      rejectTitle: /^(liveblog|ticker|mehr zum thema|alle themen|bildbeschreibung ausklappen|artikelrechte erwerben)$/i,
      siteName: "Frankfurter Allgemeine Zeitung"
    };
  }

  registerNewsHomepageListProfile(/(^|\.)faz\.net$/, fazHomepageListConfig);
