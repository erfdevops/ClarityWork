/**
 * Handler class for LMS Module External checkbox trigger
 * Cascades External_Module__c checkbox value to all related lessons
 */
public without sharing class LMSModuleExternalTriggerHandler {
    
    /**
     * Handles after update to cascade External_Module__c to related lessons
     * @param newModules List of updated modules
     * @param oldModuleMap Map of old module values
     */
    public static void handleAfterUpdate(List<LMS_Module__c> newModules, Map<Id, LMS_Module__c> oldModuleMap) {
        
        // Map to store module IDs and their External_Module__c values that have changed
        Map<Id, Boolean> modulesWithChangedExternalFlag = new Map<Id, Boolean>();
        
        // Check which modules had their External_Module__c checkbox changed
        for (LMS_Module__c newModule : newModules) {
            LMS_Module__c oldModule = oldModuleMap.get(newModule.Id);
            
            // Check if External_Module__c field changed
            if (newModule.External_Module__c != oldModule.External_Module__c) {
                modulesWithChangedExternalFlag.put(newModule.Id, newModule.External_Module__c);
            }
        }
        
        // If no modules have changed External_Module__c, exit early
        if (modulesWithChangedExternalFlag.isEmpty()) {
            return;
        }
        
        // Query all lessons related to the modules that changed
        List<LMS_Lesson__c> lessonsToUpdate = [
            SELECT Id, Module__c, External_Lesson__c
            FROM LMS_Lesson__c
            WHERE Module__c IN :modulesWithChangedExternalFlag.keySet()
        ];
        
        // Update each lesson with the parent module's External_Module__c value
        for (LMS_Lesson__c lesson : lessonsToUpdate) {
            Boolean newExternalValue = modulesWithChangedExternalFlag.get(lesson.Module__c);
            lesson.External_Lesson__c = newExternalValue;
        }
        
        // Perform bulk update if there are lessons to update
        if (!lessonsToUpdate.isEmpty()) {
            try {
                update lessonsToUpdate;
                System.debug('Successfully updated ' + lessonsToUpdate.size() + ' lessons with External_Lesson__c flag');
            } catch (DmlException e) {
                System.debug('Error updating lessons: ' + e.getMessage());
                // Re-throw to ensure the error is visible
                throw e;
            }
        }
    }
}