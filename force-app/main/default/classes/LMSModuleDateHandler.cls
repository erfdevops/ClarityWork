public without sharing class LMSModuleDateHandler {
    
    /**
     * Validates that module assignment dates fall within the journey date range
     * @param moduleAssignments List of module assignments to validate
     */
    public static void validateModuleDates(List<LMS_Module_Assignment__c> moduleAssignments) {
        
        // Collect journey IDs
        Set<Id> journeyIds = collectJourneyIds(moduleAssignments);
        
        if (journeyIds.isEmpty()) {
            return;
        }
        
        // Query journeys with their date ranges
        Map<Id, LMS_Journey__c> journeyMap = queryJourneys(journeyIds);
        
        // Validate each module assignment against its journey dates
        validateDateRanges(moduleAssignments, journeyMap);
    }
    
    /**
     * Collects unique journey IDs from module assignments
     */
    private static Set<Id> collectJourneyIds(List<LMS_Module_Assignment__c> moduleAssignments) {
        Set<Id> journeyIds = new Set<Id>();
        for (LMS_Module_Assignment__c assignment : moduleAssignments) {
            if (assignment.Journey__c != null) {
                journeyIds.add(assignment.Journey__c);
            }
        }
        return journeyIds;
    }
    
    /**
     * Queries journeys with their start and end dates
     */
    private static Map<Id, LMS_Journey__c> queryJourneys(Set<Id> journeyIds) {
        Map<Id, LMS_Journey__c> journeyMap = new Map<Id, LMS_Journey__c>();
        
        List<LMS_Journey__c> journeys = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM LMS_Journey__c
            WHERE Id IN :journeyIds
            WITH SECURITY_ENFORCED
        ];
        
        for (LMS_Journey__c journey : journeys) {
            journeyMap.put(journey.Id, journey);
        }
        
        return journeyMap;
    }
    
    /**
     * Validates module assignment dates against journey date ranges
     */
    private static void validateDateRanges(List<LMS_Module_Assignment__c> moduleAssignments, Map<Id, LMS_Journey__c> journeyMap) {
        for (LMS_Module_Assignment__c moduleAssignment : moduleAssignments) {
            LMS_Journey__c journey = journeyMap.get(moduleAssignment.Journey__c);
            
            if (journey != null) {
                validateModuleAgainstJourney(moduleAssignment, journey);
            }
        }
    }
    
    /**
     * Validates a single module assignment against its journey dates
     */
    private static void validateModuleAgainstJourney(LMS_Module_Assignment__c moduleAssignment, LMS_Journey__c journey) {
        Date moduleStartDate = moduleAssignment.Start_Date__c;
        Date moduleEndDate = moduleAssignment.End_Date__c;
        Date journeyStartDate = journey.Start_Date__c;
        Date journeyEndDate = journey.End_Date__c;
        
        // Check if journey has valid date range
        if (journeyStartDate == null || journeyEndDate == null) {
            moduleAssignment.addError('The related Journey must have valid Start and End dates.');
            return;
        }
        
        // Validate module start date
        if (moduleStartDate < journeyStartDate) {
            moduleAssignment.Start_Date__c.addError(
                'Module start date (' + moduleStartDate.format() + ') cannot be before the Journey start date (' + journeyStartDate.format() + ').'
            );
        }
        
        if (moduleStartDate > journeyEndDate) {
            moduleAssignment.Start_Date__c.addError(
                'Module start date (' + moduleStartDate.format() + ') cannot be after the Journey end date (' + journeyEndDate.format() + ').'
            );
        }
        
        // Validate module end date
        if (moduleEndDate < journeyStartDate) {
            moduleAssignment.End_Date__c.addError(
                'Module end date (' + moduleEndDate.format() + ') cannot be before the Journey start date (' + journeyStartDate.format() + ').'
            );
        }
        
        if (moduleEndDate > journeyEndDate) {
            moduleAssignment.End_Date__c.addError(
                'Module end date (' + moduleEndDate.format() + ') cannot be after the Journey end date (' + journeyEndDate.format() + ').'
            );
        }
        
        // Validate that module start date is not after module end date
        if (moduleStartDate > moduleEndDate) {
            moduleAssignment.Start_Date__c.addError(
                'Module start date (' + moduleStartDate.format() + ') cannot be after the module end date (' + moduleEndDate.format() + ').'
            );
        }
    }
}