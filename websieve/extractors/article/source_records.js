function sourceRecordType(value) {
  var key = sourceRecordLabelKey(value);
  return ["notice", "proposed rule", "rule", "presidential document"].indexOf(key) === -1 ? null : value;
}

function sourceRecordHeaderWitness(main, titleHeading, recordType, agencies, published, body) {
  var typeKey = sourceRecordTextKey(recordType);
  var dateKey = sourceRecordTextKey(published);
  var witnesses = Array.prototype.filter.call(main.querySelectorAll("p"), function(paragraph) {
    if (elementVisuallyHidden(paragraph) || paragraph.closest("nav, aside, footer, [role='navigation'], [role='complementary']")) return false;
    var text = normalizeText(visibleMetadataNodeText(paragraph));
    var match = text.match(/^a\s+(.+?)\s+by\s+(.+?)\s+on\s+(.+)$/i);
    if (!match || sourceRecordTextKey(match[1]) !== typeKey || sourceRecordTextKey(match[3]) !== dateKey) return false;
    var headerAgency = sourceRecordTextKey(match[2]).replace(/^the\s+/, "");
    var agencySection = sourceRecordSectionByLabel(body.sections, "agency");
    var agencySectionText = sourceRecordTextKey(sourceRecordSectionText(agencySection, body.root));
    return agencies.every(function(agency) {
      var key = sourceRecordTextKey(agency).replace(/^the\s+/, "");
      return key && (" " + agencySectionText + " ").indexOf(" " + key + " ") !== -1;
    }) && headerAgency && (" " + agencySectionText + " ").indexOf(" " + headerAgency + " ") !== -1;
  });
  if (witnesses.length !== 1) return null;
  var owner = sourceRecordLowestCommonAncestor([titleHeading, witnesses[0]]);
  if (!owner || owner === main) return null;
  var ownerHeadings = sourceRecordVisibleHeadings(owner).filter(function(heading) {
    return heading.tagName === "H1";
  });
  if (ownerHeadings.length !== 1 || ownerHeadings[0] !== titleHeading) return null;
  return { node: witnesses[0], owner: owner };
}

function sourceRecordAgencyMatch(section, root, agencies) {
  var text = sourceRecordTextKey(sourceRecordSectionText(section, root));
  return agencies.length > 0 && agencies.every(function(agency) {
    var key = sourceRecordTextKey(agency);
    return key && (" " + text + " ").indexOf(" " + key + " ") !== -1;
  });
}

function sourceRecordAgencyHeadings(main, record) {
  var headings = sourceRecordVisibleHeadings(main);
  var selected = [];
  for (var index = 0; index < record.agencies.length; index += 1) {
    var agencyKey = sourceRecordTextKey(record.agencies[index]);
    var matches = headings.filter(function(heading) {
      return heading.tagName === "H6" && sourceRecordTextKey(visibleMetadataNodeText(heading)) === agencyKey;
    });
    if (matches.length > 1) return null;
    if (matches.length === 1 && !record.root.contains(matches[0])) {
      if (!sourceRecordBefore(matches[0], record.formalSections[0].heading) ||
          !record.root.parentElement || !record.root.parentElement.contains(matches[0])) return null;
      selected.push(matches[0]);
    }
  }
  return selected;
}

function sourceRecordGroupCandidate(group) {
  var typeValue = sourceRecordUniqueField(group, ["document type"]);
  var agencies = sourceRecordFieldValues(group, ["agency", "agencies"]);
  var published = sourceRecordUniqueField(group, ["published", "publication date"]);
  if (!typeValue || !sourceRecordType(typeValue) || !agencies.length || !published) return null;
  var type = sourceRecordType(typeValue);
  var number = sourceRecordUniqueField(group, ["document number"]);
  var citation = sourceRecordUniqueField(group, ["document citation"]);
  return {
    group: group,
    recordType: type,
    agencies: agencies,
    publishedTime: published,
    number: number,
    citation: citation,
    hasIdentifier: !!(number || citation)
  };
}

function sourceRecordCandidateKey(candidate) {
  return JSON.stringify([
    sourceRecordTextKey(candidate.recordType),
    candidate.agencies.map(sourceRecordTextKey).sort(),
    sourceRecordTextKey(candidate.publishedTime),
    sourceRecordTextKey(candidate.number),
    sourceRecordTextKey(candidate.citation)
  ]);
}

function sourceRecordFormalBody(main, candidate) {
  var formal = sourceRecordFormalSections(main);
  if (!formal) return null;
  var agencySection = sourceRecordSectionByLabel(formal.sections, "agency");
  var summarySection = sourceRecordSectionByLabel(formal.sections, "summary");
  var agencyText = sourceRecordSectionText(agencySection, formal.root);
  var actionText = sourceRecordSectionText(sourceRecordSectionByLabel(formal.sections, "action"), formal.root);
  var summaryText = sourceRecordSectionText(summarySection, formal.root);
  var datesText = sourceRecordSectionText(sourceRecordSectionByLabel(formal.sections, "dates"), formal.root);
  if (!agencyText || !actionText || !summaryText || !datesText) return null;
  if (!sourceRecordAgencyMatch(agencySection, formal.root, candidate.agencies)) return null;
  var summaryParagraph = sourceRecordSummaryParagraph(summarySection, formal.root);
  if (!summaryParagraph) return null;
  return {
    root: formal.root,
    sections: formal.sections,
    summaryParagraph: summaryParagraph
  };
}

function sourceRecordHasCompetingArticle(main, root) {
  return Array.prototype.some.call(main.querySelectorAll("article"), function(article) {
    if (elementVisuallyHidden(article) || root.contains(article) || article.contains(root)) return false;
    var headings = sourceRecordVisibleHeadings(article).filter(function(heading) {
      return heading.tagName === "H1";
    });
    return headings.length > 0 && normalizeText(visibleMetadataNodeText(article)).length >= 120;
  });
}

function sourceRecordCandidate(main, metadata, candidate, candidates) {
  var competing = candidates.some(function(other) {
    return sourceRecordCandidateKey(other) !== sourceRecordCandidateKey(candidate);
  });
  if (competing) return null;
  if (candidate.hasIdentifier && (!candidate.number || !candidate.citation ||
      !sourceRecordCanonicalIdentity(metadata, candidate.number))) return null;
  if (!candidate.hasIdentifier && candidates.length !== 1) return null;
  if (candidate.number && !/^\d{4}-\d{4,}$/.test(candidate.number)) return null;

  var matchingTitles = sourceRecordVisibleHeadings(main).filter(function(heading) {
    return heading.tagName === "H1" && sourceRecordTitleMatches(visibleMetadataNodeText(heading), metadata.title);
  });
  if (matchingTitles.length !== 1) return null;
  var titleHeading = matchingTitles[0];
  var body = sourceRecordFormalBody(main, candidate);
  if (!body || sourceRecordHasCompetingArticle(main, body.root)) return null;
  var header = sourceRecordHeaderWitness(main, titleHeading, candidate.recordType, candidate.agencies, candidate.publishedTime, body);
  if (!header) return null;
  var recordContainer = sourceRecordLowestCommonAncestor([titleHeading, header.node, body.root]);
  if (!recordContainer || !main.contains(recordContainer) ||
      recordContainer.matches("nav, aside, footer, [role='navigation'], [role='complementary']")) return null;

  var markers = [];
  if (candidate.number) {
    markers = sourceRecordMarkerNodes(main, candidate.number);
    if (markers.length !== 1) return null;
  }
  var record = {
    root: body.root,
    recordContainer: recordContainer,
    agencies: candidate.agencies,
    title: metadata.title,
    sourceHeadline: normalizeText(visibleMetadataNodeText(titleHeading)),
    byline: candidate.agencies.join("; "),
    publishedTime: candidate.publishedTime,
    contentType: "notice",
    recordType: candidate.recordType,
    documentNumber: candidate.number,
    documentCitation: candidate.citation,
    summaryParagraph: body.summaryParagraph,
    excerpt: normalizeText(visibleMetadataNodeText(body.summaryParagraph)),
    headerOwner: header.owner,
    headerNode: header.node,
    metadataGroup: candidate.group,
    formalSections: body.sections,
    documentMarker: markers[0] || null,
    main: main,
    hasIdentifier: candidate.hasIdentifier
  };
  record.agencyHeadings = sourceRecordAgencyHeadings(main, record);
  return record.agencyHeadings ? record : null;
}

function structuredSourceRecordOwnership(metadata) {
  if (!metadata || !metadata.title) return null;
  var main = sourceRecordVisibleMain();
  if (!main) return null;
  var groups = visibleLabeledMetadataGroups(main).filter(function(group) {
    return !group.list.closest("aside, [role='complementary'], [aria-label*='sidebar' i], [class*='sidebar' i]");
  });
  var candidates = groups.map(sourceRecordGroupCandidate).filter(Boolean);
  if (!candidates.length) return null;

  var recordGroups = groups.filter(function(group) {
    return group.fields.some(function(field) {
      return ["agency", "agencies", "document type", "published", "publication date"].indexOf(
        sourceRecordLabelKey(field.label)
      ) !== -1;
    });
  });
  var candidateLists = candidates.map(function(candidate) { return candidate.group.list; });
  if (recordGroups.some(function(group) { return candidateLists.indexOf(group.list) === -1; })) return null;
  if (candidates.some(function(candidate) {
    return sourceRecordCandidateKey(candidate) !== sourceRecordCandidateKey(candidates[0]);
  })) return null;

  return sourceRecordCandidate(main, metadata, candidates[0], candidates);
}

function sourceOwnedRecordResources(record) {
  if (!record || !record.hasIdentifier || !record.documentNumber) return [];
  var number = record.documentNumber;
  var numberPattern = new RegExp("\\b" + number.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\b");
  var markerPattern = new RegExp("\\bFR\\s+(?:Doc\\.?\\s*)?" + number.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\b", "i");
  return Array.prototype.filter.call(record.main.querySelectorAll("a[href]"), function(link) {
    if (elementVisuallyHidden(link)) return false;
    var href = materializedHttpUrl(link.getAttribute("href"));
    if (!href || !/\.pdf(?:$|[?#])/i.test(href)) return false;
    var path = "";
    try { path = new URL(href).pathname.split("/").pop() || ""; } catch (e) { return false; }
    if (!numberPattern.test(path)) return false;

    var label = sourceRecordTextKey(visibleMetadataNodeText(link));
    var printedVersion = /^view (?:the )?printed version pdf$/.test(label);
    for (var current = link.parentElement; current && current !== record.main; current = current.parentElement) {
      var context = sourceRecordTextKey(visibleMetadataNodeText(current));
      if (markerPattern.test(context)) return true;
      if (printedVersion && /official content/.test(context)) return true;
    }
    return false;
  }).map(function(link) {
    return { href: materializedHttpUrl(link.getAttribute("href")), text: normalizeText(visibleMetadataNodeText(link)) };
  });
}

function sourceRecordIdentityMetadata(record) {
  if (!record || !record.documentNumber || !record.documentCitation) return null;
  var metadata = document.createElement("dl");
  metadata.setAttribute("data-fetchutil-source-record-identity", "true");
  [
    { label: "Document Citation", value: record.documentCitation },
    { label: "Document Number", value: record.documentNumber }
  ].forEach(function(field) {
    var label = document.createElement("dt");
    var value = document.createElement("dd");
    label.textContent = field.label;
    value.textContent = field.value;
    metadata.appendChild(label);
    metadata.appendChild(value);
  });
  return metadata;
}

function sourceRecordFallbackContent(metadata, record) {
  if (!record) return null;
  var discussion = sourceRecordHasVisibleDiscussion(record) ? sourceRecordDiscussionMarkup(record) : "";
  if (discussion === null) return null;
  var resources = sourceOwnedRecordResources(record);
  var identityMetadata = sourceRecordIdentityMetadata(record);
  return profileHtmlContent(metadata, record.root, {
    title: record.sourceHeadline,
    prependTitle: false,
    contentType: "notice",
    byline: record.byline,
    publishedTime: record.publishedTime,
    excerpt: record.excerpt,
    rewriteRoot: function(root) {
      var headline = document.createElement("h1");
      headline.textContent = record.sourceHeadline;
      root.insertBefore(headline, root.firstChild);
      var header = cleanClone(record.headerNode);
      header.removeAttribute("class");
      header.setAttribute("data-fetchutil-source-record-header", "true");
      root.insertBefore(header, headline.nextSibling);
      var afterHeader = header.nextSibling;
      if (identityMetadata) {
        root.insertBefore(identityMetadata, afterHeader);
        afterHeader = identityMetadata.nextSibling;
      }
      record.agencyHeadings.forEach(function(heading) {
        var clone = cleanClone(heading);
        root.insertBefore(clone, afterHeader);
        afterHeader = clone.nextSibling;
      });
      resources.forEach(function(resource) {
        var paragraph = document.createElement("p");
        var link = document.createElement("a");
        link.href = resource.href;
        link.textContent = resource.text;
        paragraph.appendChild(link);
        root.appendChild(paragraph);
      });
      if (discussion) root.insertAdjacentHTML("beforeend", discussion);
    }
  });
}
