  function jobPostingNode() {
    return structuredDataNodes().find(function(node) {
      return nodeTypes(node).some(function(type) {
        return /(?:^|\/)JobPosting$/i.test(type);
      });
    }) || null;
  }

  function jobLocationText(value) {
    return structuredPostalAddressText(value);
  }

  function genericJobListContent(metadata) {
    if (typeof jobResultsPage !== "function" || !jobResultsPage(document.body)) return null;

    var jobCardSelectors = "[data-testid='slider_container'], [data-test='jobListing'], [data-jobid], [data-testid*='job' i], [class*='job-card' i], [class*='jobCard'], tr[data-id][data-url*='/remote-jobs/'], [data-url*='/remote-jobs/']";

    function cardUrl(card, link) {
      var href = link && link.getAttribute("href");
      href = href || card.getAttribute("data-href") || card.getAttribute("data-url") || "";
      return href ? absoluteUrl(href) : "";
    }

    function titleLink(card) {
      return card.querySelector("a[data-test='job-title'], a[id*='job-title' i], a[href*='/job-listing/'], a[href*='/remote-jobs/'], a[href*='/viewjob'], a[href*='/rc/clk'], a[href*='jk='], a[href*='jl=']");
    }

    function cardTitle(card, link) {
      var company = normalizeText(card.getAttribute("data-company") || "");
      var search = normalizeText(card.getAttribute("data-search") || "").replace(/\s*\[.*$/i, "");
      if (company && search.indexOf(company) === 0) search = normalizeText(search.slice(company.length));

      var candidates = [
        search,
        normalizeText(link && (link.textContent || link.getAttribute("aria-label"))),
        normalizeText((card.querySelector("[data-test='job-title'], [data-testid*='jobTitle' i], h2, h3") || {}).textContent || "")
      ].map(function(value) {
        return normalizeText(value || "").replace(/\s*-?\s*\{\"@context\".*$/i, "");
      }).filter(Boolean);

      candidates.sort(function(a, b) { return b.length - a.length; });
      return candidates[0] || "";
    }

    function cardDetail(card, title) {
      var parts = [];
      ["[data-testid='company-name']", "[data-test='employer-name']", "[data-test='location']", "[data-testid*='location' i]", "[data-test='descSnippet']", "[data-testid='belowJobSnippet']"].forEach(function(selector) {
        var node = card.querySelector(selector);
        var text = normalizeText(node && node.textContent);
        if (text && parts.indexOf(text) === -1) parts.push(text);
      });

      if (!parts.length) {
        parts.push(normalizeText(card.textContent || "").replace(title, ""));
      }

      var detail = normalizeText(parts.join(" - ")).replace(title, "");
      detail = detail.replace(/\s*\{\"@context\".*$/i, "");
      if (detail.length > 220) detail = detail.slice(0, 217).replace(/\s+\S*$/, "") + "...";
      return detail;
    }

    var items = collectCardLinkCandidates(document, {
      cardSelectors: jobCardSelectors,
      linkBuilder: titleLink,
      allowMissingUrl: true,
      minTitleLength: minimumListTitleLength,
      maxTitleLength: 220,
      maxItems: 18,
      keyBuilder: function(candidate) {
        return candidate.text + "|" + candidate.url;
      },
      candidateBuilder: function(card, link) {
        var title = cardTitle(card, link);
        var url = cardUrl(card, link);

        return { text: title, url: url, detail: cardDetail(card, title) };
      }
    });

    if (items.length < 4) return null;

    var markdown = listMarkdown(items);

    return listItemsContentResult(metadata, {
      excerpt: items[0].text,
      textContent: markdown,
      markdown: markdown,
      items: items
    });
  }
  function jobResultsPage(root) {
    root = root || document.body;
    if (!root || articleLikePath()) return false;

    var context = normalizeText([location.pathname, location.search, document.title].join(" ")).toLowerCase();
    if (!/(\bjobs?\b|employment|careers?|jobsearch|job-list|job results?|hiring|remote-[a-z0-9+-]+-jobs|q-[a-z0-9-]+-jobs)/i.test(context)) return false;

    var jobCards = root.querySelectorAll("[data-testid='slider_container'], [data-test='jobListing'], [data-jobid], [data-testid*='job' i], [class*='job-card' i], [class*='jobCard'], tr[data-id][data-url*='/remote-jobs/'], [data-url*='/remote-jobs/']").length;
    var jobLinks = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
      var href = link.getAttribute("href") || "";
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      if (text.length < minimumListTitleLength(text) || text.length > 220) return false;
      return /(\/job-listing\/|\/remote-jobs\/|\/viewjob\b|\/rc\/clk\b|[?&](?:jk|jl)=)/i.test(href);
    }).length;

    return jobCards >= 4 || jobLinks >= 4;
  }
