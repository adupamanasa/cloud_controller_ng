module VCAP::CloudController
  class ServicePlanAccess < BaseAccess
    def read?(service_plan)
      return true if object_is_visible_to_user_for_read?(service_plan, context.user)
      super(service_plan)
    end

    private

    def object_is_visible_to_user_for_read?(service_plan, user)
      VCAP::CloudController::ServicePlan.user_visible(user, false, :read).where(guid: service_plan.guid).count > 0
    end
  end
end
