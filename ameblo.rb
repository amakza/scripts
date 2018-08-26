#!/home/amakza/.rvm/rubies/ruby-2.4.0/bin/ruby

require 'open-uri'
require 'nokogiri'


URL = 'https://ameblo.jp/morningmusume-10ki/entry-12397451202.html'
#URL = 'https://ameblo.jp/morningmusume-10ki/entry-11351538282.html' # FIRST BLOG
AMEBLO_URL = 'https://ameblo.jp'
PROJECT_URL = '/home/amakza/sites/thefirstgame/app/assets/images/ameblo/'
IMG_REGEX = Regexp.new('^https:\/\/stat\.ameba\.jp\/{1,2}user_images\/\d{8}\/\d+\/morningmusume-10ki')
JUUKIS = { iikubo: '飯窪春菜', ishida: '石田亜佑美', satou: '佐藤優樹', kudou: '工藤遥', oda: '小田さくら'}

def run(url)
  @index = 1
  main url
end

def main(url)
  #if @index <= 10
  if !url.nil?
    begin
      doc = Nokogiri::HTML(open(url))
      if doc.at_css('article')
        images = get_images doc
        member = get_member doc
        puts "(#{@index}) Getting #{images.length} images from #{get_member doc}'s post: #{get_title doc}"

        images.each do |src|
          download_image src, member
        end

        @index += 1
      else
        puts 'SECRETSECRETSECRETSECRETSECRETSECRET'
      end

      sleep 1
      main get_next_post_url doc
    rescue => e
      puts 'FATAL ERROR'
      puts "URL: #{url}"
      puts e
      puts e.backtrace
      return
    end
  end
end

def get_member(doc)
  name_tag = doc.css('a[rel="tag"]')[0]
  name_tag.nil? ? '' : name_tag.text
end

def get_title(doc)
  doc.css('article').attr('data-unique-entry-title')
end

def get_next_post_url(doc)

  if doc.at_css('a.ga-entryPagingPrev')
    href = doc.css('a.ga-entryPagingPrev').attr('href')
  elsif
    doc.css('a.ga-pagingEntryPrevBottom')
    return nil
  else
    puts 'SECRETSECRETSECRETSECRETSECRETSECRET'
    href = doc.css('a.ga-pagingEntryPrevBottom').attr('href')
  end

  if href.value.start_with?('http')
    return href
  elsif href.value.start_with?('//ameblo.jp')
    return "https:#{href}"
  else
    return "#{AMEBLO_URL}#{href}"
  end
end

def get_images(doc)
  images = Array.new
  doc.xpath("//article").xpath('//img/@src').each do |src|
    if IMG_REGEX.match?(src) && src.parent.parent.attr('class').nil?
       images << src
    end
  end

  images
end

def download_image(url, member)
  name = File.basename(URI.parse(url).path)
  route = "#{PROJECT_URL}#{JUUKIS.key(member)}"

  Dir.mkdir(route) unless Dir.exist?(route)

  File.open("#{route}/#{name}", 'wb') do |fo|
    fo.write open(url).read 
  end
end

run URL
