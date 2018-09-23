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
    Dotenv.load
    post = trend
    if post.nil?
      return
    end
    client.create_status(post, visibility: 'public')
  end

  def trend_unlisted
    Dotenv.load
    post = trend
    if post.nil?
      return
    end
    client.create_status(post, visibility: 'unlisted')
  end

  def trend_daily
    Dotenv.load
    log = get_yesterday(log_all)
    post = daily_highscore(log)
    if post.nil?
      return
    end
    client.create_status(post, visibility: 'public')
    post = daily_longtime(log)
    if post.nil?
      return
    end
    client.create_status(post, visibility: 'public')
  end

  private

  def trend
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
    arr = remove_ng_tags(result).sort_by(&:last).reverse

    if arr.length == 0
      return nil
    end

    post = "#{Time.now.strftime('%H:%M')}現在のトレンドタグ\n\n"
    [5, arr.length].min.times do |i|
      post << "＃#{arr[i][0]} [#{arr[i][1]}]"
      if log['score'].has_key?(arr[i][0])
        before = (arr[i][1] - log['score'][arr[i][0]])
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

  def daily_highscore(log)
    score = {}
    log.each do |h|
      score.merge!(h["score"]) do |k, o, n|
        n > o ? n : o
      end
    end
    highscore = remove_ng_tags(score, false).sort do |a, b|
      a[1] <=> b[1]
    end.reverse
    post = ""
    if highscore.nil? || highscore.empty? || highscore[0].nil?
      return nil
    end
    post << "昨日のトレンド\n「ハイスコアランキング」\n1位:＃#{highscore[0][0]} [#{highscore[0][1]}]\n"
    if highscore[1].nil?
      return post
    end
    post << "2位:＃#{highscore[1][0]} [#{highscore[1][1]}]\n"
    if highscore[2].nil?
      return post
    else
      return post << "3位:＃#{highscore[2][0]} [#{highscore[2][1]}]"
    end
  end

  def daily_longtime(log)
    score = log.map do |e|
      remove_ng_tags(e)
    end
    keys = score.map do |e|
      e.sort_by { |k, v| -v }[0][0]
    end.uniq
    count = keys.inject({}) do |hash, key|
      hash[key] = score.count do |item|
        item.has_key?(key)
      end
      hash
    end
    rank = count.sort_by do |k, v|
      -v
    end
    post = ""
    if rank.nil? || rank.empty? || rank[0].nil?
      return nil
    end
    post << "昨日のトレンド\n「ロングタイムランキング」\n1位:＃#{rank[0][0]}: #{rank[0][1] / 6}時間#{rank[0][1] % 6 * 10}分\n"
    if rank[1].nil?
      return post
    end
    post << "2位:＃#{rank[1][0]}: #{rank[1][1] / 6}時間#{rank[1][1] % 6 * 10}分\n"
    if rank[2].nil?
      return post
    else
      return post << "3位:＃#{rank[2][0]}: #{rank[2][1] / 6}時間#{rank[2][1] % 6 * 10}分"
    end
  end

  def get_yesterday(log)
    log.find_all do |h|
      year, mon, date, hour, min, sec = h["updated_at"].split(/[-TZ:]/)
      ((DateTime.now.beginning_of_day - 1.day + 10.minutes)..DateTime.now).cover?(Time.utc(year, mon, date, hour, min, sec))
    end
  end

  def log_all
    Dir.chdir(File.expand_path("../", __FILE__))
    log = []
    File.open(File.expand_path("../TrendTags.log", __FILE__), "r").each_line do |l|
      log << JSON.parse(l)
    end
    log
  end

  def log_last
    Dir.chdir(File.expand_path("../", __FILE__))
    f = File.open(File.expand_path("../TrendTags.log", __FILE__),"r")
    log = JSON.parse(f.readlines[-1])
    f.close
    log
  end

  def log_add(json)
    Dir.chdir(File.expand_path("../", __FILE__))
    f = File.open(File.expand_path("../TrendTags.log", __FILE__),"a")
    f.puts(json)
    f.close
  end

  def remove_ng_tags(result, nested = true)
    result = result['score'] if nested
    ng_tags = ['test', 'ミリシタガシャシミュレータ', 'imas_oshigoto', '奈緒のお天気', '奈緒のお天気警報情報', '歌田音のアイドル紹介', 'usa_botアイキャッチ', 'usa_bot更新キーワード', '歌田音のvocal_master', 'official_bot', 'アイドル投票tb', 'nowplaying', 'とは']
    result.except!(*ng_tags)
  end

  def client
    Mastodon::REST::Client.new(base_url: ENV["MASTODON_URL"], bearer_token: ENV["MASTODON_ACCESS_TOKEN"])
  end

  def get_json(addr)
    uri = URI.parse(addr)
    Net::HTTP.get(uri)
  end

  module_function :trend_public, :trend_unlisted, :trend_daily, :trend, :daily_highscore, :daily_longtime, :get_yesterday, :log_all, :log_last, :log_add, :remove_ng_tags, :client, :get_json
end

if __FILE__ == $0
  TrendTags.trend_daily
end
