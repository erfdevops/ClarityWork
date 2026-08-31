/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
@IsTest
private class dlrs_Initiative_StageTest
{
    @IsTest
    private static void testTrigger()
    {
        // Force the dlrs_Initiative_StageTrigger to be invoked, fails the test if org config or other Apex code prevents this.
        dlrs.RollupService.testHandler(new Initiative_Stage__c());
    }
}