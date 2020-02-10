require 'redmine'
require_dependency 'mail_handler_patch'

Redmine::Plugin.register :private_email_support do
  name 'Private Email Support plugin'
  author 'Juhani Seppälä'
  description 'A Redmine plugin for redirecting issue replies into a private project.'
  version '0.0.1'
  url 'https://github.com/jseplae/redmine_private_email_support'
  author_url 'https://github.com/jseplae'
  settings :default => {'target_private_project' => nil},
           :partial => 'settings/private_email_support_settings'
end