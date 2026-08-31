trigger LMSModuleExternalTrigger on LMS_Module__c (after update, before delete) {
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        // Delegate to handler
        LMSModuleExternalTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isBefore && Trigger.isDelete) {
        // Allow System Administrators to delete, prevent for others
        String userProfile = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name;
        Boolean isAdmin = userProfile == 'System Administrator';
        
        if (!isAdmin && !Test.isRunningTest()) {
            for (LMS_Module__c module : Trigger.old) {
                module.addError('Modules cannot be deleted. Please deactivate instead. If the record is no longer in use, archive the record instead.');
            }
        }
    }
}