class Activity < ActiveRecord::Base
  belongs_to :actor,   polymorphic: true
  belongs_to :subject, polymorphic: true
  belongs_to :target,  polymorphic: true

  belongs_to :story

  has_many :tips, foreign_key: 'via_id'

  validates :actor,   presence: true
  validates :subject, presence: true
  validates :target,  presence: true

  after_commit :track_in_segment, on: :create

  attr_accessor :socket_id

  def self.publish!(opts)
    create!(opts).tap do |a|
      if a.publishable
        PublishActivity.perform_async(a.id) if Story.should_publish?(a)
        a.publish_to_chat

        if product = opts[:product] || a.find_product
          product.update!(last_activity_at: a.created_at)
        end
      end
    end
  end

  def track_in_segment
    return if actor && actor.staff?

    TrackActivityCreated.perform_async(self.id)
  end

  # make this object tippable
  def tip_receiver
    actor
  end

  def verb
    self.class.name.split('::').last
  end

  def verb_subject
    s = subject_type == 'Event' ? target : subject
    raise "Bad Subject #{self.inspect}" if s.nil?

    s.class.name.split('::').last
  end

  def find_product
    subject.try(:product) || target.try(:product)
  end

  # deprecated
  def streams
    stream_targets.map do |o|
      ActivityStream.new(o)
    end
  end

  def stream_targets
    [actor, target]
  end

  def publish_to_chat
    streams.each do |stream|
      stream.push(self)
    end
  end

  def publishable
    false
  end
end
