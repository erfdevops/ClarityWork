public with sharing class TaskKanbanController {

    @AuraEnabled
    public static Boolean pingSession() {
        return true;
    }

    @AuraEnabled(cacheable=true)
    public static List<Task> getUserTasks(String projectId) {
        Id userId = UserInfo.getUserId();
        Date today = Date.today();
        if (String.isBlank(projectId)) {
            return [
                SELECT Id, Subject, Kanban_Status__c, ActivityDate, Assign_To_Month__c, Priority,
                       Task_Number__c, External_Link__c, Project__c, Project__r.Name,
                       Smart_Goal__c, Smart_Goal__r.Name, Smart_Goal__r.Initiative_Name__c,
                       OwnerId, Owner.Name, Description, Time_Spent__c, CreatedDate,
                       IsRecurrence
                FROM Task
                WHERE OwnerId = :userId
                AND (
                    Kanban_Status__c != null
                    OR (IsClosed = false AND IsRecurrence = false)
                    OR (IsClosed = false AND IsRecurrence = true AND ActivityDate <= :today)
                )
                ORDER BY ActivityDate ASC NULLS LAST
                LIMIT 1000
            ];
        }
        return [
            SELECT Id, Subject, Kanban_Status__c, ActivityDate, Assign_To_Month__c, Priority,
                   Task_Number__c, External_Link__c, Project__c, Project__r.Name,
                   Smart_Goal__c, Smart_Goal__r.Name, Smart_Goal__r.Initiative_Name__c,
                   OwnerId, Owner.Name, Description, Time_Spent__c, CreatedDate,
                   IsRecurrence
            FROM Task
            WHERE OwnerId = :userId
            AND Project__c = :projectId
            AND (
                Kanban_Status__c != null
                OR (IsClosed = false AND IsRecurrence = false)
                OR (IsClosed = false AND IsRecurrence = true
                    AND (ActivityDate = null OR ActivityDate <= :today))
            )
            ORDER BY ActivityDate ASC NULLS LAST
            LIMIT 1000
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Initiative__c> getSmartGoals() {
        return smartGoalsForFiscalYear(Date.today().year(), Date.today().month());
    }

    // Smart goals for the fiscal year containing selectedMonth ('YYYY-MM'), so the
    // board filter and Submit can reach goals from past fiscal years.
    @AuraEnabled(cacheable=true)
    public static List<Initiative__c> getSmartGoalsForMonth(String selectedMonth) {
        if (String.isBlank(selectedMonth) || !Pattern.matches('\\d{4}-\\d{2}', selectedMonth)) {
            return getSmartGoals();
        }
        List<String> parts = selectedMonth.split('-');
        return smartGoalsForFiscalYear(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]));
    }

    private static List<Initiative__c> smartGoalsForFiscalYear(Integer yr, Integer mo) {
        Id userId = UserInfo.getUserId();
        List<Employee__c> emps = [SELECT Id FROM Employee__c WHERE User__c = :userId LIMIT 1];
        if (emps.isEmpty()) return new List<Initiative__c>();

        String fy = mo >= 10
            ? 'October ' + yr + ' - September ' + (yr + 1)
            : 'October ' + (yr - 1) + ' - September ' + yr;

        return [
            SELECT Id, Name, Initiative_Name__c
            FROM Initiative__c
            WHERE Ownership__c = :emps[0].Id
            AND Fiscal_Year__c = :fy
            ORDER BY Initiative_Name__c ASC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Project__c> getUserProjects() {
        Id userId = UserInfo.getUserId();
        Set<Id> projectIdsFromTasks = new Set<Id>();
        for (Task t : [SELECT Project__c FROM Task WHERE OwnerId = :userId AND Project__c != null LIMIT 500]) {
            projectIdsFromTasks.add(t.Project__c);
        }
        return [
            SELECT Id, Name, Status__c, Due_Date__c
            FROM Project__c
            WHERE OwnerId = :userId OR Id IN :projectIdsFromTasks
            ORDER BY Name ASC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Export_Column_Config__mdt> getExportColumns() {
        User u = [SELECT Department FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String dept = u.Department;

        List<Export_Column_Config__mdt> cols = String.isNotBlank(dept)
            ? [SELECT Department__c, Column_Order__c, Column_Header__c, Field_API_Name__c
               FROM Export_Column_Config__mdt
               WHERE Department__c = :dept AND Is_Active__c = true
               ORDER BY Column_Order__c ASC]
            : new List<Export_Column_Config__mdt>();

        if (!cols.isEmpty()) return cols;

        return [
            SELECT Department__c, Column_Order__c, Column_Header__c, Field_API_Name__c
            FROM Export_Column_Config__mdt
            WHERE Department__c = 'Default' AND Is_Active__c = true
            ORDER BY Column_Order__c ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<User> getActiveUsers() {
        return [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
            AND UserType = 'Standard'
            ORDER BY Name ASC
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Task_Comment__c> getTaskComments(String taskId) {
        if (String.isBlank(taskId)) return new List<Task_Comment__c>();
        return [
            SELECT Id, Comment__c, CreatedBy.Name, CreatedDate
            FROM Task_Comment__c
            WHERE Task__c = :taskId
            ORDER BY CreatedDate ASC
        ];
    }

    @AuraEnabled
    public static Task_Comment__c addComment(String taskId, String commentText, List<String> mentionedUserIds) {
        Task_Comment__c c = new Task_Comment__c(
            Task__c    = taskId,
            Comment__c = commentText
        );
        insert c;

        // Persist newly mentioned users first so getInvolvedUserIds sees them
        if (mentionedUserIds != null && !mentionedUserIds.isEmpty()) {
            List<Task_Mention__c> mentions = new List<Task_Mention__c>();
            for (String uid : mentionedUserIds) {
                if (String.isNotBlank(uid)) {
                    mentions.add(new Task_Mention__c(Task_Id__c = taskId, User_Id__c = uid));
                }
            }
            if (!mentions.isEmpty()) insert mentions;
        }

        TaskNotificationService.notifyComment(taskId, mentionedUserIds, UserInfo.getUserId());

        return [SELECT Id, Comment__c, CreatedBy.Name, CreatedDate FROM Task_Comment__c WHERE Id = :c.Id];
    }

    @AuraEnabled
    public static void deleteComment(String commentId) {
        delete new Task_Comment__c(Id = commentId);
    }

    @AuraEnabled
    public static List<SharePoint_Sync__c> getTaskSyncedFiles(String taskId) {
        if (String.isBlank(taskId)) return new List<SharePoint_Sync__c>();
        return [
            SELECT Id, File_Name__c, Folder_Name__c, SharePoint_URL__c, CreatedDate
            FROM SharePoint_Sync__c
            WHERE Related_Record_Id__c = :taskId
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static void syncTaskFilesToSharePoint(String taskId) {
        System.enqueueJob(new TaskSharePointSyncJob(taskId));
    }

    // ─── Monday.com integration (see MondayService) ──────────────────────────
    // Non-cacheable: each call checks the live Monday connection.
    @AuraEnabled
    public static MondayService.MondayContext getMondayContext() {
        return MondayService.getContext();
    }

    @AuraEnabled
    public static List<MondayService.Option> getMyMondayBoards() {
        try {
            return MondayService.getMyBoards();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static MondayService.MondayContext connectMondayBoard(String boardId) {
        try {
            return MondayService.connectBoard(boardId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Returns the task's Monday fields; Monday_Sync_Status__c = 'Error' when the item could not be created
    @AuraEnabled
    public static Task createMondayItem(String taskId, String groupId) {
        try {
            return MondayService.createItemForTask(taskId, groupId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Ids of every task linked to a smart goal through Task_Smart_Goal__c (not just
    // the primary Smart_Goal__c field). Non-cacheable so the board filter sees new links.
    @AuraEnabled
    public static List<String> getTaskIdsForSmartGoal(String smartGoalId) {
        List<String> ids = new List<String>();
        if (String.isBlank(smartGoalId)) return ids;
        for (Task_Smart_Goal__c j : [SELECT Task__c FROM Task_Smart_Goal__c
                                     WHERE Smart_Goal__c = :smartGoalId AND Task__c != null]) {
            ids.add(j.Task__c);
        }
        return ids;
    }

    @AuraEnabled
    public static List<Task_Smart_Goal__c> getTaskSmartGoals(String taskId) {
        if (String.isBlank(taskId)) return new List<Task_Smart_Goal__c>();
        return [
            SELECT Id, Smart_Goal__c, Smart_Goal__r.Initiative_Name__c, Smart_Goal__r.Name
            FROM Task_Smart_Goal__c
            WHERE Task__c = :taskId
            ORDER BY CreatedDate ASC
        ];
    }

    @AuraEnabled
    public static List<Recurring_Template_Smart_Goal__c> getTemplateSmartGoals(String templateId) {
        if (String.isBlank(templateId)) return new List<Recurring_Template_Smart_Goal__c>();
        return [
            SELECT Id, Smart_Goal__c, Smart_Goal__r.Initiative_Name__c, Smart_Goal__r.Name
            FROM Recurring_Template_Smart_Goal__c
            WHERE Template__c = :templateId
            ORDER BY CreatedDate ASC
        ];
    }

    private static void saveTaskSmartGoals(String taskId, List<String> smartGoalIds) {
        delete [SELECT Id FROM Task_Smart_Goal__c WHERE Task__c = :taskId];
        if (smartGoalIds == null || smartGoalIds.isEmpty()) return;
        List<Task_Smart_Goal__c> toInsert = new List<Task_Smart_Goal__c>();
        for (String goalId : smartGoalIds) {
            if (String.isNotBlank(goalId)) {
                toInsert.add(new Task_Smart_Goal__c(Task__c = taskId, Smart_Goal__c = goalId));
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    private static void saveTemplateSmartGoals(String templateId, List<String> smartGoalIds) {
        delete [SELECT Id FROM Recurring_Template_Smart_Goal__c WHERE Template__c = :templateId];
        if (smartGoalIds == null || smartGoalIds.isEmpty()) return;
        List<Recurring_Template_Smart_Goal__c> toInsert = new List<Recurring_Template_Smart_Goal__c>();
        for (String goalId : smartGoalIds) {
            if (String.isNotBlank(goalId)) {
                toInsert.add(new Recurring_Template_Smart_Goal__c(Template__c = templateId, Smart_Goal__c = goalId));
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    @AuraEnabled
    public static List<Task> getRelatedTasks(String taskId) {
        if (String.isBlank(taskId)) return new List<Task>();
        Set<String> relatedIds = new Set<String>();
        for (Task_Relation__c r : [
            SELECT Task_Id__c, Related_Task_Id__c
            FROM Task_Relation__c
            WHERE Task_Id__c = :taskId OR Related_Task_Id__c = :taskId
        ]) {
            relatedIds.add(r.Task_Id__c == taskId ? r.Related_Task_Id__c : r.Task_Id__c);
        }
        if (relatedIds.isEmpty()) return new List<Task>();
        Set<Id> idSet = new Set<Id>();
        for (String s : relatedIds) {
            if (String.isNotBlank(s)) {
                try { idSet.add((Id)s); } catch (Exception e) {}
            }
        }
        if (idSet.isEmpty()) return new List<Task>();
        return [
            SELECT Id, Subject, Task_Number__c, Kanban_Status__c
            FROM Task WHERE Id IN :idSet
            ORDER BY Task_Number__c ASC NULLS LAST
        ];
    }

    @AuraEnabled
    public static List<Project__c> getTaskProjects(String taskId) {
        if (String.isBlank(taskId)) return new List<Project__c>();
        List<String> projIds = new List<String>();
        for (Task_Project__c tp : [SELECT Project_Id__c FROM Task_Project__c WHERE Task_Id__c = :taskId]) {
            projIds.add(tp.Project_Id__c);
        }
        if (projIds.isEmpty()) return new List<Project__c>();
        Set<Id> idSet = new Set<Id>();
        for (String s : projIds) { try { idSet.add((Id)s); } catch (Exception e) {} }
        return [SELECT Id, Name FROM Project__c WHERE Id IN :idSet ORDER BY Name ASC];
    }

    @AuraEnabled
    public static void saveTaskProjects(String taskId, List<String> projectIds) {
        if (String.isBlank(taskId)) return;
        delete [SELECT Id FROM Task_Project__c WHERE Task_Id__c = :taskId];
        if (projectIds == null || projectIds.isEmpty()) return;
        List<Task_Project__c> toInsert = new List<Task_Project__c>();
        for (String projId : projectIds) {
            if (String.isNotBlank(projId)) {
                toInsert.add(new Task_Project__c(Task_Id__c = taskId, Project_Id__c = projId));
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    @AuraEnabled
    public static List<Project__c> getTemplateProjects(String templateId) {
        if (String.isBlank(templateId)) return new List<Project__c>();
        List<String> projIds = new List<String>();
        for (Recurring_Template_Project__c tp : [SELECT Project_Id__c FROM Recurring_Template_Project__c WHERE Template_Id__c = :templateId]) {
            projIds.add(tp.Project_Id__c);
        }
        if (projIds.isEmpty()) return new List<Project__c>();
        Set<Id> idSet = new Set<Id>();
        for (String s : projIds) { try { idSet.add((Id)s); } catch (Exception e) {} }
        return [SELECT Id, Name FROM Project__c WHERE Id IN :idSet ORDER BY Name ASC];
    }

    @AuraEnabled
    public static void saveTemplateProjects(String templateId, List<String> projectIds) {
        if (String.isBlank(templateId)) return;
        delete [SELECT Id FROM Recurring_Template_Project__c WHERE Template_Id__c = :templateId];
        if (projectIds == null || projectIds.isEmpty()) return;
        List<Recurring_Template_Project__c> toInsert = new List<Recurring_Template_Project__c>();
        for (String projId : projectIds) {
            if (String.isNotBlank(projId)) {
                toInsert.add(new Recurring_Template_Project__c(Template_Id__c = templateId, Project_Id__c = projId));
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    @AuraEnabled
    public static List<Tag__c> searchTags(String query) {
        String q = '%' + (String.isBlank(query) ? '' : query.trim()) + '%';
        return [SELECT Id, Name FROM Tag__c WHERE Name LIKE :q ORDER BY Name ASC LIMIT 20];
    }

    @AuraEnabled
    public static String ensureTag(String tagName) {
        if (String.isBlank(tagName)) return null;
        String trimmed = tagName.trim();
        List<Tag__c> existing = [SELECT Id FROM Tag__c WHERE Name = :trimmed LIMIT 1];
        if (!existing.isEmpty()) return existing[0].Id;
        Tag__c t = new Tag__c(Name = trimmed);
        insert t;
        return t.Id;
    }

    @AuraEnabled
    public static List<Tag__c> getTaskTags(String taskId) {
        if (String.isBlank(taskId)) return new List<Tag__c>();
        List<String> tagIds = new List<String>();
        for (Task_Tag__c tt : [SELECT Tag_Id__c FROM Task_Tag__c WHERE Task_Id__c = :taskId]) {
            tagIds.add(tt.Tag_Id__c);
        }
        if (tagIds.isEmpty()) return new List<Tag__c>();
        Set<Id> idSet = new Set<Id>();
        for (String s : tagIds) { try { idSet.add((Id)s); } catch (Exception e) {} }
        return [SELECT Id, Name FROM Tag__c WHERE Id IN :idSet ORDER BY Name ASC];
    }

    @AuraEnabled
    public static void saveTaskTags(String taskId, List<String> tagIds) {
        if (String.isBlank(taskId)) return;
        delete [SELECT Id FROM Task_Tag__c WHERE Task_Id__c = :taskId];
        if (tagIds == null || tagIds.isEmpty()) return;
        List<Task_Tag__c> toInsert = new List<Task_Tag__c>();
        for (String tagId : tagIds) {
            if (String.isNotBlank(tagId)) {
                toInsert.add(new Task_Tag__c(Task_Id__c = taskId, Tag_Id__c = tagId));
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    @AuraEnabled
    public static List<Tag__c> getTemplateTags(String templateId) {
        if (String.isBlank(templateId)) return new List<Tag__c>();
        List<String> tagIds = new List<String>();
        for (Recurring_Template_Tag__c tt : [SELECT Tag_Id__c FROM Recurring_Template_Tag__c WHERE Template_Id__c = :templateId]) {
            tagIds.add(tt.Tag_Id__c);
        }
        if (tagIds.isEmpty()) return new List<Tag__c>();
        Set<Id> idSet = new Set<Id>();
        for (String s : tagIds) { try { idSet.add((Id)s); } catch (Exception e) {} }
        return [SELECT Id, Name FROM Tag__c WHERE Id IN :idSet ORDER BY Name ASC];
    }

    @AuraEnabled
    public static void saveTemplateTags(String templateId, List<String> tagIds) {
        if (String.isBlank(templateId)) return;
        delete [SELECT Id FROM Recurring_Template_Tag__c WHERE Template_Id__c = :templateId];
        if (tagIds == null || tagIds.isEmpty()) return;
        List<Recurring_Template_Tag__c> toInsert = new List<Recurring_Template_Tag__c>();
        for (String tagId : tagIds) {
            if (String.isNotBlank(tagId)) {
                toInsert.add(new Recurring_Template_Tag__c(Template_Id__c = templateId, Tag_Id__c = tagId));
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    @AuraEnabled
    public static void saveMentions(String taskId, List<String> userIds) {
        if (String.isBlank(taskId) || userIds == null || userIds.isEmpty()) return;
        List<Task_Mention__c> toInsert = new List<Task_Mention__c>();
        for (String uid : userIds) {
            if (String.isNotBlank(uid)) {
                toInsert.add(new Task_Mention__c(Task_Id__c = taskId, User_Id__c = uid));
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;
        TaskNotificationService.notifyDescriptionMentioned(taskId, userIds, UserInfo.getUserId());
    }

    @AuraEnabled
    public static void saveTaskRelations(String taskId, List<String> relatedTaskIds) {
        if (String.isBlank(taskId)) return;
        delete [SELECT Id FROM Task_Relation__c
                WHERE Task_Id__c = :taskId OR Related_Task_Id__c = :taskId];
        if (relatedTaskIds == null || relatedTaskIds.isEmpty()) return;
        List<Task_Relation__c> toInsert = new List<Task_Relation__c>();
        for (String relId : relatedTaskIds) {
            if (String.isNotBlank(relId) && relId != taskId) {
                toInsert.add(new Task_Relation__c(Task_Id__c = taskId, Related_Task_Id__c = relId));
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    @AuraEnabled
    public static void bulkUpdateStatus(List<String> taskIds, String newStatus) {
        if (taskIds == null || taskIds.isEmpty() || String.isBlank(newStatus)) return;
        String stdStatus = newStatus == 'Complete'    ? 'Completed'
                         : newStatus == 'In Progress' ? 'In Progress'
                         : 'Open';
        List<Task> toUpdate = new List<Task>();
        for (String tid : taskIds) {
            if (String.isNotBlank(tid)) {
                toUpdate.add(new Task(Id = tid, Kanban_Status__c = newStatus, Status = stdStatus));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    @AuraEnabled
    public static void updateTaskStatus(String taskId, String newStatus) {
        Task before = [SELECT Kanban_Status__c FROM Task WHERE Id = :taskId LIMIT 1];
        String oldStatus = before.Kanban_Status__c;
        String stdStatus = newStatus == 'Complete' ? 'Completed'
                         : newStatus == 'In Progress' ? 'In Progress'
                         : 'Open';
        update new Task(Id = taskId, Kanban_Status__c = newStatus, Status = stdStatus);
        if (oldStatus != newStatus) {
            TaskNotificationService.notifyStatusChange(taskId, oldStatus, newStatus, UserInfo.getUserId());
        }
    }

    @AuraEnabled
    public static Task createTask(String subject, String projectId, String kanbanStatus,
                                  Date dueDate, String description, String priority,
                                  List<String> smartGoalIds, Decimal timeSpent, String assignedToId,
                                  Date assignToMonth) {
        String stdStatus = kanbanStatus == 'Complete' ? 'Completed'
                         : kanbanStatus == 'In Progress' ? 'In Progress'
                         : 'Open';
        String ownerId = String.isNotBlank(assignedToId) ? assignedToId : UserInfo.getUserId();
        Task t = new Task(
            Subject            = subject,
            OwnerId            = ownerId,
            Status             = stdStatus,
            Kanban_Status__c   = String.isBlank(kanbanStatus) ? 'Queue' : kanbanStatus,
            ActivityDate       = dueDate,
            Assign_To_Month__c = assignToMonth,
            Description        = description,
            Priority           = String.isBlank(priority) ? 'Normal' : priority
        );
        if (timeSpent != null) t.Time_Spent__c = timeSpent;
        if (String.isNotBlank(projectId)) t.Project__c = projectId;
        if (smartGoalIds != null && !smartGoalIds.isEmpty()) t.Smart_Goal__c = smartGoalIds[0];
        insert t;
        saveTaskSmartGoals(t.Id, smartGoalIds);
        if (ownerId != UserInfo.getUserId()) {
            TaskNotificationService.notifyAssigned(t.Id, ownerId, UserInfo.getUserId());
        }
        return [
            SELECT Id, Subject, Kanban_Status__c, ActivityDate, Assign_To_Month__c, Priority,
                   Task_Number__c, External_Link__c, Project__c, Project__r.Name,
                   Smart_Goal__c, Smart_Goal__r.Name, Smart_Goal__r.Initiative_Name__c,
                   OwnerId, Owner.Name, Description, Time_Spent__c, CreatedDate
            FROM Task WHERE Id = :t.Id
        ];
    }

    @AuraEnabled
    public static Task updateTask(String taskId, String subject, String projectId,
                                  String kanbanStatus, Date dueDate, String description,
                                  String priority, List<String> smartGoalIds,
                                  Decimal timeSpent, String assignedToId, Date assignToMonth) {
        Task before = [SELECT OwnerId, Kanban_Status__c FROM Task WHERE Id = :taskId LIMIT 1];
        String oldOwnerId = before.OwnerId;
        String oldStatus  = before.Kanban_Status__c;

        String stdStatus = kanbanStatus == 'Complete'    ? 'Completed'
                         : kanbanStatus == 'In Progress' ? 'In Progress'
                         : 'Open';
        Task t = new Task(
            Id                 = taskId,
            Subject            = subject,
            Status             = stdStatus,
            Kanban_Status__c   = kanbanStatus,
            ActivityDate       = dueDate,
            Assign_To_Month__c = assignToMonth,
            Description        = description,
            Priority           = priority,
            Time_Spent__c      = timeSpent,
            Smart_Goal__c      = (smartGoalIds != null && !smartGoalIds.isEmpty()) ? smartGoalIds[0] : null
        );
        String newOwnerId = String.isNotBlank(assignedToId) ? assignedToId : oldOwnerId;
        if (String.isNotBlank(assignedToId)) t.OwnerId = assignedToId;
        t.Project__c = String.isNotBlank(projectId) ? projectId : null;
        update t;
        saveTaskSmartGoals(taskId, smartGoalIds);

        if (newOwnerId != oldOwnerId) {
            TaskNotificationService.notifyAssigned(taskId, newOwnerId, UserInfo.getUserId());
        }
        if (kanbanStatus != oldStatus) {
            TaskNotificationService.notifyStatusChange(taskId, oldStatus, kanbanStatus, UserInfo.getUserId());
        }

        return [
            SELECT Id, Subject, Kanban_Status__c, ActivityDate, Assign_To_Month__c, Priority,
                   Task_Number__c, External_Link__c, Project__c, Project__r.Name,
                   Smart_Goal__c, Smart_Goal__r.Name, Smart_Goal__r.Initiative_Name__c,
                   OwnerId, Owner.Name, Description, Time_Spent__c, CreatedDate
            FROM Task WHERE Id = :t.Id
        ];
    }

    @AuraEnabled
    public static void bulkAssignToMonth(List<String> taskIds, Date targetMonth) {
        if (taskIds == null || taskIds.isEmpty() || targetMonth == null) return;
        List<Task> toUpdate = new List<Task>();
        for (String tid : taskIds) {
            if (String.isNotBlank(tid)) {
                toUpdate.add(new Task(Id = tid, Assign_To_Month__c = targetMonth));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    @AuraEnabled
    public static List<Recurring_Task_Template__c> getRecurringTemplates() {
        Id userId = UserInfo.getUserId();
        return [
            SELECT Id, Name, Subject__c, Project__c, Project__r.Name, Priority__c,
                   Description__c, Assigned_To__c, Is_Active__c,
                   Frequency__c, Last_Spawn_Date__c, Spawn_Day__c
            FROM Recurring_Task_Template__c
            WHERE OwnerId = :userId
            ORDER BY Subject__c ASC
        ];
    }

    @AuraEnabled
    public static Recurring_Task_Template__c saveRecurringTemplate(String templateId, String subject,
            String projectId, String priority, String description,
            String assignedToId, Boolean isActive, List<String> smartGoalIds,
            String frequency, Decimal spawnDay) {
        Recurring_Task_Template__c t;
        if (String.isNotBlank(templateId)) {
            t = new Recurring_Task_Template__c(Id = templateId);
        } else {
            t = new Recurring_Task_Template__c();
        }
        t.Subject__c     = subject;
        t.Project__c     = String.isNotBlank(projectId)    ? projectId    : null;
        t.Priority__c    = String.isNotBlank(priority)     ? priority     : 'Normal';
        t.Description__c = description;
        t.Assigned_To__c = String.isNotBlank(assignedToId) ? assignedToId : null;
        t.Is_Active__c   = isActive != false;
        t.Frequency__c   = String.isNotBlank(frequency)    ? frequency    : 'Monthly';
        t.Spawn_Day__c   = spawnDay;
        upsert t;
        saveTemplateSmartGoals(t.Id, smartGoalIds);
        RecurringTaskSpawnJob.setupSchedule();
        return [
            SELECT Id, Name, Subject__c, Project__c, Project__r.Name, Priority__c,
                   Description__c, Assigned_To__c, Is_Active__c,
                   Frequency__c, Last_Spawn_Date__c, Spawn_Day__c
            FROM Recurring_Task_Template__c WHERE Id = :t.Id
        ];
    }

    @AuraEnabled
    public static void toggleRecurringTemplate(String templateId, Boolean isActive) {
        update new Recurring_Task_Template__c(Id = templateId, Is_Active__c = isActive);
        if (isActive) RecurringTaskSpawnJob.setupSchedule();
    }

    @AuraEnabled
    public static void deleteRecurringTemplate(String templateId) {
        delete new Recurring_Task_Template__c(Id = templateId);
    }

    @AuraEnabled
    public static void triggerRecurringSpawn() {
        RecurringTaskSpawnJob.spawnForCurrentMonth();
    }

    @AuraEnabled
    public static void deleteTask(String taskId) {
        System.enqueueJob(new TaskSharePointDeleteJob(taskId));
        delete new Task(Id = taskId);
    }

    @AuraEnabled
    public static List<Initiative_Stage__c> getInitiativeStages(String smartGoalId, String selectedMonth) {
        List<Employee__c> emps = [SELECT Id FROM Employee__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
        if (emps.isEmpty()) return new List<Initiative_Stage__c>();
        Id empId = emps[0].Id;

        Id parentStageId = null;
        String initiativeDescName = null;
        if (String.isNotBlank(smartGoalId)) {
            // smartGoalId is always an Initiative__c Id (both ClarityDev and UAT use Lookup(Initiative) on tasks)
            List<Initiative__c> inits = [SELECT Initiative_Name__c FROM Initiative__c WHERE Id = :smartGoalId LIMIT 1];
            if (!inits.isEmpty()) {
                initiativeDescName = inits[0].Initiative_Name__c;
            }
            // Also check for a linked parent Initiative Stage (set on Smart_Goal__c in some orgs)
            List<Smart_Goal__c> goals = [SELECT Initiative_Stage__c FROM Smart_Goal__c WHERE Id = :smartGoalId LIMIT 1];
            if (!goals.isEmpty() && goals[0].Initiative_Stage__c != null) {
                parentStageId = goals[0].Initiative_Stage__c;
            }
        }

        // Tightest: Initiative__c lookup directly on Initiative_Stage__c matches the selected smart goal
        if (String.isNotBlank(smartGoalId)) {
            List<Initiative_Stage__c> direct = [
                SELECT Id, Name, Status__c
                FROM Initiative_Stage__c
                WHERE Employee__c = :empId
                AND Initiative__c = :smartGoalId
                ORDER BY Name ASC
                LIMIT 200
            ];
            if (!direct.isEmpty()) return direct;
        }

        // Second: children of the smart goal's linked parent stage
        if (parentStageId != null) {
            List<Initiative_Stage__c> children = [
                SELECT Id, Name, Status__c
                FROM Initiative_Stage__c
                WHERE Employee__c = :empId
                AND Parent_Initiative_Stage__c = :parentStageId
                ORDER BY Name ASC
                LIMIT 200
            ];
            if (!children.isEmpty()) return children;
        }

        // Third: name prefix match using the Initiative's descriptive name
        // (stage names follow "[Initiative_Name__c] - [Month] [Year]")
        if (String.isNotBlank(initiativeDescName)) {
            List<Initiative_Stage__c> nameMatches = [
                SELECT Id, Name, Status__c
                FROM Initiative_Stage__c
                WHERE Employee__c = :empId
                AND Name LIKE :initiativeDescName + '%'
                ORDER BY Name ASC
                LIMIT 200
            ];
            if (!nameMatches.isEmpty()) return nameMatches;
        }

        // Fallback: all stages for this employee
        return [
            SELECT Id, Name, Status__c
            FROM Initiative_Stage__c
            WHERE Employee__c = :empId
            ORDER BY Name ASC
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static void attachCsvToInitiativeStage(String stageId, String csvBase64, String filename) {
        if (String.isBlank(stageId) || String.isBlank(csvBase64) || String.isBlank(filename)) {
            throw new AuraHandledException('Missing required parameters.');
        }
        ContentVersion cv = new ContentVersion();
        cv.Title = filename.replaceAll('\\.(csv|xlsx)$', '');
        cv.PathOnClient = filename;
        cv.VersionData = EncodingUtil.base64Decode(csvBase64);
        cv.IsMajorVersion = true;
        insert cv;

        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cv.ContentDocumentId;
        cdl.LinkedEntityId = stageId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;
    }
}
