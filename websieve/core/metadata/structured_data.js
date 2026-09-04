function flattenStructuredData(value, nodes) {
  if (!value) return;
  if (Array.isArray(value)) {
    value.forEach(function(item) {
      flattenStructuredData(item, nodes);
    });
    return;
  }
  if (typeof value !== "object") return;

  if (value["@graph"]) flattenStructuredData(value["@graph"], nodes);
  nodes.push(value);
}

function structuredDataDocumentKey(value) {
  if (typeof value !== "string" || !normalizeText(value)) return null;

  try {
    var resolved = new URL(value, document.baseURI);
    return resolved.origin + resolved.pathname + resolved.search;
  } catch (_error) {
    return null;
  }
}

function pageStructuredDataDocumentKeys() {
  return [location.href, materializedCanonicalUrl()].map(structuredDataDocumentKey).filter(Boolean);
}

function structuredDataFocalRecord(node) {
  var focalTypes = [
    "Article", "NewsArticle", "BlogPosting", "ReportageNewsArticle", "AnalysisNewsArticle",
    "OpinionNewsArticle", "LiveBlogPosting", "Product", "Book", "Recipe", "Event", "MusicEvent",
    "SportsEvent", "TheaterEvent", "Festival", "JobPosting", "MedicalWebPage", "Dataset", "DataCatalog",
    "VideoObject", "Clip", "Movie", "TVEpisode", "TVSeries", "TVSeason", "DiscussionForumPosting",
    "SocialMediaPosting"
  ];
  return nodeTypes(node).some(function(type) { return focalTypes.indexOf(type) !== -1; });
}

function anonymousPageStructuredDataOwner(node, nodes) {
  var mainEntityIds = asArray(node.mainEntity).map(function(entity) {
    var id = typeof entity === "string" ? entity : structuredDataNodeId(entity);
    return structuredDataIdentityKey(id);
  }).filter(Boolean);
  var resolvedFocalEntity = (nodes || []).some(function(candidate) {
    if (!structuredDataFocalRecord(candidate)) return false;

    var id = structuredDataIdentityKey(structuredDataNodeId(candidate));
    return id && mainEntityIds.indexOf(id) !== -1;
  });
  if (resolvedFocalEntity) return true;

  return !(nodes || []).some(function(candidate) {
    if (candidate === node || !structuredDataFocalRecord(candidate)) return false;

    var id = structuredDataIdentityKey(structuredDataNodeId(candidate));
    return !id || mainEntityIds.indexOf(id) === -1;
  });
}

function pageStructuredDataOwner(node, documentKeys, nodes) {
  var pageType = nodeTypes(node).some(function(type) {
    return type === "WebPage" || type === "ProfilePage";
  });
  if (!pageType) return false;

  var identity = structuredDataNodeId(node) || node.url;
  if (identity) return documentKeys.indexOf(structuredDataDocumentKey(identity)) !== -1;

  return anonymousPageStructuredDataOwner(node, nodes);
}

function pageOwnedStructuredDataNodes(nodes) {
  var ownedIds = Object.create(null);
  var ownedEntities = [];
  var documentKeys = pageStructuredDataDocumentKeys();

  nodes.forEach(function(node) {
    if (!pageStructuredDataOwner(node, documentKeys, nodes)) return;

    asArray(node.mainEntity).forEach(function(entity) {
      var id = typeof entity === "string" ? entity : entity && entity["@id"];
      if (id) ownedIds[structuredDataIdentityKey(id)] = true;
      if (entity && typeof entity === "object") ownedEntities.push(entity);
    });
  });

  var mergedById = Object.create(null);
  nodes.concat(ownedEntities).forEach(function(node) {
    var id = structuredDataIdentityKey(structuredDataNodeId(node));
    if (!id || !ownedIds[id]) return;
    mergedById[id] = mergeStructuredDataEntity(mergedById[id] || Object.create(null), node);
  });

  var emittedIds = Object.create(null);
  var expanded = [];

  function appendNode(node) {
    if (!node || typeof node !== "object") return;

    var id = structuredDataIdentityKey(structuredDataNodeId(node));
    if (id && ownedIds[id]) {
      node = mergedById[id];
      if (emittedIds[id] || !structuredDataEntityHasProperties(node)) return;
      emittedIds[id] = true;
    }
    if (expanded.indexOf(node) === -1) expanded.push(node);
  }

  nodes.forEach(function(node) {
    if (pageStructuredDataOwner(node, documentKeys, nodes)) {
      asArray(node.mainEntity).forEach(function(entity) {
        var id = typeof entity === "string" ? entity : entity && entity["@id"];
        appendNode(id ? mergedById[structuredDataIdentityKey(id)] : entity);
      });
    }
  });

  expanded = expanded.filter(structuredDataEntityHasProperties);
  if (expanded.length) return expanded;

  nodes.forEach(function(node) {
    appendNode(node);
  });

  return expanded;
}

function structuredDataNodes() {
  var nodes = [];

  document.querySelectorAll('script[type="application/ld+json"]').forEach(function(script) {
    var text = script.textContent || script.innerText || "";
    if (!normalizeText(text)) return;

    try {
      flattenStructuredData(JSON.parse(text), nodes);
    } catch (_error) {
    }
  });

  return pageOwnedStructuredDataNodes(nodes);
}

function structuredDataNode(typeNames) {
  var wanted = asArray(typeNames);

  return structuredDataNodes().find(function(node) {
    return nodeTypes(node).some(function(type) {
      return wanted.indexOf(type) !== -1;
    });
  }) || null;
}

function structuredDataNodeMatchingType(predicate) {
  return structuredDataNodes().find(function(node) {
    return nodeTypes(node).some(predicate);
  }) || null;
}

function entityName(value) {
  if (!value) return null;
  if (typeof value === "string") return normalizeText(value);
  if (Array.isArray(value)) return entityName(value[0]);
  return normalizeText(value.name || value.headline || value.alternateName || "");
}

function entityText(value) {
  if (!value) return null;
  if (typeof value === "string") return normalizeText(value);
  if (Array.isArray(value)) {
    return normalizeText(value.map(function(item) {
      return entityText(item) || "";
    }).join(" "));
  }
  return normalizeText(value.text || value.description || value.name || "");
}

function structuredDescriptionMarkdown(value) {
  var text = typeof value === "string" ? value : entityText(value);
  if (!normalizeText(text)) return null;

  if (/<[a-z][\s\S]*>/i.test(text) && typeof markdownFor === "function") {
    var root = document.createElement("div");
    root.innerHTML = text;
    return cleanupMarkdownNoise(markdownFor(root.innerHTML));
  }

  return cleanupMarkdownNoise(text);
}

function structuredPostalAddressText(value) {
  if (!value) return null;
  if (typeof value === "string") return normalizeText(value);
  if (Array.isArray(value)) {
    return normalizeText(value.map(structuredPostalAddressText).filter(Boolean).join("; "));
  }
  if (typeof value !== "object") return null;

  var address = value.address || value;
  if (typeof address === "string") return normalizeText(address);

  return normalizeText([
    address.streetAddress,
    address.addressLocality,
    address.addressRegion,
    address.postalCode,
    address.addressCountry && entityText(address.addressCountry)
  ].filter(Boolean).join(", ")) || entityText(value);
}
