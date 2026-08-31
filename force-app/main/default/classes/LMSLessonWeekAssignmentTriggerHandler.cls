public without sharing class LMSLessonWeekAssignmentTriggerHandler {
    
    /**
     * Handles completed lesson week assignments and updates module assignment status if all lessons are complete
     * @param completedAssignments List of lesson week assignments that were just marked as completed
     */
    public static void handleCompletedAssignments(List<LMS_Lesson_Week_Assignment__c> completedAssignments) {
        
        // Collect all unique module assignment IDs
        Set<Id> moduleAssignmentIds = collectModuleAssignmentIds(completedAssignments);
        
        if (moduleAssignmentIds.isEmpty()) {
            return;
        }
        
        // Query all lesson week assignments for these module assignments
        List<LMS_Lesson_Week_Assignment__c> allRelatedLessons = queryRelatedLessons(moduleAssignmentIds);
        
        // Group lessons by module assignment
        Map<Id, List<LMS_Lesson_Week_Assignment__c>> moduleToLessonsMap = groupLessonsByModule(allRelatedLessons);
        
        // Check which module assignments should be marked as completed
        List<LMS_Module_Assignment__c> moduleAssignmentsToUpdate = identifyCompletedModules(moduleAssignmentIds, moduleToLessonsMap);
        
        // Update module assignments if any need to be marked as completed
        updateModuleAssignments(moduleAssignmentsToUpdate);
    }
    
    /**
     * Collects unique module assignment IDs from completed lesson assignments
     */
    private static Set<Id> collectModuleAssignmentIds(List<LMS_Lesson_Week_Assignment__c> completedAssignments) {
        Set<Id> moduleAssignmentIds = new Set<Id>();
        for (LMS_Lesson_Week_Assignment__c assignment : completedAssignments) {
            if (assignment.Module_Assignment__c != null) {
                moduleAssignmentIds.add(assignment.Module_Assignment__c);
            }
        }
        return moduleAssignmentIds;
    }
    
    /**
     * Queries all related lesson week assignments for the given module assignments
     */
    private static List<LMS_Lesson_Week_Assignment__c> queryRelatedLessons(Set<Id> moduleAssignmentIds) {
        return [
            SELECT Id, Module_Assignment__c, Completed__c
            FROM LMS_Lesson_Week_Assignment__c
            WHERE Module_Assignment__c IN :moduleAssignmentIds
            WITH SECURITY_ENFORCED
        ];
    }
    
    /**
     * Groups lesson assignments by their parent module assignment
     */
    private static Map<Id, List<LMS_Lesson_Week_Assignment__c>> groupLessonsByModule(List<LMS_Lesson_Week_Assignment__c> allRelatedLessons) {
        Map<Id, List<LMS_Lesson_Week_Assignment__c>> moduleToLessonsMap = new Map<Id, List<LMS_Lesson_Week_Assignment__c>>();
        for (LMS_Lesson_Week_Assignment__c lesson : allRelatedLessons) {
            if (!moduleToLessonsMap.containsKey(lesson.Module_Assignment__c)) {
                moduleToLessonsMap.put(lesson.Module_Assignment__c, new List<LMS_Lesson_Week_Assignment__c>());
            }
            moduleToLessonsMap.get(lesson.Module_Assignment__c).add(lesson);
        }
        return moduleToLessonsMap;
    }
    
    /**
     * Identifies which module assignments should be marked as completed
     */
    private static List<LMS_Module_Assignment__c> identifyCompletedModules(Set<Id> moduleAssignmentIds, Map<Id, List<LMS_Lesson_Week_Assignment__c>> moduleToLessonsMap) {
        List<LMS_Module_Assignment__c> moduleAssignmentsToUpdate = new List<LMS_Module_Assignment__c>();
        
        for (Id moduleAssignmentId : moduleAssignmentIds) {
            List<LMS_Lesson_Week_Assignment__c> moduleLessons = moduleToLessonsMap.get(moduleAssignmentId);
            
            if (moduleLessons != null && !moduleLessons.isEmpty() && areAllLessonsCompleted(moduleLessons)) {
                moduleAssignmentsToUpdate.add(new LMS_Module_Assignment__c(
                    Id = moduleAssignmentId,
                    Status__c = 'Completed'
                ));
            }
        }
        
        return moduleAssignmentsToUpdate;
    }
    
    /**
     * Checks if all lessons in the list are completed
     */
    private static Boolean areAllLessonsCompleted(List<LMS_Lesson_Week_Assignment__c> moduleLessons) {
        for (LMS_Lesson_Week_Assignment__c lesson : moduleLessons) {
            if (lesson.Completed__c != true) {
                return false;
            }
        }
        return true;
    }
    
    /**
     * Updates module assignments with completed status
     */
    private static void updateModuleAssignments(List<LMS_Module_Assignment__c> moduleAssignmentsToUpdate) {
        if (!moduleAssignmentsToUpdate.isEmpty()) {
            try {
                update as user moduleAssignmentsToUpdate;
                System.debug('Successfully updated ' + moduleAssignmentsToUpdate.size() + ' module assignments to Completed status');
            } catch (Exception e) {
                System.debug('Error updating module assignments: ' + e.getMessage());
                // In a production environment, you might want to log this error or handle it differently
            }
        }
    }
}