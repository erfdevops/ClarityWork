public without sharing class LMSLessonDateHandler {
    
    /**
     * Validates that lesson week assignment dates fall within the enrollment date range
     * @param lessonAssignments List of lesson week assignments to validate
     */
    public static void validateLessonDates(List<LMS_Lesson_Week_Assignment__c> lessonAssignments) {
        
        // Collect enrollment IDs
        Set<Id> enrollmentIds = collectEnrollmentIds(lessonAssignments);
        
        if (enrollmentIds.isEmpty()) {
            return;
        }
        
        // Query enrollments with their date ranges
        Map<Id, LMS_Enrollment__c> enrollmentMap = queryEnrollments(enrollmentIds);
        
        // Validate each lesson assignment against its enrollment dates
        validateDateRanges(lessonAssignments, enrollmentMap);
    }
    
    /**
     * Collects unique enrollment IDs from lesson week assignments
     */
    private static Set<Id> collectEnrollmentIds(List<LMS_Lesson_Week_Assignment__c> lessonAssignments) {
        Set<Id> enrollmentIds = new Set<Id>();
        for (LMS_Lesson_Week_Assignment__c assignment : lessonAssignments) {
            if (assignment.Enrollment__c != null) {
                enrollmentIds.add(assignment.Enrollment__c);
            }
        }
        return enrollmentIds;
    }
    
    /**
     * Queries enrollments with their start and end dates
     */
    private static Map<Id, LMS_Enrollment__c> queryEnrollments(Set<Id> enrollmentIds) {
        Map<Id, LMS_Enrollment__c> enrollmentMap = new Map<Id, LMS_Enrollment__c>();
        
        List<LMS_Enrollment__c> enrollments = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM LMS_Enrollment__c
            WHERE Id IN :enrollmentIds
            WITH SECURITY_ENFORCED
        ];
        
        for (LMS_Enrollment__c enrollment : enrollments) {
            enrollmentMap.put(enrollment.Id, enrollment);
        }
        
        return enrollmentMap;
    }
    
    /**
     * Validates lesson assignment dates against enrollment date ranges
     */
    private static void validateDateRanges(List<LMS_Lesson_Week_Assignment__c> lessonAssignments, Map<Id, LMS_Enrollment__c> enrollmentMap) {
        for (LMS_Lesson_Week_Assignment__c lessonAssignment : lessonAssignments) {
            LMS_Enrollment__c enrollment = enrollmentMap.get(lessonAssignment.Enrollment__c);
            
            if (enrollment != null) {
                validateLessonAgainstEnrollment(lessonAssignment, enrollment);
            }
        }
    }
    
    /**
     * Validates a single lesson assignment against its enrollment dates
     */
    private static void validateLessonAgainstEnrollment(LMS_Lesson_Week_Assignment__c lessonAssignment, LMS_Enrollment__c enrollment) {
        Date lessonStartDate = lessonAssignment.Start_Date__c;
        Date lessonEndDate = lessonAssignment.End_Date__c;
        Date enrollmentStartDate = enrollment.Start_Date__c;
        Date enrollmentEndDate = enrollment.End_Date__c;
        
        // Check if enrollment has valid date range
        if (enrollmentStartDate == null || enrollmentEndDate == null) {
            lessonAssignment.addError('The related Enrollment must have valid Start and End dates.');
            return;
        }
        
        // Validate lesson start date
        if (lessonStartDate < enrollmentStartDate) {
            lessonAssignment.Start_Date__c.addError(
                'Lesson start date (' + lessonStartDate.format() + ') cannot be before the Enrollment start date (' + enrollmentStartDate.format() + ').'
            );
        }
        
        if (lessonStartDate > enrollmentEndDate) {
            lessonAssignment.Start_Date__c.addError(
                'Lesson start date (' + lessonStartDate.format() + ') cannot be after the Enrollment end date (' + enrollmentEndDate.format() + ').'
            );
        }
        
        // Validate lesson end date
        if (lessonEndDate < enrollmentStartDate) {
            lessonAssignment.End_Date__c.addError(
                'Lesson end date (' + lessonEndDate.format() + ') cannot be before the Enrollment start date (' + enrollmentStartDate.format() + ').'
            );
        }
        
        if (lessonEndDate > enrollmentEndDate) {
            lessonAssignment.End_Date__c.addError(
                'Lesson end date (' + lessonEndDate.format() + ') cannot be after the Enrollment end date (' + enrollmentEndDate.format() + ').'
            );
        }
        
        // Validate that lesson start date is not after lesson end date
        if (lessonStartDate > lessonEndDate) {
            lessonAssignment.Start_Date__c.addError(
                'Lesson start date (' + lessonStartDate.format() + ') cannot be after the lesson end date (' + lessonEndDate.format() + ').'
            );
        }
    }
}