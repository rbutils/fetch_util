  function academicFamilyContent(metadata) {
    return acsAbstractArticleContent(metadata) ||
      plosStyleArticleContent(metadata) ||
      highwireArticleContent(metadata) ||
      elsevierArticleContent(metadata) ||
      ieeeXploreArticleContent(metadata) ||
      arxivAbstractContent(metadata) ||
      genericScholarlyArticleContent(metadata);
  }
