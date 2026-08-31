/**
 * @description: SharePoint Site Service
 * Handles API calls to Microsoft Graph to retrieve SharePoint site information
 * Uses cached OAuth token from SharePointAuthService
 * @author: Fernando Hernandez
 * @created: 2026-01-04
 */
@SuppressWarnings('sf:ApexCRUDViolation,sf:ApexDangerousMethods')
global without sharing class SharePointSiteService {
    
    private static final String GRAPH_API_ENDPOINT = 'https://graph.microsoft.com/v1.0';
    
    /**
     * @description: Initializes all SharePoint configuration in one call
     * Orchestrates the complete setup flow:
     * 1. Gets/generates access token (cached if valid)
     * 2. Gets Site ID (cached if already retrieved)
     * 3. Gets Drive ID (cached if already retrieved)
     * All results are stored in metadata in a single batch to avoid uncommitted work errors
     * @return: SharePointConfig wrapper with all populated values
     */
    public static SharePointIntegrationConfig.SharePointConfig initializeSharePointConfiguration() {
        try {
            System.debug('===== Initializing SharePoint Configuration =====');
            
            // Get configuration from metadata
            SharePointIntegrationConfig.SharePointConfig config = SharePointIntegrationConfig.getConfig();
            System.debug('✅ Configuration loaded from metadata');
            System.debug('  Tenant: ' + config.tenantName);
            System.debug('  Site: ' + config.siteName);
            
            // Step 1: Get/validate access token (will generate if expired)
            System.debug('Step 1: Ensuring valid access token...');
            String accessToken = SharePointAuthService.getAccessToken();
            if (String.isBlank(accessToken)) {
                throw new SharePointSiteException('Failed to obtain access token');
            }
            System.debug('✅ Access token ready (cached or newly generated)');
            System.debug('  Token length: ' + accessToken.length());
            
            // Step 2: Get Site ID without updating metadata yet (to avoid uncommitted work error)
            System.debug('Step 2: Ensuring Site ID is populated...');
            String siteId = getSiteIdWithoutMetadataUpdate(config.tenantName, config.siteName);
            System.debug('Site ID value after getSiteId(): ' + siteId);
            System.debug('Site ID is blank: ' + String.isBlank(siteId));
            
            if (String.isBlank(siteId)) {
                throw new SharePointSiteException('Failed to obtain Site ID');
            }
            System.debug('✅ Site ID ready (cached or newly retrieved)');
            System.debug('  Site ID: ' + siteId);
            
            // Step 3: Get Drive ID without updating metadata yet (to avoid uncommitted work error)
            System.debug('Step 3: Ensuring Drive ID is populated...');
            System.debug('  Calling getDriveId with siteId: ' + siteId);
            String driveId = getDriveIdWithoutMetadataUpdate(siteId);
            System.debug('Drive ID value after getDriveId(): ' + driveId);
            System.debug('Drive ID is blank: ' + String.isBlank(driveId));
            
            if (String.isBlank(driveId)) {
                throw new SharePointSiteException('Failed to obtain Drive ID');
            }
            System.debug('✅ Drive ID ready (cached or newly retrieved)');
            System.debug('  Drive ID: ' + driveId);
            
            // Step 4: Update all metadata at once (after all callouts are complete)
            System.debug('Step 4: Updating all values in metadata...');
            updateAllConfigurationInMetadata(siteId, driveId);
            System.debug('✅ All values updated in metadata');
            
            System.debug('===== SharePoint Configuration Initialized Successfully =====');
            System.debug('All required fields are now populated in metadata');
            
            return config;
            
        } catch (Exception e) {
            System.debug('❌ Error initializing SharePoint configuration: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new SharePointSiteException('Failed to initialize configuration: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Gets Site ID without updating metadata (prevents uncommitted work error)
     * Checks cache first, then calls API if needed
     * @param tenantName: SharePoint tenant name
     * @param siteName: SharePoint site name
     * @return: Site ID string (from cache or Graph API)
     */
    private static String getSiteIdWithoutMetadataUpdate(String tenantName, String siteName) {
        try {
            // Check if Site ID is already cached in metadata
            String cachedSiteId = getMetadataFieldValue('Site_ID__c');
            if (String.isNotBlank(cachedSiteId) && !Test.isRunningTest()) {
                System.debug('✅ Using cached Site ID from metadata');
                return cachedSiteId;
            }
            
            System.debug('Retrieving Site ID from Graph API...');
            
            // Get access token
            String accessToken = SharePointAuthService.getAccessToken();
            
            if (String.isBlank(accessToken)) {
                throw new SharePointSiteException('Failed to obtain access token for site lookup');
            }
            
            // Build Graph API endpoint
            String endpoint = GRAPH_API_ENDPOINT + '/sites/' + tenantName + '.sharepoint.com:/sites/' + siteName;
            
            // Make HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Accept', 'application/json');
            req.setTimeout(30000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Graph API Response Status: ' + res.getStatusCode());
            
            if (res.getStatusCode() != 200) {
                throw new SharePointSiteException(
                    'Failed to retrieve site. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody()
                );
            }
            
            // Parse response
            SiteResponse siteResponse = (SiteResponse) JSON.deserialize(res.getBody(), SiteResponse.class);
            
            if (String.isBlank(siteResponse.id)) {
                throw new SharePointSiteException('Site ID not found in response');
            }
            
            System.debug('✅ Retrieved Site ID from Graph API (will update metadata later)');
            return siteResponse.id;
            
        } catch (Exception e) {
            System.debug('❌ Error retrieving site ID: ' + e.getMessage());
            throw new SharePointSiteException('Failed to get site ID: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Gets Drive ID without updating metadata (prevents uncommitted work error)
     * Checks cache first, then calls API if needed
     * @param siteId: SharePoint Site ID
     * @return: Drive ID string (from cache or Graph API)
     */
    private static String getDriveIdWithoutMetadataUpdate(String siteId) {
        try {
            // Check if Drive ID is already cached in metadata
            String cachedDriveId = getMetadataFieldValue('Drive_ID__c');
            if (String.isNotBlank(cachedDriveId) && !Test.isRunningTest()) {
                System.debug('✅ Using cached Drive ID from metadata');
                return cachedDriveId;
            }
            
            System.debug('Retrieving Drive ID from Graph API...');
            
            // Get access token
            String accessToken = SharePointAuthService.getAccessToken();
            
            if (String.isBlank(accessToken)) {
                throw new SharePointSiteException('Failed to obtain access token for drive lookup');
            }
            
            if (String.isBlank(siteId)) {
                throw new SharePointSiteException('Site ID cannot be blank');
            }
            
            // Build Graph API endpoint
            String endpoint = GRAPH_API_ENDPOINT + '/sites/' + siteId + '/drives';
            
            // Make HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Accept', 'application/json');
            req.setTimeout(30000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Graph API Response Status: ' + res.getStatusCode());
            
            if (res.getStatusCode() != 200) {
                throw new SharePointSiteException(
                    'Failed to retrieve drives. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody()
                );
            }
            
            // Parse response
            DrivesResponse drivesResponse = (DrivesResponse) JSON.deserialize(res.getBody(), DrivesResponse.class);
            
            if (drivesResponse.value == null || drivesResponse.value.isEmpty()) {
                throw new SharePointSiteException('No drives found in response');
            }
            
            // Get first drive
            DriveInfo firstDrive = drivesResponse.value[0];
            
            if (String.isBlank(firstDrive.id)) {
                throw new SharePointSiteException('Drive ID not found in response');
            }
            
            System.debug('✅ Retrieved Drive ID from Graph API (will update metadata later)');
            System.debug('Drive Name: ' + firstDrive.name);
            return firstDrive.id;
            
        } catch (Exception e) {
            System.debug('❌ Error retrieving drive ID: ' + e.getMessage());
            throw new SharePointSiteException('Failed to get drive ID: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Updates ALL configuration fields in metadata at once
     * Called AFTER all API callouts are complete to avoid uncommitted work errors
     * @param siteId: The Site ID to store
     * @param driveId: The Drive ID to store
     */
    @TestVisible
    private static void updateAllConfigurationInMetadata(String siteId, String driveId) {
        try {
            System.debug('Updating Site_ID__c and Drive_ID__c in metadata...');
            
            // Create metadata instance
            Metadata.CustomMetadata metadataRecord = new Metadata.CustomMetadata();
            metadataRecord.fullName = 'SharePoint_Configuration.Default';
            metadataRecord.label = 'SharePoint Configuration';
            
            // Add Site ID field
            Metadata.CustomMetadataValue siteIdField = new Metadata.CustomMetadataValue();
            siteIdField.field = 'Site_ID__c';
            siteIdField.value = siteId;
            metadataRecord.values.add(siteIdField);
            
            // Add Drive ID field
            Metadata.CustomMetadataValue driveIdField = new Metadata.CustomMetadataValue();
            driveIdField.field = 'Drive_ID__c';
            driveIdField.value = driveId;
            metadataRecord.values.add(driveIdField);
            
            // Deploy via Metadata API
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            mdContainer.addMetadata(metadataRecord);
            
            if (!Test.isRunningTest()) {
                Metadata.Operations.enqueueDeployment(mdContainer, new SharePointMetadataCallback());
            }
            
            System.debug('✅ Metadata deployment initiated (Site ID + Drive ID)');
            
        } catch (Exception e) {
            System.debug('⚠️ Warning: Could not update metadata. ' + e.getMessage());
            // Don't throw - we have the values, just metadata update failed
        }
    }
    
    /**
     * @description: Gets list of folders in the SharePoint drive root
     * Calls Microsoft Graph API to retrieve folder names from drive root children
     * This version accepts both driveId and accessToken to avoid uncommitted work errors
     * Call this AFTER configuration is already initialized
     * @param driveId: The Drive ID (from SharePoint configuration)
     * @param accessToken: The access token (from cached configuration)
     * @return: List of folder names (for dropdown in UI)
     */
    public static List<String> getFolderList(String driveId, String accessToken) {
        List<String> folderNames = new List<String>();
       
        try {
            if (String.isBlank(driveId)) {
                throw new SharePointSiteException('Drive ID cannot be blank');
            }
            
            if (String.isBlank(accessToken)) {
                throw new SharePointSiteException('Access token cannot be blank');
            }
            
            System.debug('Retrieving folder list from drive: ' + driveId);
            
            // Build Graph API endpoint for drive root children
            String endpoint = GRAPH_API_ENDPOINT + '/drives/' + driveId + '/root/children';
            
            // Make HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Accept', 'application/json');
            req.setTimeout(30000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Graph API Response Status: ' + res.getStatusCode());
            
            if (res.getStatusCode() != 200) {
                throw new SharePointSiteException(
                    'Failed to retrieve folder list. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody()
                );
            }
            
            // Parse response
            DriveItemsResponse itemsResponse = (DriveItemsResponse) JSON.deserialize(res.getBody(), DriveItemsResponse.class);
            
            if (itemsResponse.value == null || itemsResponse.value.isEmpty()) {
                System.debug('⚠️ No items found in drive root');
                return folderNames;
            }
            
            // Extract folder names only (filter out files by checking for folder property)
            for (DriveItem item : itemsResponse.value) {
                if (item.folder != null) {
                    // This is a folder
                    folderNames.add(item.name);
                    System.debug('  📁 Folder: ' + item.name);
                }
            }
            
            System.debug('✅ Retrieved ' + folderNames.size() + ' folders from drive');
            return folderNames;
            
        } catch (Exception e) {
            System.debug('❌ Error retrieving folder list: ' + e.getMessage());
            throw new SharePointSiteException('Failed to get folder list: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Gets list of folders in the SharePoint drive root (with auto token refresh)
     * Overloaded version that retrieves access token automatically
     * Use this if you're calling separately from configuration initialization
     * @param driveId: The Drive ID (from SharePoint configuration)
     * @return: List of folder names (for dropdown in UI)
     */
    public static List<String> getFolderList(String driveId) {
        try {
            if (String.isBlank(driveId)) {
                throw new SharePointSiteException('Drive ID cannot be blank');
            }
            
            // Get access token (this may trigger metadata operations)
            String accessToken = SharePointAuthService.getAccessToken();
            
            if (String.isBlank(accessToken)) {
                throw new SharePointSiteException('Failed to obtain access token for folder retrieval');
            }
            
            // Call the main getFolderList method with token
            return getFolderList(driveId, accessToken);
            
        } catch (Exception e) {
            System.debug('❌ Error retrieving folder list: ' + e.getMessage());
            throw new SharePointSiteException('Failed to get folder list: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Gets the SharePoint Site ID for a given tenant and site name
     * Calls Microsoft Graph API to retrieve site details only if not already cached
     * Updates the metadata with the Site_ID__c value
     * @param tenantName: SharePoint tenant name (e.g., soaritude084)
     * @param siteName: SharePoint site name (e.g., SoaritudeSPI)
     * @return: Site ID from Microsoft Graph response or cached metadata
     */
    public static String getSiteId(String tenantName, String siteName) {
        try {
            // Check if Site ID is already populated in metadata
            String cachedSiteId = getMetadataFieldValue('Site_ID__c');
            if (String.isNotBlank(cachedSiteId) && !Test.isRunningTest()) {
                System.debug('✅ Using cached Site ID from metadata: ' + cachedSiteId);
                return cachedSiteId;
            }
            
            System.debug('Retrieving SharePoint Site ID for: ' + tenantName + ' / ' + siteName);
            
            // Get valid access token
            String accessToken = SharePointAuthService.getAccessToken();
            
            if (String.isBlank(accessToken)) {
                throw new SharePointSiteException('Failed to obtain access token for site lookup');
            }
            
            // Build the Graph API endpoint for site lookup
            String endpoint = GRAPH_API_ENDPOINT + '/sites/' + tenantName + '.sharepoint.com:/sites/' + siteName;
            
            // Make HTTP request to Graph API
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Accept', 'application/json');
            req.setTimeout(30000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Graph API Response Status: ' + res.getStatusCode());
            System.debug('Graph API Response Body: ' + res.getBody());
            
            if (res.getStatusCode() != 200) {
                throw new SharePointSiteException(
                    'Failed to retrieve site information. Status: ' + res.getStatusCode() + 
                    ' Body: ' + res.getBody()
                );
            }
            
            // Parse response to extract site ID
            SiteResponse siteResponse = (SiteResponse) JSON.deserialize(res.getBody(), SiteResponse.class);
            
            if (String.isBlank(siteResponse.id)) {
                throw new SharePointSiteException('Site ID not found in response');
            }
            
            System.debug('✅ Retrieved Site ID from Graph API: ' + siteResponse.id);
            
            // Update metadata with the Site ID
            updateSiteIdInMetadata(siteResponse.id);
            
            return siteResponse.id;
            
        } catch (Exception e) {
            System.debug('❌ Error retrieving site ID: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new SharePointSiteException('Failed to get site ID: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Gets the SharePoint Drive ID for a given site ID
     * Calls Microsoft Graph API /sites/{siteId}/drives endpoint only if not already cached
     * Returns the first drive (typically the Documents library)
     * Updates the metadata with the Drive_ID__c value
     * @param siteId: The SharePoint site ID (from getSiteId method)
     * @return: Drive ID from Microsoft Graph response or cached metadata
     */
    public static String getDriveId(String siteId) {
        try {
            // Check if Drive ID is already populated in metadata
            String cachedDriveId = getMetadataFieldValue('Drive_ID__c');
            if (String.isNotBlank(cachedDriveId) && !Test.isRunningTest()) {
                System.debug('✅ Using cached Drive ID from metadata: ' + cachedDriveId);
                return cachedDriveId;
            }
            
            System.debug('Retrieving SharePoint Drive ID for Site: ' + siteId);
            
            // Get valid access token
            String accessToken = SharePointAuthService.getAccessToken();
            
            if (String.isBlank(accessToken)) {
                throw new SharePointSiteException('Failed to obtain access token for drive lookup');
            }
            
            if (String.isBlank(siteId)) {
                throw new SharePointSiteException('Site ID cannot be blank');
            }
            
            // Build the Graph API endpoint for drives
            String endpoint = GRAPH_API_ENDPOINT + '/sites/' + siteId + '/drives';
            
            // Make HTTP request to Graph API
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Accept', 'application/json');
            req.setTimeout(30000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Graph API Response Status: ' + res.getStatusCode());
            System.debug('Graph API Response Body: ' + res.getBody());
            
            if (res.getStatusCode() != 200) {
                throw new SharePointSiteException(
                    'Failed to retrieve drives information. Status: ' + res.getStatusCode() + 
                    ' Body: ' + res.getBody()
                );
            }
            
            // Parse response to extract first drive ID
            DrivesResponse drivesResponse = (DrivesResponse) JSON.deserialize(res.getBody(), DrivesResponse.class);
            
            if (drivesResponse.value == null || drivesResponse.value.isEmpty()) {
                throw new SharePointSiteException('No drives found in response');
            }
            
            // Get the first drive (typically Documents library)
            DriveInfo firstDrive = drivesResponse.value[0];
            
            if (String.isBlank(firstDrive.id)) {
                throw new SharePointSiteException('Drive ID not found in response');
            }
            
            System.debug('✅ Retrieved Drive ID from Graph API: ' + firstDrive.id);
            System.debug('Drive Name: ' + firstDrive.name);
            System.debug('Drive Type: ' + firstDrive.driveType);
            
            // Update metadata with the Drive ID
            updateDriveIdInMetadata(firstDrive.id);
            
            return firstDrive.id;
            
        } catch (Exception e) {
            System.debug('❌ Error retrieving drive ID: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new SharePointSiteException('Failed to get drive ID: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Helper method to get a specific field value from metadata
     * Reads the current SharePoint_Configuration.Default metadata record
     * @param fieldName: The API name of the field to retrieve
     * @return: The field value as a string, or blank if not found
     */
    @SuppressWarnings('sf:ApexCRUDViolation')
    private static String getMetadataFieldValue(String fieldName) {
        try {
            List<SharePoint_Configuration__mdt> configList = [
                SELECT Site_ID__c, Drive_ID__c
                FROM SharePoint_Configuration__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            
            if (configList.isEmpty()) {
                return '';
            }
            
            SharePoint_Configuration__mdt config = configList[0];
            
            if (fieldName == 'Site_ID__c') {
                return config.Site_ID__c;
            } else if (fieldName == 'Drive_ID__c') {
                return config.Drive_ID__c;
            }
            
            return '';
        } catch (Exception e) {
            System.debug('Warning: Could not retrieve metadata field value: ' + e.getMessage());
            return '';
        }
    }
    
    /**
     * @description: Updates the Site_ID__c field in SharePoint_Configuration metadata
     * Uses Metadata API to persist the site ID
     * @param siteId: The site ID from Microsoft Graph
     */
    private static void updateSiteIdInMetadata(String siteId) {
        try {
            System.debug('Updating Site ID in metadata: ' + siteId);
            
            // Create metadata instance
            Metadata.CustomMetadata metadataRecord = new Metadata.CustomMetadata();
            metadataRecord.fullName = 'SharePoint_Configuration.Default';
            metadataRecord.label = 'SharePoint Configuration';
            
            // Add the Site ID field
            Metadata.CustomMetadataValue siteIdField = new Metadata.CustomMetadataValue();
            siteIdField.field = 'Site_ID__c';
            siteIdField.value = siteId;
            metadataRecord.values.add(siteIdField);
            
            // Deploy via Metadata API
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            mdContainer.addMetadata(metadataRecord);
            
            if (!Test.isRunningTest()) {
                Metadata.Operations.enqueueDeployment(mdContainer, new SharePointMetadataCallback());
            }
            
            System.debug('✅ Site ID metadata deployment initiated');
            
        } catch (Exception e) {
            System.debug('⚠️ Warning: Could not update Site ID in metadata. ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Don't throw - we got the site ID successfully, just metadata update failed
        }
    }
    
    /**
     * @description: Updates the Drive_ID__c field in SharePoint_Configuration metadata
     * Uses Metadata API to persist the drive ID
     * @param driveId: The drive ID from Microsoft Graph
     */
    private static void updateDriveIdInMetadata(String driveId) {
        try {
            System.debug('Updating Drive ID in metadata: ' + driveId);
            
            // Create metadata instance
            Metadata.CustomMetadata metadataRecord = new Metadata.CustomMetadata();
            metadataRecord.fullName = 'SharePoint_Configuration.Default';
            metadataRecord.label = 'SharePoint Configuration';
            
            // Add the Drive ID field
            Metadata.CustomMetadataValue driveIdField = new Metadata.CustomMetadataValue();
            driveIdField.field = 'Drive_ID__c';
            driveIdField.value = driveId;
            metadataRecord.values.add(driveIdField);
            
            // Deploy via Metadata API
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            mdContainer.addMetadata(metadataRecord);
            
            if (!Test.isRunningTest()) {
                Metadata.Operations.enqueueDeployment(mdContainer, new SharePointMetadataCallback());
            }
            
            System.debug('✅ Drive ID metadata deployment initiated');
            
        } catch (Exception e) {
            System.debug('⚠️ Warning: Could not update Drive ID in metadata. ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Don't throw - we got the drive ID successfully, just metadata update failed
        }
    }
    
    /**
     * Wrapper class for Microsoft Graph Drive Items response
     * Deserializes JSON response from /drives/{driveId}/root/children endpoint
     */
    public class DriveItemsResponse {
        public List<DriveItem> value { get; set; }
    }
    
    /**
     * Wrapper class for individual Drive Item (file or folder)
     * Represents a single item object from the children endpoint
     */
    public class DriveItem {
        public String id { get; set; }
        public String name { get; set; }
        public String webUrl { get; set; }
        public String createdDateTime { get; set; }
        public String lastModifiedDateTime { get; set; }
        public FolderInfo folder { get; set; }  // Present if this is a folder
        public FileInfo file { get; set; }      // Present if this is a file
        public Long size { get; set; }
    }
    
    /**
     * Wrapper class for Folder information
     * Indicates item is a folder and contains child count
     */
    public class FolderInfo {
        public Integer childCount { get; set; }
    }
    
    /**
     * Wrapper class for File information
     * Indicates item is a file and contains mime type
     */
    public class FileInfo {
        public String mimeType { get; set; }
    }
    
    /**
     * Wrapper class for Microsoft Graph Site response
     * Deserializes JSON response from /sites endpoint
     */
    public class SiteResponse {
        public String id { get; set; }
        public String name { get; set; }
        public String displayName { get; set; }
        public String webUrl { get; set; }
        public String description { get; set; }
        public String createdDateTime { get; set; }
        public String lastModifiedDateTime { get; set; }
    }
    
    /**
     * Wrapper class for Microsoft Graph Drives response
     * Deserializes JSON response from /sites/{siteId}/drives endpoint
     */
    public class DrivesResponse {
        public List<DriveInfo> value { get; set; }
    }
    
    /**
     * Wrapper class for individual Drive info
     * Represents a single drive object from the drives endpoint
     */
    public class DriveInfo {
        public String id { get; set; }
        public String name { get; set; }
        public String driveType { get; set; }
        public String webUrl { get; set; }
        public String description { get; set; }
        public String createdDateTime { get; set; }
        public String lastModifiedDateTime { get; set; }
        public DriveQuota quota { get; set; }
    }
    
    /**
     * Wrapper class for Drive quota information
     */
    public class DriveQuota {
        public Long total { get; set; }
        public Long used { get; set; }
        public Long remaining { get; set; }
        public Long deleted { get; set; }
        public String state { get; set; }
    }
    
    /**
     * @description: Custom exception for SharePoint site operations
     */
    public class SharePointSiteException extends Exception {}
    
    /**
     * @description: Callback handler for Metadata API deployments
     * Logs deployment status for site ID updates
     */
    public class SharePointMetadataCallback implements Metadata.DeployCallback {
        public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
            if (result.done) {
                System.debug('✅ Site ID metadata deployed successfully');
            } else {
                System.debug('⚠️ Site ID metadata deployment may have issues');
                if (result.details != null && result.details.componentFailures != null) {
                    System.debug('Deploy failures: ' + result.details.componentFailures);
                }
            }
        }
    }
}