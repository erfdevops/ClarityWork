public without sharing class LMSEnrollmentTriggerHandler {
    
    public static void handleNewEnrollments(List<LMS_Enrollment__c> newEnrollments) {
        // Filter enrollments that have a module assignment
        List<LMS_Enrollment__c> enrollmentsWithModules = new List<LMS_Enrollment__c>();
        
        for (LMS_Enrollment__c enrollment : newEnrollments) {
            if (enrollment.Module_Assignment__c != null) {
                enrollmentsWithModules.add(enrollment);
            }
        }
        
        if (!enrollmentsWithModules.isEmpty()) {
            createLessonWeekAssignments(enrollmentsWithModules);
        }
    }
    
    private static void createLessonWeekAssignments(List<LMS_Enrollment__c> enrollments) {
        // Collect module assignment IDs
        Set<Id> moduleAssignmentIds = collectModuleAssignmentIds(enrollments);
        
        // Get module assignments with their module relationships
        Map<Id, LMS_Module_Assignment__c> moduleAssignmentMap = queryModuleAssignments(moduleAssignmentIds);
        
        // Get all lessons for these modules
        Map<Id, List<LMS_Lesson__c>> moduleToLessons = queryModuleLessons(moduleAssignmentMap);
        
        // Create lesson week assignments
        List<LMS_Lesson_Week_Assignment__c> assignmentsToCreate = buildLessonAssignments(enrollments, moduleAssignmentMap, moduleToLessons);
        
        // Insert assignments
        insertLessonAssignments(assignmentsToCreate);
    }
    
    private static Set<Id> collectModuleAssignmentIds(List<LMS_Enrollment__c> enrollments) {
        Set<Id> moduleAssignmentIds = new Set<Id>();
        for (LMS_Enrollment__c enrollment : enrollments) {
            moduleAssignmentIds.add(enrollment.Module_Assignment__c);
        }
        return moduleAssignmentIds;
    }
    
    private static Map<Id, LMS_Module_Assignment__c> queryModuleAssignments(Set<Id> moduleAssignmentIds) {
        if (!Schema.sObjectType.LMS_Module_Assignment__c.isAccessible()) {
            throw new SecurityException('Insufficient access to LMS_Module_Assignment__c');
        }
        
        return new Map<Id, LMS_Module_Assignment__c>([
            SELECT Id, Module__c, Enrollment__c
            FROM LMS_Module_Assignment__c
            WHERE Id IN :moduleAssignmentIds
        ]);
    }
    
    private static Map<Id, List<LMS_Lesson__c>> queryModuleLessons(Map<Id, LMS_Module_Assignment__c> moduleAssignmentMap) {
        // Collect module IDs
        Set<Id> moduleIds = new Set<Id>();
        for (LMS_Module_Assignment__c moduleAssignment : moduleAssignmentMap.values()) {
            if (moduleAssignment.Module__c != null) {
                moduleIds.add(moduleAssignment.Module__c);
            }
        }
        
        Map<Id, List<LMS_Lesson__c>> moduleToLessons = new Map<Id, List<LMS_Lesson__c>>();
        if (!moduleIds.isEmpty()) {
            if (!Schema.sObjectType.LMS_Lesson__c.isAccessible()) {
                throw new SecurityException('Insufficient access to LMS_Lesson__c');
            }
            
            List<LMS_Lesson__c> lessons = [
                SELECT Id, Module__c, Name, Week__c, Lesson_Overview__c
                FROM LMS_Lesson__c
                WHERE Module__c IN :moduleIds
                ORDER BY Week__c ASC
            ];
            
            for (LMS_Lesson__c lesson : lessons) {
                if (!moduleToLessons.containsKey(lesson.Module__c)) {
                    moduleToLessons.put(lesson.Module__c, new List<LMS_Lesson__c>());
                }
                moduleToLessons.get(lesson.Module__c).add(lesson);
            }
        }
        return moduleToLessons;
    }
    
    private static List<LMS_Lesson_Week_Assignment__c> buildLessonAssignments(
        List<LMS_Enrollment__c> enrollments, 
        Map<Id, LMS_Module_Assignment__c> moduleAssignmentMap, 
        Map<Id, List<LMS_Lesson__c>> moduleToLessons
    ) {
        List<LMS_Lesson_Week_Assignment__c> assignmentsToCreate = new List<LMS_Lesson_Week_Assignment__c>();
        
        for (LMS_Enrollment__c enrollment : enrollments) {
            LMS_Module_Assignment__c moduleAssignment = moduleAssignmentMap.get(enrollment.Module_Assignment__c);
            if (moduleAssignment != null && moduleAssignment.Module__c != null) {
                List<LMS_Lesson__c> moduleLessons = moduleToLessons.get(moduleAssignment.Module__c);
                
                if (moduleLessons != null) {
                    Integer weekCounter = 1; // Sequential week counter starting from 1
                    
                    for (LMS_Lesson__c lesson : moduleLessons) {
                        assignmentsToCreate.add(new LMS_Lesson_Week_Assignment__c(
                            Lesson__c = lesson.Id,
                            Enrollment__c = enrollment.Id,
                            Module_Assignment__c = enrollment.Module_Assignment__c,
                            Status__c = 'Not Started',
                            Start_Date__c = enrollment.Start_Date__c,
                            End_Date__c = enrollment.End_Date__c,
                            Lesson_Due_Week__c = String.valueOf(weekCounter++), // Sequential: '1', '2', '3', etc.
                            Completed__c = false
                        ));
                    }
                }
            }
        }
        return assignmentsToCreate;
    }
    
    private static void insertLessonAssignments(List<LMS_Lesson_Week_Assignment__c> assignmentsToCreate) {
        if (!assignmentsToCreate.isEmpty()) {
            if (!Schema.sObjectType.LMS_Lesson_Week_Assignment__c.isCreateable()) {
                throw new SecurityException('Insufficient access to create LMS_Lesson_Week_Assignment__c');
            }
            insert assignmentsToCreate;
        }
    }

    /**
     * When an enrollment's Status__c changes to 'Unenrolled', sets all related
     * LMS_Lesson_Week_Assignment__c records to Status__c = 'Unenrolled' as well.
     * @param newEnrollments Trigger.new
     * @param oldEnrollmentMap Trigger.oldMap
     */
    public static void handleUnenrolledEnrollments(
        List<LMS_Enrollment__c> newEnrollments,
        Map<Id, LMS_Enrollment__c> oldEnrollmentMap
    ) {
        Set<Id> unenrolledIds = new Set<Id>();

        for (LMS_Enrollment__c enrollment : newEnrollments) {
            LMS_Enrollment__c oldEnrollment = oldEnrollmentMap.get(enrollment.Id);
            if (enrollment.Status__c == 'Unenrolled' && oldEnrollment.Status__c != 'Unenrolled') {
                unenrolledIds.add(enrollment.Id);
            }
        }

        if (unenrolledIds.isEmpty()) {
            return;
        }

        List<LMS_Lesson_Week_Assignment__c> assignmentsToUpdate = [
            SELECT Id, Status__c
            FROM LMS_Lesson_Week_Assignment__c
            WHERE Enrollment__c IN :unenrolledIds
            AND Status__c != 'Unenrolled'
        ];

        for (LMS_Lesson_Week_Assignment__c assignment : assignmentsToUpdate) {
            assignment.Status__c = 'Unenrolled';
        }

        if (!assignmentsToUpdate.isEmpty()) {
            update assignmentsToUpdate;
        }
    }

    public class SecurityException extends Exception {}
}