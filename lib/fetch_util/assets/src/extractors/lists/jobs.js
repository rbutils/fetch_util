  function jobPostingNode() {
    return structuredDataNodes().find(function(node) {
      return nodeTypes(node).some(function(type) {
        return /(?:^|\/)JobPosting$/i.test(type);
      });
    }) || null;
  }

  function jobLocationText(value) {
    if (!value) return null;
    if (typeof value === "string") return normalizeText(value);
    if (Array.isArray(value)) {
      return normalizeText(value.map(jobLocationText).filter(Boolean).join("; "));
    }
    if (typeof value !== "object") return null;

    var address = value.address || value;
    if (typeof address === "string") return normalizeText(address);

    return normalizeText([
      address.streetAddress,
      address.addressLocality,
      address.addressRegion,
      address.postalCode,
      address.addressCountry && entityText(address.addressCountry)
    ].filter(Boolean).join(", ")) || entityText(value);
  }

  function jobDescriptionMarkdown(value) {
    var text = typeof value === "string" ? value : entityText(value);
    if (!normalizeText(text)) return null;

    if (/<[a-z][\s\S]*>/i.test(text) && typeof markdownFor === "function") {
      var root = document.createElement("div");
      root.innerHTML = text;
      return cleanupMarkdownNoise(markdownFor(root.innerHTML));
    }

    return cleanupMarkdownNoise(text);
  }

  function jobContentResult(options) {
    var title = normalizeText(options.title || "");
    var company = normalizeText(options.company || "");
    var locationText = normalizeText(options.location || "");
    var description = cleanupMarkdownNoise(String(options.description || "")).trim();
    if (!title || !normalizeText(description) || normalizeText(description).length < 80) return null;

    var details = [];
    if (company) details.push("Company: " + company);
    if (locationText) details.push("Location: " + locationText);

    var markdown = [
      "# " + title,
      details.length ? details.map(function(item) { return "- " + item; }).join("\n") : null,
      description
    ].filter(Boolean).join("\n\n").trim();

    return {
      title: title,
      company: company || null,
      location: locationText || null,
      description: description,
      byline: null,
      excerpt: normalizeText(description),
      siteName: company || location.hostname,
      publishedTime: options.publishedTime || null,
      html: options.html || "",
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "job"
    };
  }

  function structuredJobPostingContent(metadata) {
    var job = jobPostingNode();
    if (!job) return null;

    return jobContentResult({
      title: entityText(job.title) || entityName(job) || metadata.title || document.title,
      company: entityName(job.hiringOrganization) || metadata.siteName,
      location: jobLocationText(job.jobLocation) || entityText(job.applicantLocationRequirements),
      description: jobDescriptionMarkdown(job.description),
      publishedTime: entityText(job.datePosted),
      html: typeof job.description === "string" ? job.description : ""
    });
  }

  function likelyJobDetailPage() {
    if (jobPostingNode()) return true;
    if (jobResultsPage(document.body)) return false;

    var context = normalizeText([location.pathname, document.title, metadataValue("og:type", "property")].join(" ")).toLowerCase();
    if (!/\b(job|jobs|career|careers|opening|position|role)\b/.test(context)) return false;

    var detailCueCount = 0;
    if (document.querySelector("[data-testid*='location' i], [class*='location' i], [class*='job-location' i]")) detailCueCount += 1;
    if (document.querySelector("[data-testid*='department' i], [class*='department' i], [class*='team' i]")) detailCueCount += 1;
    if (document.querySelector("[data-testid*='apply' i], a[href*='apply' i], button[class*='apply' i], .application, #application")) detailCueCount += 1;
    if (/\b(apply for this job|apply now|job description|about the role|responsibilities|qualifications|requirements)\b/i.test(normalizeText(document.body && document.body.textContent))) detailCueCount += 1;

    return detailCueCount >= 2;
  }

  function domJobPostingContent(metadata) {
    if (!likelyJobDetailPage()) return null;

    var root = document.querySelector("main, article, [role='main'], .job, .job-post, .job-posting, .opening, #content") || document.body;
    var title = firstText(["main h1", "article h1", "h1", "[data-testid*='title' i]", ".app-title"]);
    var company = firstText([
      "[data-testid*='company' i]",
      "[class*='company' i]"
    ]) || metadataValue("og:site_name", "property") || metadata.siteName;
    var locationText = firstText([
      "[data-testid*='location' i]",
      "[class*='job-location' i]",
      "[class*='location' i]",
      "[class*='office' i]"
    ]);
    var descriptionRoot = root.querySelector("[data-testid*='description' i], [class*='description' i], [class*='content' i], [class*='body' i], .job-post, .job-posting, .opening") || root;
    var clone = cleanClone(descriptionRoot);
    cleanupAgentRoot(clone);
    removeAll(clone, "nav, header, footer, aside, form, script, style, noscript, [class*='apply' i], [id*='apply' i]");
    var description = cleanupMarkdownNoise(markdownFor(clone.innerHTML));

    return jobContentResult({
      title: title || metadata.title || document.title,
      company: company,
      location: locationText,
      description: description,
      html: clone.innerHTML
    });
  }

  function jobPostingContent(metadata) {
    return structuredJobPostingContent(metadata) || domJobPostingContent(metadata);
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
