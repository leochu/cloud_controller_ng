class MaxAppTasksPolicy
  def initialize(task, space_or_org, error_name)
    @task = task
    @space_or_org = space_or_org
    @error_name = error_name
    @errors = task.errors
  end

  def validate
    return unless @space_or_org
    quota_definition = @space_or_org.quota_definition
    return unless quota_definition
    return if quota_definition.app_task_limit == -1

    if @space_or_org.meets_max_task_limit?
      @errors.add(:app_task_limit, @error_name)
    end
  end
end
