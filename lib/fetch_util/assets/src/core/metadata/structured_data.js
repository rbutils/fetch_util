function asArray(value) {
  if (!value) return [];
  return Array.isArray(value) ? value : [value];
}

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

  return nodes;
}

function nodeTypes(node) {
  return asArray(node && node["@type"]).map(function(type) {
    return String(type);
  });
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

function definitionReferenceMetadataScore(metadata) {
  var text = normalizeText([
    metadata && metadata.title,
    metadata && metadata.excerpt,
    metadata && metadata.siteName,
    metadataValue("og:type", "property")
  ].join(" ")).toLowerCase();
  var score = 0;

  if (/\b(dictionary|glossary|lexicon|thesaurus|encyclopedia|database)\b/.test(text)) score += 3;
  if (/\b(definition|definitions|meaning|pronunciation|part of speech|citation|reference)\b/.test(text)) score += 2;
  if (/\b(website|article)\b/.test(text) && /\b(dictionary|glossary|definition|definitions|database)\b/.test(text)) score += 1;

  structuredDataNodes().some(function(node) {
    var types = nodeTypes(node).join(" ").toLowerCase();
    if (/definedterm|dictionary|glossary|creativework|article/.test(types) && /\b(definition|term|description|citation)\b/.test(text + " " + types)) {
      score += 2;
      return true;
    }
    return false;
  });

  return score;
}
