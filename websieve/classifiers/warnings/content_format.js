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

  function unicodeWordCount(text) {
    var value = String(text || "");
    if (typeof Intl !== "undefined" && typeof Intl.Segmenter === "function") {
      var segments = new Intl.Segmenter(undefined, { granularity: "word" }).segment(value);
      var words = 0;
      for (var segment of segments) {
        if (segment.isWordLike) words++;
      }
      return words;
    }
    return (value.match(/[\p{L}\p{N}]+/gu) || []).length;
  }

  function newsletterStructuralEvidence(content, markdown, root, focalArticleRoot) {
    if (!markdown || !content || !content.html || !root) return { dense: false, linkDominated: false };

    var mdLines = markdown.split("\n").filter(function(line) { return line.trim().length > 0; });
    var mdLinks = (markdown.replace(/!\[[^\]]*\]\([^)]+\)/g, "").match(/\[([^\]]*)\]\([^)]+\)/g) || []);
    var mdHeadings = (markdown.match(/^#{1,3}\s+/gm) || []).length;
    var shortBlocks = 0;
    var currentBlockLen = 0;
    for (var lineIndex = 0; lineIndex < mdLines.length; lineIndex++) {
      var line = mdLines[lineIndex];
      if (/^#{1,3}\s+/.test(line)) {
        if (currentBlockLen > 0 && currentBlockLen < 200) shortBlocks++;
        currentBlockLen = 0;
      } else {
        currentBlockLen += newsletterVisibleMarkdownLength(line);
      }
    }
    if (currentBlockLen > 0 && currentBlockLen < 200) shortBlocks++;

    var commerceCardCount = newsletterCommerceCardCount(focalArticleRoot);
    shortBlocks = Math.max(0, shortBlocks - commerceCardCount);
    var linkedSections = Math.max(0, newsletterIndependentLinkedSectionCount(root) - commerceCardCount);
    var dense = mdHeadings >= 4 && mdLinks.length >= 5 && linkedSections >= 4 &&
      shortBlocks >= 4 && shortBlocks >= mdHeadings * 0.6;
    var proseText = markdown.replace(/\[([^\]]*)\]\([^)]+\)/g, "$1").replace(/^#{1,6}\s+.*$/gm, "");
    var proseWordCount = unicodeWordCount(proseText);
    var linkDominated = !!(focalArticleRoot && mdLinks.length >= 8 && mdHeadings >= 4 &&
      proseWordCount < mdLinks.length * 5);

    return { dense: dense, linkDominated: linkDominated };
  }

  function newsletterHasMultiTopicListStructure(content, markdown, root) {
    if (!content || content.contentType !== "list") return false;
    var evidence = newsletterStructuralEvidence(content, markdown, root, root);
    return evidence.dense || evidence.linkDominated;
  }

  function newsletterFocalArticleRoot(metadata, content, root) {
    if (!content || content.contentType !== "article" || !root) return null;
    var pageTitle = normalizeText((content && content.title) || (metadata && metadata.title) || "");
    var titleOwner = newsletterSelectedSourceTitleOwner(root, pageTitle, false);
    return titleOwner ? titleOwner.selectedOwner : null;
  }

  // Detect liveblog / multi-topic / briefing content format
  function detectContentFormat(metadata, content, markdown) {
    var title = normalizeText((content && content.title) || metadata.title || "").toLowerCase();
    var pathname = (location.pathname || "").toLowerCase();
    var body = normalizeText(markdown || (content && content.textContent) || "").toLowerCase();

    // 1. Structured data: LiveBlogPosting
    var liveblog = structuredDataNode(["LiveBlogPosting"]);
    if (liveblog) return "liveblog";
    if (content && content.sourceOwnedLiveblog === true) return "liveblog";
    if (content && content.sourceOwnedUnattributedManual === true && content.sourceOwnedManualTitle === content.title &&
        content.sourceOwnedCleanedManualHtml === content.html) return null;

    // 2. DOM signals for liveblog
    var formatRoot = multiTopicExtractionRoot(content);
    var liveblogDOM = (formatRoot || document).querySelector(
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

    if (content && content.sourceOwnedContentsComponent) return null;
    if (content && content.sourceOwnedPublishedFeed === true &&
        content.contentType === "social" && content.socialKind === "feed") return null;

    if (content.mediaOwnedTranscript && /\/(?:videos|watch|clip|replay)\b/.test(pathname) &&
        structuredDataNode(["VideoObject"])) return "video";

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

    var guideRoot = formatRoot;
    var formatHtml = guideRoot ? guideRoot.innerHTML : "";
    var editionContext = newsletterEditionContext(metadata, content, guideRoot);
    var singleArticleIdentity = newsletterSingleArticleIdentity(guideRoot);
    var focalArticleRoot = newsletterFocalArticleRoot(metadata, content, guideRoot);
    var authoredDigestRecords = newsletterIndependentLinkedSectionCount(guideRoot, true);
    var focalArticleDigestRecords = focalArticleRoot ? newsletterIndependentLinkedSectionCount(focalArticleRoot, true) : 0;
    // Extracted topic pages can contain article cards without owning a focal article or digest.
    var articleDigestEvidence = content && content.contentType === "article" &&
      (!content.wordpressBlockPage || editionContext) &&
      (focalArticleRoot || authoredDigestRecords >= 4) &&
      (!singleArticleIdentity || (focalArticleDigestRecords >= 4 &&
        (editionContext || newsletterIndependentLinkedSectionCount(focalArticleRoot, true, true) >= 4)));
    var listDigestEvidence = content && content.contentType === "list" && authoredDigestRecords >= 4 &&
      editionContext && !newsletterNonEditorialList(guideRoot);
    var newsletterEvidence = !!(articleDigestEvidence || listDigestEvidence);
    var codeRichGuide = content && content.contentType === "article" && guideRoot &&
      /\b(?:guides?|docs?|documentation|reference|tutorials?|manual)\b/i.test([
        document.title, location.pathname, location.hostname
      ].join(" ")) &&
      guideRoot.querySelectorAll("pre").length >= 6 && guideRoot.querySelectorAll("p").length >= 8 &&
      guideRoot.querySelectorAll("h2, h3").length >= 6;

    // 5. Multi-topic heuristic: page contains multiple distinct timestamped entries or update blocks
    // Count headings and timestamps only after related/sidebar/list/feed widgets are removed.
    var timestampedIndexList = content && (content.contentType === "list" || content.wordpressBlockPage === true);
    var timestampedHomepageList = timestampedIndexList && homepageRootPath();
    var credibleRootHomepageList = timestampedHomepageList &&
      (content.portalRootEvidence || homepageHasEditorialSections(document));
    // Dated records on any list are not live updates without the explicit evidence above.
    if (guideRoot && !timestampedIndexList && !codeRichGuide) {
      var headings = guideRoot.querySelectorAll("h2, h3");
      var timeElements = guideRoot.querySelectorAll("time, [datetime]");

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
    var needsFormatMarkdown = (!timestampedIndexList && !codeRichGuide) || newsletterEvidence;
    var formatMarkdown = "";
    if (needsFormatMarkdown) {
      formatMarkdown = (guideRoot ? multiTopicViewMarkdown(content, formatHtml, markdown) : markdown) || markdown || "";
    }
    if (formatMarkdown && !timestampedIndexList && !codeRichGuide) {
      var h2Count = (formatMarkdown.match(/^##\s+/gm) || []).length;
      // A dotted coin price such as 0.01 is not a time; dotted clocks need a time unit.
      var clockTimes = formatMarkdown.match(/\b(?:[01]?\d|2[0-3]):[0-5]\d\b/gm) || [];
      var dottedTimes = formatMarkdown.match(/\b(?:[01]?\d|2[0-3])\.[0-5]\d\s*(?:Uhr|AM|PM|CET|CEST|UTC|GMT)\b/gm) || [];
      var timestampCount = clockTimes.length + dottedTimes.length;
      if (h2Count >= 6 && timestampCount >= 6) return "liveblog";
    }

    // 7. Newsletter / flash-news digest / hub detection:
    // Pages with many short items each linking out (e.g. daily flash-news compilations,
    // weekly newsletters, aggregated briefing hubs). Distinct from "briefing" which
    // matches specific title patterns — this catches structural layout patterns.
    // A proved alphabet/year browse index is a directory, even when its links
    // satisfy the short-block and link-density heuristics for a digest.
    if (formatMarkdown && content && content.html && guideRoot &&
        (!credibleRootHomepageList || newsletterEvidence) && (!content.browseIndexEvidence || newsletterEvidence)) {
      if (!newsletterEvidence) return null;
      var structuralNewsletter = newsletterStructuralEvidence(content, formatMarkdown, guideRoot, focalArticleRoot);
      // Newsletter format requires source-owned editorial evidence as well as this structure.
      if (newsletterEvidence && structuralNewsletter.dense) {
        return "newsletter";
      }

      // Hub/index page: dominated by links with very little prose relative to link count
      // (e.g. news hub pages listing story headlines as links)
      if (newsletterEvidence && structuralNewsletter.linkDominated) {
        return "newsletter";
      }
    }

    return null;
  }
