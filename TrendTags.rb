module TrendTags
  require 'active_support'
  require 'active_support/core_ext'
  require 'nokogiri'
  require 'mastodon'
  require 'date'
  require 'dotenv'
  require 'net/http'
  require 'uri'
  require 'json'

  def trend_public
    post = trend
    if post.nil?
      return
    end
    c = client
    puts post
    c.create_status(post, visibility: 'public')
  end

  def trend_unlisted
    post = trend
    if post.nil?
      return
    end
    c = client
    c.create_status(post, visibility: 'unlisted')
  end

  private

  def trend
    Dir.chdir(File.expand_path("../", __FILE__))
    Dotenv.load
    log = log_last
    json = get_json('https://imastodon.net/api/v1/trend_tags')
    result = JSON.parse(json)
    i = 0

    while i < 6 && log['updated_at'] == result['updated_at']
      i += 1
      sleep(10)
      json = get_json('https://imastodon.net/api/v1/trend_tags')
      result = JSON.parse(json)
    end

    if log['updated_at'] == result['updated_at']
      return nil
    end

    log_add(json)
    arr = process(result)

    if arr.length == 0
      return nil
    end

    post = "#{Time.now.strftime('%H:%M')}現在のトレンドタグ\n\n"
    [5, arr.length].min.times do |i|
      post << "＃#{arr[i][0]} [#{arr[i][1]}]"
      if log['score_ex'].has_key?(arr[i][0])
        before = (arr[i][1] - log['score_ex'][arr[i][0]])
        if before > 0
          post << "[↗+#{before.round(2)}]\n"
        elsif before < 0
          post << "[↘#{before.round(2)}]\n"
        else
          post << "[→±0]\n"
        end
      else
        post << "[NEW]\n"
      end
    end
    post
  end

  def log_last
    f = File.open(File.expand_path("../TrendTags.log", __FILE__),"r")
    log = JSON.parse(f.readlines[-1])
    f.close
    return log
  end

  def log_add(json)
    f = File.open(File.expand_path("../TrendTags.log", __FILE__),"a")
    f.puts(json)
    f.close
  end

  def process(result)
    h = result['score']
    h_ex = result['score_ex']
    ng_tags = ['test', 'ミリシタガシャシミュレータ', 'imas_oshigoto', '奈緒のお天気', '奈緒のお天気警報情報']
    h.except!(*ng_tags)
    h_ex.except!(*ng_tags)
    h.sort_by(&:last).reverse
    h_ex.sort_by(&:last).reverse
  end

  def client
    Mastodon::REST::Client.new(base_url: ENV["MASTODON_URL"], bearer_token: ENV["MASTODON_ACCESS_TOKEN"])
  end

  def get_json(addr)
    uri = URI.parse(addr)
    Net::HTTP.get(uri)
  end

  module_function :trend_public, :trend_unlisted, :trend, :log_last, :log_add, :process, :client, :get_json
end

if __FILE__ == $0
  TrendTags.trend_public
end
