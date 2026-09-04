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
