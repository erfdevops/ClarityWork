public without sharing class LMSModuleAssignmentTriggerHandler {
    
    /**
     * Handles completed module assignments and updates enrollment status if all modules are complete
     * @param completedModules List of module assignments that were just marked as completed
     */
    public static void handleCompletedModules(List<LMS_Module_Assignment__c> completedModules) {
        
        // Collect all unique enrollment IDs
        Set<Id> enrollmentIds = collectEnrollmentIds(completedModules);
        
        if (enrollmentIds.isEmpty()) {
            return;
        }
        
        // Query all module assignments for these enrollments
        List<LMS_Module_Assignment__c> allRelatedModules = queryRelatedModules(enrollmentIds);
        
        // Group modules by enrollment
        Map<Id, List<LMS_Module_Assignment__c>> enrollmentToModulesMap = groupModulesByEnrollment(allRelatedModules);
        
        // Check which enrollments should be marked as completed
        List<LMS_Enrollment__c> enrollmentsToUpdate = identifyCompletedEnrollments(enrollmentIds, enrollmentToModulesMap);
        
        // Update enrollments if any need to be marked as completed
        updateEnrollments(enrollmentsToUpdate);
    }
    
    /**
     * Collects unique enrollment IDs from completed module assignments
     */
    private static Set<Id> collectEnrollmentIds(List<LMS_Module_Assignment__c> completedModules) {
        Set<Id> enrollmentIds = new Set<Id>();
        for (LMS_Module_Assignment__c moduleAssignment : completedModules) {
            if (moduleAssignment.Enrollment__c != null) {
                enrollmentIds.add(moduleAssignment.Enrollment__c);
            }
        }
        return enrollmentIds;
    }
    
    /**
     * Queries all related module assignments for the given enrollments
     */
    private static List<LMS_Module_Assignment__c> queryRelatedModules(Set<Id> enrollmentIds) {
        return [
            SELECT Id, Enrollment__c, Status__c
            FROM LMS_Module_Assignment__c
            WHERE Enrollment__c IN :enrollmentIds
            WITH SECURITY_ENFORCED
        ];
    }
    
    /**
     * Groups module assignments by their parent enrollment
     */
    private static Map<Id, List<LMS_Module_Assignment__c>> groupModulesByEnrollment(List<LMS_Module_Assignment__c> allRelatedModules) {
        Map<Id, List<LMS_Module_Assignment__c>> enrollmentToModulesMap = new Map<Id, List<LMS_Module_Assignment__c>>();
        for (LMS_Module_Assignment__c module : allRelatedModules) {
            if (!enrollmentToModulesMap.containsKey(module.Enrollment__c)) {
                enrollmentToModulesMap.put(module.Enrollment__c, new List<LMS_Module_Assignment__c>());
            }
            enrollmentToModulesMap.get(module.Enrollment__c).add(module);
        }
        return enrollmentToModulesMap;
    }
    
    /**
     * Identifies which enrollments should be marked as completed
     */
    private static List<LMS_Enrollment__c> identifyCompletedEnrollments(Set<Id> enrollmentIds, Map<Id, List<LMS_Module_Assignment__c>> enrollmentToModulesMap) {
        List<LMS_Enrollment__c> enrollmentsToUpdate = new List<LMS_Enrollment__c>();
        
        for (Id enrollmentId : enrollmentIds) {
            List<LMS_Module_Assignment__c> enrollmentModules = enrollmentToModulesMap.get(enrollmentId);
            
            if (enrollmentModules != null && !enrollmentModules.isEmpty() && areAllModulesCompleted(enrollmentModules)) {
                enrollmentsToUpdate.add(new LMS_Enrollment__c(
                    Id = enrollmentId,
                    Status__c = 'Completed'
                ));
            }
        }
        
        return enrollmentsToUpdate;
    }
    
    /**
     * Checks if all modules in the list are completed
     */
    private static Boolean areAllModulesCompleted(List<LMS_Module_Assignment__c> enrollmentModules) {
        for (LMS_Module_Assignment__c module : enrollmentModules) {
            if (module.Status__c != 'Completed') {
                return false;
            }
        }
        return true;
    }
    
    /**
     * Updates enrollments with completed status
     */
    private static void updateEnrollments(List<LMS_Enrollment__c> enrollmentsToUpdate) {
        if (!enrollmentsToUpdate.isEmpty()) {
            try {
                update as user enrollmentsToUpdate;
                System.debug('Successfully updated ' + enrollmentsToUpdate.size() + ' enrollments to Completed status');
            } catch (Exception e) {
                System.debug('Error updating enrollments: ' + e.getMessage());
                // In a production environment, you might want to log this error or handle it differently
            }
        }
    }
}