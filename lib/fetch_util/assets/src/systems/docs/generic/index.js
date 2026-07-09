  function genericDocsSystemContent(metadata) {
    var info = docsSystemInfo(metadata);
    return stlDocsContent(metadata, info) || rustdocContent(metadata, info) || dartdocContent(metadata, info) || goPkgDocsSystemContent(metadata, info) || googleDevsiteContent(metadata, info) || elasticDocsContent(metadata, info) || readmeIoDocsContent(metadata, info) || redocDocsContent(metadata, info) || mintlifyDocsContent(metadata, info) || gitbookDocsContent(metadata, info) || scalarDocsContent(metadata, info) || fernDocsContent(metadata, info) || nextDocsContent(metadata, info) || nextraDocsContent(metadata, info) || docusaurusDocsContent(metadata, info) || vitePressDocsContent(metadata, info) || rspressDocsContent(metadata, info) || mkdocsMaterialContent(metadata, info) || mdBookContent(metadata, info) || antoraDocsContent(metadata, info) || readTheDocsContent(metadata, info) || sphinxDocsContent(metadata, info);
  }

  function registerGenericDocsSystemProfiles() {
    registerHostAwareProfile(true, genericDocsSystemContent);
  }
