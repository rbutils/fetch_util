  function protectMarkdownFences(markdown) {
    var fencedBlocks = [];
    var protectedMarkdown = String(markdown || "").replace(/(^|\n)(```[^\n]*\n[\s\S]*?\n```)/g, function(match, prefix, block) {
      var marker = "@@FETCH_UTIL_FENCE_" + fencedBlocks.length + "@@";
      fencedBlocks.push(block);
      return prefix + marker;
    });

    return { markdown: protectedMarkdown, blocks: fencedBlocks };
  }

  function restoreMarkdownFences(markdown, fencedBlocks) {
    return markdown.replace(/@@FETCH_UTIL_FENCE_(\d+)@@/g, function(match, index) {
      return fencedBlocks[Number(index)] || "";
    });
  }
