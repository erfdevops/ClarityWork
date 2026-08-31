@isTest
private class LessonWeekAssignHandlerTest {

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
            End_Date__c = System.today().addDays(30)
        );
        insert enrollment;

        LMS_Lesson__c lesson1 = new LMS_Lesson__c(
            Lesson_Name__c = 'Lesson 1',
            Module__c = module.Id,
            Type__c = 'Lesson'
        );
        LMS_Lesson__c lesson2 = new LMS_Lesson__c(
            Lesson_Name__c = 'Lesson 2',
            Module__c = module.Id,
            Type__c = 'Lesson'
        );
        insert new List<LMS_Lesson__c>{ lesson1, lesson2 };

        LMS_Lesson_Week_Assignment__c lwa1 = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson1.Id,
            Enrollment__c = enrollment.Id,
            Module_Assignment__c = moduleAssignment.Id,
            Completed__c = false,
            Status__c = 'Not Started'
        );
        LMS_Lesson_Week_Assignment__c lwa2 = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson2.Id,
            Enrollment__c = enrollment.Id,
            Module_Assignment__c = moduleAssignment.Id,
            Completed__c = false,
            Status__c = 'Not Started'
        );
        insert new List<LMS_Lesson_Week_Assignment__c>{ lwa1, lwa2 };
    }

    // ─── Direct handler tests ───────────────────────────────────────────────

    @isTest
    static void testHandleCompletedAssignmentsEmpty() {
        Test.startTest();
        LMSLessonWeekAssignmentTriggerHandler.handleCompletedAssignments(new List<LMS_Lesson_Week_Assignment__c>());
        Test.stopTest();
        Assert.isTrue(true, 'Empty list should complete without error');
    }

    @isTest
    static void testHandleCompletedAssignmentsNoModuleAssignment() {
        // Assignment with no Module_Assignment__c → collectModuleAssignmentIds returns empty → early return
        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Completed__c = true
            // Module_Assignment__c intentionally null
        );

        Test.startTest();
        LMSLessonWeekAssignmentTriggerHandler.handleCompletedAssignments(
            new List<LMS_Lesson_Week_Assignment__c>{ assignment }
        );
        Test.stopTest();

        Assert.isTrue(true, 'No module assignment ID should exit early without error');
    }

    // ─── Trigger-driven DML tests ───────────────────────────────────────────

    @isTest
    static void testPartialCompletionDoesNotUpdateModuleAssignment() {
        // Only one of two lessons completed → module should stay In Progress
        LMS_Lesson_Week_Assignment__c lwa1 = [
            SELECT Id, Completed__c FROM LMS_Lesson_Week_Assignment__c
            WHERE Lesson__r.Lesson_Name__c = 'Lesson 1' LIMIT 1
        ];

        Test.startTest();
        lwa1.Completed__c = true;
        lwa1.Status__c = 'Completed';
        update lwa1;
        Test.stopTest();

        LMS_Module_Assignment__c moduleAssignment = [SELECT Status__c FROM LMS_Module_Assignment__c LIMIT 1];
        Assert.areEqual('In Progress', moduleAssignment.Status__c, 'Module should remain In Progress when not all lessons are complete');
    }

    @isTest
    static void testAllLessonsCompletedUpdatesModuleAssignment() {
        // Complete lesson 1 first (outside test transaction), then complete lesson 2 → all done
        List<LMS_Lesson_Week_Assignment__c> lwas = [
            SELECT Id, Lesson__r.Lesson_Name__c, Completed__c, Status__c
            FROM LMS_Lesson_Week_Assignment__c
            ORDER BY Lesson__r.Lesson_Name__c
        ];

        // Mark lesson 1 completed outside Test.startTest to pre-set state
        LMS_Lesson_Week_Assignment__c lwa1 = lwas[0];
        lwa1.Completed__c = true;
        lwa1.Status__c = 'Completed';
        update lwa1;

        Test.startTest();
        LMS_Lesson_Week_Assignment__c lwa2 = lwas[1];
        lwa2.Completed__c = true;
        lwa2.Status__c = 'Completed';
        update lwa2; // Trigger fires → handler sees all completed → updates module
        Test.stopTest();

        LMS_Module_Assignment__c moduleAssignment = [SELECT Status__c FROM LMS_Module_Assignment__c LIMIT 1];
        Assert.areEqual('Completed', moduleAssignment.Status__c, 'Module should be Completed when all lessons are done');
    }

    @isTest
    static void testTriggerNotFiredWhenCompletedAlreadyTrue() {
        // Complete both lessons first
        List<LMS_Lesson_Week_Assignment__c> lwas = [SELECT Id, Completed__c, Status__c FROM LMS_Lesson_Week_Assignment__c];
        for (LMS_Lesson_Week_Assignment__c lwa : lwas) {
            lwa.Completed__c = true;
            lwa.Status__c = 'Completed';
        }
        update lwas;

        // Reset module back to In Progress to detect if trigger would accidentally fire again
        LMS_Module_Assignment__c moduleAssignment = [SELECT Id FROM LMS_Module_Assignment__c LIMIT 1];
        moduleAssignment.Status__c = 'In Progress';
        update moduleAssignment;

        Test.startTest();
        // Update a field other than Completed__c on an already-completed assignment
        LMS_Lesson_Week_Assignment__c lwa = lwas[0];
        lwa.Status__c = 'Completed'; // still true → trigger filter: old was true, new is true → not added to completedAssignments
        update lwa;
        Test.stopTest();

        LMS_Module_Assignment__c reloaded = [SELECT Status__c FROM LMS_Module_Assignment__c LIMIT 1];
        Assert.areEqual('In Progress', reloaded.Status__c, 'Module should not be updated when Completed did not change from false to true');
    }

    @isTest
    static void testModuleWithNoLessonsNotUpdated() {
        // Handler called with an assignment whose module has no related lesson week assignments in DB
        LMS_Module_Assignment__c orphanModule = new LMS_Module_Assignment__c(
            Module__c = [SELECT Id FROM LMS_Module__c LIMIT 1].Id,
            Status__c = 'In Progress',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(30)
        );
        insert orphanModule;

        LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
            Module_Assignment__c = orphanModule.Id,
            Completed__c = true
        );

        Test.startTest();
        // identifyCompletedModules: moduleLessons list returned from query is empty → no update
        LMSLessonWeekAssignmentTriggerHandler.handleCompletedAssignments(
            new List<LMS_Lesson_Week_Assignment__c>{ assignment }
        );
        Test.stopTest();

        LMS_Module_Assignment__c reloaded = [SELECT Status__c FROM LMS_Module_Assignment__c WHERE Id = :orphanModule.Id];
        Assert.areEqual('In Progress', reloaded.Status__c, 'Module with no lessons should not be updated');
    }
}