module ListCutter
  class ExternalActionRule < Rule
    fields :action_slugs, :since, :activity

    validates_presence_of :action_slugs, :message => 'Please specify the external action page slugs'
    validates_presence_of :since, :message => 'Please specify date'
    validates_inclusion_of :activity, :in => ExternalActivityEvent::ACTIVITIES
    validates_each :since do |record, attr, value|
      record.errors.add attr, "can't be in the future" if value && Date.strptime(value, '%m/%d/%Y').future?
    end

    def to_sql
      date = Date.strptime(since, '%m/%d/%Y')

      sanitize_sql <<-SQL, @movement.id, self.activity, self.action_slugs, date
        SELECT user_id FROM external_activity_events
        WHERE movement_id = ?
        AND activity = ?
        AND action_slug IN (?)
        AND created_at >= ?
        GROUP BY user_id
      SQL
    end

    def active?
      !action_slugs.blank?
    end

    def to_human_sql
      slugs = (action_slugs.length > 20) ? "#{action_slugs.length} actions (too many to list)" : action_slugs

      "External #{activity.titleize.downcase} #{is_clause} any of the following since #{since}: #{slugs}"
    end

  end
end