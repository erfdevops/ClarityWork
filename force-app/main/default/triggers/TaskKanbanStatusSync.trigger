trigger TaskKanbanStatusSync on Task (before update) {
    for (Task t : Trigger.new) {
        Task old = Trigger.oldMap.get(t.Id);
        // Sync Status → Kanban_Status__c when:
        //   1. The task is already on the Kanban board (has a Kanban_Status__c)
        //   2. The standard Status changed (e.g., native "Mark Complete" button)
        //   3. Kanban_Status__c did NOT change in the same operation
        //      (guards against overwriting when the Kanban controller sets both fields together)
        if (String.isNotBlank(t.Kanban_Status__c)
                && t.Status != old.Status
                && t.Kanban_Status__c == old.Kanban_Status__c) {

            if (t.Status == 'Completed') {
                t.Kanban_Status__c = 'Complete';
            } else if (t.Status == 'In Progress') {
                t.Kanban_Status__c = 'In Progress';
            } else {
                t.Kanban_Status__c = 'Queue';
            }
        }
    }
}
