@isTest
private class LMSModuleAssignmentTriggerHandlerTest {

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

        LMS_Module__c module1 = new LMS_Module__c(
            Module_Name__c = 'Module 1',
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published'
        );
        LMS_Module__c module2 = new LMS_Module__c(
            Module_Name__c = 'Module 2',
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published'
        );
        insert new List<LMS_Module__c>{ module1, module2 };

        Learner_Portfolio__c portfolio = new Learner_Portfolio__c(
            Employee__c = employee.Id
        );
        insert portfolio;

        LMS_Module_Assignment__c ma1 = new LMS_Module_Assignment__c(
            Module__c = module1.Id,
            Status__c = 'In Progress',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
        );
        LMS_Module_Assignment__c ma2 = new LMS_Module_Assignment__c(
            Module__c = module2.Id,
            Status__c = 'In Progress',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
        );
        insert new List<LMS_Module_Assignment__c>{ ma1, ma2 };

        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = ma1.Id,
            Status__c = 'In Progress',
            Learner_Portfolio__c = portfolio.Id,
            End_Date__c = System.today().addDays(30)
        );
        insert enrollment;

        // Link both module assignments to the enrollment
        ma1.Enrollment__c = enrollment.Id;
        ma2.Enrollment__c = enrollment.Id;
        update new List<LMS_Module_Assignment__c>{ ma1, ma2 };
    }

    // ─── Direct handler tests ───────────────────────────────────────────────

    @isTest
    static void testHandleCompletedModulesEmpty() {
        Test.startTest();
        LMSModuleAssignmentTriggerHandler.handleCompletedModules(new List<LMS_Module_Assignment__c>());
        Test.stopTest();
        Assert.isTrue(true, 'Empty list should complete without error');
    }

    @isTest
    static void testHandleCompletedModulesNoEnrollmentId() {
        // Module assignment with no Enrollment__c → collectEnrollmentIds returns empty → early return
        LMS_Module_Assignment__c ma = new LMS_Module_Assignment__c(
            Status__c = 'Completed'
            // Enrollment__c intentionally null
        );

        Test.startTest();
        LMSModuleAssignmentTriggerHandler.handleCompletedModules(
            new List<LMS_Module_Assignment__c>{ ma }
        );
        Test.stopTest();

        Assert.isTrue(true, 'No enrollment ID should exit early without error');
    }

    // ─── Trigger-driven DML tests ───────────────────────────────────────────

    @isTest
    static void testPartialCompletionDoesNotUpdateEnrollment() {
        // Complete only one of two module assignments → enrollment should stay In Progress
        LMS_Module_Assignment__c ma1 = [
            SELECT Id FROM LMS_Module_Assignment__c
            WHERE Module__r.Module_Name__c = 'Module 1' LIMIT 1
        ];

        Test.startTest();
        ma1.Status__c = 'Completed';
        update ma1;
        Test.stopTest();

        LMS_Enrollment__c enrollment = [SELECT Status__c FROM LMS_Enrollment__c LIMIT 1];
        Assert.areEqual('In Progress', enrollment.Status__c, 'Enrollment should remain In Progress when not all modules are complete');
    }

    @isTest
    static void testAllModulesCompletedUpdatesEnrollment() {
        // Complete module 1 outside test transaction, then complete module 2 → all done
        LMS_Module_Assignment__c ma1 = [
            SELECT Id FROM LMS_Module_Assignment__c WHERE Module__r.Module_Name__c = 'Module 1' LIMIT 1
        ];
        ma1.Status__c = 'Completed';
        update ma1;

        Test.startTest();
        LMS_Module_Assignment__c ma2 = [
            SELECT Id FROM LMS_Module_Assignment__c WHERE Module__r.Module_Name__c = 'Module 2' LIMIT 1
        ];
        ma2.Status__c = 'Completed';
        update ma2; // Trigger fires → handler sees all completed → updates enrollment
        Test.stopTest();

        LMS_Enrollment__c enrollment = [SELECT Status__c FROM LMS_Enrollment__c LIMIT 1];
        Assert.areEqual('Completed', enrollment.Status__c, 'Enrollment should be Completed when all modules are done');
    }

    @isTest
    static void testTriggerNotFiredWhenStatusAlreadyCompleted() {
        // Complete both modules first
        List<LMS_Module_Assignment__c> mas = [SELECT Id, Status__c FROM LMS_Module_Assignment__c];
        for (LMS_Module_Assignment__c ma : mas) {
            ma.Status__c = 'Completed';
        }
        update mas;

        // Reset enrollment back to In Progress to detect if trigger would fire again
        LMS_Enrollment__c enrollment = [SELECT Id FROM LMS_Enrollment__c LIMIT 1];
        enrollment.Status__c = 'In Progress';
        update enrollment;

        Test.startTest();
        // Update a field on an already-Completed module — trigger filter: old was Completed → not added
        LMS_Module_Assignment__c ma = mas[0];
        ma.End_Date__c = System.today().addDays(60);
        update ma;
        Test.stopTest();

        LMS_Enrollment__c reloaded = [SELECT Status__c FROM LMS_Enrollment__c LIMIT 1];
        Assert.areEqual('In Progress', reloaded.Status__c, 'Enrollment should not be updated when Status__c did not change from non-Completed to Completed');
    }

    @isTest
    static void testEnrollmentWithNoModulesNotUpdated() {
        // Handler called with a module assignment whose enrollment has no related modules in DB
        Learner_Portfolio__c portfolio = [SELECT Id FROM Learner_Portfolio__c LIMIT 1];
        LMS_Journey__c journey = [SELECT Id FROM LMS_Journey__c LIMIT 1];
        Employee__c employee = [SELECT Id FROM Employee__c LIMIT 1];

        LMS_Module_Assignment__c orphanMa = new LMS_Module_Assignment__c(
            Module__c = [SELECT Id FROM LMS_Module__c LIMIT 1].Id,
            Status__c = 'In Progress',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
        );
        insert orphanMa;

        LMS_Enrollment__c orphanEnrollment = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = orphanMa.Id,
            Status__c = 'In Progress',
            Learner_Portfolio__c = portfolio.Id,
            End_Date__c = System.today().addDays(30)
        );
        insert orphanEnrollment;

        // Link the module assignment to the enrollment, then call handler directly
        // with an in-memory record — enrollment has no modules linked via Enrollment__c
        LMS_Module_Assignment__c inMemoryMa = new LMS_Module_Assignment__c(
            Id = orphanMa.Id,
            Enrollment__c = orphanEnrollment.Id,
            Status__c = 'Completed'
        );

        Test.startTest();
        LMSModuleAssignmentTriggerHandler.handleCompletedModules(
            new List<LMS_Module_Assignment__c>{ inMemoryMa }
        );
        Test.stopTest();

        LMS_Enrollment__c reloaded = [SELECT Status__c FROM LMS_Enrollment__c WHERE Id = :orphanEnrollment.Id];
        Assert.areEqual('In Progress', reloaded.Status__c, 'Enrollment with no linked modules should not be updated');
    }
}