  function noisePatternSource(parts) {
    return parts.join("|");
  }

  function noiseExactTextPattern(parts, flags) {
    return new RegExp("^(?:" + noisePatternSource(parts) + ")$", flags || "i");
  }

  function noiseLeadingTextPattern(parts, flags) {
    return new RegExp("^(?:" + noisePatternSource(parts) + ")", flags || "i");
  }

  function noiseMarkdownWholeLinePattern(parts, suffix, flags) {
    return new RegExp("^\\s*(?:" + noisePatternSource(parts) + ")" + (suffix || "") + "\\s*$", flags || "gmi");
  }

  function noiseMarkdownPrefixLinePatterns(parts) {
    return parts.map(function(part) {
      return new RegExp("^\\s*(?:" + part + ")\\b.*$", "gmi");
    });
  }

  function noiseMarkdownWholeLinePatterns(parts) {
    return parts.map(function(part) {
      return noiseMarkdownWholeLinePattern([part]);
    });
  }

  var NOISE_AD_LABEL_TERMS = [
    "skip ad", "continue watching", "visit advertiser website", "go to page", "advertisement \\d+\\/\\d+", "advertisement",
    "close ad", "skip this ad", "skip in \\d+", "ad \\d+ of \\d+", "sponsored", "sponsor", "reklama",
    "materiał sponsorowany", "materiał promocyjny", "materiał partnerski", "autopromocja", "ad$",
    "Реклама", "Рекламний блок", "Рекламний матеріал", "Διαφήμιση", "Iklan", "Quảng cáo", "โฆษณา", "Sponsorlu",
    "Reklama?", "Advertentie", "Оглас", "Publicidade", "Anúncio", "Annons", "Annonce", "Reklame", "Annonsørinnhold",
    "Kommersielt innhold", "Contingut patrocinat"
  ];

  var NOISE_MARKDOWN_AD_LABEL_TERMS = [
    "Реклама", "Рекламний блок", "Рекламний матеріал", "Διαφήμιση", "Iklan", "Quảng cáo", "โฆษณา", "Sponsorlu",
    "Reklama?", "Advertentie", "Реклама", "Оглас", "Publicidade", "Anúncio", "Annons", "Annonce", "Reklame", "Annonsørinnhold",
    "Kommersielt innhold", "Contingut patrocinat"
  ];

  var NOISE_AD_NETWORK_HOST_PATTERN = "(?:outbrain|taboola|zemanta|revcontent|mgid|content\\.ad|plista|ligatus|adblade|nativendo|dianomi|nativo|sharethrough|triplelift)\\.(?:com|net|co|io)";
  var NOISE_AD_NETWORK_CONTAINER_TERMS = ["taboola", "outbrain", "promoted-content", "promoted_content", "sponsored-content", "sponsored_content", "mgid", "zergnet", "revcontent"];
  var NOISE_AD_NETWORK_CONTAINER_SELECTOR = "[class*='taboola'], [id*='taboola'], [class*='outbrain'], [id*='outbrain'], [data-widget-type*='taboola'], [data-widget-type*='outbrain'], [class*='promoted-content'], [class*='promoted_content'], [id*='promoted-content'], [class*='sponsored-content'], [class*='sponsored_content'], [class*='mgid'], [id*='mgid'], [class*='zergnet'], [id*='zergnet'], [class*='revcontent'], [id*='revcontent']";
  var NOISE_PROMO_ATTR_TERMS = "ad|ads|advert|advertisement|promo|promoted|sponsor|sponsored|subscription|subscribe|subscriber|paywall|upsell|marketing|newsletter|cta";
  var NOISE_PROMO_TEXT_TERMS = "save\\s+\\d+%|subscribe\\s+(?:now|today)|subscription|subscriber|sign\\s+up\\s+for|get\\s+started\\s+for\\s+free|limited\\s+time\\s+offer|annual\\s+subscriptions?|trusted\\s+destination\\s+for";
  var NOISE_PROMO_MEDIA_TERMS = "ad|ads|advert|promo|sponsor|sponsored|subscription|subscribe|marketing|upsell";

  var NOISE_ACCOUNT_ACTION_TERMS = [
    "report this article", "\\+?\\s*follow", "sign in", "sign up", "join now", "show more", "show less", "log in",
    "create account", "create an account", "subscribe to read", "inloggen", "iniciar sessão", "entrar", "prijavi se", "пријави се",
    "log masuk", "maak een account", "criar conta", "registreer", "cadastre-se", "přihlásit se", "logga in", "log ind",
    "logg inn", "inicia sessió", "iniciar sessió", "giriş yap", "შესვლა", "පිවිසෙන්න", "daxil ol", "zaloguj się",
    "zarejestruj się", "zaloguj", "załóż konto", "moje konto", "dołącz do nas", "zobacz więcej", "czytaj więcej",
    "czytaj dalej", "pokaż więcej", "zwiń", "rozwiń"
  ];

  var NOISE_MARKDOWN_ACCOUNT_CTA_TERMS = [
    "Met een account kan je", "Log in of maak een account", "Acesse seus artigos salvos", "Uma só conta para todos",
    "Maak een account aan", "Cadastre-se", "Faça login", "Faça seu login", "Crie sua conta", "Meld je aan", "Inloggen",
    "Entrar na sua conta", "Sign in to save", "Create an account", "Log in to continue", "Log in", "Sign in", "Create account",
    "Subscribe to read", "Daftar atau masuk", "Giriş yap", "Logg inn", "Opprett konto", "For å kunne lagre", "Inicia sessió",
    "Crea un compte", "Registra't", "පිවිසෙන්න", "ගිණුමක් සාදන්න", "Daxil ol", "Hesab yaradın"
  ];

  var NOISE_SOCIAL_APP_CTA_TERMS = [
    "join (?:us )?on (?:telegram|whatsapp|instagram|facebook|youtube|twitter|x|viber)",
    "follow (?:us )?on (?:telegram|whatsapp|instagram|facebook|youtube|twitter|x|viber)",
    "join (?:our )?(?:telegram|whatsapp|viber) (?:group|channel)", "download (?:our|the) app", "get (?:our|the) app",
    "install (?:our|the) app", "डाउनलोड करें", "ऐप डाउनलोड", "टेलीग्राम", "व्हाट्सएप ग्रुप", "হোয়াটসঅ্যাপ", "টেলিগ্রাম",
    "(?:become|be) a (?:member|subscriber|patron)", "subscribe (?:now|today|here)", "sign up (?:for|to) (?:our )?(?:newsletter|updates|emails?)",
    "get started for free", "サブスクライブ", "구독하기", "підписуйтесь на наш", "приєднуйтесь до нас", "підписатися на телеграм",
    "підписатися на канал", "ακολουθήστε μας", "εγγραφείτε", "ikuti kami di", "gabung (?:di )?(?:telegram|whatsapp)", "berlangganan",
    "ติดตาม(?:เรา)?(?:ที่|ใน|ได้ที่)", "theo dõi chúng tôi", "volg ons", "schrijf je in", "abonneer", "meld je aan", "пратите нас",
    "пријавите се", "претплатите се", "pratite nas", "prijavite se", "pretplatite se", "ikut(?:i)? kami", "langgan", "inscreva-se",
    "siga-nos", "assine", "sledujte nás", "odebírejte", "přihlaste se k odběru", "připojte se", "följ oss", "prenumerera",
    "registrera dig", "følg os", "abonner", "tilmeld dig", "følg oss", "abonner på", "meld deg på", "registrer deg", "subscriu-te",
    "fes-te subscriptor", "fes-te'n subscriptor", "გამოიწერეთ", "შემოგვიერთდით", "მოგვყევით", "අපව අනුගමනය කරන්න",
    "bizə qoşulun", "abunə olun", "bizi izləyin", "subskrybuj", "zasubskrybuj", "zapisz się na newsletter", "dołącz do nas",
    "obserwuj nas", "śledź nas"
  ];

  var NOISE_MARKDOWN_SOCIAL_CTA_SOURCES = [
    "Підписуйтесь на наш|Приєднуйтесь до нас|Підписатися на (?:телеграм|канал)|Читай(?:те)? також у|Ми у (?:телеграмі|фейсбуці|інстаграмі)",
    "Ακολουθήστε μας|Εγγραφείτε", "Ikuti kami di|Gabung (?:di )?(?:Telegram|WhatsApp)|Berlangganan", "Theo dõi chúng tôi",
    "Volg ons|Schrijf je in|Abonneer je|Meld je aan voor", "Пратите нас|Претплатите се|Пријавите се|Pratite nas|Pretplatite se|Prijavite se",
    "Ikuti kami|Langgan(?:i)?|Sertai (?:kami|saluran)", "Siga-nos|Inscreva-se|Assine|Acompanhe-nos",
    "Sledujte nás|Odebírejte|Přihlaste se k odběru|Připojte se", "Följ oss|Prenumerera|Registrera dig", "Følg os|Abonner|Tilmeld dig",
    "Følg oss|Abonner på|Meld deg på|Registrer deg", "Subscriu-te|Fer-se subscriptor|Si ets subscriptor|Suma't a|Quins són els avantatges|Fes-te subscriptor|Fes-te'n subscriptor",
    "გამოიწერეთ|შემოგვიერთდით|მოგვყევით", "වැඩි විස්තර කියවන්න|අපව අනුගමනය කරන්න", "Bizə qoşulun|Abunə olun|Bizi izləyin"
  ];

  var NOISE_MARKDOWN_SOCIAL_APP_CTA_LINE_SOURCES = [
    "(?:Join|Follow)\\s+(?:us\\s+)?on\\s+(?:Telegram|WhatsApp|Instagram|Facebook|YouTube|Twitter|X)",
    "(?:Join|Follow)\\s+(?:our\\s+)?(?:Telegram|WhatsApp)\\s+(?:Group|Channel)",
    "(?:Download|Get|Install)\\s+(?:our|the)\\s+(?:App|Mobile App)"
  ];

  var NOISE_INLINE_CONSENT_PROMPT_SOURCES = [
    "za ogled potrebujemo tvojo privolitev(?: za vstavljanje vsebin družbenih omrežij in tretjih ponudnikov\\.?)?",
    "omogoči piškotke",
    "cookie manager",
    "your cookie preferences",
    "got it!",
    "let us know your cookie preferences",
    "we value your privacy",
    "manage choices",
    "privacy settings",
    "polityka prywatności i cookies",
    "nie widzisz nawet do 30% treści dostępnych w serwisie",
    "data preferences(?:\\s*[\\/|]\\s*|\\s+)manage your data",
    "data preferences",
    "manage your data",
    "manage (?:privacy|cookie|consent|data) preferences",
    "privacy preference center",
    "your privacy settings",
    "your privacy choices",
    "veri tercihleri",
    "nastavení souhlasu",
    "souhlas s personalizací",
    "เว็บไซต์นี้ใช้คุ้กกี้"
  ];

  var NOISE_POLISH_PROMO_CTA_PREFIX_SOURCES = [
    "Subskrybuj|Zasubskrybuj|Zapisz się na newsletter|Dołącz do nas|Obserwuj nas|Śledź nas",
    "Dziękujemy,?\\s*że\\s*przeczytała?(?:ś|ś\\/eś|eś)?", "Bądź na bieżąco", "Obserwuj nas w Google",
    "Dalszy ciąg (?:artykułu|materiału) (?:pod |poniżej )?(?:materiałem wideo|wideo|galerią|zdjęciem)",
    "Sprawdź,?\\s*gdzie kupisz", "Materiał (?:sponsorowany|promocyjny|partnerski)"
  ];

  var NOISE_POLISH_PROMO_CTA_LINE_SOURCES = [
    "Zobacz więcej|Czytaj więcej|Czytaj dalej|Pokaż więcej|Więcej informacji",
    "Zaloguj się|Zarejestruj się|Zaloguj|Załóż konto|Moje konto",
    "Udostępnij|Skomentuj|Komentarze\\s*\\d*|Dodaj komentarz|Napisz komentarz",
    "Autopromocja"
  ];

  var NOISE_RELATED_HEADING_TERMS = [
    "related\\s*(articles?|stories|news|posts|content|links)?", "more\\s*(from|in|stories|articles?|news)", "see\\s*also", "you\\s*may\\s*(also\\s*)?like",
    "recommended", "trending", "popular", "latest\\s*news", "other\\s*news", "also\\s*read", "read\\s*more\\s*:?", "further\\s*reading",
    "references", "citations", "metrics", "altmetric", "więcej\\s*(z\\s*tej\\s*kategorii|artykułów|wiadomości|na\\s*ten\\s*temat)",
    "zobacz\\s*również", "polecamy", "czytaj\\s*również", "inne\\s*wiadomości", "повезано", "погледајте", "сродне\\s*вијести", "слично",
    "такође\\s*прочитајте", "още\\s*от", "виж\\s*също", "свързани\\s*новини", "más\\s*de", "noticias\\s*relacionadas", "ver\\s*también",
    "plus\\s*de", "à\\s*lire\\s*aussi", "lire\\s*aussi", "sur\\s*le\\s*même\\s*sujet", "mehr\\s*aus", "lesen\\s*sie\\s*auch",
    "das\\s*könnte\\s*sie\\s*auch\\s*interessieren", "altre\\s*notizie", "leggi\\s*anche", "ook\\s*interessant", "lees\\s*ook", "läs\\s*också",
    "relateret", "relaterte\\s*saker", "les\\s*også", "aiheeseen\\s*liittyvät", "lue\\s*myös", "ilgili\\s*haberler", "daha\\s*fazla",
    "saistītie", "susijusios\\s*naujienos", "поврзано", "citește\\s*și", "articole\\s*similare", "також\\s*читайте", "схожі\\s*новини",
    "σχετικά\\s*νέα", "διαβάστε\\s*επίσης", "関連記事", "関連ニュース", "おすすめ", "あわせて読みたい", "続きを読む", "更多相关新闻", "相关新闻",
    "相关阅读", "延伸阅读", "관련\\s*기사", "함께\\s*읽기", "اقرأ\\s*أيض[اً]ا", "إقرأ\\s*أيض[اً]ا", "مواضيع\\s*ذات\\s*صلة",
    "أخبار\\s*ذات\\s*صلة", "مطالب\\s*مرتبط", "مطالب\\s*ذات\\s*صلة", "مرتبط", "עוד\\s*כתבות", "כתבות\\s*נוספות",
    "संबंधित\\s*(?:खबरें|लेख)", "और\\s*पढ़ें", "আরও\\s*পড়ুন", "সম্পর্কিত\\s*খবর", "อ่านเพิ่มเติม", "ข่าวที่เกี่ยวข้อง",
    "tin\\s*liên\\s*quan", "đọc\\s*thêm", "baca\\s*juga", "berita\\s*terkait"
  ];
