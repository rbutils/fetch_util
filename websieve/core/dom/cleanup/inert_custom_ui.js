  var CUSTOM_SHARE_LABEL_PATTERN = /^(share(?: this)?(?: (?:article|story|page))?|شارك الخبر)$/i;
  var CUSTOM_UI_ROLE_SUFFIX_PATTERN = /(?:^|-)(?:share|related(?:-article)?)$/i;

  function stripInertCustomUiElements(root) {
    if (!root || !root.querySelectorAll) return root;
    var elements = Array.prototype.slice.call(root.querySelectorAll("*"));
    if (root.matches && root.localName && root.localName.indexOf("-") !== -1) elements.unshift(root);

    elements.forEach(function(element) {
      var name = (element.localName || "").toLowerCase();
      if (name.indexOf("-") === -1 || !CUSTOM_UI_ROLE_SUFFIX_PATTERN.test(name)) return;
      if (element.children.length || nodeHasShadowContent(element) ||
          Array.prototype.some.call(element.childNodes, function(child) { return child.nodeType !== 3; })) return;
      if (element.matches("[href], [src], [srcset], [poster], [data], [cite], [background], [role='heading'], [contenteditable], [data-fetchutil-material]")) return;
      if (element.closest("p, h1, h2, h3, h4, h5, h6, [role='heading'], blockquote, q, li, td, th, figure, figcaption, caption, svg, math, pre, code")) return;

      var text = normalizeText(element.textContent || "");
      var isShare = /(?:^|-)share$/i.test(name);
      if (isShare ? !CUSTOM_SHARE_LABEL_PATTERN.test(text) : !utilityHeadingText(text)) return;
      element.remove();
    });
    return root;
  }
