public without sharing class FileUploadController {
    
    @AuraEnabled
    public static String uploadFile(String base64Data, String fileName, Id lessonWeekAssignmentId) {
        try {
            // Check CRUD permissions for ContentVersion
            if (!Schema.sObjectType.ContentVersion.isCreateable()) {
                throw new AuraHandledException('You do not have permission to upload files.');
            }
            
            // Create ContentVersion record
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = fileName;
            contentVersion.PathOnClient = fileName;
            contentVersion.VersionData = EncodingUtil.base64Decode(base64Data);
            contentVersion.ContentLocation = 'S'; // Stored in Salesforce
            contentVersion.IsMajorVersion = true;
            
            insert contentVersion;
            
            // Get the ContentDocumentId from the inserted ContentVersion
            ContentVersion insertedVersion = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :contentVersion.Id 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            // Check CRUD permissions for ContentDocumentLink
            if (!Schema.sObjectType.ContentDocumentLink.isCreateable()) {
                throw new AuraHandledException('You do not have permission to link files.');
            }
            
            // Create ContentDocumentLink to associate the file with the lesson week assignment
            ContentDocumentLink contentDocLink = new ContentDocumentLink();
            contentDocLink.ContentDocumentId = insertedVersion.ContentDocumentId;
            contentDocLink.LinkedEntityId = lessonWeekAssignmentId; // Link to the lesson week assignment record
            contentDocLink.ShareType = 'V'; // Viewer permission
            contentDocLink.Visibility = 'AllUsers'; // Visible to all users
            
            insert contentDocLink;

            List<LMS_Lesson_Week_Assignment__c> enrollmentJourney = new List<LMS_Lesson_Week_Assignment__c>();
            enrollmentJourney = [
                SELECT Id, Name, Enrollment__r.Journey__c, Enrollment__r.Journey__r.Journey_Name__c 
                FROM LMS_Lesson_Week_Assignment__c 
                WHERE Id = :lessonWeekAssignmentId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            String journeyName = enrollmentJourney[0].Enrollment__r.Journey__r.Journey_Name__c;
            if (journeyName == 'Member Retirement') {
                Id currentUserId = UserInfo.getUserId();
                List<User> userContact = [SELECT Id, ContactId FROM User WHERE Id = :currentUserId WITH SECURITY_ENFORCED LIMIT 1];
                String userContactId  = userContact[0].ContactId;

                List<Benefit__c> retirementBenefit = [
                    SELECT Id, Name, Member__r.Name, Benefit_Type__c
                    FROM Benefit__c
                    WHERE Member__c = :userContactId
                    AND Benefit_Type__c = 'Retirement'
                ];

                if (retirementBenefit.size() > 0) {
                    ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
                    contentDocumentLink.ContentDocumentId = insertedVersion.ContentDocumentId;
                    contentDocumentLink.LinkedEntityId = retirementBenefit[0].Id; 
                    contentDocumentLink.ShareType = 'V';
                    contentDocumentLink.Visibility = 'AllUsers';
                    
                    insert contentDocumentLink;
                }
            }

            // Create LMS_Survey_Result__c record for assignment completion
            createAssignmentSurveyResult(lessonWeekAssignmentId);
            
            // Mark the Lesson Week Assignment as Completed
            markAssignmentAsCompleted(lessonWeekAssignmentId);
            
            return insertedVersion.ContentDocumentId;
            
        } catch (Exception e) {
            System.debug('Error in uploadFile: ' + e.getMessage());
            throw new AuraHandledException('Error uploading file: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FileData> getUploadedFiles(Id lessonWeekAssignmentId) {
        try {
            // Return empty list if no lesson week assignment provided
            if (lessonWeekAssignmentId == null) {
                return new List<FileData>();
            }
            
            return getUploadedFilesForAssignment(lessonWeekAssignmentId);
            
        } catch (Exception e) {
            System.debug('Error in getUploadedFiles: ' + e.getMessage());
            // Return empty list instead of throwing exception for cacheable method
            return new List<FileData>();
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FileData> getUploadedFilesForAssignment(Id lessonWeekAssignmentId) {
        try {
            // Return empty list if no lesson week assignment provided
            if (lessonWeekAssignmentId == null) {
                return new List<FileData>();
            }
            
            // Query ContentDocumentLinks for this lesson week assignment
            List<ContentDocumentLink> docLinks = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, 
                       ContentDocument.ContentSize, ContentDocument.CreatedDate, ContentDocument.CreatedBy.Name
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :lessonWeekAssignmentId
                WITH SECURITY_ENFORCED
                ORDER BY ContentDocument.CreatedDate DESC
            ];
            
            List<FileData> files = new List<FileData>();
            for (ContentDocumentLink docLink : docLinks) {
                FileData fileData = new FileData();
                fileData.id = docLink.ContentDocumentId;
                fileData.title = docLink.ContentDocument.Title;
                fileData.fileExtension = docLink.ContentDocument.FileExtension;
                fileData.size = docLink.ContentDocument.ContentSize;
                fileData.uploadedDate = docLink.ContentDocument.CreatedDate;
                fileData.uploadedBy = docLink.ContentDocument.CreatedBy.Name;
                fileData.formattedSize = formatFileSize(fileData.size);
                files.add(fileData);
            }
            
            return files;
            
        } catch (Exception e) {
            System.debug('Error in getUploadedFiles: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving uploaded files: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void deleteFile(Id contentDocumentId) {
        try {
            // Check CRUD permissions for ContentDocument
            if (!Schema.sObjectType.ContentDocument.isDeletable()) {
                throw new AuraHandledException('You do not have permission to delete files.');
            }
            
            ContentDocument docToDelete = [
                SELECT Id 
                FROM ContentDocument 
                WHERE Id = :contentDocumentId 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            delete docToDelete;
            
        } catch (Exception e) {
            System.debug('Error in deleteFile: ' + e.getMessage());
            throw new AuraHandledException('Error deleting file: ' + e.getMessage());
        }
    }
    
    private static String formatFileSize(Long sizeInBytes) {
        if (sizeInBytes == null || sizeInBytes == 0) {
            return '0 B';
        }
        
        Decimal size = Decimal.valueOf(sizeInBytes);
        List<String> units = new List<String>{'B', 'KB', 'MB', 'GB'};
        Integer unitIndex = 0;
        
        while (size >= 1024 && unitIndex < units.size() - 1) {
            size = size / 1024;
            unitIndex++;
        }
        
        return size.setScale(1).toPlainString() + ' ' + units[unitIndex];
    }
    
    @AuraEnabled(cacheable=true)
    public static PdfFileData getPdfFile(Id lessonId) {
        try {
            // First, check if the lesson has a File_Url__c field with a URL
            List<LMS_Lesson__c> lessons = [
                SELECT Id, File_Url__c, Lesson_Name__c
                FROM LMS_Lesson__c 
                WHERE Id = :lessonId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!lessons.isEmpty() && String.isNotBlank(lessons[0].File_Url__c)) {
                // Return the file URL from the lesson field
                LMS_Lesson__c lesson = lessons[0];
                PdfFileData pdfData = new PdfFileData();
                pdfData.fileUrl = lesson.File_Url__c;
                pdfData.fileName = lesson.Lesson_Name__c + '.pdf';
                pdfData.isExternalUrl = true;
                return pdfData;
            }
            
            // Fallback: Query for PDF files linked to the lesson
            List<ContentDocumentLink> docLinks = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension,
                       ContentDocument.ContentSize, ContentDocument.CreatedDate
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :lessonId 
                AND ContentDocument.FileExtension = 'pdf'
                WITH SECURITY_ENFORCED
                ORDER BY ContentDocument.CreatedDate DESC
                LIMIT 1
            ];
            
            if (docLinks.isEmpty()) {
                return null;
            }
            
            ContentDocumentLink docLink = docLinks[0];
            
            // Get the latest ContentVersion for this ContentDocument
            List<ContentVersion> versions = [
                SELECT Id, Title, FileExtension, ContentSize, CreatedDate, CreatedBy.Name
                FROM ContentVersion 
                WHERE ContentDocumentId = :docLink.ContentDocumentId 
                AND IsLatest = true
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (versions.isEmpty()) {
                return null;
            }
            
            ContentVersion version = versions[0];
            
            PdfFileData pdfData = new PdfFileData();
            pdfData.fileId = version.Id; // ContentVersion ID
            pdfData.contentDocumentId = docLink.ContentDocumentId; // ContentDocument ID
            pdfData.fileName = version.Title;
            pdfData.fileExtension = version.FileExtension;
            pdfData.size = version.ContentSize;
            pdfData.formattedSize = formatFileSize(version.ContentSize);
            pdfData.uploadedDate = version.CreatedDate;
            pdfData.uploadedBy = version.CreatedBy.Name;
            pdfData.isExternalUrl = false;
            
            return pdfData;
            
        } catch (Exception e) {
            System.debug('Error in getPdfFile: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving PDF file: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static VideoFileData getVideoFile(Id lessonId) {
        try {
            // Query for MP4 video files linked to the lesson
            List<ContentDocumentLink> docLinks = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension,
                       ContentDocument.ContentSize, ContentDocument.CreatedDate
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :lessonId 
                AND ContentDocument.FileExtension = 'mp4'
                WITH SECURITY_ENFORCED
                ORDER BY ContentDocument.CreatedDate DESC
                LIMIT 1
            ];
            
            if (docLinks.isEmpty()) {
                return null;
            }
            
            ContentDocumentLink docLink = docLinks[0];
            
            // Get the latest ContentVersion for this ContentDocument
            List<ContentVersion> versions = [
                SELECT Id, Title, FileExtension, ContentSize, CreatedDate, CreatedBy.Name
                FROM ContentVersion 
                WHERE ContentDocumentId = :docLink.ContentDocumentId 
                AND IsLatest = true
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (versions.isEmpty()) {
                return null;
            }
            
            ContentVersion version = versions[0];
            
            VideoFileData videoData = new VideoFileData();
            videoData.fileId = version.Id; // ContentVersion ID
            videoData.contentDocumentId = docLink.ContentDocumentId; // ContentDocument ID
            videoData.fileName = version.Title;
            videoData.fileExtension = version.FileExtension;
            videoData.size = version.ContentSize;
            videoData.formattedSize = formatFileSize(version.ContentSize);
            videoData.uploadedDate = version.CreatedDate;
            videoData.uploadedBy = version.CreatedBy.Name;
            
            return videoData;
            
        } catch (Exception e) {
            System.debug('Error in getVideoFile: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving video file: ' + e.getMessage());
        }
    }
    
    // Data structure for file information
    public class FileData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String fileExtension { get; set; }
        @AuraEnabled public Long size { get; set; }
        @AuraEnabled public String formattedSize { get; set; }
        @AuraEnabled public DateTime uploadedDate { get; set; }
        @AuraEnabled public String uploadedBy { get; set; }
    }
    
    // Data structure for PDF file information
    public class PdfFileData {
        @AuraEnabled public Id fileId { get; set; } // ContentVersion ID
        @AuraEnabled public Id contentDocumentId { get; set; } // ContentDocument ID
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String fileExtension { get; set; }
        @AuraEnabled public Long size { get; set; }
        @AuraEnabled public String formattedSize { get; set; }
        @AuraEnabled public DateTime uploadedDate { get; set; }
        @AuraEnabled public String uploadedBy { get; set; }
        @AuraEnabled public String fileUrl { get; set; } // External URL from File_Url__c field
        @AuraEnabled public Boolean isExternalUrl { get; set; } // Flag to indicate if URL is external
    }
    
    // Data structure for video file information
    public class VideoFileData {
        @AuraEnabled public Id fileId { get; set; } // ContentVersion ID
        @AuraEnabled public Id contentDocumentId { get; set; } // ContentDocument ID
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String fileExtension { get; set; }
        @AuraEnabled public Long size { get; set; }
        @AuraEnabled public String formattedSize { get; set; }
        @AuraEnabled public DateTime uploadedDate { get; set; }
        @AuraEnabled public String uploadedBy { get; set; }
    }
    
    
    /**
     * Helper method to mark lesson week assignment as completed and update enrollment status
     */
    private static void markAssignmentAsCompleted(Id lessonWeekAssignmentId) {
        try {
            // Check CRUD permissions before updating
            if (!Schema.sObjectType.LMS_Lesson_Week_Assignment__c.isUpdateable()) {
                System.debug('User does not have permission to update LMS_Lesson_Week_Assignment__c records');
                return;
            }
            
            // Mark the Lesson Week Assignment as Completed
            LMS_Lesson_Week_Assignment__c assignment = new LMS_Lesson_Week_Assignment__c(
                Id = lessonWeekAssignmentId,
                Status__c = 'Completed',
                Completed__c=true
            );
            update assignment;
            System.debug('Successfully marked assignment as completed: ' + lessonWeekAssignmentId);
            
            // Check if all assignments in the enrollment are completed
            updateEnrollmentStatus(lessonWeekAssignmentId);
            
        } catch (Exception e) {
            System.debug('Error marking assignment as completed: ' + e.getMessage());
            // Don't fail the file upload - this is a post-upload operation
        }
    }
    
    /**
     * Helper method to update enrollment status based on assignment completion
     */
    private static void updateEnrollmentStatus(Id lessonWeekAssignmentId) {
        try {
            // Check CRUD permissions for LMS_Enrollment__c
            if (!Schema.sObjectType.LMS_Enrollment__c.isUpdateable()) {
                System.debug('User does not have permission to update LMS_Enrollment__c records');
                return;
            }
            
            // Get the enrollment ID from the assignment
            List<LMS_Lesson_Week_Assignment__c> assignments = [
                SELECT Enrollment__c
                FROM LMS_Lesson_Week_Assignment__c
                WHERE Id = :lessonWeekAssignmentId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (assignments.isEmpty() || assignments[0].Enrollment__c == null) {
                return;
            }
            
            Id enrollmentId = assignments[0].Enrollment__c;

            // Do not override Unenrolled status
            List<LMS_Enrollment__c> enrollmentCheck = [
                SELECT Id, Status__c
                FROM LMS_Enrollment__c
                WHERE Id = :enrollmentId
                LIMIT 1
            ];
            if (!enrollmentCheck.isEmpty() && enrollmentCheck[0].Status__c == 'Unenrolled') {
                return;
            }

            // Check if all assignments in this enrollment are completed
            List<LMS_Lesson_Week_Assignment__c> allAssignments = [
                SELECT Id, Status__c
                FROM LMS_Lesson_Week_Assignment__c
                WHERE Enrollment__c = :enrollmentId
                WITH SECURITY_ENFORCED
            ];
            
            Boolean allCompleted = true;
            for (LMS_Lesson_Week_Assignment__c assign : allAssignments) {
                if (assign.Status__c != 'Completed') {
                    allCompleted = false;
                    break;
                }
            }
            
            // Update enrollment status based on assignment completion
            LMS_Enrollment__c enrollment = new LMS_Enrollment__c(Id = enrollmentId);
            
            if (allCompleted) {
                enrollment.Status__c = 'Completed';
                System.debug('All assignments completed - updating enrollment to Completed: ' + enrollmentId);
            } else {
                enrollment.Status__c = 'In Progress';
                System.debug('Some assignments completed - updating enrollment to In Progress: ' + enrollmentId);
            }
            
            update enrollment;
            System.debug('Successfully updated enrollment status: ' + enrollmentId);
            
        } catch (Exception e) {
            System.debug('Error updating enrollment status: ' + e.getMessage());
            // Don't fail the file upload - this is a post-upload operation
        }
    }

    /**
     * Helper method to create LMS_Survey_Result__c record for assignment completion
     */
    private static void createAssignmentSurveyResult(Id lessonWeekAssignmentId) {
        try {
            // Query the lesson week assignment to get required relationship data
            List<LMS_Lesson_Week_Assignment__c> assignments = [
                SELECT Id, 
                       Lesson__c,
                       Lesson__r.Module__c,
                       Enrollment__c,
                       Completed__c
                FROM LMS_Lesson_Week_Assignment__c 
                WHERE Id = :lessonWeekAssignmentId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (assignments.isEmpty()) {
                System.debug('No lesson week assignment found for ID: ' + lessonWeekAssignmentId);
                return;
            }
            
            LMS_Lesson_Week_Assignment__c assignment = assignments[0];
            
            // Check if a survey result already exists for this assignment to avoid duplicates
            List<LMS_Survey_Result__c> existingResults = [
                SELECT Id 
                FROM LMS_Survey_Result__c 
                WHERE Lesson__c = :assignment.Lesson__c 
                AND Enrollment__c = :assignment.Enrollment__c
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!existingResults.isEmpty()) {
                System.debug('Survey result already exists for this assignment');
                return;
            }
            
            // Check CRUD permissions for LMS_Survey_Result__c
            if (!Schema.sObjectType.LMS_Survey_Result__c.isCreateable()) {
                System.debug('User does not have permission to create LMS_Survey_Result__c records');
                return;
            }
            
            // Create the survey result record for file upload completion
            LMS_Survey_Result__c surveyResult = new LMS_Survey_Result__c();
            surveyResult.Lesson__c = assignment.Lesson__c;
            surveyResult.Module__c = assignment.Lesson__r.Module__c;
            surveyResult.Enrollment__c = assignment.Enrollment__c;
            surveyResult.Total_Number_of_Questions__c = 1;
            surveyResult.Total_Correct_Answers__c = 1;
            surveyResult.Percentage__c = 100;
            surveyResult.LMS_Survey_Result_Type__c = 'Lesson Assignment';
            
            insert surveyResult;
            
            // Update the lesson week assignment to mark as "In Progress"
            // Check CRUD permissions before updating
            if (Schema.sObjectType.LMS_Lesson_Week_Assignment__c.isUpdateable()) {
                assignment.Completed__c = false; // Mark as started/in progress (not completed)
                update assignment;
                System.debug('Successfully updated LMS_Lesson_Week_Assignment__c to In Progress: ' + lessonWeekAssignmentId);
            } else {
                System.debug('User does not have permission to update LMS_Lesson_Week_Assignment__c records');
            }
            
            System.debug('Successfully created LMS_Survey_Result__c for assignment: ' + lessonWeekAssignmentId);
            
        } catch (Exception e) {
            // Log the error but don't fail the file upload process
            System.debug('Error creating survey result for assignment ' + lessonWeekAssignmentId + ': ' + e.getMessage());
        }
    }
}