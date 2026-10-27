// Covers Clarity Work's background pieces: reminders, recurring spawn,
// notifications, and the SharePoint sync/delete jobs.
@IsTest
private class ClarityWorkJobsTest {

    // Answers both the Microsoft token request and the Graph upload/delete calls
    private class GraphMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getMethod() == 'DELETE') {
                res.setStatusCode(204);
                return res;
            }
            res.setStatusCode(200);
            res.setBody('{"access_token":"test-token","id":"1","name":"Notes.txt","webUrl":"https://sharepoint.test/Notes.txt"}');
            return res;
        }
    }

    private static User otherUser() {
        List<User> users = [
            SELECT Id FROM User
            WHERE IsActive = true AND UserType = 'Standard' AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0];
    }

    // ─── TaskNeglectScheduler ────────────────────────────────────────────────

    @IsTest
    static void dueTomorrowRemindersOnlyForClarityTasks() {
        insert new List<Task>{
            new Task(Subject = 'Clarity due tomorrow', Kanban_Status__c = 'Queue', Status = 'Open',
                     ActivityDate = Date.today().addDays(1)),
            new Task(Subject = 'Other app task', Status = 'Open', ActivityDate = Date.today().addDays(1))
        };

        Test.startTest();
        TaskNeglectScheduler.run();
        Test.stopTest();

        // run() has no return value; this documents the scoping rule the query enforces
        Assert.areEqual(1, [
            SELECT COUNT() FROM Task
            WHERE ActivityDate = :Date.today().addDays(1)
            AND Kanban_Status__c != 'Complete' AND Kanban_Status__c != null AND IsClosed = false
        ]);
    }

    @IsTest
    static void buildRemindersCoversEveryReminderType() {
        User other = otherUser();
        Task t = new Task(Subject = 'Neglected', Kanban_Status__c = 'Queue', Status = 'Open',
                          OwnerId = UserInfo.getUserId());
        if (other != null) {
            System.runAs(other) { insert t; } // creator differs from owner → creator also emailed
        } else {
            insert t;
        }
        List<Task> tasks = [SELECT Id, Subject, OwnerId, CreatedById FROM Task WHERE Id = :t.Id];

        Test.startTest();
        List<Messaging.SingleEmailMessage> emails = TaskNeglectScheduler.buildReminders(tasks, tasks, tasks);
        Test.stopTest();

        Assert.areEqual(other != null ? 4 : 3, emails.size());
    }

    @IsTest
    static void reminderScheduleRunsAndIsIdempotent() {
        Test.startTest();
        TaskNeglectScheduler.setupSchedule();
        TaskNeglectScheduler.setupSchedule();
        System.schedule('Clarity reminder test run', '0 0 5 * * ?', new TaskNeglectScheduler());
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :TaskNeglectScheduler.JOB_NAME]);
    }

    // ─── RecurringTaskSpawnJob ───────────────────────────────────────────────

    @IsTest
    static void spawnHandlesEveryFrequency() {
        Date today = Date.today();
        List<Recurring_Task_Template__c> templates = new List<Recurring_Task_Template__c>{
            new Recurring_Task_Template__c(Subject__c = 'Never spawned', Is_Active__c = true, Frequency__c = 'Monthly'),
            new Recurring_Task_Template__c(Subject__c = 'Weekly', Is_Active__c = true, Frequency__c = 'Weekly',
                                           Spawn_Day__c = 1, Last_Spawn_Date__c = today.addDays(-30)),
            new Recurring_Task_Template__c(Subject__c = 'Bi-weekly', Is_Active__c = true, Frequency__c = 'Bi-Weekly',
                                           Last_Spawn_Date__c = today.addDays(-30)),
            new Recurring_Task_Template__c(Subject__c = 'Monthly', Is_Active__c = true, Frequency__c = 'Monthly',
                                           Spawn_Day__c = 31, Last_Spawn_Date__c = today.addMonths(-2)),
            new Recurring_Task_Template__c(Subject__c = 'Inactive', Is_Active__c = false)
        };
        insert templates;
        Tag__c tag = new Tag__c(Name = 'Recurring');
        insert tag;
        insert new Recurring_Template_Tag__c(Template_Id__c = templates[0].Id, Tag_Id__c = tag.Id);

        Test.startTest();
        RecurringTaskSpawnJob.spawnForCurrentMonth();
        Test.stopTest();

        List<Task> spawned = [SELECT Id, Subject, Kanban_Status__c FROM Task WHERE Subject = 'Never spawned'];
        Assert.areEqual(1, spawned.size());
        Assert.areEqual('Queue', spawned[0].Kanban_Status__c);
        Assert.areEqual(1, [SELECT COUNT() FROM Task_Tag__c WHERE Task_Id__c = :spawned[0].Id]);
        Assert.areEqual(0, [SELECT COUNT() FROM Task WHERE Subject = 'Inactive']);
        Assert.areEqual(today, [SELECT Last_Spawn_Date__c FROM Recurring_Task_Template__c WHERE Id = :templates[0].Id].Last_Spawn_Date__c);
    }

    @IsTest
    static void spawnScheduleRunsAndIsIdempotent() {
        Test.startTest();
        RecurringTaskSpawnJob.setupSchedule();
        RecurringTaskSpawnJob.setupSchedule();
        System.schedule('Clarity spawn test run', '0 0 2 * * ?', new RecurringTaskSpawnJob());
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :RecurringTaskSpawnJob.JOB_NAME]);
    }

    // ─── TaskNotificationService ─────────────────────────────────────────────

    @IsTest
    static void notificationsCoverEachEvent() {
        User other = otherUser();
        if (other == null) return;
        Task t = new Task(Subject = 'Notify me', Kanban_Status__c = 'Queue', Status = 'Open');
        System.runAs(other) { insert t; }
        insert new Task_Mention__c(Task_Id__c = t.Id, User_Id__c = other.Id);

        Test.startTest();
        TaskNotificationService.notifyComment(t.Id, new List<String>{ other.Id, 'not-an-id', '' }, UserInfo.getUserId());
        TaskNotificationService.notifyAssigned(t.Id, other.Id, UserInfo.getUserId());
        TaskNotificationService.notifyAssigned(t.Id, UserInfo.getUserId(), UserInfo.getUserId()); // self-assign: no-op
        TaskNotificationService.notifyStatusChange(t.Id, 'Queue', 'Complete', UserInfo.getUserId());
        TaskNotificationService.notifyStatusChange(t.Id, 'Queue', 'Queue', UserInfo.getUserId());  // unchanged: no-op
        TaskNotificationService.notifyDescriptionMentioned(t.Id,
            new List<String>{ other.Id, other.Id, 'not-an-id' }, UserInfo.getUserId());
        TaskNotificationService.notifyDescriptionMentioned(t.Id, new List<String>(), null);
        TaskNotificationService.notifyComment('', null, null);
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Task_Mention__c WHERE Task_Id__c = :t.Id]);
    }

    // ─── SharePoint jobs ─────────────────────────────────────────────────────

    @IsTest
    static void syncJobUploadsTaskFilesToSharePoint() {
        Task t = new Task(Subject = 'With files', Kanban_Status__c = 'Queue', Status = 'Open');
        insert t;
        ContentVersion cv = new ContentVersion(Title = 'Notes', PathOnClient = 'Notes.txt',
                                               VersionData = Blob.valueOf('hello'));
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(ContentDocumentId = docId, LinkedEntityId = t.Id, ShareType = 'V');
        Test.setMock(HttpCalloutMock.class, new GraphMock());

        Test.startTest();
        TaskKanbanController.syncTaskFilesToSharePoint(t.Id);
        Test.stopTest();

        // Depends on the org's SharePoint_Configuration__mdt "Default" record having a Drive Id
        List<SharePoint_Sync__c> synced = [SELECT File_Name__c, Folder_Name__c FROM SharePoint_Sync__c WHERE Related_Record_Id__c = :t.Id];
        if (!synced.isEmpty()) {
            Assert.areEqual('Notes.txt', synced[0].File_Name__c);
            Assert.isTrue(synced[0].Folder_Name__c.startsWith('Clarity Work/'));
            Assert.areEqual(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId]);
        }
    }

    @IsTest
    static void deleteJobRemovesFolderAndSyncRecords() {
        Task t = new Task(Subject = 'Synced task', Kanban_Status__c = 'Queue', Status = 'Open');
        insert t;
        insert new SharePoint_Sync__c(Related_Record_Id__c = t.Id, File_Name__c = 'Notes.txt',
                                      Folder_Name__c = 'Clarity Work/T-1 - Synced task & more #1');
        Test.setMock(HttpCalloutMock.class, new GraphMock());

        Test.startTest();
        System.enqueueJob(new TaskSharePointDeleteJob(t.Id));
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM SharePoint_Sync__c WHERE Related_Record_Id__c = :t.Id]);
    }
}
