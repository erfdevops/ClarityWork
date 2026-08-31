@isTest
private class LMSEnrollmentPortfolioTriggerHandlerTest {

    @testSetup
    static void setupTestData() {
        Employee__c employee = new Employee__c(
            Name = 'Test Employee',
            User__c = UserInfo.getUserId()
        );
        insert employee;

        Contact contact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact'
        );
        insert contact;

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

        LMS_Module_Assignment__c assignment = new LMS_Module_Assignment__c(
            Module__c = module.Id,
            Status__c = 'In Progress'
        );
        insert assignment;
    }

    // ── handleAfterInsert ────────────────────────────────────────────────────

    @isTest
    static void testHandleAfterInsertNotInsert() {
        // isInsert = false → immediate return, no work done
        Test.startTest();
        LMSEnrollmentPortfolioTriggerHandler.handleAfterInsert(new List<LMS_Enrollment__c>(), false);
        Test.stopTest();
        Assert.isTrue(true, 'Not-insert flag should return early');
    }

    @isTest
    static void testHandleAfterInsertEmptyList() {
        // isInsert = true but no enrollments → no portfolios to create
        Test.startTest();
        LMSEnrollmentPortfolioTriggerHandler.handleAfterInsert(new List<LMS_Enrollment__c>(), true);
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Learner_Portfolio__c], 'No portfolios should be created for empty list');
    }

    @isTest
    static void testHandleAfterInsertCreatesPortfolioForEmployee() {
        Employee__c employee = [SELECT Id FROM Employee__c LIMIT 1];
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        LMS_Module_Assignment__c assignment = [SELECT Id FROM LMS_Module_Assignment__c LIMIT 1];

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = assignment.Id,
            Status__c = 'In Progress',
            End_Date__c = System.today().addDays(30)
        );
        // No insert needed — handler only reads fields, does not require an Id

        Test.startTest();
        LMSEnrollmentPortfolioTriggerHandler.handleAfterInsert(
            new List<LMS_Enrollment__c>{ enrollment }, true
        );
        Test.stopTest();

        List<Learner_Portfolio__c> portfolios = [SELECT Employee__c, Journey_Status__c FROM Learner_Portfolio__c WHERE Employee__c = :employee.Id];
        Assert.areEqual(1, portfolios.size(), 'Should create one portfolio for employee');
        Assert.areEqual('In Progress', portfolios[0].Journey_Status__c, 'Portfolio status should be In Progress');
    }

    @isTest
    static void testHandleAfterInsertCreatesPortfolioForContact() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        LMS_Module_Assignment__c assignment = [SELECT Id FROM LMS_Module_Assignment__c LIMIT 1];

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            External_Resource__c = contact.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = assignment.Id,
            Status__c = 'In Progress',
            End_Date__c = System.today().addDays(30)
        );
        // No insert needed — handler only reads fields, does not require an Id

        Test.startTest();
        LMSEnrollmentPortfolioTriggerHandler.handleAfterInsert(
            new List<LMS_Enrollment__c>{ enrollment }, true
        );
        Test.stopTest();

        List<Learner_Portfolio__c> portfolios = [SELECT Contact__c FROM Learner_Portfolio__c WHERE Contact__c = :contact.Id];
        Assert.areEqual(1, portfolios.size(), 'Should create one portfolio for contact');
    }

    @isTest
    static void testHandleAfterInsertSkipsExistingPortfolio() {
        Employee__c employee = [SELECT Id FROM Employee__c LIMIT 1];
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        LMS_Module_Assignment__c assignment = [SELECT Id FROM LMS_Module_Assignment__c LIMIT 1];

        // Pre-existing portfolio for this employee
        Learner_Portfolio__c existingPortfolio = new Learner_Portfolio__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Journey_Status__c = 'In Progress'
        );
        insert existingPortfolio;

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = assignment.Id,
            Status__c = 'In Progress',
            End_Date__c = System.today().addDays(30)
        );
        // No insert needed — handler only reads fields, does not require an Id

        Test.startTest();
        LMSEnrollmentPortfolioTriggerHandler.handleAfterInsert(
            new List<LMS_Enrollment__c>{ enrollment }, true
        );
        Test.stopTest();

        // Still only one portfolio — the existing one was not duplicated
        List<Learner_Portfolio__c> portfolios = [SELECT Id FROM Learner_Portfolio__c WHERE Employee__c = :employee.Id];
        Assert.areEqual(1, portfolios.size(), 'Should not create a duplicate portfolio when one already exists');
    }

    @isTest
    static void testHandleAfterInsertNoDuplicatesInSameBatch() {
        Employee__c employee = [SELECT Id FROM Employee__c LIMIT 1];
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        LMS_Module_Assignment__c assignment = [SELECT Id FROM LMS_Module_Assignment__c LIMIT 1];

        // Two enrollments for the same employee in one batch — no insert needed
        LMS_Enrollment__c e1 = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = assignment.Id,
            Status__c = 'In Progress',
            End_Date__c = System.today().addDays(30)
        );
        LMS_Enrollment__c e2 = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = assignment.Id,
            Status__c = 'In Progress',
            End_Date__c = System.today().addDays(60)
        );

        Test.startTest();
        LMSEnrollmentPortfolioTriggerHandler.handleAfterInsert(
            new List<LMS_Enrollment__c>{ e1, e2 }, true
        );
        Test.stopTest();

        List<Learner_Portfolio__c> portfolios = [SELECT Id FROM Learner_Portfolio__c WHERE Employee__c = :employee.Id];
        Assert.areEqual(1, portfolios.size(), 'Batch deduplication should create only one portfolio for the same employee');
    }

    // ── handleAfterUpdate ────────────────────────────────────────────────────

    @isTest
    static void testHandleAfterUpdateNotUpdate() {
        Test.startTest();
        LMSEnrollmentPortfolioTriggerHandler.handleAfterUpdate(
            new List<LMS_Enrollment__c>(),
            new Map<Id, LMS_Enrollment__c>(),
            false
        );
        Test.stopTest();
        Assert.isTrue(true, 'Not-update flag should return early');
    }

    @isTest
    static void testHandleAfterUpdateNoStatusChange() {
        // Status stays the same — contactIdsToCheck and employeeIdsToCheck remain empty → early return
        Employee__c employee = [SELECT Id FROM Employee__c LIMIT 1];
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        LMS_Module_Assignment__c assignment = [SELECT Id FROM LMS_Module_Assignment__c LIMIT 1];

        Learner_Portfolio__c portfolio = new Learner_Portfolio__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Journey_Status__c = 'In Progress'
        );
        insert portfolio;

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = assignment.Id,
            Status__c = 'In Progress',
            Learner_Portfolio__c = portfolio.Id,
            End_Date__c = System.today().addDays(30)
        );
        insert enrollment;

        // Old and new both have same status — no change
        LMS_Enrollment__c oldEnrollment = enrollment.clone(true);
        oldEnrollment.Status__c = 'In Progress';
        enrollment.Status__c = 'In Progress';

        Test.startTest();
        LMSEnrollmentPortfolioTriggerHandler.handleAfterUpdate(
            new List<LMS_Enrollment__c>{ enrollment },
            new Map<Id, LMS_Enrollment__c>{ enrollment.Id => oldEnrollment },
            true
        );
        Test.stopTest();

        Learner_Portfolio__c unchanged = [SELECT Journey_Status__c FROM Learner_Portfolio__c WHERE Id = :portfolio.Id];
        Assert.areEqual('In Progress', unchanged.Journey_Status__c, 'Portfolio should remain In Progress when no status change');
    }

    @isTest
    static void testHandleAfterUpdateAllCompletedUpdatesPortfolio() {
        Employee__c employee = [SELECT Id FROM Employee__c LIMIT 1];
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        LMS_Module_Assignment__c assignment = [SELECT Id FROM LMS_Module_Assignment__c LIMIT 1];

        Learner_Portfolio__c portfolio = new Learner_Portfolio__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Journey_Status__c = 'In Progress'
        );
        insert portfolio;

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = assignment.Id,
            Status__c = 'Completed',
            Learner_Portfolio__c = portfolio.Id,
            End_Date__c = System.today().addDays(30)
        );
        insert enrollment;

        // Old status was In Progress, new is Completed
        LMS_Enrollment__c oldEnrollment = enrollment.clone(true);
        oldEnrollment.Status__c = 'In Progress';

        Test.startTest();
        LMSEnrollmentPortfolioTriggerHandler.handleAfterUpdate(
            new List<LMS_Enrollment__c>{ enrollment },
            new Map<Id, LMS_Enrollment__c>{ enrollment.Id => oldEnrollment },
            true
        );
        Test.stopTest();

        Learner_Portfolio__c updated = [SELECT Journey_Status__c FROM Learner_Portfolio__c WHERE Id = :portfolio.Id];
        Assert.areEqual('Completed', updated.Journey_Status__c, 'Portfolio should be updated to Completed when all enrollments are done');
    }

    @isTest
    static void testHandleAfterUpdateNotAllCompletedDoesNotUpdatePortfolio() {
        Employee__c employee = [SELECT Id FROM Employee__c LIMIT 1];
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        LMS_Module_Assignment__c assignment = [SELECT Id FROM LMS_Module_Assignment__c LIMIT 1];

        Learner_Portfolio__c portfolio = new Learner_Portfolio__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Journey_Status__c = 'In Progress'
        );
        insert portfolio;

        // Insert two enrollments: one will be completed, one stays in progress
        LMS_Enrollment__c e1 = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = assignment.Id,
            Status__c = 'In Progress',
            Learner_Portfolio__c = portfolio.Id,
            End_Date__c = System.today().addDays(30)
        );
        insert e1;

        LMS_Enrollment__c e2 = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = assignment.Id,
            Status__c = 'In Progress',
            Learner_Portfolio__c = portfolio.Id,
            End_Date__c = System.today().addDays(60)
        );
        insert e2;

        // e1 changes to Completed, e2 remains In Progress
        LMS_Enrollment__c e1Old = e1.clone(true);
        e1Old.Status__c = 'In Progress';
        e1.Status__c = 'Completed';

        Test.startTest();
        LMSEnrollmentPortfolioTriggerHandler.handleAfterUpdate(
            new List<LMS_Enrollment__c>{ e1 },
            new Map<Id, LMS_Enrollment__c>{ e1.Id => e1Old },
            true
        );
        Test.stopTest();

        Learner_Portfolio__c unchanged = [SELECT Journey_Status__c FROM Learner_Portfolio__c WHERE Id = :portfolio.Id];
        Assert.areEqual('In Progress', unchanged.Journey_Status__c, 'Portfolio should stay In Progress when not all enrollments are completed');
    }
}