require_dependency 'mail_handler'

module MailHandlerPatch

  class MissingInformation < StandardError; end

  # Creates a new issue and adds a related link to the parameter-given issue.
  def receive_issue_and_relate(target_project, related_issue)
    project = target_project
    # check permission
    unless handler_options[:no_permission_check]
      raise UnauthorizedAction, "not allowed to add issues to project [#{project.name}]" unless user.allowed_to?(:add_issues, project)
    end

    issue = Issue.new(:author => user, :project => project)
    attributes = issue_attributes_from_keywords(issue)
    if handler_options[:no_permission_check]
      issue.tracker_id = attributes['tracker_id']
      if project
        issue.tracker_id ||= project.trackers.first.try(:id)
      end
    end
    issue.safe_attributes = attributes
    issue.safe_attributes = {'custom_field_values' => custom_field_values_from_keywords(issue)}
    issue.subject = cleaned_up_subject
    if issue.subject.blank?
      issue.subject = "(#{ll(Setting.default_language, :text_no_subject)})"
    end
    issue.description = cleaned_up_text_body
    issue.start_date ||= User.current.today if Setting.default_issue_start_date_to_creation_date?
    if handler_options[:issue][:is_private] == '1'
      issue.is_private = true
    end

    relation = IssueRelation.new
    relation.issue_from = related_issue
    relation.issue_to = issue
    relation.init_journals(User.current)

    begin
      saved = relation.save
    rescue ActiveRecord::RecordNotUnique
      saved = false
      relation.errors.add :base, :taken
    end

    # add To and Cc as watchers before saving so the watchers can reply to Redmine
    add_watchers(issue)
    issue.save!
    add_attachments(issue)
    logger&.info "MailHandlerPatch: issue ##{issue.id} created by #{user}"
    issue
  end

  # Adds a note to an existing issue
  def receive_issue_reply(issue_id, from_journal=nil)
    issue = Issue.find_by(:id => issue_id)
    if issue.nil?
      logger&.info "MailHandler: ignoring reply from [#{email.from.first}] to a nonexistent issue"
      return nil
    end

    logger&.info "MailHandlerPatch: rerouting a reply to public issue #{issue}"
    original_issue = issue
    private_project = Project.find(Setting.plugin_redmine_private_email_support["target_private_project"])
    if private_project.nil?
      raise MissingInformation, 'Target private project is not configured for email handling. Check you plugin settings.'
    end

    relations = original_issue.relations

    existing_private_open_issues = Array.new()
    closed_status_id = IssueStatus.find_by_name("Closed").id
    relations.each do |relation|
      from_issue = Issue.find(relation.issue_from_id)
      to_issue = Issue.find(relation.issue_to_id)
      if from_issue.project_id == private_project.id && from_issue.status_id != closed_status_id
        existing_private_open_issues.push(from_issue)
      elsif to_issue.project_id == private_project.id && to_issue.status_id != closed_status_id
        existing_private_open_issues.push(to_issue)
      end
    end

    if existing_private_open_issues.length == 0
      receive_issue_and_relate(private_project, original_issue)
      return
    else
      issues_to_comment = existing_private_open_issues
    end

    issues_to_comment.each do |issue|
      # check permission
      unless handler_options[:no_permission_check]
        unless user.allowed_to?(:add_issue_notes, issue.project) ||
            user.allowed_to?(:edit_issues, issue.project)
          raise UnauthorizedAction, "not allowed to add notes on issues to project [#{project.name}]"
        end
      end

      # ignore CLI-supplied defaults for new issues
      handler_options[:issue] = {}

      journal = issue.init_journal(user)
      if from_journal && from_journal.private_notes?
        # If the received email was a reply to a private note, make the added note private
        issue.private_notes = true
      end
      issue.safe_attributes = issue_attributes_from_keywords(issue)
      issue.safe_attributes = {'custom_field_values' => custom_field_values_from_keywords(issue)}
      journal.notes = cleaned_up_text_body

      # add To and Cc as watchers before saving so the watchers can reply to Redmine
      add_watchers(issue)
      issue.save!
      add_attachments(issue)
      logger&.info "MailHandler: issue ##{issue.id} updated by #{user}"
      journal
    end
  end

end

MailHandler.prepend(MailHandlerPatch)
