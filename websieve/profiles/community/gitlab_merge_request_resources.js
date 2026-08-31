function gitlabResourceRoot() {
  return document.querySelector("main") ||
    document.querySelector(".content-wrapper") ||
    document.querySelector(".merge-request") ||
    document.querySelector("[data-page]") ||
    document.body;
}

function gitlabResourceNodes(root, selector) {
  var nodes = Array.prototype.slice.call(root.querySelectorAll(selector));
  return nodes.filter(function(node, index) {
    if (elementSubtreeHidden(node)) return false;
    return !nodes.some(function(other, otherIndex) {
      return otherIndex < index && other.contains(node);
    });
  });
}

function gitlabResourceNodeMarkdown(node) {
  var clone = visibilityPrunedClone(node);
  removeAll(clone, "button, [role='tooltip'], .dropdown, .js-dropdown, .gl-new-dropdown");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function gitlabResourceRecords(root, selector) {
  return gitlabResourceNodes(root, selector).map(function(node) {
    return { node: node, markdown: gitlabResourceNodeMarkdown(node) };
  }).filter(function(record) {
    return !!normalizeText(record.markdown);
  });
}

function gitlabListedResourceContent(metadata, route, root, configuration) {
  var records = gitlabResourceRecords(root, configuration.selector);
  var empty = gitlabResourceEmptyMarkdown(root);
  if (!records.length && !empty) return null;

  var title = gitlabResourceTitle(metadata, configuration.title);
  var sections = ["# " + title];
  if (records.length) {
    sections.push("- Records shown: " + records.length, "## " + configuration.title);
    records.forEach(function(record, index) {
      sections.push("### " + configuration.itemLabel + " " + (index + 1), record.markdown);
    });
  } else {
    sections.push(empty);
  }
  sections.push(browsableInventory("Browse this GitLab merge request", gitlabCoreInventoryEntries(route)));
  return gitlabResourceResult(title, sections, records.map(function(record) {
    return visibilityPrunedClone(record.node);
  }));
}

function gitlabMergeRequestResourceContent(metadata) {
  var route = gitlabResourceRoute();
  if (!route || route.kind !== "merge_requests" || !route.surface) return null;

  var root = gitlabResourceRoot();
  if (!gitlabProductMatch(root)) return null;
  if (route.surface === "diffs") return gitlabDiffResourceContent(metadata, route, root);

  var configurations = {
    commits: {
      title: "Commits",
      itemLabel: "Commit",
      selector: "[data-testid='commit-content'], [data-testid='commit-row'], .commit-row, li.commit"
    },
    pipelines: {
      title: "Pipelines",
      itemLabel: "Pipeline",
      selector: "[data-testid='pipeline-table-row'], .pipeline-row, .ci-table tbody tr, table.pipelines tbody tr"
    },
    reports: {
      title: "Reports",
      itemLabel: "Report",
      selector: "[data-testid*='report'], .report-block, .mr-widget-reports > *, .report-section"
    }
  };
  var configuration = configurations[route.surface];
  return configuration && gitlabListedResourceContent(metadata, route, root, configuration);
}

function registerGitLabMergeRequestResourceProfiles() {
  registerHostAwareProfile(true, gitlabMergeRequestResourceContent);
}
