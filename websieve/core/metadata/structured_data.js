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

function pageStructuredDataOwner(node) {
  return nodeTypes(node).some(function(type) {
    return type === "WebPage" || type === "ProfilePage";
  });
}

function mergeStructuredDataTypes(current, incoming) {
  var types = [];
  asArray(current).concat(asArray(incoming)).forEach(function(type) {
    if (types.indexOf(type) === -1) types.push(type);
  });
  return types.length === 1 ? types[0] : types;
}

function mergeStructuredDataEntity(target, source) {
  Object.keys(source).forEach(function(key) {
    var incoming = source[key];
    if (key === "@type" && target[key]) {
      target[key] = mergeStructuredDataTypes(target[key], incoming);
    } else if (incoming && typeof incoming === "object" && !Array.isArray(incoming)) {
      var current = target[key] && typeof target[key] === "object" && !Array.isArray(target[key]) ? target[key] : Object.create(null);
      var differentIds = current["@id"] && incoming["@id"] && current["@id"] !== incoming["@id"];
      target[key] = mergeStructuredDataEntity(differentIds ? Object.create(null) : current, incoming);
    } else {
      target[key] = Array.isArray(incoming) ? incoming.slice() : incoming;
    }
  });
  return target;
}

function structuredDataEntityHasProperties(node) {
  return Object.keys(node).some(function(key) {
    return key !== "@context" && key !== "@id" && key !== "@type" && node[key] != null;
  });
}

function pageOwnedStructuredDataNodes(nodes) {
  var ownedIds = Object.create(null);
  var ownedEntities = [];

  nodes.forEach(function(node) {
    if (!pageStructuredDataOwner(node)) return;

    asArray(node.mainEntity).forEach(function(entity) {
      var id = typeof entity === "string" ? entity : entity && entity["@id"];
      if (id) ownedIds[id] = true;
      if (entity && typeof entity === "object") ownedEntities.push(entity);
    });
  });

  var mergedById = Object.create(null);
  nodes.concat(ownedEntities).forEach(function(node) {
    var id = node && node["@id"];
    if (!id || !ownedIds[id]) return;
    mergedById[id] = mergeStructuredDataEntity(mergedById[id] || Object.create(null), node);
  });

  var emittedIds = Object.create(null);
  var expanded = [];

  function appendNode(node) {
    if (!node || typeof node !== "object") return;

    var id = node["@id"];
    if (id && ownedIds[id]) {
      node = mergedById[id];
      if (emittedIds[id] || !structuredDataEntityHasProperties(node)) return;
      emittedIds[id] = true;
    }
    if (expanded.indexOf(node) === -1) expanded.push(node);
  }

  nodes.forEach(function(node) {
    if (pageStructuredDataOwner(node)) {
      asArray(node.mainEntity).forEach(function(entity) {
        var id = typeof entity === "string" ? entity : entity && entity["@id"];
        appendNode(id ? mergedById[id] : entity);
      });
    }
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
      var scriptNodes = [];
      flattenStructuredData(JSON.parse(text), scriptNodes);
      pageOwnedStructuredDataNodes(scriptNodes).forEach(function(node) {
        nodes.push(node);
      });
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
