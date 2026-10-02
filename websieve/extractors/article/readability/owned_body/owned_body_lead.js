function readabilityExcerptIsVisibleLead(article, excerpt) {
  if (!article || !article.content) return false;

  var template = document.createElement("template");
  template.innerHTML = article.content;
  return Array.from(template.content.querySelectorAll("p")).some(function(paragraph) {
    if (normalizeText(paragraph.textContent || "") !== excerpt) return false;

    var range = document.createRange();
    range.setStart(template.content, 0);
    range.setEndBefore(paragraph);
    var prefix = normalizeText(range.toString());
    return Array.from(prefix).length < 40 && !/\p{Sentence_Terminal}/u.test(prefix);
  });
}

function readabilityOwnedArticleLeadExcerpt(article, metadata, marker, bodyEvidence) {
  var paragraphs = bodyEvidence && bodyEvidence.sourceParagraphs;
  var sourceEvidence = Array.isArray(paragraphs) && paragraphs.length >= 2;
  var metadataExcerpt = normalizeText(metadata && metadata.excerpt || "");
  var lead = sourceEvidence ? paragraphs[0] : null;
  if (sourceEvidence && metadataExcerpt) {
    var describedLead = paragraphs.find(function(paragraph) {
      return readabilityMetadataExcerptOwned(paragraph, metadataExcerpt);
    });
    if (describedLead) lead = describedLead;
  }
  if (!lead) {
    var template = readabilityArticleTemplate(article);
    if (template) {
      lead = Array.from(template.content.querySelectorAll("p")).find(function(paragraph) {
        return paragraph.getAttribute("data-fetchutil-excerpt-body") === marker;
      });
    }
  }
  if (!lead || lead.localName !== "p" || elementVisuallyHidden(lead)) return null;

  var value = normalizeText(lead.textContent || "");
  if (!value) return null;
  if (!sourceEvidence && readabilityExcerptLength(value) < 80) return null;
  var excerpt = normalizeText(article.excerpt || "");
  var sourceLeadFragment = Array.from(value).slice(0, 80).join("");
  var metadataOwnsLead = metadataExcerpt && readabilityMetadataExcerptOwned(lead, metadataExcerpt);
  var excerptContainsLead = sourceLeadFragment.length >= 80 && excerpt.indexOf(sourceLeadFragment) !== -1;
  var shortLeadHasArticleOwner = readabilityExcerptLength(value) < 80 && !metadataOwnsLead &&
    readabilityOwnedShortSourceArticleLead(article, metadata, marker, bodyEvidence, lead);
  var excerptMatchesSourceParagraph = sourceEvidence && paragraphs.some(function(paragraph) {
    return readabilityMetadataExcerptOwned(paragraph, excerpt);
  });

  if (readabilityExcerptLength(value) < 80 && !metadataOwnsLead && !shortLeadHasArticleOwner) return null;
  if (!excerptContainsLead && !metadataOwnsLead &&
      (!shortLeadHasArticleOwner || (excerptMatchesSourceParagraph && excerpt !== value))) return null;

  return value;
}

function readabilityOwnedShortSourceArticleLead(article, metadata, marker, bodyEvidence, lead) {
  var paragraphs = bodyEvidence && bodyEvidence.sourceParagraphs;
  if (!article || !metadata || !Array.isArray(paragraphs) || paragraphs.length < 2 ||
      (bodyEvidence.unmappedTrailingParagraphs || []).length ||
      typeof sourceOwnedSemanticArticleOwnership !== "function") return false;

  var proof = sourceOwnedSemanticArticleOwnership(metadata);
  var ownership = proof && proof.ownership;
  if (!ownership || !ownership.titleIdentityProven || !ownership.node ||
      !ownership.node.matches("article") || !ownership.heading ||
      ownership.heading.closest("article") !== ownership.node || lead.closest("article") !== ownership.node) return false;

  var title = normalizeText(article.title || "");
  var heading = normalizeText(ownership.heading.textContent || "");
  if (!title || !heading || articleTitleFromOwnedHeading(ownership.heading.outerHTML, title, metadata.siteName) !== heading) {
    return false;
  }

  var bodySelector = "[itemprop~='articleBody' i], [data-article-body], [class*='article-body' i], " +
    "[class*='article-content' i], [class*='entry-content' i], [class*='post-content' i], [class*='story-content' i]";
  var bodyRoots = [];
  if (ownership.node.matches(bodySelector)) bodyRoots.push(ownership.node);
  bodyRoots = bodyRoots.concat(Array.from(ownership.node.querySelectorAll(bodySelector)));
  var containingRoots = bodyRoots.filter(function(root) {
    return paragraphs.every(function(paragraph) { return root.contains(paragraph); });
  });
  var bodyRoot = ownership.node;
  if (bodyRoots.length) {
    var innermostRoots = containingRoots.filter(function(root) {
      return !containingRoots.some(function(other) { return other !== root && root.contains(other); });
    });
    if (innermostRoots.length !== 1) return false;
    bodyRoot = innermostRoots[0];
  }

  var excluded = "header, address, nav, footer, aside, form, figure, figcaption, blockquote, time, " +
    "[role='complementary'], [itemprop~='author' i], [itemprop~='creator' i], " +
    "[class*='byline' i], [class*='author' i], [class*='credit' i], [class*='caption' i], " +
    "[class*='related' i], [class*='sidebar' i], [class*='recommend' i], [class*='summary' i], " +
    "[class*='standfirst' i], [class*='excerpt' i]";
  function bodyParagraph(paragraph) {
    return paragraph && paragraph.localName === "p" && bodyRoot.contains(paragraph) &&
      paragraph.closest("article") === ownership.node && !elementVisuallyHidden(paragraph) &&
      !paragraph.closest(excluded) && !paragraph.querySelector("button, input, select, textarea");
  }

  if (!paragraphs.every(bodyParagraph)) return false;
  var sourceBodyParagraphs = Array.from(bodyRoot.querySelectorAll("p")).filter(bodyParagraph);
  if (!sourceBodyParagraphs.length || sourceBodyParagraphs[0] !== lead) return false;
  for (var index = 1; index < paragraphs.length; index += 1) {
    if (!(paragraphs[index - 1].compareDocumentPosition(paragraphs[index]) & Node.DOCUMENT_POSITION_FOLLOWING)) {
      return false;
    }
  }

  var template = readabilityArticleTemplate(article);
  if (!template) return false;
  var markedParagraphs = Array.from(template.content.querySelectorAll("p")).filter(function(paragraph) {
    return paragraph.getAttribute("data-fetchutil-excerpt-body") === marker;
  });
  return markedParagraphs.length === paragraphs.length && markedParagraphs.every(function(paragraph, index) {
    return normalizeText(paragraph.textContent || "") === normalizeText(paragraphs[index].textContent || "");
  });
}
