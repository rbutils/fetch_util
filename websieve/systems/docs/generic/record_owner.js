function physicalDataRecordContext() {
  var keys = pageStructuredDataDocumentKeys();
  var records = structuredDataNodes().filter(function(node) {
    return nodeTypes(node).indexOf("DataRecord") !== -1 && node.url &&
      keys.indexOf(structuredDataDocumentKey(node.url)) !== -1;
  });
  if (records.length !== 1) return null;
  var record = records[0];
  var entity = record.mainEntity;
  if (!entity || typeof entity !== "object" || Array.isArray(entity) ||
      typeof entity.identifier !== "string" || !entity.name || !nodeTypes(entity).length) return null;
  if (nodeTypes(entity).some(function(type) {
    return /^(?:Article|NewsArticle|BlogPosting|WebPage|WebSite|Organization|Person|Product|VideoObject)$/.test(type);
  })) return null;
  var entityUrl = entity.url || entity["@id"];
  if (!entityUrl || keys.indexOf(structuredDataDocumentKey(entityUrl)) === -1) return null;
  // This path owns an un-attributed technical reference, not publication metadata.
  if (record.author || record.creator || record.datePublished || entity.author || entity.creator || entity.datePublished) return null;

  var roots = document.querySelectorAll("main, [role='main']");
  if (roots.length !== 1) return null;
  var root = roots[0];
  var headings = root.querySelectorAll("h1");
  if (headings.length !== 1 || !root.querySelector("table, dl") || !root.querySelector("h2, h3")) return null;
  var identifier = normalizeText(entity.identifier);
  var title = cleanDocsHeadingText(headings[0].textContent);
  if (!identifier || !(title === identifier || title.indexOf(identifier + " ") === 0)) return null;
  if (elementSubtreeHidden(root) || elementSubtreeHidden(headings[0]) ||
      physicalTechnicalOwnerChrome(root, root) || physicalTechnicalOwnerChrome(headings[0], root)) return null;

  var name = normalizeText(entity.name);
  var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  var printedName = false;
  for (var text = walker.nextNode(); text; text = walker.nextNode()) {
    if (normalizeText(text.textContent) !== name || !text.parentElement) continue;
    if (!physicalTechnicalOwnerChrome(text.parentElement, root) && !elementVisuallyHidden(text.parentElement)) printedName = true;
  }
  return printedName ? { root: root, title: title } : null;
}

function physicalDataRecordContent(metadata) {
  var context = physicalDataRecordContext();
  if (!context) return null;
  var sourceClones = new Map();
  var readable = visibilityPrunedClone(context.root, document, sourceClones);
  var referenceSlots = new Map();
  var existingSlots = new Set(Array.from(readable.querySelectorAll("[data-fetchutil-record-reference-slot]")).map(function(node) {
    return node.getAttribute("data-fetchutil-record-reference-slot");
  }));
  var referenceIndex = 0;
  Array.from(context.root.querySelectorAll("button[aria-controls][aria-expanded]")).forEach(function(button) {
    var field = button.closest("td, dd, li");
    var label = normalizeText(button.textContent);
    var target = document.getElementById(button.getAttribute("aria-controls"));
    if (!field || !context.root.contains(field) || !target || !field.contains(target) ||
        button.hasAttribute("aria-haspopup") || !/\p{L}/u.test(label) ||
        normalizeText(field.textContent) === label || button.querySelector("a, input, select, textarea, button")) return;
    var clone = sourceClones.get(button);
    if (!clone || !readable.contains(clone)) return;
    var value = clone.ownerDocument.createElement("span");
    while (clone.firstChild) value.appendChild(clone.firstChild);
    clone.replaceWith(value);
  });
  Array.from(context.root.querySelectorAll("a[href]")).forEach(function(link) {
    var group = link.parentElement;
    var children = Array.from(group.children);
    if (!context.root.contains(group) || !children.some(function(node) { return node.nodeName === "BUTTON"; }) ||
        !children.every(function(node) {
          return node.nodeName === "BUTTON" ? node.disabled : node.nodeName === "A" &&
            !!normalizeText(node.textContent) && !!materializedHttpUrl(node.href);
        }) || Array.from(group.childNodes).some(function(node) { return node.nodeType === 3 && normalizeText(node.textContent); })) return;
    var clone = sourceClones.get(group);
    if (!clone || !readable.contains(clone)) return;
    var references = clone.ownerDocument.createElement("p");
    Array.from(clone.children).filter(function(node) { return node.nodeName === "A"; }).forEach(function(node) {
      var source = children.find(function(child) { return sourceClones.get(child) === node; });
      if (source) node.setAttribute("href", materializedHttpUrl(source.href));
      references.appendChild(node);
    });
    while (existingSlots.has(String(referenceIndex))) referenceIndex++;
    var key = String(referenceIndex++);
    references.setAttribute("data-fetchutil-record-reference-slot", key);
    referenceSlots.set(key, references.innerHTML);
    clone.replaceWith(references);
  });
  var content = docsContentForNode(metadata, readable, {
    title: context.title,
    hostAware: false,
    focusFragment: false,
    preserveAuthoredSections: true,
    preserveCleanedRoot: true,
    rewriteRoot: function(root) {
      root.querySelectorAll("[data-fetchutil-record-reference-slot]").forEach(function(slot) {
        var key = slot.getAttribute("data-fetchutil-record-reference-slot");
        if (!referenceSlots.has(key)) return;
        slot.innerHTML = referenceSlots.get(key);
        slot.removeAttribute("data-fetchutil-record-reference-slot");
      });
    }
  });
  if (!content) return null;
  content.sourceOwnedDataRecord = true;
  content.sourceOwnedGeneratedDocs = true;
  content.byline = null;
  content.publishedTime = null;
  return content;
}
