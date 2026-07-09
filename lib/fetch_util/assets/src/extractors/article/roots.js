  var LEGAL_PROVISION_TITLE_PATTERN = /(?:constitution|constitutional|constitui[cç]?[aã]o|c[oó]digo|codigo|code|statute|act|law|regulation|ordinance|decree|treaty|convention)/i;
  var LEGAL_PROVISION_OFFICIAL_TITLE_PATTERN = /\b(?:civil|criminal|commercial|tax|labou?r|procedure|family|public|administrative)?\s*(?:code|statute|act|law|regulation|ordinance)\b/i;
  var LEGAL_PROVISION_MARKER_PATTERN = /(?:^|\s)(?:Art\.?|Article|Section|Sec\.?|§)\s*(?:\d+[ºª]?|[IVXLCDM]+)/gi;
  var LEGAL_PROVISION_STRUCTURAL_PATTERN = /\b(?:title|chapter|part|book|t[ií]tulo|cap[ií]tulo|se[cç][aã]o)\s+(?:[IVXLCDM]+|\d+)/gi;
  var LEGAL_PROVISION_TERMS_PATTERN = /(?:federal republic|rep[úu]blica federativa|republica federativa|civil rights|fundamental rights|legal provisions?|official gazette|promulgat|enacted|amended|paragraph|par[áa]grafo|paragrafo|inciso|subsection)/i;
  var LEGAL_PROVISION_OFFICIAL_TEXT_PATTERN = /\b(?:legal provisions?|federal law gazette|official gazette|version information|translation includes? the amendment|current status of the .* version|conditions governing use of this translation)\b/i;
  var LEGAL_PROVISION_PROFILE_OFFICIAL_TEXT_PATTERN = /\b(?:version information|translation provided by|translations? may not be updated|full citation|federal law gazette|table of contents)\b/i;
  var LEGAL_PROVISION_TRANSLATION_PATTERN = /\b(?:translation provided by|translated by|translation includes?|translations? may not be updated|updated by|revised and updated by)\b/i;
  var LEGAL_PROVISION_SECTION_MARKER_PATTERN = /(?:^|\s)(?:§|Section|Sec\.?|Article)\s*\d+/i;
  var LEGAL_PROVISION_BODY_START_PATTERN = /(?:^|\s)(?:Art\.?|Article|Section|Sec\.?|§)\s*(?:1|I)\b/i;

  function legalProvisionContext(options) {
    options = options || {};
    var root = options.root || null;
    var text = normalizeText(options.text || (root && root.textContent) || "");
    var title = normalizeText(options.title || document.title || "");
    var path = safeDecodeURI(options.path || (location && location.pathname) || "").toLowerCase();
    var titleContext = normalizeText([title, path].join(" ")).toLowerCase();
    var context = normalizeText([titleContext, text.slice(0, options.contextLimit || 4000)].join(" ")).toLowerCase();

    return {
      text: text,
      titleContext: titleContext,
      context: context,
      legalTitle: LEGAL_PROVISION_TITLE_PATTERN.test(context),
      officialStatuteTitle: LEGAL_PROVISION_OFFICIAL_TITLE_PATTERN.test(titleContext),
      officialTextSignals: LEGAL_PROVISION_OFFICIAL_TEXT_PATTERN.test(context),
      profileOfficialTextSignals: LEGAL_PROVISION_PROFILE_OFFICIAL_TEXT_PATTERN.test(text),
      translationAttribution: LEGAL_PROVISION_TRANSLATION_PATTERN.test(context),
      provisionMarkers: (text.match(LEGAL_PROVISION_MARKER_PATTERN) || []).length,
      structuralMarkers: (text.match(LEGAL_PROVISION_STRUCTURAL_PATTERN) || []).length,
      legalTerms: LEGAL_PROVISION_TERMS_PATTERN.test(text),
      numberedClauses: (text.match(/(?:^|\s)\(\d+\)|(?:^|\s)\([a-z]\)/gi) || []).length,
      sectionOrArticleMarker: LEGAL_PROVISION_SECTION_MARKER_PATTERN.test(text),
      bodyStartMatch: text.match(LEGAL_PROVISION_BODY_START_PATTERN)
    };
  }

  function genericArticleSelectors() {
    return [
      "main[role='main']",
      "article[role='main']",
      "[itemprop='articleBody']", ".article__body", ".post-content", ".entry-content", "[class*='article-content']", "[class*='amp-article-content' i]", "[class*='amp-article-body' i]", "[class*='mobile-article' i]", "[class*='mobile-content' i]", "[class*='rtl-article' i]",
      "[class*='article-content' i]",
      "[class*='article-body' i]",
      "[class*='article-main' i]",
      "[class*='article__body' i]",
      "[class*='article__content' i]",
      "[class*='articletext' i]",
      "[class*='article-text' i]",
      "[class*='article_text' i]",
      "[class*='content-body' i]",
      "[class*='content__body' i]",
      "[class*='main-article' i]",
      "[class*='post-content' i]",
      "[class*='post-description' i]",
      "[class*='entry-content' i]",
      "[class*='story-content' i]",
      "[class*='news-content' i]",
      "[class*='amp-wp-article-content' i]",
      "[class*='article-body-mobile' i]",
      "[class*='mobile-article-body' i]",
      "[class*='contenido-noticia' i]",
      "[class*='conteudo-noticia' i]",
      "[class*='corpo-noticia' i]",
      "[class*='texto-noticia' i]",
      "[class*='isi-berita' i]",
      "[class*='berita-content' i]",
      "[class*='haber-metni' i]",
      "[class*='wysiwyg' i]",
      "[class*='rich-text' i]",
      "[data-testid*='article-body' i]",
      "[data-testid*='article-content' i]",
      "[data-component*='article-body' i]",
      "[data-component*='article-content' i]",
      "[data-module*='article-body' i]",
      "[data-module*='article-content' i]",
      "[data-qa*='article-body' i]",
      "[data-qa*='article-content' i]",
      "main",
      "article",
      ".article-content",
      ".t-content",
      ".t-content--article",
      ".main-content",
      ".post-content",
      ".entry-content",
      ".story-body",
      ".news-content",
      ".article-body",
      "[data-article-body]",
      ".content-body",
      ".article__body",
      ".article",
      ".post",
      ".entry",
      ".content",
      ".main",
      "section",
      "div"
    ];
  }

  function cleanupGenericArticleRoot(root) {
    if (!root || !root.querySelectorAll) return root;

    removeAll(root, "#comments, #respond, .comments-area, .comment-list, .comments-section, .post-comments, .disqus-comment-count, [class*='comment-respond'], [class*='comentario' i], [class*='comentarios' i], [class*='commentaire' i], [class*='komentar' i], [class*='komentarze' i], [class*='yorum' i], .sharedaddy, .share, .share-links, .share-buttons, .social-sharing, .social-buttons, [class*='share' i], [id*='share' i], [class*='compartir' i], [class*='partager' i], [class*='teilen' i], [class*='paylas' i], [class*='paylaş' i], [class*='related' i], [id*='related' i], [class*='recommend' i], [id*='recommend' i], [class*='relacionad' i], [class*='relacionados' i], [class*='recomendad' i], [class*='recomendados' i], [class*='similares' i], [class*='newsletter' i], [id*='newsletter' i], [class*='subscribe' i], [id*='subscribe' i], [class*='advert' i], [id*='advert' i], [class*='promo' i], [id*='promo' i], [class*='adslot' i], [id*='adslot' i], [data-ad], [data-ads]");
    stripNavigationLeaks(root);
    stripRelatedSectionsByHeading(root);

    return root;
  }

  function legalProvisionContent() {
    var structuredRoot = structuredLegalTextRoot();
    var provisionRoot = document.querySelector("#viewLegSnippet, .viewLegSnippet, .LegislationSection, .legislation-section, [class*='LegislationSection' i], #viewLegContents, .viewLegContents") || structuredRoot;
    if (!provisionRoot) return null;

    var pageText = normalizeText(document.body && document.body.textContent || "");
    var provisionText = normalizeText(provisionRoot.textContent || "");
    var legalContext = legalProvisionContext({ root: provisionRoot, text: provisionText });
    var structuralContext = document.querySelector("#changesOverTime, #legNav, #breadCrumb, .legContent, [id*='legislation' i], [class*='legislation' i]");
    var legislationChrome = /\b(what version|changes to legislation|timeline of changes|plain view|print options|opening options)\b/i.test(pageText);

    if (provisionText.length < 250) return null;
    if (!structuredRoot && !structuralContext && !legislationChrome) return null;
    if (legalContext.numberedClauses < 2 && !/\b(section|article|regulation|schedule)\s+\d+\b/i.test(provisionText)) return null;

    var clone = cleanClone(provisionRoot);
    var title = document.querySelector("#pageTitle, h1") || null;
    var heading = clone.querySelector("h1, h2, h3") || null;
    var text = normalizeText(clone.textContent || "");

    return {
      title: normalizeText((title && title.textContent) || document.title),
      byline: null,
      excerpt: text.slice(0, 280) || null,
      siteName: location.hostname,
      publishedTime: null,
      html: (heading ? "" : title ? title.outerHTML : "") + clone.innerHTML,
      textContent: text,
      readerMode: false,
      contentType: "article",
      legalProvision: true
    };
  }

  function structuredLegalTextRoot() {
    var root = document.querySelector("text .text .section, text .section, [class~='text'] > .section");
    if (!root) return null;

    var text = normalizeText(root.textContent || "");
    var hasLegalNotes = !!document.querySelector("notes, [id*='notes' i], [class*='notes' i]");
    var legalContext = legalProvisionContext({ text: text, title: document.title || "" });
    var hasStatutoryMarkers = /\b(?:U\.S\.\s+Code|Code|Statute|Act|Section|§)\b/i.test(document.title || "") || legalContext.sectionOrArticleMarker;

    if (text.length < 250 || !hasLegalNotes || !hasStatutoryMarkers || legalContext.numberedClauses < 2) return null;
    return root;
  }
