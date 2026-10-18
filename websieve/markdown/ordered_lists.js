function addOrderedListContinuationRule(service) {
  service.addRule("orderedListItems", {
    filter: function(node) {
      return node.nodeName === "LI" && node.parentNode && node.parentNode.nodeName === "OL";
    },
    replacement: function(content, node) {
      var parent = node.parentNode;
      var start = parent.getAttribute("start");
      var index = Array.prototype.indexOf.call(parent.children, node);
      var prefix = (start ? Number(start) + index : index + 1) + ".  ";
      var continuation = " ".repeat(prefix.length);
      content = content
        .replace(/^\n+/, "")
        .replace(/\n+$/, "\n")
        .replace(/\n/g, "\n" + continuation);
      return prefix + content + (node.nextSibling && !/\n$/.test(content) ? "\n" : "");
    }
  });
}
