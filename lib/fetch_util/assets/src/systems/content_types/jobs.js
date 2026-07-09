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
