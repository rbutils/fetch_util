  function mediaVisibleTexts(selectors) {
    var seen = {};
    var items = [];

    selectors.forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(node) {
        var text = normalizeText(node.textContent);
        if (!text || seen[text]) return;
        seen[text] = true;
        items.push(text);
      });
    });

    return items;
  }

  function mediaPlayerProfileData() {
    var video = structuredDataNode(["VideoObject", "Clip", "Movie", "TVEpisode"]);
    var data = {
      title: video && (video.name || video.headline),
      description: video && video.description,
      byline: video && (video.author || video.publisher),
      publishedTime: video && (video.uploadDate || video.datePublished),
      duration: video && video.duration,
      views: null
    };

    var yt = global.ytInitialPlayerResponse;
    var details = yt && yt.videoDetails;
    var microformat = yt && yt.microformat && yt.microformat.playerMicroformatRenderer;
    if (details) {
      data.title = data.title || details.title;
      data.description = data.description || details.shortDescription;
      data.byline = data.byline || details.author;
      data.views = data.views || details.viewCount;
    }
    if (microformat) {
      data.byline = data.byline || microformat.ownerChannelName;
      data.publishedTime = data.publishedTime || microformat.publishDate || microformat.uploadDate;
    }

    return data;
  }

  function mediaPageTitle(metadata, profile) {
    var title = normalizeText(profile.title || "");
    var headings = mediaVisibleTexts(["main h1", "article h1", "h1"]).filter(function(text) {
      return !/^(loading|this video is processing|verify to continue|checking if the site connection is secure)/i.test(text);
    });

    if (!title && headings.length) title = headings[0];
    if (!title) title = normalizeText(metadata.title || document.title);

    return title.replace(/\s*[-|]\s*(YouTube|Vimeo|Videos & Movies on Vimeo)$/i, "");
  }

  function mediaPageDescription(metadata, profile) {
    var description = normalizeText(profile.description || metadata.excerpt || "");
    if (description) return description;

    var candidates = mediaVisibleTexts([
      "#description-inline-expander",
      "ytd-expandable-video-description-body-renderer",
      "#description.ytd-watch-metadata",
      "#description",
      "[data-testid='vd-wrapper'] p",
      "main article p",
      "main p"
    ]);

    return candidates.find(function(text) {
      if (text.length < 30) return false;
      return !/^(loading|you'll be able to view it as soon as it's done|verify to continue|checking if the site connection is secure)/i.test(text);
    }) || null;
  }

  function mediaWatchContent(metadata) {
    var profile = mediaPlayerProfileData();
    var ogType = normalizeText(metadataValue("og:type", "property") || "").toLowerCase();
    var playerData = !!(global.ytInitialPlayerResponse && global.ytInitialPlayerResponse.videoDetails);
    var videoEmbed = !!(metadata.video || /^video\b/.test(ogType));
    var videoPath = /\/(watch|shorts|live|videos?|player|clip|replay)\b/i.test(location.pathname || "");
    var visiblePlayer = !!document.querySelector("video, iframe[src*='youtube'], iframe[src*='youtu.be'], iframe[src*='vimeo'], [data-video-id], [data-video], [data-player]");
    var videoSignal = !!(
      playerData ||
      videoEmbed ||
      (videoPath && visiblePlayer)
    );
    var watchShape = videoPath || playerData || videoEmbed;

    if (!videoSignal || !watchShape) return null;

    if (!playerData && !videoPath && !/^video\b/.test(ogType)) {
      var articleParagraphs = Array.prototype.filter.call(document.querySelectorAll("article p, main p"), function(paragraph) {
        return normalizeText(paragraph.textContent || "").length >= 80;
      });
      if (articleParagraphs.length >= 3) return null;
    }

    var title = mediaPageTitle(metadata, profile);
    var description = mediaPageDescription(metadata, profile);
    var byline = entityName(profile.byline) || metadata.byline;
    var publishedTime = entityText(profile.publishedTime) || firstText(["time[datetime]"], "datetime") || metadata.publishedTime;
    var details = [];
    var duration = entityText(profile.duration);
    var views = entityText(profile.views);

    if (duration) details.push("Duration: " + duration);
    if (views) details.push("Views: " + views);
    if (!title || !description) return null;

    return articleContentFromParts({
      title: title,
      byline: byline,
      publishedTime: publishedTime,
      description: description,
      details: details,
      siteName: metadata.siteName || location.hostname,
      hostAware: true
    });
  }

  function youtubeContent(metadata) {
    if (!hostMatches(/(^|\.)(youtube\.com|youtu\.be)$/)) return null;
    if (!(queryParam("v") || /^\/(watch|shorts|live)\b/.test(location.pathname))) return null;

    var media = mediaWatchContent(metadata);
    if (media) return media;

    var video = structuredDataNode(["VideoObject"]);
    var title = normalizeText((video && (video.name || video.headline)) || metadata.title).replace(/\s*[-|]\s*YouTube$/i, "");
    var description = firstText([
      "#description-inline-expander",
      "ytd-expandable-video-description-body-renderer",
      "#description.ytd-watch-metadata",
      "#description"
    ]) || entityText(video && video.description) || metadata.excerpt;
    var byline = entityName(video && (video.author || video.publisher)) || metadata.byline;
    var publishedTime = entityText(video && (video.uploadDate || video.datePublished)) || metadata.publishedTime;
    var details = [];
      var chapters = mediaVisibleTexts([
      "ytd-macro-markers-list-item-renderer h4",
      "ytd-macro-markers-list-item-renderer #title"
    ]);

    if (entityText(video && video.duration)) details.push("Duration: " + entityText(video.duration));
    if (chapters.length) details.push("Chapters: " + chapters.join(" | "));

    if (!title || !description) return null;

    return articleContentFromParts({
      title: title,
      byline: byline,
      publishedTime: publishedTime,
      description: description,
      details: details,
      siteName: metadata.siteName || "YouTube",
      hostAware: true
    });
  }
