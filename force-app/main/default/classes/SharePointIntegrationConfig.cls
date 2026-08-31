/**
 * @description: Configuration class for SharePoint Integration
 * Retrieves SharePoint credentials and settings from custom metadata type
 * @author: Fernando Hernandez
 * @created: 2026-01-04
 */
public without sharing class SharePointIntegrationConfig {
    
    private static final String CONFIG_RECORD_NAME = 'Default';
    
    /**
     * @description: Gets the SharePoint configuration from custom metadata type
     * @return: SharePointConfig wrapper with all required fields
     */
    public static SharePointConfig getConfig() {
        try {
            SharePoint_Configuration__mdt config = [
                SELECT 
                    Tenant_ID__c,
                    Client_ID__c,
                    Client_Secret__c,
                    Tenant_Name__c,
                    Site_Name__c,
                    Site_ID__c,
                    List_ID__c,
                    Drive_ID__c
                FROM SharePoint_Configuration__mdt
                WHERE DeveloperName = :CONFIG_RECORD_NAME
                LIMIT 1
            ];
            
            if (config == null) {
                throw new SharePointConfigurationException('SharePoint configuration not found. Please create a "Default" record in the SharePoint_Configuration__mdt metadata type.');
            }
            
            return new SharePointConfig(config);
        } catch (QueryException e) {
            throw new SharePointConfigurationException('Error retrieving SharePoint configuration: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Gets a specific configuration value by field name
     * @param fieldName: The API name of the field to retrieve
     * @return: The field value as a string
     */
    public static String getConfigValue(String fieldName) {
        SharePointConfig config = getConfig();
        
        switch on fieldName {
            when 'TenantID' {
                return config.tenantId;
            }
            when 'ClientID' {
                return config.clientId;
            }
            when 'ClientSecret' {
                return config.clientSecret;
            }
            when 'TenantName' {
                return config.tenantName;
            }
            when 'SiteName' {
                return config.siteName;
            }
            when 'SiteID' {
                return config.siteId;
            }
            when 'ListID' {
                return config.listId;
            }
            when 'DriveID' {
                return config.driveId;
            }
            when else {
                throw new SharePointConfigurationException('Unknown configuration field: ' + fieldName);
            }
        }
    }
    
    /**
     * @description: Wrapper class for SharePoint Configuration
     * Provides easy access to all configuration values
     */
    public class SharePointConfig {
        public String tenantId { get; set; }
        public String clientId { get; set; }
        public String clientSecret { get; set; }
        public String tenantName { get; set; }
        public String siteName { get; set; }
        public String siteId { get; set; }
        public String listId { get; set; }
        public String driveId { get; set; }
        
        public SharePointConfig(SharePoint_Configuration__mdt config) {
            this.tenantId = config.Tenant_ID__c;
            this.clientId = config.Client_ID__c;
            this.clientSecret = config.Client_Secret__c;
            this.tenantName = config.Tenant_Name__c;
            this.siteName = config.Site_Name__c;
            this.siteId = config.Site_ID__c;
            this.listId = config.List_ID__c;
            this.driveId = config.Drive_ID__c;
        }
        
        /**
         * @description: Validates that all required fields are populated
         * @return: true if valid, false otherwise
         */
        public Boolean isValid() {
            return String.isNotBlank(tenantId) && 
                   String.isNotBlank(clientId) && 
                   String.isNotBlank(clientSecret);
        }
    }
    
    /**
     * @description: Custom exception for SharePoint configuration errors
     */
    public class SharePointConfigurationException extends Exception {}
}