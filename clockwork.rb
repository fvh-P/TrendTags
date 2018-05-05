require 'clockwork'
require_relative 'TrendTags'

module Clockwork
  extend TrendTags

  def trend
    TrendTags.trend
  end

  handler do |job|
    self.send(job.to_sym)
  end

  every(1.hour, 'trend_unlisted', at: '**:05')
  every(1.hour, 'trend_public', at: '**:15')
  every(1.hour, 'trend_unlisted', at: '**:25')
  every(1.hour, 'trend_unlisted', at: '**:35')
  every(1.hour, 'trend_public', at: '**:45')
  every(1.hour, 'trend_unlisted', at: '**:55')
  every(1.day, 'trend_daily', at: '00:06')
end
