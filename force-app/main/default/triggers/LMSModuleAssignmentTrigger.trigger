trigger LMSModuleAssignmentTrigger on LMS_Module_Assignment__c (after update) {
    
    // Only process records where Status__c field was changed to 'Completed'
    List<LMS_Module_Assignment__c> completedModules = new List<LMS_Module_Assignment__c>();
    
    for (LMS_Module_Assignment__c moduleAssignment : Trigger.new) {
        LMS_Module_Assignment__c oldModuleAssignment = Trigger.oldMap.get(moduleAssignment.Id);
        
        // Check if Status__c field was changed to 'Completed'
        if (moduleAssignment.Status__c == 'Completed' && 
            oldModuleAssignment.Status__c != 'Completed' && 
            moduleAssignment.Enrollment__c != null) {
            completedModules.add(moduleAssignment);
        }
    }
    
    // If we have completed module assignments, check if their enrollments should be marked complete
    if (!completedModules.isEmpty()) {
        LMSModuleAssignmentTriggerHandler.handleCompletedModules(completedModules);
    }
}