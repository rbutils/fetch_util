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
    var children = stlDirectChildProperties(block).map(function(child) {
      return stlPropertyFieldSummary(child, depth + 1);
    }).filter(Boolean);

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
      if (group.closest(".stldocs-property")) return;

      var heading = docsScopedFirstText(group, ["h2", "h3", "h4", "summary", "[class*='title']"], ".stldocs-property");
      if (!/\b(parameters?|request|responses?|returns?|body|headers?)\b/i.test(heading)) return;

      var fields = stlDirectChildProperties(group).map(function(child) {
        return stlPropertyFieldSummary(child, 0);
      }).filter(Boolean);
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
      }).filter(Boolean);
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

    return preferred.map(function(item) {
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
