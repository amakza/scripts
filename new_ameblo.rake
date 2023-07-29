require 'open-uri'
require 'watir'
require 'json'
require 'webdrivers'

# Get information for the blog to scrape
CONFIG = OpenStruct.new(YAML.load_file("config/ameblo.yml")['ameblo'])
BLOG = CONFIG['blogs']['morningmusume-10ki']

namespace :ameblo_crawler do
  desc "Ameblo Crawler"
  task :get_images => :environment do

    @index = 1
    @login = false
    @browser = Watir::Browser.new :chrome, headless: true, disableDevShmUsage: true
    new_ameblo_main BLOG['latest']

    @browser.close
  end
end


def new_ameblo_main(blog_id, publish_flg = 'open')
  retries ||= 0
  if !blog_id.nil?
    begin
      blog_url = ''
      blog_images = []

      if publish_flg == 'open'
        blog_url = CONFIG.url + BLOG['name'] + '/entry-' + blog_id + '.html'
      end

      if publish_flg == 'amember'
        if !@login
          login
        end

        blog_url = CONFIG.secret_url + BLOG['name'] + '/amemberentry-' + blog_id + '.html'
      end

      @browser.goto(blog_url)

      # Get data related to the post (and link to next post)
      data = get_post_data blog_id, publish_flg
      # Get all images inside the post
      images = get_images publish_flg

      puts "(#{@index}) Getting #{images.length} images from #{data[:member]}'s post: #{data[:title]}"

      # Download images
      images.each do |url|
        download_image url, data[:member]
        blog_images << AmebloImage.new({
          member: data[:member],
          image_name: File.basename(URI.parse(url).path)
        })
      end

      data.merge!(get_meta_data blog_id)

      # Create entry in the DB
      AmebloPost.create({
        blog_id: blog_id,
        ameblo_id: BLOG['id'],
        blog_title: data[:title],
        member: data[:member],
        blog_date: DateTime.parse(data[:blog_date]),
        likes: data[:likes],
        comments: data[:comments],
        reblogs: data[:reblogs],
        secret: publish_flg == 'amember',
        ameblo_images: blog_images
      })


      @index += 1

      if data[:next_id].blank?
        return 0
      end

      sleep 1
      new_ameblo_main data[:next_id], data[:next_publish_flg]


    rescue => e
      puts 'FATAL ERROR'
      puts "URL: #{@browser.url}"
      puts "DATA: #{data.inspect}"
      puts e
      # Backtracing an error make it appear for each time the main function was called (because
      # its is recursive). So either put this logic on a different function or stop backtracing
      #puts e.backtrace
      retries += 1
      puts "Retrying(#{retries})"
      retry if retries <= 3
      return
    end
  end
end



def login
  @browser.goto(CONFIG.url)

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

  login_form.text_field(name: 'accountId').set(CONFIG.user)
  login_form.text_field(name: 'password').set(CONFIG.password)
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
    blog_date = data['entryState']['entryMap'][blog_id]['entry_created_datetime']
    if data['entryState']['entryMetaMap'][blog_id]['paging']['next']
      next_id = data['entryState']['entryMetaMap'][blog_id]['paging']['next'].to_s
      next_publish_flg = data['entryState']['entryMap'][next_id]['publish_flg']
    else
      next_id = ""
      next_publish_flg = ""
    end

  end

  if publish_flg == 'amember'
    member = @browser.element(css: 'a[rel="tag"]').text
    title =  @browser.h1().a().text
    blog_date = @browser.element(css: 'p[data-uranus-component="entryDate"] time').text

    next_blog_url = @browser.a(css: '.ga-pagingEntryPrevTop').href
    next_publish_flg = next_blog_url.start_with?(CONFIG.url) ? 'open' : 'amember'
    next_id = next_blog_url .match(/[\d]{3,}/).to_s
  end

  { member: member, title: title, blog_date: blog_date, next_id: next_id, next_publish_flg: next_publish_flg }
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
  route = "#{Rails.root}#{CONFIG.image_folder}#{BLOG['members'].key(member)}"

  Dir.mkdir(route) unless Dir.exist?(route)

  File.open("#{route}/#{name}", 'wb') do |fo|
    fo.write URI.open(url).read 
  end
end

def get_meta_data(blog_id)
  api_url = "#{CONFIG.api_url}amebaId=#{BLOG['name']};blogId=#{BLOG['id']};entryIds=#{blog_id}?returnMeta=true"
  meta_data = JSON.parse(`curl -s "#{api_url}"`)['data'][blog_id]

  {likes: meta_data['iineCnt'], comments: meta_data['commentCnt'], reblogs: meta_data['reblogCnt']}
end
