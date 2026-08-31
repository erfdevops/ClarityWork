/**
 * @description: SharePoint Authentication Service
 * Handles OAuth 2.0 token generation for Microsoft Graph API
 * Stores tokens in custom metadata type for persistence across sessions
 * Uses Metadata API for token writes (metadata is read-only via standard DML)
 * @author: Fernando Hernandez
 * @created: 2026-01-04
 */
global without sharing class SharePointAuthService {
    
    private static final String TOKEN_ENDPOINT = 'https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token';
    private static final String GRANT_TYPE = 'client_credentials';
    private static final String SCOPE = 'https://graph.microsoft.com/.default';
    private static final Integer TOKEN_EXPIRY_TIME_MS = 3600000; // 1 hour in milliseconds
    private static final String CONFIG_NAME = 'Default';
    
    /**
     * @description: Gets a valid access token for SharePoint API calls
     * Checks if cached token in metadata is still valid (less than 1 hour old)
     * If not valid, generates a new token via OAuth 2.0 Client Credentials flow
     * @return: Valid OAuth access token for SharePoint Graph API
     */
    public static String getAccessToken() {
        try {
            // Check if valid cached token exists in metadata
            if (isTokenValid()) {
                System.debug('Using cached token from metadata');
                return getStoredToken();
            }
            
            // No valid token cached - generate new one
            System.debug('Cached token invalid or expired. Generating new token...');
            TokenResponse tokenResponse = generateAccessToken();
            
            if (tokenResponse == null || String.isBlank(tokenResponse.access_token)) {
                throw new SharePointAuthException('Failed to generate access token');
            }
            
            // Persist token in metadata for future use
            updateSharePointAccessToken(tokenResponse);
            
            return tokenResponse.access_token;
        } catch (Exception e) {
            System.debug('Error in getAccessToken: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new SharePointAuthException('Failed to get SharePoint access token: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Validates if the cached token in metadata is still valid
     * Checks for token existence and age (must be less than 1 hour old)
     * @return: true if cached token exists and is less than 1 hour old
     */
    @SuppressWarnings('sf:ApexCRUDViolation')
    private static Boolean isTokenValid() {
        try {
            List<SharePoint_Configuration__mdt> configList = [
                SELECT Access_Token__c, Token_Generated_Time__c 
                FROM SharePoint_Configuration__mdt 
                WHERE DeveloperName = :CONFIG_NAME 
                LIMIT 1
            ];
            
            if (configList.isEmpty()) {
                System.debug('No cached token found in metadata');
                return false;
            }
            
            SharePoint_Configuration__mdt config = configList[0];
            
            if (String.isBlank(config.Access_Token__c) || config.Token_Generated_Time__c == null) {
                System.debug('Token or timestamp missing in metadata');
                return false;
            }
            
            // Calculate time difference (Token_Generated_Time__c is DateTime)
            Long currentTimeMs = System.currentTimeMillis();
            Long generatedTimeMs = config.Token_Generated_Time__c.getTime();
            Long timeDiffMs = currentTimeMs - generatedTimeMs;
            
            // Token is valid if less than 1 hour old
            Boolean isValid = timeDiffMs < TOKEN_EXPIRY_TIME_MS;
            
            if (!isValid) {
                System.debug('Cached token expired. Age in ms: ' + timeDiffMs + ' (max: ' + TOKEN_EXPIRY_TIME_MS + ')');
            } else {
                System.debug('Cached token is valid. Age in ms: ' + timeDiffMs + ' / ' + TOKEN_EXPIRY_TIME_MS);
            }
            
            return isValid;
        } catch (Exception e) {
            System.debug('Error checking token validity: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description: Retrieves the stored token from metadata
     * Reads from custom metadata type SharePoint_Configuration.Default
     * @return: Full access token
     */
    @SuppressWarnings('sf:ApexCRUDViolation')
    //private static String getStoredToken() {
    public static String getStoredToken() {
        try {
            List<SharePoint_Configuration__mdt> configList = [
                SELECT Access_Token__c
                FROM SharePoint_Configuration__mdt
                WHERE DeveloperName = :CONFIG_NAME
                LIMIT 1
            ];
            
            if (configList.isEmpty() || String.isBlank(configList[0].Access_Token__c)) {
                return null;
            }
            
            return configList[0].Access_Token__c;
        } catch (Exception e) {
            System.debug('Error retrieving stored token: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description: Stores the new token in custom metadata type for future use
     * Uses Metadata API to update SharePoint_Configuration.Default record
     * This approach matches the Fortellis metadata pattern for token persistence
     * @param tokenResponse: OAuth token response containing the new token
     */
    private static void updateSharePointAccessToken(TokenResponse tokenResponse) {
        try {
            // Create metadata instance for SharePoint_Configuration.Default
            Metadata.CustomMetadata metadataRecord = new Metadata.CustomMetadata();
            metadataRecord.fullName = 'SharePoint_Configuration.Default';
            metadataRecord.label = 'SharePoint Configuration';
            
            // Add token field value
            Metadata.CustomMetadataValue tokenField = new Metadata.CustomMetadataValue();
            tokenField.field = 'Access_Token__c';
            tokenField.value = tokenResponse.access_token;
            metadataRecord.values.add(tokenField);
            
            // Add timestamp - store DateTime directly, Metadata API handles conversion
            Metadata.CustomMetadataValue timeField = new Metadata.CustomMetadataValue();
            timeField.field = 'Token_Generated_Time__c';
            timeField.value = System.now();
            metadataRecord.values.add(timeField);
            
            // Deploy via Metadata API
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            mdContainer.addMetadata(metadataRecord);
            
            // Deploy asynchronously (fire and forget)
            if (!Test.isRunningTest()) {
                Metadata.Operations.enqueueDeployment(mdContainer, new SharePointTokenDeployCallback());
            }
            
            System.debug('Token update deployment initiated');
            System.debug('Token expires at: ' + System.now().addSeconds(3600).format());
            
        } catch (Exception e) {
            System.debug('Warning: Could not update token in metadata. ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * @description: Clears the cached token (useful for testing or forcing refresh)
     * Uses Metadata API to clear token fields in SharePoint_Configuration.Default
     */
    public static void clearCachedToken() {
        try {
            // Create metadata instance and clear token field
            Metadata.CustomMetadata metadataRecord = new Metadata.CustomMetadata();
            metadataRecord.fullName = 'SharePoint_Configuration.Default';
            
            Metadata.CustomMetadataValue tokenField = new Metadata.CustomMetadataValue();
            tokenField.field = 'Access_Token__c';
            tokenField.value = '';
            metadataRecord.values.add(tokenField);
            
            Metadata.CustomMetadataValue timeField = new Metadata.CustomMetadataValue();
            timeField.field = 'Token_Generated_Time__c';
            timeField.value = null;
            metadataRecord.values.add(timeField);
            
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            mdContainer.addMetadata(metadataRecord);
            
            if (!Test.isRunningTest()) {
                Metadata.Operations.enqueueDeployment(mdContainer, new SharePointTokenDeployCallback());
            }
            System.debug('Clear token deployment initiated');
            
        } catch (Exception e) {
            System.debug('Error clearing cached token: ' + e.getMessage());
        }
    }
    
    /**
     * @description: Generates a new OAuth access token via Azure AD
     * Uses Client Credentials grant type with configured client credentials
     * @return: TokenResponse object containing access_token and expires_in
     */
    private static TokenResponse generateAccessToken() {
        try {
            // Get configuration from metadata
            SharePointIntegrationConfig.SharePointConfig config = SharePointIntegrationConfig.getConfig();
            
            if (!config.isValid()) {
                throw new SharePointAuthException('SharePoint configuration is incomplete');
            }
            
            // Build token request
            String tokenEndpoint = TOKEN_ENDPOINT.replace('{tenantId}', config.tenantId);
            String requestBody = buildTokenRequestBody(config);
            
            // Make HTTP request to Azure OAuth endpoint
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(requestBody);
            req.setTimeout(30000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() != 200) {
                throw new SharePointAuthException(
                    'OAuth token generation failed. Status: ' + res.getStatusCode() + 
                    ' Body: ' + res.getBody()
                );
            }
            
            // Parse response
            TokenResponse tokenResponse = (TokenResponse) JSON.deserialize(res.getBody(), TokenResponse.class);
            return tokenResponse;
            
        } catch (Exception e) {
            System.debug('Error generating access token: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return null;
        }
    }
    
    /**
     * @description: Builds the OAuth token request body
     * Uses client credentials grant type
     * @param config: SharePoint configuration containing client credentials
     * @return: URL-encoded form data for token request
     */
    private static String buildTokenRequestBody(SharePointIntegrationConfig.SharePointConfig config) {
        String body = '';
        body += 'grant_type=' + EncodingUtil.urlEncode(GRANT_TYPE, 'UTF-8') + '&';
        body += 'client_id=' + EncodingUtil.urlEncode(config.clientId, 'UTF-8') + '&';
        body += 'client_secret=' + EncodingUtil.urlEncode(config.clientSecret, 'UTF-8') + '&';
        body += 'scope=' + EncodingUtil.urlEncode(SCOPE, 'UTF-8');
        return body;
    }
    
    /**
     * Wrapper class for JSON deserialization of Azure OAuth token response
     */
    public class TokenResponse {
        public String token_type { get; set; }
        public Integer expires_in { get; set; }
        public String ext_expires_in { get; set; }
        public String access_token { get; set; }
    }
    
    /**
     * @description: Custom exception for SharePoint authentication errors
     */
    public class SharePointAuthException extends Exception {}
    
    /**
     * @description: Callback handler for Metadata API deployments
     * Logs deployment status (success or failure) for token updates
     */
    public class SharePointTokenDeployCallback implements Metadata.DeployCallback {
        public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
            if (result.done) {
                System.debug('Token metadata deployed successfully');
            } else {
                System.debug('Token metadata deployment failed');
                if (result.details != null && result.details.componentFailures != null) {
                    System.debug('Deploy failures: ' + result.details.componentFailures);
                }
            }
        }
    }
}