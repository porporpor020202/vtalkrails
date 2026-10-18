require 'selenium-webdriver'
require 'json'
root = File.expand_path(__dir__)
slides = [
 ['01-login','하루 한 문장,','영어가 습관이 돼요'],
 ['02-question','오늘의 질문 하나,','내 이야기 한 문장'],
 ['03-translation','질문이 어려우면','한국어로 확인해요'],
 ['04-english-help','하고 싶은 말,','영어로 바꿔보세요'],
 ['05-recording','영어 표현을 보며','바로 말해보세요'],
 ['06-preview','내 목소리를 듣고','한 문장 전송'],
 ['07-streak','오늘의 한 문장이','연속 기록으로']
]
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless=new')
options.add_argument('--allow-file-access-from-files')
options.add_argument('--hide-scrollbars')
driver = Selenium::WebDriver.for(:chrome, options: options)
%w[iphone android].each do |platform|
  iphone = platform == 'iphone'
  width, height = iphone ? [1290,2796] : [1080,1920]
  phone_width = iphone ? 1040 : 696
  phone_height = phone_width * (iphone ? 1795.0 / 876 : 1846.0 / 852)
  phone_top = iphone ? 525 : 365
  slides.each_with_index do |(name,line1,line2), index|
    path = File.join(root,platform,"#{name}.html")
    File.write(path, <<~HTML)
      <!doctype html><html lang="ko"><meta charset="UTF-8"><style>
      *{box-sizing:border-box}html,body{margin:0;width:#{width}px;height:#{height}px;overflow:hidden}
      body{background:#{index.odd? ? '#eef2e9' : '#faf8f1'};color:#234b3d;font-family:-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo',sans-serif}
      .brand{position:absolute;top:#{iphone ? 95 : 55}px;left:0;width:100%;text-align:center;font-size:#{iphone ? 32 : 25}px;font-weight:500;letter-spacing:-.5px;color:#7c8c70}
      h1{position:absolute;top:#{iphone ? 182 : 115}px;left:55px;right:55px;margin:0;text-align:center;font-size:#{iphone ? 83 : 65}px;line-height:1.33;letter-spacing:-4px;font-weight:750}
      .phone{position:absolute;width:#{phone_width}px;height:#{phone_height}px;left:#{(width-phone_width)/2}px;top:#{phone_top}px;filter:drop-shadow(0 24px 25px #293e3328)}
      .screen{position:absolute;inset:#{iphone ? '2.8% 8.8% 3.1%' : '2.7% 6.4% 3%'};background:#faf9f5;border-radius:#{iphone ? 85 : 58}px;overflow:hidden;display:flex;flex-direction:column;}
      .status{height:#{iphone ? 80 : 60}px;flex-shrink:0;display:flex;align-items:center;justify-content:space-between;padding:0 46px;font-size:#{iphone ? 25 : 19}px;font-weight:650;color:#203f35}
      .status span:last-child{font-size:#{iphone ? 21 : 16}px;letter-spacing:1px}
      .app{display:block;flex:1;width:100%;min-height:0;object-fit:contain;object-position:top center}
      .home{height:#{iphone ? 29 : 22}px;flex-shrink:0;display:grid;place-items:center}.home:after{content:'';width:32%;height:#{iphone ? 7 : 5}px;border-radius:10px;background:#17271f}
      .frame{position:absolute;inset:0;width:100%;height:100%;pointer-events:none}
      .footer{position:absolute;bottom:#{iphone ? 90 : 22}px;left:0;width:100%;text-align:center;font-size:#{iphone ? 27 : 21}px;color:#8b967e;letter-spacing:0}
      </style><body><div class="brand">세이원띵 · Say One Thing</div><h1>#{line1}<br>#{line2}</h1>
      <div class="phone"><div class="screen"><div class="status"><span>9:41</span><span>▮▮▮ ▰</span></div><img class="app" src="../raw/#{name}.png"><div class="home"></div></div><img class="frame" src="../#{platform}-frame.png"></div>
      <div class="footer">하루 한 번, 나를 위한 영어 말하기</div></body></html>
    HTML
    driver.execute_cdp('Emulation.setDeviceMetricsOverride', width: width, height: height, deviceScaleFactor: 1, mobile: false)
    driver.navigate.to("file://#{path}")
    driver.execute_script('return Promise.all(Array.from(document.images).map(img => img.decode()))')
    driver.save_screenshot(File.join(root,platform,"#{name}.png"))
  end
end
driver.quit
puts 'Rendered 7 iPhone and 7 Android store images.'
