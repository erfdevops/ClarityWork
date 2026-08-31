public without sharing class LMSEnrollmentDateHandler {
    
    /**
     * Validates that enrollment dates fall within the module assignment date range
     * @param enrollments List of enrollments to validate
     */
    public static void validateEnrollmentDates(List<LMS_Enrollment__c> enrollments) {
        
        // Collect module assignment IDs
        Set<Id> moduleAssignmentIds = collectModuleAssignmentIds(enrollments);
        
        if (moduleAssignmentIds.isEmpty()) {
            return;
        }
        
        // Query module assignments with their date ranges
        Map<Id, LMS_Module_Assignment__c> moduleAssignmentMap = queryModuleAssignments(moduleAssignmentIds);
        
        // Validate each enrollment against its module assignment dates
        validateDateRanges(enrollments, moduleAssignmentMap);
    }
    
    /**
     * Collects unique module assignment IDs from enrollments
     */
    private static Set<Id> collectModuleAssignmentIds(List<LMS_Enrollment__c> enrollments) {
        Set<Id> moduleAssignmentIds = new Set<Id>();
        for (LMS_Enrollment__c enrollment : enrollments) {
            if (enrollment.Module_Assignment__c != null) {
                moduleAssignmentIds.add(enrollment.Module_Assignment__c);
            }
        }
        return moduleAssignmentIds;
    }
    
    /**
     * Queries module assignments with their start and end dates
     */
    private static Map<Id, LMS_Module_Assignment__c> queryModuleAssignments(Set<Id> moduleAssignmentIds) {
        Map<Id, LMS_Module_Assignment__c> moduleAssignmentMap = new Map<Id, LMS_Module_Assignment__c>();
        
        List<LMS_Module_Assignment__c> moduleAssignments = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM LMS_Module_Assignment__c
            WHERE Id IN :moduleAssignmentIds
            WITH SECURITY_ENFORCED
        ];
        
        for (LMS_Module_Assignment__c moduleAssignment : moduleAssignments) {
            moduleAssignmentMap.put(moduleAssignment.Id, moduleAssignment);
        }
        
        return moduleAssignmentMap;
    }
    
    /**
     * Validates enrollment dates against module assignment date ranges
     */
    private static void validateDateRanges(List<LMS_Enrollment__c> enrollments, Map<Id, LMS_Module_Assignment__c> moduleAssignmentMap) {
        for (LMS_Enrollment__c enrollment : enrollments) {
            LMS_Module_Assignment__c moduleAssignment = moduleAssignmentMap.get(enrollment.Module_Assignment__c);
            
            if (moduleAssignment != null) {
                validateEnrollmentAgainstModuleAssignment(enrollment, moduleAssignment);
            }
        }
    }
    
    /**
     * Validates a single enrollment against its module assignment dates
     */
    private static void validateEnrollmentAgainstModuleAssignment(LMS_Enrollment__c enrollment, LMS_Module_Assignment__c moduleAssignment) {
        Date enrollmentStartDate = enrollment.Start_Date__c;
        Date enrollmentEndDate = enrollment.End_Date__c;
        Date moduleStartDate = moduleAssignment.Start_Date__c;
        Date moduleEndDate = moduleAssignment.End_Date__c;
        
        // Check if module assignment has valid date range
        if (moduleStartDate == null || moduleEndDate == null) {
            enrollment.addError('The related Module Assignment must have valid Start and End dates.');
            return;
        }
        
        // Validate enrollment start date
        if (enrollmentStartDate < moduleStartDate) {
            enrollment.Start_Date__c.addError(
                'Enrollment start date (' + enrollmentStartDate.format() + ') cannot be before the Module Assignment start date (' + moduleStartDate.format() + ').'
            );
        }
        
        if (enrollmentStartDate > moduleEndDate) {
            enrollment.Start_Date__c.addError(
                'Enrollment start date (' + enrollmentStartDate.format() + ') cannot be after the Module Assignment end date (' + moduleEndDate.format() + ').'
            );
        }
        
        // Validate enrollment end date
        if (enrollmentEndDate < moduleStartDate) {
            enrollment.End_Date__c.addError(
                'Enrollment end date (' + enrollmentEndDate.format() + ') cannot be before the Module Assignment start date (' + moduleStartDate.format() + ').'
            );
        }
        
        if (enrollmentEndDate > moduleEndDate) {
            enrollment.End_Date__c.addError(
                'Enrollment end date (' + enrollmentEndDate.format() + ') cannot be after the Module Assignment end date (' + moduleEndDate.format() + ').'
            );
        }
        
        // Validate that enrollment start date is not after enrollment end date
        if (enrollmentStartDate > enrollmentEndDate) {
            enrollment.Start_Date__c.addError(
                'Enrollment start date (' + enrollmentStartDate.format() + ') cannot be after the enrollment end date (' + enrollmentEndDate.format() + ').'
            );
        }
    }
    
    /**
     * Validates that there are no duplicate enrollments for the same Employee, Module Assignment, and dates
     * @param enrollments List of enrollments to validate
     */
    public static void validateNoDuplicateEnrollments(List<LMS_Enrollment__c> enrollments) {
        // Collect employee IDs and module assignment IDs
        Set<Id> employeeIds = new Set<Id>();
        Set<Id> moduleAssignmentIds = new Set<Id>();
        Map<Id, LMS_Enrollment__c> enrollmentMap = new Map<Id, LMS_Enrollment__c>();
        
        for (LMS_Enrollment__c enrollment : enrollments) {
            if (enrollment.Employee__c != null && enrollment.Module_Assignment__c != null) {
                employeeIds.add(enrollment.Employee__c);
                moduleAssignmentIds.add(enrollment.Module_Assignment__c);
                enrollmentMap.put(enrollment.Id, enrollment);
            }
        }
        
        if (employeeIds.isEmpty() || moduleAssignmentIds.isEmpty()) {
            return;
        }
        
        // Query existing enrollments that match the criteria
        Set<String> newEnrollmentKeys = new Set<String>();
        for (LMS_Enrollment__c enrollment : enrollments) {
            if (enrollment.Employee__c != null && enrollment.Module_Assignment__c != null) {
                String key = createEnrollmentKey(
                    enrollment.Employee__c,
                    enrollment.Module_Assignment__c,
                    enrollment.Start_Date__c,
                    enrollment.End_Date__c
                );
                newEnrollmentKeys.add(key);
            }
        }
        
        // Query existing enrollments with matching Employee and Module Assignment
        List<LMS_Enrollment__c> existingEnrollments = [
            SELECT Id, Employee__c, Module_Assignment__c, Start_Date__c, End_Date__c
            FROM LMS_Enrollment__c
            WHERE Employee__c IN :employeeIds 
            AND Module_Assignment__c IN :moduleAssignmentIds
            WITH SECURITY_ENFORCED
        ];
        
        // Check for duplicates
        for (LMS_Enrollment__c newEnrollment : enrollments) {
            if (newEnrollment.Employee__c != null && newEnrollment.Module_Assignment__c != null) {
                String newKey = createEnrollmentKey(
                    newEnrollment.Employee__c,
                    newEnrollment.Module_Assignment__c,
                    newEnrollment.Start_Date__c,
                    newEnrollment.End_Date__c
                );
                
                // Check against existing enrollments
                for (LMS_Enrollment__c existingEnrollment : existingEnrollments) {
                    // Skip if it's the same record (for updates)
                    if (existingEnrollment.Id == newEnrollment.Id) {
                        continue;
                    }
                    
                    String existingKey = createEnrollmentKey(
                        existingEnrollment.Employee__c,
                        existingEnrollment.Module_Assignment__c,
                        existingEnrollment.Start_Date__c,
                        existingEnrollment.End_Date__c
                    );
                    
                    if (newKey == existingKey) {
                        newEnrollment.addError(
                            'A duplicate enrollment already exists for this Employee, Module Assignment, and date range. ' +
                            'Employee: ' + newEnrollment.Employee__c + ', Module Assignment: ' + newEnrollment.Module_Assignment__c + '. ' +
                            'Please check existing enrollments before creating a new one.'
                        );
                        break;
                    }
                }
            }
        }
    }
    

    private static String createEnrollmentKey(Id employeeId, Id moduleAssignmentId, Date startDate, Date endDate) {
        return employeeId + '|' + moduleAssignmentId + '|' + 
               (startDate != null ? String.valueOf(startDate) : 'null') + '|' + 
               (endDate != null ? String.valueOf(endDate) : 'null');
    }
}