  function searchItemTitle(link) {
    var heading = link.querySelector("h1, h2, h3, h4");
    return normalizeText(heading ? heading.textContent : link.textContent);
  }
  function searchItemDetail(node, title) {
    var detail = normalizeText(node && node.textContent).replace(normalizeText(title), "").replace(/\s*[|·]\s*/g, " - ");
    detail = detail
      .replace(/Only include results for this site.*$/i, "")
      .replace(/This search result is provided by Google Learn more Report result/gi, "")
      .replace(/Learn more Report result/gi, "")
      .replace(/Report Ad/gi, "")
      .replace(/\bhttps?:\/\/\S+/gi, "")
      .replace(/\s{2,}/g, " ");
    return normalizeText(detail);
  }
  function newsHomepageListContent(metadata, config) {
    config = config || {};
    if (config.prepareMetadata) config.prepareMetadata(metadata);
    if (config.pathAllowed && !config.pathAllowed()) return null;

    var seen = {};
    var items = [];
    var minItems = config.minItems || 4;
    var minTitleLength = config.minTitleLength || 18;
    var maxTitleLength = config.maxTitleLength || 220;
    var linkSelector = config.linkSelector || "a[href]";
    var cardSelector = config.cardSelector || "article, section, li, div";

    function rejectedTitle(title) {
      if (!title || title.length < minTitleLength || title.length > maxTitleLength) return true;
      if (!config.rejectTitle) return false;
      if (typeof config.rejectTitle === "function") return config.rejectTitle(title);
      return config.rejectTitle.test(title);
    }

    document.querySelectorAll(linkSelector).forEach(function(link) {
      if (config.excludeClosest && link.closest(config.excludeClosest)) return;

      var href = link.getAttribute("href") || "";
      var url = absoluteUrl(href);
      if (!url || seen[url]) return;
      if (config.acceptLink && !config.acceptLink(href, url, link)) return;

      var title = config.titleBuilder ? config.titleBuilder(link) : searchItemTitle(link);
      if (config.transformTitle) title = config.transformTitle(title, link);
      title = normalizeText(title || "");
      if (rejectedTitle(title)) return;

      var container = link.closest(cardSelector) || link.parentElement;
      var detail = searchItemDetail(container, title);

      seen[url] = true;
      items.push({ text: title, url: url, detail: detail });
    });

    if (items.length < minItems) return null;

    var result = listContentResult({
      title: config.title || ((metadata && metadata.title) || document.title || config.defaultTitle),
      excerpt: metadata && metadata.excerpt,
      siteName: (metadata && metadata.siteName) || config.siteName || location.hostname,
      items: items
    });
    if (config.hostAware) result.hostAware = true;
    if (config.statusPage) result.statusPage = true;
    return result;
  }
  window.newsHomepageListProfiles = window.newsHomepageListProfiles || [];

  function newsHomepageListProfileMatches(condition, metadata) {
    if (condition === true) return true;
    if (condition === false) return false;
    if (typeof condition === "function") return condition(metadata);
    return hostMatches(condition);
  }

  window.registerNewsHomepageListProfile = function(condition, config) {
    newsHomepageListProfiles.push({ condition: condition, config: config });
  };

  window.hostAwareProfiles = window.hostAwareProfiles || [];
  window.hostAwareProfiles.push({
    condition: true,
    fn: function(metadata) {
      for (var i = 0; i < newsHomepageListProfiles.length; i += 1) {
        var profile = newsHomepageListProfiles[i];
        if (!newsHomepageListProfileMatches(profile.condition, metadata)) continue;

        var config = typeof profile.config === "function" ? profile.config(metadata) : profile.config;
        var result = newsHomepageListContent(metadata, config);
        if (result) return result;
      }
      return null;
    }
  });
