#!/home/amakza/.rbenv/shims/ruby

require 'open-uri'
require 'watir'

AMEBLO_URL = 'https://ameblo.jp/'
AMEMBER_URL = 'https://secret.ameba.jp/'
BLOG = 'morningmusume-10ki'
BLOG_ID = '11351538282' # FIRST_BLOG
# BLOG_ID = '11360044909' # SECRET BLOG
USER = ''
PWD = ''
PROJECT_URL = '/home/amakza/sites/ayumin/app/assets/images/ameblo/'
MEMBERS = {
  iikubo: '飯窪春菜',
  ishida: '石田亜佑美',
  satou: '佐藤優樹',
  kudou: '工藤遥',
  oda: '小田さくら'
}

def run(blog_id)
  @index = 1
  @login = false
  @browser = Watir::Browser.new :chrome, headless: true, disableDevShmUsage: true
  main blog_id
  @browser.close
end

def main(blog_id, publish_flg = 'open')
  retries ||= 0
  if !blog_id.nil?
    begin
      script_data = ''
      blog_url = ''

      if publish_flg == 'open'
        blog_url = AMEBLO_URL + BLOG + '/entry-' + blog_id + '.html'
      end

      if publish_flg == 'amember'
        if !@login
          login
        end

        blog_url = AMEMBER_URL + BLOG + '/amemberentry-' + blog_id + '.html'
      end

      @browser.goto(blog_url)

      data = get_post_data blog_id, publish_flg
      images = get_images publish_flg

      puts "(#{@index}) Getting #{images.length} images from #{data[:member]}'s post: #{data[:title]}"

      images.each do |src|
        download_image src, data[:member]
      end

      @index += 1

      if data[:next_id].nil? 
        return 0
      end

      sleep 0.5
      main data[:next_id], data[:next_publish_flg]


    rescue => e
      puts 'FATAL ERROR'
      puts "URL: #{@browser.url}"
      puts "DATA: #{data.inspect}"
      puts e
      puts e.backtrace
      retries += 1
      puts "Retrying(#{retries})"
      retry if retries <= 3
      return
    end
  end
end



def login
  @browser.goto(AMEBLO_URL)

  login_link = @browser.link(text: 'ログイン')
  if !login_link
    puts 'NO LOGIN LINK'
    return false
  end
  login_link.click

  login_form = @browser.form()

  if !login_form
    puts 'NO LOGIN FORM'
    return false
  end

  login_form.text_field(name: 'accountId').set(USER)
  login_form.text_field(name: 'password').set(PWD)
  login_form.button(type: 'submit').click
  
  puts 'LOGGED IN'
  sleep 3
  @login = true
end

def get_post_data(blog_id, publish_flg)
  post_data = Hash.new

  if publish_flg == 'open'
    @browser.body().scripts.each do |x|
      if x.html.start_with?('<script>window.INIT_DATA=')
        @browser.execute_script(x.html.gsub(/<\/?[^>]*>/, ""))
      end
    end

    data = @browser.execute_script('return window.INIT_DATA')


    member = data['entryState']['entryMap'][blog_id]['theme_name']
    title = data['entryState']['entryMap'][blog_id]['entry_title']
    next_id= data['entryState']['entryMetaMap'][blog_id]['paging']['next'].to_s
    # publish_flag 'open' | 'amember'
    next_publish_flg = data['entryState']['entryMap'][next_id]['publish_flg']
  end

  if publish_flg == 'amember'
    member = @browser.element(css: 'a[rel="tag"]').text

    title =  @browser.h1().a().text

    next_blog_url = @browser.a(css: '.ga-pagingEntryPrevTop').href
    next_publish_flg = next_blog_url.start_with?(AMEBLO_URL) ? 'open' : 'amember'
    next_id = next_blog_url .match(/[\d]{3,}/).to_s
  end

  { member: member, title: title, next_id: next_id, next_publish_flg: next_publish_flg }
end

def get_images(publish_flg)
  images = Array.new

  if publish_flg === 'open'
    @browser.article().images(class: 'PhotoSwipeImage').each do |img|
      images << img.src.gsub(/\?.*/, '')
    end
  end

  if publish_flg === 'amember'
    @browser.article().as(css: '.detailOn').each do |img|
      images << img.image().src.gsub(/\?.*/, '')
    end
  end


  images

end

def download_image(url, member)
  name = File.basename(URI.parse(url).path)
  route = "#{PROJECT_URL}#{MEMBERS.key(member)}"

  Dir.mkdir(route) unless Dir.exist?(route)

  File.open("#{route}/#{name}", 'wb') do |fo|
    fo.write URI.open(url).read 
  end
end

run BLOG_ID
