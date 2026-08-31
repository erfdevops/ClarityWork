public without sharing class TaskNotificationService {

    private static final String NOTIF_TYPE_DEV_NAME = 'Task_Activity';

    // Called from addComment: bells all involved, emails newly mentioned users
    public static void notifyComment(String taskId, List<String> newMentionIds, String actorId) {
        if (String.isBlank(taskId)) return;
        Task t = [SELECT Id, Subject, OwnerId, CreatedById FROM Task WHERE Id = :taskId LIMIT 1];
        Id actor = String.isNotBlank(actorId) ? (Id)actorId : UserInfo.getUserId();

        Set<Id> involved = getInvolvedUserIds(taskId, t);
        involved.remove(actor);
        if (!involved.isEmpty()) {
            sendBell(involved,
                'New comment on task',
                'A new comment was posted on: ' + t.Subject,
                taskId);
        }

        if (newMentionIds != null && !newMentionIds.isEmpty()) {
            List<Id> toEmail = new List<Id>();
            for (String uid : newMentionIds) {
                if (String.isNotBlank(uid)) {
                    try {
                        Id parsed = (Id)uid;
                        if (parsed != actor) toEmail.add(parsed);
                    } catch (Exception e) {}
                }
            }
            if (!toEmail.isEmpty()) {
                String baseUrl = URL.getOrgDomainUrl().toExternalForm();
                sendEmail(toEmail,
                    'Clarity Task: You were @mentioned',
                    '<p>You were <strong>@mentioned</strong> in a comment on the task:</p>'
                    + '<p><strong>' + t.Subject + '</strong></p>'
                    + '<p><a href="' + baseUrl + '/' + t.Id + '">View Task</a></p>');
            }
        }
    }

    // Called when a task is assigned to a new user
    public static void notifyAssigned(String taskId, String newAssigneeId, String actorId) {
        if (String.isBlank(taskId) || String.isBlank(newAssigneeId)) return;
        Id actor = String.isNotBlank(actorId) ? (Id)actorId : UserInfo.getUserId();
        Id assignee = (Id)newAssigneeId;
        if (assignee == actor) return;

        Task t = [SELECT Id, Subject FROM Task WHERE Id = :taskId LIMIT 1];
        Set<Id> recipients = new Set<Id>{ assignee };
        sendBell(recipients, 'Task assigned to you', 'You were assigned: ' + t.Subject, taskId);
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        sendEmail(new List<Id>(recipients),
            'Clarity Task: Assigned to You',
            '<p>You have been assigned to the following task:</p>'
            + '<p><strong>' + t.Subject + '</strong></p>'
            + '<p><a href="' + baseUrl + '/' + t.Id + '">View Task</a></p>');
    }

    // Called when task status changes
    public static void notifyStatusChange(String taskId, String oldStatus, String newStatus, String actorId) {
        if (String.isBlank(taskId) || oldStatus == newStatus) return;
        Task t = [SELECT Id, Subject, CreatedById FROM Task WHERE Id = :taskId LIMIT 1];
        Id actor = String.isNotBlank(actorId) ? (Id)actorId : UserInfo.getUserId();
        if (String.isBlank(t.CreatedById)) return;
        Id creator = t.CreatedById;
        if (creator == actor) return;

        Set<Id> recipients = new Set<Id>{ creator };
        String title = 'Task moved to ' + newStatus;
        String body = '"' + t.Subject + '" was moved to ' + newStatus + '.';
        sendBell(recipients, title, body, taskId);

        if (newStatus == 'Complete') {
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            sendEmail(new List<Id>(recipients),
                'Clarity Task: Marked Complete',
                '<p>' + body + '</p>'
                + '<p><a href="' + baseUrl + '/' + t.Id + '">View Task</a></p>');
        }
    }

    // Called when description @mentions are saved on task create/update
    public static void notifyDescriptionMentioned(String taskId, List<String> mentionedUserIds, String actorId) {
        if (String.isBlank(taskId) || mentionedUserIds == null || mentionedUserIds.isEmpty()) return;
        Task t = [SELECT Id, Subject FROM Task WHERE Id = :taskId LIMIT 1];
        Id actor = String.isNotBlank(actorId) ? (Id)actorId : UserInfo.getUserId();
        List<Id> toNotify = new List<Id>();
        Set<Id> seen = new Set<Id>();
        for (String uid : mentionedUserIds) {
            if (String.isNotBlank(uid)) {
                try {
                    Id parsed = (Id)uid;
                    if (parsed != actor && !seen.contains(parsed)) {
                        toNotify.add(parsed);
                        seen.add(parsed);
                    }
                } catch (Exception e) {}
            }
        }
        if (toNotify.isEmpty()) return;
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        sendBell(new Set<Id>(toNotify),
            'You were mentioned in a task',
            '@mentioned in the description of: ' + t.Subject,
            taskId);
        sendEmail(toNotify,
            'Clarity Task: You were @mentioned',
            '<p>You were <strong>@mentioned</strong> in the description of a task:</p>'
            + '<p><strong>' + t.Subject + '</strong></p>'
            + '<p><a href="' + baseUrl + '/' + t.Id + '">View Task</a></p>');
    }

    private static Set<Id> getInvolvedUserIds(String taskId, Task t) {
        Set<Id> ids = new Set<Id>();
        if (t.CreatedById != null) ids.add(t.CreatedById);
        if (t.OwnerId     != null) ids.add(t.OwnerId);
        for (Task_Mention__c m : [
            SELECT User_Id__c FROM Task_Mention__c WHERE Task_Id__c = :taskId
        ]) {
            if (String.isNotBlank(m.User_Id__c)) {
                try { ids.add((Id)m.User_Id__c); } catch (Exception e) {}
            }
        }
        return ids;
    }

    private static void sendBell(Set<Id> recipientIds, String title, String body, String targetId) {
        if (recipientIds == null || recipientIds.isEmpty()) return;
        try {
            List<CustomNotificationType> types = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = :NOTIF_TYPE_DEV_NAME LIMIT 1
            ];
            if (types.isEmpty()) return;
            Set<String> recipientStrs = new Set<String>();
            for (Id rid : recipientIds) recipientStrs.add(String.valueOf(rid));
            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setTitle(title);
            notif.setBody(body);
            notif.setNotificationTypeId(types[0].Id);
            notif.setTargetId(targetId);
            notif.send(recipientStrs);
        } catch (Exception e) {
            System.debug('TaskNotificationService.sendBell: ' + e.getMessage());
        }
    }

    private static void sendEmail(List<Id> recipientIds, String subject, String htmlBody) {
        if (recipientIds == null || recipientIds.isEmpty()) return;
        try {
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            for (Id uid : recipientIds) {
                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                msg.setTargetObjectId(uid);
                msg.setSubject(subject);
                msg.setHtmlBody(htmlBody);
                msg.setSaveAsActivity(false);
                emails.add(msg);
            }
            Messaging.sendEmail(emails);
        } catch (Exception e) {
            System.debug('TaskNotificationService.sendEmail: ' + e.getMessage());
        }
    }
}
