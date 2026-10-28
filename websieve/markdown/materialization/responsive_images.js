  function responsiveImageTokenPrefix(root) {
    var prefix = "FETCHUTILRESPONSIVEIMAGE";
    var suffixLength = 0;
    var inspect = function(value) {
      var matches = String(value || "").match(/FETCHUTILRESPONSIVEIMAGEX*/g) || [];
      matches.forEach(function(match) {
        suffixLength = Math.max(suffixLength, match.length - prefix.length + 1);
      });
    };
    inspect(root.textContent);
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_COMMENT);
    var node = walker.currentNode;
    while (node) {
      if (node.nodeType === Node.COMMENT_NODE) inspect(node.data);
      Array.from(node.attributes || []).forEach(function(attribute) {
        inspect(attribute.value);
        inspect(normalizeText(attribute.value).replace(/[\[\]]/g, ""));
      });
      node = walker.nextNode();
    }
    return prefix + "X".repeat(suffixLength);
  }

  function prepareResponsiveImageMarkdown(root) {
    var images = Array.from(root.querySelectorAll("img[srcset]")).filter(function(image) {
      return !image.closest("pre, code, kbd, samp, template") &&
        !materializedHttpUrl(image.getAttribute("src")) &&
        !!materializedSrcset(image.getAttribute("srcset"));
    });
    if (!images.length) return null;

    var attribute = "data-fetchutil-responsive-image-token";
    while ((root.hasAttribute && root.hasAttribute(attribute)) || root.querySelector("[" + attribute + "]")) attribute += "-x";
    var state = { attribute: attribute, prefix: responsiveImageTokenPrefix(root), images: [] };
    images.forEach(function(image) {
      var holder = document.createElement("div");
      holder.appendChild(image.cloneNode(true));
      materializeHttpAttributes(holder, false, false);
      var snapshot = holder.firstElementChild;
      if (!snapshot || !materializedSrcset(snapshot.getAttribute("srcset"))) return;
      var index = state.images.length;
      state.images.push(singleBlockMaterializedHtml(holder.innerHTML));
      image.setAttribute(attribute, String(index));
    });
    return state;
  }

  function responsiveImageMarkdownToken(node, state) {
    if (!state) return null;
    var key = node.getAttribute(state.attribute);
    if (key === null || !/^\d+$/.test(key)) return null;
    var index = Number(key);
    return state.images[index] === undefined ? null : state.prefix + index + "END";
  }

  function restoreResponsiveImageMarkdown(markdown, state) {
    if (!state) return markdown;
    state.images.forEach(function(html, index) {
      markdown = markdown.split(state.prefix + index + "END").join(html);
    });
    return markdown;
  }

  function addMarkdownImageRule(service, responsiveImages) {
    service.addRule("images", {
      filter: function(node) {
        return node.nodeName === "IMG";
      },
      replacement: function(_content, node) {
        var responsive = responsiveImageMarkdownToken(node, responsiveImages);
        if (responsive !== null) return responsive;
        var src = node.getAttribute("src") || node.getAttribute("data-src") || node.getAttribute("data-lazy-src") || "";
        var alt = normalizeText(node.getAttribute("alt") || "").replace(/[\[\]]/g, "");
        var url = materializedHttpUrl(src);
        return url ? "![" + alt + "](" + escapeMarkdownDestination(url) + ")" : alt;
      }
    });
  }
