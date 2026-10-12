function productSourceChrome(node, boundary) {
  for (var current = node; current && current.nodeType === 1; current = current.parentElement) {
    if (current.matches("nav, aside, footer, form, dialog, template, [role='navigation'], [role='dialog'], [role='complementary']")) return true;
    if (current === boundary) break;
  }
  return false;
}

function productSourceLabel(node) {
  var clone = node.cloneNode(true);
  Array.from(clone.querySelectorAll("sup")).forEach(function(sup) { sup.remove(); });
  return productIdentityKey(clone.textContent);
}

function productPhysicalLabels(root, labels, selector) {
  var wanted = labels.map(productIdentityKey);
  var matches = wanted.map(function() { return []; });
  var indexes = Object.create(null);
  wanted.forEach(function(label, index) { indexes[label] = index; });
  Array.from(root.querySelectorAll(selector)).forEach(function(node) {
    var plain = productIdentityKey(node.textContent);
    var index = indexes[plain];
    if (index === undefined && node.querySelector("sup")) index = indexes[productSourceLabel(node)];
    if (index === undefined || productSourceChrome(node, root) || elementSubtreeHidden(node)) return;
    matches[index].push(node);
  });
  return matches.every(function(nodes) { return nodes.length; }) ? matches.map(function(nodes) { return nodes[0]; }) : null;
}

function productBodyRegion(node) {
  for (var current = node; current && current.parentElement; current = current.parentElement) {
    if (current.parentElement === document.body) return current;
  }
  return null;
}

function sourceOwnedProductContext(metadata) {
  var family = declaredProductFamily(metadata);
  if (!family) return null;
  var headings = Array.from(document.body.querySelectorAll("h1")).filter(function(node) {
    var label = productIdentityKey(node.textContent);
    return (label === family.name || label === family.topic) && !productSourceChrome(node, document.body) && !elementSubtreeHidden(node);
  });
  if (headings.length !== 1) return null;
  var heading = headings[0];
  var mains = Array.from(document.body.querySelectorAll("main, [role='main']")).filter(function(node) {
    return node.contains(heading) && !productSourceChrome(node, document.body) && !elementSubtreeHidden(node);
  });
  if (mains.length > 1) return null;
  var root = mains[0] || document.body;
  var variants = productPhysicalLabels(root, family.variants, "h2, h3, h4, h5, h6, button, p, span, dt, th");
  var questions = productPhysicalLabels(root, family.questions, "h2, h3, h4, h5, h6, button, summary, p, span, div");
  if (!variants || !questions) return null;
  if (mains.length) return { heading: heading, regions: [root], labels: variants.concat(questions) };

  var start = productBodyRegion(heading);
  var finalQuestion = questions[questions.length - 1];
  questions.forEach(function(question) {
    if (finalQuestion.compareDocumentPosition(question) & Node.DOCUMENT_POSITION_FOLLOWING) finalQuestion = question;
  });
  var end = productBodyRegion(finalQuestion);
  if (!start || !end || start === end) return null;
  var regions = [];
  for (var region = start; region; region = region.nextElementSibling) {
    if (!productSourceChrome(region, document.body) && !elementSubtreeHidden(region)) regions.push(region);
    if (region === end) break;
  }
  if (!regions.length || regions[regions.length - 1] !== end) return null;
  var anchors = [heading].concat(variants, questions);
  if (anchors.some(function(anchor) { return !regions.some(function(region) { return region.contains(anchor); }); })) return null;
  if (regions.some(function(region) { return region.querySelector("article, [itemtype*='NewsArticle'], [itemtype*='BlogPosting']"); })) return null;
  return { heading: heading, regions: regions, labels: variants.concat(questions) };
}
