/**
 * Handler class for LMS_Enrollment__c trigger
 * Manages Learner_Portfolio__c records creation and updates
 */
public without sharing class LMSEnrollmentPortfolioTriggerHandler {
    
    /**
     * Handles after insert logic
     * Creates Learner Portfolio record if one doesn't exist for the Contact/Employee
     * @param newEnrollments List of newly inserted enrollments
     * @param isInsert Boolean flag to indicate insert context
     */
    public static void handleAfterInsert(List<LMS_Enrollment__c> newEnrollments, Boolean isInsert) {
        if (!isInsert) {
            return;
        }
        
        // Collect unique Contact and Employee IDs
        Set<Id> contactIds = new Set<Id>();
        Set<Id> employeeIds = new Set<Id>();
        Map<Id, Id> contactToJourneyMap = new Map<Id, Id>();
        Map<Id, Id> employeeToJourneyMap = new Map<Id, Id>();
        
        for (LMS_Enrollment__c enrollment : newEnrollments) {
            if (enrollment.External_Resource__c != null) {
                contactIds.add(enrollment.External_Resource__c);
                // Store the journey for this contact (use first journey found)
                if (!contactToJourneyMap.containsKey(enrollment.External_Resource__c) && enrollment.Journey__c != null) {
                    contactToJourneyMap.put(enrollment.External_Resource__c, enrollment.Journey__c);
                }
            }
            if (enrollment.Employee__c != null) {
                employeeIds.add(enrollment.Employee__c);
                // Store the journey for this employee (use first journey found)
                if (!employeeToJourneyMap.containsKey(enrollment.Employee__c) && enrollment.Journey__c != null) {
                    employeeToJourneyMap.put(enrollment.Employee__c, enrollment.Journey__c);
                }
            }
        }
        
        // Query existing Learner Portfolio records
        Set<Id> existingPortfolioContacts = new Set<Id>();
        Set<Id> existingPortfolioEmployees = new Set<Id>();
        
        List<Learner_Portfolio__c> existingPortfolios = [
            SELECT Id, Contact__c, Employee__c
            FROM Learner_Portfolio__c
            WHERE Contact__c IN :contactIds
            OR Employee__c IN :employeeIds
        ];
        
        for (Learner_Portfolio__c portfolio : existingPortfolios) {
            if (portfolio.Contact__c != null) {
                existingPortfolioContacts.add(portfolio.Contact__c);
            }
            if (portfolio.Employee__c != null) {
                existingPortfolioEmployees.add(portfolio.Employee__c);
            }
        }
        
        // Create new Learner Portfolio records for enrollments without one
        List<Learner_Portfolio__c> portfoliosToCreate = new List<Learner_Portfolio__c>();
        
        for (LMS_Enrollment__c enrollment : newEnrollments) {
            Boolean needsPortfolio = false;
            
            // Check if Contact needs a portfolio
            if (enrollment.External_Resource__c != null && 
                !existingPortfolioContacts.contains(enrollment.External_Resource__c)) {
                needsPortfolio = true;
                existingPortfolioContacts.add(enrollment.External_Resource__c); // Prevent duplicates in same batch
            }
            
            // Check if Employee needs a portfolio
            if (enrollment.Employee__c != null && 
                !existingPortfolioEmployees.contains(enrollment.Employee__c)) {
                needsPortfolio = true;
                existingPortfolioEmployees.add(enrollment.Employee__c); // Prevent duplicates in same batch
            }
            
            if (needsPortfolio) {
                Learner_Portfolio__c newPortfolio = new Learner_Portfolio__c();
                newPortfolio.Contact__c = enrollment.External_Resource__c;
                newPortfolio.Employee__c = enrollment.Employee__c;
                newPortfolio.Journey__c = enrollment.Journey__c;
                newPortfolio.Journey_Status__c = 'In Progress';
                
                portfoliosToCreate.add(newPortfolio);
            }
        }
        
        // Insert new portfolios
        if (!portfoliosToCreate.isEmpty()) {
            try {
                insert portfoliosToCreate;
                System.debug('Created ' + portfoliosToCreate.size() + ' new Learner Portfolio records');
            } catch (DmlException e) {
                System.debug('Error creating Learner Portfolio records: ' + e.getMessage());
                throw e;
            }
        }
    }
    
    /**
     * Handles after update logic
     * Checks if all enrollments are completed and updates Learner Portfolio status
     * @param newEnrollments List of updated enrollments
     * @param oldEnrollmentMap Map of old enrollment values
     * @param isUpdate Boolean flag to indicate update context
     */
    public static void handleAfterUpdate(List<LMS_Enrollment__c> newEnrollments, Map<Id, LMS_Enrollment__c> oldEnrollmentMap, Boolean isUpdate) {
        if (!isUpdate) {
            return;
        }
        
        // Collect enrollments that changed to Completed
        Set<Id> contactIdsToCheck = new Set<Id>();
        Set<Id> employeeIdsToCheck = new Set<Id>();
        
        for (LMS_Enrollment__c newEnrollment : newEnrollments) {
            LMS_Enrollment__c oldEnrollment = oldEnrollmentMap.get(newEnrollment.Id);
            
            // Check if status changed to Completed
            if (newEnrollment.Status__c == 'Completed' && oldEnrollment.Status__c != 'Completed') {
                if (newEnrollment.External_Resource__c != null) {
                    contactIdsToCheck.add(newEnrollment.External_Resource__c);
                }
                if (newEnrollment.Employee__c != null) {
                    employeeIdsToCheck.add(newEnrollment.Employee__c);
                }
            }
        }
        
        // If no enrollments were marked as completed, exit
        if (contactIdsToCheck.isEmpty() && employeeIdsToCheck.isEmpty()) {
            return;
        }
        
        // Query all enrollments for these contacts/employees
        List<LMS_Enrollment__c> allEnrollments = [
            SELECT Id, Status__c, External_Resource__c, Employee__c
            FROM LMS_Enrollment__c
            WHERE External_Resource__c IN :contactIdsToCheck
            OR Employee__c IN :employeeIdsToCheck
        ];
        
        // Group enrollments by Contact and Employee
        Map<Id, List<LMS_Enrollment__c>> enrollmentsByContact = new Map<Id, List<LMS_Enrollment__c>>();
        Map<Id, List<LMS_Enrollment__c>> enrollmentsByEmployee = new Map<Id, List<LMS_Enrollment__c>>();
        
        for (LMS_Enrollment__c enrollment : allEnrollments) {
            if (enrollment.External_Resource__c != null) {
                if (!enrollmentsByContact.containsKey(enrollment.External_Resource__c)) {
                    enrollmentsByContact.put(enrollment.External_Resource__c, new List<LMS_Enrollment__c>());
                }
                enrollmentsByContact.get(enrollment.External_Resource__c).add(enrollment);
            }
            
            if (enrollment.Employee__c != null) {
                if (!enrollmentsByEmployee.containsKey(enrollment.Employee__c)) {
                    enrollmentsByEmployee.put(enrollment.Employee__c, new List<LMS_Enrollment__c>());
                }
                enrollmentsByEmployee.get(enrollment.Employee__c).add(enrollment);
            }
        }
        
        // Determine which contacts/employees have all enrollments completed
        Set<Id> completedContactIds = new Set<Id>();
        Set<Id> completedEmployeeIds = new Set<Id>();
        
        // Check contacts
        for (Id contactId : enrollmentsByContact.keySet()) {
            Boolean allCompleted = true;
            for (LMS_Enrollment__c enrollment : enrollmentsByContact.get(contactId)) {
                if (enrollment.Status__c != 'Completed') {
                    allCompleted = false;
                    break;
                }
            }
            if (allCompleted) {
                completedContactIds.add(contactId);
            }
        }
        
        // Check employees
        for (Id employeeId : enrollmentsByEmployee.keySet()) {
            Boolean allCompleted = true;
            for (LMS_Enrollment__c enrollment : enrollmentsByEmployee.get(employeeId)) {
                if (enrollment.Status__c != 'Completed') {
                    allCompleted = false;
                    break;
                }
            }
            if (allCompleted) {
                completedEmployeeIds.add(employeeId);
            }
        }
        
        // Query and update Learner Portfolio records
        List<Learner_Portfolio__c> portfoliosToUpdate = [
            SELECT Id, Journey_Status__c, Contact__c, Employee__c
            FROM Learner_Portfolio__c
            WHERE Contact__c IN :completedContactIds
            OR Employee__c IN :completedEmployeeIds
        ];
        
        for (Learner_Portfolio__c portfolio : portfoliosToUpdate) {
            // Only update if not already completed
            if (portfolio.Journey_Status__c != 'Completed') {
                portfolio.Journey_Status__c = 'Completed';
            }
        }
        
        // Update portfolios
        if (!portfoliosToUpdate.isEmpty()) {
            try {
                update portfoliosToUpdate;
                System.debug('Updated ' + portfoliosToUpdate.size() + ' Learner Portfolio records to Completed status');
            } catch (DmlException e) {
                System.debug('Error updating Learner Portfolio records: ' + e.getMessage());
                throw e;
            }
        }
    }
}