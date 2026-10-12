function visibleMetadataNodeText(node) {
  if (!node) return "";
  if (node.nodeType === 3) {
    return elementVisuallyHidden(node.parentElement) ? "" : node.nodeValue || "";
  }
  if (node.nodeType !== 1 || elementVisuallyHidden(node) ||
      /^(script|style|noscript|template)$/i.test(node.tagName || "")) return "";

  return Array.prototype.map.call(node.childNodes || [], visibleMetadataNodeText).filter(Boolean).join(" ");
}

function visibleLabeledMetadataGroups(root, includeLabel) {
  if (!root || !root.querySelectorAll) return [];
  var lists = [];
  if (root.matches && root.matches("dl")) lists.push(root);
  Array.prototype.forEach.call(root.querySelectorAll("dl"), function(list) { lists.push(list); });

  return lists.filter(function(list) {
    return !elementVisuallyHidden(list);
  }).map(function(list) {
    var terms = Array.prototype.filter.call(list.querySelectorAll("dt"), function(term) {
      return term.closest("dl") === list && !elementVisuallyHidden(term);
    });
    var fields = terms.map(function(term) {
      var label = normalizeText(visibleMetadataNodeText(term)).toLowerCase().replace(/\s+/g, " ");
      if (!label || (includeLabel && !includeLabel(label))) return null;
      var values = [];
      var sibling = term.nextElementSibling;
      while (sibling && sibling.tagName === "DD" && sibling.closest("dl") === list) {
        if (!elementVisuallyHidden(sibling)) {
          var value = normalizeText(visibleMetadataNodeText(sibling));
          if (value) values.push(value);
        }
        sibling = sibling.nextElementSibling;
      }
      return {
        label: label,
        values: values,
        term: term
      };
    }).filter(function(field) { return field && field.values.length; });

    return { list: list, fields: fields };
  }).filter(function(group) { return group.fields.length; });
}
