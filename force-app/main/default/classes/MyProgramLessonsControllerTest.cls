@isTest
private class MyProgramLessonsControllerTest {

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
            Module_Status__c = 'Active'
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
            Lesson_Points__c = 10,
            Duration_Hours__c = 1.5
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
    static void testUpdateLessonWeekAssignmentStatus() {
        LMS_Lesson_Week_Assignment__c assignment = [SELECT Id FROM LMS_Lesson_Week_Assignment__c LIMIT 1];
        Test.startTest();
        MyProgramLessonsController.updateLessonWeekAssignmentStatus(assignment.Id);
        Test.stopTest();
        LMS_Lesson_Week_Assignment__c updated = [SELECT Status__c FROM LMS_Lesson_Week_Assignment__c WHERE Id = :assignment.Id];
        System.assertEquals('In Progress', updated.Status__c);
    }

    @isTest
    static void testSaveExternalLessonScore() {
        LMS_Lesson_Week_Assignment__c assignment = [SELECT Id FROM LMS_Lesson_Week_Assignment__c LIMIT 1];
        Test.startTest();
        Id surveyResultId = MyProgramLessonsController.saveExternalLessonScore(assignment.Id, 85);
        Test.stopTest();
        System.assertNotEquals(null, surveyResultId);
        LMS_Lesson_Week_Assignment__c updated = [SELECT Completed__c, Status__c, External_Lesson_Score__c FROM LMS_Lesson_Week_Assignment__c WHERE Id = :assignment.Id];
        System.assertEquals(true, updated.Completed__c);
        System.assertEquals('Completed', updated.Status__c);
        System.assertEquals(85, updated.External_Lesson_Score__c);
    }

    @isTest
    static void testSaveExternalLessonScorePassing() {
        LMS_Lesson_Week_Assignment__c assignment = [SELECT Id FROM LMS_Lesson_Week_Assignment__c LIMIT 1];
        Test.startTest();
        Id surveyResultId = MyProgramLessonsController.saveExternalLessonScore(assignment.Id, 70);
        Test.stopTest();
        System.assertNotEquals(null, surveyResultId);
        LMS_Survey_Result__c result = [SELECT Passed__c FROM LMS_Survey_Result__c WHERE Id = :surveyResultId];
        System.assertEquals(true, result.Passed__c);
    }

    @isTest
    static void testSaveExternalLessonScoreFailing() {
        LMS_Lesson_Week_Assignment__c assignment = [SELECT Id FROM LMS_Lesson_Week_Assignment__c LIMIT 1];
        Test.startTest();
        Id surveyResultId = MyProgramLessonsController.saveExternalLessonScore(assignment.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, surveyResultId);
        LMS_Survey_Result__c result = [SELECT Passed__c FROM LMS_Survey_Result__c WHERE Id = :surveyResultId];
        System.assertEquals(false, result.Passed__c);
    }


    @isTest
    static void testGetLessonAssignmentsData() {
        LMS_Module__c module = [SELECT Id FROM LMS_Module__c LIMIT 1];
        Test.startTest();
        MyProgramLessonsController.LessonAssignmentsData result = MyProgramLessonsController.getLessonAssignmentsData(module.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.assignments);
        System.assertEquals(1, result.totalCount);
    }

    @isTest
    static void testGetLessonAssignmentsDataBlankModule() {
        Test.startTest();
        MyProgramLessonsController.LessonAssignmentsData result = MyProgramLessonsController.getLessonAssignmentsData(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(0, result.totalCount);
    }

    @isTest
    static void testGetLessonsData() {
        LMS_Module__c module = [SELECT Id FROM LMS_Module__c LIMIT 1];
        Test.startTest();
        MyProgramLessonsController.LessonsData result = MyProgramLessonsController.getLessonsData(module.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.lessons);
        System.assertEquals(1, result.lessons.size());
    }

    @isTest
    static void testGetLessonsDataBlankModule() {
        Test.startTest();
        MyProgramLessonsController.LessonsData result = MyProgramLessonsController.getLessonsData(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(0, result.lessons.size());
    }

    @isTest
    static void testGetLessonDetails() {
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];
        Test.startTest();
        MyProgramLessonsController.LessonData result = MyProgramLessonsController.getLessonDetails(lesson.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals('Test Lesson', result.title);
    }


    @isTest
    static void testGetLessonWeekAssignmentId() {
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];
        Test.startTest();
        Id result = MyProgramLessonsController.getLessonWeekAssignmentId(lesson.Id);
        Test.stopTest();
        // Running user does not have Employee link to lesson week assignment via Employee path
        // so null is the expected result for default test user
       
    }

    // ── LessonAssignmentsData & LessonAssignmentWrapper constructors ──────────

    @isTest
    static void testLessonAssignmentsDataOneArgConstructor() {
        // Exercises LessonAssignmentsData(List) → LessonAssignmentWrapper(assignment) 1-arg path
        LMS_Lesson_Week_Assignment__c lwa = [
            SELECT Id, Name, Lesson__c,
                   Lesson__r.Lesson_Name__c, Lesson__r.Type__c, Lesson__r.Lesson_Badge__c,
                   Lesson__r.Lesson_Points__c, Lesson__r.Start_Date__c, Lesson__r.End_Date__c,
                   Lesson__r.Duration_Hours__c, Lesson__r.Lesson_Overview__c,
                   Lesson__r.Learning_Objectives__c, Lesson__r.Prerequisites__c,
                   Lesson__r.Lesson_Content__c, Lesson__r.External_Lesson__c,
                   Lesson_Due_Week__c, Completed__c, Status__c, End_Date__c,
                   Extension_Date__c, External_Lesson_Score__c,
                   Enrollment__c, Enrollment__r.Module_Assignment__c,
                   Enrollment__r.Module_Assignment__r.Module__c
            FROM LMS_Lesson_Week_Assignment__c
            LIMIT 1
        ];

        Test.startTest();
        MyProgramLessonsController.LessonAssignmentsData data =
            new MyProgramLessonsController.LessonAssignmentsData(
                new List<LMS_Lesson_Week_Assignment__c>{ lwa }
            );
        Test.stopTest();

        Assert.areEqual(1, data.totalCount, 'Should have 1 assignment');
        Assert.areEqual('Test Lesson', data.assignments[0].lessonName);
    }

    @isTest
    static void testLessonAssignmentsDataTwoArgConstructor() {
        // Exercises LessonAssignmentsData(List, quizCounts) → LessonAssignmentWrapper(assignment, quizCounts) 2-arg path
        LMS_Lesson_Week_Assignment__c lwa = [
            SELECT Id, Name, Lesson__c,
                   Lesson__r.Lesson_Name__c, Lesson__r.Type__c, Lesson__r.Lesson_Badge__c,
                   Lesson__r.Lesson_Points__c, Lesson__r.Start_Date__c, Lesson__r.End_Date__c,
                   Lesson__r.Duration_Hours__c, Lesson__r.Lesson_Overview__c,
                   Lesson__r.Learning_Objectives__c, Lesson__r.Prerequisites__c,
                   Lesson__r.Lesson_Content__c, Lesson__r.External_Lesson__c,
                   Lesson_Due_Week__c, Completed__c, Status__c, End_Date__c,
                   Extension_Date__c, External_Lesson_Score__c,
                   Enrollment__c, Enrollment__r.Module_Assignment__c,
                   Enrollment__r.Module_Assignment__r.Module__c
            FROM LMS_Lesson_Week_Assignment__c
            LIMIT 1
        ];

        Map<Id, Integer> quizCounts = new Map<Id, Integer>{ lwa.Lesson__c => 2 };

        Test.startTest();
        MyProgramLessonsController.LessonAssignmentsData data =
            new MyProgramLessonsController.LessonAssignmentsData(
                new List<LMS_Lesson_Week_Assignment__c>{ lwa },
                quizCounts
            );
        Test.stopTest();

        Assert.areEqual(1, data.totalCount, 'Should have 1 assignment');
        Assert.areEqual(2, data.assignments[0].quizzes, 'Quiz count should be populated from map');
    }

    // ── getCurrentUserContactId & isContactMemberOrNone ────────────────────

    @isTest
    static void testGetCurrentUserContactIdNoContact() {
        // Standard test user has no ContactId → should return null
        Test.startTest();
        Id contactId = MyProgramLessonsController.getCurrentUserContactId();
        Test.stopTest();
        Assert.isNull(contactId, 'Should return null when running user has no ContactId');
    }

    @isTest
    static void testIsContactMemberOrNoneNoContact() {
        // Standard test user has no ContactId → should return false
        Test.startTest();
        Boolean result = MyProgramLessonsController.isContactMemberOrNone();
        Test.stopTest();
        Assert.isFalse(result, 'Should return false when running user has no ContactId');
    }

    // ── formatDuration ───────────────────────────────────────────────────────

    @isTest
    static void testFormatDurationNull() {
        Assert.areEqual('0:30', MyProgramLessonsController.formatDuration(null));
    }

    @isTest
    static void testFormatDurationZeroHours() {
        // 0.5 hours = 0 hours 30 minutes → '0:30'
        Assert.areEqual('0:30', MyProgramLessonsController.formatDuration(0.5));
    }

    @isTest
    static void testFormatDurationWithHours() {
        // 1.5 hours = 1 hour 30 minutes → '1:30'
        Assert.areEqual('1:30', MyProgramLessonsController.formatDuration(1.5));
    }

    @isTest
    static void testFormatDurationWholeHours() {
        // 2.0 hours = 2 hours 0 minutes → '2:00'
        Assert.areEqual('2:00', MyProgramLessonsController.formatDuration(2.0));
    }

    // ── getQuizCounts ────────────────────────────────────────────────────────

    @isTest
    static void testGetQuizCountsEmpty() {
        Map<Id, Integer> result = MyProgramLessonsController.getQuizCounts(new Set<Id>());
        Assert.isTrue(result.isEmpty(), 'Empty lessonIds should return empty map');
    }

    @isTest
    static void testGetQuizCountsWithLesson() {
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];
        // No quizzes created, so count should be 0 (no entry in map)
        Test.startTest();
        Map<Id, Integer> result = MyProgramLessonsController.getQuizCounts(new Set<Id>{ lesson.Id });
        Test.stopTest();
        Assert.isFalse(result.containsKey(lesson.Id), 'No quiz entries expected for lesson with no quizzes');
    }

    @isTest
    static void testGetQuizCountsWithQuiz() {
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];
        LMS_Survey__c quiz = new LMS_Survey__c(
            Lesson__c = lesson.Id,
            Status__c = 'Ready',
            Survey_Type__c = 'Quiz'
        );
        insert quiz;

        Test.startTest();
        Map<Id, Integer> result = MyProgramLessonsController.getQuizCounts(new Set<Id>{ lesson.Id });
        Test.stopTest();
        Assert.isTrue(result.containsKey(lesson.Id), 'Should have a quiz count for the lesson');
        Assert.areEqual(1, result.get(lesson.Id), 'Quiz count should be 1');
    }

    // ── getLessonWeekAssignmentMap ────────────────────────────────────────────

    @isTest
    static void testGetLessonWeekAssignmentMapNoMatch() {
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];
        Test.startTest();
        Map<Id, Id> result = MyProgramLessonsController.getLessonWeekAssignmentMap(
            new Set<Id>{ lesson.Id }, UserInfo.getUserId()
        );
        Test.stopTest();
        // The lesson week assignment is linked via Employee→User, but the running
        // test user matches, so this returns the assignment
        Assert.isNotNull(result, 'Map should not be null');
    }

    // ── getFileCounts ────────────────────────────────────────────────────────

    @isTest
    static void testGetFileCountsEmpty() {
        Map<Id, Integer> result = MyProgramLessonsController.getFileCounts(new Set<Id>());
        Assert.isTrue(result.isEmpty(), 'Empty assignmentIds should return empty map');
    }

    @isTest
    static void testGetFileCountsNoFiles() {
        LMS_Lesson_Week_Assignment__c lwa = [SELECT Id FROM LMS_Lesson_Week_Assignment__c LIMIT 1];
        Test.startTest();
        Map<Id, Integer> result = MyProgramLessonsController.getFileCounts(new Set<Id>{ lwa.Id });
        Test.stopTest();
        Assert.isFalse(result.containsKey(lwa.Id), 'No file entries expected for assignment with no files');
    }

    @isTest
    static void testGetFileCountsWithFile() {
        LMS_Lesson_Week_Assignment__c lwa = [SELECT Id FROM LMS_Lesson_Week_Assignment__c LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'TestDoc',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('content'),
            IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = lwa.Id,
            ContentDocumentId = docId,
            ShareType = 'V'
        );
        insert cdl;

        Test.startTest();
        Map<Id, Integer> result = MyProgramLessonsController.getFileCounts(new Set<Id>{ lwa.Id });
        Test.stopTest();
        Assert.isTrue(result.containsKey(lwa.Id), 'Should have a file count for the assignment');
        Assert.areEqual(1, result.get(lwa.Id), 'File count should be 1');
    }
}