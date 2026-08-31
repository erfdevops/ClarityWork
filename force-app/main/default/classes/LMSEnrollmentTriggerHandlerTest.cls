@IsTest
private class LMSEnrollmentTriggerHandlerTest {

    @IsTest
    static void testHandleNewEnrollmentsCreatesLessonAssignments() {
        Date startDate = Date.today();
        Date endDate = startDate.addDays(30);

        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        Contact testContact = new Contact(
            LastName = 'Test Contact',
            AccountId = testAccount.Id
        );
        insert testContact;

        Employee__c testEmployee = new Employee__c(
            Name = 'Test Employee',
            Employee_Name__c = 'Test Employee',
            Phone__c = '1234567890',
            User__c = UserInfo.getUserId()
        );
        insert testEmployee;

        LMS_Module__c testModule = new LMS_Module__c(
            Module_Name__c = 'Test Module',
            Module_Status__c = 'Active',
            Publishing_Status__c = 'Published'
        );
        insert testModule;

        List<LMS_Lesson__c> testLessons = new List<LMS_Lesson__c>();
        for (Integer index = 1; index <= 3; index++) {
            testLessons.add(new LMS_Lesson__c(
                Lesson_Name__c = 'Lesson ' + String.valueOf(index),
                Module__c = testModule.Id,
                Type__c = 'Lesson'
            ));
        }
        insert testLessons;

        LMS_Journey__c testJourney = new LMS_Journey__c(
            Journey_Name__c = 'Test Journey',
            Type__c = 'Member Journey'
        );
        insert testJourney;

        Learner_Portfolio__c testPortfolio = new Learner_Portfolio__c(
            Contact__c = testContact.Id, 
            Employee__c = testEmployee.Id,
            Journey__c = testJourney.Id
        );
        insert testPortfolio;

        LMS_Enrollment__c testEnrollment = new LMS_Enrollment__c(
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Status__c = 'In Progress',
            Enrollment_Role__c = 'Participant',
            Learner_Portfolio__c = testPortfolio.Id
        );
        insert testEnrollment;

        LMS_Module_Assignment__c testModuleAssignment = new LMS_Module_Assignment__c(
            Module__c = testModule.Id,
            Enrollment__c = testEnrollment.Id,
            Status__c = 'In Progress',
            Start_Date__c = startDate,
            End_Date__c = endDate
        );
        insert testModuleAssignment;

        testEnrollment.Module_Assignment__c = testModuleAssignment.Id;

        Test.startTest();
        update testEnrollment;
        Test.stopTest();

        List<LMS_Lesson_Week_Assignment__c> createdAssignments = [
            SELECT Id, Lesson__c, Enrollment__c, Lesson_Due_Week__c
            FROM LMS_Lesson_Week_Assignment__c
            WHERE Enrollment__c = :testEnrollment.Id
        ];

        Assert.areEqual(3, createdAssignments.size(), 'Should create one assignment per lesson');

        Set<String> expectedWeeks = new Set<String>{'1','2','3'};
        Set<String> actualWeeks = new Set<String>();

        for (LMS_Lesson_Week_Assignment__c assignment : createdAssignments) {
            actualWeeks.add(assignment.Lesson_Due_Week__c);
        }

        Assert.areEqual(expectedWeeks, actualWeeks, 'Weeks should be sequential');
    }

    @IsTest
    static void testNoAssignmentsWhenNoModuleAssignment() {
        Employee__c employee = new Employee__c(
            Name = 'Test Employee 2',
            User__c = UserInfo.getUserId()
        );
        insert employee;

        Learner_Portfolio__c portfolio = new Learner_Portfolio__c(
            Employee__c = employee.Id
        );
        insert portfolio;

        LMS_Enrollment__c testEnrollment = new LMS_Enrollment__c(
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(10),
            Status__c = 'In Progress',
            Enrollment_Role__c = 'Participant',
            Learner_Portfolio__c = portfolio.Id
        );

        Test.startTest();
        insert testEnrollment;
        Test.stopTest();

        List<LMS_Lesson_Week_Assignment__c> assignments = [
            SELECT Id FROM LMS_Lesson_Week_Assignment__c
            WHERE Enrollment__c = :testEnrollment.Id
        ];

        Assert.areEqual(0, assignments.size(), 'No assignments should be created');
    }
}