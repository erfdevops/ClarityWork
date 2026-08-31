public without sharing class MyProgramCoursesController {
    
    /**
     * Helper method to check if current user's Contact RecordType is 'Member'
     * Returns true if Member, false if External or No Contact (No Contact will use Employee lookup)
     */
    private static Boolean isContactMemberOrNone() {
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
    private static Id getCurrentUserContactId() {
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
    
    @AuraEnabled(cacheable=true)
    public static List<JourneyOption> getUserJourneys() {
        try {
            Id currentUserId = UserInfo.getUserId();
            Boolean isMemberOrNone = isContactMemberOrNone();
            
            // Query enrollments based on Contact RecordType
            List<LMS_Enrollment__c> enrollments;
            
            if (isMemberOrNone) {
                // Member: query enrollments where current Contact is the External_Resource__c
                Id currentContactId = getCurrentUserContactId();
                enrollments = [
                    SELECT Journey__c, Journey__r.Journey_Name__c
                    FROM LMS_Enrollment__c
                    WHERE External_Resource__c = :currentContactId
                    AND Journey__c != null
                    AND Module_Assignment__c != null
                    AND Status__c != 'Unenrolled'
                    WITH SECURITY_ENFORCED
                    ORDER BY Journey__r.Journey_Name__c ASC
                ];
            } else {
                // Non-Member Contact or No Contact: query enrollments using Employee relationship
                enrollments = [
                    SELECT Journey__c, Journey__r.Journey_Name__c
                    FROM LMS_Enrollment__c
                    WHERE Employee__r.User__c = :currentUserId
                    AND Journey__c != null
                    AND Module_Assignment__c != null
                    AND Status__c != 'Unenrolled'
                    WITH SECURITY_ENFORCED
                    ORDER BY Journey__r.Journey_Name__c ASC
                ];
            }
            
            Map<Id, String> uniqueJourneys = new Map<Id, String>();
            for (LMS_Enrollment__c enrollment : enrollments) {
                uniqueJourneys.put(enrollment.Journey__c, enrollment.Journey__r.Journey_Name__c);
            }
            
            List<JourneyOption> journeyOptions = new List<JourneyOption>();
            for (Id journeyId : uniqueJourneys.keySet()) {
                JourneyOption option = new JourneyOption();
                option.value = journeyId;
                option.label = uniqueJourneys.get(journeyId);
                journeyOptions.add(option);
            }
            
            return journeyOptions;
            
        } catch (Exception e) {
            System.debug('Error in getUserJourneys: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving user journeys: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static CoursesData getCoursesData() {
        // Get first journey by default
        List<JourneyOption> userJourneys = getUserJourneys();
        if (!userJourneys.isEmpty()) {
            return getCoursesDataByJourney(userJourneys[0].value);
        }
        return new CoursesData();
    }
    
    @AuraEnabled(cacheable=true)
    public static CoursesData getCoursesDataByJourney(Id journeyId) {
        try {
            // Get current user ID
            Id currentUserId = UserInfo.getUserId();
            Boolean isMemberOrNone = isContactMemberOrNone();
            
            // Query enrollments based on Contact RecordType
            List<LMS_Enrollment__c> enrollments;
            
            if (isMemberOrNone) {
                // Member: query enrollments where current Contact is the External_Resource__c
                Id currentContactId = getCurrentUserContactId();
                enrollments = [
                    SELECT Id, Journey__c, Journey__r.Id, Journey__r.Name, Journey__r.Journey_Name__c,
                           Employee__c, Employee__r.User__c, Module_Assignment__c, Module_Assignment__r.Id,
                           Module_Assignment__r.Duration__c, Module_Assignment__r.Module__c,
                           Module_Assignment__r.Module__r.Id, Module_Assignment__r.Module__r.Module_ID__c,
                           Module_Assignment__r.Module__r.Name, Module_Assignment__r.Module__r.Module_Name__c,
                           Module_Assignment__r.Module__r.Module_Badge__c, Module_Assignment__r.Module__r.Module_Level__c,
                           Module_Assignment__r.Module__r.Module_Length_Months__c, Module_Assignment__r.Module__r.Module_Points__c,
                           Module_Assignment__r.Module__r.Module_Overview__c, Module_Assignment__r.Module__r.Module_Learning_Objectives__c,
                           Module_Assignment__r.Module__r.Publishing_Status__c, Module_Assignment__r.Module__r.Module_Status__c,
                           Module_Assignment__r.Module__r.Published_Date__c, Module_Assignment__r.Module__r.CreatedBy.Name,
                           Module_Assignment__r.Module__r.Journey__c, Module_Assignment__r.Module__r.Journey__r.Journey_Name__c
                    FROM LMS_Enrollment__c 
                    WHERE External_Resource__c = :currentContactId 
                    AND Journey__c = :journeyId
                    AND Module_Assignment__c != null
                    AND Status__c != 'Unenrolled'
                    WITH SECURITY_ENFORCED
                    ORDER BY CreatedDate ASC
                ];
            } else {
                // Non-Member Contact or No Contact: query enrollments using Employee relationship
                enrollments = [
                    SELECT Id, Journey__c, Journey__r.Id, Journey__r.Name, Journey__r.Journey_Name__c,
                           Employee__c, Employee__r.User__c, Module_Assignment__c, Module_Assignment__r.Id,
                           Module_Assignment__r.Duration__c, Module_Assignment__r.Module__c,
                           Module_Assignment__r.Module__r.Id, Module_Assignment__r.Module__r.Module_ID__c,
                           Module_Assignment__r.Module__r.Name, Module_Assignment__r.Module__r.Module_Name__c,
                           Module_Assignment__r.Module__r.Module_Badge__c, Module_Assignment__r.Module__r.Module_Level__c,
                           Module_Assignment__r.Module__r.Module_Length_Months__c, Module_Assignment__r.Module__r.Module_Points__c,
                           Module_Assignment__r.Module__r.Module_Overview__c, Module_Assignment__r.Module__r.Module_Learning_Objectives__c,
                           Module_Assignment__r.Module__r.Publishing_Status__c, Module_Assignment__r.Module__r.Module_Status__c,
                           Module_Assignment__r.Module__r.Published_Date__c, Module_Assignment__r.Module__r.CreatedBy.Name,
                           Module_Assignment__r.Module__r.Journey__c, Module_Assignment__r.Module__r.Journey__r.Journey_Name__c
                    FROM LMS_Enrollment__c 
                    WHERE Employee__r.User__c = :currentUserId 
                    AND Journey__c = :journeyId
                    AND Module_Assignment__c != null
                    AND Status__c != 'Unenrolled'
                    WITH SECURITY_ENFORCED
                    ORDER BY CreatedDate ASC
                ];
            }
            
            if (enrollments.isEmpty()) {
                CoursesData emptyCoursesData = new CoursesData();
                emptyCoursesData.isEmpty = true;
                emptyCoursesData.emptyStateMessage = 'No courses found for this journey. You may not be enrolled in any modules for this journey yet.';
                return emptyCoursesData;
            }
            
            // Get all enrollment IDs for lesson progress calculation
            Set<Id> enrollmentIds = new Set<Id>();
            Set<Id> moduleIds = new Set<Id>();
            Set<Id> journeyIds = new Set<Id>();
            Set<Id> moduleAssignmentIds = new Set<Id>();
            for (LMS_Enrollment__c enrollment : enrollments) {
                if (enrollment.Module_Assignment__c != null) {
                    enrollmentIds.add(enrollment.Id);
                    moduleIds.add(enrollment.Module_Assignment__r.Module__c);
                    journeyIds.add(enrollment.Journey__c);
                    moduleAssignmentIds.add(enrollment.Module_Assignment__c);
                }
            }
            
            // Query lesson week assignments for progress calculation
            Map<Id, List<LMS_Lesson_Week_Assignment__c>> enrollmentToLessons = new Map<Id, List<LMS_Lesson_Week_Assignment__c>>();
            if (!enrollmentIds.isEmpty()) {
                List<LMS_Lesson_Week_Assignment__c> lessonAssignments = [
                    SELECT Id, Enrollment__c, Completed__c, Lesson__c, Lesson__r.Module__c
                    FROM LMS_Lesson_Week_Assignment__c
                    WHERE Enrollment__c IN :enrollmentIds
                    WITH SECURITY_ENFORCED
                ];
                
                for (LMS_Lesson_Week_Assignment__c assignment : lessonAssignments) {
                    if (!enrollmentToLessons.containsKey(assignment.Enrollment__c)) {
                        enrollmentToLessons.put(assignment.Enrollment__c, new List<LMS_Lesson_Week_Assignment__c>());
                    }
                    enrollmentToLessons.get(assignment.Enrollment__c).add(assignment);
                }
            }
            
            // Query for trainer enrollments to get the "Designed by" information
            Map<String, String> moduleAssignmentToTrainer = new Map<String, String>();
            if (!moduleAssignmentIds.isEmpty() && !journeyIds.isEmpty()) {
                List<LMS_Enrollment__c> trainerEnrollments = [
                    SELECT Id, 
                           Journey__c,
                           Module_Assignment__c,
                           Employee__c,
                           Employee__r.Name,
                           Enrollment_Role__c
                    FROM LMS_Enrollment__c
                    WHERE Journey__c IN :journeyIds
                    AND Module_Assignment__c IN :moduleAssignmentIds
                    AND Enrollment_Role__c = 'Trainer'
                    WITH SECURITY_ENFORCED
                ];
                
                for (LMS_Enrollment__c trainerEnrollment : trainerEnrollments) {
                    String key = String.valueOf(trainerEnrollment.Journey__c) + '_' + String.valueOf(trainerEnrollment.Module_Assignment__c);
                    moduleAssignmentToTrainer.put(key, trainerEnrollment.Employee__r.Name);
                }
            }
            
            // Query total lessons per module for progress calculation
            Map<Id, Integer> moduleTotalLessons = new Map<Id, Integer>();
            if (!moduleIds.isEmpty()) {
                AggregateResult[] lessonCounts = [
                    SELECT Module__c, COUNT(Id) lessonCount
                    FROM LMS_Lesson__c
                    WHERE Module__c IN :moduleIds
                    WITH SECURITY_ENFORCED
                    GROUP BY Module__c
                ];
                
                for (AggregateResult ar : lessonCounts) {
                    moduleTotalLessons.put((Id)ar.get('Module__c'), (Integer)ar.get('lessonCount'));
                }
            }
            
            // Create courses data response
            CoursesData coursesData = new CoursesData();
            coursesData.courses = new List<CourseData>();
            
            // Convert enrollments with module assignments to CourseData
            for (LMS_Enrollment__c enrollment : enrollments) {
                if (enrollment.Module_Assignment__c == null) {
                    continue;
                }
                
                LMS_Module_Assignment__c assignment = enrollment.Module_Assignment__r;
                LMS_Module__c module = assignment.Module__r;
                
                // Calculate lesson progress for this enrollment
                Integer completedLessons = 0;
                Integer totalLessons = 0;
                
                List<LMS_Lesson_Week_Assignment__c> assignments = enrollmentToLessons.get(enrollment.Id);
                
                if (assignments != null) {
                    totalLessons = assignments.size();
                    for (LMS_Lesson_Week_Assignment__c lessonAssignment : assignments) {
                        if (lessonAssignment.Completed__c == true) {
                            completedLessons++;
                        }
                    }
                } else {
                    // If no lesson assignments, use total module lessons
                    totalLessons = moduleTotalLessons.get(module.Id) != null ? 
                                  moduleTotalLessons.get(module.Id) : 0;
                }
                
                CourseData courseData = new CourseData();
                courseData.id = module.Id;
                courseData.moduleCode = module.Module_ID__c;
                courseData.title = module.Module_Name__c != null ? module.Module_Name__c : module.Name;
                courseData.description = module.Module_Overview__c;
                
                // Use Module_Level__c for tags
                List<String> tags = new List<String>();
                if (String.isNotBlank(module.Module_Level__c)) {
                    tags.add(module.Module_Level__c);
                }
                courseData.tags = tags;
                
                // Set duration using the Duration__c formula field from Module Assignment
                courseData.duration = assignment.Duration__c != null ? String.valueOf(assignment.Duration__c) + ' weeks' : '';
                courseData.points = module.Module_Points__c != null ? String.valueOf(Integer.valueOf(module.Module_Points__c)) : '0';
                
                // Get trainer name as designer
                String trainerKey = String.valueOf(enrollment.Journey__c) + '_' + String.valueOf(enrollment.Module_Assignment__c);
                String trainerName = moduleAssignmentToTrainer.get(trainerKey);
                courseData.designer = String.isNotBlank(trainerName) ? trainerName : 
                                    (String.isNotBlank(module.CreatedBy.Name) ? module.CreatedBy.Name : 'Unknown');
                
                // Show actual lesson progress
                courseData.progress = completedLessons + '/' + totalLessons;
                
                courseData.comments = '0'; // Default, could be from related records
                courseData.edits = '0'; // Default, could be from related records
                courseData.selected = false; // Default to not selected
                courseData.status = determineModuleStatus(module);
                courseData.journeyName = module.Journey__r.Journey_Name__c;
                courseData.badge = module.Module_Badge__c; // Rich text field containing badge image
                
                // Add assignment and enrollment information
                courseData.assignmentId = assignment.Id;
                courseData.enrollmentId = enrollment.Id;
                
                coursesData.courses.add(courseData);
            }
            
            // Set first course as selected by default
            if (!coursesData.courses.isEmpty()) {
                coursesData.courses[0].selected = true;
            }
            
            return coursesData;
            
        } catch (Exception e) {
            System.debug('Error in getCoursesData: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving courses data: ' + e.getMessage());
        }
    }
    
    @TestVisible private static String determineModuleStatus(LMS_Module__c module) {
        // Same logic as JourneyOverviewController
        if (module.Module_Status__c == 'Active' && module.Publishing_Status__c == 'Published') {
            return 'Available';
        } else if (module.Module_Status__c == 'Active') {
            return 'Coming Soon';
        } else if (module.Module_Status__c == 'Inactive') {
            return 'Unavailable';
        } else if (module.Module_Status__c == 'Archived') {
            return 'Archived';
        } else {
            return 'Coming Soon';
        }
    }
    
    @TestVisible private static String formatDuration(Decimal lengthMonths) {
        if (lengthMonths == null) {
            return '1 hour';
        }
        
        // Convert months to approximate hours (assuming 40 hours per month)
        Integer hours = Integer.valueOf(lengthMonths * 40);
        
        if (hours < 1) {
            return '30 minutes';
        } else if (hours == 1) {
            return '1 hour';
        } else {
            return hours + ' hours';
        }
    }
    
    // Wrapper classes for data structure
    public class CoursesData {
        @AuraEnabled public List<CourseData> courses { get; set; }
        @AuraEnabled public Boolean isEmpty { get; set; }
        @AuraEnabled public String emptyStateMessage { get; set; }
        
        public CoursesData() {
            this.courses = new List<CourseData>();
            this.isEmpty = false;
        }
    }
    
    public class CourseData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String moduleCode { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public List<String> tags { get; set; }
        @AuraEnabled public String duration { get; set; }
        @AuraEnabled public String points { get; set; }
        @AuraEnabled public String designer { get; set; }
        @AuraEnabled public String progress { get; set; }
        @AuraEnabled public String comments { get; set; }
        @AuraEnabled public String edits { get; set; }
        @AuraEnabled public Boolean selected { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String journeyName { get; set; }
        @AuraEnabled public Id assignmentId { get; set; }
        @AuraEnabled public Id enrollmentId { get; set; }
        @AuraEnabled public String badge { get; set; }
    }
    
    public class JourneyOption {
        @AuraEnabled public Id value { get; set; }
        @AuraEnabled public String label { get; set; }
    }
}