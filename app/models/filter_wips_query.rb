class FilterWipsQuery
  attr_accessor :product_wips, :user, :filters

  def self.call(product_wips, user, filters)
    new(product_wips, user, filters).filter_wips
  end

  def initialize(product_wips, user, filters)
    self.product_wips = product_wips
    self.user = user
    self.filters = filters
  end

  def filter_wips
    apply_filters(product_wips_with_users)
  end

  def product_wips_with_users
    product_wips.includes(:user)
  end

  def apply_filters(query)
    filter_clauses.inject(query) do |query, clause|
      query.merge(clause)
    end
  end

  def filter_clauses
    [state_filter, tag_filter, mark_filter, doing_filter, created_filter,
     commented_filter, query_filter, user_filter, sort_order,
     page_selection].compact
  end

  def state_filter
    return unless states.present?

    expanded_states = states.flat_map do |state|
      case state
      when 'open' 
        'open'
      when 'doing'
        ['allocated', 'awarding']
      when 'reviewing'
        'reviewing'
      when 'done'
        ['closed', 'resolved']
      end
    end

    Wip.where(state: expanded_states)
  end

  def tag_filter
    return unless tags.present?

    Wip.joins(:tags).where(wip_tags: { name: tags }).uniq
  end

  def mark_filter
    return unless marks.present?

    Wip.joins(:marks).where(marks: { name: marks }).uniq
  end

  def doing_filter
    return unless doing.present?

    doing_ids = User.where(username: doing).pluck(:id)
    Task.joins(:wip_workers).where(user_id: doing_ids).uniq
  end

  def created_filter
    return unless created.present?

    created_ids = User.where(username: created).pluck(:id)
    Wip.where(user_id: created_ids)
  end

  def commented_filter
    return unless commented.present?

    commented_ids = User.where(username: commented).pluck(:id)
    Wip.joins(:comments).where(user_id: commented_ids).uniq
  end

  def query_filter
    return unless query.present?

    Wip.where('title ILIKE ?', "%#{query}%")
  end

  def user_filter
    case user_params
    when 'started'
      user.wips
    when 'assigned'
      user.wips_working_on
    when 'following'
      user.wips_watched
    when 'awarded'
      # TODO: Backfill awards and swap with a simpler query
      Wip.joins(events: :event).
        where(events: { type: 'Event::Win' }).
        where(events_events: { user_id: user.id }).
        order('events.created_at DESC')
    when 'commented'
      user.wips_commented_on
    else # all
      Wip.all
    end
  end

  def sort_order
    case sort
    when 'most_valuable'
      Wip.order('total_coins_cache DESC')
    when 'least_valuable'
      Wip.order('total_coins_cache ASC')
    when 'newest'
      Wip.order('wips.created_at DESC')
    when 'oldest'
      Wip.order('wips.created_at ASC')
    when 'recently_updated'
      Wip.order('wips.updated_at DESC')
    when 'least_recently_updated'
      Wip.order('wips.updated_at ASC')
    when 'priority'
      Wip.order('wips.multiplier DESC')
    when false
      Wip.all
    else #  (default)
      Wip.order('updated_at desc')
    end
  end

  def page_selection
    Wip.page(page)
  end

  def states
    Array.wrap(filters[:state])
  end

  def tags
    Array.wrap(filters[:tag])
  end

  def marks
    Array.wrap(filters[:mark])
  end

  def doing
    Array.wrap(filters[:doing])
  end

  def created
    Array.wrap(filters[:created])
  end

  def commented
    Array.wrap(filters[:commented])
  end

  def query
    filters[:query]
  end

  def user_params
    filters[:user]
  end

  def user_id_params
    filters[:user_id]
  end

  def sort
    filters[:sort]
  end

  def page
    filters[:page]
  end
end
