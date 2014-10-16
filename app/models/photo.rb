class Photo < ActiveRecord::Base
  MAIN_DIMENSIONS = "940x470"

  belongs_to :project
  has_attached_file :image,
                    :default_url => "/assets/no-image-:style.png"

  attr_accessible :image, :direct_upload_url

  after_create :transfer_from_direct_upload

  # Build a URL to dynamically resize application images via an external service
  # Currently using http://magickly.afeld.me/ 
  def url(size = nil)
    case size

    when :main
      image.present? ? cropped_image_url("#{MAIN_DIMENSIONS}#") : image.url(:main)
      
    when :index
      image.present? ? cropped_image_url("500x300#") : image.url(:index)

    else
      image_url
    end
  end

  def transfer_from_direct_upload
    if persisted? && direct_upload_url.present?
      set_attributes_from_direct_upload

      if uploaded_file = bucket.files.get(direct_upload_path)
        uploaded_file.copy(Rails.configuration.fog.bucket, image.path)

        destination_file = bucket.files.get(image.path)
        destination_file.public = true
        destination_file.save

        uploaded_file.destroy

        self.direct_upload_url = nil

        save
      end
    end
  end

  protected

  def image_url
    image.url(:original, :timestamp => false)
  end

  def cropped_image_url(crop)
    [image_host, "q", image_path(crop)].join("/")
  end

  def image_host
    ENV['MAGICKLY_HOST']
  end

  def image_path(crop)
    [ "src", image_with_host(image_url), "thumb", crop ].collect { |part| CGI.escape(part) }.join("/")
  end

  def image_with_host(image_url)
    base_uri = URI(ENV['DEFAULT_URL'] || "http://localhost:3000")

    uri = URI(image_url)
    uri.scheme ||= base_uri.scheme
    uri.host   ||= base_uri.host
    uri.port   ||= base_uri.port

    uri.to_s
  end

  def fog
    @fog ||= Fog::Storage.new(Rails.configuration.fog.credentials)
  end

  def bucket
    @bucket ||= fog.directories.get(Rails.configuration.fog.bucket)
  end

  def set_attributes_from_direct_upload
    file = bucket.files.get(direct_upload_path)

    self.image_file_name = File.basename(direct_upload_path)
    self.image_content_type = file.content_type
    self.image_file_size = file.content_length
    self.image_updated_at = file.last_modified
  end

  def direct_upload_path
    URI(direct_upload_url).path[1..-1]
  end
end
