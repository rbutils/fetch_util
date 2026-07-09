  function metadataListValue(root, label) {
    var terms = Array.prototype.slice.call((root || document).querySelectorAll("dt"));
    var values = [];

    terms.forEach(function(term) {
      if (!new RegExp("^" + label + "s?:?$", "i").test(normalizeText(term.textContent || ""))) return;

      var node = term.nextElementSibling;
      while (node && node.tagName && node.tagName.toLowerCase() === "dd") {
        var value = normalizeText(node.textContent || "");
        if (value && values.indexOf(value) === -1) values.push(value);
        node = node.nextElementSibling;
      }
    });

    return values.join("; ") || null;
  }
