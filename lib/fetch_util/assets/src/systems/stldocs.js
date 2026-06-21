  function stlDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || (info.system !== "stldocs" && info.system !== "starlight")) return null;

    var selectors = [
      "main .stldocs-content",
      "main .stldocs-resource-content",
      "main .stl-content-panel",
      "main article",
      "main [data-pagefind-body]",
      "main .sl-markdown-content",
      "main .content-panel",
      "main"
    ];
    var node = selectors.map(function(selector) {
      return Array.prototype.slice.call(document.querySelectorAll(selector));
    }).flat().sort(function(a, b) {
      function score(el) {
        var methodCount = el.querySelectorAll("[class*='stldocs-method-summary'], [class*='method-summary']").length;
        var routeCount = el.querySelectorAll("[class*='stldocs-method-route'], [class*='method-route']").length;
        var descCount = el.querySelectorAll("[class*='resource-description']").length;
        var propertyCount = el.querySelectorAll(".stldocs-property").length;
        return (methodCount * 1000) + (routeCount * 200) + (propertyCount * 80) + (descCount * 50) + normalizeText(el.textContent).length;
      }

      return score(b) - score(a);
    })[0] || null;

    var summaryNode = cleanClone(node || document.body);
    cleanupAgentRoot(summaryNode);
    cleanupDocsRoot(summaryNode, {});
    var title = firstText(["main h1", "main article h1"]) || normalizeText(metadata.title || document.title);
    var methods = stlSectionSummary(summaryNode);
    var schemas = stlSchemaSummary(summaryNode, title);

    if (methods.length || schemas.length) {
      var description = stlResourceDescription(summaryNode, metadata, title);
      if (methods.length >= 6) {
        schemas = schemas.slice(0, 2).map(function(item) {
          return {
            declaration: item.declaration,
            description: item.description,
            fields: item.fields.slice(0, 3)
          };
        });
      }

      var markdownParts = [];
      if (title) markdownParts.push("# " + title);
      if (description) markdownParts.push(description);
      if (methods.length) markdownParts.push(stlMethodsMarkdown(methods));
      if (schemas.length) markdownParts.push(stlSchemasMarkdown(schemas));

      return {
        title: title || metadata.title,
        byline: null,
        excerpt: description || metadata.excerpt,
        siteName: metadata.siteName || location.hostname,
        publishedTime: null,
        html: "",
        markdown: markdownParts.filter(Boolean).join("\n\n").trim(),
        textContent: normalizeText(markdownParts.join(" ")),
        readerMode: false,
        contentType: "article"
      };
    }

    return docsArticleContent(metadata, node, {
      title: firstText(["main h1", "main article h1"]) || normalizeText(metadata.title || document.title),
      rewriteRoot: function(root) {
        root.querySelectorAll("#starlight__sidebar, starlight-menu-button, [class*='stldocs-sidebar'], [class*='stldocs-sidebar-entry'], [class*='stldocs-expander'], [class*='sidebar-pane'], [class*='sidebar-content'], [class*='sidebar-accordion'], [class*='table-of-contents'], .stldocs-breadcrumbs, .stl-ui-dropdown, aside").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "div, p, span, button, a", /^(on this page|table of contents|copy page|edit page|expand|collapse|api reference)$/i);
        root.querySelectorAll("h1").forEach(function(el, index) {
          if (index > 0) el.remove();
        });
        root.querySelectorAll("h2, h3, h4, h5, h6, p, div, span").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/expand collapse/i.test(text)) el.remove();
          if (/^[A-Z][a-z]+(?:[A-Z][a-z]+){1,}$/.test(text) && text.length < 40) el.remove();
        });
      }
    });
  }

  function stlMethodSummary(block) {
    if (!block) return null;

    var route = firstRootText(block, [
      "[class*='method-route']",
      "[class*='route-endpoint']",
      "code",
      "pre"
    ]);
    route = normalizeText(route).replace(/\s+/g, "");

    var title = firstRootText(block, [
      "h2",
      "h3",
      "h4",
      "strong",
      "[class*='method-name']",
      "[class*='method-title']",
      "[class*='summary-title']"
    ]);

    var text = normalizeText(block.textContent);
    if (!title) {
      title = text;
      if (route) title = normalizeText(title.replace(route, ""));
      title = title.replace(/\s{2,}/g, " ");
      title = title.split(/(?:(?:GET|POST|PUT|PATCH|DELETE|OPTIONS|HEAD)\/)/)[0].trim();
    }

    if (!title) return null;

    var detail = firstRootText(block, [
      "p",
      "[class*='description']",
      "[class*='summary-description']"
    ]);
    if (detail) {
      detail = compactReferenceText(normalizeText(detail));
      if (title && detail.indexOf(title) === 0) detail = normalizeText(detail.slice(title.length));
      if (route && detail.indexOf(route) === 0) detail = normalizeText(detail.slice(route.length));
    }

    var item = { text: title };
    if (route) item.route = route;
    if (detail) item.detail = detail;
    item.groups = stlMethodGroups(block);
    return item;
  }

  function stlSectionSummary(root) {
    var seen = {};
    var items = [];

    root.querySelectorAll("[class*='stldocs-method-summary'], [class*='method-summary']").forEach(function(block) {
      if (items.length >= 12) return;

      var item = stlMethodSummary(block);
      if (!item) return;

      var key = item.text + "|" + (item.route || "");
      if (seen[key]) return;
      seen[key] = true;
      items.push(item);
    });

    return items;
  }

  function stlPropertyAncestor(node) {
    var current = node && node.parentElement;

    while (current) {
      if (current.classList && current.classList.contains("stldocs-property")) return current;
      current = current.parentElement;
    }

    return null;
  }

  function stlOwnPropertyText(block, selector) {
    return docsScopedFirstText(block, [selector], ".stldocs-property");
  }

  function stlDirectChildProperties(block) {
    return docsScopedDescendants(block, ".stldocs-property", ".stldocs-property").filter(function(child) {
      return child !== block;
    });
  }

  function stlLiteralDeclaration(text) {
    text = normalizeText(text);
    return /^("|').+("|')$/.test(text);
  }

  function stlPropertyFieldSummary(block, depth) {
    if (!block) return null;
    depth = depth || 0;

    var declaration = normalizeText(stlOwnPropertyText(block, ".stldocs-property-declaration, [class*='property-declaration']"));
    if (!declaration || stlLiteralDeclaration(declaration)) return null;

    var description = compactReferenceText(stlOwnPropertyText(block, ".stldocs-property-description, [class*='property-description']"));
    var children = depth < 2 ? stlDirectChildProperties(block).map(function(child) {
      return stlPropertyFieldSummary(child, depth + 1);
    }).filter(Boolean).slice(0, depth === 0 ? 3 : 2) : [];

    return {
      declaration: declaration,
      description: description || null,
      fields: children
    };
  }

  function stlMethodGroups(block) {
    var groups = [];
    var seen = {};

    docsScopedDescendants(block, "section, div, details", ".stldocs-property").forEach(function(group) {
      if (groups.length >= 3) return;
      if (group.closest(".stldocs-property")) return;

      var heading = docsScopedFirstText(group, ["h2", "h3", "h4", "summary", "[class*='title']"], ".stldocs-property");
      if (!/\b(parameters?|request|responses?|returns?|body|headers?)\b/i.test(heading)) return;

      var fields = stlDirectChildProperties(group).map(function(child) {
        return stlPropertyFieldSummary(child, 0);
      }).filter(Boolean).slice(0, 4);
      if (!fields.length || seen[heading]) return;

      seen[heading] = true;
      groups.push({ heading: heading, fields: fields });
    });

    return groups;
  }

  function stlSchemaSummary(root, title) {
    var seen = {};
    var items = [];
    var titleHint = normalizeText(String(title || "")).toLowerCase().replace(/s$/i, "");

    Array.prototype.slice.call(root.querySelectorAll(".stldocs-property")).forEach(function(block) {
      if (stlPropertyAncestor(block)) return;
      if (block.closest("[class*='stldocs-method-summary'], [class*='method-summary']")) return;

      var declaration = normalizeText(stlOwnPropertyText(block, ".stldocs-property-declaration, [class*='property-declaration']"));
      if (!declaration || stlLiteralDeclaration(declaration) || seen[declaration]) return;

      var description = compactReferenceText(stlOwnPropertyText(block, ".stldocs-property-description, [class*='property-description']"));
      var fields = stlDirectChildProperties(block).map(function(child) {
        return stlPropertyFieldSummary(child, 0);
      }).filter(Boolean).slice(0, 5);
      if (!description && !fields.length) return;
      var objectSchema = /(?:=|:)\s*object\s*\{|\bobject\s*\{/.test(declaration);
      var schemaName = normalizeText(declaration.split(/[:=]/)[0]).replace(/\s+$/, "");
      var schemaKey = schemaName.replace(/([a-z0-9])([A-Z])/g, "$1 $2");
      var tokenCount = schemaKey.split(/[\s_.-]+/).filter(Boolean).length;
      var titlePrefix = titleHint && schemaName.toLowerCase().indexOf(titleHint) === 0;

      seen[declaration] = true;
      items.push({
        declaration: declaration,
        description: description || null,
        fields: fields,
        objectSchema: objectSchema,
        score: (objectSchema ? 600 : 0) + (fields.length * 200) + (description ? 50 : 0) + (titlePrefix ? 700 : 0) + (titleHint && declaration.toLowerCase().indexOf(titleHint) !== -1 ? 250 : 0) - ((declaration.match(/\s+or\s+/g) || []).length * 120) - (Math.max(tokenCount - 2, 0) * 80) + Math.min(declaration.length, 80)
      });
    });

    var preferred = items.some(function(item) {
      return item.objectSchema;
    }) ? items.filter(function(item) {
      return item.objectSchema;
    }) : items;

    return preferred.sort(function(a, b) {
      return b.score - a.score;
    }).slice(0, 3).map(function(item) {
      delete item.score;
      delete item.objectSchema;
      return item;
    });
  }

  function stlSchemasMarkdown(items) {
    var sections = ["## Schemas"];

    items.forEach(function(item) {
      sections.push("### " + item.declaration);
      if (item.description) sections.push(item.description);
      if (item.fields.length) {
        sections.push(stlFieldsMarkdown(item.fields, ""));
      }
    });

    return sections.join("\n\n");
  }

  function stlFieldsMarkdown(fields, indent) {
    indent = indent || "";

    return fields.map(function(field) {
      var line = indent + "- `" + field.declaration + "`";
      if (field.description) line += ": " + field.description;
      if (field.fields && field.fields.length) line += "\n" + stlFieldsMarkdown(field.fields, indent + "  ");
      return line;
    }).join("\n");
  }

  function stlResourceDescription(root, metadata, title) {
    var selectors = [
      ".stldocs-resource-description",
      "[class*='resource-description']",
      ".stldocs-resource-content > p",
      ".stldocs-markdown > p",
      ".sl-markdown-content > p",
      "p"
    ];

    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = Array.prototype.slice.call(root.querySelectorAll(selectors[i]));

      for (var j = 0; j < nodes.length; j += 1) {
        var node = nodes[j];
        if (node.closest(".stldocs-property, [class*='stldocs-method-summary'], [class*='method-summary'], .stldocs-properties, [class*='resource-content-properties']")) continue;

        var text = compactReferenceText(normalizeText(node.textContent));
        if (!text || text === title || text.length < 20) continue;
        if (/^(models?\s*expand\s*collapse|api reference)$/i.test(text)) continue;

        return text;
      }
    }

    var fallback = compactReferenceText(normalizeText(metadata && metadata.excerpt));
    if (!fallback || fallback === title) return null;
    if (/^api reference for .* endpoints?$/i.test(fallback)) return null;
    return fallback;
  }

  function stlMethodsMarkdown(items) {
    return items.map(function(item) {
      var line = "- " + item.text;
      if (item.route) line += " (" + item.route + ")";
      if (item.detail) line += ": " + item.detail;
      if (item.groups && item.groups.length) {
        item.groups.forEach(function(group) {
          line += "\n  - " + group.heading + "\n" + stlFieldsMarkdown(group.fields, "    ");
        });
      }
      return line;
    }).join("\n");
  }
