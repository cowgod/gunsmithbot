# frozen_string_literal: true

module Retryable
  extend ActiveSupport::Concern

  MAX_RETRIES = 3


  def with_retry
    response      = nil
    retry_attempt = 0

    begin
      response = yield
    rescue Net::ReadTimeout, SocketError => e
      if retry_attempt < MAX_RETRIES
        retry_attempt += 1
        Cowgod::Logger.log "#{self.class}.#{__method__} - Error '#{e.message}'. Retrying #{retry_attempt}/#{MAX_RETRIES}...'"
        retry
      else
        Cowgod::Logger.log "#{self.class}.#{__method__} - Error '#{e.message}'. Giving up...'"
      end
    end

    response
  end
end


