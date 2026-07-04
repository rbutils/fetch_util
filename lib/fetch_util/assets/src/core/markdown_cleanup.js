  function cleanupMarkdownNoise(markdown) {
    var result = (markdown || "")
      .replace(/Your browser doesn't support HTML5 audio\s*/g, "")
      .replace(/^\s*[-*]\s*$/gm, "")
      .replace(/<iframe\b[^>]*>?(?:<\/iframe>)?/gi, "")
      .replace(/<iframe\b[^\n]*/gi, "")
      .replace(/document\s*\.\s*body\s*\.\s*classList\s*\.\s*add\s*\([^)]*\)\s*;?/g, "")
      .replace(/\biaw\s*\.\s*cmd\s*\.\s*push\s*\([^)]*\)\s*;?/g, "")
      .replace(/\biaw\s*\.\s*display\s*\([^)]*\)\s*;?\s*\}\s*\)\s*;?/g, "")
      .replace(/^\s*(?:var|let|const)\s+\w+\s*=\s*[^;]+;\s*$/gm, "")
      .replace(/\bSkip Ad\b/g, "")
      .replace(/\bContinue watching\s*(?:after the ad)?/gi, "")
      .replace(/Visit Advertiser website/gi, "")
      .replace(/\bExplore\b[^\n]{0,120}S\W*U\W*B\W*S\W*C\W*R\W*I\W*B\W*E\b/gi, "")
      .replace(/\bExplore\b[^\n]{0,100}\bSUBSCRIBE\b/gi, "")
      .replace(/\bExplore\s+[A-Z][A-Za-z0-9 .!&-]{0,80}\d+%\s+SUBSCRIBE\b/gi, "")
      .replace(/\bExplore\s+(?:[A-Z][A-Za-z0-9&.-]+\s+)?\d+%\s+SUBSCRIBE\b/gi, "")
      .replace(/\b\d+%[^\n]{0,60}S\W*U\W*B\W*S\W*C\W*R\W*I\W*B\W*E\b/gi, "")
      .replace(/\b\d+%\s+SUBSCRIBE\b/g, "")
      .replace(/\b[A-Z][A-Za-z0-9 .&-]{1,60}\s+AIchevron_right[A-Z][A-Za-z0-9 .&-]{0,80}\b/g, "")
      .replace(/\b[A-Z][A-Za-z0-9 .&-]{0,60}\s+AI(?:chevron_right)?\s*AI-generated answers? from [^.\n]{0,180}\.\s*AI makes mistakes,?\s*so verify(?: using| with)? [^.\n]{0,160}\.?/g, "")
      .replace(/\bAI-generated answers? from [^.\n]{0,180}\.\s*AI makes mistakes,?\s*so verify(?: using| with)? [^.\n]{0,160}\.?/gi, "")
      .replace(/,?\s*so verify(?: using| with)? [A-Z][A-Za-z0-9 .&-]{0,80} articles\.?/g, "")
      .replace(/GO TO PAGE\.?/g, "")
      .replace(/^\s*#{1,6}\s*$/gm, "")
      .replace(/\bAdvertisement\s+\d+\/\d+\b/gi, "")
      .replace(/^\s*Advertisement\s*$/gmi, "")
      // Strip multilingual ad labels
      .replace(/^\s*(?:Реклама|Рекламний блок|Рекламний матеріал|Διαφήμιση|Iklan|Quảng cáo|โฆษณา|Sponsorlu|Reklama?|Advertentie|Реклама|Оглас|Publicidade|Anúncio|Annons|Annonce|Reklame|Annonsørinnhold|Kommersielt innhold|Contingut patrocinat)\s*:?\s*$/gmi, "")
      .replace(/Definition Source\s+All sources\s+\w+/gi, "")
      .replace(/^.*\bdebug info:.*(?:\n.*(?:fetchCache|expirationTime|cache key|seconds remaining|All fetchCache).*)*$/gmi, "")
      .replace(/!\[close\]\([^)]*(?:close|cross)[^)]*\)/gi, "")
      .replace(/^\s*#\s*Tags?\s*$/gmi, "")
      .replace(/^\s*Comments?\s*\d*\s*$/gmi, "")
      .replace(/^\s*Leave a Reply\s*(?:Cancel reply)?\s*$/gmi, "")
      .replace(/^\s*Loading comments\.*\s*$/gmi, "")
      // Strip video player UI controls that leaked into content
      .replace(/Current Time\s+\d+:\d+\s*/gi, "")
      .replace(/Duration\s+[-\\]?:?[-\\]?\s*/gi, "")
      .replace(/Remaining Time\s+-?\d+:\d+\s*/gi, "")
      .replace(/Loaded:\s*\d+%?\s*/gi, "")
      .replace(/Progress:\s*\d+%?\s*/gi, "")
      .replace(/^\s*Volume\s+\d+%\s*$/gmi, "")
      .replace(/^\s*Rewind\s+\d+\s+Seconds\s*$/gmi, "")
      .replace(/^\s*Chromecast\s*$/gmi, "")
      .replace(/^\s*Closed Captions\s*$/gmi, "")
      .replace(/^\s*Settings\s*$/gmi, "")
      .replace(/^\s*Fullscreen\s*$/gmi, "")
      .replace(/^\s*Learn More\s*$/gmi, "")
      .replace(/^\s*This website uses cookies\..*$/gmi, "")
      .replace(/^\s*By accepting cookies.*$/gmi, "")
      .replace(/^\s*Cookie declaration last updated.*$/gmi, "")
      .replace(/^\s*Consent ID:.*$/gmi, "")
      .replace(/^\s*Change your consent.*$/gmi, "")
      .replace(/^\s*Your current state:.*$/gmi, "")
      .replace(/^\s*(?:Necessary|Preference|Statistics|Marketing)\s*\(\d+\)\s*$/gmi, "")
      .replace(/^\s*Video Player is loading\.\s*$/gmi, "")
      .replace(/^\s*Play Video\s*$/gmi, "")
      .replace(/^\s*Playback Speed\s*$/gmi, "")
      // Strip social/app download CTAs
      .replace(/^\s*(?:Join|Follow)\s+(?:us\s+)?on\s+(?:Telegram|WhatsApp|Instagram|Facebook|YouTube|Twitter|X)\s*$/gmi, "")
      .replace(/^\s*(?:Join|Follow)\s+(?:our\s+)?(?:Telegram|WhatsApp)\s+(?:Group|Channel)\s*$/gmi, "")
      .replace(/^\s*(?:Download|Get|Install)\s+(?:our|the)\s+(?:App|Mobile App)\s*$/gmi, "")
      // Strip multilingual social/channel promo CTAs
      .replace(/^\s*(?:Підписуйтесь на наш|Приєднуйтесь до нас|Підписатися на (?:телеграм|канал)|Читай(?:те)? також у|Ми у (?:телеграмі|фейсбуці|інстаграмі))\b.*$/gmi, "")
      .replace(/^\s*(?:Ακολουθήστε μας|Εγγραφείτε)\b.*$/gmi, "")
      .replace(/^\s*(?:Ikuti kami di|Gabung (?:di )?(?:Telegram|WhatsApp)|Berlangganan)\b.*$/gmi, "")
      .replace(/^\s*(?:Theo dõi chúng tôi)\b.*$/gmi, "")
      // Strip Dutch social/newsletter CTAs
      .replace(/^\s*(?:Volg ons|Schrijf je in|Abonneer je|Meld je aan voor)\b.*$/gmi, "")
      // Strip Serbian social/newsletter CTAs (Latin + Cyrillic)
      .replace(/^\s*(?:Пратите нас|Претплатите се|Пријавите се|Pratite nas|Pretplatite se|Prijavite se)\b.*$/gmi, "")
      // Strip Malay social/newsletter CTAs
      .replace(/^\s*(?:Ikuti kami|Langgan(?:i)?|Sertai (?:kami|saluran))\b.*$/gmi, "")
      // Strip Portuguese social/newsletter CTAs
      .replace(/^\s*(?:Siga-nos|Inscreva-se|Assine|Acompanhe-nos)\b.*$/gmi, "")
      // Strip Czech social/newsletter CTAs
      .replace(/^\s*(?:Sledujte nás|Odebírejte|Přihlaste se k odběru|Připojte se)\b.*$/gmi, "")
      // Strip Swedish social/newsletter CTAs
      .replace(/^\s*(?:Följ oss|Prenumerera|Registrera dig)\b.*$/gmi, "")
      // Strip Danish social/newsletter CTAs
      .replace(/^\s*(?:Følg os|Abonner|Tilmeld dig)\b.*$/gmi, "")
      // Strip Norwegian social/newsletter CTAs
      .replace(/^\s*(?:Følg oss|Abonner på|Meld deg på|Registrer deg)\b.*$/gmi, "")
      // Strip Catalan subscription/paywall CTAs
      .replace(/^\s*(?:Subscriu-te|Fer-se subscriptor|Si ets subscriptor|Suma't a|Quins són els avantatges|Fes-te subscriptor|Fes-te'n subscriptor)\b.*$/gmi, "")
      // Strip Georgian social/newsletter CTAs
      .replace(/^\s*(?:გამოიწერეთ|შემოგვიერთდით|მოგვყევით)\b.*$/gmi, "")
      // Strip Sinhala "read more" / social CTAs
      .replace(/^\s*(?:වැඩි විස්තර කියවන්න|අපව අනුගමනය කරන්න)\b.*$/gmi, "")
      // Strip Azerbaijani social/newsletter CTAs
      .replace(/^\s*(?:Bizə qoşulun|Abunə olun|Bizi izləyin)\b.*$/gmi, "")
      // Strip Polish reader/article CTAs and promo noise
      .replace(/^\s*(?:Subskrybuj|Zasubskrybuj|Zapisz się na newsletter|Dołącz do nas|Obserwuj nas|Śledź nas)\b.*$/gmi, "")
      .replace(/^\s*(?:Dziękujemy,?\s*że\s*przeczytała?(?:ś|ś\/eś|eś)?)\b.*$/gmi, "")
      .replace(/^\s*(?:Bądź na bieżąco)\b.*$/gmi, "")
      .replace(/^\s*(?:Obserwuj nas w Google)\b.*$/gmi, "")
      .replace(/^\s*(?:Zobacz więcej|Czytaj więcej|Czytaj dalej|Pokaż więcej|Więcej informacji)\s*$/gmi, "")
      .replace(/^\s*(?:Dalszy ciąg (?:artykułu|materiału) (?:pod |poniżej )?(?:materiałem wideo|wideo|galerią|zdjęciem))\b.*$/gmi, "")
      .replace(/^\s*(?:Sprawdź,?\s*gdzie kupisz)\b.*$/gmi, "")
      .replace(/^\s*(?:Zaloguj się|Zarejestruj się|Zaloguj|Załóż konto|Moje konto)\s*$/gmi, "")
      .replace(/^\s*(?:Udostępnij|Skomentuj|Komentarze\s*\d*|Dodaj komentarz|Napisz komentarz)\s*$/gmi, "")
      .replace(/^\s*(?:Materiał (?:sponsorowany|promocyjny|partnerski))\b.*$/gmi, "")
      .replace(/^\s*(?:Autopromocja)\s*$/gmi, "")
      // Strip docs chrome/control labels that leak as standalone lines
      .replace(/^\s*(?:Skip to main content|Skip to content|View on GitHub|Report a problem with this content|Copy item path|Open menu|Open Sidebar|Search or ask Copilot|API preferences|JavaScriptTypeScript|TypeScriptJavaScript)\s*$/gmi, "")
      // Strip breadcrumb separator artifacts (e.g. "/ " followed by "* * *")
      .replace(/^\s*\/\s*$/gm, "")
      .replace(/^\s*\*\s+\*\s+\*\s*$/gm, "")
      // Strip leaked sidebar/toggle text from docs engines
      .replace(/^\s*(?:show sidebar|hide sidebar|toggle sidebar|show attributes?|hide attributes?|show child attributes?|hide child attributes?)\s*$/gmi, "")
      // Strip inline toggle text from Elastic docs (e.g., "...link Hide attributes Show attributes")
      .replace(/\s+(?:Hide|Show)\s+(?:child\s+)?attributes?\s+(?:Hide|Show)\s+(?:child\s+)?attributes?\s*$/gm, "")
      // Strip "Stay organized with collections" Devsite chrome
      .replace(/Stay organized with collections\s*Save and categorize content based on your preferences\.?\s*/gi, "")
      // Strip empty markdown links [](url) that are anchor-ID placeholders
      .replace(/!\[]\([^)]+\)\s*/g, "")
      .replace(/\[]\([^)]+\)\s*/g, "")
      // Strip oversized inline data images, which are usually error-page artwork or placeholders.
      .replace(/!\[[^\]]*\]\(data:image\/(?:png|gif|jpe?g|webp);base64,[A-Za-z0-9+/=]{500,}\)\s*/gi, "")
      // Card grids can place image-only media before headings inside list items.
      .replace(/^\s*([-*])\s+\[(?:!\[[^\]]*\]\([^)]+\)\s*)?\n+\s*#{1,6}\s*([^\n]+)\n+\s*\]\(([^)]+)\)/gm, "$1 [$2]($3)")
      .replace(/^(\s*[-*]\s*)!#{1,6}\s*/gm, "$1")
      .replace(/^(\s*[-*]\s*)#{1,6}\s*/gm, "$1")
      // Repair or remove orphan card-link fragments from nested image/title anchors.
      .replace(/^\s*\[\s*\n+\s*(#{1,6})\s+([^\n]+)\n+\s*\]\((https?:\/\/[^)]+)\)\s*$/gm, "$1 [$2]($3)")
      .replace(/^\s*\]\((https?:\/\/[^)]+)\)\[\s*\n+\s*([^\n\[\]#][^\n]*)\n+\s*\]\(\1\)\s*$/gm, "[$2]($1)")
      .replace(/^\s*\[\s*$/gm, "")
      .replace(/^\s*\]\(https?:\/\/[^)]+\)\[?\s*$/gm, "")
      .replace(/^\s*\]\s*$/gm, "")
      // Legal citations often italicize section letters; de-emphasize those compact code-like tokens.
      .replace(/\[([^\]]*\d)\]\(([^)]*\/section-[^)]+)\)_([a-z])_\\?-([0-9])/gi, "[$1$3-$4]($2)")
      .replace(/\[(\d+)\]\(([^)]*\/link\/uscode\/[^)]+)\)_([a-z])_/gi, "[$1$3]($2)")
      .replace(/(\b\d+)_([a-z])_,_/gi, "$1$2,")
      .replace(/(\b\d+)_([a-z])_\\?-/gi, "$1$2-")
      .replace(/(\b\d+)_([a-z])_(?=[\s),.;])/gi, "$1$2")
      // Strip "Last modified" footer lines
      .replace(/^\s*Last modified\s+\w+\s+\d{1,2},\s+\d{4}.*$/gmi, "")
      // Strip account/login CTA text that leaks repeatedly
      .replace(/^\s*(?:Met een account kan je|Log in of maak een account|Acesse seus artigos salvos|Uma só conta para todos|Maak een account aan|Cadastre-se|Faça login|Faça seu login|Crie sua conta|Meld je aan|Inloggen|Entrar na sua conta|Sign in to save|Create an account|Log in to continue|Daftar atau masuk|Giriş yap|Logg inn|Opprett konto|For å kunne lagre|Inicia sessió|Crea un compte|Registra't|පිවිසෙන්න|ගිණුමක් සාදන්න|Daxil ol|Hesab yaradın)\b.*$/gmi, "")
      // Drop literal JS placeholder text from image/link titles and image alt labels.
      .replace(/(!?\[[^\]\n]*\]\([^\)\s]+)\s+"[^"\n]*\bundefined\b[^"\n]*"\)/gi, "$1)")
      .replace(/!\[\s*undefined\s*\]\(([^)]+)\)/gi, "![]($1)")
      // Strip HTML comment artifacts that bleed through
      .replace(/\s*-->\s*/g, " ")
      .replace(/\s*<!--\s*/g, " ")
      // Strip image gallery pagination counters (e.g. "1 14", "2 14" between images)
      .replace(/(?:^|\n)\s*\d{1,3}\s+\d{1,3}\s*(?:\n|$)/g, "\n")
      // Strip markdown links pointing to ad/tracking redirect domains (Outbrain, Taboola, etc.)
      // These leak through when the ad widget's container isn't caught by class/id stripping
      .replace(/\[([^\]]*)\]\(https?:\/\/(?:[a-z0-9-]+\.)*(?:outbrain|taboola|zemanta|revcontent|mgid|content\.ad|plista|ligatus|adblade|nativendo|dianomi|nativo|sharethrough|triplelift)\.(?:com|net|co|io)\/[^)]*\)/gi, "")
      // Strip standalone lines that are just ad-network URLs without markdown link syntax
      .replace(/^\s*https?:\/\/(?:[a-z0-9-]+\.)*(?:outbrain|taboola|zemanta|revcontent|mgid|content\.ad|plista|ligatus|adblade|nativendo|dianomi|nativo|sharethrough|triplelift)\.(?:com|net|co|io)\b[^\n]*$/gmi, "")
      .replace(/\n{3,}/g, "\n\n")
      .trim();

    result = stripTrailingArticlePromoTail(result);

    result = result.split("\n").map(function(line) {
      if (line.length < 120 || /\[[^\]]+\]\([^)]+\)/.test(line)) return line;
      return line.replace(/(.{50,300}?[.!?])(?:\s*\1)+/g, "$1");
    }).join("\n");

    // Deduplicate consecutive identical lines (collapse runs of 3+ identical lines to one)
    var lines = result.split("\n");
    var deduped = [];
    var prevLine = null;
    var runCount = 0;
    for (var i = 0; i < lines.length; i++) {
      var trimmed = lines[i].trim();
      if (trimmed === prevLine && trimmed.length > 0) {
        runCount++;
        if (runCount < 2) deduped.push(lines[i]);
        // Skip lines beyond the 2nd consecutive duplicate
      } else {
        prevLine = trimmed;
        runCount = 1;
        deduped.push(lines[i]);
      }
    }
    result = deduped.join("\n");

    // Collapse non-consecutive duplicate lines: if the same non-empty, non-heading line
    // appears 4+ times total in the document, keep only the first occurrence
    lines = result.split("\n");
    var lineCounts = {};
    for (var j = 0; j < lines.length; j++) {
      var key = lines[j].trim();
      if (key.length > 0 && !/^#{1,6}\s/.test(key)) {
        lineCounts[key] = (lineCounts[key] || 0) + 1;
      }
    }
    var lineSeen = {};
    var filtered = [];
    for (var k = 0; k < lines.length; k++) {
      var lineKey = lines[k].trim();
      if (lineKey.length > 0 && !/^#{1,6}\s/.test(lineKey) && (lineCounts[lineKey] || 0) >= 4) {
        if (!lineSeen[lineKey]) {
          lineSeen[lineKey] = true;
          filtered.push(lines[k]);
        }
        // Skip subsequent duplicates
      } else {
        filtered.push(lines[k]);
      }
    }

    return filtered.join("\n").replace(/\n{3,}/g, "\n\n").trim();
  }

  function stripTrailingArticlePromoTail(markdown) {
    var text = markdown || "";
    if (text.length < 300) return text;

    var cutoff = Math.floor(text.length * 0.35);
    var markers = [
      /Was (?:this )?(?:summary |article |page )?helpful\?\s+Thank you\s+(?:for\s+)?feedback/i,
      /Trusted by Consumers\.\s+Recognized by AI\./i,
      /(?:^|\n|\s{2,})(?:AI[-\s]generated summary|AI summary|Related content|You May Also Like|Need (?:to )?Find (?:an? )?Attorney\?|For Legal Professionals|Get updates)\b/i
    ];
    var trimAt = -1;

    markers.forEach(function(pattern) {
      var match;
      var regex = new RegExp(pattern.source, pattern.flags.indexOf("g") >= 0 ? pattern.flags : pattern.flags + "g");
      while ((match = regex.exec(text)) !== null) {
        if (match.index >= cutoff && (trimAt < 0 || match.index < trimAt)) trimAt = match.index;
        if (match.index === regex.lastIndex) regex.lastIndex += 1;
      }
    });

    return trimAt >= 0 ? text.slice(0, trimAt).trim() : text;
  }
