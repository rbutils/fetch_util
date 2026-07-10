  window.hostAwareProfiles = window.hostAwareProfiles || [];

  function defaultContentResult(_metadata) {
    return null;
  }

  window.registerHostAwareProfile = function(condition, fn) {
    hostAwareProfiles.push({ condition: condition, fn: fn });
  };

  function hostAwareProfileMatches(condition, metadata, host) {
    if (condition === true) return true;
    if (condition === false) return false;
    if (typeof condition === "function") return condition(metadata);
    return hostMatches(condition, host);
  }

  function hostAwareContent(metadata, pageText) {
    var host = (metadata && metadata.host) || location.hostname || "";

    for (var i = 0; i < hostAwareProfiles.length; i += 1) {
      var specificProfile = hostAwareProfiles[i];
      if (specificProfile.condition === true) continue;
      if (!hostAwareProfileMatches(specificProfile.condition, metadata, host)) continue;

      var specificResult = specificProfile.fn(metadata, pageText);
      if (specificResult) return specificResult;
    }

    for (var j = 0; j < hostAwareProfiles.length; j += 1) {
      var genericProfile = hostAwareProfiles[j];
      if (genericProfile.condition !== true) continue;
      if (!hostAwareProfileMatches(genericProfile.condition, metadata, host)) continue;

      var genericResult = genericProfile.fn(metadata, pageText);
      if (genericResult) return genericResult;
    }

    return defaultContentResult(metadata);
  }
