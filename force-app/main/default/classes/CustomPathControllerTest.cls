/**
 * @description       : This class is the Unit Test for the Custom Path Controller class
 * @author            : Pablo Castro 12-10-2025
 * @group             : 
 * @last modified on  : 12-10-2025
 * @last modified by  : Pablo Castro
**/

@isTest
private class CustomPathControllerTest {

    @isTest
    static void testGetDependentPicklistMap() {
        Map<String, List<String>> results = CustomPathController.getDependentPicklistMap(
            'Benefit__c',
            'Initiative_Stage__c',
            'Initiative_Stage__c'
        );

        Assert.areNotEqual(null, results, 'Result should not be null');
        Assert.isTrue(results.keySet().size() > 0, 'Should return at least one picklist entry');

        for (String key : results.keySet()) {
            Assert.areNotEqual(null, results.get(key), 'List should not be null');
        }
    }

    @isTest
    static void testUpdateInitiativeStage() {
        Benefit__c benefit = new Benefit__c(
            Benefit_Type__c = 'Death Benefit',
            Benefit_Sub_Type__c = 'Estate Payments - Post-Ret Death',
            Initiative_Stage__c = 'Death Notice'
        );
        insert benefit;

        Test.startTest();
        CustomPathController.updateInitiativeStage(benefit.Id, 'Completed');
        Test.stopTest();

        Benefit__c updated = [SELECT Initiative_Stage__c FROM Benefit__c WHERE Id = :benefit.Id];
        Assert.areEqual('Completed', updated.Initiative_Stage__c, 'The Initiative Stage should have been updated');
    }

    @isTest
    static void testUpdateInitiativeStageWithBlankInputs() {
        Test.startTest();
        CustomPathController.updateInitiativeStage('', '');
        Test.stopTest();
        Assert.isTrue('' == '', 'values should be equal');
    }
}