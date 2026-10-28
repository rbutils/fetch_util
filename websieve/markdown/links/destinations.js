function escapeMarkdownDestination(value) {
  return String(value || "").replace(/\\/g, "\\\\")
    .replace(/&(?=(?:#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z][a-zA-Z0-9]+);)/g, "&amp;");
}

function decodeMarkdownDestination(value) {
  // CommonMark numeric references have at most six hexadecimal or seven decimal digits.
  var decoded = String(value || "").replace(/\\([!-/:-@[-`{-~])|&(?:#[xX][0-9a-fA-F]{1,6}|#[0-9]{1,7}|[a-zA-Z][a-zA-Z0-9]+);/g,
    function(reference, punctuation) {
      if (punctuation) return punctuation;
      var decoder = document.createElement("textarea");
      decoder.innerHTML = reference;
      return decoder.value;
    });
  // A URL constructor strips literal tabs/newlines; CommonMark destinations encode them.
  return decoded.replace(/[\u0000-\u0020\u007f]/g, function(character) { return encodeURIComponent(character); });
}

function addLiteralEntityDestinationRule(service) {
  var probe = document.createElement("a");
  probe.setAttribute("href", "/");
  probe.textContent = "reference";
  var original = service.rules.forNode(probe);
  service.addRule("literalEntityDestinations", {
    filter: function(node) {
      var href = node.nodeName === "A" && node.getAttribute("href");
      return !!href && escapeMarkdownDestination(href) !== href;
    },
    replacement: function(content, node, options) {
      var serialized = node.cloneNode(false);
      serialized.setAttribute("href", escapeMarkdownDestination(node.getAttribute("href")));
      return original.replacement.call(original, content, serialized, options);
    }
  });
}

function literalMarkdownDestination(node) {
  var value = node.tagName === "A" ? node.getAttribute("href") :
    node.getAttribute("src") || node.getAttribute("data-src") || node.getAttribute("data-lazy-src");
  var url = materializedHttpUrl(value || "");
  return url && url.indexOf("\\") >= 0 ? url : null;
}

function literalMarkdownDestinationNodes(root) {
  var backslash = "\\\\";
  var selector = "a[href*='" + backslash + "'], img[src*='" + backslash + "'], " +
    "img[data-src*='" + backslash + "'], img[data-lazy-src*='" + backslash + "']";
  var nodes = Array.from(root.querySelectorAll(selector));
  if (root.matches && root.matches(selector)) nodes.unshift(root);
  return nodes.filter(function(node) {
    return !node.closest("pre, code, kbd, samp, [hidden], details:not([open])") &&
      !!literalMarkdownDestination(node);
  });
}

function prepareLiteralDestinationMarkdown(root, protectedLinks) {
  var candidates = literalMarkdownDestinationNodes(root).filter(function(node) {
    if (node.closest("table")) return false;
    if (protectedLinks && node.closest("[" + protectedLinks.attribute + "]")) return false;
    return !node.parentElement || !node.parentElement.closest("a[href]") || node.tagName === "A" ||
      !literalMarkdownDestination(node.parentElement.closest("a[href]"));
  });
  if (!candidates.length) return null;
  var attribute = "data-fetchutil-literal-destination";
  while (root.hasAttribute(attribute) || root.querySelector("[" + attribute + "]")) attribute += "-owned";
  var prefix = "FETCHUTILLITERALDESTINATION";
  while (root.innerHTML.indexOf(prefix) >= 0) prefix += "OWNED";
  var values = candidates.map(function(node, index) {
    var owner = node;
    var paragraph = node.parentElement;
    if (paragraph && paragraph !== root && paragraph.tagName === "P" &&
        Array.from(paragraph.childNodes).every(function(child) {
          return child === node || child.nodeType === Node.TEXT_NODE && !child.textContent.trim();
        })) owner = paragraph;
    var clone = owner.cloneNode(true);
    if (node.tagName === "IMG") {
      var image = owner === node ? clone : clone.firstElementChild;
      image.setAttribute("src", literalMarkdownDestination(node));
    }
    var holder = document.createElement("div");
    holder.appendChild(clone);
    var walker = document.createTreeWalker(holder, NodeFilter.SHOW_COMMENT);
    var comments = [];
    var comment;
    while ((comment = walker.nextNode())) comments.push(comment);
    comments.forEach(function(value) { value.remove(); });
    materializeHttpAttributes(holder, false, false);
    var linkedBlocks = clone.tagName === "A" &&
      !!clone.querySelector("div, p, figure, h1, h2, h3, h4, h5, h6, ul, ol, table, pre, blockquote");
    var block = clone.tagName === "P" || linkedBlocks;
    var html = singleBlockMaterializedHtml(linkedBlocks ? holder.outerHTML : clone.outerHTML);
    owner.setAttribute(attribute, String(index));
    if (owner.tagName !== "IMG") owner.textContent = "x";
    return { html: html, block: block };
  });
  return { attribute: attribute, prefix: prefix, values: values };
}

function addLiteralDestinationRule(service, prepared) {
  if (!prepared) return;
  service.addRule("literalDestinationMaterial", {
    filter: function(node) {
      return node.nodeType === Node.ELEMENT_NODE && node.hasAttribute(prepared.attribute);
    },
    replacement: function(_content, node) {
      var key = node.getAttribute(prepared.attribute);
      if (!Object.prototype.hasOwnProperty.call(prepared.values, key)) throw new Error("Missing literal destination snapshot");
      var token = prepared.prefix + key + "END";
      return prepared.values[key].block ? "\n\n" + token + "\n\n" : token;
    }
  });
}

function restoreLiteralDestinationMarkdown(markdown, prepared) {
  if (!prepared) return markdown;
  return markdown.replace(new RegExp(prepared.prefix + "([0-9]+)END", "g"), function(_match, key) {
    if (!Object.prototype.hasOwnProperty.call(prepared.values, key)) throw new Error("Missing rendered literal destination");
    return prepared.values[key].html;
  });
}
