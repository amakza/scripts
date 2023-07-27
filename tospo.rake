require 'mechanize'
require 'addressable'

TOSPO_CONFIG = OpenStruct.new(YAML.load_file("config/tospo.yml")['tospo'])

namespace :tospo_crawler do
  desc "Tospo Crawler"
  task :get_info => :environment do

    @index = 1
    @agent = Mechanize.new
    @agent.user_agent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1'
    @agent.default_encoding = 'Windows-31J'
    @agent.force_default_encoding = true
    @agent.cookie_jar.add!(create_login_cookie(TOSPO_CONFIG.cookie))

    tospo_crawler_main TOSPO_CONFIG.first_article_url

    p "All posts: #{@index}"
  end
end

def tospo_crawler_main(article_url)

  page = @agent.get(article_url)

  loop do
    # Initialization
    article_id = (Rack::Utils.parse_nested_query URI(page.uri).query)['art_id']
    title = ''
    article = ''
    article_images = []
    recipe = ''

    # Get date
    date_string = page.search('div.date').text
    article_date = Time.strptime(date_string, "%Y年%m月%d日 %H時%M分").strftime("%Y%m%d%H%M")

    # LOG
    p "#{article_date}: #{page.uri}"

    # Get images
    page.search('div.article-image img').each_with_index do |img, idx|
      # p "Saving: #{idx} src: #{img.attributes['src']} as #{article_date}_#{idx}.jpg"
      @agent.get(("#{TOSPO_CONFIG['url']}#{img.attributes['src']}")).save "#{Rails.root}#{TOSPO_CONFIG.image_folder}#{article_date}_#{idx}.jpg"
        article_images << TospoImage.new({
          image_name: "#{article_date}_#{idx}.jpg"
        })
    end

    # Get title
    title = page.search('div.article-header h1.protect-copy').text
    # Get article
    page.search('br').each do |br|
      br.replace("\n")
    end

    article = page.search('div.article-body .protect-copy').text
    # Get ayupad
    if article.include?('ayu') && article.include?('pad')
      is_ayupad_line_found = false

      article.lines.map do |line|
        if line.include?('ayu') && line.include?('pad')
          is_ayupad_line_found = true
        end
        if is_ayupad_line_found
          recipe.concat line
        end
      end

      if recipe != ''
        ayupad_recipe = AyupadRecipe.new({
          recipe: recipe
        })
      end
    end

    TospoArticle.create({
      article_id: article_id,
      article_title: title,
      article_date: article_date,
      article: article,
      ayupad: !ayupad_recipe.nil?,
      tospo_images: article_images,
      ayupad_recipe: ayupad_recipe
    })

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
      @index += 1
      page = @agent.click(link)
      sleep(0.5)
    end
  end

end

def create_login_cookie(cookie_info)
  cookie = Mechanize::Cookie.new(cookie_info['name'], cookie_info['value'])
  cookie.domain = cookie_info['domain']
  cookie.path = cookie_info['path']

  return cookie
end
