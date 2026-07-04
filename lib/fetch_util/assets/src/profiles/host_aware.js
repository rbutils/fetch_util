  function hostAwareContent(metadata, pageText) {
    return pinterestSearchContent(metadata) ||
      tikTokContent(metadata, pageText) ||
      ebaySearchContent(metadata, pageText) ||
      glassdoorContent(metadata) ||
      mediaWatchContent(metadata) ||
      youtubeContent(metadata) ||
      amazonSearchContent(metadata) ||
      amazonProductContent(metadata) ||
      bloombergContent(metadata) ||
      economistContent(metadata) ||
      financialTimesContent(metadata) ||
      bookingContent(metadata) ||
      arxivAbstractContent(metadata) ||
      substackContent(metadata) ||
      packageRegistryContent(metadata) ||
      statuspageContent(metadata) ||
      wykopContent(metadata) ||
      docsHostContent(metadata) ||
      railsGuidesContent(metadata) ||
      rdocDocsContent(metadata) ||
      railsApiContent(metadata) ||
      gitLabContent(metadata) ||
      githubContent(metadata) ||
      genericDocsSystemContent(metadata) ||
      genericPortalHomepageContent(metadata) ||
      mastodonContent(metadata) ||
      fandomContent(metadata) ||
      mediaWikiContent(metadata) ||
      stackExchangeContent(metadata) ||
      discourseTopicContent(metadata) ||
      redditContent(metadata, pageText) ||
      behanceContent(metadata, pageText) ||
      instagramContent(metadata, pageText) ||
      facebookContent(metadata, pageText) ||
      telegramContent(metadata, pageText) ||
      twitterContent(metadata, pageText) ||
      threadsContent(metadata, pageText) ||
      linkedinContent(metadata, pageText) ||
      blueskyContent(metadata, pageText) ||
      quoraContent(metadata, pageText);
  }
