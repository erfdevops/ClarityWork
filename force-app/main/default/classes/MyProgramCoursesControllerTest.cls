@isTest
private class MyProgramCoursesControllerTest {

    @testSetup
    static void setupTestData() {
        Employee__c employee = new Employee__c(
            Name = 'Test Employee',
            User__c = UserInfo.getUserId()
        );
        insert employee;

        LMS_Journey__c journey = new LMS_Journey__c(
            Journey_Name__c = 'Test Journey'
        );
        insert journey;

        LMS_Module__c module = new LMS_Module__c(
            Module_Name__c = 'Test Module',
            Journey__c = journey.Id,
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published',
            Module_Points__c = 50
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
            Status__c = 'Not Started'
        );
        insert lessonAssignment;
    }

    @isTest
    static void testGetUserJourneys() {
        Test.startTest();
        List<MyProgramCoursesController.JourneyOption> result = MyProgramCoursesController.getUserJourneys();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetCoursesData() {
        Test.startTest();
        MyProgramCoursesController.CoursesData result = MyProgramCoursesController.getCoursesData();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.courses);
    }

    @isTest
    static void testGetCoursesDataByJourney() {
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        Test.startTest();
        MyProgramCoursesController.CoursesData result = MyProgramCoursesController.getCoursesDataByJourney(journey.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.isEmpty);
        System.assertNotEquals(null, result.courses);
        System.assertEquals(1, result.courses.size());
    }

    @isTest
    static void testGetCoursesDataByJourneyNoEnrollments() {
        LMS_Journey__c emptyJourney = new LMS_Journey__c(Journey_Name__c = 'Empty Journey');
        insert emptyJourney;
        Test.startTest();
        MyProgramCoursesController.CoursesData result = MyProgramCoursesController.getCoursesDataByJourney(emptyJourney.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(true, result.isEmpty);
    }

    @isTest
    static void testGetCoursesDataWithCompletedLesson() {
        LMS_Lesson_Week_Assignment__c assignment = [SELECT Id FROM LMS_Lesson_Week_Assignment__c LIMIT 1];
        assignment.Completed__c = true;
        assignment.Status__c = 'Completed';
        update assignment;

        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        Test.startTest();
        MyProgramCoursesController.CoursesData result = MyProgramCoursesController.getCoursesDataByJourney(journey.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.courses);
    }

    // ── determineModuleStatus ────────────────────────────────────────────────

    @isTest
    static void testDetermineModuleStatusAvailable() {
        LMS_Module__c module = new LMS_Module__c(
            Module_Name__c = 'M', Module_Status__c = 'Active', Publishing_Status__c = 'Published', Module_Points__c = 0
        );
        Assert.areEqual('Available', MyProgramCoursesController.determineModuleStatus(module));
    }

    @isTest
    static void testDetermineModuleStatusComingSoonActiveNotPublished() {
        LMS_Module__c module = new LMS_Module__c(
            Module_Name__c = 'M', Module_Status__c = 'Active', Publishing_Status__c = 'Draft', Module_Points__c = 0
        );
        Assert.areEqual('Coming Soon', MyProgramCoursesController.determineModuleStatus(module));
    }

    @isTest
    static void testDetermineModuleStatusUnavailable() {
        LMS_Module__c module = new LMS_Module__c(
            Module_Name__c = 'M', Module_Status__c = 'Inactive', Module_Points__c = 0
        );
        Assert.areEqual('Unavailable', MyProgramCoursesController.determineModuleStatus(module));
    }

    @isTest
    static void testDetermineModuleStatusArchived() {
        LMS_Module__c module = new LMS_Module__c(
            Module_Name__c = 'M', Module_Status__c = 'Archived', Module_Points__c = 0
        );
        Assert.areEqual('Archived', MyProgramCoursesController.determineModuleStatus(module));
    }

    @isTest
    static void testDetermineModuleStatusDefaultComingSoon() {
        LMS_Module__c module = new LMS_Module__c(
            Module_Name__c = 'M', Module_Status__c = 'Unknown', Module_Points__c = 0
        );
        Assert.areEqual('Coming Soon', MyProgramCoursesController.determineModuleStatus(module));
    }

    // ── formatDuration ───────────────────────────────────────────────────────

    @isTest
    static void testFormatDurationNull() {
        Assert.areEqual('1 hour', MyProgramCoursesController.formatDuration(null));
    }

    @isTest
    static void testFormatDurationLessThanOneHour() {
        // 0.02 months * 40 = 0 hours → '30 minutes'
        Assert.areEqual('30 minutes', MyProgramCoursesController.formatDuration(0.02));
    }

    @isTest
    static void testFormatDurationExactlyOneHour() {
        // 0.025 months * 40 = 1 hour
        Assert.areEqual('1 hour', MyProgramCoursesController.formatDuration(0.025));
    }

    @isTest
    static void testFormatDurationMultipleHours() {
        // 2 months * 40 = 80 hours
        Assert.areEqual('80 hours', MyProgramCoursesController.formatDuration(2));
    }
}