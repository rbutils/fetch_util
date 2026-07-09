  function scientificRecordContent(metadata) {
    return iucnRedListContent(metadata) ||
      ensemblGeneContent(metadata) ||
      ncbiGeneContent(metadata) ||
      oeisSequenceContent(metadata) ||
      rcsbStructureContent(metadata) ||
      nistReferenceDataContent(metadata);
  }

  function registerScientificRecordProfiles() {
    registerHostAwareProfile(true, scientificRecordContent);
  }
