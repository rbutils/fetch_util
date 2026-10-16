function softwareApplicationNode(node) {
  return nodeTypes(node).some(function(type) {
    return /^(?:SoftwareApplication|WebApplication|MobileApplication)$/i.test(type);
  });
}

function softwareLandingTitleAgrees(value, name) {
  var title = normalizeText(value || "").toLowerCase();
  return title === name || (title.indexOf(name) === 0 && /^[\s|:–—-]/.test(title.substring(name.length)));
}

function declaredSoftwareLanding(metadata) {
  var nodes = structuredDataNodes();
  var applications = nodes.filter(softwareApplicationNode);
  if (applications.length !== 1 || nodes.some(function(node) {
    return !softwareApplicationNode(node) && structuredDataFocalRecord(node);
  })) return null;
  var application = applications[0];
  var name = normalizeText(entityText(application.name)).toLowerCase();
  var current = structuredDataDocumentKey(location.href);
  if (!name || !application.url || structuredDataDocumentKey(application.url) !== current) return null;
  var page = application.mainEntityOfPage;
  if (page && typeof page === "object") page = page.url || page["@id"];
  if (page && structuredDataDocumentKey(page) !== current) return null;
  var types = Array.from(document.head.querySelectorAll("meta[property='og:type' i]"));
  var urls = Array.from(document.head.querySelectorAll("meta[property='og:url' i]"));
  var titles = Array.from(document.head.querySelectorAll("meta[property='og:title' i]")).map(function(node) {
    return node.getAttribute("content");
  });
  if (!types.length || types.some(function(node) { return normalizeText(node.content).toLowerCase() !== "website"; }) ||
      !urls.length || urls.some(function(node) { return structuredDataDocumentKey(node.content) !== current; }) ||
      !titles.length || titles.concat([document.title, metadata.title]).some(function(title) {
        return !softwareLandingTitleAgrees(title, name);
      }) || Array.from(document.head.querySelectorAll("link[rel~='canonical' i]")).some(function(node) {
        return structuredDataDocumentKey(node.getAttribute("href")) !== current;
      })) return null;
  var offers = asArray(application.offers);
  var plans = offers.map(function(offer) {
    return offer && typeof offer === "object" ? normalizeText(entityText(offer.name)).toLowerCase() : "";
  });
  if (!plans.length || plans.some(function(plan) { return !plan; })) return null;
  plans = plans.filter(function(plan, index) { return plans.indexOf(plan) === index; });
  return plans.length >= 2 ? { name: name, plans: plans, title: normalizeText(titles[0]) } : null;
}

function softwareLandingPhysicalName(root, name) {
  return Array.from(root.querySelectorAll("h1, [itemprop~='name'], img[alt], svg[aria-label], [role='img'][aria-label]")).some(function(node) {
    var label = node.matches("img") ? node.getAttribute("alt") : node.getAttribute("aria-label") || node.textContent;
    return normalizeText(label).toLowerCase() === name && !elementVisuallyHidden(node);
  });
}

function softwareLandingPhysicalPlans(root, plans) {
  var found = new Set();
  Array.from(root.querySelectorAll("h1, h2, h3, h4, h5, h6, dt, th, legend, button, p, span, strong, b, div")).forEach(function(node) {
    var label = normalizeText(node.textContent || "").toLowerCase();
    if (plans.indexOf(label) !== -1 && !elementVisuallyHidden(node)) found.add(label);
  });
  return plans.every(function(plan) { return found.has(plan); });
}

function softwareLandingOutsideMaterial(root) {
  return Array.from(document.body.childNodes).some(function(node) {
    if (node === root || node.nodeType === 8) return false;
    if (node.nodeType === 3) return !!normalizeText(node.nodeValue || "");
    if (node.nodeType !== 1 || node.matches("script, style, noscript, template, meta, link") || elementSubtreeHidden(node)) return false;
    var clone = visibilityPrunedClone(node, document);
    if (!clone) return false;
    removeAll(clone, "script, style, noscript, template, meta, link");
    return !!normalizeText(clone.textContent || "") ||
      !!clone.querySelector("a[href], img, picture, video, audio, iframe, object, embed, pre, code, table");
  });
}

function sourceOwnedSoftwareLandingContext(metadata) {
  var declared = declaredSoftwareLanding(metadata);
  if (!declared || !document.body) return null;
  var headings = Array.from(document.body.querySelectorAll("h1, h2, h3, h4, h5, h6")).filter(function(node) {
    return normalizeText(node.textContent || "") && !elementVisuallyHidden(node);
  });
  if (headings.filter(function(node) { return node.matches("h2"); }).length < 2) return null;
  var roots = Array.from(document.body.children).filter(function(root) {
    return root.matches("main, [role='main'], section, div") && !elementSubtreeHidden(root) &&
      headings.every(function(heading) { return root.contains(heading); }) &&
      !root.querySelector("article, [role='article'], [itemprop~='articleBody']") &&
      softwareLandingPhysicalName(root, declared.name) && softwareLandingPhysicalPlans(root, declared.plans) &&
      !softwareLandingOutsideMaterial(root);
  });
  return roots.length === 1 ? { root: roots[0], title: declared.title } : null;
}
