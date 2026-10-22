  function materializeMarkdownHeadingLayouts(root) {
    var headings = Array.prototype.slice.call(root.querySelectorAll("h1, h2, h3, h4, h5, h6"));
    if (root.nodeType === Node.ELEMENT_NODE && /^H[1-6]$/.test(root.nodeName)) headings.unshift(root);

    headings.forEach(function(heading) {
      if (heading.closest("pre, code, kbd, samp, svg, math, table")) return;

      heading.querySelectorAll("div, address").forEach(function(layout) {
        if (layout.closest("pre, code, kbd, samp, svg, math, table")) return;
        if (layout.querySelector("p, ul, ol, dl, pre, table, form, input, button, select, textarea, nav, h1, h2, h3, h4, h5, h6, blockquote, section, article, details, figure")) return;
        var role = (layout.getAttribute("role") || "").toLowerCase();
        if (role && role !== "none" && role !== "presentation") return;

        // Block layout must not split a physical heading into Markdown paragraphs.
        // Preserve its complete children and the boundaries between layout groups.
        var inline = layout.ownerDocument.createElement("span");
        Array.prototype.forEach.call(layout.attributes, function(attribute) {
          inline.setAttribute(attribute.name, attribute.value);
        });
        while (layout.firstChild) inline.appendChild(layout.firstChild);
        layout.parentNode.replaceChild(inline, layout);
        inline.parentNode.insertBefore(inline.ownerDocument.createTextNode(" "), inline);
        inline.parentNode.insertBefore(inline.ownerDocument.createTextNode(" "), inline.nextSibling);
      });

      heading.querySelectorAll("br").forEach(function(lineBreak) {
        if (lineBreak.closest("pre, code, kbd, samp, svg, math, table")) return;
        // An ATX heading occupies one line; retain each physical word boundary.
        lineBreak.parentNode.replaceChild(lineBreak.ownerDocument.createTextNode(" "), lineBreak);
      });
    });
  }
