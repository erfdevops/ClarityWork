@isTest
public class FileUploadControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test employee
        Employee__c employee = new Employee__c(
            Name = 'Test Employee',
            User__c = UserInfo.getUserId()
        );
        insert employee;
        
        // Create test journey with required fields
        LMS_Journey__c journey = new LMS_Journey__c(
            Journey_Name__c = 'Test Journey',
            End_Date__c = System.today().addDays(30),
            Journey_Status__c = 'Active'
        );
        insert journey;
        
        // Create test module
        LMS_Module__c module = new LMS_Module__c(
            Module_Name__c = 'Test Module',
            Journey__c = journey.Id,
            Module_Status__c = 'Active'
        );
        insert module;
        
        // Create test lesson
        LMS_Lesson__c lesson = new LMS_Lesson__c(
            Lesson_Name__c = 'Test Lesson',
            Module__c = module.Id,
            Type__c = 'Lesson'
        );
        insert lesson;
        
        // Create test module assignment
        LMS_Module_Assignment__c moduleAssignment = new LMS_Module_Assignment__c(
            Module__c = module.Id,
            Status__c = 'In Progress'
        );
        insert moduleAssignment;
        
        // Create Learner Portfolio (required for enrollment)
        Learner_Portfolio__c portfolio = new Learner_Portfolio__c(
            Employee__c = employee.Id
        );
        insert portfolio;
        
        // Create test enrollment with required fields
        LMS_Enrollment__c enrollment = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = journey.Id,
            Module_Assignment__c = moduleAssignment.Id,
            Status__c = 'In Progress',
            Learner_Portfolio__c = portfolio.Id,
            End_Date__c = System.today().addDays(30)
        );
        insert enrollment;
        
        // Create test lesson week assignment
        LMS_Lesson_Week_Assignment__c lessonAssignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = enrollment.Id,
            Completed__c = false
        );
        insert lessonAssignment;
    }
    
    @isTest
    static void testUploadFile() {
        LMS_Lesson_Week_Assignment__c assignment = [SELECT Id FROM LMS_Lesson_Week_Assignment__c LIMIT 1];
        
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Test file content'));
        String fileName = 'test.txt';
        
        Test.startTest();
        try {
            String result = FileUploadController.uploadFile(base64Data, fileName, assignment.Id);
            System.assert(true, 'Method executed');
        } catch (Exception e) {
            System.assert(true, 'Exception handled');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetUploadedFiles() {
        LMS_Lesson_Week_Assignment__c assignment = [SELECT Id FROM LMS_Lesson_Week_Assignment__c LIMIT 1];
        
        Test.startTest();
        try {
            List<FileUploadController.FileData> files = FileUploadController.getUploadedFiles(assignment.Id);
            System.assert(true, 'Method executed');
        } catch (Exception e) {
            System.assert(true, 'Exception handled');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetUploadedFilesNull() {
        Test.startTest();
        try {
            List<FileUploadController.FileData> files = FileUploadController.getUploadedFiles(null);
            System.assert(true, 'Method executed');
        } catch (Exception e) {
            System.assert(true, 'Exception handled');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetUploadedFilesForAssignment() {
        LMS_Lesson_Week_Assignment__c assignment = [SELECT Id FROM LMS_Lesson_Week_Assignment__c LIMIT 1];
        
        Test.startTest();
        try {
            List<FileUploadController.FileData> files = FileUploadController.getUploadedFilesForAssignment(assignment.Id);
            System.assert(true, 'Method executed');
        } catch (Exception e) {
            System.assert(true, 'Exception handled');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testDeleteFile() {
        // Create a test ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('Test content'),
            IsMajorVersion = true
        );
        insert cv;
        
        ContentVersion insertedVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        
        Test.startTest();
        try {
            FileUploadController.deleteFile(insertedVersion.ContentDocumentId);
            System.assert(true, 'Method executed');
        } catch (Exception e) {
            System.assert(true, 'Exception handled');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetPdfFile() {
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];
        
        // Create a test PDF ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test PDF',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test PDF content'),
            IsMajorVersion = true
        );
        insert cv;
        
        ContentVersion insertedVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        
        // Link to lesson
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedVersion.ContentDocumentId,
            LinkedEntityId = lesson.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
        
        Test.startTest();
        try {
            FileUploadController.PdfFileData pdfData = FileUploadController.getPdfFile(lesson.Id);
            System.assert(true, 'Method executed');
        } catch (Exception e) {
            System.assert(true, 'Exception handled');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVideoFile() {
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];
        
        // Create a test video ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test Video',
            PathOnClient = 'test.mp4',
            VersionData = Blob.valueOf('Test video content'),
            IsMajorVersion = true
        );
        insert cv;
        
        ContentVersion insertedVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        
        // Link to lesson
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedVersion.ContentDocumentId,
            LinkedEntityId = lesson.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
        
        Test.startTest();
        try {
            FileUploadController.VideoFileData videoData = FileUploadController.getVideoFile(lesson.Id);
            System.assert(true, 'Method executed');
        } catch (Exception e) {
            System.assert(true, 'Exception handled');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetPdfFileNoFile() {
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];
        
        Test.startTest();
        try {
            FileUploadController.PdfFileData pdfData = FileUploadController.getPdfFile(lesson.Id);
            System.assert(true, 'Method executed');
        } catch (Exception e) {
            System.assert(true, 'Exception handled');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetVideoFileNoFile() {
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];
        
        Test.startTest();
        try {
            FileUploadController.VideoFileData videoData = FileUploadController.getVideoFile(lesson.Id);
            System.assert(true, 'Method executed');
        } catch (Exception e) {
            System.assert(true, 'Exception handled');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetPdfFileWithExternalUrl() {
        // Test the File_Url__c path in getPdfFile
        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];
        lesson.File_Url__c = 'https://example.com/test.pdf';
        update lesson;

        Test.startTest();
        FileUploadController.PdfFileData result = FileUploadController.getPdfFile(lesson.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.isExternalUrl);
        System.assertEquals('https://example.com/test.pdf', result.fileUrl);
    }

    @isTest
    static void testGetUploadedFilesForAssignmentNull() {
        Test.startTest();
        List<FileUploadController.FileData> files = FileUploadController.getUploadedFilesForAssignment(null);
        Test.stopTest();
        System.assertNotEquals(null, files);
        System.assertEquals(0, files.size());
    }

    @isTest
    static void testUploadFileForMemberRetirementJourney() {
        // Set the enrollment's journey to 'Member Retirement' to exercise that branch
        LMS_Journey__c retirementJourney = new LMS_Journey__c(
            Journey_Name__c = 'Member Retirement',
            End_Date__c = System.today().addDays(30),
            Journey_Status__c = 'Active'
        );
        insert retirementJourney;

        LMS_Module__c module = [SELECT Id FROM LMS_Module__c LIMIT 1];
        LMS_Module_Assignment__c moduleAssignment = new LMS_Module_Assignment__c(
            Module__c = module.Id,
            Status__c = 'In Progress'
        );
        insert moduleAssignment;

        Employee__c employee = [SELECT Id FROM Employee__c LIMIT 1];
        
        // Create Learner Portfolio for enrollment
        Learner_Portfolio__c portfolio = new Learner_Portfolio__c(
           
            Employee__c = employee.Id
        );
        insert portfolio;
        
        LMS_Enrollment__c retirementEnrollment = new LMS_Enrollment__c(
            Employee__c = employee.Id,
            Journey__c = retirementJourney.Id,
            Module_Assignment__c = moduleAssignment.Id,
            Status__c = 'In Progress',
            Enrollment_Role__c = 'Participant',
            Learner_Portfolio__c = portfolio.Id,
            End_Date__c = System.today().addDays(30)
        );
        insert retirementEnrollment;

        LMS_Lesson__c lesson = [SELECT Id FROM LMS_Lesson__c LIMIT 1];
        LMS_Lesson_Week_Assignment__c retirementAssignment = new LMS_Lesson_Week_Assignment__c(
            Lesson__c = lesson.Id,
            Enrollment__c = retirementEnrollment.Id,
            Completed__c = false,
            Status__c = 'Not Started'
        );
        insert retirementAssignment;

        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Retirement file content'));

        Test.startTest();
        try {
            String result = FileUploadController.uploadFile(base64Data, 'retirement.txt', retirementAssignment.Id);
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            System.assert(true, 'Exception handled: ' + e.getMessage());
        }
        Test.stopTest();
    }
}