  function repositoryPathParts() {
    return location.pathname.split("/").filter(Boolean);
  }

  function repositorySignature(metadata) {
    return normalizeText([
      metadata && metadata.title,
      metadata && metadata.siteName,
      firstText(["meta[name='application-name']", "meta[name='generator']", "meta[property='og:site_name']"], "content"),
      document.title,
      document.body && document.body.className
    ].join(" "));
  }

  function repositoryLandingPath(profile) {
    var parts = repositoryPathParts();
    if (location.protocol === "about:") return true;
    if (parts.length < 2) return false;
    if (location.pathname.indexOf("/-/") !== -1) return false;

    var firstExtra = parts[2] || "";
    if (/^(issues?|pulls?|pull-requests?|merge[-_]requests?|commits?|branches|tags|releases|wiki|settings|src|source|downloads|actions|projects|security|pulse|graphs)$/i.test(firstExtra)) return false;

    if (profile && profile.platform === "gitlab") return true;
    return parts.length === 2;
  }

  function repositoryReadmeNode(selectors) {
    for (var i = 0; i < selectors.length; i += 1) {
      var candidates = Array.prototype.slice.call(document.querySelectorAll(selectors[i]));
      for (var j = 0; j < candidates.length; j += 1) {
        var candidate = candidates[j];
        if (!candidate || !normalizeText(candidate.textContent)) continue;
        if (candidate.closest("[data-testid='issue-body'], [data-testid='comment-body'], .js-comment-container, .timeline-comment, .comment, .issue-content, .pullrequest-description, .pull-request-description")) continue;

        return candidate;
      }
    }

    return null;
  }

  function repositoryDescription(profile, metadata) {
    return firstText(profile.descriptionSelectors) || metadata.excerpt;
  }

  function repositoryTitle(profile, metadata) {
    var title = normalizeText(metadata.title || document.title);
    if (profile.titleCleaner) title = normalizeText(profile.titleCleaner(title));
    return title;
  }

  function repositoryReadmeResult(profile, metadata, node) {
    var title = repositoryTitle(profile, metadata);
    var description = repositoryDescription(profile, metadata);
    var siteName = metadata.siteName || profile.siteName || location.hostname;

    if (!node) {
      if (!title && !description) return null;

      return articleContentFromParts({
        title: title,
        description: description,
        siteName: siteName,
        hostAware: true
      });
    }

    var root = cleanClone(node);
    cleanupAgentRoot(root);

    var markdown = markdownFor(root.innerHTML).replace(/^README(?:\.[a-z0-9_-]+)?\s*/i, "").trim();
    if (!normalizeText(markdown)) {
      if (!description) return null;

      return articleContentFromParts({
        title: title,
        description: description,
        siteName: siteName,
        hostAware: true
      });
    }

    if (description && markdown.toLowerCase().indexOf(description.toLowerCase()) === -1) markdown = description + "\n\n" + markdown;
    if (title) markdown = "# " + title + "\n\n" + markdown;

    return {
      title: title || metadata.title,
      byline: metadata.byline,
      excerpt: description,
      siteName: siteName,
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: normalizeText(markdown),
      hostAware: true,
      readerMode: false,
      contentType: "article"
    };
  }

  function repositoryPlatformProfile(metadata) {
    var signature = repositorySignature(metadata);
    var hasGitLabProject = !!document.querySelector(".project-home-panel, .project-information, .readme-holder, .file-holder.readme-holder, [data-testid='blob-viewer-content'] .blob-viewer[data-path][data-rich-type='markup'], [data-testid='blob-viewer-content'] .file-content.md");
    if (/gitlab/i.test(signature) && hasGitLabProject) {
      return {
        platform: "gitlab",
        siteName: location.hostname,
        readmeSelectors: [
          "[data-testid='blob-viewer-content'] .blob-viewer[data-path='README.md'][data-rich-type='markup'] .file-content.md",
          "[data-testid='blob-viewer-content'] .blob-viewer[data-path='README.md'] .file-content.md",
          "[data-testid='blob-viewer-content'] .file-content.md",
          ".blob-viewer[data-path='README.md'][data-rich-type='markup'] .file-content.md",
          ".blob-viewer[data-path='README.md'] .file-content.md",
          ".readme-holder .md",
          ".readme-holder .wiki",
          ".readme-holder [data-testid='readme-content']",
          ".file-holder.readme-holder .md",
          ".file-holder.readme-holder .wiki"
        ],
        descriptionSelectors: [
          ".project-information .project-description",
          ".project-home-panel .project-description",
          ".project-home-panel p"
        ],
        titleCleaner: function(title) { return title.replace(/\s*[·|-]\s*GitLab.*$/i, ""); }
      };
    }

    if (/^GitHub\s+-\s+[^\s/]+\/[^\s:]+/i.test(signature) || document.querySelector("[data-testid='repository-container-header'], strong[itemprop='name'] a, h1 strong[itemprop='name']")) {
      return {
        platform: "github",
        siteName: "GitHub",
        readmeSelectors: [
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
        ],
        descriptionSelectors: [
          "[data-testid='repository-description']",
          "[itemprop='about']",
          ".BorderGrid-cell p.f4",
          ".repository-content .f4.my-3",
          ".repository-meta-content"
        ],
        titleCleaner: function(title) { return title.replace(/^GitHub -\s*/i, "").replace(/\s*[·|-]\s*GitHub$/i, ""); }
      };
    }

    if (/gitea|forgejo/i.test(signature) || document.querySelector(".repository .repo-description, .repository #repo-files-table, .repository .file-view.markup.markdown, .repository .markup.markdown")) {
      return {
        platform: "gitea",
        readmeSelectors: [
          ".repository #readme .markdown",
          ".repository #readme .markup.markdown",
          ".repository .file-view.markup.markdown",
          ".repository .markup.markdown",
          "#readme .markdown",
          ".file-content.markup.markdown"
        ],
        descriptionSelectors: [
          ".repository .repo-description",
          ".repo-description",
          ".repository-summary .description"
        ],
        titleCleaner: function(title) { return title.replace(/\s*[·|-]\s*(Gitea|Forgejo|Codeberg).*$/i, ""); }
      };
    }

    if (/bitbucket/i.test(signature) || document.querySelector("[data-testid='repo-overview-description'], [data-testid='repository-readme'], [data-testid='readme-content']")) {
      return {
        platform: "bitbucket",
        siteName: "Bitbucket",
        readmeSelectors: [
          "[data-testid='repository-readme'] [data-testid='readme-content']",
          "[data-testid='readme'] [data-testid='readme-content']",
          "[data-testid='readme-content']",
          ".readme-content .markdown-body",
          ".readme-content",
          ".markdown-body"
        ],
        descriptionSelectors: [
          "[data-testid='repo-overview-description']",
          "[data-testid='repository-description']"
        ],
        titleCleaner: function(title) { return title.replace(/\s*[·|-]\s*Bitbucket.*$/i, ""); }
      };
    }

    return null;
  }

  function repositoryReadmeContent(metadata) {
    var profile = repositoryPlatformProfile(metadata);
    if (!profile || !repositoryLandingPath(profile)) return null;

    return repositoryReadmeResult(profile, metadata, repositoryReadmeNode(profile.readmeSelectors));
  }
