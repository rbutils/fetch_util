  function strongSingleTopicPage(metadata, content, markdown, body) {
    if (!content || content.contentType !== "article" || content.docsLike || body.length < 1500) return false;
    var view = multiTopicExtractionView(content, markdown);
    var root = view.root || document;
    var cleanedMarkdown = view.markdown || markdown || "";
    if (content.singleTopicPage) return true;

    var title = normalizeText((content && content.title) || metadata.title || "").toLowerCase();
    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    var site = normalizeText((metadata && metadata.siteName) || "").toLowerCase();
    var mediaWikiArticleRoot = !!(root && root.matches && root.matches(".mw-parser-output, #mw-content-text, #bodyContent, .vector-body, .vector-body-inner"));
    var hasHeading = !!(content.html && /<h1\b/i.test(content.html)) || title.length > 20;
    if (!hasHeading) return false;

    var paragraphCount = ((cleanedMarkdown || "").match(/\n\s*\n/g) || []).length;
    var headingCount = ((cleanedMarkdown || "").match(/^#{1,6}\s+/gm) || []).length;
    var articleLikeRoot = !!root.querySelector("article, main, [itemprop='articleBody'], #mw-content-text .mw-parser-output, #bodyContent .mw-parser-output");
    if (mediaWikiArticleRoot && paragraphCount >= 3 && headingCount <= paragraphCount * 4 && body.length >= 800) return true;
    if (articleLikeRoot && paragraphCount >= 4 && headingCount <= paragraphCount * 3 && body.length >= 3000) return true;
    if (paragraphCount >= 10 && body.length >= 2500 && headingCount <= paragraphCount * 2) return true;

    var scholarlyContext = /\b(abstract|references|methods|results|discussion|data availability|journal|protein|genome|doi)\b/i.test(body) || /\/(articles?|doi)\//.test(path);
    if (body.length > 8000 && scholarlyContext) return true;

    var overviewContext = /\/(?:what-we-do|what_we_do|our-work|our_work|about|mission|programmes?|programs?)\b/.test(path) || /\b(institution|agency|united nations|ngo|foundation|what we do|our work|mission)\b/.test(title + " " + site);
    if (overviewContext && /\b(what we focus on|we work|our work|mission|protect|provide|advocate|countries and territories|programmes?|programs?)\b/i.test(body)) return true;

    return false;
  }

  function multiTopicIgnoredContainerSelector() {
    return [
      "aside", "nav", "footer", "[role='complementary']", "[role='navigation']",
      "[aria-label*='related' i]", "[aria-label*='recommended' i]", "[aria-label*='latest' i]",
      "[class*='related' i]", "[class*='recommend' i]", "[class*='recirculat' i]",
      "[class*='liveblog' i]", "[class*='live-blog' i]",
      "[class*='sidebar' i]", "[class*='side-bar' i]", "[class*='widget' i]",
      "[class*='comment' i]", "[class*='discussion' i]", "[class*='community' i]",
      "[class*='popular' i]", "[class*='trending' i]", "[class*='suggest' i]",
      "[class*='teaser' i]", "[class*='also-read' i]", "[class*='read-more' i]",
      "[class*='more-news' i]", "[class*='more-stories' i]", "[class*='more-from' i]", "[class*='front-page' i]",
      "[class*='article-list' i]", "[class*='content-list' i]", "[class*='story-list' i]",
      "[class*='news-list' i]", "[class*='headline-list' i]", "[class*='feed' i]",
      "[class*='story-card' i]", "[class*='storycard' i]", "[class*='article-related-content' i]",
      "[id*='related' i]", "[id*='recommend' i]", "[id*='comment' i]", "[id*='sidebar' i]", "[id*='widget' i]",
      "[data-component*='article-list' i]", "[data-component*='related' i]",
      "[data-testid*='related' i]", "[data-testid*='recommend' i]", "[data-testid*='comment' i]"
    ].join(", ");
  }

  function multiTopicExtractionView(content, markdown) {
    var root = document.createElement("div");
    root.innerHTML = content && content.html ? content.html : "";
    if (!root.innerHTML) return { root: null, markdown: markdown };

    Array.prototype.forEach.call(root.querySelectorAll(multiTopicIgnoredContainerSelector()), function(node) {
      node.parentNode.removeChild(node);
    });

    var filteredMarkdown = markdown;
    if (typeof markdownFor === "function") filteredMarkdown = markdownFor(root.innerHTML || "");
    return { root: root, markdown: filteredMarkdown || "" };
  }

  // Detect liveblog / multi-topic / briefing content format
  function detectContentFormat(metadata, content, markdown) {
    var title = normalizeText((content && content.title) || metadata.title || "").toLowerCase();
    var pathname = (location.pathname || "").toLowerCase();
    var body = normalizeText(markdown || (content && content.textContent) || "").toLowerCase();

    // 1. Structured data: LiveBlogPosting
    var liveblog = structuredDataNode(["LiveBlogPosting"]);
    if (liveblog) return "liveblog";

    // 2. DOM signals for liveblog
    var liveblogDOM = (multiTopicExtractionView(content, markdown).root || document).querySelector(
      "[data-liveblog], [class*='liveblog' i], [class*='live-blog' i], [id*='liveblog' i], " +
      "[class*='live-ticker' i], [class*='liveticker' i], [id*='live-ticker' i], " +
      "[class*='live-feed' i], [class*='live-updates' i], [class*='live-entries' i]"
    );
    if (liveblogDOM) return "liveblog";

    // 3. Title/URL patterns for liveblog
    if (/\b(liveblog|live.blog|live.ticker|liveticker|live updates?|live.updates?)\b/.test(title) ||
        /\b(liveblog|live-blog|liveticker|live-ticker|live-updates)\b/.test(pathname)) {
      return "liveblog";
    }

    // 4. Briefing / digest / roundup / compilation detection
    // Title patterns: "This Week in ...", "Daily Briefing", "Morning Roundup", "News Digest", etc.
    if (/\b(daily briefing|morning briefing|evening briefing|weekly briefing|news briefing|this week in|week in review|daily digest|news digest|morning roundup|evening roundup|weekly roundup|daily round-?up|weekly round-?up|tagesüberblick|nachrichtenüberblick|wochenrückblick|résumé de la semaine|tour d'horizon|resumen semanal|rassegna stampa|przegląd tygodnia|przegląd dnia|podsumowanie tygodnia|podsumowanie dnia|daglig oversikt|veckosammanfattning|nyhedsoverblik|ugens nyheder|viikon katsaus|savaitės apžvalga|nedēļas apskats|преглед на седмицата|огляд тижня|преглед на денот|săptămâna în revistă|heti összefoglaló|týdenní přehled)\b/.test(title)) {
      return "briefing";
    }

    // 4b. Event listing / calendar / agenda detection
    if (/\b(events?[\s-]*(?:calendar|listing|guide|agenda|schedule)|what['']?s on|upcoming events?|things to do|veranstaltungen|événements|eventos|eventi|wydarzenia|evenementen|evenemang|begivenheder|tapahtumat|renginiai|pasākumi|események|události|events?\s+this\s+week|events?\s+today|event guide|gig guide|concert schedule)\b/.test(title) ||
        /\/(events?|calendar|agenda|whats-on|what-s-on|veranstaltungen|evenements)\b/.test(pathname)) {
      // Verify content has event-like structure (multiple date/time references)
      var datePatterns = body.match(/\b\d{1,2}[\s./-]\s*(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?|janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre|januar|februar|märz|april|juni|juli|august|oktober|dezember|styczeń|luty|marzec|kwiecień|maj|czerwiec|lipiec|sierpień|wrzesień|październik|listopad|grudzień)\b/gi) || [];
      if (datePatterns.length >= 2) return "event_listing";
      // Also detect structured event data
      var eventSD = structuredDataNode(["Event", "MusicEvent", "SportsEvent", "TheaterEvent", "Festival"]);
      if (eventSD) return "event_listing";
    }

    // 4c. Video-only / video-centric page detection
    // Structured data: VideoObject, Movie, TVEpisode, etc.
    var videoSD = structuredDataNode(["VideoObject", "Movie", "TVEpisode", "TVSeries", "TVSeason", "Clip"]);
    if (videoSD) {
      // Only classify as video if text content is thin (not a full article with embedded video)
      if (body.length < 800) return "video";
    }
    // DOM signals: prominent video players with minimal article text
    var videoPlayers = document.querySelectorAll(
      "video, [class*='video-player' i], [class*='videoplayer' i], [id*='video-player' i], " +
      "[class*='jwplayer' i], [class*='bitmovin' i], [class*='brightcove' i], " +
      "[data-player], [data-video-id], [data-video], " +
      "[class*='auvio' i][class*='player' i], [class*='media-player' i], [class*='mediaplayer' i]"
    );
    var videoIframes = document.querySelectorAll(
      "iframe[src*='youtube'], iframe[src*='youtu.be'], iframe[src*='vimeo'], " +
      "iframe[src*='dailymotion'], iframe[src*='player'], iframe[src*='video'], " +
      "iframe[data-src*='youtube'], iframe[data-src*='vimeo']"
    );
    if ((videoPlayers.length >= 1 || videoIframes.length >= 1) && body.length < 600) {
      return "video";
    }
    // URL path signals combined with short content
    if (/\/(video|videos|watch|player|clip|replay|auvio|mediathek|mediatheque|videoteka|platforma)\b/.test(pathname) && body.length < 800) {
      // Verify there's actually minimal prose (not just a video page with a full article too)
      var proseLen = body.replace(/https?:\/\/\S+/g, "").replace(/[^a-zA-Z\u00C0-\u024F\u0400-\u04FF\u0370-\u03FF\u0100-\u017F\u0180-\u024F]/g, " ").replace(/\s+/g, " ").trim().length;
      if (proseLen < 500) return "video";
    }

    var formatView = multiTopicExtractionView(content, markdown);
    var formatMarkdown = formatView.markdown || markdown || "";

    // 5. Multi-topic heuristic: page contains multiple distinct timestamped entries or update blocks
    // Count headings and timestamps only after related/sidebar/list/feed widgets are removed.
    if (formatView.root) {
      var headings = formatView.root.querySelectorAll("h2, h3");
      var timeElements = formatView.root.querySelectorAll("time, [datetime]");

      // Multiple time-stamped entries suggest a compilation / live-update page
      // Require higher thresholds: >= 6 time elements (up from 4) and >= 4 headings (up from 3)
      if (timeElements.length >= 6 && headings.length >= 4) {
        // Verify the time elements are associated with distinct sections
        var uniqueTimes = [];
        for (var i = 0; i < timeElements.length; i++) {
          var dt = timeElements[i].getAttribute("datetime") || normalizeText(timeElements[i].textContent);
          if (dt && uniqueTimes.indexOf(dt) === -1) uniqueTimes.push(dt);
        }
        if (uniqueTimes.length >= 4) return "liveblog";
      }
    }

    // 6. Markdown-level heuristic: many H2/H3 with timestamps interspersed
    // Require higher thresholds to avoid false positives on regular articles
    // with a single publication timestamp (e.g. "Stand: 04:07 Uhr")
    if (formatMarkdown) {
      var h2Count = (formatMarkdown.match(/^##\s+/gm) || []).length;
      var timestampCount = (formatMarkdown.match(/\b\d{1,2}[:.]\d{2}\s*(?:Uhr|AM|PM|CET|CEST|UTC|GMT|[A-Z]{2,4}T)?\b/gm) || []).length;
      if (h2Count >= 6 && timestampCount >= 6) return "liveblog";
    }

    // 7. Newsletter / flash-news digest / hub detection:
    // Pages with many short items each linking out (e.g. daily flash-news compilations,
    // weekly newsletters, aggregated briefing hubs). Distinct from "briefing" which
    // matches specific title patterns — this catches structural layout patterns.
    if (formatMarkdown && content && content.html) {
      var mdLines = formatMarkdown.split("\n").filter(function(l) { return l.trim().length > 0; });
      var mdLinks = (formatMarkdown.match(/\[([^\]]*)\]\([^)]+\)/g) || []);
      var mdHeadings = (formatMarkdown.match(/^#{1,3}\s+/gm) || []).length;

      // Count short text blocks (< 200 chars between headings/links) — characteristic of
      // digest/hub layouts where each item is just a headline + 1-2 sentence summary + link
      var shortBlocks = 0;
      var currentBlockLen = 0;
      for (var li = 0; li < mdLines.length; li++) {
        var line = mdLines[li];
        if (/^#{1,3}\s+/.test(line)) {
          if (currentBlockLen > 0 && currentBlockLen < 200) shortBlocks++;
          currentBlockLen = 0;
        } else {
          currentBlockLen += line.length;
        }
      }
      if (currentBlockLen > 0 && currentBlockLen < 200) shortBlocks++;

      // Newsletter/digest: many headings, many links, and most content blocks are short
      if (mdHeadings >= 4 && mdLinks.length >= 5 && shortBlocks >= 4 && shortBlocks >= mdHeadings * 0.6) {
        return "newsletter";
      }

      // Hub/index page: dominated by links with very little prose relative to link count
      // (e.g. news hub pages listing story headlines as links)
      var proseText = formatMarkdown.replace(/\[([^\]]*)\]\([^)]+\)/g, "$1").replace(/^#{1,6}\s+.*$/gm, "").replace(/[^a-zA-Z\u00C0-\u024F\u0400-\u04FF\u0370-\u03FF\u0100-\u017F\u0180-\u024F]/g, " ").replace(/\s+/g, " ").trim();
      var proseWordCount = proseText.split(/\s+/).filter(function(w) { return w.length >= 3; }).length;
      if (mdLinks.length >= 8 && mdHeadings >= 4 && proseWordCount < mdLinks.length * 5) {
        return "newsletter";
      }
    }

    return null;
  }
