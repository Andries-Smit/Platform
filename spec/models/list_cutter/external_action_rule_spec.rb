require "spec_helper"

describe ListCutter::ExternalActionRule do
  before do
    @action_taken = ExternalActivityEvent::Activity::ACTION_TAKEN
    @action_created = ExternalActivityEvent::Activity::ACTION_CREATED
    @yesterday = 1.day.ago.strftime("%m/%d/%Y")
  end

  it { should validate_presence_of(:action_slugs).with_message("Please specify the external action page slugs") }
  it { should validate_presence_of(:since).with_message("Please specify date") }
  it { should ensure_inclusion_of(:activity).in_array(ExternalActivityEvent::ACTIVITIES) }

  it "should ensure that since date is not in the future" do
    rule = ListCutter::ExternalActionRule.new(:not => false, :action_slugs => ['cuba'], :activity => @action_taken, :since => 1.day.from_now.strftime("%m/%d/%Y"))

    rule.valid?.should be_false
    rule.errors.messages.should == {:since => ["can't be in the future"]}
  end

  describe do

    before do
      @movement = FactoryGirl.create(:movement)
      @bob, @john, @sally, @jenny = FactoryGirl.create_list(:user, 4, :movement => @movement)
    end

    it "should return users that have taken action on specific external pages" do
      event_attributes = {:movement_id => @movement.id,
                          :role => 'signer',
                          :action_language_iso => 'en',
                          :source => 'controlshift',
                          :activity => @action_taken}

      ExternalActivityEvent.create! event_attributes.merge(:user_id => @bob.id,   :action_slug => 'russia',)
      ExternalActivityEvent.create! event_attributes.merge(:user_id => @john.id,  :action_slug => 'cuba',)
      ExternalActivityEvent.create! event_attributes.merge(:user_id => @sally.id, :action_slug => 'ecuador',)
      ExternalActivityEvent.create! event_attributes.merge(:user_id => @jenny.id, :action_slug => 'china', :activity => @action_created, :role => 'creator')

      rule = ListCutter::ExternalActionRule.new(:not => false, :action_slugs => ['cuba', 'ecuador', 'china'], :activity => @action_taken, :since => @yesterday, :movement => @movement)

      rule.to_relation.all.should =~ [@john, @sally, @jenny]
    end

    describe 'action_created' do

      before do
        all_action_slugs = ['russia', 'cuba', 'ecuador', 'china']
        @rule_parameters = {:not => false, :action_slugs => all_action_slugs, :activity => @action_created, :since => @yesterday, :movement => @movement}
        event_attributes = {:movement_id => @movement.id, :action_language_iso => 'en', :source => 'controlshift'}
        ExternalActivityEvent.create! event_attributes.merge(:user_id => @bob.id,     :action_slug => 'russia',  :activity => @action_created, :role => 'creator')
        ExternalActivityEvent.create! event_attributes.merge(:user_id => @john.id,    :action_slug => 'cuba',    :activity => @action_created, :role => 'creator')
        ExternalActivityEvent.create! event_attributes.merge(:user_id => @sally.id,   :action_slug => 'ecuador', :activity => @action_created, :role => 'creator')
        ExternalActivityEvent.create! event_attributes.merge(:user_id => @jenny.id,   :action_slug => 'china',   :activity => @action_taken,   :role => 'signer')
      end

      it "should return users that have created external actions for the specified sources" do
        rule = ListCutter::ExternalActionRule.new(@rule_parameters)

        rule.to_relation.all.should =~ [@bob, @john, @sally]
      end

      it "should return users that have created external actions within a timeframe" do
        ExternalActivityEvent.find_by_user_id(@bob.id).update_attribute(:created_at, 3.days.ago)

        rule = ListCutter::ExternalActionRule.new(@rule_parameters)

        rule.to_relation.all.should =~ [@john, @sally]
      end

    end

  end

  describe "#to_human_sql" do

    it "should return rule conditions in human readable form" do
      slugs = ['cuba', 'ecuador']

      ListCutter::ExternalActionRule.new(:not => false, :action_slugs => slugs, :activity => @action_taken, :since => @yesterday).to_human_sql.should ==
          "External action taken is any of the following since #{@yesterday}: [\"cuba\", \"ecuador\"]"

      ListCutter::ExternalActionRule.new(:not => true, :action_slugs => slugs, :activity => @action_created, :since => @yesterday).to_human_sql.should ==
          "External action created is not any of the following since #{@yesterday}: [\"cuba\", \"ecuador\"]"
    end

    it "should truncate action slugs list when it's very long" do
      slugs = *(1..30).map {|i| i.to_s}

      ListCutter::ExternalActionRule.new(:not => false, :action_slugs => slugs, :activity => @action_taken, :since => @yesterday).to_human_sql.should ==
          "External action taken is any of the following since #{@yesterday}: 30 actions (too many to list)"
    end

  end

end