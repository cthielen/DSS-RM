# This controller is necessary for single resource-type access, needed for the JSON API
# in order to allow clients to create rules without nesting them in a 'Group' object.
class GroupRulesController < ApplicationController
  before_filter :new_group_rule_from_params, :only => :create
  filter_access_to :all, :attribute_check => true

  def show
    @group_rule = GroupRule.find(params[:id])

    respond_to do |format|
      format.json { render json: @group_rule }
    end
  end

  def create
    @group_rule.save

    respond_to do |format|
      format.json { render json: @group_rule }
    end
  end

  def update
    @group_rule.update_attributes(params[:group_rule])

    respond_to do |format|
      format.json { render json: @group_rule }
    end
  end

  def destroy
    @group_rule.destroy

    respond_to do |format|
      format.json { render json: @group_rule }
    end
  end

  private

  def new_group_rule_from_params
    @group_rule = GroupRule.new(params[:group_rule])
  end
end
