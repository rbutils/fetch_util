function bitbucketCloudPreparedDiff(route) {
  var prepared = window.__fetchUtilBitbucketPullDiff;
  if (!prepared || !prepared.route || prepared.route.workspace !== route.workspace ||
      prepared.route.repository !== route.repository || normalizeText(prepared.route.number) !== route.number) return null;
  if (prepared.status === "failed") return prepared;
  if (prepared.status !== "ready" || !prepared.metadata || !Array.isArray(prepared.values)) return null;
  var repository = prepared.metadata.destination && prepared.metadata.destination.repository || {};
  if (normalizeText(prepared.metadata.id) !== route.number ||
      normalizeText(repository.full_name).toLowerCase() !== route.community.toLowerCase()) return null;
  return prepared;
}

function bitbucketCloudDiffWarningContent(metadata, route, prepared) {
  var title = normalizeText(metadata.title || document.title || "Bitbucket pull request") + " - Changed files";
  var reason = normalizeText(prepared.reason || "Bitbucket diffstat preparation failed");
  var markdown = [
    "# " + title,
    "## Retrieval warning",
    "Bitbucket diffstat preparation failed; visible page content may be incomplete.",
    "    " + reason,
    browsableInventory("Browse this Bitbucket pull request", bitbucketCloudInventoryEntries(route))
  ].join("\n\n");
  return {
    title: title,
    siteName: "Bitbucket",
    html: "",
    markdown: markdown,
    textContent: normalizeText(markdown),
    contentType: "list",
    hostAware: true,
    readerMode: false,
    warningReasons: ["bitbucket_cloud_diffstat_incomplete"]
  };
}

function bitbucketCloudPullDiffContent(metadata, route) {
  var prepared = bitbucketCloudPreparedDiff(route);
  if (!prepared) return null;
  if (prepared.status === "failed") return bitbucketCloudDiffWarningContent(metadata, route, prepared);

  var heading = firstText(["[data-testid='pr-header'] h1", "[data-testid='pr-header'] [role='heading']", "h1"]);
  var title = normalizeText(heading || metadata.title || document.title || "Bitbucket pull request") + " - Changed files";
  var sections = ["# " + title, "- Changed files shown: " + prepared.values.length, "## Changed files"];
  var inventory = bitbucketCloudInventoryEntries(route);
  prepared.values.forEach(function(record, index) {
    sections = sections.concat(bitbucketCloudDiffFileSections(record, index));
    inventory = inventory.concat(bitbucketCloudDiffFileInventoryEntries(record, index));
  });

  var articles = bitbucketCloudLoadedDiffArticles();
  if (articles.length) {
    sections.push("## Loaded diff content");
    articles.forEach(function(article) {
      var clone = bitbucketCloudVisibleClone(article);
      if (!clone) return;
      removeAll(clone, "button, [role='tooltip'], [data-testid*='menu'], [data-qa*='menu']");
      var articleMarkdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
      if (articleMarkdown) sections.push(articleMarkdown);
    });
  }
  sections.push(browsableInventory("Browse this Bitbucket pull request", inventory));
  var markdown = sections.filter(Boolean).join("\n\n");
  return {
    title: title,
    siteName: "Bitbucket",
    excerpt: prepared.values.length ? normalizeText(bitbucketCloudDiffFilePath(prepared.values[0].new) ||
      bitbucketCloudDiffFilePath(prepared.values[0].old)) : title,
    html: articles.map(function(article) {
      var clone = bitbucketCloudVisibleClone(article);
      return clone ? clone.outerHTML : "";
    }).filter(Boolean).join("\n"),
    markdown: markdown,
    textContent: normalizeText(markdown),
    contentType: "list",
    hostAware: true,
    readerMode: false
  };
}
