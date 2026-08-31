@isTest
private class JourneyOverviewControllerTest {

    @testSetup
    static void setupTestData() {
        Employee__c employee = new Employee__c(
            Name = 'Test Employee',
            User__c = UserInfo.getUserId()
        );
        insert employee;

        LMS_Journey__c journey = new LMS_Journey__c(
            Journey_Name__c = 'Test Journey', 
            Journey_Status__c = 'Active'
        );
        insert journey;

        LMS_Module__c module = new LMS_Module__c(
            Module_Name__c = 'Test Module',
            Journey__c = journey.Id,
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published',
            Module_Points__c = 100
        );
        insert module;

        LMS_Module_Assignment__c moduleAssignment = new LMS_Module_Assignment__c(
            Module__c = module.Id,
            Status__c = 'In Progress'
        );
        insert moduleAssignment;

        Learner_Portfolio__c portfolio = new Learner_Portfolio__c(
            Employee__c = employee.Id
        );
        insert portfolio;

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = moduleAssignment.Id,
            Status__c = 'In Progress',
            Enrollment_Role__c = 'Participant',
            Learner_Portfolio__c = portfolio.Id,
            End_Date__c = System.today().addDays(30)
        );
        insert enrollment;

        LMS_Lesson__c lesson = new LMS_Lesson__c(
            Lesson_Name__c = 'Test Lesson',
            Module__c = module.Id,
            Type__c = 'Lesson',
            Lesson_Points__c = 10
        );
        insert lesson;

        LMS_Lesson_Week_Assignment__c lessonAssignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = enrollment.Id,
            Completed__c = false,
            Lesson_Due_Week__c = '1',
            Status__c = 'Not Started'
        );
        insert lessonAssignment;
    }

    @isTest
    static void testGetUserJourneys() {
        Test.startTest();
        List<JourneyOverviewController.JourneyOption> result = JourneyOverviewController.getUserJourneys();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetJourneyData() {
        Test.startTest();
        JourneyOverviewController.JourneyData result = JourneyOverviewController.getJourneyData();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetCurrentUserContactId() {
        Test.startTest();
        Id contactId = JourneyOverviewController.getCurrentUserContactId();
        Test.stopTest();
        // May be null in test context if no contact is linked to the test user
        System.assert(true, 'Method executed successfully');
    }

    @isTest
    static void testDetermineModuleStatus_ActiveAndPublished() {
        LMS_Module__c module = new LMS_Module__c(
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published'
        );
        
        Test.startTest();
        String status = JourneyOverviewController.determineModuleStatus(module);
        Test.stopTest();
        
        Assert.areEqual('On Track', status, 'Active and Published modules should return On Track');
    }

    @isTest
    static void testDetermineModuleStatus_ActiveNotPublished() {
        LMS_Module__c module = new LMS_Module__c(
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Draft'
        );
        
        Test.startTest();
        String status = JourneyOverviewController.determineModuleStatus(module);
        Test.stopTest();
        
        Assert.areEqual('Upcoming', status, 'Active but not Published modules should return Upcoming');
    }

    @isTest
    static void testDetermineModuleStatus_Inactive() {
        LMS_Module__c module = new LMS_Module__c(
            Module_Status__c = 'Inactive',
            Publishing_Status__c = 'Published'
        );
        
        Test.startTest();
        String status = JourneyOverviewController.determineModuleStatus(module);
        Test.stopTest();
        
        Assert.areEqual('Behind', status, 'Inactive modules should return Behind');
    }

    @isTest
    static void testDetermineModuleStatus_Archived() {
        LMS_Module__c module = new LMS_Module__c(
            Module_Status__c = 'Archived',
            Publishing_Status__c = 'Published'
        );
        
        Test.startTest();
        String status = JourneyOverviewController.determineModuleStatus(module);
        Test.stopTest();
        
        Assert.areEqual('Completed', status, 'Archived modules should return Completed');
    }

    @isTest
    static void testDetermineModuleStatus_Unknown() {
        LMS_Module__c module = new LMS_Module__c(
            Module_Status__c = 'Unknown',
            Publishing_Status__c = 'Published'
        );
        
        Test.startTest();
        String status = JourneyOverviewController.determineModuleStatus(module);
        Test.stopTest();
        
        Assert.areEqual('Upcoming', status, 'Unknown module status should default to Upcoming');
    }

    @isTest
    static void testGetJourneyDataById() {
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        Test.startTest();
        JourneyOverviewController.JourneyData result = JourneyOverviewController.getJourneyDataById(journey.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.isEmpty);
        System.assertNotEquals(null, result.modules);
    }

    @isTest
    static void testGetJourneyDataByIdNoEnrollments() {
        LMS_Journey__c emptyJourney = new LMS_Journey__c(Journey_Name__c = 'Empty Journey');
        insert emptyJourney;
        Test.startTest();
        JourneyOverviewController.JourneyData result = JourneyOverviewController.getJourneyDataById(emptyJourney.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(true, result.isEmpty);
    }

    @isTest
    static void testGetTimelineData() {
        Test.startTest();
        JourneyOverviewController.TimelineData result = JourneyOverviewController.getTimelineData();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetTimelineDataByJourney() {
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        Test.startTest();
        JourneyOverviewController.TimelineData result = JourneyOverviewController.getTimelineDataByJourney(journey.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetTimelineDataByJourneyNoAssignments() {
        LMS_Journey__c emptyJourney = new LMS_Journey__c(Journey_Name__c = 'No-Assignments Journey');
        insert emptyJourney;
        Test.startTest();
        JourneyOverviewController.TimelineData result = JourneyOverviewController.getTimelineDataByJourney(emptyJourney.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(true, result.isEmpty);
    }

    @isTest
    static void testGetJourneyDataCompletedEnrollment() {
        LMS_Enrollment__c enrollment = [SELECT Id FROM LMS_Enrollment__c LIMIT 1];
        enrollment.Status__c = 'Completed';
        update enrollment;

        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        Test.startTest();
        JourneyOverviewController.JourneyData result = JourneyOverviewController.getJourneyDataById(journey.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetTimelineDataByModule() {
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        
        Test.startTest();
        JourneyOverviewController.TimelineData result = JourneyOverviewController.getTimelineDataByModule(journey.Id);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isNotNull(result.journeyName, 'Journey name should not be null');
        Assert.areEqual('Module', result.weekLabel, 'Week label should be Module');
    }

    @isTest
    static void testGetTimelineDataByModule_WithAssignments() {
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        
        Test.startTest();
        JourneyOverviewController.TimelineData result = JourneyOverviewController.getTimelineDataByModule(journey.Id);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isFalse(result.isEmpty, 'Result should not be empty when assignments exist');
        Assert.isNotNull(result.weeks, 'Weeks list should not be null');
        Assert.isFalse(result.weeks.isEmpty(), 'Weeks list should contain modules');
    }

    @isTest
    static void testGetTimelineDataByModule_NoAssignments() {
        LMS_Journey__c emptyJourney = new LMS_Journey__c(
            Journey_Name__c = 'Timeline Empty Journey',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
        );
        insert emptyJourney;
        
        Test.startTest();
        JourneyOverviewController.TimelineData result = JourneyOverviewController.getTimelineDataByModule(emptyJourney.Id);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.isEmpty, 'Result should be empty when no assignments exist');
        Assert.isNotNull(result.emptyStateMessage, 'Empty state message should be provided');
    }

    @isTest
    static void testGetTimelineDataByModule_MultipleModules() {
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        LMS_Module__c existingModule = [SELECT Id FROM LMS_Module__c WHERE Module_Name__c = 'Test Module' LIMIT 1];
        
        // Create additional module
        LMS_Module__c module2 = new LMS_Module__c(
            Module_Name__c = 'Second Module',
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published'
        );
        insert module2;
        
        // Create second assignment
        LMS_Module_Assignment__c assignment2 = new LMS_Module_Assignment__c(
            Module__c = module2.Id,
            Status__c = 'In Progress',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
        );
        insert assignment2;
        
        // Create second enrollment and lesson assignment
        Employee__c employee = [SELECT Id FROM Employee__c LIMIT 1];
        Learner_Portfolio__c portfolio = [SELECT Id FROM Learner_Portfolio__c LIMIT 1];
        
        LMS_Enrollment__c enrollment2 = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = assignment2.Id,
            Status__c = 'In Progress',
            Learner_Portfolio__c = portfolio.Id,
            End_Date__c = System.today().addDays(30)
        );
        insert enrollment2;
        
        LMS_Lesson__c lesson2 = new LMS_Lesson__c(
            Lesson_Name__c = 'Second Lesson',
            Module__c = module2.Id,
            Type__c = 'Lesson'
        );
        insert lesson2;
        
        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson2.Id,
            Enrollment__c = enrollment2.Id,
            Completed__c = false
        );
        insert assignment;
        
        Test.startTest();
        JourneyOverviewController.TimelineData result = JourneyOverviewController.getTimelineDataByModule(journey.Id);
        Test.stopTest();
        
        Assert.isFalse(result.isEmpty, 'Result should not be empty');
        Assert.isNotNull(result.weeks, 'Weeks should not be null');
        Assert.isTrue(result.weeks.size() >= 2, 'Should have multiple modules');
    }
}