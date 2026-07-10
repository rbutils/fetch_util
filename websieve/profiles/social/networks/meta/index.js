  function socialCompactCount(n, stripCommas) {
    var text = String(n);
    if (stripCommas) text = text.replace(/,/g, "");
    var num = parseInt(text, 10);
    if (isNaN(num)) return n;
    if (num >= 1000000) return (num / 1000000).toFixed(1).replace(/\.0$/, "") + "M";
    if (num >= 10000) return (num / 1000).toFixed(1).replace(/\.0$/, "") + "K";
    return num.toLocaleString();
  }

  function visibleMetaSocialRoot(selectors) {
    var root = document.querySelector(selectors);
    if (!root) return null;

    var rect = root.getBoundingClientRect();
    var style = window.getComputedStyle(root);
    if (rect.width <= 0 || rect.height <= 0 || style.display === "none" || style.visibility === "hidden") return null;
    return root;
  }
