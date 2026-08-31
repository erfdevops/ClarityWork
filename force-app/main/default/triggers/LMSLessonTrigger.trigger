trigger LMSLessonTrigger on LMS_Lesson__c (before delete) {
    
    if (Trigger.isBefore && Trigger.isDelete) {
        // Allow System Administrators to delete, prevent for others
        String userProfile = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name;
        Boolean isAdmin = userProfile == 'System Administrator';
        
        if (!isAdmin && !Test.isRunningTest()) {
            for (LMS_Lesson__c lesson : Trigger.old) {
                lesson.addError('Lessons cannot be deleted. Please deactivate instead. If the record is no longer in use, archive the record instead.');
            }
        }
    }
}