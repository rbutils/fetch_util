  var SCHOLARLY_RECORD_ABSTRACT_SELECTORS = [
    "[role='doc-abstract']", "[property='abstract']", "blockquote.abstract",
    "section.abstract", ".article_abstract", ".abstractSection", ".article__abstract",
    ".article-abstract", ".html-abstract", ".art-abstract", ".abstract-text-content",
    ".abstract.toc-section", "#abstract", ".abstract"
  ];

  var SCHOLARLY_RECORD_BODY_SELECTORS = [
    "[property='articleBody']", "[itemprop='articleBody']", "#bodymatter",
    ".html-body", ".art-body", ".article__body", ".article-body", ".ArticleBody"
  ];

  function scholarlyRecordVisible(node) {
    return !!node && !elementVisuallyHidden(node);
  }

  function scholarlyRecordAbstracts(root) {
    var nodes = [];
    SCHOLARLY_RECORD_ABSTRACT_SELECTORS.forEach(function(selector) {
      root.querySelectorAll(selector).forEach(function(node) {
        if (nodes.indexOf(node) === -1 && scholarlyRecordVisible(node)) nodes.push(node);
      });
    });
    return nodes;
  }

  function scholarlyRecordOwner(abstractNode) {
    var semanticArticle = abstractNode.closest("article[typeof*='ScholarlyArticle' i], article[itemtype*='ScholarlyArticle' i]");
    if (semanticArticle) return semanticArticle;
    var article = abstractNode.closest("article");
    if (article) return article;
    var articleText = abstractNode.closest(".article-text");
    if (articleText) return articleText;
    var local = abstractNode.parentElement;
    while (local && local !== document.body) {
      var headlines = Array.prototype.filter.call(local.querySelectorAll("[itemprop='headline'], h1"), scholarlyRecordVisible);
      var recordMetadata = local.querySelector(".authors, .dateline, .metatable, [itemprop='author'], time[datetime]");
      if (headlines.length === 1 && recordMetadata) return local;
      local = local.parentElement;
    }
    var main = abstractNode.closest("main");
    if (main) return main;
    var roleMain = abstractNode.closest("[role='main']");
    if (roleMain) return roleMain;
    return scholarlyRecordBodyLevelProof(abstractNode) ? document.body : null;
  }

  function scholarlyRecordBodyLevelProof(abstractNode) {
    if (!abstractNode || abstractNode.parentElement !== document.body) return false;
    var visibleAbstracts = scholarlyRecordAbstracts(document);
    if (visibleAbstracts.length !== 1 || visibleAbstracts[0] !== abstractNode) return false;

    var citationTitle = document.querySelectorAll("meta[name='citation_title']");
    var citationDoi = document.querySelectorAll("meta[name='citation_doi']");
    if (citationTitle.length !== 1 || citationDoi.length !== 1 ||
        !normalizeText(citationTitle[0].getAttribute("content") || "") ||
        !normalizeText(citationDoi[0].getAttribute("content") || "")) return false;

    if (document.querySelector("article, [typeof*='ScholarlyArticle' i], [itemtype*='ScholarlyArticle' i], .article-text")) return false;
    var bodyChildren = Array.prototype.filter.call(document.body.children, scholarlyRecordVisible);
    var bodyMarkers = bodyChildren.filter(function(node) {
      return node.matches("[property='articleBody'], [itemprop='articleBody']");
    });
    var articleSections = bodyChildren.filter(function(node) {
      return node.matches("section[id^='sec_' i], section[id^='sec-' i]") &&
        normalizeText(visibilityPrunedClone(node, document).textContent || "").length >= 80;
    });
    var bibliographies = bodyChildren.filter(function(node) {
      return node.matches("[role='doc-bibliography'], [itemprop='backstory']");
    });
    return bibliographies.length === 1 && (bodyMarkers.length === 1 || articleSections.length >= 2);
  }

  function scholarlyRecordTitleNode(root) {
    var headlines = Array.prototype.filter.call(root.querySelectorAll("[itemprop='headline'], h1"), scholarlyRecordVisible);
    if (headlines.length === 1) return headlines[0];
    var main = root.closest("main, [role='main']");
    if (!main) return null;
    var mainHeadlines = Array.prototype.filter.call(main.querySelectorAll("[itemprop='headline'], h1"), scholarlyRecordVisible);
    return mainHeadlines.length === 1 ? mainHeadlines[0] : null;
  }

  function scholarlyRecordCandidateOwner(abstractNode) {
    var owner = scholarlyRecordOwner(abstractNode);
    if (!owner || owner === document.documentElement) return null;
    if (owner === document.body && !scholarlyRecordBodyLevelProof(abstractNode)) return null;
    if (abstractNode.closest("aside, nav, footer, [role='navigation'], [role='complementary'], [role='dialog'], [class*='recommend' i], [id*='recommend' i], [class*='sidebar' i], [id*='sidebar' i]")) return null;
    return owner;
  }

  function scholarlyRecordOwnersConflict(owner) {
    var recordOwners = Array.prototype.filter.call(document.querySelectorAll("article, [typeof*='ScholarlyArticle' i], [itemtype*='ScholarlyArticle' i]"), scholarlyRecordVisible);
    var relevant = recordOwners.filter(function(candidate) {
      if (candidate === owner || owner.contains(candidate)) return true;
      return !!(candidate.querySelector("[role='doc-abstract'], [property='abstract'], blockquote.abstract, .article_abstract, .abstractSection, .abstract-text-content, .abstract") ||
        candidate.querySelector("[property='articleBody'], [itemprop='articleBody'], #bodymatter"));
    });
    var topLevel = relevant.filter(function(candidate) {
      return !relevant.some(function(other) { return other !== candidate && other.contains(candidate); });
    });
    return topLevel.length > 1;
  }

  function scholarlyRecordAbstractScore(node) {
    var score = node.matches("[role='doc-abstract'], [property='abstract']") ? 10 : 0;
    var identityNode = node.closest("[id], [class]");
    var identity = ((identityNode && identityNode.id) || "") + " " + ((identityNode && identityNode.className) || "");
    if (/author-abstract|article[-_]abstract/i.test(identity)) score += 20;
    if (/highlight|teaser|summary[-_]points/i.test(identity)) score -= 40;
    var heading = node.querySelector("h1, h2, h3, [property='name']");
    var headingText = normalizeText(heading && heading.textContent || "");
    if (/^(abstract|summary)$/i.test(headingText)) score += 10;
    if (/^highlights?$/i.test(headingText)) score -= 40;
    return score;
  }

  function scholarlyRecordIdentity(owner, abstractNode, metadata) {
    var title = scholarlyRecordTitleNode(owner);
    var schema = owner.matches("[typeof*='ScholarlyArticle' i], [itemtype*='ScholarlyArticle' i]");
    var citationTitle = document.querySelector("meta[name='citation_title']");
    var citationDoi = document.querySelector("meta[name='citation_doi'], meta[name='dc.Identifier'][content*='doi' i]");
    var citationJournal = document.querySelector("meta[name='citation_journal_title']");
    var localRecordFields = owner.querySelector("[itemprop='author'], [rel='author'], .authors, .dateline, [itemprop='datePublished'], time[datetime], [role='doc-bibliography']");
    var labeledPublication = Array.prototype.some.call(owner.querySelectorAll("p, div, span"), function(node) {
      return scholarlyRecordVisible(node) && /^(?:published in|doi|submitted|last revised)\s*:/i.test(normalizeText(node.textContent || ""));
    });
    var citationElements = document.querySelectorAll("meta[name='citation_title'], meta[name='citation_doi'], meta[name='citation_journal_title']");
    var recordNodes = Array.prototype.filter.call(document.querySelectorAll("article, [typeof*='ScholarlyArticle' i], [itemtype*='ScholarlyArticle' i], .article-text"), scholarlyRecordVisible);
    var topRecordNodes = recordNodes.filter(function(node) {
      return !recordNodes.some(function(other) { return other !== node && other.contains(node); });
    });
    var uniqueCitation = (!!citationTitle || !!citationDoi || !!citationJournal) &&
      citationElements.length <= 3 && topRecordNodes.length <= 1 &&
      document.querySelectorAll("meta[name='citation_title']").length <= 1 &&
      document.querySelectorAll("meta[name='citation_doi']").length <= 1 &&
      document.querySelectorAll("meta[name='citation_journal_title']").length <= 1;
    var titledRecord = !!title || (!!citationTitle && uniqueCitation);
    var structuralOwner = owner.matches("main, [role='main']") && title &&
      abstractNode.closest("[data-extent='frontmatter']") &&
      owner.querySelectorAll("[property='articleBody']:not([hidden])").length === 1 &&
      owner.querySelectorAll("article").length === 0 &&
      owner.querySelectorAll("[data-extent='bodymatter']").length === 1;
    return !!(schema || structuralOwner || (abstractNode.closest("[role='doc-abstract']") && titledRecord && (uniqueCitation || localRecordFields)) ||
      (title && (uniqueCitation || localRecordFields || labeledPublication)) ||
      (abstractNode.matches(".abstract-text-content") && labeledPublication));
  }

  function scholarlyRecordBodyRoots(owner, abstractNode) {
    var body = null;
    for (var index = 0; index < SCHOLARLY_RECORD_BODY_SELECTORS.length; index += 1) {
      var matches = Array.prototype.filter.call(owner.querySelectorAll(SCHOLARLY_RECORD_BODY_SELECTORS[index]), function(node) {
        return scholarlyRecordVisible(node);
      });
      if (matches.length) {
        body = matches[0];
        break;
      }
    }

    if (body && body !== owner && body !== abstractNode && !body.contains(abstractNode)) {
      var explicitFrontAndBody = body.matches("[property='articleBody'], [itemprop='articleBody'], #bodymatter") &&
        abstractNode.closest("[data-extent='frontmatter'], [property='abstract'], [role='doc-abstract']");
      if (owner.matches("article, [typeof*='ScholarlyArticle' i], [itemtype*='ScholarlyArticle' i], .article-text") || explicitFrontAndBody) return [body];
    }

    if (!owner.matches("article, [typeof*='ScholarlyArticle' i], [itemtype*='ScholarlyArticle' i], .article-text")) body = null;

    var sections = Array.prototype.filter.call(owner.querySelectorAll(
      "section[id^='sec' i], section.section, div.section, .section"
    ), function(node) {
      if (!scholarlyRecordVisible(node) || node === abstractNode || node.contains(abstractNode)) return false;
      if (!/^sec/i.test(node.id || "") && !node.querySelector("a[data-toc]")) return false;
      if (node.closest("[role='doc-bibliography'], [itemprop='backstory'], [id*='supplement' i], [class*='supplement' i]")) return false;
      var heading = node.querySelector("h2, h3, h4");
      if (/^(?:supporting information|supplementary material|supplemental information)$/i.test(normalizeText(heading && heading.textContent || ""))) return false;
      return normalizeText(visibilityPrunedClone(node, document).textContent || "").length >= 80;
    });
    sections = sections.filter(function(node) {
      return !sections.some(function(other) { return other !== node && other.contains(node); });
    });
    if (sections.length) return sections;

    if (body && body.contains(abstractNode)) {
      var visibleBody = visibilityPrunedClone(body, document);
      visibleBody.querySelectorAll("[role='doc-abstract'], [property='abstract'], blockquote.abstract, .article_abstract, .abstractSection, .abstract-text-content, .abstract").forEach(function(node) {
        node.remove();
      });
      return normalizeText(visibleBody.textContent || "").length >= 80 ? [visibleBody] : [];
    }
    return [];
  }

  function scholarlyRecordAuthors(owner, metadata) {
    var authors = [];
    var authorNodes = Array.prototype.filter.call(owner.querySelectorAll("[itemprop='author'], [rel='author'], .authors"), function(node) {
      return !Array.prototype.some.call(owner.querySelectorAll("[itemprop='author'], [rel='author'], .authors"), function(other) {
        return other !== node && other.contains(node);
      });
    });
    authorNodes.forEach(function(node) {
      if (!scholarlyRecordVisible(node)) return;
      var nameNodes = node.querySelectorAll("[itemprop='name'], [rel='author']");
      var value = nameNodes.length ? Array.prototype.map.call(nameNodes, function(nameNode) {
        return normalizeText(nameNode.textContent || "");
      }).filter(Boolean).join(", ") : normalizeText(node.textContent || "");
      value = value.replace(/^Authors?:\s*/i, "");
      if (value && authors.indexOf(value) === -1) authors.push(value);
    });
    return authors.join(", ") || metadata.byline || "";
  }

  function scholarlyRecordPublishedTime(owner, metadata) {
    var dateNode = Array.prototype.find.call(owner.querySelectorAll(".dateline, [itemprop='datePublished'], time[datetime]"), scholarlyRecordVisible);
    if (!dateNode) return metadata.publishedTime;
    return dateNode.getAttribute("datetime") || normalizeText(dateNode.textContent || "");
  }

  function scholarlyRecordMetadataRoot(owner, abstractNode) {
    var node = abstractNode;
    while (node && node !== owner) {
      if (node.nodeType === 1) {
        if (node.matches("[data-extent='frontmatter'], .article-text")) return node;
        if (node.querySelector("h1, [itemprop='headline']")) return node;
        if (Array.prototype.some.call(node.querySelectorAll("p, div, span"), function(field) {
          return /^(?:published in|doi|publication date|submitted|last revised)\s*:/i.test(normalizeText(field.textContent || ""));
        })) return node;
      }
      node = node.parentElement;
    }
    return owner;
  }
