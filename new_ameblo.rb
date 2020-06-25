#!/home/amakza/.rbenv/shims/ruby

require 'watir'

# URL = 'https://ameblo.jp/morningmusume-10ki/entry-11351538282.html' # FIRST BLOG
URL = 'https://ameblo.jp/morningmusume-10ki/entry-'
BLOG_ID = '11360044909'

def main() 

  script_data = ''
  browser = Watir::Browser.new :chrome, headless: true, disableDevShmUsage: true


  browser.goto(URL + BLOG_ID + '.html')
  browser.body().scripts.each do |x|
    if x.html.start_with?('<script>window.INIT_DATA=')
      browser.execute_script(x.html.gsub(/<\/?[^>]*>/, ""))
    end
  end

  data = browser.execute_script('return window.INIT_DATA')

  puts "Member: #{data['entryState']['entryMap'][BLOG_ID]['theme_name']}"
  puts "NEXT: #{data['entryState']['entryMetaMap'][BLOG_ID]['paging']['next']}"
  puts "Images:"
  browser.article().images(class: 'PhotoSwipeImage').each do |x|
    puts x.src.gsub(/\?.*/, '')
  end

  browser.close
end

main()
