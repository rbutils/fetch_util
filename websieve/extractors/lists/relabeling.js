  function markdownArticleEntryLinks(markdown) {
    var seen = [];
    var pattern = /\[[^\]]{8,220}\]\(([^\s)]+)\)|https?:\/\/[^\s)]+/g;
    var match;

    while ((match = pattern.exec(String(markdown || "")))) {
      var raw = match[1] || match[0];
      var parsed;

      try {
        parsed = new URL(raw, location.href);
      } catch (_error) {
        continue;
      }

      if (parsed.origin !== location.origin || (parsed.origin + parsed.pathname) === currentListPageUrl()) continue;
      if (!articleEntryPath(parsed.pathname)) continue;
      if (seen.indexOf(parsed.origin + parsed.pathname) === -1) seen.push(parsed.origin + parsed.pathname);
    }

    return seen.length;
  }

  function relabelAsListContent(content, options) {
    if (content && articleRouteFocalContent(content) && !(options && options.strongList)) return content;
    if (content) content.contentType = "list";
    return content;
  }
  function referenceTableArticleMarkdown(markdown) {
    markdown = String(markdown || "");
    var text = normalizeText(markdown);
    if (text.length < 700 || !/^\|\s*[-: ]+\|/m.test(markdown)) return false;
    if ((markdown.match(/^\s*- \[/gm) || []).length >= 3) return false;

    var proseBlocks = markdown.split(/\n{2,}/).filter(function(block) {
      var trimmed = block.trim();
      if (!trimmed || /^\|/.test(trimmed) || /^#/.test(trimmed)) return false;
      return normalizeText(trimmed).length >= 80 && /[.!?)]$/.test(normalizeText(trimmed));
    }).length;
    var tableRows = (markdown.match(/^\|/gm) || []).length;
    var headings = (markdown.match(/^#{1,3}\s+/gm) || []).length;

    return headings >= 1 && proseBlocks >= 2 && tableRows >= 4 && tableRows <= 40;
  }

  function legalJudgmentArticleContent(root, text) {
    text = normalizeText(text || "");
    if (text.length < 5000) return false;

    if (/\bresults?\s+\d+\s*[-–]\s*\d+\s+(?:of|sur|von|de)\s+\d+\b/i.test(text)) return false;
    if (root && root.querySelector("[class*='result' i], [id*='result' i]")) return false;

    var signals = 0;
    if (/\b(?:high court|supreme court|court of appeal|federal court|district court|court of justice|tribunal)\b/i.test(text)) signals += 1;
    if (/\b(?:judg(?:e)?ment|opinion of the court|reasons for judgment|delivered by|per curiam)\b/i.test(text)) signals += 1;
    if (/\b(?:appellant|respondent|plaintiff|defendant|petitioner|counsel|solicitor|amicus|certiorari)\b/i.test(text)) signals += 1;
    if (/\b[A-Z][A-Za-z'.-]+\s+v\.?\s+[A-Z][A-Za-z'.-]+\b/.test(text)) signals += 1;
    if (/\[[12][0-9]{3}\]\s+[A-Z][A-Z0-9.]{1,12}\s+\d+|\([12][0-9]{3}\)\s+\d+\s+[A-Z][A-Z0-9.]{1,12}\s+\d+/i.test(text)) signals += 1;
    if (signals < 3) return false;

    var longBlocks = root ? Array.prototype.filter.call(root.querySelectorAll("p, div, section, article, pre, blockquote"), function(node) {
      return normalizeText(node.textContent || "").length >= 180;
    }).length : 0;
    var sentenceRuns = (text.match(/[.;:]\s+[A-Z][a-z]{2,}/g) || []).length;

    return longBlocks >= 5 || sentenceRuns >= 35 || text.length >= 20000;
  }

  function legalStatuteArticleContent(root, text) {
    text = normalizeText(text || "");
    if (text.length < 5000) return false;

    if (/\bresults?\s+\d+\s*[-–]\s*\d+\s+(?:of|sur|von|de)\s+\d+\b/i.test(text)) return false;
    if (root && root.querySelector("[class*='result' i], [id*='result' i]")) return false;

    var legalContext = legalProvisionContext({
      root: root,
      text: text,
      title: document.title || "",
      path: location.pathname || ""
    });

    if (!legalContext.legalTitle || legalContext.provisionMarkers < 8) return false;

    var longBlocks = root ? Array.prototype.filter.call(root.querySelectorAll("p, div, section, article, td, pre, blockquote"), function(node) {
      return normalizeText(node.textContent || "").length >= 180;
    }).length : 0;

    return legalContext.structuralMarkers >= 3 || legalContext.legalTerms || longBlocks >= 8 || text.length >= 20000;
  }

  function legalTableOfContentsPage(root, text) {
    root = root || document.body;
    text = normalizeText(text || (root && root.textContent) || "");
    if (!root || text.length < 200) return false;

    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    var title = normalizeText([document.title || "", (document.querySelector("h1") || {}).textContent || ""].join(" "));
    var context = normalizeText([path, title, text.slice(0, 1200)].join(" ")).toLowerCase();
    var tocRoute = /\/(?:contents?|table-of-contents|toc)(?:\/)?$/i.test(path);
    var tocRoot = root.querySelector(".LegContents, .LegContentsEntry, [class*='contents' i], [id*='contents' i], [aria-label*='contents' i]");
    var sectionLinks = Array.prototype.filter.call(root.querySelectorAll("a[href]"), function(link) {
      var href = link.getAttribute("href") || "";
      var label = normalizeText(link.textContent || "");
      return /\/(?:section|article|schedule|part|chapter)\/[^\s#?]+/i.test(href) ||
        /\b(?:section|article|schedule|part|chapter)\s+(?:\d+[a-z]?|[ivxlcdm]+)\b/i.test(label);
    }).length;
    var proseBlocks = Array.prototype.filter.call(root.querySelectorAll("p"), function(paragraph) {
      return normalizeText(paragraph.textContent || "").length >= 160;
    }).length;

    if (!tocRoute && !tocRoot && !/\b(?:table of contents|contents|collapse all)\b/i.test(context)) return false;
    if (!/\b(?:act|code|law|regulation|ordinance|statute|legislation|convention|treaty|schedule)\b/i.test(context)) return false;

    return sectionLinks >= 6 && proseBlocks < 4;
  }

  function legalTableOfContentsMarkdown(markdown) {
    var text = normalizeText(markdown || "");
    if (text.length < 200) return false;

    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    var tocRoute = /\/(?:contents?|table-of-contents|toc)(?:\/)?$/i.test(path);
    var linkedItems = (String(markdown || "").match(/^\s*[-*]\s+(?:\[[^\]]+\]\([^)]*\)|(?:\d+[A-Z]?\.|Article\s+\d+|Schedule\s+\d+))/gim) || []).length;
    var proseLines = String(markdown || "").split(/\n+/).filter(function(line) {
      var lineText = normalizeText(line).replace(/^[-*#\s]+/, "");
      return lineText.length >= 160 && !/^\[[^\]]+\]\(/.test(lineText);
    }).length;

    return tocRoute && linkedItems >= 6 && proseLines < 4;
  }

  function strongArticleMetadata(metadata, content) {
    metadata = metadata || {};
    content = content || {};

    var title = normalizeText(content.title || metadata.title || "");
    var excerpt = normalizeText(content.excerpt || metadata.excerpt || "");
    var publishedTime = normalizeText(content.publishedTime || metadata.publishedTime || "");
    var byline = normalizeText(content.byline || metadata.byline || "");
    var text = normalizeText(content.textContent || content.markdown || "");

    if (title.length < minimumListTitleLength(title) || text.length < 220) return false;
    if (publishedTime && excerpt.length >= 40) return true;
    if (publishedTime && byline) return true;
    return !!(publishedTime && text.length >= 320);
  }

  function sourceOwnedListAgainstReader(content, metadata) {
    var browseIndex = content && content.browseIndexContent || sourceOwnedBrowseIndexContent(content, metadata);
    if (browseIndex) return browseIndex;
    if (!document.body || !content || content.contentType !== "article" || !content.readerMode ||
        content.hostAware || articleRouteFocalContent(content) || !isProbablyListPage(content)) return null;

    var readerRoot = document.createElement("div");
    readerRoot.innerHTML = content.html || "";
    if (readerRoot.querySelector("h1, h2, h3, article")) return null;

    var readerText = normalizeText(content.markdown || content.textContent || "");
    var pageHeading = Array.prototype.find.call(document.querySelectorAll("h1"), function(heading) {
      return !elementSubtreeHidden(heading) && normalizeText(heading.textContent || "");
    });
    if (!readerText || !pageHeading) return null;

    var candidate = listContent(metadata);
    var candidateText = normalizeText(candidate.markdown || candidate.textContent || "");
    if (candidateText.length < readerText.length * 2) return null;
    var candidateUrls = new Set((candidate.listExtraction.items || []).map(function(item) { return item.url; }));
    var readerParagraphs = Array.prototype.map.call(readerRoot.querySelectorAll("p, blockquote"), function(paragraph) {
      return normalizeText(paragraph.textContent || "");
    }).filter(function(text) { return text.length >= 80; });

    var completeCollection = Array.prototype.some.call(document.querySelectorAll("ul, ol, [role='list']"), function(list) {
      if (elementSubtreeHidden(list) || list.closest("nav, header, footer, aside, form, [role='navigation'], [role='complementary']")) return false;
      var owner = list.parentElement;
      while (owner && owner !== document.body && !owner.contains(pageHeading)) owner = owner.parentElement;
      if (!owner || owner === document.body || owner.querySelectorAll("h1").length !== 1) return false;
      var ownerText = normalizeText(owner.textContent || "");
      if (readerParagraphs.some(function(text) { return ownerText.indexOf(text) >= 0; })) return false;

      var records = Array.prototype.filter.call(list.children, function(child) {
        return child.matches("li, [role='listitem']") && !elementSubtreeHidden(child) &&
          child.querySelector("h2, h3, h4") && child.querySelector("a[href]");
      });
      if (records.length < 4 || records.filter(function(child) {
        return Array.prototype.some.call(child.querySelectorAll("p"), function(paragraph) {
          return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent || "").length >= 40;
        });
      }).length < records.length / 2) return false;

      var urls = records.map(function(child) {
        return materializedHttpUrl(child.querySelector("a[href]").getAttribute("href"));
      });
      return urls.every(function(url) { return url && candidateUrls.has(url); }) && new Set(urls).size === records.length;
    });
    return completeCollection ? candidate : null;
  }
