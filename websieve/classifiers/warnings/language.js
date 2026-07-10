  // Language stopword sets for content language detection
  var langStopwords = {
    de: /\b(und|die|der|das|ist|von|zu|mit|den|ein|eine|für|auf|als|auch|nicht|sich|werden|nach|bei|aus|wie|oder|noch|nur|dem|des|über)\b/gi,
    fr: /\b(les|des|une|est|dans|pour|sur|par|pas|qui|que|avec|son|sont|plus|ses|mais|cette|ont|tout|nous|vous|aux|leur)\b/gi,
    es: /\b(los|las|una|del|por|con|para|que|más|son|sus|pero|como|esta|todo|nos|hay|fue|muy|han|sin|sobre|tiene)\b/gi,
    pt: /\b(dos|das|uma|por|com|para|que|mais|são|mas|como|esta|seu|sua|tem|nos|foi|pode|muito|seus|sobre|também)\b/gi,
    pl: /\b(nie|jest|są|się|jak|czy|ale|lub|oraz|tak|ich|jego|już|pod|przy|bez|dla|gdy|gdzie|między|tylko|może|który|która|które|których|którym|którego|którą|ten|ta|tej|tego|tym|tych|przez|dnia|roku|wobec|nadto|ponadto|został|została|był|była|było|były)\b/gi,
    it: /\b(gli|una|del|per|con|che|sono|più|dalla|della|delle|dei|anche|come|questa|tutto|suo|sua|suoi|nelle|alla)\b/gi,
    nl: /\b(een|het|van|zijn|met|dat|voor|maar|niet|ook|als|nog|wel|hun|uit|bij|kan|zou|meer|alle|dit|wordt)\b/gi,
    da: /\b(den|det|til|med|har|som|kan|vil|blev|efter|også|eller|han|hun|var|fra|ved|skal|ikke|mange|denne|blev|over|under)\b/gi,
    sv: /\b(den|det|att|som|har|med|för|kan|och|var|till|från|inte|ska|alla|hon|han|efter|över|under|denna|också|eller|blev)\b/gi,
    no: /\b(den|det|til|med|har|som|kan|vil|ble|etter|også|eller|han|hun|var|fra|ved|skal|ikke|mange|denne|over|under)\b/gi,
    nb: /\b(den|det|til|med|har|som|kan|vil|ble|etter|også|eller|han|hun|var|fra|ved|skal|ikke|mange|denne|over|under)\b/gi,
    fi: /\b(sen|oli|kun|tai|niin|mutta|ovat|joka|myös|kuin|siitä|tämä|hänen|tämän|vain|olla|sillä|sekä|ovat|vielä|nyt|yli|alle)\b/gi,
    tr: /\b(bir|için|ile|olan|olarak|gibi|daha|kadar|ancak|ayrıca|sonra|yapılan|ise|olan|üzerinde|tarafından|büyük|yeni|sonra)\b/gi,
    lv: /\b(par|kas|bet|arī|lai|jau|gan|nav|tad|vai|kur|šis|tās|kā|pie|pēc|tiek|var|būt|kad|vēl|viņa|visi|tikko|savs|kurš)\b/gi,
    lt: /\b(tai|yra|kad|bet|jau|dar|tik|bus|nuo|per|bei|iki|dėl|kas|čia|jis|jos|kur|buvo|labai|arba|dabar|turi|savo|apie)\b/gi,
    ro: /\b(este|sunt|fost|care|dar|sau|mai|pentru|într|cea|cel|acest|după|când|cum|prin|din|lor|avea|fost|toate|poate|doar)\b/gi,
    hr: /\b(koji|koja|koje|biti|nije|kao|ali|ako|više|samo|mogu|nakon|između|tada|sve|još|prije|već|prema|sada|njegov|ovaj)\b/gi,
    sr: /\b(који|која|које|бити|није|као|али|ако|више|само|могу|након|између|тада|све|још|пре|већ|према|сада|његов|овај)\b/gi,
    uk: /\b(що|але|як|або|вже|для|при|без|між|під|над|після|тому|який|яка|яке|його|його|цей|ще|також|може|були|буде)\b/gi,
    bg: /(?:^|\s)(и|в|на|за|с|от|до|е|са|се|че|но|като|през|които|която|което|след|това|също|повече|само|между|тези|всички|може|имат|обаче|когато|върху|срещу)(?=\s|$)/gi,
    el: /\b(και|που|από|στο|στα|στη|στις|στον|στους|για|με|της|του|των|ότι|αυτό|ήταν|είναι|αλλά|μετά|πριν|ακόμα|μπορεί)\b/gi,
    sk: /\b(ktorý|ktorá|ktoré|alebo|jeho|jeho|tento|tiež|môže|boli|bude|keď|pred|všetky|len|ešte|však|medzi|zatiaľ)\b/gi,
    sl: /\b(vendar|ampak|lahko|tudi|pred|vsak|bolj|že|prav|toda|niso|bili|bila|bilo|bodo|oziroma|čeprav|vedno|takoj)\b/gi,
    hu: /\b(hogy|mint|amikor|pedig|csak|volt|lesz|még|vagy|máig|után|előtt|mivel|összes|fogja|ehhez|tehát|viszont|minden)\b/gi,
    cs: /\b(který|která|které|jako|jeho|tento|také|může|byli|bude|když|před|všechny|ještě|pouze|však|mezi|zatím|proto)\b/gi
  };


  function compactNonLatinArticleBody(text) {
    var normalized = normalizeText(text || "");
    if (!normalized || !containsNonLatinScript(normalized)) return false;

    var compact = normalized.replace(/\s/g, "");
    if (compact.length < 60 || compact.length > 2400) return false;

    var words = normalized.split(/\s+/).filter(function(token) { return token.length > 0; }).length;
    if (words <= 1) return true;

    return words < 220 || (compact.length / Math.max(words, 1)) >= 4;
  }

  function bodyMatchesLanguage(langCode, body) {
    if (scriptMatchesLanguage(langCode, body)) return true;

    var pattern = langStopwords[langCode];
    if (!pattern) return true; // Unknown language, assume match
    var matches = body.match(pattern) || [];
    var words = body.split(/\s+/).length;
    var threshold = langCode === "pl" ? 0.025 : 0.03;
    // Expect a small but language-specific share of words to be stopwords.
    return words < 40 || (matches.length / words) >= threshold;
  }

  function scriptMatchesLanguage(langCode, body) {
    var text = normalizeText(body || "");
    if (!text || text.length < 120) return false;

    var compact = text.replace(/\s/g, "");
    if (!compact) return false;

    var pattern = { bg: /[\u0400-\u04FF]/g, el: /[\u0370-\u03FF]/g, sr: /[\u0400-\u04FF]/g, uk: /[\u0400-\u04FF]/g }[langCode];
    if (!pattern) return false;

    return ((compact.match(pattern) || []).length / compact.length) >= 0.25;
  }
