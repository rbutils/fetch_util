require 'spec_helper'
require 'support/extractor_integration_helpers'

RSpec.describe FetchUtil::Extractor, 'non-space-delimited headline collections' do
  include_context 'extractor integration helpers'

  [
    %w[
      研究团队发布新的城市空气质量报告 居民讨论公共交通线路的最新调整
      科学家发现改善河流水质的新方法 图书馆公布下个月的阅读活动计划
      社区志愿者帮助修复受损的历史建筑 新的铁路服务连接附近的主要城市
    ],
    %w[
      นักวิจัยเผยแพร่รายงานคุณภาพอากาศฉบับใหม่ ประชาชนหารือการปรับปรุงระบบขนส่งสาธารณะ
      นักวิทยาศาสตร์ค้นพบวิธีดูแลคุณภาพน้ำ ห้องสมุดประกาศกิจกรรมส่งเสริมการอ่านเดือนหน้า
      อาสาสมัครช่วยบูรณะอาคารประวัติศาสตร์ บริการรถไฟใหม่เชื่อมต่อเมืองสำคัญใกล้เคียง
    ]
  ].each_with_index do |titles, language_index|
    it "retains meaningful linked headlines for language sample #{language_index + 1}" do
      records = titles.each_with_index.map do |title, index|
        "<li><a href='/report-#{index}'>#{title}</a></li>"
      end.join
      html = <<~HTML
        <html><head><title>International bulletin</title></head><body>
          <h1>International bulletin</h1>
          <p>Reports from our local correspondents cover public transport, scientific research,
          community projects and cultural activities. Browse the complete published collection below.</p>
          <div class='news-list'><ul>#{records}</ul></div>
          <nav>#{records.gsub("/report-", "/navigation-")}</nav>
        </body></html>
      HTML
      with_url_page('https://bulletin.example/', html) do |page|
        markdown = extract_payload(page).fetch('markdown')
        titles.each_with_index do |title, index|
          expect(markdown).to include(title, "https://bulletin.example/report-#{index}")
        end
        expect(markdown).not_to include('https://bulletin.example/navigation-')
      end
    end
  end
end
