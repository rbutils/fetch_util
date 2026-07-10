function xinhuaWeeklyContent(metadata) {
  if (!hostMatches(/(^|\.)english\.news\.cn$/i)) return null;
  if (!/\/weekly\.htm$/i.test(location.pathname || "")) return null;

  return newsHomepageListContent(metadata, {
    title: (metadata && metadata.title) || document.title || "Biz China Weekly",
    siteName: (metadata && metadata.siteName) || "english.news.cn",
    minItems: 4,
    minTitleLength: 8,
    maxTitleLength: 40,
    linkSelector: "#list .item .tit a[href]",
    cardSelector: "#list .item",
    rejectTitle: /^More$/i
  });
}

registerHostAwareProfile(true, xinhuaWeeklyContent);
