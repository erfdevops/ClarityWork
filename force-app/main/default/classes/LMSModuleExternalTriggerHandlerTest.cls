@isTest
private class LMSModuleExternalTriggerHandlerTest {

    @testSetup
    static void setupData() {
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
            Publishing_Status__c = 'Published',
            External_Module__c = false
        );
        insert module;

        List<LMS_Lesson__c> lessons = new List<LMS_Lesson__c>{
            new LMS_Lesson__c(Lesson_Name__c = 'Lesson A', Module__c = module.Id, Type__c = 'Lesson', External_Lesson__c = false),
            new LMS_Lesson__c(Lesson_Name__c = 'Lesson B', Module__c = module.Id, Type__c = 'Lesson', External_Lesson__c = false)
        };
        insert lessons;
    }

    @isTest
    static void testHandleAfterUpdateEmpty() {
        LMSModuleExternalTriggerHandler.handleAfterUpdate(
            new List<LMS_Module__c>(),
            new Map<Id, LMS_Module__c>()
        );
        Assert.isTrue(true, 'Empty list should complete without error');
    }

    @isTest
    static void testHandleAfterUpdateNoFlagChange() {
        LMS_Module__c module = [SELECT Id, External_Module__c FROM LMS_Module__c LIMIT 1];

        // Old and new have the same External_Module__c — should be no-op
        LMS_Module__c oldModule = new LMS_Module__c(Id = module.Id, External_Module__c = false);
        LMS_Module__c newModule = new LMS_Module__c(Id = module.Id, External_Module__c = false);

        Test.startTest();
        LMSModuleExternalTriggerHandler.handleAfterUpdate(
            new List<LMS_Module__c>{ newModule },
            new Map<Id, LMS_Module__c>{ oldModule.Id => oldModule }
        );
        Test.stopTest();

        List<LMS_Lesson__c> lessons = [SELECT External_Lesson__c FROM LMS_Lesson__c WHERE Module__c = :module.Id];
        for (LMS_Lesson__c lesson : lessons) {
            Assert.isFalse(lesson.External_Lesson__c, 'Lessons should remain false when flag did not change');
        }
    }

    @isTest
    static void testHandleAfterUpdateFlagSetToTrue() {
        LMS_Module__c module = [SELECT Id FROM LMS_Module__c LIMIT 1];

        // Simulate trigger: External_Module__c changed from false to true
        LMS_Module__c oldModule = new LMS_Module__c(Id = module.Id, External_Module__c = false);
        LMS_Module__c newModule = new LMS_Module__c(Id = module.Id, External_Module__c = true);

        Test.startTest();
        LMSModuleExternalTriggerHandler.handleAfterUpdate(
            new List<LMS_Module__c>{ newModule },
            new Map<Id, LMS_Module__c>{ oldModule.Id => oldModule }
        );
        Test.stopTest();

        List<LMS_Lesson__c> lessons = [SELECT External_Lesson__c FROM LMS_Lesson__c WHERE Module__c = :module.Id];
        Assert.isFalse(lessons.isEmpty(), 'Should have lessons linked to module');
        for (LMS_Lesson__c lesson : lessons) {
            Assert.isTrue(lesson.External_Lesson__c, 'Lessons should be set to true when module flag changed to true');
        }
    }

    @isTest
    static void testHandleAfterUpdateFlagSetToFalse() {
        LMS_Module__c module = [SELECT Id FROM LMS_Module__c LIMIT 1];

        // First set lessons to true
        List<LMS_Lesson__c> lessons = [SELECT Id FROM LMS_Lesson__c WHERE Module__c = :module.Id];
        for (LMS_Lesson__c l : lessons) {
            l.External_Lesson__c = true;
        }
        update lessons;

        // Simulate trigger: External_Module__c changed from true to false
        LMS_Module__c oldModule = new LMS_Module__c(Id = module.Id, External_Module__c = true);
        LMS_Module__c newModule = new LMS_Module__c(Id = module.Id, External_Module__c = false);

        Test.startTest();
        LMSModuleExternalTriggerHandler.handleAfterUpdate(
            new List<LMS_Module__c>{ newModule },
            new Map<Id, LMS_Module__c>{ oldModule.Id => oldModule }
        );
        Test.stopTest();

        List<LMS_Lesson__c> updatedLessons = [SELECT External_Lesson__c FROM LMS_Lesson__c WHERE Module__c = :module.Id];
        for (LMS_Lesson__c lesson : updatedLessons) {
            Assert.isFalse(lesson.External_Lesson__c, 'Lessons should be set to false when module flag changed to false');
        }
    }

    @isTest
    static void testHandleAfterUpdateNoRelatedLessons() {
        LMS_Module__c moduleNoLessons = new LMS_Module__c(
            Module_Name__c = 'Module No Lessons',
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published',
            External_Module__c = false
        );
        insert moduleNoLessons;

        LMS_Module__c oldModule = new LMS_Module__c(Id = moduleNoLessons.Id, External_Module__c = false);
        LMS_Module__c newModule = new LMS_Module__c(Id = moduleNoLessons.Id, External_Module__c = true);

        Test.startTest();
        LMSModuleExternalTriggerHandler.handleAfterUpdate(
            new List<LMS_Module__c>{ newModule },
            new Map<Id, LMS_Module__c>{ oldModule.Id => oldModule }
        );
        Test.stopTest();

        List<LMS_Lesson__c> lessons = [SELECT Id FROM LMS_Lesson__c WHERE Module__c = :moduleNoLessons.Id];
        Assert.isTrue(lessons.isEmpty(), 'There should be no lessons for this module');
    }

    @isTest
    static void testTriggerAfterUpdate() {
        // Fires the trigger's after update branch via real DML
        LMS_Module__c module = [SELECT Id, External_Module__c FROM LMS_Module__c LIMIT 1];

        Test.startTest();
        module.External_Module__c = true;
        update module;
        Test.stopTest();

        List<LMS_Lesson__c> lessons = [SELECT External_Lesson__c FROM LMS_Lesson__c WHERE Module__c = :module.Id];
        for (LMS_Lesson__c lesson : lessons) {
            Assert.isTrue(lesson.External_Lesson__c, 'Lessons should reflect the updated External_Module__c flag');
        }
    }

    @isTest
    static void testAdminCanDeleteModule() {
        // Running as System Administrator (default test context) — delete should succeed
        LMS_Module__c module = [SELECT Id FROM LMS_Module__c LIMIT 1];

        Test.startTest();
        delete module;
        Test.stopTest();

        List<LMS_Module__c> remaining = [SELECT Id, IsDeleted FROM LMS_Module__c WHERE Id = :module.Id ALL ROWS];
        Assert.isTrue(remaining[0].IsDeleted, 'System Administrator should be able to delete a module');
    }
}