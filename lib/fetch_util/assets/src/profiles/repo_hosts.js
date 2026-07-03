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
        siteName: metadata.siteName || location.hostname,
        hostAware: true
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
        siteName: metadata.siteName || location.hostname,
        hostAware: true
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
      hostAware: true,
      readerMode: false,
      contentType: "article"
    };
  }

  function githubRepositoryPath() {
    var parts = location.pathname.split("/").filter(Boolean);
    if (parts.length < 2) return null;

    return parts;
  }

  function githubRepositoryLandingPage(metadata) {
    var parts = githubRepositoryPath();
    if (!parts || parts.length !== 2) return false;
    if (document.querySelector("[data-testid='repository-container-header'], strong[itemprop='name'] a, h1 strong[itemprop='name']")) return true;

    var signature = normalizeText([
      metadata && metadata.title,
      document.title
    ].join(" "));

    return /^GitHub\s+-\s+[^\s/]+\/[^\s:]+/i.test(signature);
  }

  function githubReadmeNode() {
    var selectors = [
      "#readme article.markdown-body",
      "#readme [data-testid='readme-content']",
      "#readme .markdown-body",
      "[data-testid='readme'] article.markdown-body",
      "[data-testid='readme'] [data-testid='readme-content']",
      "[data-testid='readme-content']",
      "[aria-label='README'] article.markdown-body",
      "[aria-labelledby='readme'] article.markdown-body",
      "article.markdown-body[itemprop='text']",
      "article.markdown-body"
    ];

    for (var i = 0; i < selectors.length; i += 1) {
      var candidates = Array.prototype.slice.call(document.querySelectorAll(selectors[i]));
      for (var j = 0; j < candidates.length; j += 1) {
        var candidate = candidates[j];
        if (!candidate || !normalizeText(candidate.textContent)) continue;
        if (candidate.closest("[data-testid='issue-body'], [data-testid='comment-body'], .js-comment-container, .timeline-comment")) continue;

        return candidate;
      }
    }

    return null;
  }

  function githubRepositoryDescription(metadata) {
    return firstText([
      "[data-testid='repository-description']",
      "[itemprop='about']",
      ".BorderGrid-cell p.f4",
      ".repository-content .f4.my-3",
      ".repository-meta-content"
    ]) || metadata.excerpt;
  }

  function githubContent(metadata) {
    if (!hostMatches(/(^|\.)github\.com$/)) return null;

    var node = githubReadmeNode();
    var title = normalizeText((metadata.title || document.title).replace(/^GitHub -\s*/i, "").replace(/\s*[·|-]\s*GitHub$/i, ""));
    var description = githubRepositoryDescription(metadata);
    if (!node) {
      if (!githubRepositoryLandingPage(metadata) || (!title && !description)) return null;

      return articleContentFromParts({
        title: title,
        description: description,
        siteName: metadata.siteName || "GitHub",
        hostAware: true
      });
    }

    var root = cleanClone(node);
    cleanupAgentRoot(root);
    var markdown = markdownFor(root.innerHTML);
    if (!normalizeText(markdown)) {
      if (!githubRepositoryLandingPage(metadata) || (!title && !description)) return null;

      return articleContentFromParts({
        title: title,
        description: description,
        siteName: metadata.siteName || "GitHub",
        hostAware: true
      });
    }

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
      hostAware: true,
      readerMode: false,
      contentType: "article"
    };
  }
