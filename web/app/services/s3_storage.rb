class S3Storage
  def self.configured?
    %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION AWS_BUCKET].all? { |k| ENV[k].present? }
  end

  def self.upload(track, stem, local_path)
    bucket.object(key(track, stem)).upload_file(local_path)
  end

  def self.presigned_url(track, stem, expires_in: 1.hour)
    bucket.object(key(track, stem)).presigned_url(:get, expires_in: expires_in.to_i)
  end

  def self.delete(track)
    Track::STEMS.each do |stem|
      bucket.object(key(track, stem)).delete
    end
  end

  class << self
    private

    def key(track, stem)
      "stems/#{track.stem_name}/#{track.stem_name}_#{stem}.wav"
    end

    def bucket
      Aws::S3::Resource.new(
        region:            ENV.fetch("AWS_REGION"),
        access_key_id:     ENV.fetch("AWS_ACCESS_KEY_ID"),
        secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY")
      ).bucket(ENV.fetch("AWS_BUCKET"))
    end
  end
end
