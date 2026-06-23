  function socialCompactCount(n, stripCommas) {
    var text = String(n);
    if (stripCommas) text = text.replace(/,/g, "");
    var num = parseInt(text, 10);
    if (isNaN(num)) return n;
    if (num >= 1000000) return (num / 1000000).toFixed(1).replace(/\.0$/, "") + "M";
    if (num >= 10000) return (num / 1000).toFixed(1).replace(/\.0$/, "") + "K";
    return num.toLocaleString();
  }
