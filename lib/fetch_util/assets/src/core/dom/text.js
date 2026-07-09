  function pageReadableText() {
    if (!document.body) return "";
    var rendered = normalizeText(document.body.innerText || "");
    if (rendered && !/(cookie|privacy|consent|prywatności|datenschutz|données|datos|dati|クッキー|쿠키|同意|隐私|принять|ኩኪ)/i.test(rendered)) return rendered;
    if (rendered && !cookieNoticeText(rendered)) return rendered;

    var clone = safeDeepClone(document.body, document);
    clone.querySelectorAll("script, style, noscript, template, iframe").forEach(function(el) {
      el.remove();
    });
    cleanupCookieChrome(clone);
    return normalizeText(clone.textContent);
  }

  function cookieNoticeText(text) {
    text = normalizeText(text || "").toLowerCase();
    if (!text || text.length > 5000) return false;

    var keywords = /cookie settings|cookie preferences|manage cookie preferences|manage cookies|accept all cookies|reject optional cookies|we use cookies|this website uses cookies|by accepting cookies|allow the use of cookies|privacy choices|privacy preference center|your privacy settings|your privacy choices|manage privacy preferences|manage consent preferences|cookie information|cookie declaration|cookie list|cookies details|list of partners(?: \(vendors\))?|cookies from other companies|essential cookies|personalize advertising|use cookies and similar technologies|before you continue|wish to store and access information|access information on your devices|collect personal data|personalized ads|trusted third party partners|browsing history|device identifiers|cookie declaration last updated|consent id|change your consent|your current state|configurações avançadas de cookies|declaração de cookies|gerenciar cookies|utilizamos cookies|dados pessoais|informazioni sulla vostra privacy|gestisci preferenze consenso|elenco dei cookie|pliki cookie|ustawienia prywatności|polityka prywatności i cookies|datenschutz|cookie-einstellungen|données personnelles|paramètres des cookies|datos personales|configuración de cookies|dati personali|impostazioni dei cookie|preferenze cookie|accetta tutto|クッキー|Cookieプリファレンス|Cookie設定|同意設定|すべて受け入れる|すべて許可|쿠키|동의|모두 허용|全部接受|接受全部|隐私设置|файлы cookie|настройки cookie|принять все|we gebruiken cookies|о вашој приватности|пристанак|колачић|колачиће|подешавања приватности|የእርስዎ ግላዊነት|ግላዊነት|ኩኪ|ኩኪዎች|የኩኪ ቅንብሮች|pro pokračování vyberte|technické cookies|jakou formou vám máme zobrazovat obsah/i;
    if (!keywords.test(text)) return false;

    var hits = text.match(/cookie|cookies|preferences|privacy choices|privacy preference center|your privacy settings|your privacy choices|manage privacy preferences|manage consent preferences|cookie information|cookie declaration|cookie list|cookies details|list of partners|accept all|reject optional|essential cookies|personalize advertising|personal data|browsing history|device identifiers|personalized ads|trusted third party|wish to store|consent id|change your consent|your current state|configurações avançadas de cookies|declaração de cookies|gerenciar cookies|utilizamos cookies|dados pessoais|informazioni sulla vostra privacy|gestisci preferenze consenso|elenco dei cookie|pliki cookie|prywatności|datenschutz|données|datos|dati|クッキー|쿠키|同意|接受|隐私|принять|cookie設定|ግላዊነት|ኩኪ|pokračování|technické cookies/g) || [];
    return hits.length >= 2;
  }

  function legalFooterText(text) {
    text = normalizeText(text || "").toLowerCase();
    if (!text || text.length > 5000) return false;

    var hits = text.match(/copyright|all rights reserved|privacy policy|cookie policy|terms of use|terms and conditions|impressum|link utili|contatti|chi siamo|newsletter|advertising|pubblicit[àa]|manage preferences|cookie settings/g) || [];
    return hits.length >= 2;
  }

  function audioFallbackText(text) {
    return /^your browser doesn't support html5 audio$/i.test(normalizeText(text || ""));
  }

  function videoFallbackText(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    return normalized === "video player is loading." || 
           normalized === "videosoitin" ||
           normalized === "play video" || 
           normalized === "playback speed" || 
           /^playback speed \d/.test(normalized) ||
           /^this is a modal window\./.test(normalized) ||
           /^beginning of dialog window\./.test(normalized) ||
           /^end of dialog window\./.test(normalized) ||
           /^current time\s+\d/.test(normalized) ||
           /^remaining time\s/.test(normalized) ||
           /^duration\s/.test(normalized) ||
           /^loaded:\s*\d/.test(normalized) ||
           /^progress:\s*\d/.test(normalized) ||
           /^fullscreen$/i.test(normalized) ||
             /^mute$/i.test(normalized) ||
             /^unmute$/i.test(normalized);
  }

  function playerControlText(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized || normalized.length > 120) return false;

    return /^(play|pause|resume|volume\s+\d+%|rewind\s+\d+\s+seconds|forward\s+\d+\s+seconds|skip\s+(?:back|forward)|chromecast|closed captions|captions|settings|fullscreen|full screen|mute|unmute|next up|up next|current time\s+\d|remaining time\s+|duration\s+|learn more)$/.test(normalized) ||
      /^\d+:\d+$/.test(normalized);
  }

  function meaningfulButtonText(text) {
    var normalized = normalizeText(text || "");
    if (!normalized) return false;
    if (normalized.length < 30 || normalized.length > 320) return false;
    if (cookieNoticeText(normalized) || utilityHeadingText(normalized) || playerControlText(normalized)) return false;
    if (/^(log in|login|sign in|register|create account|get disney\+|accept all|reject all|confirm my choices|manage preferences|save preferences|allow all|more details|cookies details)$/i.test(normalized)) return false;

    return normalized.split(/\s+/).length >= 4;
  }

  function utilityHeadingText(text) {
    return /^(nearby entries|browse nearby words|cited by|related content|more like this|people also viewed|recommended articles?|translation|numerology|citation|word of the day|quiz|discover more|related posts|latest news|trending now|popular posts|most read|you might also like|you may also like|read more|related articles?|leave a reply|cancel reply|about the authors?|#\s*tags|comments?\s*\d*|also read|further reading|see also|more stories|don't miss|privacy preference center|your privacy settings|manage privacy preferences|manage consent preferences|informazioni sulla vostra privacy|gestisci preferenze consenso|elenco dei cookie|list of partners(?: \(vendors\))?|polecane|przeczytaj (też|również)|podobne (artykuły|wpisy)|leia (também|mais)|artigos? relacionados?|também pode gostar|ähnliche (beiträge|artikel)|das könnte sie auch interessieren|weiterlesen|mehr zum thema|artículos? relacionados?|también te puede interesar|te puede interesar|lee también|noticias relacionadas|articles? (connexes?|similaires?|associée?s?)|à lire aussi|sur le même (sujet|thème)|vous aimerez aussi)$/i.test(text || "") ||
      /^more from /i.test(text || "") ||
      /^popular in /i.test(text || "") ||
      /^browse definitions\.net$/i.test(text || "") ||
      // Arabic / Hebrew / Urdu / Persian sidebar headings
      /^(الأكثر قراءة|الأكثر مشاهدة|الأكثر تعليقاً|مقالات ذات صلة|اقرأ أيضاً|أخبار ذات صلة|مواضيع ذات صلة|موضوعات متعلقة|الأكثر تداولاً|قد يهمك|المزيد|تابع القراءة|הנקראים ביותר|כתבות קשורות|פופולרי|נצפה הכי הרבה|הכי נקראים|مزید پڑھیں|سب سے زیادہ پڑھی جانے والی|متعلقہ خبریں|بیشتر بخوانید|محبوب‌ترین|پربازدیدترین)$/i.test(text || "") ||
      // Turkish sidebar headings
      /^(en çok okunan|ilgili haberler|benzer haberler|popüler haberler|çok okunanlar|ilgili içerikler)$/i.test(text || "") ||
      // Thai sidebar headings
      /^(บทความที่เกี่ยวข้อง|อ่านเพิ่มเติม|ข่าวที่เกี่ยวข้อง|ข่าวยอดนิยม|บทความยอดนิยม|อ่านต่อ|เนื้อหาที่เกี่ยวข้อง|แนะนำสำหรับคุณ|ข่าวล่าสุด)$/i.test(text || "") ||
      // Vietnamese sidebar headings
      /^(bài viết liên quan|tin liên quan|đọc thêm|xem thêm|tin tức liên quan|bài viết nổi bật|có thể bạn quan tâm|tin nổi bật|bài viết mới nhất|đọc nhiều nhất)$/i.test(text || "") ||
      // Greek sidebar headings
      /^(σχετικά άρθρα|διαβάστε (επίσης|ακόμη|περισσότερα)|δημοφιλή άρθρα|περισσότερα νέα|τελευταία νέα|δείτε επίσης|μπορεί να σας ενδιαφέρει|σχετικά νέα|τα πιο δημοφιλή)$/i.test(text || "") ||
      // Ukrainian sidebar headings
      /^(схожі (статті|матеріали|новини)|читайте (також|ще)|також читайте|популярні (статті|новини)|останні новини|найпопулярніше|вас (також )?може зацікавити|рекомендуємо|дивіться також)$/i.test(text || "") ||
      // Indonesian sidebar headings
      /^(baca juga|artikel terkait|berita terkait|berita populer|artikel populer|terpopuler|baca selengkapnya|lihat juga|rekomendasi|berita lainnya|pilihan editor)$/i.test(text || "") ||
      // Dutch sidebar headings
      /^(lees ook|gerelateerde (artikelen|berichten)|ook interessant|meer (lezen|artikelen|nieuws)|populair(st)?e? artikelen|aanbevolen|bekijk ook|misschien vind je dit ook leuk|dit vind je misschien ook interessant|meest gelezen)$/i.test(text || "") ||
      // Serbian sidebar headings (Latin + Cyrillic)
      /^(povezani (članci|tekstovi)|pročitajte (još|i|također)|slični (članci|tekstovi)|popularno|najčitanije|preporučujemo|pogledajte (još|i|takođe)|više vesti|повезани (чланци|текстови)|прочитајте (још|и|такође)|слични (чланци|текстови)|популарно|најчитаније|препоручујемо|погледајте (још|и|такође)|више вести)$/i.test(text || "") ||
      // Malay sidebar headings
      /^(baca juga|artikel berkaitan|berita berkaitan|berita popular|artikel popular|terpopular|baca lagi|lihat juga|cadangan|berita lain|pilihan editor|paling dibaca|trending)$/i.test(text || "") ||
      // Portuguese sidebar headings
      /^(leia (também|mais)|artigos? relacionados?|também pode gostar|mais (lidos?|populares?|notícias)|notícias relacionadas|veja (também|mais)|confira também|continue lendo|recomendado|sugestões?|últimas notícias)$/i.test(text || "") ||
      // Czech sidebar headings
      /^(související (články|zprávy)|čtěte (také|dále|více)|mohlo by vás zajímat|doporučujeme|nejčtenější|nejnovější zprávy|další články|přečtěte si (také|též)|více článků)$/i.test(text || "") ||
      // Swedish sidebar headings
      /^(relaterade (artiklar|nyheter)|läs (också|mer|vidare|även)|mest lästa|populärast|senaste (nyheterna|artiklarna)|fler (artiklar|nyheter)|rekommenderat|du kanske också gillar)$/i.test(text || "") ||
      // Danish sidebar headings
      /^(relaterede (artikler|nyheder)|læs (også|mere|videre)|mest læste|populært|seneste (nyheder|artikler)|flere (artikler|nyheder)|anbefalet|det kunne også interessere dig)$/i.test(text || "") ||
      // Filipino/Tagalog sidebar headings
      /^(kaugnay na (mga )?artikulo|basahin (din|rin)|mga kaugnay na balita|pinaka-?popular|pinakabagong balita|iba pang mga artikulo|maaari mo ring gustuhin)$/i.test(text || "") ||
      // Amharic sidebar headings
      /^(ተዛማጅ ዜናዎች|ተጨማሪ ያንብቡ|ተመልከቱ|ተጨማሪ ዜና|በጣም የተነበቡ|ቀጣይ ዜና)$/i.test(text || "") ||
      // Norwegian sidebar headings
      /^(relaterte (artikler|saker|nyheter)|les (også|mer|videre)|mest lest[e]?|populær[te]?|siste nytt|flere (artikler|saker|nyheter)|anbefalt|aktive debatter|se flere meldinger|du vil kanskje også like)$/i.test(text || "") ||
      // Catalan sidebar headings
      /^(articles? relaciona(ts?|des?)|notícies relacionades|llegeix (també|més)|més (llegits?|populars?|notícies)|últimes notícies|també et pot interessar|contingut relacionat|mostra'n més|temes relacionats)$/i.test(text || "") ||
      // Georgian sidebar headings
      /^(დაკავშირებული (სტატიები|ამბები|სიახლეები)|წაიკითხეთ (ასევე|მეტი)|ყველაზე (წაკითხვადი|პოპულარული)|ბოლო ამბები|მეტი (სტატიები|ამბები)|რეკომენდებული|გაიგეთ მეტი)$/i.test(text || "") ||
      // Sinhala sidebar headings
      /^(සම්බන්ධිත (පුවත්|ලිපි)|තවත් කියවන්න|වැඩි විස්තර|උණුසුම් පුවත්|නවතම පුවත්|ජනප්‍රිය (පුවත්|ලිපි)|වැඩි විස්තර කියවන්න)$/i.test(text || "") ||
      // Azerbaijani sidebar headings
      /^(əlaqəli (xəbərlər|məqalələr)|daha çox oxu(?:yun)?|ən çox oxunan(?:lar)?|son xəbərlər|digər (xəbərlər|məqalələr)|tövsiyə olunan|oxşar xəbərlər)$/i.test(text || "") ||
      // Polish sidebar headings
      /^(powiązane (artykuły|wpisy|tematy|wiadomości)|najczęściej czytane|najpopularniejsze|najnowsze (wiadomości|artykuły)|więcej (artykułów|wpisów|wiadomości)|może cię (też )?zainteresować|zobacz (też|również|także)|czytaj (też|również|także)|warto przeczytać|to też warto przeczytać|to może cię zainteresować|ostatnie (wpisy|artykuły)|popularne (wpisy|artykuły|tematy)|komentarze\s*\d*|dodaj komentarz|zostaw komentarz|napisz komentarz)$/i.test(text || "");
  }
