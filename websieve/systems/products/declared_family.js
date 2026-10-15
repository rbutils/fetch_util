function productIdentityKey(value) {
  return normalizeText(value).toLowerCase().replace(/&(?:reg|trade|amp);/g, "").replace(/[^\p{L}\p{N}]/gu, "");
}

function currentProductDeclaration(node) {
  var identity = node.url || (node.mainEntityOfPage && (node.mainEntityOfPage["@id"] || node.mainEntityOfPage)) || node["@id"];
  return !identity || pageStructuredDataDocumentKeys().indexOf(structuredDataDocumentKey(identity)) !== -1;
}

function declaredProductFaqNodes() {
  var nodes = [];
  Array.from(document.querySelectorAll('script[type="application/ld+json"]')).forEach(function(script) {
    try {
      flattenStructuredData(JSON.parse(script.textContent), nodes);
    } catch (_error) {
    }
  });
  return nodes.filter(function(node) {
    return nodeTypes(node).indexOf("FAQPage") !== -1 && currentProductDeclaration(node);
  });
}

function productDeclaredDescription(name, metadata) {
  var description = normalizeText(metadata && metadata.declaredDescription || "");
  if (!description) return null;
  var escapedName = normalizeText(name).replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s+");
  if (!escapedName || !new RegExp("(^|[^\\p{L}\\p{N}])" + escapedName + "(?=$|[^\\p{L}\\p{N}])", "iu").test(description)) return null;
  var declarations = Array.from(document.head.querySelectorAll("meta[name='description' i], meta[property='og:description' i]")).map(function(node) {
    return normalizeText(node.getAttribute("content"));
  }).filter(Boolean);
  if (!declarations.length || declarations.some(function(value) { return value !== description; })) return null;
  return description;
}

function declaredProductFamily(metadata) {
  var families = structuredDataNodes().filter(function(node) {
    return nodeTypes(node).some(function(type) { return type === "ProductGroup" || type === "Product" || type === "Car"; }) &&
      node.name && asArray(node.hasVariant).length && currentProductDeclaration(node);
  });
  if (!families.length) return null;

  var family = families[0];
  var name = productIdentityKey(family.name);
  var topic = productIdentityKey(family.model || String(family.name).replace(/^\d{4}\s+/, ""));
  var titles = [document.title, metadata.title, metadata.ogTitle].filter(Boolean);
  if (!name || !topic || titles.some(function(title) { return productIdentityKey(title).indexOf(topic) === -1; })) return null;
  if (families.some(function(node) {
    return productIdentityKey(node.name) !== name ||
      productIdentityKey(node.model || String(node.name).replace(/^\d{4}\s+/, "")) !== topic;
  })) return null;

  var variants = [];
  families.forEach(function(node) {
    asArray(node.hasVariant).forEach(function(variant) {
      if (!variant || typeof variant !== "object" || !variant.name) return;
      var label = normalizeText(String(variant.vehicleConfiguration || variant.name).replace(/^\d{4}\s+/, ""));
      if (variants.indexOf(label) === -1) variants.push(label);
    });
  });
  if (!variants.length) return null;

  var faqs = declaredProductFaqNodes();
  var questions = [];
  faqs.forEach(function(faq) {
    asArray(faq.mainEntity).forEach(function(question) {
      if (!question || nodeTypes(question).indexOf("Question") === -1 || !question.name) return;
      var name = normalizeText(question.name);
      if (questions.indexOf(name) === -1) questions.push(name);
    });
  });
  return questions.length ? {
    name: name,
    topic: topic,
    variants: variants,
    questions: questions,
    description: productDeclaredDescription(family.name, metadata)
  } : null;
}
