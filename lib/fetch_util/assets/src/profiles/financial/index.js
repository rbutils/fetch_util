  function registerFinancialProfiles() {
    registerHostAwareProfile(/(^|\.)sec\.gov$/i, secEdgarFilingContent);
  }
