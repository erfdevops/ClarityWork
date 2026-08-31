trigger LMSModuleDateTrigger on LMS_Module_Assignment__c (before insert, before update) {
    
    // Only process records that have date fields populated
    List<LMS_Module_Assignment__c> recordsToValidate = new List<LMS_Module_Assignment__c>();
    
    for (LMS_Module_Assignment__c assignment : Trigger.new) {
        if (assignment.Start_Date__c != null && assignment.End_Date__c != null) {
            recordsToValidate.add(assignment);
        }
    }
    
    if (!recordsToValidate.isEmpty()) {
        LMSModuleDateHandler.validateModuleDates(recordsToValidate);
    }
}