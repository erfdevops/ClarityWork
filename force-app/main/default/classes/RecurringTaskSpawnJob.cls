global class RecurringTaskSpawnJob implements Schedulable {

    public static final String JOB_NAME = 'Clarity Work - Recurring Task Spawn';
    // Run daily at 1:00 AM to support weekly and bi-weekly frequencies
    public static final String CRON_EXP  = '0 0 1 * * ? *';

    global void execute(SchedulableContext ctx) {
        spawnForCurrentMonth();
    }

    public static void spawnForCurrentMonth() {
        Date today = Date.today();

        List<Recurring_Task_Template__c> templates = [
            SELECT Id, Subject__c, Project__c, Priority__c, Description__c,
                   Assigned_To__c, Smart_Goal__c, OwnerId,
                   Frequency__c, Last_Spawn_Date__c, Spawn_Day__c
            FROM Recurring_Task_Template__c
            WHERE Is_Active__c = true
        ];

        if (templates.isEmpty()) return;

        List<Recurring_Task_Template__c> toSpawn = new List<Recurring_Task_Template__c>();
        for (Recurring_Task_Template__c tmpl : templates) {
            Date last = tmpl.Last_Spawn_Date__c;
            String freq = String.isNotBlank(tmpl.Frequency__c) ? tmpl.Frequency__c : 'Monthly';
            Integer spawnDay = (tmpl.Spawn_Day__c != null) ? Integer.valueOf(tmpl.Spawn_Day__c) : null;
            Boolean due = false;

            if (last == null) {
                due = true;
            } else if (freq == 'Weekly') {
                Integer targetDow = (spawnDay != null) ? spawnDay : 1; // 0=Sun,1=Mon...6=Sat; default Monday
                Date thisWeekTarget = today.toStartOfWeek().addDays(targetDow);
                due = today >= thisWeekTarget && last < thisWeekTarget;
            } else if (freq == 'Bi-Weekly') {
                Integer targetDow = (spawnDay != null) ? spawnDay : 1; // default Monday
                Date thisWeekTarget = today.toStartOfWeek().addDays(targetDow);
                // >=13 aligns to target weekday while allowing for scheduler drift
                due = today >= thisWeekTarget && last < thisWeekTarget
                      && last.daysBetween(thisWeekTarget) >= 13;
            } else { // Monthly
                Integer targetDom = (spawnDay != null) ? spawnDay : 1; // default 1st
                Integer daysInMonth = Date.daysInMonth(today.year(), today.month());
                Date thisMonthTarget = Date.newInstance(
                    today.year(), today.month(), Math.min(targetDom, daysInMonth));
                due = today >= thisMonthTarget && last < thisMonthTarget;
            }

            if (due) toSpawn.add(tmpl);
        }

        if (toSpawn.isEmpty()) return;

        // Collect template IDs, smart goals, and projects
        Set<Id> tmplIds = new Set<Id>();
        for (Recurring_Task_Template__c tmpl : toSpawn) tmplIds.add(tmpl.Id);

        Map<Id, List<Id>> tmplGoals = new Map<Id, List<Id>>();
        for (Recurring_Template_Smart_Goal__c jxn : [
            SELECT Template__c, Smart_Goal__c
            FROM Recurring_Template_Smart_Goal__c
            WHERE Template__c IN :tmplIds AND Smart_Goal__c != null
        ]) {
            if (!tmplGoals.containsKey(jxn.Template__c)) tmplGoals.put(jxn.Template__c, new List<Id>());
            tmplGoals.get(jxn.Template__c).add(jxn.Smart_Goal__c);
        }

        Map<Id, List<String>> tmplProjects = new Map<Id, List<String>>();
        for (Recurring_Template_Project__c jxn : [
            SELECT Template_Id__c, Project_Id__c
            FROM Recurring_Template_Project__c
            WHERE Template_Id__c IN :tmplIds AND Project_Id__c != null
        ]) {
            Id tmplId = (Id)jxn.Template_Id__c;
            if (!tmplProjects.containsKey(tmplId)) tmplProjects.put(tmplId, new List<String>());
            tmplProjects.get(tmplId).add(jxn.Project_Id__c);
        }

        Map<Id, List<String>> tmplTags = new Map<Id, List<String>>();
        for (Recurring_Template_Tag__c jxn : [
            SELECT Template_Id__c, Tag_Id__c
            FROM Recurring_Template_Tag__c
            WHERE Template_Id__c IN :tmplIds AND Tag_Id__c != null
        ]) {
            Id tmplId = (Id)jxn.Template_Id__c;
            if (!tmplTags.containsKey(tmplId)) tmplTags.put(tmplId, new List<String>());
            tmplTags.get(tmplId).add(jxn.Tag_Id__c);
        }

        List<Task> toInsert = new List<Task>();
        for (Recurring_Task_Template__c tmpl : toSpawn) {
            String ownerId = String.isNotBlank(tmpl.Assigned_To__c) ? tmpl.Assigned_To__c : tmpl.OwnerId;
            List<Id> goals = tmplGoals.containsKey(tmpl.Id) ? tmplGoals.get(tmpl.Id) : new List<Id>();
            List<String> projs = tmplProjects.containsKey(tmpl.Id) ? tmplProjects.get(tmpl.Id) : new List<String>();
            toInsert.add(new Task(
                Subject          = tmpl.Subject__c,
                Project__c       = !projs.isEmpty() ? (Id)projs[0] : tmpl.Project__c,
                Kanban_Status__c = 'Queue',
                Status           = 'Open',
                Priority         = String.isNotBlank(tmpl.Priority__c) ? tmpl.Priority__c : 'Normal',
                Description      = tmpl.Description__c,
                Smart_Goal__c    = goals.isEmpty() ? null : goals[0],
                OwnerId          = ownerId
            ));
        }
        insert toInsert;

        // Create junction records for each spawned task
        List<Task_Smart_Goal__c> goalJunctions = new List<Task_Smart_Goal__c>();
        List<Task_Project__c> projectJunctions = new List<Task_Project__c>();
        for (Integer i = 0; i < toSpawn.size(); i++) {
            List<Id> goals = tmplGoals.containsKey(toSpawn[i].Id) ? tmplGoals.get(toSpawn[i].Id) : new List<Id>();
            for (Id goalId : goals) {
                goalJunctions.add(new Task_Smart_Goal__c(Task__c = toInsert[i].Id, Smart_Goal__c = goalId));
            }
            List<String> projs = tmplProjects.containsKey(toSpawn[i].Id) ? tmplProjects.get(toSpawn[i].Id) : new List<String>();
            for (String projId : projs) {
                projectJunctions.add(new Task_Project__c(Task_Id__c = toInsert[i].Id, Project_Id__c = projId));
            }
        }
        List<Task_Tag__c> tagJunctions = new List<Task_Tag__c>();
        for (Integer i = 0; i < toSpawn.size(); i++) {
            List<String> tags = tmplTags.containsKey(toSpawn[i].Id) ? tmplTags.get(toSpawn[i].Id) : new List<String>();
            for (String tagId : tags) {
                tagJunctions.add(new Task_Tag__c(Task_Id__c = toInsert[i].Id, Tag_Id__c = tagId));
            }
        }
        if (!goalJunctions.isEmpty()) insert goalJunctions;
        if (!projectJunctions.isEmpty()) insert projectJunctions;
        if (!tagJunctions.isEmpty()) insert tagJunctions;

        for (Recurring_Task_Template__c tmpl : toSpawn) {
            tmpl.Last_Spawn_Date__c = today;
        }
        update toSpawn;
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
        System.schedule(JOB_NAME, CRON_EXP, new RecurringTaskSpawnJob());
    }
}
