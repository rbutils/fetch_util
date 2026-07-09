  function recipeStructuredDataContent(metadata) {
    var recipe = structuredDataNode(["Recipe"]);
    if (!recipe) return null;

    var ingredients = asArray(recipe.recipeIngredient).map(function(item) {
      return typeof item === "string" ? normalizeText(item) : entityText(item);
    }).filter(Boolean);
    var instructions = [];

    function collectInstructions(value) {
      if (!value) return;
      if (Array.isArray(value)) {
        value.forEach(collectInstructions);
        return;
      }
      if (typeof value === "string") {
        var text = normalizeText(value);
        if (text) instructions.push(text);
        return;
      }
      if (typeof value !== "object") return;

      if (value.itemListElement) {
        collectInstructions(value.itemListElement);
        return;
      }

      var text = entityText(value);
      if (text) instructions.push(text);
    }

    collectInstructions(recipe.recipeInstructions);

    if (ingredients.length + instructions.length < 3) return null;

    var details = [
      recipe.recipeYield ? "Yield: " + entityText(recipe.recipeYield) : null,
      recipe.prepTime ? "Prep: " + normalizeText(recipe.prepTime) : null,
      recipe.cookTime ? "Cook: " + normalizeText(recipe.cookTime) : null,
      recipe.totalTime ? "Total: " + normalizeText(recipe.totalTime) : null
    ].filter(Boolean);
    var sections = [];
    var title = entityName(recipe.name || recipe.headline) || metadata.title || document.title;
    var description = entityText(recipe.description) || metadata.excerpt;

    if (title) sections.push("# " + title);
    if (details.length) sections.push(details.map(function(item) {
      return "- " + item;
    }).join("\n"));
    if (description) sections.push(description);
    if (ingredients.length) {
      sections.push("## Ingredients\n\n" + ingredients.slice(0, 25).map(function(item) {
        return "- " + item;
      }).join("\n"));
    }
    if (instructions.length) {
      sections.push("## Instructions\n\n" + instructions.slice(0, 20).map(function(item, index) {
        return (index + 1) + ". " + item;
      }).join("\n"));
    }

    var markdown = sections.join("\n\n").trim();

    return {
      title: title,
      byline: entityName(recipe.author) || null,
      excerpt: description || null,
      siteName: metadata.siteName || location.hostname,
      publishedTime: recipe.datePublished || metadata.publishedTime || null,
      ingredients: ingredients,
      instructions: instructions,
      html: "",
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "recipe"
    };
  }
