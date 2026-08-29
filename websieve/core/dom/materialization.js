  function materializeHttpAttributes(root, retainUnsafeLinks) {
    if (!root || !root.querySelectorAll) return root;

    var svgUrlAttributes = ["fill", "stroke", "filter", "mask", "clip-path", "cursor", "marker", "marker-start", "marker-mid", "marker-end"];
    root.querySelectorAll("template").forEach(function(el) {
      materializeHttpAttributes(el.content, retainUnsafeLinks);
    });
    root.querySelectorAll("[href]").forEach(function(el) {
      var href = materializedHttpUrl(el.getAttribute("href"));
      if (href) el.setAttribute("href", href);
      else if (!retainUnsafeLinks) el.removeAttribute("href");
    });
    root.querySelectorAll("*").forEach(function(el) {
      if (/^(?:set|animate|animatemotion|animatetransform|animatecolor|discard)$/i.test(el.localName || "")) {
        el.remove();
        return;
      }
      Array.prototype.slice.call(el.attributes || []).forEach(function(attribute) {
        if (/^on/i.test(attribute.name)) el.removeAttribute(attribute.name);
      });
      if (el.hasAttribute("xlink:href")) materializeHttpAttribute(el, "xlink:href");
      if (el.hasAttribute("ping")) el.removeAttribute("ping");
      if (el.hasAttribute("archive")) el.removeAttribute("archive");
      if (el.hasAttribute("style")) el.removeAttribute("style");
      if ((el.namespaceURI || "").toLowerCase() === "http://www.w3.org/2000/svg") {
        svgUrlAttributes.forEach(function(attribute) {
          el.removeAttribute(attribute);
        });
      }
    });
    root.querySelectorAll("style").forEach(function(el) {
      el.remove();
    });
    root.querySelectorAll("script").forEach(function(el) {
      el.remove();
    });
    root.querySelectorAll("meta").forEach(function(el) {
      el.remove();
    });
    root.querySelectorAll("iframe[srcdoc]").forEach(function(el) {
      el.setAttribute("srcdoc", materializedHtml(el.getAttribute("srcdoc")));
    });
    root.querySelectorAll("img").forEach(function(el) {
      var lazyAttributes = ["data-lazy-src", "data-src", "data-original", "data-lazy"];
      var src = materializedHttpUrl(el.getAttribute("src"));
      for (var index = 0; !src && index < lazyAttributes.length; index++) {
        src = materializedHttpUrl(el.getAttribute(lazyAttributes[index]));
      }
      if (src) el.setAttribute("src", src);
      else el.removeAttribute("src");
      lazyAttributes.forEach(function(attribute) {
        el.removeAttribute(attribute);
      });
    });
    root.querySelectorAll("[src]:not(img)").forEach(function(el) {
      materializeHttpAttribute(el, "src");
    });
    root.querySelectorAll("[poster], [action], [formaction], [cite], [data], [background], [longdesc], [usemap], [profile], [manifest], [codebase], [classid], [itemid]").forEach(function(el) {
      ["poster", "action", "formaction", "cite", "data", "background", "longdesc", "usemap", "profile", "manifest", "codebase", "classid", "itemid"].forEach(function(attribute) {
        if (el.hasAttribute(attribute)) materializeHttpAttribute(el, attribute);
      });
    });
    root.querySelectorAll("[srcset], [imagesrcset]").forEach(function(el) {
      ["srcset", "imagesrcset"].forEach(function(attribute) {
        if (!el.hasAttribute(attribute)) return;
        var srcset = materializedSrcset(el.getAttribute(attribute));
        if (srcset) el.setAttribute(attribute, srcset);
        else el.removeAttribute(attribute);
      });
    });
    return root;
  }

  function materializeHttpAttribute(element, attribute) {
    var url = materializedHttpUrl(element.getAttribute(attribute));
    if (url) element.setAttribute(attribute, url);
    else element.removeAttribute(attribute);
  }

  function materializedSrcset(value) {
    return srcsetCandidates(value).map(function(candidate) {
      var url = materializedHttpUrl(candidate.url);
      var descriptor = candidate.descriptor;
      if (!url || !validSrcsetDescriptor(descriptor)) return "";
      return url + (descriptor ? " " + descriptor : "");
    }).filter(Boolean).join(", ");
  }

  function validSrcsetDescriptor(descriptor) {
    if (!descriptor) return true;
    if (/^\d+w$/.test(descriptor)) return parseInt(descriptor, 10) > 0;
    if (!/^(?:\d+(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?x$/i.test(descriptor)) return false;

    var density = Number(descriptor.slice(0, -1));
    return Number.isFinite(density) && density > 0;
  }

  function srcsetCandidates(value) {
    var input = value || "";
    var candidates = [];
    var position = 0;

    while (position < input.length) {
      while (position < input.length && /[\s,]/.test(input[position])) position += 1;
      if (position >= input.length) break;

      var urlStart = position;
      while (position < input.length && !/\s/.test(input[position])) position += 1;
      var url = input.slice(urlStart, position);
      var descriptor = "";
      var trailingCommas = url.match(/,+$/);

      if (trailingCommas) {
        url = url.slice(0, -trailingCommas[0].length);
      } else {
        while (position < input.length && /\s/.test(input[position])) position += 1;
        var descriptorStart = position;
        var parentheses = 0;
        while (position < input.length) {
          var character = input[position];
          if (character === "(") parentheses += 1;
          else if (character === ")" && parentheses) parentheses -= 1;
          else if (character === "," && !parentheses) break;
          position += 1;
        }
        descriptor = input.slice(descriptorStart, position).trim();
      }

      if (position < input.length && input[position] === ",") position += 1;
      if (url) candidates.push({ url: url, descriptor: descriptor });
    }

    return candidates;
  }

  function materializedHtml(html) {
    if (typeof html !== "string") return html;

    var template = document.createElement("template");
    template.innerHTML = html;
    materializeHttpAttributes(template.content);
    return template.innerHTML;
  }
