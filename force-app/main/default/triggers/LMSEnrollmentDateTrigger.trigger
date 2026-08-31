trigger LMSEnrollmentDateTrigger on LMS_Enrollment__c (before insert, before update, after insert, after update) {
    
    if (Trigger.isBefore) {
        // Validate no duplicate enrollments for the same Employee, Module Assignment, and dates
        LMSEnrollmentDateHandler.validateNoDuplicateEnrollments(Trigger.new);
        
        // Only process records that have date fields populated
        List<LMS_Enrollment__c> recordsToValidate = new List<LMS_Enrollment__c>();
        
        for (LMS_Enrollment__c enrollment : Trigger.new) {
            if (enrollment.Start_Date__c != null && enrollment.End_Date__c != null) {
                recordsToValidate.add(enrollment);
            }
        }
        
        if (!recordsToValidate.isEmpty()) {
            LMSEnrollmentDateHandler.validateEnrollmentDates(recordsToValidate);
        }
    }
    
    if (Trigger.isAfter && Trigger.isInsert) {
        // Filter for participant enrollments with module assignments
        List<LMS_Enrollment__c> participantEnrollments = new List<LMS_Enrollment__c>();
        
        for (LMS_Enrollment__c enrollment : Trigger.new) {
            if (enrollment.Enrollment_Role__c == 'Participant' && enrollment.Module_Assignment__c != null) {
                participantEnrollments.add(enrollment);
            }
        }
        
        if (!participantEnrollments.isEmpty()) {
            LMSEnrollmentTriggerHandler.handleNewEnrollments(participantEnrollments);
        }
        
        // Create Learner Portfolio records for new enrollments
        LMSEnrollmentPortfolioTriggerHandler.handleAfterInsert(Trigger.new, true);
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        // Update Learner Portfolio status when enrollments are completed
      //  LMSEnrollmentPortfolioTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap, true);

        // Cascade Unenrolled status to all related lesson week assignments
        LMSEnrollmentTriggerHandler.handleUnenrolledEnrollments(Trigger.new, Trigger.oldMap);

        // Create lesson week assignments when Module_Assignment__c is newly set on update
        List<LMS_Enrollment__c> newlyAssignedEnrollments = new List<LMS_Enrollment__c>();
        for (LMS_Enrollment__c enrollment : Trigger.new) {
            LMS_Enrollment__c oldEnrollment = Trigger.oldMap.get(enrollment.Id);
            if (enrollment.Enrollment_Role__c == 'Participant' &&
                enrollment.Module_Assignment__c != null &&
                oldEnrollment.Module_Assignment__c == null) {
                newlyAssignedEnrollments.add(enrollment);
            }
        }
        if (!newlyAssignedEnrollments.isEmpty()) {
            LMSEnrollmentTriggerHandler.handleNewEnrollments(newlyAssignedEnrollments);
        }
    }
}