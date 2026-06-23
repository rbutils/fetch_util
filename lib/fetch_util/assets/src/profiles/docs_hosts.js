  function docsHostContent(metadata) {
    return nextJsDocsContent(metadata) ||
      reactDocsContent(metadata) ||
      stripeApiContent(metadata) ||
      awsDocsContent(metadata) ||
      mdnDocsContent(metadata) ||
      githubDocsContent(metadata) ||
      pythonDocsContent(metadata) ||
      hashicorpDocsContent(metadata) ||
      dockerDocsContent(metadata) ||
      grafanaDocsContent(metadata) ||
      baselinkerDocsContent(metadata) ||
      rubyApiContent(metadata);
  }
