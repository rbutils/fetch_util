# frozen_string_literal: true

RSpec.describe 'FetchUtil empty comment UI cleanup' do
  include_context 'extractor integration helpers'

  def comment_cleanup_article(comment_ui)
    paragraphs = 4.times.map do |index|
      "<p>Verified report paragraph #{index + 1} preserves source facts, local context, and enough substantive prose for stable article extraction.</p>"
    end.join

    <<~HTML
      <html>
        <head><title>Verified infrastructure report</title></head>
        <body>
          <main>
            <article>
              <h1>Verified infrastructure report</h1>
              #{paragraphs}
              #{comment_ui}
            </article>
          </main>
        </body>
      </html>
    HTML
  end

  def extract_comment_cleanup(comment_ui)
    with_url_page('https://reports.example/verified-infrastructure', comment_cleanup_article(comment_ui)) do |page|
      source = page.evaluate('document.body.innerHTML')
      payload = extract_payload(page)
      yield payload, page.evaluate('document.body.innerHTML'), source
    end
  end

  def clean_comment_ui_root(html)
    root = File.expand_path('../../..', __dir__)
    source = File.readlines(File.join(root, 'websieve/manifest.txt'), chomp: true)
                 .reject { |line| line.empty? || line.start_with?('#') }
                 .map { |path| File.read(File.join(root, 'websieve', path)) }.join("\n")
    outro = File.read(File.join(root, 'websieve/99_outro.js'))
    source = source.delete_suffix(outro) + <<~JS + outro
      window.__cleanCommentUiRoot = function(input) {
        var template = document.createElement("template");
        template.innerHTML = input;
        var sourceNode = template.content.firstElementChild;
        var before = sourceNode.outerHTML;
        var clone = cleanClone(sourceNode);
        return {clone: clone.outerHTML, sourceUnchanged: sourceNode.outerHTML === before};
      };
    JS

    with_page('<main>Unchanged source page</main>') do |page|
      before = page.evaluate('document.body.innerHTML')
      page.add_script_tag(content: source)
      result = page.evaluate("window.__cleanCommentUiRoot(#{JSON.generate(html)})")
      expect(page.evaluate('document.body.innerHTML')).to eq(before)
      result
    end
  end

  it 'removes explicit comment forms and zero-count continuation controls from article clones' do
    comment_ui = <<~HTML
      <div id="comment-form-div" class="comment-form">
        <h3>Komentari</h3>
        <form><label>Name</label><input><textarea></textarea><button>Post</button></form>
      </div>
      <form class="comment-form">
        <button><img src="https://reports.example/button-owned.png" alt="Button-owned helper media">Post media reply</button>
      </form>
      <div class="more-comments-button"><a href="/comments">Other comments (0)</a></div>
    HTML

    extract_comment_cleanup(comment_ui) do |payload, after, before|
      expect(payload.fetch('markdown')).not_to include('Komentari', 'Other comments', 'Name', 'Post')
      expect(payload.fetch('markdown')).not_to include('button-owned.png', 'Button-owned helper media')
      expect(payload.fetch('markdown')).to include('Verified report paragraph 1')
      expect(payload.fetch('readerMode')).to be(false)
      expect(after).to eq(before)
    end
  end

  it 'removes only a compact comment subscription prompt, not published replies' do
    prompt = <<~HTML
      <div class="comments">Comentarios SUSCRIBITE PARA COMENTAR YA TENGO SUSCRIPCIÓN</div>
      <section class="comments"><article itemprop="comment"><p>A published reply supplies a substantive correction to the source record.</p></article></section>
    HTML

    extract_comment_cleanup(prompt) do |payload, after, before|
      expect(payload.fetch('markdown')).not_to include('SUSCRIBITE PARA COMENTAR', 'YA TENGO SUSCRIPCIÓN')
      expect(payload.fetch('markdown')).to include('A published reply supplies a substantive correction')
      expect(payload.fetch('markdown')).to include('Verified report paragraph 1')
      expect(after).to eq(before)
    end
  end

  it 'removes a text-only comment form invitation while retaining real replies' do
    comment_ui = <<~HTML
      <div class="comments">Leave a comment</div>
      <section class="comments">
        <article itemprop="comment"><p>A published reply supplies a correction to the public report.</p></article>
      </section>
      <div class="comments"><p>A real comment can quote the phrase Leave a comment.</p></div>
    HTML

    extract_comment_cleanup(comment_ui) do |payload, after, before|
      expect(payload.fetch('markdown')).not_to include("\nLeave a comment\n")
      expect(payload.fetch('html')).not_to include('<div class="comments">Leave a comment</div>')
      expect(payload.fetch('textContent')).not_to start_with('Leave a comment')
      expect(payload.fetch('markdown')).to include('A published reply supplies a correction')
      expect(payload.fetch('markdown')).to include('A real comment can quote the phrase Leave a comment.')
      expect(after).to eq(before)
    end
  end

  it 'preserves nonempty continuation controls and actual comment or reply content' do
    controls = <<~HTML
      <div class="more-comments-button"><a href="/comments">Other comments (3)</a></div>
      <div class="more-comments-button">
        <article itemprop="comment"><p class="comment-body">A published correction adds material context.</p></article>
        <span>Other comments (0)</span>
      </div>
      <div class="more-comments-button">
        <blockquote class="reply-body">A verified reply clarifies the cited source.</blockquote>
        <span>Other comments (0)</span>
      </div>
      <div class="more-comments-button">
        <a href="/comments">Other comments (0)</a>
        <div class="comment-content">A nested comment must not be erased with its control.</div>
      </div>
      <div class="more-comments-button">
        <a href="/comments"><span class="comment-text">A linked correction remains material.</span> Other comments (0)</a>
      </div>
      <div class="more-comments-button">
        <a href="/article/correction">Correction (0)</a>
      </div>
      <div class="more-comments-button">
        <a href="https://comments.example/comments">External comments (0)</a>
      </div>
      <div class="more-comments-button">
        <a href="/comments">A published correction remains valid. Other comments (0)</a>
      </div>
      <div id="comment-form-div" class="comment-form">
        <h3>Important correction</h3>
        <form><textarea></textarea><button>Post</button></form>
      </div>
      <section class="comment-form" itemprop="comment">
        <p>A wrapper-owned published comment remains material.</p>
        <form><label>Reply</label><textarea></textarea><button>Post reply</button></form>
      </section>
      <form class="comment-form">
        <span class="comment-text">A form-owned published comment remains material.</span>
        <label>Reply again</label><textarea></textarea><button>Post another reply</button>
      </form>
      <section class="comment-form">
        <form>
          <p>A nested form-owned published comment remains material.</p>
          <label>Nested form reply</label><textarea></textarea><button>Post nested form reply</button>
        </form>
      </section>
      <section class="comment-form">
        <p>An unmarked direct correction remains material.</p>
        <label>Direct reply</label><textarea></textarea><button>Post direct reply</button>
      </section>
      <section class="comment-form">
        <div><p>An unmarked nested correction remains material.</p></div>
        <label>Nested reply</label><textarea></textarea><button>Post nested reply</button>
      </section>
      <section class="comment-form">
        <div>Arbitrary unmarked correction text remains material.</div>
        <label>Layout reply</label><textarea></textarea><button>Post layout reply</button>
      </section>
      <section class="comment-form">
        <h2>Comments</h2>
        <article itemprop="comment"><p>A published comment with a prompt-named heading remains material.</p></article>
        <form><textarea></textarea><button>Post another comment</button></form>
      </section>
    HTML

    extract_comment_cleanup(controls) do |payload, after, before|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('Other comments (3)')
      expect(markdown).to include('A published correction adds material context.')
      expect(markdown).to include('A verified reply clarifies the cited source.')
      expect(markdown).to include('A nested comment must not be erased with its control.')
      expect(markdown).to include('A linked correction remains material.')
      expect(markdown).to include('Correction (0)')
      expect(markdown).to include('External comments (0)')
      expect(markdown).to include('A published correction remains valid. Other comments (0)')
      expect(markdown).to include('Important correction')
      expect(markdown).to include('A wrapper-owned published comment remains material.')
      expect(markdown).to include('A form-owned published comment remains material.')
      expect(markdown).to include('A nested form-owned published comment remains material.')
      expect(markdown).to include('An unmarked direct correction remains material.')
      expect(markdown).to include('An unmarked nested correction remains material.')
      expect(markdown).to include('Arbitrary unmarked correction text remains material.')
      expect(markdown).to include('Comments')
      expect(markdown).to include('A published comment with a prompt-named heading remains material.')
      expect(markdown).not_to include('Post reply')
      expect(markdown).not_to include('Post another reply', 'Reply again')
      expect(markdown).not_to include('Post nested form reply', 'Nested form reply')
      expect(markdown).not_to include('Post direct reply', 'Direct reply')
      expect(markdown).not_to include('Post nested reply', 'Nested reply')
      expect(markdown).not_to include('Post layout reply', 'Layout reply')
      expect(after).to eq(before)
    end
  end

  it 'does not match similarly named comment content or zeroes outside parentheses' do
    controls = <<~HTML
      <div class="more-comments-buttonish">Editorial comments remain available.</div>
      <div class="more-comments-button"><a href="/comments?page=10">Other comments page 10</a></div>
      <div class="more-comments-button"><span>Editorial score (0)</span></div>
      <div class="comment-form">A class name alone does not prove form UI.</div>
      <a class="more-comments-button" href="/empty-comments">Standalone comments (0)</a>
      <div class="more-comments-button"><a href="/comments">Published correction confirms the date (0)</a></div>
    HTML

    extract_comment_cleanup(controls) do |payload, after, before|
      markdown = payload.fetch('markdown')
      expect(markdown).to include('Editorial comments remain available.')
      expect(markdown).to include('Other comments page 10')
      expect(markdown).to include('Editorial score (0)')
      expect(markdown).to include('A class name alone does not prove form UI.')
      expect(markdown).to include('Published correction confirms the date (0)')
      expect(markdown).to include('Standalone comments (0)')
      expect(after).to eq(before)
    end
  end

  it 'returns a neutral empty clone when the selected root itself is pure comment UI' do
    form = clean_comment_ui_root('<form class="comment-form"><textarea></textarea><button>Post</button></form>')
    control = clean_comment_ui_root('<a class="more-comments-button" href="/comments">Other comments (0)</a>')
    script_anchor = clean_comment_ui_root('<a class="more-comments-button">Other comments (0)</a>')
    button_control = clean_comment_ui_root('<button class="more-comments-button">Other comments (0)</button>')
    correction_control = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button"><a href="/updates">Correction note (0)</a></div>
    HTML
    replacement_control = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button"><a href="/replacement">Replacement (0)</a></div>
    HTML
    encoded_separator_control = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button"><a href="/news%2Fcomments">Other comments (0)</a></div>
    HTML
    raw_backslash_control = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button"><a href="/comments\\evil">Other comments (0)</a></div>
    HTML
    unsafe_control = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button"><a href="javascript:void(0)">Other comments (0)</a></div>
    HTML
    credential_control = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button"><a href="https://reader:secret@fetchutil.invalid/comments">Other comments (0)</a></div>
    HTML
    malformed_control = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button"><a href="/news%ZZ/comments">Other comments (0)</a></div>
    HTML
    external_protocol_control = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button"><a href="//comments.example/comments">Other comments (0)</a></div>
    HTML
    media_control = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button">
        <a href="/comments">Other comments (0)</a>
        <img src="https://reports.example/continuation-evidence.png" alt="Continuation evidence">
      </div>
    HTML
    embedded_control = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button">
        <a href="/comments">Other comments (0)</a>
        <object data="https://reports.example/continuation-evidence.pdf"></object>
      </div>
    HTML
    preview_control = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button">
        <a href="/comments">Other comments (0)</a>
        <div class="comment-content">A separate published preview remains.</div>
      </div>
    HTML
    two_controls = clean_comment_ui_root(<<~HTML)
      <div class="more-comments-button"><button>Other comments (0)</button><a>Other comments (0)</a></div>
    HTML
    material_form = clean_comment_ui_root(<<~HTML)
      <form class="comment-form">
        <span class="comment-text">A root-owned correction remains material.</span>
        <textarea></textarea><button>Post reply</button>
      </form>
    HTML
    heading_form = clean_comment_ui_root(<<~HTML)
      <form class="comment-form"><h2>Important correction</h2><textarea></textarea></form>
    HTML
    prompt_heading_form = clean_comment_ui_root(<<~HTML)
      <div id="comment-form-div"><h2>Leave a reply</h2><form><textarea></textarea></form></div>
    HTML
    normalized_prompt_forms = [
      '<div class="comment-form"><h2>  LEAVE   A REPLY </h2><form><textarea></textarea></form></div>',
      '<div class="comment-form"><h2>Deixe um comentário</h2><form><textarea></textarea></form></div>',
      '<div class="comment-form"><h2><span>Комментарии</span></h2><form><textarea></textarea></form></div>'
    ].map { |html| clean_comment_ui_root(html) }
    similarly_named_owner = clean_comment_ui_root(<<~HTML)
      <div class="comment-form-wrapper" id="comment-form-div-preview"><h2>Leave a reply</h2></div>
    HTML
    media_form = clean_comment_ui_root(<<~HTML)
      <form class="comment-form"><img src="https://reports.example/evidence.png" alt="Evidence"><textarea></textarea></form>
    HTML
    responsive_media_form = clean_comment_ui_root(<<~HTML)
      <form class="comment-form"><img srcset="https://reports.example/evidence-320.png 320w" alt="Responsive evidence"><textarea></textarea></form>
    HTML
    embedded_media_form = clean_comment_ui_root(<<~HTML)
      <form class="comment-form"><object data="https://reports.example/evidence.pdf"></object><textarea></textarea></form>
    HTML
    lazy_media_form = clean_comment_ui_root(<<~HTML)
      <form class="comment-form"><img data-src="https://reports.example/lazy-evidence.png" alt="Lazy evidence"><textarea></textarea></form>
    HTML
    lazy_responsive_form = clean_comment_ui_root(<<~HTML)
      <form class="comment-form"><img data-lazy-srcset="https://reports.example/lazy-evidence-640.png 640w"><textarea></textarea></form>
    HTML
    original_source_form = clean_comment_ui_root(<<~HTML)
      <form class="comment-form"><img data-original-src="https://reports.example/original-evidence.png"><textarea></textarea></form>
    HTML
    poster_media_form = clean_comment_ui_root(<<~HTML)
      <form class="comment-form"><video poster="https://reports.example/evidence-poster.png"></video><textarea></textarea></form>
    HTML
    empty_marker_form = clean_comment_ui_root(<<~HTML)
      <form class="comment-form"><article class="comment"><blockquote></blockquote><label>Reply</label><textarea></textarea></article></form>
    HTML
    empty_marker_wrapper = clean_comment_ui_root(<<~HTML)
      <div id="comment-form-div"><article class="comment"><label>Reply</label><textarea></textarea></article></div>
    HTML
    legend_form = clean_comment_ui_root(<<~HTML)
      <form class="comment-form"><fieldset><legend>Leave a reply</legend><textarea></textarea></fieldset></form>
    HTML
    wrapped_control = clean_comment_ui_root(<<~HTML)
      <div class="comment-form"><div class="more-comments-button"><a href="/comments">Other comments (0)</a></div></div>
    HTML

    expect(form).to eq('clone' => '<div></div>', 'sourceUnchanged' => true)
    expect(control).to eq('clone' => '<div></div>', 'sourceUnchanged' => true)
    expect(script_anchor).to eq('clone' => '<a class="more-comments-button">Other comments (0)</a>', 'sourceUnchanged' => true)
    expect(button_control).to eq('clone' => '<button class="more-comments-button">Other comments (0)</button>', 'sourceUnchanged' => true)
    expect(correction_control.fetch('clone')).to include('Correction note (0)')
    expect(correction_control.fetch('sourceUnchanged')).to be(true)
    expect(replacement_control.fetch('clone')).to include('Replacement (0)')
    expect(replacement_control.fetch('sourceUnchanged')).to be(true)
    [encoded_separator_control, raw_backslash_control, unsafe_control, credential_control, malformed_control, external_protocol_control].each do |result|
      expect(result.fetch('clone')).to include('Other comments (0)')
      expect(result.fetch('sourceUnchanged')).to be(true)
    end
    expect(media_control.fetch('clone')).to include('https://reports.example/continuation-evidence.png')
    expect(media_control.fetch('clone')).to include('Other comments (0)')
    expect(media_control.fetch('sourceUnchanged')).to be(true)
    expect(embedded_control.fetch('clone')).to include('https://reports.example/continuation-evidence.pdf')
    expect(embedded_control.fetch('clone')).to include('Other comments (0)')
    expect(embedded_control.fetch('sourceUnchanged')).to be(true)
    expect(preview_control.fetch('clone')).to include('A separate published preview remains.')
    expect(preview_control.fetch('clone')).to include('Other comments (0)')
    expect(preview_control.fetch('sourceUnchanged')).to be(true)
    expect(two_controls.fetch('clone')).to start_with('<div class="more-comments-button">')
    expect(two_controls.fetch('clone')).to include('<a>Other comments (0)</a>')
    expect(two_controls.fetch('sourceUnchanged')).to be(true)
    expect(material_form.fetch('clone')).to start_with('<div>')
    expect(material_form.fetch('clone')).to include('A root-owned correction remains material.')
    expect(material_form.fetch('clone')).not_to include('<form', '<textarea', '<button')
    expect(material_form.fetch('sourceUnchanged')).to be(true)
    expect(heading_form.fetch('clone')).to include('<h2>Important correction</h2>')
    expect(heading_form.fetch('clone')).not_to include('<form', '<textarea')
    expect(heading_form.fetch('sourceUnchanged')).to be(true)
    expect(prompt_heading_form).to eq('clone' => '<div></div>', 'sourceUnchanged' => true)
    expect(normalized_prompt_forms).to all(eq('clone' => '<div></div>', 'sourceUnchanged' => true))
    expect(similarly_named_owner.fetch('clone')).to include('Leave a reply')
    expect(similarly_named_owner.fetch('sourceUnchanged')).to be(true)
    expect(media_form.fetch('clone')).to include('https://reports.example/evidence.png')
    expect(media_form.fetch('clone')).not_to include('<form', '<textarea')
    expect(media_form.fetch('sourceUnchanged')).to be(true)
    expect(responsive_media_form.fetch('clone')).to include('https://reports.example/evidence-320.png 320w')
    expect(responsive_media_form.fetch('clone')).not_to include('<form', '<textarea')
    expect(responsive_media_form.fetch('sourceUnchanged')).to be(true)
    expect(embedded_media_form.fetch('clone')).to include('<object data="https://reports.example/evidence.pdf"></object>')
    expect(embedded_media_form.fetch('clone')).not_to include('<form', '<textarea')
    expect(embedded_media_form.fetch('sourceUnchanged')).to be(true)
    expect(lazy_media_form.fetch('clone')).to include('src="https://reports.example/lazy-evidence.png"')
    expect(lazy_media_form.fetch('clone')).not_to include('<form', '<textarea')
    expect(lazy_media_form.fetch('sourceUnchanged')).to be(true)
    expect(lazy_responsive_form.fetch('clone')).to include('data-lazy-srcset="https://reports.example/lazy-evidence-640.png 640w"')
    expect(lazy_responsive_form.fetch('clone')).not_to include('<form', '<textarea')
    expect(lazy_responsive_form.fetch('sourceUnchanged')).to be(true)
    expect(original_source_form.fetch('clone')).to include('data-original-src="https://reports.example/original-evidence.png"')
    expect(original_source_form.fetch('clone')).not_to include('<form', '<textarea')
    expect(original_source_form.fetch('sourceUnchanged')).to be(true)
    expect(poster_media_form.fetch('clone')).to include('poster="https://reports.example/evidence-poster.png"')
    expect(poster_media_form.fetch('clone')).not_to include('<form', '<textarea')
    expect(poster_media_form.fetch('sourceUnchanged')).to be(true)
    expect(empty_marker_form).to eq('clone' => '<div></div>', 'sourceUnchanged' => true)
    expect(empty_marker_wrapper).to eq('clone' => '<div></div>', 'sourceUnchanged' => true)
    expect(legend_form).to eq('clone' => '<div></div>', 'sourceUnchanged' => true)
    expect(wrapped_control).to eq('clone' => '<div></div>', 'sourceUnchanged' => true)
  end
end
