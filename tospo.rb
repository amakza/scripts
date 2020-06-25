#!/home/amakza/.rvm/rubies/ruby-2.4.0/bin/ruby

require 'mechanize'

#TOSPO = 'https://g.tospo.jp/sp2/TospoCafe/ColumnNomember.asp?sendtime=20191114165523&cor_id=026&col_id=069&art_id=0000016123'
#LOGIN_URL = 'https://ms-charge.mscon.jp/tospo/sp/userWeb/registAuone.php'
TOSPO_TOP = 'https://g.tospo.jp/sp2/'
TOSPO_BASE_URL = "#{TOSPO_TOP}TospoCafe/"
TOSPO_FIRST_POST_URL = "#{TOSPO_BASE_URL}ColumnDisp.asp?cor_id=026&col_id=069&art_id=0000011993"
PROJECT_URL = '/home/amakza/sites/thefirstgame/app/assets/images/tospo/'

def main
  @agent = Mechanize.new
  @agent.user_agent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1'
  @agent.default_encoding='Shift_JIS'
  @agent.cookie_jar.add!(create_login_cookie)

  page = @agent.get(TOSPO_FIRST_POST_URL)

  loop do
    date_string = page.search('div.date').text.delete("^0-9")

    # LOG
    p "#{date_string}: #{page.uri}"

    page.search('div.article-image img').each_with_index do |img, idx|
      #p "#{idx} src: #{img.attributes['src']}"
      @agent.get(("#{TOSPO_BASE_URL}#{img.attributes['src']}")).save "#{PROJECT_URL}#{date_string}_#{idx}.jpg"
    end

    link = page.search('div.prev a').first
    # Sometimes there are encoding problems and can't get the link
    if link.nil?
      page.encoding = 'utf-8'
      link = page.search('div.prev a').first
    end

    if link.nil? || link.attributes['href'].value.empty?  # If no link left, then break out of loop
      p 'THE END'
      break
    else # As long as there is still a nextpage link...
      page = @agent.click(link)
      sleep(0.3)
    end
  end

end

def create_login_cookie
  cookie = Mechanize::Cookie.new('WebCookie', 'uid=4d4fccfa3fb3a12de7f3a9af56826dcf0b7282e7&tmpId=5cd90fc2b7a7578dbd36fc8feb074a88')
  cookie.domain = 'g.tospo.jp'
  cookie.path = '/sp2'

  return cookie
end

main
