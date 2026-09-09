# frozen_string_literal: true

RSpec.describe "FetchUtil extractor integration - described link groups" do
  include_context "extractor integration helpers"

  def described_groups_source
    root = File.expand_path("../../..", __dir__)
    source = File.readlines(File.join(root, "websieve/manifest.txt"), chomp: true).reject(&:empty?).map do |entry|
      File.read(File.join(root, "websieve", entry))
    end.join("\n")
    source.sub("})(window);", "global.GroupProbe = {group: genericListLinkGroup, clone: visibleListClone, items: extractListItems, render: listMarkdown}; })(window);")
  end

  it "preserves every short action with its own described audience group in DOM order" do
    groups = (1..125).map do |i|
      "<div><h2>Audience #{i}</h2><p>Independent advice for audience #{i}.</p>" \
        "<a href='/en/#{i}'>English</a><a href='/es/#{i}' lang='es'>Español</a></div>"
    end.join
    with_url_page("https://public.example/", "<main>#{groups}</main>") do |page|
      page.add_script_tag(content: described_groups_source)
      lines = page.evaluate("GroupProbe.render(GroupProbe.items(GroupProbe.clone(document.querySelector('main')))).split('\\n')")
      expected = (1..125).flat_map do |i|
        ["- [English](https://public.example/en/#{i}) - Audience #{i}",
         "- [Español](https://public.example/es/#{i}) - Audience #{i}"]
      end
      expect(lines).to eq(expected)
    end
  end

  it "does not use navigation, hidden or unsafe peers, nested cards or article references as evidence" do
    html = "<main><div id='group'><h2>For families</h2><p>Advice for families.</p><a href='/en'>English</a><a href='/es'>Español</a></div></main>"
    with_url_page("https://public.example/", html) do |page|
      page.add_script_tag(content: described_groups_source)
      result = page.evaluate(<<~JS)
        (() => {
          const group = document.querySelector('#group'), original = group.innerHTML;
          const changes = [
            node => node.setAttribute('role', 'navigation'),
            node => node.lastElementChild.hidden = true,
            node => node.lastElementChild.href = 'javascript:void(0)',
            node => node.lastElementChild.href = 'https://fixture:secret@example.test/private',
            node => node.lastElementChild.innerHTML = '<h3>Another story</h3><p>Independent story prose.</p>',
            node => node.querySelector('p').innerHTML = '<a href="/citation">A citation</a>'
          ];
          return changes.map(change => {
            group.innerHTML = original; group.removeAttribute('role'); change(group);
            return !!GroupProbe.group(group.querySelector('a'));
          });
        })()
      JS
      expect(result).to eq([false] * 6)
    end
    with_url_page("https://public.example/articles/example", html) do |page|
      page.add_script_tag(content: described_groups_source)
      expect(page.evaluate("GroupProbe.group(document.querySelector('a'))")).to be_nil
    end
  end
end
