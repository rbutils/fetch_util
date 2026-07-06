# frozen_string_literal: true

RSpec.describe 'FetchUtil extractor integration' do
  include_context 'extractor integration helpers'

  it "extracts offered Le Monde articles without a paywall false positive" do
    html = <<~HTML
      <html lang="fr">
        <head>
          <title>La France bascule dans une nouvelle vague de chaleur caniculaire, avec des pics à 40 °C</title>
          <meta property="og:site_name" content="Le Monde">
          <meta name="description" content="Le troisième épisode caniculaire de l’année s’annonce intense et durable.">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"NewsArticle","headline":"La France bascule dans une nouvelle vague de chaleur caniculaire, avec des pics à 40 °C","isAccessibleForFree":"False"}
          </script>
        </head>
        <body>
          <div id="js-modal-gifted-url" class="article__gift-modal">
            <p>Cet article vous est offert</p>
            <p>Pour lire gratuitement cet article réservé aux abonnés, connectez-vous</p>
          </div>
          <main id="ds-anchor-target-content">
            <h1 class="article__title">La France bascule dans une nouvelle vague de chaleur caniculaire, avec des pics à 40 °C</h1>
            <p class="article__desc">Provoquée par un anticyclone au large du Portugal et des îles britanniques, la chaleur s’est installée lundi dans une large partie du territoire.</p>
            <p class="article__author">Audrey Garric</p>
            <article class="article__content old__article-content-single">
              <figure class="article__media"><img src="heatwave.jpg" alt="A Bordeaux, le 6 juillet 2026"><figcaption>A Bordeaux, le 6 juillet 2026, alors que la France connaît une nouvelle vague de chaleur.</figcaption></figure>
              <p class="article__paragraph">Les Français n’ont presque pas eu le temps de ranger les ventilateurs. Moins d’une semaine après la fin de la canicule historique de juin, le pays bascule officiellement dans une nouvelle vague de chaleur.</p>
              <p class="article__paragraph">Cette surchauffe s’annonce intense et durable, probablement autour d’une douzaine de jours. Ce troisième épisode caniculaire de l’année mettra de nouveau à rude épreuve les organismes.</p>
              <p class="article__paragraph">De nouveau, le thermomètre s’affole. Les 40 °C seront atteints dans de nombreuses régions du Sud et de l’Ouest.</p>
            </article>
            <section class="paywall js-paywall">
              <p>La suite est réservée à nos abonnés.</p>
              <a id="js-paywall-subscribtion" href="https://abo.lemonde.fr/">Découvrir nos offres</a>
            </section>
          </main>
        </body>
      </html>
    HTML

    url = "https://www.lemonde.fr/planete/article/2026/07/06/" \
          "la-france-bascule-dans-une-nouvelle-vague-de-chaleur-caniculaire-avec-des-pics-a-40-c_6721222_3244.html"

    extract_from_url(url, html) do |payload|
      expect_content_type(payload, "article")
      expect(payload["markdown"]).to include("# La France bascule dans une nouvelle vague de chaleur caniculaire")
      expect(payload["markdown"]).to include("Les Français n’ont presque pas eu le temps de ranger les ventilateurs")
      expect(payload["markdown"]).not_to include("Cet article vous est offert")
      expect(payload["markdown"]).not_to include("La suite est réservée")
      expect_warnings(payload, exclude: %w[paywall_partial_content empty_extraction short_extraction url_content_mismatch consent_interstitial])
      expect(payload["suspect"]).to be(false)
    end
  end

  it "keeps the paywall warning for non-offered Le Monde teaser articles" do
    html = <<~HTML
      <html lang="fr">
        <head>
          <title>Article réservé à nos abonnés</title>
          <meta property="og:site_name" content="Le Monde">
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"NewsArticle","headline":"Article réservé à nos abonnés","isAccessibleForFree":"False"}
          </script>
        </head>
        <body>
          <main>
            <h1 class="article__title">Article réservé à nos abonnés</h1>
            <article class="article__content">
              <p class="article__paragraph">Ce paragraphe public présente le sujet de l’enquête avant que la suite ne soit réservée aux abonnés du journal.</p>
            </article>
            <section class="paywall js-paywall"><p>La suite est réservée à nos abonnés.</p></section>
          </main>
        </body>
      </html>
    HTML

    extract_from_url("https://www.lemonde.fr/politique/article/2026/07/06/article-reserve_6721000_823448.html", html) do |payload|
      expect_content_type(payload, "article")
      expect(payload["markdown"]).to include("Ce paragraphe public présente le sujet")
      expect_warnings(payload, include: %w[paywall_partial_content])
    end
  end
end
