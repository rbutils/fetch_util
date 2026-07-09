  function institutionalPlatformContent(metadata) {
    return eurLexDocumentContent(metadata) ||
      governmentProgramMicrositeContent(metadata) ||
      europaServiceLandingContent(metadata) ||
      standardsRecordContent(metadata) ||
      legalConventionIndexContent(metadata) ||
      drupalInstitutionalContent(metadata) ||
      genericInstitutionalComponentHubContent(metadata) ||
      institutionalTopicCardListContent(metadata);
  }
