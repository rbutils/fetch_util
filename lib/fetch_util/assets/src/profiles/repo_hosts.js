  function gitLabInstancePage(metadata) {
    if (!document.querySelector(".project-home-panel, .project-information, .readme-holder, .file-holder.readme-holder")) return false;

    var signature = normalizeText([
      metadata && metadata.title,
      metadata && metadata.siteName,
      firstText(["meta[name='application-name']", "meta[property='og:site_name']"], "content"),
      document.title
    ].join(" "));

    return /gitlab/i.test(signature);
  }

  function gitLabContent(metadata) {
    if (!gitLabInstancePage(metadata)) return null;

    var node = document.querySelector(".readme-holder .md, .readme-holder .wiki, .readme-holder [data-testid='readme-content'], .file-holder.readme-holder .md, .file-holder.readme-holder .wiki");
    var title = normalizeText((metadata.title || document.title).replace(/\s*[·|-]\s*GitLab.*$/i, ""));
    var description = firstText([
      ".project-information .project-description",
      ".project-home-panel .project-description",
      ".project-home-panel p"
    ]) || metadata.excerpt;

    if (!node) {
      if (!title && !description) return null;

      return articleContentFromParts({
        title: title,
        description: description,
        siteName: metadata.siteName || location.hostname
      });
    }

    var root = cleanClone(node);
    cleanupAgentRoot(root);

    var markdown = markdownFor(root.innerHTML).replace(/^README\.md\s*/i, "").trim();
    if (!normalizeText(markdown)) {
      if (!description) return null;

      return articleContentFromParts({
        title: title,
        description: description,
        siteName: metadata.siteName || location.hostname
      });
    }

    if (description && markdown.toLowerCase().indexOf(description.toLowerCase()) === -1) markdown = description + "\n\n" + markdown;
    if (title) markdown = "# " + title + "\n\n" + markdown;

    return {
      title: title || metadata.title,
      byline: metadata.byline,
      excerpt: description,
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "article"
    };
  }

  function githubContent(metadata) {
    if (!hostMatches(/(^|\.)github\.com$/)) return null;

    var node = document.querySelector("#readme article.markdown-body, #readme .markdown-body, article.markdown-body, .markdown-body");
    if (!node) return null;

    var root = cleanClone(node);
    cleanupAgentRoot(root);
    var title = normalizeText((metadata.title || document.title).replace(/^GitHub -\s*/i, "").replace(/\s*[·|-]\s*GitHub$/i, ""));
    var description = metadata.excerpt;
    var markdown = markdownFor(root.innerHTML);
    if (!normalizeText(markdown)) return null;

    if (description && markdown.toLowerCase().indexOf(description.toLowerCase()) === -1) markdown = description + "\n\n" + markdown;
    if (title) markdown = "# " + title + "\n\n" + markdown;

    return {
      title: title || metadata.title,
      byline: metadata.byline,
      excerpt: description,
      siteName: metadata.siteName || "GitHub",
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "article"
    };
  }
