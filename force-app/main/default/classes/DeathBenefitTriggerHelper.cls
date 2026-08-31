/**
 * @description       : This class is the Trigger Handler for the Initiative Task object
 * @author            : Pablo Castro 08-13-2025
 * @group             : 
 * @last modified on  : 08-15-2025
 * @last modified by  : Pablo Castro
**/

public class DeathBenefitTriggerHelper {

    public static void templateMethodForTrigger(List<Death_Benefit__c> newList, String executionStep) {
        System.debug('Death Benefit Trigger Handler Execution - ' + executionStep);
        for (Death_Benefit__c newDeathBenefit : newList) {
            System.debug('> ' + newDeathBenefit.Name + ' - ' + newDeathBenefit.Id);
        }
    }
}