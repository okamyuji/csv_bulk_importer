# typed: true
# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  around_perform do |job, block|
    Current.request_id = "job:#{job.job_id}"
    block.call
  ensure
    Current.reset
  end
end
