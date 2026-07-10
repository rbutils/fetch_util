  function suspicionReasons(metadata, content, markdown, pageText, signals) {
    var reasons = [];
    var title = normalizeText((content && content.title) || metadata.title).toLowerCase();
    var body = normalizeText(markdown || (content && content.textContent) || "").toLowerCase();
    var page = normalizeText(pageText || "").toLowerCase();
    var combined = (title + " " + body + " " + page).trim();
    var compactNonLatinBody = compactNonLatinArticleBody(body);
    var challengeType = challengePageType(metadata, pageText, signals);
    var interstitialType = interstitialPageType(metadata, pageText);
    var docsLike = !!(content && content.docsLike);
    var packagePage = !!(content && content.packagePage);
    var glossaryPage = /definition of |what does .+ mean\??| pronunciation in english|dictionary|definitions for /.test(title) || /(\/dictionary\/|\/definition\/|\/definitions\/|\/pronunciation\/)/.test(location.pathname || "") ||
      (!!queryParam("q") && /\b(dictionary|translation|translate|thesaurus|lexicon|s[łl]ownik|t[łl]umaczenie)\b/.test(title + " " + normalizeText(metadata.excerpt || "").toLowerCase()));
    var readableDocsPage = docsLike && body.length > 20;
    var emptyExtraction = !normalizeText(markdown || "") && !normalizeText((content && content.textContent) || "");
    var boilerplateOnlyExtraction = body.length < 140 && /copyright\b.*\ball rights reserved\b/i.test(body) && !/[.!?].+[.!?]/.test(body);
    var contentText = normalizeText((content && content.textContent) || "").toLowerCase();
    var credibleListFeed = credibleHomepageListFeed(content, markdown, body, page);
    var extractedNotFoundText = normalizeText([body, contentText].join(" ")).toLowerCase();
    var extractedNotFoundBody = notFoundInterstitialEvidence(title, extractedNotFoundText, { maxTextLength: 1100 });
    var hasPublicContent = document.querySelectorAll("main a[href], article a[href]").length >= 3 || (content && content.contentType === "list");
    var consentDominatedBody = consentWallDominates(body);
    var substantialContent = body.length > 500 && !(consentDominatedBody && !hasPublicContent);
    var clearStructure = clearArticleStructure(content, markdown, body);

    reasons = reasons.concat(accessWarningReasons(metadata, content, markdown, body, page, combined, title, docsLike, readableDocsPage,
      challengeType, interstitialType, extractedNotFoundBody, hasPublicContent, substantialContent,
      emptyExtraction, boilerplateOnlyExtraction, signals));
    reasons = reasons.concat(contentIntegrityWarningReasons(metadata, content, markdown, body, page, combined, title, docsLike,
      readableDocsPage, glossaryPage, packagePage, credibleListFeed, challengeType, interstitialType,
      clearStructure, compactNonLatinBody, extractedNotFoundBody, hasPublicContent, substantialContent));
    return reasons;
  }
