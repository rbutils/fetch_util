  function docsHostContent(metadata) {
    return nextJsDocsContent(metadata) ||
      reactDocsContent(metadata) ||
      stripeApiContent(metadata) ||
      awsDocsContent(metadata) ||
      mdnDocsContent(metadata) ||
      githubDocsContent(metadata) ||
      hashicorpDocsContent(metadata) ||
      dockerDocsContent(metadata) ||
      grafanaDocsContent(metadata) ||
      baselinkerDocsContent(metadata) ||
      rubyApiContent(metadata);
  }

  function registerDocsHostProfiles() {
    registerHostAwareProfile(true, docsHostContent);
  }
