@isTest
private class LMSModuleDateHandlerTest {

    @testSetup
    static void setupData() {
        insert new List<LMS_Journey__c>{
            new LMS_Journey__c(
                Journey_Name__c = 'Valid Journey',
                Start_Date__c = System.today(),
                End_Date__c = System.today().addDays(30)
            ),
            new LMS_Journey__c(
                Journey_Name__c = 'Journey Without Dates'
            )
        };
    }

    @isTest
    static void testValidateEmptyList() {
        LMSModuleDateHandler.validateModuleDates(new List<LMS_Module_Assignment__c>());
        Assert.isTrue(true, 'Empty list should be handled without errors');
    }

    @isTest
    static void testValidateModuleDatesWithinJourneyRange() {
        LMS_Journey__c journey = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM LMS_Journey__c
            WHERE Journey_Name__c = 'Valid Journey'
            LIMIT 1
        ];

        LMS_Module_Assignment__c assignment = new LMS_Module_Assignment__c(
            Journey__c = journey.Id,
            Start_Date__c = journey.Start_Date__c.addDays(1),
            End_Date__c = journey.End_Date__c.addDays(-1)
        );

        LMSModuleDateHandler.validateModuleDates(new List<LMS_Module_Assignment__c>{ assignment });

        Assert.isFalse(assignment.hasErrors(), 'Assignment within journey dates should not have validation errors');
    }

    @isTest
    static void testValidateModuleDatesJourneyMissingDates() {
        LMS_Journey__c journey = [
            SELECT Id
            FROM LMS_Journey__c
            WHERE Journey_Name__c = 'Journey Without Dates'
            LIMIT 1
        ];

        LMS_Module_Assignment__c assignment = new LMS_Module_Assignment__c(
            Journey__c = journey.Id,
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(5)
        );

        LMSModuleDateHandler.validateModuleDates(new List<LMS_Module_Assignment__c>{ assignment });

        Assert.isTrue(assignment.hasErrors(), 'Assignment should fail when journey dates are missing');
        Assert.isTrue(
            assignment.getErrors()[0].getMessage().contains('must have valid Start and End dates'),
            'Expected missing journey date validation message'
        );
    }

    @isTest
    static void testValidateModuleDatesStartBeforeJourney() {
        LMS_Journey__c journey = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM LMS_Journey__c
            WHERE Journey_Name__c = 'Valid Journey'
            LIMIT 1
        ];

        LMS_Module_Assignment__c assignment = new LMS_Module_Assignment__c(
            Journey__c = journey.Id,
            Start_Date__c = journey.Start_Date__c.addDays(-1),
            End_Date__c = journey.End_Date__c.addDays(-1)
        );

        LMSModuleDateHandler.validateModuleDates(new List<LMS_Module_Assignment__c>{ assignment });

        Assert.isTrue(assignment.hasErrors(), 'Assignment should fail when start date is before journey start');
        Assert.isTrue(
            assignment.getErrors()[0].getMessage().contains('cannot be before the Journey start date'),
            'Expected start date before journey start message'
        );
    }

    @isTest
    static void testValidateModuleDatesEndAfterJourney() {
        LMS_Journey__c journey = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM LMS_Journey__c
            WHERE Journey_Name__c = 'Valid Journey'
            LIMIT 1
        ];

        LMS_Module_Assignment__c assignment = new LMS_Module_Assignment__c(
            Journey__c = journey.Id,
            Start_Date__c = journey.Start_Date__c.addDays(1),
            End_Date__c = journey.End_Date__c.addDays(1)
        );

        LMSModuleDateHandler.validateModuleDates(new List<LMS_Module_Assignment__c>{ assignment });

        Assert.isTrue(assignment.hasErrors(), 'Assignment should fail when end date is after journey end');
        Assert.isTrue(
            assignment.getErrors()[0].getMessage().contains('cannot be after the Journey end date'),
            'Expected end date after journey end message'
        );
    }

    @isTest
    static void testValidateModuleDatesStartAfterModuleEnd() {
        LMS_Journey__c journey = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM LMS_Journey__c
            WHERE Journey_Name__c = 'Valid Journey'
            LIMIT 1
        ];

        LMS_Module_Assignment__c assignment = new LMS_Module_Assignment__c(
            Journey__c = journey.Id,
            Start_Date__c = journey.Start_Date__c.addDays(10),
            End_Date__c = journey.Start_Date__c.addDays(5)
        );

        LMSModuleDateHandler.validateModuleDates(new List<LMS_Module_Assignment__c>{ assignment });

        Assert.isTrue(assignment.hasErrors(), 'Assignment should fail when start date is after module end date');
        Assert.isTrue(
            assignment.getErrors()[0].getMessage().contains('cannot be after the module end date'),
            'Expected start date after module end date message'
        );
    }
}