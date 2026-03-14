class Track < ApplicationRecord
  STATUSES = %w[pending processing done failed].freeze
  MODELS   = { "htdemucs" => "Standard ($1)", "htdemucs_ft" => "High Quality ($3)" }.freeze

  validates :name,     presence: true
  validates :filename, presence: true
  validates :status,   inclusion: { in: STATUSES }
  validates :model,    inclusion: { in: MODELS.keys }

  after_update_commit do
    broadcast_replace_to :tracks, partial: "tracks/track", locals: { track: self }
    broadcast_replace_to self,    partial: "tracks/track", locals: { track: self }
  end

  STEMS = %w[bass drums other vocals].freeze

  def stems = STEMS

  def stem_name
    File.basename(filename, File.extname(filename))
  end

  def stem_path(stem)
    output_base = Rails.application.config.demucs_output_path
    File.join(output_base, model, stem_name, "#{stem}.wav")
  end
end
