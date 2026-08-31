/**
 * @description       : This class is the Controller for the Custom Path component
 * @author            : Pablo Castro 10-27-2025
 * @group             : 
 * @last modified on  : 10-21-2025
 * @last modified by  : Pablo Castro
**/

public without sharing class CustomPathController {

    public class MyPickListInfo {
        public String validFor;
    }
    
    @AuraEnabled(cacheable=false)
    public static Map<String, List<String>> getDependentPicklistMap(String objectApiName, String controllingFieldApiName, String dependentFieldApiName) {

        Map<String, List<String>> controllingToDependentMap = new Map<String, List<String>>();
        
        Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get(objectApiName);
        Schema.DescribeSObjectResult describeResult = sobjectType.getDescribe();
        Map<String, Schema.SObjectField> fields = describeResult.fields.getMap();
        
        Schema.DescribeFieldResult controllingField = fields.get(controllingFieldApiName).getDescribe();
        Schema.DescribeFieldResult dependentField = fields.get(dependentFieldApiName).getDescribe();
                
        List<Schema.PicklistEntry> controllingPicklistValues = controllingField.getPicklistValues();
        List<Schema.PicklistEntry> dependentPicklistValues = dependentField.getPicklistValues();

        List<String> typeA = new List<String> {'On Hold', 'Completed'};
        List<String> typeB = new List<String> {'Regular Retirement', 'Disability', 'Term Vested', 'QDRO', 'Deferred Calculations'};
        List<String> typeC = new List<String> {'Benefit Calc & Peer Review', 'LWOP Audit', 'Peer Review', 'Benefit Approval'};

        for (Schema.PicklistEntry controllingPicklist : controllingPicklistValues) {            
            String controllingFieldLabel = String.valueOf(controllingPicklist.Label);
            List<String> dependentFieldsList = new List<String>();

            for (Schema.PicklistEntry dependentPicklist : dependentPicklistValues) {
                String dependentFieldLabel = String.valueOf(dependentPicklist.Label);

                if (typeA.contains(dependentFieldLabel)) {
                    dependentFieldsList.add(dependentFieldLabel);
                }

                if ((controllingFieldLabel.contains('Estate Payments') || controllingFieldLabel.contains('Survivor Payments')) && dependentFieldLabel == 'Death Notice') {
                    dependentFieldsList.add(dependentFieldLabel);
                }

                if ((controllingFieldLabel.contains('Estate Payments') && dependentFieldLabel.contains('Estate Payments')) || (controllingFieldLabel.contains('Survivor Payments') && dependentFieldLabel.contains('Survivor Payments'))) {
                    if ((controllingFieldLabel.contains('Pre-Ret Death') && dependentFieldLabel.contains('Pre-Ret Death')) || (controllingFieldLabel.contains('Post-Ret Death') && dependentFieldLabel.contains('Post-Ret Death'))) {
                        dependentFieldsList.add(dependentFieldLabel);
                    }
                }
                
                if ((typeB.contains(controllingFieldLabel) && typeC.contains(dependentFieldLabel))) {
                    dependentFieldsList.add(dependentFieldLabel);
                }

                if ((controllingFieldLabel == 'Disability' && dependentFieldLabel.contains('Member'))) {
                    dependentFieldsList.add(dependentFieldLabel);
                }

                controllingToDependentMap.put(controllingFieldLabel, dependentFieldsList);
            }
        }
           
        return controllingToDependentMap;
    }

    @AuraEnabled(cacheable=false)
    public static void updateInitiativeStage(String benefitRecordId, String newInitiativeStageValue) {
        Boolean isBenefitObjectAccessible = Benefit__c.SObjectType.getDescribe().isAccessible();
        Boolean isInitiativeStageFieldAccessible = Benefit__c.SObjectType.getDescribe().fields.getMap().get('Initiative_Stage__c').getDescribe().isAccessible();
        Boolean isInitiativeStageFieldUpdatable = Benefit__c.SObjectType.getDescribe().fields.getMap().get('Initiative_Stage__c').getDescribe().isUpdateable();
        if(String.isNotBlank(benefitRecordId) && String.isNotBlank(newInitiativeStageValue) && isBenefitObjectAccessible && isInitiativeStageFieldAccessible && isInitiativeStageFieldUpdatable) {
            Benefit__c benefitRecord = [SELECT Id, Initiative_Stage__c FROM Benefit__c WHERE Id = :benefitRecordId];
            benefitRecord.Initiative_Stage__c = newInitiativeStageValue;
            update benefitRecord;
        }        
    }
}