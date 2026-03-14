class CleanupTracksJob < ApplicationJob
  queue_as :default

  def perform
    Track.where(status: "done")
         .where("created_at < ?", 24.hours.ago)
         .find_each do |track|
      S3Storage.delete(track) if S3Storage.configured?
      track.audio_file.purge if track.audio_file.attached?
      track.destroy
      Rails.logger.info("[CleanupTracksJob] Deleted track #{track.id} (#{track.name})")
    rescue => e
      Rails.logger.error("[CleanupTracksJob] Failed to delete track #{track.id}: #{e.message}")
    end
  end
end
