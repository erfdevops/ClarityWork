@isTest
private class LMSLessonTriggerTest {

    @testSetup
    static void setupTestData() {
        LMS_Module__c module = new LMS_Module__c(
            Module_Name__c = 'Test Module',
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published'
        );
        insert module;

        LMS_Lesson__c lesson = new LMS_Lesson__c(
            Lesson_Name__c = 'Test Lesson',
            Module__c = module.Id,
            Type__c = 'Lesson'
        );
        insert lesson;
    }

    @isTest
    static void testAdminCanDeleteLesson() {
        // Running as System Administrator (default test context) — delete should succeed
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];

        Test.startTest();
        delete lesson;
        Test.stopTest();

        List<LMS_Lesson__c> remaining = [SELECT Id, IsDeleted FROM LMS_Lesson__c WHERE Id = :lesson.Id ALL ROWS];
        Assert.isTrue(remaining[0].IsDeleted, 'System Administrator should be able to delete a lesson');
    }

}