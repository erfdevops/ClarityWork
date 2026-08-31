@isTest
private class LMSLessonDateHandlerTest {

    @testSetup
    static void setupTestData() {
        Employee__c employee = new Employee__c(
            Name = 'Test Employee',
            User__c = UserInfo.getUserId()
        );
        insert employee;

        LMS_Journey__c journey = new LMS_Journey__c(
            Journey_Name__c = 'Test Journey',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(60)
        );
        insert journey;

        LMS_Module__c module = new LMS_Module__c(
            Module_Name__c = 'Test Module',
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published'
        );
        insert module;

        LMS_Module_Assignment__c moduleAssignment = new LMS_Module_Assignment__c(
            Module__c = module.Id,
            Status__c = 'In Progress',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
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
            Learner_Portfolio__c = portfolio.Id,
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
        );
        insert enrollment;

        LMS_Lesson__c lesson = new LMS_Lesson__c(
            Lesson_Name__c = 'Test Lesson',
            Module__c = module.Id,
            Type__c = 'Lesson'
        );
        insert lesson;
    }

    // ─── Direct handler tests ───────────────────────────────────────────────

    @isTest
    static void testValidateEmptyList() {
        Test.startTest();
        LMSLessonDateHandler.validateLessonDates(new List<LMS_Lesson_Week_Assignment__c>());
        Test.stopTest();
        Assert.isTrue(true, 'Empty list should complete without error');
    }

    @isTest
    static void testValidateNoEnrollmentId() {
        // Assignment with no Enrollment__c → collectEnrollmentIds returns empty → early return
        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(5)
            // Enrollment__c intentionally omitted
        );

        Test.startTest();
        LMSLessonDateHandler.validateLessonDates(new List<LMS_Lesson_Week_Assignment__c>{ assignment });
        Test.stopTest();

        Assert.isTrue(true, 'No enrollment ID should exit early without error');
    }

    // ─── Trigger-driven DML tests ───────────────────────────────────────────

    @isTest
    static void testDatesWithinRange() {
        LMS_Enrollment__c enrollment = [SELECT Id FROM LMS_Enrollment__c LIMIT 1];
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];

        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = enrollment.Id,
            Start_Date__c = System.today().addDays(1),
            End_Date__c = System.today().addDays(10)
        );

        Test.startTest();
        insert assignment; // Should succeed — dates within enrollment range
        Test.stopTest();

        LMS_Lesson_Week_Assignment__c inserted = [SELECT Id FROM LMS_Lesson_Week_Assignment__c WHERE Id = :assignment.Id];
        Assert.isNotNull(inserted.Id, 'Assignment should be inserted successfully');
    }

    @isTest
    static void testEnrollmentMissingStartDate() {
        // Enrollment without Start_Date__c → addError on the assignment
        LMS_Enrollment__c enrollment = [SELECT Id FROM LMS_Enrollment__c LIMIT 1];
        enrollment.Start_Date__c = null;
        update enrollment;

        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];

        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = enrollment.Id,
            Start_Date__c = System.today().addDays(1),
            End_Date__c = System.today().addDays(10)
        );

        Test.startTest();
        try {
            insert assignment;
            Assert.fail('Expected DmlException for missing enrollment dates');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('Enrollment must have valid Start and End dates'), 'Error should mention enrollment dates: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testStartDateBeforeEnrollmentStart() {
        LMS_Enrollment__c enrollment = [SELECT Id, Start_Date__c FROM LMS_Enrollment__c LIMIT 1];
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];

        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = enrollment.Id,
            Start_Date__c = enrollment.Start_Date__c.addDays(-5), // before enrollment start
            End_Date__c = System.today().addDays(10)
        );

        Test.startTest();
        try {
            insert assignment;
            Assert.fail('Expected DmlException for start date before enrollment start');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('cannot be before the Enrollment start date'), 'Error should mention start date before enrollment: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testStartDateAfterEnrollmentEnd() {
        LMS_Enrollment__c enrollment = [SELECT Id, End_Date__c FROM LMS_Enrollment__c LIMIT 1];
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];

        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = enrollment.Id,
            Start_Date__c = enrollment.End_Date__c.addDays(5), // after enrollment end
            End_Date__c = enrollment.End_Date__c.addDays(10)
        );

        Test.startTest();
        try {
            insert assignment;
            Assert.fail('Expected DmlException for start date after enrollment end');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('cannot be after the Enrollment end date'), 'Error should mention start date after enrollment end: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testEndDateBeforeEnrollmentStart() {
        LMS_Enrollment__c enrollment = [SELECT Id, Start_Date__c FROM LMS_Enrollment__c LIMIT 1];
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];

        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = enrollment.Id,
            Start_Date__c = enrollment.Start_Date__c.addDays(-10),
            End_Date__c = enrollment.Start_Date__c.addDays(-2) // end before enrollment start
        );

        Test.startTest();
        try {
            insert assignment;
            Assert.fail('Expected DmlException for end date before enrollment start');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('cannot be before the Enrollment start date'), 'Error should mention end/start date violation: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testEndDateAfterEnrollmentEnd() {
        LMS_Enrollment__c enrollment = [SELECT Id, Start_Date__c, End_Date__c FROM LMS_Enrollment__c LIMIT 1];
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];

        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = enrollment.Id,
            Start_Date__c = enrollment.Start_Date__c.addDays(1),
            End_Date__c = enrollment.End_Date__c.addDays(10) // end after enrollment end
        );

        Test.startTest();
        try {
            insert assignment;
            Assert.fail('Expected DmlException for end date after enrollment end');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('cannot be after the Enrollment end date'), 'Error should mention end date after enrollment end: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testStartDateAfterLessonEndDate() {
        LMS_Enrollment__c enrollment = [SELECT Id, Start_Date__c, End_Date__c FROM LMS_Enrollment__c LIMIT 1];
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];

        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = enrollment.Id,
            Start_Date__c = enrollment.Start_Date__c.addDays(15), // start after end
            End_Date__c = enrollment.Start_Date__c.addDays(5)
        );

        Test.startTest();
        try {
            insert assignment;
            Assert.fail('Expected DmlException for lesson start after lesson end');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('cannot be after the lesson end date'), 'Error should mention start after end: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateWithValidDates() {
        // Insert a valid assignment, then update it — trigger fires on before update too
        LMS_Enrollment__c enrollment = [SELECT Id FROM LMS_Enrollment__c LIMIT 1];
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];

        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = enrollment.Id,
            Start_Date__c = System.today().addDays(1),
            End_Date__c = System.today().addDays(10)
        );
        insert assignment;

        Test.startTest();
        assignment.End_Date__c = System.today().addDays(15);
        update assignment; // Should succeed
        Test.stopTest();

        LMS_Lesson_Week_Assignment__c updated = [SELECT End_Date__c FROM LMS_Lesson_Week_Assignment__c WHERE Id = :assignment.Id];
        Assert.areEqual(System.today().addDays(15), updated.End_Date__c, 'End date should be updated');
    }

    @isTest
    static void testNoDatesSkippedByTrigger() {
        // Assignments without dates are filtered out by the trigger — no validation errors
        LMS_Enrollment__c enrollment = [SELECT Id FROM LMS_Enrollment__c LIMIT 1];
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];

        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = enrollment.Id
            // No Start_Date__c or End_Date__c → trigger filters out
        );

        Test.startTest();
        insert assignment; // Should succeed without validation
        Test.stopTest();

        LMS_Lesson_Week_Assignment__c inserted = [SELECT Id FROM LMS_Lesson_Week_Assignment__c WHERE Id = :assignment.Id];
        Assert.isNotNull(inserted.Id, 'Assignment without dates should insert without error');
    }
}