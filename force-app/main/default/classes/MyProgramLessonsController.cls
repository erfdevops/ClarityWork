public without sharing class MyProgramLessonsController {
    
    /**
     * Helper method to check if current user's Contact RecordType is 'Member'
     * Returns true if Member, false if External or No Contact (No Contact will use Employee lookup)
     */
    public static Boolean isContactMemberOrNone() {
        try {
            Id currentUserId = UserInfo.getUserId();
            List<User> users = [SELECT Id, ContactId FROM User WHERE Id = :currentUserId LIMIT 1];
            
            if (users.isEmpty() || users[0].ContactId == null) {
                return false; // No contact, fall back to Employee-based lookup
            }
            
            Id contactId = users[0].ContactId;
            List<Contact> contacts = [
                SELECT Id, RecordType.DeveloperName 
                FROM Contact 
                WHERE Id = :contactId 
                LIMIT 1
            ];
            
            if (contacts.isEmpty()) {
                return false; // No contact found, fall back to Employee-based lookup
            }
            
            String recordTypeName = contacts[0].RecordType.DeveloperName;
            return recordTypeName == 'Member' || recordTypeName == null;
            
        } catch (Exception e) {
            System.debug('Error checking contact record type: ' + e.getMessage());
            return false; // Default to Employee-based lookup on error
        }
    }
    
    /**
     * Helper method to get current user's Contact ID
     * Returns the Contact ID if found, null otherwise
     */
    public static Id getCurrentUserContactId() {
        try {
            Id currentUserId = UserInfo.getUserId();
            List<User> users = [SELECT Id, ContactId FROM User WHERE Id = :currentUserId LIMIT 1];
            
            if (users.isEmpty() || users[0].ContactId == null) {
                return null;
            }
            
            return users[0].ContactId;
        } catch (Exception e) {
            System.debug('Error getting contact ID: ' + e.getMessage());
            return null;
        }
    }
    
     @AuraEnabled
    public static void updateLessonWeekAssignmentStatus(Id lessonWeekAssignmentId) {
        try {
            // Check CRUD permissions
            if (!Schema.sObjectType.LMS_Lesson_Week_Assignment__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update lesson assignments.');
            }
            
            // Query the lesson week assignment
            List<LMS_Lesson_Week_Assignment__c> assignments = [
                SELECT Id, 
                       Completed__c,
                       Status__c
                FROM LMS_Lesson_Week_Assignment__c
                WHERE Id = :lessonWeekAssignmentId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (assignments.isEmpty()) {
                throw new AuraHandledException('Lesson week assignment not found.');
            }
            
            LMS_Lesson_Week_Assignment__c assignment = assignments[0];
            
            // Mark as in progress (started) by setting both Completed and Status fields
            // This ensures the status changes from "Not Started" to "In Progress"
            assignment.Completed__c = false;
            assignment.Status__c = 'In Progress';
            
            update assignment;
            
            System.debug('Successfully updated lesson week assignment status: ' + lessonWeekAssignmentId);
            
        } catch (Exception e) {
            System.debug('Error updating lesson week assignment status: ' + e.getMessage());
            throw new AuraHandledException('Error updating status: ' + e.getMessage());
        }
    }
    
    /**
     * Save external lesson score and create survey result
     * @param lessonWeekAssignmentId The ID of the lesson week assignment
     * @param score The score value (0-100)
     * @return The created survey result record
     */
    @AuraEnabled
    public static Id saveExternalLessonScore(Id lessonWeekAssignmentId, Decimal score) {
        try {
            // Validate score range
            if (score < 0 || score > 100) {
                throw new AuraHandledException('Score must be between 0 and 100.');
            }
            
            // Check CRUD permissions
            if (!Schema.sObjectType.LMS_Lesson_Week_Assignment__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update lesson assignments.');
            }
            
            if (!Schema.sObjectType.LMS_Survey_Result__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create survey results.');
            }
            
            // Query the lesson week assignment with related data
            List<LMS_Lesson_Week_Assignment__c> assignments = [
                SELECT Id, 
                       Lesson__c,
                       Lesson__r.Module__c,
                       Enrollment__c,
                       External_Lesson_Score__c
                FROM LMS_Lesson_Week_Assignment__c
                WHERE Id = :lessonWeekAssignmentId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (assignments.isEmpty()) {
                throw new AuraHandledException('Lesson week assignment not found.');
            }
            
            LMS_Lesson_Week_Assignment__c assignment = assignments[0];
            
            // Update the external lesson score
            assignment.External_Lesson_Score__c = score;
            assignment.Completed__c = true; // Mark as completed
            assignment.Status__c = 'Completed'; // Update status
            
            update assignment;
            
            // Create survey result record (similar to quiz results)
            LMS_Survey_Result__c surveyResult = new LMS_Survey_Result__c();
            surveyResult.Lesson__c = assignment.Lesson__c;
            surveyResult.Enrollment__c = assignment.Enrollment__c;
            surveyResult.Module__c = assignment.Lesson__r.Module__c;
            surveyResult.Percentage__c = score;
            surveyResult.LMS_Survey_Result_Type__c = 'External Lesson';
            surveyResult.Passed__c = score >= 70; // 70% passing threshold
            
            insert surveyResult;
            
            System.debug('Successfully saved external lesson score: ' + score + ' for assignment: ' + lessonWeekAssignmentId);
            
            return surveyResult.Id;
            
        } catch (Exception e) {
            System.debug('Error saving external lesson score: ' + e.getMessage());
            throw new AuraHandledException('Error saving score: ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static LessonAssignmentsData getLessonAssignmentsData(String moduleId) {
        try {
            if (String.isBlank(moduleId)) {
                return new LessonAssignmentsData();
            }
            
            // Get current user ID
            Id currentUserId = UserInfo.getUserId();
            
            // Find the user's enrollment for this module
            Boolean isMemberOrNone = isContactMemberOrNone();
            List<LMS_Enrollment__c> enrollments;
            
            if (isMemberOrNone) {
                // Member: query enrollments where current Contact is the External_Resource__c
                Id currentContactId = getCurrentUserContactId();
                System.debug('Member query - moduleId: ' + moduleId + ', currentContactId: ' + currentContactId);
                enrollments = [
                    SELECT Id
                    FROM LMS_Enrollment__c
                    WHERE Module_Assignment__r.Module__c = :moduleId
                    AND External_Resource__c = :currentContactId
                    AND Module_Assignment__c != null
                    AND Status__c != 'Unenrolled'
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                System.debug('Member enrollments found: ' + enrollments.size());
            } else {
                // Non-Member Contact or No Contact: query enrollments using Employee relationship
                System.debug('Non-Member query - moduleId: ' + moduleId + ', currentUserId: ' + currentUserId);
                enrollments = [
                    SELECT Id
                    FROM LMS_Enrollment__c
                    WHERE Module_Assignment__r.Module__c = :moduleId
                    AND Employee__r.User__c = :currentUserId
                    AND Module_Assignment__c != null
                    AND Status__c != 'Unenrolled'
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                System.debug('Non-Member enrollments found: ' + enrollments.size());
            }
            
            if (enrollments.isEmpty()) {
                return new LessonAssignmentsData();
            }
            
            Id enrollmentId = enrollments[0].Id;
            
            // Query lesson week assignments for this enrollment
            List<LMS_Lesson_Week_Assignment__c> assignments = [
                SELECT Id,
                       Name,
                       Lesson__c,
                       Lesson__r.Id,
                       Lesson__r.Lesson_ID__c,
                       Lesson__r.Lesson_Name__c,
                       Lesson__r.Lesson_Badge__c,
                       Lesson__r.Lesson_Points__c,
                       Lesson__r.Start_Date__c,
                       Lesson__r.End_Date__c,
                       Lesson__r.Duration_Hours__c,
                       Lesson__r.Lesson_Overview__c,
                       Lesson__r.Learning_Objectives__c,
                       Lesson__r.Prerequisites__c,
                       Lesson__r.Lesson_Content__c,
                       Lesson__r.Type__c,
                       Lesson__r.Module__c,
                       Lesson__r.Module__r.Name,
                       Lesson__r.External_Lesson__c,
                       Lesson_Due_Week__c,
                       Completed__c,
                       Status__c,
                       End_Date__c,
                       Extension_Date__c,
                       External_Lesson_Score__c,
                       Enrollment__c,
                       Enrollment__r.Module_Assignment__c,
                       Enrollment__r.Module_Assignment__r.Id,
                       Enrollment__r.Module_Assignment__r.Module__c
                FROM LMS_Lesson_Week_Assignment__c
                WHERE Enrollment__c = :enrollmentId
                ORDER BY Lesson_Due_Week__c ASC, Lesson__r.CreatedDate ASC
            ];
            
            // Get lesson IDs for quiz counting
            Set<Id> lessonIds = new Set<Id>();
            for (LMS_Lesson_Week_Assignment__c assignment : assignments) {
                lessonIds.add(assignment.Lesson__c);
            }
            
            // Count quizzes per lesson
            Map<Id, Integer> lessonQuizCounts = new Map<Id, Integer>();
            if (!lessonIds.isEmpty()) {
                AggregateResult[] quizCounts = [
                    SELECT Lesson__c, COUNT(Id) quizCount
                    FROM LMS_Survey__c
                    WHERE Lesson__c IN :lessonIds
                    GROUP BY Lesson__c
                ];
                
                for (AggregateResult ar : quizCounts) {
                    lessonQuizCounts.put((Id)ar.get('Lesson__c'), (Integer)ar.get('quizCount'));
                }
            }
            
            // Count files per lesson
            Map<Id, Integer> lessonFileCounts = new Map<Id, Integer>();
            if (!lessonIds.isEmpty()) {
                // Assuming there's a ContentDocumentLink or similar file relationship
                // You may need to adjust the object name based on your file storage method
                AggregateResult[] fileCounts = [
                    SELECT LinkedEntityId, COUNT(Id) fileCount
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId IN :lessonIds
                    GROUP BY LinkedEntityId
                ];
                
                for (AggregateResult ar : fileCounts) {
                    lessonFileCounts.put((Id)ar.get('LinkedEntityId'), (Integer)ar.get('fileCount'));
                }
            }
            
            return new LessonAssignmentsData(assignments, lessonQuizCounts, lessonFileCounts);
            
        } catch (Exception e) {
            System.debug('Error in getLessonAssignmentsData: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error retrieving lesson assignments: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static LessonsData getLessonsData(String moduleId) {
        try {
            if (String.isBlank(moduleId)) {
                return new LessonsData();
            }
            
            // Query lessons for the selected module with security enforced
            List<LMS_Lesson__c> lessons = [
                SELECT Id, 
                       Lesson_ID__c, 
                       Lesson_Name__c, 
                       Lesson_Badge__c,
                       Lesson_Points__c,
                       Start_Date__c,
                       End_Date__c,
                       Duration_Hours__c,
                       Lesson_Overview__c,
                       Learning_Objectives__c,
                       Prerequisites__c,
                       Lesson_Content__c,
                       Type__c,
                       Module__c,
                       Module__r.Name
                FROM LMS_Lesson__c 
                WHERE Module__c = :moduleId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate ASC
            ];
            
            if (lessons.isEmpty()) {
                return new LessonsData();
            }
            
            // Get lesson IDs for quiz and file counting
            Set<Id> lessonIds = new Set<Id>();
            for (LMS_Lesson__c lesson : lessons) {
                lessonIds.add(lesson.Id);
            }
            
            // Get current user's lesson week assignments for these lessons
            Id currentUserId = UserInfo.getUserId();
            Map<Id, Id> lessonToAssignmentMap = getLessonWeekAssignmentMap(lessonIds, currentUserId);
            
            // Count quizzes per lesson
            Map<Id, Integer> lessonQuizCounts = getQuizCounts(lessonIds);
            
            // Count files per lesson week assignment
            Map<Id, Integer> lessonFileCounts = getFileCounts(new Set<Id>(lessonToAssignmentMap.values()));
            
            // Create lessons data response
            LessonsData lessonsData = new LessonsData();
            lessonsData.lessons = new List<LessonData>();
            lessonsData.moduleId = moduleId;
            
            // Convert lessons to LessonData
            for (LMS_Lesson__c lesson : lessons) {
                LessonData lessonData = new LessonData();
                lessonData.id = lesson.Id;
                lessonData.lessonId = lesson.Lesson_ID__c;
                lessonData.title = lesson.Lesson_Name__c;
                lessonData.badge = lesson.Lesson_Badge__c;
                lessonData.points = lesson.Lesson_Points__c != null ? Integer.valueOf(lesson.Lesson_Points__c) : 0;
                lessonData.startDate = lesson.Start_Date__c;
                lessonData.endDate = lesson.End_Date__c;
                lessonData.duration = formatDuration(lesson.Duration_Hours__c);
                lessonData.overview = lesson.Lesson_Overview__c;
                lessonData.learningObjectives = lesson.Learning_Objectives__c;
                lessonData.prerequisites = lesson.Prerequisites__c;
                lessonData.content = lesson.Lesson_Content__c;
                lessonData.moduleName = lesson.Module__r.Name;
                
                // Set additional properties for UI compatibility
                lessonData.type = lesson.Type__c != null ? lesson.Type__c : 'Lesson'; // Use Type__c field or default to 'Lesson'
                lessonData.quizzes = lessonQuizCounts.get(lesson.Id) != null ? lessonQuizCounts.get(lesson.Id) : 0;
                
                // Get file count from lesson week assignment
                Id assignmentId = lessonToAssignmentMap.get(lesson.Id);
                lessonData.files = (assignmentId != null && lessonFileCounts.get(assignmentId) != null) ? 
                                  lessonFileCounts.get(assignmentId) : 0;
                
                lessonData.statusCompleted = false; // Default, can be enhanced with progress tracking
                
                lessonsData.lessons.add(lessonData);
            }
            
            return lessonsData;
            
        } catch (Exception e) {
            System.debug('Error in getLessonsData: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving lessons data: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static LessonData getLessonDetails(Id lessonId) {
        try {
            // Query single lesson with full details including content
            List<LMS_Lesson__c> lessons = [
                SELECT Id, 
                       Lesson_ID__c, 
                       Lesson_Name__c, 
                       Lesson_Badge__c,
                       Lesson_Points__c,
                       Start_Date__c,
                       End_Date__c,
                       Duration_Hours__c,
                       Lesson_Overview__c,
                       Learning_Objectives__c,
                       Prerequisites__c,
                       Lesson_Content__c,
                       Type__c,
                       Module__c,
                       Module__r.Name,
                       External_Lesson__c
                FROM LMS_Lesson__c 
                WHERE Id = :lessonId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (lessons.isEmpty()) {
                return null;
            }
            
            LMS_Lesson__c lesson = lessons[0];
            LessonData lessonData = new LessonData();
            lessonData.id = lesson.Id;
            lessonData.lessonId = lesson.Lesson_ID__c;
            lessonData.title = lesson.Lesson_Name__c;
            lessonData.badge = lesson.Lesson_Badge__c;
            lessonData.points = lesson.Lesson_Points__c != null ? Integer.valueOf(lesson.Lesson_Points__c) : 0;
            lessonData.startDate = lesson.Start_Date__c;
            lessonData.endDate = lesson.End_Date__c;
            lessonData.duration = formatDuration(lesson.Duration_Hours__c);
            lessonData.overview = lesson.Lesson_Overview__c;
            lessonData.learningObjectives = lesson.Learning_Objectives__c;
            lessonData.prerequisites = lesson.Prerequisites__c;
            lessonData.content = lesson.Lesson_Content__c;
            lessonData.moduleName = lesson.Module__r.Name;
            
            // Set additional properties for UI compatibility
            lessonData.type = lesson.Type__c != null ? lesson.Type__c : 'Lesson'; // Use Type__c field or default to 'Lesson'
            lessonData.quizzes = 0; // Default, can be enhanced with actual quiz count
            lessonData.files = 0; // Default, can be enhanced with actual file count
            lessonData.statusCompleted = false; // Default, can be enhanced with progress tracking
            
            return lessonData;
            
        } catch (Exception e) {
            System.debug('Error in getLessonDetails: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving lesson details: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Id getLessonWeekAssignmentId(Id lessonId) {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            List<LMS_Lesson_Week_Assignment__c> assignments = [
                SELECT Id
                FROM LMS_Lesson_Week_Assignment__c
                WHERE Lesson__c = :lessonId
                AND Enrollment__r.Employee__r.User__c = :currentUserId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            return assignments.isEmpty() ? null : assignments[0].Id;
            
        } catch (Exception e) {
            System.debug('Error in getLessonWeekAssignmentId: ' + e.getMessage());
            return null;
        }
    }

    public static String formatDuration(Decimal durationHours) {
        if (durationHours == null) {
            return '0:30';
        }
        
        Integer hours = Integer.valueOf(durationHours);
        Integer minutes = Integer.valueOf((durationHours - hours) * 60);
        
        if (hours == 0) {
            return '0:' + String.valueOf(minutes).leftPad(2, '0');
        } else {
            return String.valueOf(hours) + ':' + String.valueOf(minutes).leftPad(2, '0');
        }
    }
    
    // Wrapper classes for data structure
    public class LessonsData {
        @AuraEnabled public List<LessonData> lessons { get; set; }
        @AuraEnabled public String moduleId { get; set; }
        
        public LessonsData() {
            this.lessons = new List<LessonData>();
        }
    }
    
    public class LessonData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String lessonId { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String badge { get; set; }
        @AuraEnabled public Integer points { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public String duration { get; set; }
        @AuraEnabled public String overview { get; set; }
        @AuraEnabled public String learningObjectives { get; set; }
        @AuraEnabled public String prerequisites { get; set; }
        @AuraEnabled public String content { get; set; }
        @AuraEnabled public String moduleName { get; set; }
        
        // Additional properties for UI compatibility
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public Integer quizzes { get; set; }
        @AuraEnabled public Integer files { get; set; }
        @AuraEnabled public Boolean statusCompleted { get; set; }
    }
    
    /**
     * Helper method to count quizzes per lesson
     */
    public static Map<Id, Integer> getQuizCounts(Set<Id> lessonIds) {
        Map<Id, Integer> quizCounts = new Map<Id, Integer>();
        
        // Query quiz counts per lesson
        AggregateResult[] quizResults = [
            SELECT Lesson__c lessonId, COUNT(Id) quizCount
            FROM LMS_Survey__c 
            WHERE Lesson__c IN :lessonIds
            AND Status__c = 'Ready'
            AND Survey_Type__c = 'Quiz'
            WITH SECURITY_ENFORCED
            GROUP BY Lesson__c
        ];
        
        for (AggregateResult result : quizResults) {
            Id lessonId = (Id) result.get('lessonId');
            Integer count = (Integer) result.get('quizCount');
            quizCounts.put(lessonId, count);
        }
        
        return quizCounts;
    }
    
    /**
     * Helper method to get lesson week assignment mapping for current user
     */
    public static Map<Id, Id> getLessonWeekAssignmentMap(Set<Id> lessonIds, Id userId) {
        Map<Id, Id> lessonToAssignmentMap = new Map<Id, Id>();
        
        // Query lesson week assignments for the current user's enrollments
        List<LMS_Lesson_Week_Assignment__c> assignments = [
            SELECT Id, Lesson__c, Enrollment__r.Employee__r.User__c
            FROM LMS_Lesson_Week_Assignment__c
            WHERE Lesson__c IN :lessonIds
            AND Enrollment__r.Employee__r.User__c = :userId
            WITH SECURITY_ENFORCED
        ];
        
        for (LMS_Lesson_Week_Assignment__c assignment : assignments) {
            lessonToAssignmentMap.put(assignment.Lesson__c, assignment.Id);
        }
        
        return lessonToAssignmentMap;
    }
    
    /**
     * Helper method to count files per lesson week assignment
     */
    public static Map<Id, Integer> getFileCounts(Set<Id> assignmentIds) {
        Map<Id, Integer> fileCounts = new Map<Id, Integer>();
        
        if (assignmentIds.isEmpty()) {
            return fileCounts;
        }
        
        // Query file counts per lesson week assignment
        AggregateResult[] fileResults = [
            SELECT LinkedEntityId assignmentId, COUNT(Id) fileCount
            FROM ContentDocumentLink 
            WHERE LinkedEntityId IN :assignmentIds
            WITH SECURITY_ENFORCED
            GROUP BY LinkedEntityId
        ];
        
        for (AggregateResult result : fileResults) {
            Id assignmentId = (Id) result.get('assignmentId');
            Integer count = (Integer) result.get('fileCount');
            fileCounts.put(assignmentId, count);
        }
        
        return fileCounts;
    }
    
    /**
     * Wrapper class for lesson assignments data
     */
    public class LessonAssignmentsData {
        @AuraEnabled public List<LessonAssignmentWrapper> assignments { get; set; }
        @AuraEnabled public Integer totalCount { get; set; }
        
        public LessonAssignmentsData() {
            this.assignments = new List<LessonAssignmentWrapper>();
            this.totalCount = 0;
        }
        
        public LessonAssignmentsData(List<LMS_Lesson_Week_Assignment__c> assignmentRecords) {
            this.assignments = new List<LessonAssignmentWrapper>();
            
            for (LMS_Lesson_Week_Assignment__c assignment : assignmentRecords) {
                this.assignments.add(new LessonAssignmentWrapper(assignment));
            }
            
            this.totalCount = this.assignments.size();
        }
        
        public LessonAssignmentsData(List<LMS_Lesson_Week_Assignment__c> assignmentRecords, Map<Id, Integer> lessonQuizCounts) {
            this.assignments = new List<LessonAssignmentWrapper>();
            
            for (LMS_Lesson_Week_Assignment__c assignment : assignmentRecords) {
                this.assignments.add(new LessonAssignmentWrapper(assignment, lessonQuizCounts));
            }
            
            this.totalCount = this.assignments.size();
        }
        
        public LessonAssignmentsData(List<LMS_Lesson_Week_Assignment__c> assignmentRecords, Map<Id, Integer> lessonQuizCounts, Map<Id, Integer> lessonFileCounts) {
            this.assignments = new List<LessonAssignmentWrapper>();
            
            for (LMS_Lesson_Week_Assignment__c assignment : assignmentRecords) {
                this.assignments.add(new LessonAssignmentWrapper(assignment, lessonQuizCounts, lessonFileCounts));
            }
            
            this.totalCount = this.assignments.size();
        }
    }
    
    /**
     * Wrapper class for individual lesson assignment
     */
    public class LessonAssignmentWrapper {
        @AuraEnabled public String id { get; set; } // Lesson Week Assignment ID
        @AuraEnabled public String lessonId { get; set; } // Lesson ID
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String lessonName { get; set; }
        @AuraEnabled public String title { get; set; } // Display title (using lesson name)
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean completed { get; set; }
        @AuraEnabled public String week { get; set; }
        @AuraEnabled public String lessonBadge { get; set; }
        @AuraEnabled public Decimal lessonPoints { get; set; }
        @AuraEnabled public Integer points { get; set; } // Integer version for UI compatibility
        @AuraEnabled public String duration { get; set; } // Formatted duration
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public Decimal durationHours { get; set; }
        @AuraEnabled public String lessonOverview { get; set; }
        @AuraEnabled public String learningObjectives { get; set; }
        @AuraEnabled public String prerequisites { get; set; }
        @AuraEnabled public String lessonContent { get; set; }
        @AuraEnabled public Integer quizzes { get; set; } // Quiz count
        @AuraEnabled public Integer files { get; set; } // File count
        @AuraEnabled public Date dueDate { get; set; }
        @AuraEnabled public Date assignmentEndDate { get; set; } // Lesson week assignment due date
        @AuraEnabled public Date assignmentExtensionDate { get; set; } // Lesson week assignment extension date
        @AuraEnabled public String enrollmentId { get; set; } // Enrollment ID
        @AuraEnabled public Boolean externalLesson { get; set; } // External lesson flag
        @AuraEnabled public Decimal externalLessonScore { get; set; } // External lesson score
        
        // Status properties for UI buttons
        @AuraEnabled public Boolean statusCompleted { get; set; }
        @AuraEnabled public Boolean statusStart { get; set; }
        @AuraEnabled public Boolean statusContinue { get; set; }
        @AuraEnabled public String moduleAssignmentId { get; set; } // Module Assignment ID
        @AuraEnabled public String moduleId { get; set; } // Module ID
        
        public LessonAssignmentWrapper(LMS_Lesson_Week_Assignment__c assignment) {
            this.id = assignment.Id;
            this.lessonId = assignment.Lesson__c;
            this.name = assignment.Name;
            this.lessonName = assignment.Lesson__r.Lesson_Name__c;
            this.title = assignment.Lesson__r.Lesson_Name__c; // Use lesson name as title for display
            this.type = assignment.Lesson__r.Type__c;
            this.status = assignment.Status__c != null ? assignment.Status__c : (assignment.Completed__c ? 'Completed' : 'Not Started');
            this.completed = assignment.Completed__c;
            this.week = assignment.Lesson_Due_Week__c;
            this.lessonBadge = assignment.Lesson__r.Lesson_Badge__c;
            this.lessonPoints = assignment.Lesson__r.Lesson_Points__c;
            this.points = assignment.Lesson__r.Lesson_Points__c != null ? Integer.valueOf(assignment.Lesson__r.Lesson_Points__c) : 0;
            this.duration = formatDuration(assignment.Lesson__r.Duration_Hours__c);
            this.startDate = assignment.Lesson__r.Start_Date__c;
            this.endDate = assignment.Lesson__r.End_Date__c;
            this.durationHours = assignment.Lesson__r.Duration_Hours__c;
            this.lessonOverview = assignment.Lesson__r.Lesson_Overview__c;
            this.learningObjectives = assignment.Lesson__r.Learning_Objectives__c;
            this.prerequisites = assignment.Lesson__r.Prerequisites__c;
            this.lessonContent = assignment.Lesson__r.Lesson_Content__c;
            this.quizzes = 0; // Default - could be calculated from related records
            this.files = 0; // Default - could be calculated from related records
            this.assignmentEndDate = assignment.End_Date__c;
            this.assignmentExtensionDate = assignment.Extension_Date__c;
            this.enrollmentId = assignment.Enrollment__c;
            this.moduleAssignmentId = assignment.Enrollment__r.Module_Assignment__c;
            this.moduleId = assignment.Enrollment__r.Module_Assignment__r.Module__c;
            
            // Set status button properties based on completion
            setStatusProperties(assignment.Completed__c, assignment.Status__c);
            
            // this.dueDate = assignment.Due_Date__c; // Field may not exist
        }
        
        public LessonAssignmentWrapper(LMS_Lesson_Week_Assignment__c assignment, Map<Id, Integer> lessonQuizCounts) {
            this.id = assignment.Id;
            this.lessonId = assignment.Lesson__c;
            this.name = assignment.Name;
            this.lessonName = assignment.Lesson__r.Lesson_Name__c;
            this.title = assignment.Lesson__r.Lesson_Name__c; // Use lesson name as title for display
            this.type = assignment.Lesson__r.Type__c;
            this.status = assignment.Status__c != null ? assignment.Status__c : (assignment.Completed__c ? 'Completed' : 'Not Started');
            this.completed = assignment.Completed__c;
            this.week = assignment.Lesson_Due_Week__c;
            this.lessonBadge = assignment.Lesson__r.Lesson_Badge__c;
            this.lessonPoints = assignment.Lesson__r.Lesson_Points__c;
            this.points = assignment.Lesson__r.Lesson_Points__c != null ? Integer.valueOf(assignment.Lesson__r.Lesson_Points__c) : 0;
            this.duration = formatDuration(assignment.Lesson__r.Duration_Hours__c);
            this.startDate = assignment.Lesson__r.Start_Date__c;
            this.endDate = assignment.Lesson__r.End_Date__c;
            this.durationHours = assignment.Lesson__r.Duration_Hours__c;
            this.lessonOverview = assignment.Lesson__r.Lesson_Overview__c;
            this.learningObjectives = assignment.Lesson__r.Learning_Objectives__c;
            this.prerequisites = assignment.Lesson__r.Prerequisites__c;
            this.lessonContent = assignment.Lesson__r.Lesson_Content__c;
            this.quizzes = lessonQuizCounts.get(assignment.Lesson__c) != null ? lessonQuizCounts.get(assignment.Lesson__c) : 0;
            this.files = 0; // Default - will be set by the new constructor with file counts
            this.assignmentEndDate = assignment.End_Date__c;
            this.assignmentExtensionDate = assignment.Extension_Date__c;
            this.enrollmentId = assignment.Enrollment__c;
            this.moduleAssignmentId = assignment.Enrollment__r.Module_Assignment__c;
            this.moduleId = assignment.Enrollment__r.Module_Assignment__r.Module__c;
            
            // Set status button properties based on completion
            setStatusProperties(assignment.Completed__c, assignment.Status__c);
            
            // this.dueDate = assignment.Due_Date__c; // Field may not exist
        }
        
        public LessonAssignmentWrapper(LMS_Lesson_Week_Assignment__c assignment, Map<Id, Integer> lessonQuizCounts, Map<Id, Integer> lessonFileCounts) {
            this.id = assignment.Id;
            this.lessonId = assignment.Lesson__c;
            this.name = assignment.Name;
            this.lessonName = assignment.Lesson__r.Lesson_Name__c;
            this.title = assignment.Lesson__r.Lesson_Name__c; // Use lesson name as title for display
            this.type = assignment.Lesson__r.Type__c;
            this.status = assignment.Status__c != null ? assignment.Status__c : (assignment.Completed__c ? 'Completed' : 'Not Started');
            this.completed = assignment.Completed__c;
            this.week = assignment.Lesson_Due_Week__c;
            this.lessonBadge = assignment.Lesson__r.Lesson_Badge__c;
            this.lessonPoints = assignment.Lesson__r.Lesson_Points__c;
            this.points = assignment.Lesson__r.Lesson_Points__c != null ? Integer.valueOf(assignment.Lesson__r.Lesson_Points__c) : 0;
            this.duration = formatDuration(assignment.Lesson__r.Duration_Hours__c);
            this.startDate = assignment.Lesson__r.Start_Date__c;
            this.endDate = assignment.Lesson__r.End_Date__c;
            this.durationHours = assignment.Lesson__r.Duration_Hours__c;
            this.lessonOverview = assignment.Lesson__r.Lesson_Overview__c;
            this.learningObjectives = assignment.Lesson__r.Learning_Objectives__c;
            this.prerequisites = assignment.Lesson__r.Prerequisites__c;
            this.lessonContent = assignment.Lesson__r.Lesson_Content__c;
            this.quizzes = lessonQuizCounts.get(assignment.Lesson__c) != null ? lessonQuizCounts.get(assignment.Lesson__c) : 0;
            this.files = lessonFileCounts.get(assignment.Lesson__c) != null ? lessonFileCounts.get(assignment.Lesson__c) : 0;
            this.assignmentEndDate = assignment.End_Date__c;
            this.assignmentExtensionDate = assignment.Extension_Date__c;
            this.enrollmentId = assignment.Enrollment__c;
            this.moduleAssignmentId = assignment.Enrollment__r.Module_Assignment__c;
            this.moduleId = assignment.Enrollment__r.Module_Assignment__r.Module__c;
            this.externalLesson = assignment.Lesson__r.External_Lesson__c;
            this.externalLessonScore = assignment.External_Lesson_Score__c;
            
            // Set status button properties based on completion
            setStatusProperties(assignment.Completed__c, assignment.Status__c);
            
            // this.dueDate = assignment.Due_Date__c; // Field may not exist
        }
        
   
    
    /**
     * Helper method to set status button properties based on completion status
     */
        private void setStatusProperties(Boolean isCompleted, String assignmentStatus) {
            if (isCompleted) {
                // Assignment is completed
                this.statusCompleted = true;
                this.statusStart = false;
                this.statusContinue = false;
            } else if (assignmentStatus == 'In Progress') {
                // Assignment is in progress
                this.statusCompleted = false;
                this.statusStart = false;
                this.statusContinue = true;  // Show CONTINUE button
            } else {
                // Assignment not started
                this.statusCompleted = false;
                this.statusStart = true;  // Show START button
                this.statusContinue = false;
            }
        }
    }
}