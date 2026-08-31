@isTest
private class JourneyModuleAssignmentControllerTest {

    @testSetup
    static void setupTestData() {
        LMS_Journey__c journey = new LMS_Journey__c(
            Journey_Name__c = 'Test Journey',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
        );
        insert journey;

        LMS_Module__c module = new LMS_Module__c(
            Module_Name__c = 'Test Module',
            Journey__c = journey.Id,
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published'
        );
        insert module;

        LMS_Module_Assignment__c assignment = new LMS_Module_Assignment__c(
            Journey__c = journey.Id,
            Module__c = module.Id,
            Status__c = 'In Progress',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
        );
        insert assignment;
    }

    @isTest
    static void testGetJourneyWithModules() {
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];

        Test.startTest();
        JourneyModuleAssignmentController.JourneyData result =
            JourneyModuleAssignmentController.getJourneyWithModules(journey.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isNotNull(result.journeyId, 'Journey Id should not be null');
        Assert.areEqual('Test Journey', result.journeyName, 'Journey name should match');
        Assert.isNotNull(result.modules, 'Modules list should not be null');
        Assert.isFalse(result.modules.isEmpty(), 'Modules list should not be empty');
    }

    @isTest
    static void testGetJourneyWithModules_AssignedFlag() {
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        LMS_Module__c module = [SELECT Id FROM LMS_Module__c LIMIT 1];

        Test.startTest();
        JourneyModuleAssignmentController.JourneyData result =
            JourneyModuleAssignmentController.getJourneyWithModules(journey.Id);
        Test.stopTest();

        // The module is already assigned - verify the isAssigned flag reflects that
        JourneyModuleAssignmentController.ModuleData md = result.modules[0];
        Assert.areEqual(module.Id, md.id, 'Module Id should match');
        Assert.areEqual('Test Module', md.moduleName, 'Module name should match');
        Assert.isTrue(md.isAssigned, 'Module should be marked as assigned');
    }

    @isTest
    static void testCreateModuleAssignments() {
        LMS_Journey__c journey = new LMS_Journey__c(
            Journey_Name__c = 'New Journey',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(60)
        );
        insert journey;

        LMS_Module__c module = [SELECT Id FROM LMS_Module__c LIMIT 1];

        Test.startTest();
        JourneyModuleAssignmentController.createModuleAssignments(journey.Id, new List<Id>{ module.Id });
        Test.stopTest();

        List<LMS_Module_Assignment__c> assignments = [
            SELECT Id, Journey__c, Module__c
            FROM LMS_Module_Assignment__c
            WHERE Journey__c = :journey.Id
        ];

        Assert.isFalse(assignments.isEmpty(), 'Assignment should have been created');
        Assert.areEqual(module.Id, assignments[0].Module__c, 'Module should match');
        Assert.areEqual(journey.Id, assignments[0].Journey__c, 'Journey should match');
    }

    @isTest
    static void testCreateModuleAssignments_MultipleModules() {
        LMS_Journey__c journey = new LMS_Journey__c(
            Journey_Name__c = 'Multi Module Journey',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(60)
        );
        insert journey;

        LMS_Module__c module2 = new LMS_Module__c(
            Module_Name__c = 'Second Module',
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published'
        );
        insert module2;

        LMS_Module__c module1 = [SELECT Id FROM LMS_Module__c WHERE Module_Name__c = 'Test Module' LIMIT 1];

        Test.startTest();
        JourneyModuleAssignmentController.createModuleAssignments(
            journey.Id,
            new List<Id>{ module1.Id, module2.Id }
        );
        Test.stopTest();

        List<LMS_Module_Assignment__c> assignments = [
            SELECT Id FROM LMS_Module_Assignment__c WHERE Journey__c = :journey.Id
        ];

        Assert.areEqual(2, assignments.size(), 'Two assignments should have been created');
    }
}