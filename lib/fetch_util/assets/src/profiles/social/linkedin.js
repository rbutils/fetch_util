  function linkedinContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)linkedin\.com$/)) return null;

    var pt = bodyInnerText(pageText);
    var isCompanyPage = /^\/company\//.test(location.pathname);
    var isPersonalProfile = /^\/in\//.test(location.pathname);

    if (!isCompanyPage && !isPersonalProfile) return null;

    if (isCompanyPage) {
      var companyName = "";
      var industry = "";
      var companyLocation = "";
      var followerCount = "";
      var aboutText = "";
      var website = "";
      var companySize = "";
      var headquarters = "";
      var companyType = "";
      var specialties = "";
      var founded = "";

      companyName = (metadata.title || "").replace(/\s*[|\-–—]\s*LinkedIn.*$/i, "").trim();

      var followerMatch = pt.match(/([\d,.]+[KMB]?)\s+followers/i);
      if (followerMatch) followerCount = followerMatch[1];

      var aboutMatch = pt.match(/\bAbout\s*\n([\s\S]*?)(?=\n(?:Website|Locations|Employees|Affiliated|Updates|Posts|Similar|Home|Products|Jobs|People|Insights)\b)/i);
      if (aboutMatch) aboutText = normalizeText(aboutMatch[1]);

      var websiteMatch = pt.match(/Website\s*\n\s*(https?:\/\/\S+|[\w.-]+\.[\w]{2,}(?:\/\S*)?)/i);
      if (websiteMatch) website = websiteMatch[1].trim();

      var industryMatch = pt.match(/Industry\s*\n\s*(.+)/i);
      if (industryMatch) industry = normalizeText(industryMatch[1]);
      if (!industry) {
        var headerMatch = pt.match(new RegExp(escapeRegex(companyName) + "\\s*\\n\\s*(.+?)\\s*\\n", "i"));
        if (headerMatch) industry = normalizeText(headerMatch[1]);
      }

      var sizeMatch = pt.match(/Company size\s*\n\s*(.+)/i);
      if (sizeMatch) companySize = normalizeText(sizeMatch[1]);

      var hqMatch = pt.match(/Headquarters\s*\n\s*(.+)/i);
      if (hqMatch) headquarters = normalizeText(hqMatch[1]);

      var typeMatch = pt.match(/Type\s*\n\s*(.+)/i);
      if (typeMatch) companyType = normalizeText(typeMatch[1]);

      var specialtiesMatch = pt.match(/Specialties\s*\n\s*([\s\S]*?)(?=\n\n|\n(?:Website|Locations|Employees|Home|Products|Jobs|People|Insights)\b)/i);
      if (specialtiesMatch) specialties = normalizeText(specialtiesMatch[1]);

      var foundedMatch = pt.match(/Founded\s*\n\s*(\d{4})/i);
      if (foundedMatch) founded = foundedMatch[1];

      if (!companyLocation && headquarters) companyLocation = headquarters;

      var posts = [];
      var updatesSection = pt.match(/(?:Updates|Posts)\s*\n([\s\S]*?)(?=\n(?:Similar pages|Affiliated|People also viewed|Browse jobs)\b|$)/i);
      if (updatesSection) {
        var postBlocks = updatesSection[1].split(/\n(?=.*?\b(?:likes?|comments?|reactions?)\b)/i);
        for (var pi = 0; pi < Math.min(postBlocks.length, 3); pi++) {
          var postText = normalizeText(postBlocks[pi]);
          if (postText && postText.length > 20 && !/^(?:Show|See|Load)\s/i.test(postText)) {
            posts.push(postText.substring(0, 500));
          }
        }
      }

      var details = [];
      if (industry) details.push("Industry: " + industry);
      if (followerCount) details.push("Followers: " + followerCount);
      if (companyLocation) details.push("Location: " + companyLocation);
      if (website) details.push("Website: " + website);
      if (companySize) details.push("Size: " + companySize);
      if (companyType) details.push("Type: " + companyType);
      if (founded) details.push("Founded: " + founded);
      if (headquarters && headquarters !== companyLocation) details.push("Headquarters: " + headquarters);
      if (specialties) details.push("Specialties: " + specialties);
      if (metadata.image) details.push("Image: " + metadata.image);

      var descParts = [];
      if (aboutText) descParts.push(aboutText);
      if (posts.length) descParts.push("## Recent Updates\n\n" + posts.join("\n\n"));

      return articleContentFromParts({
        title: companyName || "LinkedIn Company",
        description: descParts.join("\n\n") || metadata.excerpt || "",
        details: details,
        siteName: "LinkedIn",
        hostAware: true,
        contentType: "article"
      });
    }

    var personName = (metadata.title || "").replace(/\s*[|\-–—]\s*LinkedIn.*$/i, "").trim();
    var personTitle = "";
    var personLocation = "";
    var personFollowers = "";
    var personConnections = "";
    var personAbout = "";

    var namePattern = personName ? new RegExp(escapeRegex(personName) + "\\s*\\n\\s*(.+?)\\s*\\n", "i") : null;
    if (namePattern) {
      var titleMatch = pt.match(namePattern);
      if (titleMatch) personTitle = normalizeText(titleMatch[1]);
    }

    var pFollowerMatch = pt.match(/([\d,.]+[KMB]?)\s+followers/i);
    if (pFollowerMatch) personFollowers = pFollowerMatch[1];

    var connMatch = pt.match(/([\d,.]+\+?)\s+connections?/i);
    if (connMatch) personConnections = connMatch[1];

    var locationLabel = pt.match(/Location\s*\n\s*([A-Z][\w\s,.-]+)/i);
    if (locationLabel) personLocation = normalizeText(locationLabel[1]);

    var aboutMatch = pt.match(/\bAbout\s*\n([\s\S]*?)(?=\n(?:Experience|Education|Skills|Activity|Courses|Articles|Interests|Licenses|Certifications|Recommendations)\b)/i);
    if (aboutMatch) personAbout = normalizeText(aboutMatch[1]);
    personAbout = personAbout.replace(/\s*\.{3}\s*see more\s*$/i, "").replace(/\s*…\s*see more\s*$/i, "");

    var articles = [];
    var activityMatch = pt.match(/(?:Activity|Articles)\s*\n([\s\S]*?)(?=\n(?:Experience|Education|Skills|Interests|Courses|Licenses|Certifications|Recommendations)\b|$)/i);
    if (activityMatch) {
      var actText = activityMatch[1];
      var artMatches = actText.match(/.{20,}(?:\d+\s*(?:likes?|comments?|reactions?|views?))/gi);
      if (artMatches) {
        for (var ai = 0; ai < Math.min(artMatches.length, 3); ai++) {
          articles.push(normalizeText(artMatches[ai]));
        }
      }
    }

    var pDetails = [];
    if (personTitle) pDetails.push("Title: " + personTitle);
    if (personFollowers) pDetails.push("Followers: " + personFollowers);
    if (personConnections) pDetails.push("Connections: " + personConnections);
    if (personLocation) pDetails.push("Location: " + personLocation);
    if (metadata.image) pDetails.push("Image: " + metadata.image);

    var pDescParts = [];
    if (personAbout) pDescParts.push(personAbout);
    if (articles.length) pDescParts.push("## Recent Activity\n\n" + articles.join("\n\n"));

    return articleContentFromParts({
      title: personName || "LinkedIn Profile",
      description: pDescParts.join("\n\n") || metadata.excerpt || "",
      details: pDetails,
      siteName: "LinkedIn",
      hostAware: true,
      contentType: "article"
    });
  }

  function registerLinkedinProfiles() {
    registerHostAwareProfile(true, linkedinContent);
  }
