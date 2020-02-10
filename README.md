# redmine_private_support_email
## Installation
1. Pull the repository into redmine/plugins/
2. Restart Redmine

## Configuration
1. Administration -> Settings -> Issue tracking

Enable `Allow cross-project issue relations` setting.

## Rake task

```rake redmine:email:receive_imap RAILS_ENV="production" host=imap.mail.com port=993 ssl=SSL username=support@company.com password=my-very-secret-password folder=Tickets project=support-emails tracker=Support unknown_user=accept no_permission_check=1```

* Host = your IMAP server
* username = IMAP username
* password = IMAP password
* folder = IMAP folder
* project = target Redmine private project
* tracker = new issues will have this tracker type, e.g. Support
