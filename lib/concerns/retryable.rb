# frozen_string_literal: true

module Retryable
  extend ActiveSupport::Concern

  MAX_RETRIES      = 3
  SECONDS_TO_SLEEP = 1


  def with_retry
    response      = nil
    retry_attempt = 0

    begin
      response = yield
    rescue Net::ReadTimeout, SocketError => e
      if retry_attempt < MAX_RETRIES
        retry_attempt += 1
        Cowgod::Logger.log "#{self.class}.#{__method__} - Error '#{e.message}'. Retrying #{retry_attempt}/#{MAX_RETRIES}...'"
        sleep SECONDS_TO_SLEEP
        retry
      else
        Cowgod::Logger.log "#{self.class}.#{__method__} - Error '#{e.message}'. Giving up...'"
      end
    end

    response
  end
end


