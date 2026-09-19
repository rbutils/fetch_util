  var STRUCTURED_CARD_FIELD_MARKER = (function() {
    var values = new Uint32Array(4);
    crypto.getRandomValues(values);
    return "\uE000fetch-util-card-field:" + Array.from(values).map(function(value) {
      return value.toString(16).padStart(8, "0");
    }).join("") + ":";
  })();

  function stripStructuredCardFieldMarkers(markdown) {
    return String(markdown || "").split(STRUCTURED_CARD_FIELD_MARKER).join("");
  }

  function structuredCardLinkEvidence(link) {
    if (!link || !link.matches("a[href]") || !materializedHttpUrl(link.getAttribute("href"))) return null;
    if (link.querySelector("a[href], h1, h2, h3, h4, h5, h6, ul, ol, table, pre, form, button, input, select, textarea")) return null;

    var fields = Array.from(link.querySelectorAll("[class], [id], [data-field], [itemprop]"));
    var titles = fields.filter(function(node) {
      var evidence = [node.className, node.id, node.getAttribute("data-field"), node.getAttribute("itemprop")]
        .join(" ").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
      var text = normalizeText(node.textContent || "");
      return evidence.some(function(token) { return token === "title" || token === "headline"; }) &&
        text.length >= 10 && text.length <= 260 && !node.querySelector("div, p, article, section, li");
    });
    var labels = fields.filter(function(node) {
      var evidence = [node.className, node.id, node.getAttribute("data-field"), node.getAttribute("itemprop")]
        .join(" ").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
      var text = normalizeText(node.textContent || "");
      return evidence.some(function(token) {
        return ["category", "eyebrow", "kicker", "label", "section", "type"].indexOf(token) !== -1;
      }) && !evidence.some(function(token) {
        return ["created", "date", "published", "time"].indexOf(token) !== -1;
      }) && !node.matches("time") && !node.querySelector("time") &&
        text.length > 0 && text.length <= 80 && !node.querySelector("div, p, article, section, li");
    });
    var dates = Array.from(link.querySelectorAll("time")).filter(function(node) {
      var text = normalizeText(node.textContent || "");
      return text.length > 0 && text.length <= 80;
    });
    var images = Array.from(link.querySelectorAll("img[src]"));
    if (titles.length !== 1 || labels.length !== 1 || dates.length !== 1 || images.length !== 1) return null;

    return {
      label: labels[0],
      title: titles[0],
      titleText: normalizeText(titles[0].textContent || ""),
      url: materializedHttpUrl(link.getAttribute("href"))
    };
  }

  function structuredCardBranch(owner, article) {
    var branch = article;
    while (branch && branch.parentElement !== owner) branch = branch.parentElement;
    return branch && branch.parentElement === owner ? branch : null;
  }

  function structuredCardOwnerLinkCounts(root, ownerMembers) {
    var counts = new Map(), total = 0;
    function visit(node) {
      var start = total;
      if (node.matches("article > a[href]")) total += 1;
      Array.from(node.children).forEach(visit);
      if (ownerMembers.has(node)) counts.set(node, total - start);
    }
    visit(root);
    return counts;
  }

  function structuredCardGroupMaps(root, candidates) {
    var ownerMembers = new Map();
    candidates.forEach(function(candidate) {
      var owner = candidate.article.parentElement;
      for (var depth = 0; owner && depth < 2; depth += 1, owner = owner.parentElement) {
        if (owner.matches("html, body")) break;
        var members = ownerMembers.get(owner) || [];
        members.push(candidate);
        ownerMembers.set(owner, members);
      }
    });
    return {
      ownerMembers: ownerMembers,
      ownerLinkCounts: structuredCardOwnerLinkCounts(root, ownerMembers),
      ownerGroups: new Map()
    };
  }

  function structuredCardGroupOwner(article, groupMaps) {
    var owner = article.parentElement;
    for (var depth = 0; owner && depth < 2; depth += 1, owner = owner.parentElement) {
      if (owner.matches("html, body")) return null;
      if (!groupMaps.ownerGroups.has(owner)) {
        var members = groupMaps.ownerMembers.get(owner) || [];
        var validOwner = null;
        if (members.length >= 2 && groupMaps.ownerLinkCounts.get(owner) === members.length) {
          var branches = members.map(function(candidate) {
            return structuredCardBranch(owner, candidate.article);
          });
          if (!branches.some(function(branch) { return !branch; }) && new Set(branches).size === members.length) {
            validOwner = owner;
          }
        }
        groupMaps.ownerGroups.set(owner, validOwner);
      }
      if (groupMaps.ownerGroups.get(owner)) return owner;
    }
    return null;
  }

  function preserveStructuredCardLinks(root) {
    root.querySelectorAll("[data-fetch-util-structured-card-field]").forEach(function(node) {
      node.removeAttribute("data-fetch-util-structured-card-field");
    });
    var candidates = [];
    root.querySelectorAll("article > a[href]").forEach(function(link) {
      var article = link.parentElement;
      if (!article || article.children.length !== 1) return;
      var evidence = structuredCardLinkEvidence(link);
      if (!evidence) return;
      candidates.push({ article: article, link: link, evidence: evidence });
    });
    var groupMaps = structuredCardGroupMaps(root, candidates);
    var groups = new Map();
    candidates.forEach(function(candidate) {
      var owner = structuredCardGroupOwner(candidate.article, groupMaps);
      if (!owner) return;
      var records = groups.get(owner) || [];
      records.push(candidate);
      groups.set(owner, records);
    });

    groups.forEach(function(records) {
      if (records.length < 2) return;
      if (new Set(records.map(function(record) { return record.evidence.url; })).size !== records.length) return;
      if (new Set(records.map(function(record) { return record.evidence.titleText; })).size !== records.length) return;

      records.forEach(function(record) {
        var link = record.link;
        record.evidence.label.setAttribute("data-fetch-util-structured-card-field", "");
        var title = record.evidence.title;
        var parent = link.parentNode;
        var href = link.getAttribute("href");
        var declaredTitle = link.getAttribute("title");
        while (link.firstChild) parent.insertBefore(link.firstChild, link);
        link.remove();

        var titleLink = document.createElement("a");
        titleLink.setAttribute("href", href);
        if (declaredTitle) titleLink.setAttribute("title", declaredTitle);
        while (title.firstChild) titleLink.appendChild(title.firstChild);
        title.appendChild(titleLink);
      });
    });
  }
