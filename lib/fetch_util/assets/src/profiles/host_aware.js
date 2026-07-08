  window.hostAwareProfiles = window.hostAwareProfiles || [];

  function defaultContentResult(_metadata) {
    return null;
  }

  window.registerHostAwareProfile = function(condition, fn) {
    hostAwareProfiles.push({ condition: condition, fn: fn });
  };

  function hostAwareProfileMatches(condition, metadata, host) {
    if (condition === true) return true;
    if (condition === false) return false;
    if (typeof condition === "function") return condition(metadata);
    return hostMatches(condition, host);
  }

  function hostAwareContent(metadata, pageText) {
    var host = (metadata && metadata.host) || location.hostname || "";

    for (var i = 0; i < hostAwareProfiles.length; i += 1) {
      var specificProfile = hostAwareProfiles[i];
      if (specificProfile.condition === true) continue;
      if (!hostAwareProfileMatches(specificProfile.condition, metadata, host)) continue;

      var specificResult = specificProfile.fn(metadata, pageText);
      if (specificResult) return specificResult;
    }

    for (var j = 0; j < hostAwareProfiles.length; j += 1) {
      var genericProfile = hostAwareProfiles[j];
      if (genericProfile.condition !== true) continue;
      if (!hostAwareProfileMatches(genericProfile.condition, metadata, host)) continue;

      var genericResult = genericProfile.fn(metadata, pageText);
      if (genericResult) return genericResult;
    }

    return defaultContentResult(metadata);
  }

  registerHostAwareProfile(true, tropeWikiContent);
  registerHostAwareProfile(true, pinterestSearchContent);
  registerHostAwareProfile(true, tikTokContent);
  registerHostAwareProfile(true, ebaySearchContent);
  registerHostAwareProfile(true, glassdoorContent);
  registerHostAwareProfile(true, function(metadata, pageText) { return mediaWatchContent(metadata, pageText); });
  registerHostAwareProfile(true, youtubeContent);
  registerHostAwareProfile(true, amazonSearchContent);
  registerHostAwareProfile(true, amazonProductContent);
  registerHostAwareProfile(true, bloombergContent);
  registerHostAwareProfile(true, economistContent);
  registerHostAwareProfile(true, financialTimesContent);
  registerHostAwareProfile(true, zeitArticleContent);
  registerHostAwareProfile(true, bookingContent);
  registerHostAwareProfile(true, highwireArticleContent);
  registerHostAwareProfile(true, acsAbstractArticleContent);
  registerHostAwareProfile(true, plosStyleArticleContent);
  registerHostAwareProfile(true, elsevierArticleContent);
  registerHostAwareProfile(true, ieeeXploreArticleContent);
  registerHostAwareProfile(true, arxivAbstractContent);
  registerHostAwareProfile(true, genericScholarlyArticleContent);
  registerHostAwareProfile(true, function(metadata, pageText) { return scientificRecordContent(metadata, pageText); });
  registerHostAwareProfile(true, csdnContent);
  registerHostAwareProfile(true, substackContent);
  registerHostAwareProfile(true, packageRegistryContent);
  registerHostAwareProfile(true, statuspageContent);
  registerHostAwareProfile(true, structuredLegalProvisionContent);
  registerHostAwareProfile(true, legalTableOfContentsContent);
  registerHostAwareProfile(true, officialStatuteContent);
  registerHostAwareProfile(true, legalReferenceArticleContent);
  registerHostAwareProfile(true, institutionalPlatformContent);
  registerHostAwareProfile(true, wykopContent);
  registerHostAwareProfile(true, docsHostContent);
  registerHostAwareProfile(true, railsGuidesContent);
  registerHostAwareProfile(true, rdocDocsContent);
  registerHostAwareProfile(true, railsApiContent);
  registerHostAwareProfile(true, repositoryReadmeContent);
  registerHostAwareProfile(true, genericDocsSystemContent);
  registerHostAwareProfile(true, genericPortalHomepageContent);
  registerHostAwareProfile(true, mastodonContent);
  registerHostAwareProfile(true, fandomContent);
  registerHostAwareProfile(true, mediaWikiContent);
  registerHostAwareProfile(true, stackExchangeContent);
  registerHostAwareProfile(true, discourseTopicContent);
  registerHostAwareProfile(true, redditContent);
  registerHostAwareProfile(true, behanceContent);
  registerHostAwareProfile(true, instagramContent);
  registerHostAwareProfile(true, facebookContent);
  registerHostAwareProfile(true, telegramContent);
  registerHostAwareProfile(true, twitterContent);
  registerHostAwareProfile(true, threadsContent);
  registerHostAwareProfile(true, linkedinContent);
  registerHostAwareProfile(true, blueskyContent);
  registerHostAwareProfile(true, quoraContent);
