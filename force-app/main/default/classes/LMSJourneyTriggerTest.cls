@isTest
private class LMSJourneyTriggerTest {

    @testSetup
    static void setupTestData() {
        LMS_Journey__c journey = new LMS_Journey__c(
            Journey_Name__c = 'Test Journey',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
        );
        insert journey;
    }

    @isTest
    static void testAdminCanDeleteJourney() {
        // Running as System Administrator (default test context) — delete should succeed
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];

        Test.startTest();
        delete journey;
        Test.stopTest();

        List<LMS_Journey__c> remaining = [SELECT Id, IsDeleted FROM LMS_Journey__c WHERE Id = :journey.Id ALL ROWS];
        Assert.isTrue(remaining[0].IsDeleted, 'System Administrator should be able to delete a journey');
    }

}