trigger LMSLessonWeekAssignmentTrigger on LMS_Lesson_Week_Assignment__c (after update) {
    
    // Only process records where Completed field was changed to true
    List<LMS_Lesson_Week_Assignment__c> completedAssignments = new List<LMS_Lesson_Week_Assignment__c>();
    
    for (LMS_Lesson_Week_Assignment__c assignment : Trigger.new) {
        LMS_Lesson_Week_Assignment__c oldAssignment = Trigger.oldMap.get(assignment.Id);
        
        // Check if Completed field was changed from false to true
        if (assignment.Completed__c == true && 
            oldAssignment.Completed__c == false && 
            assignment.Module_Assignment__c != null) {
            completedAssignments.add(assignment);
        }
    }
    
    // If we have completed assignments, check if their module assignments should be marked complete
    if (!completedAssignments.isEmpty()) {
        LMSLessonWeekAssignmentTriggerHandler.handleCompletedAssignments(completedAssignments);
    }
}