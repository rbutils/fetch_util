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

function readabilityExcerptSameArticleOwner(node, structuredOwner) {
  return node.closest("article") === structuredOwner.heading.closest("article");
}

function readabilityDistinctArticleOwner(node) {
  var article = node.closest("article");
  return !article.matches("article article") && readabilityExternalArticleBodyOwner(node) !== false;
}

function readabilityOwnedArticleParagraphs(article, bodyEvidence) {
  var sources = bodyEvidence && bodyEvidence.sourceParagraphs;
  if (!Array.isArray(sources)) return null;
  if (sources.some(function(node) { return readabilityExternalArticleBodyOwner(node) === false; })) return null;
  var paragraphs = sources;
  var headings = Array.from(document.querySelectorAll("article h1")).filter(function(heading) {
    return !elementVisuallyHidden(heading) &&
      normalizeText(heading.textContent || "") === normalizeText(article.title || "");
  });
  if (headings.length === 1) {
    var owner = headings[0].closest("article");
    if (!paragraphs.every(function(node) { return node.closest("article") === owner; })) return null;
  }
  return paragraphs;
}

function readabilityExternalArticleBodyOwner(node) {
  var main = node.closest("main, [role='main']");
  if (!main) return null;
  var headings = Array.from(main.querySelectorAll("h1")).filter(function(heading) {
    return !elementVisuallyHidden(heading);
  });
  if (headings.length !== 1 || headings[0].closest("article")) return null;
  var headline = normalizeText(headings[0].textContent || "");
  var title = normalizeText(document.title || "");
  if (title !== headline) {
    var publisher = document.querySelector("meta[property='og:site_name' i]");
    var siteName = normalizeText(publisher && publisher.getAttribute("content"));
    if (!headline || !title.startsWith(headline) ||
        !sourceOwnedTitleSuffixMatchesPublisher(normalizeText(title.slice(headline.length)), siteName)) return null;
  }

  var bodySelector = "[itemprop~='articleBody' i], [data-article-body], [class*='article-body' i], " +
    "[class*='article-content' i], [class*='entry-content' i], [class*='post-content' i], [class*='story-content' i]";
  var bodies = Array.from(main.querySelectorAll(bodySelector)).filter(function(body) {
    if (body.closest("article") || !(headings[0].compareDocumentPosition(body) & Node.DOCUMENT_POSITION_FOLLOWING)) {
      return false;
    }
    return Array.from(body.querySelectorAll("p")).filter(function(paragraph) {
      return !paragraph.closest("article") && readabilityExcerptNode(paragraph);
    }).length >= 2;
  });
  var innermost = bodies.filter(function(body) {
    return !bodies.some(function(other) { return other !== body && body.contains(other); });
  });
  if (innermost.length !== 1) return null;
  var foreignArticle = node.closest("article");
  if (foreignArticle && main.contains(foreignArticle) && !innermost[0].contains(foreignArticle)) return false;
  if (!main.contains(node) || foreignArticle) return null;
  if (innermost[0].contains(node)) return true;
  var section = node.closest("section");
  var separateSection = section && Array.from(section.querySelectorAll("h1, h2, h3")).some(function(heading) {
    return !elementVisuallyHidden(heading);
  });
  if (!(headings[0].compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) ||
      !(node.compareDocumentPosition(innermost[0]) & Node.DOCUMENT_POSITION_FOLLOWING) ||
      node.closest("aside, form") || separateSection) return false;
  return true;
}

function readabilityOwnedArticleLeadExcerpt(article, metadata, marker, bodyEvidence) {
  var paragraphs = readabilityOwnedArticleParagraphs(article, bodyEvidence);
  var sourceEvidence = Array.isArray(paragraphs) && paragraphs.length >= 2;
  var metadataExcerpt = normalizeText(metadata && metadata.excerpt || "");
  var lead = sourceEvidence ? paragraphs[0] : null;
  var publicationAction = sourceEvidence && paragraphs.some(function(paragraph) {
    return normalizeText(paragraph.textContent || "") === normalizeText(article.excerpt || "") &&
      sourceOwnedPublicationField(paragraph);
  });
  if (publicationAction) lead = paragraphs.find(function(paragraph) {
    return !sourceOwnedPublicationField(paragraph);
  });
  publicationAction = publicationAction && readabilityOwnedPublicationActionLead(article, metadata, marker, bodyEvidence, lead);
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
  if (readabilityExcerptLength(value) < 80 && !metadataOwnsLead && !shortLeadHasArticleOwner && !publicationAction) return null;
  if (!excerptContainsLead && !metadataOwnsLead && !publicationAction &&
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

function readabilityForeignMetadataBodyExcerpt(article, metadata, marker, bodyEvidence) {
  var paragraphs = bodyEvidence && bodyEvidence.sourceParagraphs;
  if (!Array.isArray(paragraphs) || paragraphs.length < 2 ||
      (bodyEvidence.unmappedHeaderParagraphs || []).length ||
      (bodyEvidence.unmappedTrailingParagraphs || []).length) return null;
  var proof = sourceOwnedSemanticArticleOwnership(metadata);
  var ownership = proof && proof.ownership;
  if (!ownership || !ownership.titleIdentityProven || !ownership.node ||
      !ownership.node.matches("article") || !ownership.heading ||
      ownership.heading.closest("article") !== ownership.node ||
      normalizeText(ownership.heading.textContent || "") !== normalizeText(article.title || "")) return null;
  var matchingHeadings = Array.from(document.querySelectorAll("article h1")).filter(function(heading) {
    return !elementVisuallyHidden(heading) &&
      normalizeText(heading.textContent || "") === normalizeText(article.title || "");
  });
  if (matchingHeadings.length !== 1 || matchingHeadings[0] !== ownership.heading) return null;
  var owner = ownership.node;
  var template = readabilityArticleTemplate(article);
  if (!template) return null;
  var readerParagraphs = Array.from(template.content.querySelectorAll("p")).filter(function(node) {
    return node.getAttribute("data-fetchutil-excerpt-body") === marker;
  });
  var owned = paragraphs.filter(function(node) {
    return node.closest("article") === owner && readabilityExcerptNode(node) &&
      readabilityBodyExcerptNode(node, null) && !node.querySelector("button, input, select, textarea");
  });
  if (owned.length !== readerParagraphs.length || !owned.every(function(node, index) {
    return normalizeText(node.textContent || "") === normalizeText(readerParagraphs[index].textContent || "");
  })) return null;
  var lead = owned.find(function(node) {
    var value = normalizeText(node.textContent || "");
    return value !== normalizeText(article.excerpt || "") && readabilityExcerptLength(value) >= 80;
  });
  if (lead && Array.from(owner.querySelectorAll("p")).filter(function(node) {
    return normalizeText(node.textContent || "") === normalizeText(lead.textContent || "");
  }).length !== 1) return null;
  return lead ? normalizeText(lead.textContent || "") : null;
}

function readabilityOwnedPublicationActionLead(article, metadata, marker, bodyEvidence, lead) {
  if (!lead || !/\p{Sentence_Terminal}/u.test(lead.textContent || "") || !metadata || !bodyEvidence ||
      (bodyEvidence.unmappedHeaderParagraphs || []).length ||
      (bodyEvidence.unmappedTrailingParagraphs || []).length) return false;
  var proof = sourceOwnedSemanticArticleOwnership(metadata);
  var ownership = proof && proof.ownership;
  if (!ownership || !ownership.titleIdentityProven || !ownership.node ||
      !ownership.node.matches("article") || !ownership.heading ||
      ownership.heading.closest("article") !== ownership.node ||
      normalizeText(ownership.heading.textContent || "") !== normalizeText(article.title || "")) return false;
  var sources = bodyEvidence.sourceParagraphs.filter(function(node) {
    return !sourceOwnedPublicationField(node);
  });
  var publication = bodyEvidence.sourceParagraphs[0];
  if (!sources.length || sources[0] !== lead ||
      !sourceOwnedPublicationField(publication) ||
      normalizeText(publication.textContent || "") !== normalizeText(article.excerpt || "")) return false;
  var template = readabilityArticleTemplate(article);
  if (!template) return false;
  var selected = Array.from(template.content.querySelectorAll("p")).filter(function(node) {
    return node.getAttribute("data-fetchutil-excerpt-body") === marker;
  });
  if (!selected.length || normalizeText(selected[0].textContent || "") !==
      normalizeText(publication.textContent || "")) return false;
  selected.shift();
  return selected.length === sources.length && selected.every(function(node, index) {
    return sources[index].closest("article") === ownership.node && readabilityExcerptNode(sources[index]) &&
      readabilityBodyExcerptNode(sources[index], null) &&
      normalizeText(node.textContent || "") === normalizeText(sources[index].textContent || "");
  });
}
