# frozen_string_literal: true

RSpec.describe 'FetchUtil NewsIT extractor integration' do
  include_context 'extractor integration helpers'

  it 'extracts NewsIT article bodies without false mismatch or multi-topic warnings' do
    html = <<~HTML
      <html lang="el">
        <head>
          <title>Βίντεο και φωτογραφίες από την υποδοχή έκπληξη του Ερντογάν στον Τραμπ</title>
          <meta property="og:site_name" content="NewsIT">
          <meta name="description" content="Γέλια και χειραψίες ανάμεσα στους δύο ηγέτες.">
        </head>
        <body class="single-post">
          <header>
            <h1 class="entry-title">Βίντεο και φωτογραφίες από την υποδοχή έκπληξη του Ερντογάν στον Τραμπ</h1>
            <div class="article-excerpt">Γέλια και χειραψίες ανάμεσα στους δύο ηγέτες - Υποδοχή με ισχυρό συμβολισμό</div>
          </header>
          <main class="main-content column gap-md">
            <article id="post-4722536" class="post type-post status-publish category-kosmos">
              <div class="share-inside-the-content">Share Tweet WhatsApp</div>
              <div class="inside-article column start-center gap-md">
                <a href="https://www.google.com/preferences/source?q=newsit.gr">Προσθήκη του newsit.gr ως προτεινόμενη πηγή στην Google</a>
                <div class="entry-content">
                  <section>
                    <p>Η άφιξη του <a href="https://www.newsit.gr/tags/ntonalnt-tramp/">Ντόναλντ Τραμπ</a> στην Τουρκία για τη Σύνοδο Κορυφής του ΝΑΤΟ συνοδεύτηκε από μια εικόνα που δεν περνά απαρατήρητη.</p>
                    <p>Ο πρόεδρος της Τουρκίας Ρετζέπ Ταγίπ Ερντογάν βρέθηκε ο ίδιος στο αεροδρόμιο της Άγκυρας για να υποδεχθεί τον Αμερικανό ομόλογό του.</p>
                    <div class="advert-block"><p>ΔΙΑΦΗΜΙΣΗ</p></div>
                    <figure><img src="/wp-content/uploads/2026/07/gelia-1200x800.jpg" alt="REUTERS"><figcaption>REUTERS/Jonathan Ernst</figcaption></figure>
                    <p>Η στιγμή αποκτά ακόμη μεγαλύτερη βαρύτητα καθώς η Σύνοδος του ΝΑΤΟ πραγματοποιείται σε μια περίοδο έντονων συζητήσεων για το μέλλον της Συμμαχίας.</p>
                    <blockquote class="twitter-tweet"><p>JUST IN: President Trump stepped off Air Force One in Turkey.</p></blockquote>
                    <p>Το κλίμα ήταν ιδιαίτερα εγκάρδιο με γέλια και χειραψίες ανάμεσα στους δύο ηγέτες.</p>
                  </section>
                </div>
              </div>
            </article>
            <article class="round-box"><h2>Άλλη είδηση με διαφορετικό θέμα</h2></article>
          </main>
        </body>
      </html>
    HTML

    url = 'https://www.newsit.gr/kosmos/vinteo-kai-fotografies-apo-tin-ypodoxi-ekpliksi-tou-erntogan-ston-tramp-stin-agkyra-ton-epiase-agkaze-sto-galazio-xali-kai-to-hello-soldier/4722536/'

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, 'article')
      expect(payload['markdown']).to include('Η άφιξη του Ντόναλντ Τραμπ στην Τουρκία')
      expect(payload['markdown']).to include('Το κλίμα ήταν ιδιαίτερα εγκάρδιο')
      expect(payload['markdown']).not_to include('Προσθήκη του newsit.gr')
      expect(payload['markdown']).not_to include('ΔΙΑΦΗΜΙΣΗ')
      expect(payload['markdown']).not_to include('JUST IN')
      expect(payload['markdown']).not_to include('Άλλη είδηση')
      expect_warnings(payload, exclude: %w[empty_extraction short_extraction url_content_mismatch multi_topic_page consent_interstitial])
      expect(payload['suspect']).to be(false)
    end
  end
end
