  function iucnRedListContent(metadata) {
    if (!/^\/species\/\d+\/\d+\/?$/i.test(location.pathname || "")) return null;

    var page = document.querySelector("#redlist-js .page-species");
    var title = normalizeText(document.title || firstText(["main h1", "h1"]) || metadata.title);
    var signature = normalizeText([
      metadata && metadata.siteName,
      metadata && metadata.title,
      document.title,
      document.body && document.body.textContent
    ].join(" "));
    if (!page || !/\bIUCN Red List\b/i.test(signature) || !title) return null;

    var cardIds = [
      "taxonomy",
      "assessment-information",
      "geographic-range",
      "population",
      "habitat-ecology",
      "threats",
      "use-trade",
      "conservation-actions"
    ];
    var cards = cardIds.map(function(id) { return document.getElementById(id); }).filter(Boolean);
    if (cards.length < 4 || !document.getElementById("assessment-information")) return null;

    var root = document.createElement("article");
    var heading = document.createElement("h1");
    heading.textContent = title.replace(/\s*--\s*$/i, "");
    root.appendChild(heading);

    var summary = page.querySelector(".layout-headline__supplement.layout-assessment, .layout-assessment__major");
    if (summary && /\b(Abstract|Red List|Assessment)\b/i.test(normalizeText(summary.textContent || ""))) {
      root.appendChild(cleanClone(summary));
    }

    cards.forEach(function(card) {
      var clone = cleanClone(card);
      clone.querySelectorAll("script, style, svg, iframe, noscript, input, button, select, form, nav, .map, [class*='map' i], [class*='tooltip' i], [class*='translate' i], [aria-hidden='true']").forEach(function(el) {
        el.remove();
      });
      cleanupAgentRoot(clone);
      root.appendChild(clone);
    });

    return profileHtmlContent(metadata, root, {
      cloneRoot: false,
      title: title,
      excerpt: metadata.excerpt,
      defaultExcerpt: false,
      siteName: metadata.siteName || "IUCN Red List",
      minTextLength: 900,
      validateMarkdown: function(markdown) {
        return /\bAssessment Information\b[\s\S]*\bPopulation\b[\s\S]*\bThreats\b/i.test(markdown);
      }
    });
  }
