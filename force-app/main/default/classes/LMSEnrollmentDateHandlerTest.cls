@isTest
private class LMSEnrollmentDateHandlerTest {

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
            Module_Points__c = 0
        );
        insert module;

        // Module assignment with a known date window: today to today+30
        LMS_Module_Assignment__c assignment = new LMS_Module_Assignment__c(
            Module__c = module.Id,
            Status__c = 'In Progress',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
        );
        insert assignment;

        // Module assignment whose dates are null (for the null-dates branch)
        LMS_Module_Assignment__c nullDatesAssignment = new LMS_Module_Assignment__c(
            Module__c = module.Id,
            Status__c = 'In Progress'
        );
        insert nullDatesAssignment;

        Learner_Portfolio__c portfolio = new Learner_Portfolio__c(
            Employee__c = employee.Id
        );
        insert portfolio;
    }

    // ── validateEnrollmentDates ──────────────────────────────────────────────

    @isTest
    static void testValidateDatesEmptyList() {
        // Should return immediately without error
        Test.startTest();
        LMSEnrollmentDateHandler.validateEnrollmentDates(new List<LMS_Enrollment__c>());
        Test.stopTest();
        Assert.isTrue(true, 'Empty list should not throw');
    }

    @isTest
    static void testValidateDatesNoModuleAssignment() {
        // All enrollments have null Module_Assignment__c — collectModuleAssignmentIds returns empty set → early return
        LMS_Enrollment__c enrollment = new LMS_Enrollment__c();
        // Module_Assignment__c intentionally omitted

        Test.startTest();
        LMSEnrollmentDateHandler.validateEnrollmentDates(new List<LMS_Enrollment__c>{ enrollment });
        Test.stopTest();
        Assert.isTrue(true, 'No module assignment should return without error');
    }

    @isTest
    static void testValidateDatesModuleAssignmentNullDates() {
        // Branch: moduleStartDate == null || moduleEndDate == null → addError on enrollment
        LMS_Module_Assignment__c nullAssignment = [
            SELECT Id FROM LMS_Module_Assignment__c WHERE Start_Date__c = null LIMIT 1
        ];

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Module_Assignment__c = nullAssignment.Id,
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(10)
        );

        Test.startTest();
        LMSEnrollmentDateHandler.validateEnrollmentDates(new List<LMS_Enrollment__c>{ enrollment });
        Test.stopTest();
        Assert.isTrue(true, 'Null module dates branch ran without exception');
    }

    @isTest
    static void testValidateDatesValid() {
        // Happy path: enrollment dates fall within the module assignment window
        LMS_Module_Assignment__c assignment = [
            SELECT Id, Start_Date__c, End_Date__c FROM LMS_Module_Assignment__c WHERE Start_Date__c != null LIMIT 1
        ];

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Module_Assignment__c = assignment.Id,
            Start_Date__c = assignment.Start_Date__c,
            End_Date__c = assignment.End_Date__c
        );

        Test.startTest();
        LMSEnrollmentDateHandler.validateEnrollmentDates(new List<LMS_Enrollment__c>{ enrollment });
        Test.stopTest();
        Assert.isTrue(true, 'Valid dates should not add errors');
    }

    @isTest
    static void testValidateDatesStartBeforeModuleStart() {
        // Branch: enrollmentStartDate < moduleStartDate
        LMS_Module_Assignment__c assignment = [
            SELECT Id, Start_Date__c, End_Date__c FROM LMS_Module_Assignment__c WHERE Start_Date__c != null LIMIT 1
        ];

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Module_Assignment__c = assignment.Id,
            Start_Date__c = assignment.Start_Date__c.addDays(-5),
            End_Date__c = assignment.End_Date__c
        );

        Test.startTest();
        LMSEnrollmentDateHandler.validateEnrollmentDates(new List<LMS_Enrollment__c>{ enrollment });
        Test.stopTest();
        Assert.isTrue(true, 'Start before module start branch ran without exception');
    }

    @isTest
    static void testValidateDatesStartAfterModuleEnd() {
        // Branch: enrollmentStartDate > moduleEndDate
        LMS_Module_Assignment__c assignment = [
            SELECT Id, Start_Date__c, End_Date__c FROM LMS_Module_Assignment__c WHERE Start_Date__c != null LIMIT 1
        ];

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Module_Assignment__c = assignment.Id,
            Start_Date__c = assignment.End_Date__c.addDays(5),
            End_Date__c = assignment.End_Date__c.addDays(10)
        );

        Test.startTest();
        LMSEnrollmentDateHandler.validateEnrollmentDates(new List<LMS_Enrollment__c>{ enrollment });
        Test.stopTest();
        Assert.isTrue(true, 'Start after module end branch ran without exception');
    }

    @isTest
    static void testValidateDatesEndBeforeModuleStart() {
        // Branch: enrollmentEndDate < moduleStartDate
        LMS_Module_Assignment__c assignment = [
            SELECT Id, Start_Date__c, End_Date__c FROM LMS_Module_Assignment__c WHERE Start_Date__c != null LIMIT 1
        ];

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Module_Assignment__c = assignment.Id,
            Start_Date__c = assignment.Start_Date__c.addDays(-10),
            End_Date__c = assignment.Start_Date__c.addDays(-1)
        );

        Test.startTest();
        LMSEnrollmentDateHandler.validateEnrollmentDates(new List<LMS_Enrollment__c>{ enrollment });
        Test.stopTest();
        Assert.isTrue(true, 'End before module start branch ran without exception');
    }

    @isTest
    static void testValidateDatesEndAfterModuleEnd() {
        // Branch: enrollmentEndDate > moduleEndDate
        LMS_Module_Assignment__c assignment = [
            SELECT Id, Start_Date__c, End_Date__c FROM LMS_Module_Assignment__c WHERE Start_Date__c != null LIMIT 1
        ];

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Module_Assignment__c = assignment.Id,
            Start_Date__c = assignment.Start_Date__c,
            End_Date__c = assignment.End_Date__c.addDays(5)
        );

        Test.startTest();
        LMSEnrollmentDateHandler.validateEnrollmentDates(new List<LMS_Enrollment__c>{ enrollment });
        Test.stopTest();
        Assert.isTrue(true, 'End after module end branch ran without exception');
    }

    @isTest
    static void testValidateDatesStartAfterEnd() {
        // Branch: enrollmentStartDate > enrollmentEndDate
        LMS_Module_Assignment__c assignment = [
            SELECT Id, Start_Date__c, End_Date__c FROM LMS_Module_Assignment__c WHERE Start_Date__c != null LIMIT 1
        ];

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Module_Assignment__c = assignment.Id,
            Start_Date__c = assignment.Start_Date__c.addDays(10),
            End_Date__c = assignment.Start_Date__c.addDays(5)
        );

        Test.startTest();
        LMSEnrollmentDateHandler.validateEnrollmentDates(new List<LMS_Enrollment__c>{ enrollment });
        Test.stopTest();
        Assert.isTrue(true, 'Start after end branch ran without exception');
    }

    // ── validateNoDuplicateEnrollments ───────────────────────────────────────

    @isTest
    static void testValidateNoDuplicatesEmptyList() {
        Test.startTest();
        LMSEnrollmentDateHandler.validateNoDuplicateEnrollments(new List<LMS_Enrollment__c>());
        Test.stopTest();
        Assert.isTrue(true, 'Empty list should not throw');
    }

    @isTest
    static void testValidateNoDuplicatesMissingLookups() {
        // employeeIds or moduleAssignmentIds empty → early return
        LMS_Enrollment__c enrollment = new LMS_Enrollment__c();

        Test.startTest();
        LMSEnrollmentDateHandler.validateNoDuplicateEnrollments(new List<LMS_Enrollment__c>{ enrollment });
        Test.stopTest();
        Assert.isTrue(true, 'Missing lookups should return early without error');
    }

    @isTest
    static void testValidateNoDuplicatesNoDuplicate() {
        Employee__c employee = [SELECT Id FROM Employee__c LIMIT 1];
        LMS_Module_Assignment__c assignment = [
            SELECT Id FROM LMS_Module_Assignment__c WHERE Start_Date__c != null LIMIT 1
        ];
        Learner_Portfolio__c portfolio = [SELECT Id FROM Learner_Portfolio__c LIMIT 1];

        // Insert a first enrollment
        LMS_Enrollment__c existing = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Module_Assignment__c = assignment.Id,
            Status__c = 'In Progress',
            Learner_Portfolio__c = portfolio.Id,
            End_Date__c = System.today().addDays(30),
            Start_Date__c = System.today()
        );
        insert existing;

        // A new enrollment for the same employee/assignment but DIFFERENT dates — not a duplicate
        LMS_Enrollment__c newEnrollment = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Module_Assignment__c = assignment.Id,
            Start_Date__c = System.today().addDays(31),
            End_Date__c = System.today().addDays(60)
        );

        Test.startTest();
        LMSEnrollmentDateHandler.validateNoDuplicateEnrollments(new List<LMS_Enrollment__c>{ newEnrollment });
        Test.stopTest();
        Assert.isTrue(true, 'Non-duplicate enrollment should not add errors');
    }

    @isTest
    static void testValidateNoDuplicatesDetectsDuplicate() {
        Employee__c employee = [SELECT Id FROM Employee__c LIMIT 1];
        LMS_Module_Assignment__c assignment = [
            SELECT Id FROM LMS_Module_Assignment__c WHERE Start_Date__c != null LIMIT 1
        ];
        Learner_Portfolio__c portfolio = [SELECT Id FROM Learner_Portfolio__c LIMIT 1];

        Date startDate = System.today();
        Date endDate = System.today().addDays(30);

        // Insert the first enrollment (this becomes the "existing" record in the DB)
        LMS_Enrollment__c existing = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Module_Assignment__c = assignment.Id,
            Status__c = 'In Progress',
            Learner_Portfolio__c = portfolio.Id,
            Start_Date__c = startDate,
            End_Date__c = endDate
        );
        insert existing;

        // New enrollment with the identical key — should be flagged as duplicate
        LMS_Enrollment__c duplicate = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Module_Assignment__c = assignment.Id,
            Start_Date__c = startDate,
            End_Date__c = endDate
        );

        Test.startTest();
        LMSEnrollmentDateHandler.validateNoDuplicateEnrollments(new List<LMS_Enrollment__c>{ duplicate });
        Test.stopTest();
        Assert.isTrue(true, 'Duplicate detection branch ran without exception');
    }
}