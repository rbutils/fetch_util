function asArray(value) {
  if (!value) return [];
  return Array.isArray(value) ? value : [value];
}

function mergeStructuredDataTypes(current, incoming) {
  var types = [];
  asArray(current).concat(asArray(incoming)).forEach(function(type) {
    if (types.indexOf(type) === -1) types.push(type);
  });
  return types.length === 1 ? types[0] : types;
}

function structuredDataArrayValueKey(value) {
  if (value && typeof value === "object" && !Array.isArray(value) && value["@id"]) {
    return "id:" + structuredDataIdentityKey(value["@id"]);
  }

  try {
    return typeof value + ":" + JSON.stringify(value);
  } catch (_error) {
    return null;
  }
}

function mergeStructuredDataArrays(current, incoming) {
  var merged = current.slice();
  var currentIndexes = Object.create(null);
  merged.forEach(function(value, index) {
    var key = structuredDataArrayValueKey(value);
    if (key != null && currentIndexes[key] == null) currentIndexes[key] = index;
  });

  incoming.forEach(function(value) {
    var key = structuredDataArrayValueKey(value);
    var index = key == null ? null : currentIndexes[key];
    if (index == null) {
      merged.push(value);
      return;
    }

    var existing = merged[index];
    if (existing && value && typeof existing === "object" && typeof value === "object" &&
        !Array.isArray(existing) && !Array.isArray(value) && existing["@id"] && value["@id"]) {
      merged[index] = mergeStructuredDataEntity(existing, value);
    }
  });
  return merged;
}

function mergeStructuredDataEntity(target, source) {
  Object.keys(source).forEach(function(key) {
    var incoming = source[key];
    if (key === "@type" && target[key]) {
      target[key] = mergeStructuredDataTypes(target[key], incoming);
    } else if (Object.prototype.hasOwnProperty.call(target, key) &&
               (Array.isArray(incoming) || Array.isArray(target[key]))) {
      target[key] = mergeStructuredDataArrays(asArray(target[key]), asArray(incoming));
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

function structuredDataValueHasMaterial(value) {
  if (value == null) return false;
  if (typeof value === "string") return !!normalizeText(value);
  if (Array.isArray(value)) return value.some(structuredDataValueHasMaterial);
  if (typeof value === "object") return Object.keys(value).some(function(key) {
    return key !== "@context" && key !== "@id" && key !== "@type" && structuredDataValueHasMaterial(value[key]);
  });
  return true;
}

function structuredDataEntityHasProperties(node) {
  return structuredDataValueHasMaterial(node);
}

function structuredDataIdentityKey(id) {
  if (typeof id !== "string" || !normalizeText(id)) return id;

  try {
    var current = new URL(location.href);
    var resolved = new URL(id, current);
    if (resolved.origin === current.origin && resolved.pathname === current.pathname && resolved.search === current.search) {
      return resolved.href;
    }
  } catch (_error) {
  }

  return id;
}

function structuredDataNodeId(node) {
  return node && node["@id"];
}

function nodeTypes(node) {
  return asArray(node && node["@type"]).map(function(type) {
    return String(type);
  });
}

function sourceOwnedPagePublicationTime(metadata) {
  var pages = structuredDataNodes().filter(function(node) {
    return nodeTypes(node).indexOf("WebPage") !== -1;
  });
  if (pages.length !== 1 || typeof pages[0].url !== "string") return null;
  var name = normalizeText(entityText(pages[0].name));
  if (name && name !== normalizeText(document.title) && name !== normalizeText(metadata && metadata.title)) return null;
  var mains = Array.from(document.querySelectorAll("main, [role='main']")).filter(function(node) {
    return !elementSubtreeHidden(node);
  });
  if (mains.length !== 1) return null;
  var headings = Array.from(mains[0].querySelectorAll("h1")).filter(function(node) {
    return !elementSubtreeHidden(node) && !node.closest("aside, nav, footer, [role='complementary'], [role='navigation']");
  });
  if (headings.length !== 1) return null;
  var value = materializedHttpUrl(pages[0].url);
  if (!value) return null;
  var page = new URL(value);
  var current = new URL(location.href);
  var canonical = new URL(metadata && metadata.canonicalUrl || location.href);
  if (page.origin !== current.origin || canonical.origin !== current.origin) return null;
  page.hash = current.hash = canonical.hash = "";
  if (page.href !== current.href && page.href !== canonical.href) return null;
  var published = entityText(pages[0].datePublished);
  if (!/^\d{4}-\d{2}-\d{2}(?:T[^\s]+)?$/.test(published) || !Number.isFinite(Date.parse(published))) return null;
  return published;
}
