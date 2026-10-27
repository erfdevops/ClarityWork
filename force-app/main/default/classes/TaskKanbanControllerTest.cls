@IsTest
private class TaskKanbanControllerTest {

    @TestSetup
    static void setup() {
        Project__c p = new Project__c(Name = 'Clarity Test Project');
        insert p;
        insert new List<Task>{
            new Task(Subject = 'Board task A', Kanban_Status__c = 'Queue', Status = 'Open',
                     Project__c = p.Id, ActivityDate = Date.today().addDays(3)),
            new Task(Subject = 'Board task B', Kanban_Status__c = 'In Progress', Status = 'In Progress')
        };
    }

    private static Task taskNamed(String subject) {
        return [SELECT Id, Subject FROM Task WHERE Subject = :subject LIMIT 1];
    }

    // Another active user, for assignment / mention / status-change notifications
    private static User otherUser() {
        List<User> users = [
            SELECT Id FROM User
            WHERE IsActive = true AND UserType = 'Standard' AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0];
    }

    // Employee__c for the running user; tolerates org-specific automation rejecting the insert
    private static Boolean makeEmployee() {
        return Database.insert(new Employee__c(Name = 'Test Employee', User__c = UserInfo.getUserId()), false).isSuccess();
    }

    @IsTest
    static void boardQueries() {
        Project__c p = [SELECT Id FROM Project__c LIMIT 1];
        makeEmployee();
        // An open task from another app (no Kanban_Status__c) must stay off the board
        insert new Task(Subject = 'Other app task', Status = 'Open', Project__c = p.Id);

        Test.startTest();
        Assert.isTrue(TaskKanbanController.pingSession());
        Assert.areEqual(2, TaskKanbanController.getUserTasks(null).size());
        Assert.areEqual(1, TaskKanbanController.getUserTasks(p.Id).size());
        Assert.isNotNull(TaskKanbanController.getSmartGoals());
        Assert.isNotNull(TaskKanbanController.getSmartGoalsForMonth('2026-11'));
        Assert.isNotNull(TaskKanbanController.getSmartGoalsForMonth('2026-03'));
        Assert.isNotNull(TaskKanbanController.getSmartGoalsForMonth('not-a-month'));
        Assert.areEqual(1, TaskKanbanController.getUserProjects().size());
        Assert.isNotNull(TaskKanbanController.getExportColumns());
        Assert.isFalse(TaskKanbanController.getActiveUsers().isEmpty());
        Test.stopTest();
    }

    @IsTest
    static void createUpdateAndStatusChanges() {
        User other = otherUser();
        Project__c p = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        Task created = TaskKanbanController.createTask('New board task', p.Id, 'Queue',
            Date.today().addDays(5), 'Details', 'High', new List<String>(), 2.5,
            other != null ? other.Id : null, Date.today().toStartOfMonth());
        Task updated = TaskKanbanController.updateTask(created.Id, 'Renamed task', null, 'In Progress',
            Date.today().addDays(6), 'More details', 'Low', new List<String>(), 3, null, null);
        TaskKanbanController.updateTaskStatus(created.Id, 'Complete');
        TaskKanbanController.bulkUpdateStatus(new List<String>{ created.Id }, 'Queue');
        TaskKanbanController.bulkAssignToMonth(new List<String>{ created.Id }, Date.newInstance(2026, 12, 1));
        Test.stopTest();

        Task t = [SELECT Subject, Kanban_Status__c, Status, Assign_To_Month__c, Priority FROM Task WHERE Id = :created.Id];
        Assert.areEqual('Renamed task', updated.Subject);
        Assert.areEqual('Queue', t.Kanban_Status__c);
        Assert.areEqual('Open', t.Status);
        Assert.areEqual(Date.newInstance(2026, 12, 1), t.Assign_To_Month__c);
        Assert.areEqual('Low', t.Priority);
    }

    @IsTest
    static void statusChangeNotifiesCreator() {
        User other = otherUser();
        if (other == null) return;
        Task t = new Task(Subject = 'Created by someone else', Kanban_Status__c = 'Queue', Status = 'Open');
        System.runAs(other) {
            insert t;
        }

        Test.startTest();
        TaskKanbanController.updateTaskStatus(t.Id, 'Complete');
        Test.stopTest();

        Assert.areEqual('Completed', [SELECT Status FROM Task WHERE Id = :t.Id].Status);
    }

    @IsTest
    static void nativeStatusChangeSyncsKanbanStatus() {
        Task a = taskNamed('Board task A');

        Test.startTest();
        update new Task(Id = a.Id, Status = 'Completed');
        Test.stopTest();

        Assert.areEqual('Complete', [SELECT Kanban_Status__c FROM Task WHERE Id = :a.Id].Kanban_Status__c);
    }

    @IsTest
    static void nativeStatusChangeMapsInProgressAndOpen() {
        Task a = taskNamed('Board task A'); // Queue
        Task b = taskNamed('Board task B'); // In Progress

        Test.startTest();
        update new List<Task>{
            new Task(Id = a.Id, Status = 'In Progress'),
            new Task(Id = b.Id, Status = 'Open')
        };
        Test.stopTest();

        Assert.areEqual('In Progress', [SELECT Kanban_Status__c FROM Task WHERE Id = :a.Id].Kanban_Status__c);
        Assert.areEqual('Queue', [SELECT Kanban_Status__c FROM Task WHERE Id = :b.Id].Kanban_Status__c);
    }

    @IsTest
    static void nativeStatusChangeLeavesNonBoardTasksAlone() {
        Task outside = new Task(Subject = 'Not a Clarity task', Status = 'Open');
        insert outside;

        Test.startTest();
        update new Task(Id = outside.Id, Status = 'Completed');
        Test.stopTest();

        Assert.isNull([SELECT Kanban_Status__c FROM Task WHERE Id = :outside.Id].Kanban_Status__c);
    }

    @IsTest
    static void commentsAndMentions() {
        Task a = taskNamed('Board task A');
        User other = otherUser();
        List<String> mentioned = other != null ? new List<String>{ other.Id } : new List<String>();

        Test.startTest();
        Task_Comment__c c = TaskKanbanController.addComment(a.Id, 'Looks good', mentioned);
        Assert.areEqual(1, TaskKanbanController.getTaskComments(a.Id).size());
        TaskKanbanController.saveMentions(a.Id, mentioned);
        TaskKanbanController.deleteComment(c.Id);
        Test.stopTest();

        Assert.areEqual(0, TaskKanbanController.getTaskComments(a.Id).size());
        Assert.isTrue(TaskKanbanController.getTaskComments('').isEmpty());
    }

    @IsTest
    static void relationsProjectsTagsAndGoals() {
        Task a = taskNamed('Board task A');
        Task b = taskNamed('Board task B');
        Project__c p = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        TaskKanbanController.saveTaskRelations(a.Id, new List<String>{ b.Id, a.Id });
        TaskKanbanController.saveTaskProjects(a.Id, new List<String>{ p.Id });
        String tagId = TaskKanbanController.ensureTag('  Budget ');
        Assert.areEqual(tagId, TaskKanbanController.ensureTag('Budget'), 'existing tag is reused');
        Assert.isNull(TaskKanbanController.ensureTag(' '));
        TaskKanbanController.saveTaskTags(a.Id, new List<String>{ tagId });
        Test.stopTest();

        Assert.areEqual(b.Id, TaskKanbanController.getRelatedTasks(a.Id)[0].Id);
        Assert.areEqual(a.Id, TaskKanbanController.getRelatedTasks(b.Id)[0].Id);
        Assert.areEqual(1, TaskKanbanController.getTaskProjects(a.Id).size());
        Assert.areEqual(1, TaskKanbanController.getTaskTags(a.Id).size());
        Assert.areEqual(1, TaskKanbanController.searchTags('Bud').size());
        Assert.isTrue(TaskKanbanController.getTaskIdsForSmartGoal(p.Id).isEmpty());
        Assert.isTrue(TaskKanbanController.getTaskIdsForSmartGoal(null).isEmpty());
        Assert.isTrue(TaskKanbanController.getTaskSmartGoals(a.Id).isEmpty());
        Assert.isTrue(TaskKanbanController.getRelatedTasks(null).isEmpty());
        Assert.isTrue(TaskKanbanController.getTaskProjects(null).isEmpty());
        Assert.isTrue(TaskKanbanController.getTaskTags(null).isEmpty());
        Assert.isTrue(TaskKanbanController.getTaskSmartGoals(null).isEmpty());
    }

    @IsTest
    static void recurringTemplates() {
        Project__c p = [SELECT Id FROM Project__c LIMIT 1];
        String tagId = TaskKanbanController.ensureTag('Monthly');

        Test.startTest();
        Recurring_Task_Template__c tmpl = TaskKanbanController.saveRecurringTemplate(null, 'Monthly report',
            p.Id, 'High', 'Send the report', null, true, new List<String>(), 'Monthly', 1);
        TaskKanbanController.saveTemplateProjects(tmpl.Id, new List<String>{ p.Id });
        TaskKanbanController.saveTemplateTags(tmpl.Id, new List<String>{ tagId });
        TaskKanbanController.toggleRecurringTemplate(tmpl.Id, true);
        TaskKanbanController.triggerRecurringSpawn();
        Test.stopTest();

        Assert.areEqual(1, TaskKanbanController.getRecurringTemplates().size());
        Assert.areEqual(1, TaskKanbanController.getTemplateProjects(tmpl.Id).size());
        Assert.areEqual(1, TaskKanbanController.getTemplateTags(tmpl.Id).size());
        Assert.isTrue(TaskKanbanController.getTemplateSmartGoals(tmpl.Id).isEmpty());
        Assert.isTrue(TaskKanbanController.getTemplateProjects(null).isEmpty());
        Assert.isTrue(TaskKanbanController.getTemplateTags(null).isEmpty());
        Assert.isTrue(TaskKanbanController.getTemplateSmartGoals(null).isEmpty());

        List<Task> spawned = [SELECT Id, Project__c FROM Task WHERE Subject = 'Monthly report'];
        Assert.areEqual(1, spawned.size());
        Assert.areEqual(p.Id, spawned[0].Project__c);
        Assert.areEqual(1, [SELECT COUNT() FROM Task_Tag__c WHERE Task_Id__c = :spawned[0].Id]);

        TaskKanbanController.deleteRecurringTemplate(tmpl.Id);
        Assert.isTrue(TaskKanbanController.getRecurringTemplates().isEmpty());
    }

    @IsTest
    static void deleteTaskAndSharePointLookups() {
        Task a = taskNamed('Board task A');

        Test.startTest();
        Assert.isTrue(TaskKanbanController.getTaskSyncedFiles(a.Id).isEmpty());
        Assert.isTrue(TaskKanbanController.getTaskSyncedFiles(null).isEmpty());
        TaskKanbanController.deleteTask(a.Id);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Task WHERE Id = :a.Id]);
    }

    @IsTest
    static void initiativeStagesAndCsvAttachment() {
        Task a = taskNamed('Board task A');
        Assert.isTrue(TaskKanbanController.getInitiativeStages(null, null).isEmpty(), 'no Employee__c yet');
        makeEmployee();

        Test.startTest();
        List<Initiative_Stage__c> stages = TaskKanbanController.getInitiativeStages(a.Id, '2026-11');
        List<Initiative_Stage__c> allStages = TaskKanbanController.getInitiativeStages(null, null);
        TaskKanbanController.attachCsvToInitiativeStage(a.Id,
            EncodingUtil.base64Encode(Blob.valueOf('a,b\n1,2')), 'Report.csv');
        Test.stopTest();

        Assert.isNotNull(stages);
        Assert.isNotNull(allStages);
        Assert.areEqual(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :a.Id]);
        try {
            TaskKanbanController.attachCsvToInitiativeStage(null, null, null);
            Assert.fail('Expected an error for missing parameters');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e);
        }
    }
}
