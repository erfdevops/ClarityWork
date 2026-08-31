global class TaskNeglectScheduler implements Schedulable {

    public static final String JOB_NAME = 'Clarity Work - Task Reminders';
    public static final String CRON_EXP = '0 0 6 * * ? *'; // Daily at 6 AM

    global void execute(SchedulableContext ctx) {
        run();
    }

    public static void run() {
        Date today    = Date.today();
        Date tomorrow = today.addDays(1);

        // Day-window approach: each task gets each email exactly once
        Datetime sevenDaysAgo    = Datetime.now().addDays(-7);
        Datetime eightDaysAgo    = Datetime.now().addDays(-8);
        Datetime fourteenDaysAgo = Datetime.now().addDays(-14);
        Datetime fifteenDaysAgo  = Datetime.now().addDays(-15);

        List<Task> sevenDayNeglect = [
            SELECT Id, Subject, OwnerId
            FROM Task
            WHERE Kanban_Status__c != 'Complete'
            AND IsClosed = false
            AND Kanban_Status__c != null
            AND LastModifiedDate <= :sevenDaysAgo
            AND LastModifiedDate >= :eightDaysAgo
            LIMIT 200
        ];

        List<Task> fourteenDayNeglect = [
            SELECT Id, Subject, OwnerId, CreatedById
            FROM Task
            WHERE Kanban_Status__c != 'Complete'
            AND IsClosed = false
            AND Kanban_Status__c != null
            AND LastModifiedDate <= :fourteenDaysAgo
            AND LastModifiedDate >= :fifteenDaysAgo
            LIMIT 200
        ];

        List<Task> dueTomorrow = [
            SELECT Id, Subject, OwnerId
            FROM Task
            WHERE ActivityDate = :tomorrow
            AND Kanban_Status__c != 'Complete'
            AND IsClosed = false
            LIMIT 200
        ];

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Task t : sevenDayNeglect) {
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setTargetObjectId(t.OwnerId);
            msg.setSubject('Reminder: Task inactive for 7 days');
            msg.setHtmlBody('<p>The following task has had no activity for 7 or more days:</p>'
                + '<p><strong><a href="' + baseUrl + '/' + t.Id + '">' + t.Subject + '</a></strong></p>'
                + '<p>Please review and update the task status or leave a comment.</p>');
            msg.setSaveAsActivity(false);
            emails.add(msg);
        }

        for (Task t : fourteenDayNeglect) {
            String htmlBody = '<p>The following task has had no activity for 14 or more days:</p>'
                + '<p><strong><a href="' + baseUrl + '/' + t.Id + '">' + t.Subject + '</a></strong></p>'
                + '<p>Please review and update the task status or close it if no longer needed.</p>';

            Messaging.SingleEmailMessage assigneeMsg = new Messaging.SingleEmailMessage();
            assigneeMsg.setTargetObjectId(t.OwnerId);
            assigneeMsg.setSubject('Reminder: Task inactive for 14 days');
            assigneeMsg.setHtmlBody(htmlBody);
            assigneeMsg.setSaveAsActivity(false);
            emails.add(assigneeMsg);

            if (t.CreatedById != null && t.CreatedById != t.OwnerId) {
                Messaging.SingleEmailMessage creatorMsg = new Messaging.SingleEmailMessage();
                creatorMsg.setTargetObjectId(t.CreatedById);
                creatorMsg.setSubject('Reminder: Task inactive for 14 days');
                creatorMsg.setHtmlBody(htmlBody);
                creatorMsg.setSaveAsActivity(false);
                emails.add(creatorMsg);
            }
        }

        List<CustomNotificationType> notifTypes = [
            SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Task_Activity' LIMIT 1
        ];

        for (Task t : dueTomorrow) {
            if (!notifTypes.isEmpty()) {
                try {
                    Messaging.CustomNotification notif = new Messaging.CustomNotification();
                    notif.setTitle('Task due tomorrow');
                    notif.setBody(t.Subject + ' is due tomorrow.');
                    notif.setNotificationTypeId(notifTypes[0].Id);
                    notif.setTargetId(t.Id);
                    notif.send(new Set<String>{ String.valueOf(t.OwnerId) });
                } catch (Exception e) {
                    System.debug('TaskNeglectScheduler.bell: ' + e.getMessage());
                }
            }

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setTargetObjectId(t.OwnerId);
            msg.setSubject('Reminder: Task Due Tomorrow');
            msg.setHtmlBody('<p>The following task is due tomorrow:</p>'
                + '<p><strong><a href="' + baseUrl + '/' + t.Id + '">' + t.Subject + '</a></strong></p>');
            msg.setSaveAsActivity(false);
            emails.add(msg);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug('TaskNeglectScheduler.sendEmail: ' + e.getMessage());
            }
        }
    }

    public static void setupSchedule() {
        List<CronTrigger> existing = [
            SELECT Id, CronExpression FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            if (existing[0].CronExpression == CRON_EXP) return;
            System.abortJob(existing[0].Id);
        }
        System.schedule(JOB_NAME, CRON_EXP, new TaskNeglectScheduler());
    }
}
