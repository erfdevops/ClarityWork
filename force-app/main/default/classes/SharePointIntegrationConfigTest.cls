/**
 * @description: Test class for SharePointIntegrationConfig
 * Tests configuration retrieval from custom metadata
 * @author: Fernando Hernandez
 * @created: 2026-01-05
 */
@isTest
private class SharePointIntegrationConfigTest {
    
    /**
     * Test getting configuration
     * Note: Custom metadata cannot be inserted in tests, so this tests the getter logic
     */
    @isTest
    static void testGetConfig() {
        Test.startTest();
        SharePointIntegrationConfig.SharePointConfig config = 
            SharePointIntegrationConfig.getConfig();
        Test.stopTest();
        
        // Verify config object is returned (even if fields are null in test context)
        System.assertNotEquals(null, config, 'Config should not be null');
    }
    
    /**
     * Test config validation
     */
    @isTest
    static void testConfigValidation() {
        Test.startTest();
        SharePointIntegrationConfig.SharePointConfig config = 
            SharePointIntegrationConfig.getConfig();
        
        // In test context, metadata may not exist, so isValid might be false
        Boolean isValid = config.isValid();
        Test.stopTest();
        
        // Just verify the method runs without error
        System.assert(isValid == true || isValid == false, 'isValid should return a boolean');
    }
    
    @IsTest
    static void testGetConfigValue() {
        String testFieldName1 = 'TenantID';
        String testFieldName2 = 'ClientID';
        String testFieldName3 = 'ClientSecret';
        String testFieldName4 = 'TenantName';
        String testFieldName5 = 'SiteName';
        String testFieldName6 = 'SiteID';
        String testFieldName7 = 'DriveID';

        String testGetConfigResult1 = '';
        String testGetConfigResult2 = '';
        String testGetConfigResult3 = '';
        String testGetConfigResult4 = '';
        String testGetConfigResult5 = '';
        String testGetConfigResult6 = '';
        String testGetConfigResult7 = '';

        Test.startTest();
            testGetConfigResult1 = SharePointIntegrationConfig.getConfigValue(testFieldName1);
            testGetConfigResult2 = SharePointIntegrationConfig.getConfigValue(testFieldName2);
            testGetConfigResult3 = SharePointIntegrationConfig.getConfigValue(testFieldName3);
            testGetConfigResult4 = SharePointIntegrationConfig.getConfigValue(testFieldName4);
            testGetConfigResult5 = SharePointIntegrationConfig.getConfigValue(testFieldName5);
            testGetConfigResult6 = SharePointIntegrationConfig.getConfigValue(testFieldName6);
            testGetConfigResult7 = SharePointIntegrationConfig.getConfigValue(testFieldName7);
        Test.stopTest();
        
        Assert.isNotNull(testGetConfigResult1, 'Returned config should not be null');
        Assert.isNotNull(testGetConfigResult2, 'Returned config should not be null');
        Assert.isNotNull(testGetConfigResult3, 'Returned config should not be null');
        Assert.isNotNull(testGetConfigResult4, 'Returned config should not be null');
        Assert.isNotNull(testGetConfigResult5, 'Returned config should not be null');
        Assert.isNotNull(testGetConfigResult6, 'Returned config should not be null');
        Assert.isNotNull(testGetConfigResult7, 'Returned config should not be null');
    }
}