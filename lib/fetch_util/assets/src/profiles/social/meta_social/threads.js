  function threadsContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)threads\.(net|com)$/)) return null;

    var ogTitle = metadata.title || "";
    var ogDesc = metadata.excerpt || "";
    var ogImage = metadata.image || "";

    var profileMatch = ogTitle.match(/^(.+?)\s*\((@\w+)\)\s*[•·]/);
    var displayName = profileMatch ? profileMatch[1].trim() : "";
    var handle = profileMatch ? profileMatch[2] : "";

    if (!profileMatch) {
      var postMatch = ogTitle.match(/^(.+?)\s*\((@\w+)\)\s+on Threads/);
      if (!postMatch) postMatch = ogTitle.match(/^(@\w+)\s+on Threads/);
      if (postMatch) {
        displayName = postMatch[1] ? postMatch[1].trim() : "";
        handle = postMatch[2] || postMatch[1] || "";
      }
    }

    var followers = "";
    var threadCount = "";
    var bio = ogDesc;

    var statsMatch = ogDesc.match(/^([\d,.]+[KMB]?)\s+Followers?\s*[•·]\s*([\d,.]+[KMB]?)\s+Threads?\s*[•·]\s*(.*)/i);
    if (statsMatch) {
      followers = statsMatch[1];
      threadCount = statsMatch[2];
      bio = normalizeText(statsMatch[3]);
    } else {
      var followerMatch = ogDesc.match(/([\d,.]+[KMB]?)\s+Followers?/i);
      if (followerMatch) followers = followerMatch[1];
      var threadMatch = ogDesc.match(/([\d,.]+[KMB]?)\s+Threads?/i);
      if (threadMatch) threadCount = threadMatch[1];
    }

    if (!displayName && !handle) {
      return null;
    }

    var details = [];
    if (handle) details.push("Handle: " + handle);
    if (followers) details.push("Followers: " + followers);
    if (threadCount) details.push("Threads: " + threadCount);
    if (ogImage) details.push("Image: " + ogImage);

    var title = displayName || handle;

    return articleContentFromParts({
      title: title,
      description: bio || ogDesc,
      details: details,
      siteName: "Threads",
      hostAware: true,
      contentType: "article"
    });
  }

  function registerThreadsProfiles() {
    registerHostAwareProfile(true, threadsContent);
  }
