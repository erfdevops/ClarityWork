public class TaskSharePointSyncJob implements Queueable, Database.AllowsCallouts {

    private String taskId;

    public TaskSharePointSyncJob(String taskId) {
        this.taskId = taskId;
    }

    public void execute(QueueableContext context) {
        // ── 1. SOQL only — no DML yet ────────────────────────────────────────
        SharePointIntegrationConfig.SharePointConfig config = SharePointIntegrationConfig.getConfig();
        if (String.isBlank(config.driveId)) return;

        Task t = [SELECT Task_Number__c, Subject FROM Task WHERE Id = :taskId LIMIT 1];
        String folderPath = 'Clarity Work/' + t.Task_Number__c + ' - ' + t.Subject;

        List<ContentDocumentLink> fileLinks = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :taskId
        ];
        if (fileLinks.isEmpty()) return;

        Set<Id> versionIds = new Set<Id>();
        for (ContentDocumentLink link : fileLinks) {
            versionIds.add(link.ContentDocument.LatestPublishedVersionId);
        }
        Map<Id, ContentVersion> versionMap = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId, VersionData, Title, FileExtension
            FROM ContentVersion
            WHERE Id IN :versionIds
        ]);

        // ── 2. Callout: fetch token directly — no caching DML ─────────────────
        String accessToken = fetchToken(config);
        if (String.isBlank(accessToken)) return;

        // ── 3. Callouts: upload each file — still no DML ──────────────────────
        List<SharePoint_Sync__c> syncRecords = new List<SharePoint_Sync__c>();
        List<Id> documentsToDelete = new List<Id>();

        for (ContentDocumentLink link : fileLinks) {
            ContentVersion version = versionMap.get(link.ContentDocument.LatestPublishedVersionId);
            if (version == null) continue;

            String fileName = version.Title + '.' + version.FileExtension;
            SharePointFileUploadService.UploadResponse resp =
                SharePointFileUploadService.uploadFile(
                    config.driveId, folderPath, fileName, version.VersionData, accessToken
                );

            syncRecords.add(new SharePoint_Sync__c(
                File_Name__c         = resp.name,
                Folder_Name__c       = folderPath,
                SharePoint_URL__c    = resp.webUrl,
                Related_Record_Id__c = taskId
            ));
            documentsToDelete.add(link.ContentDocumentId);
        }

        // ── 4. DML — all callouts are finished ────────────────────────────────
        if (!syncRecords.isEmpty()) insert syncRecords;
        if (!documentsToDelete.isEmpty()) {
            delete [SELECT Id FROM ContentDocument WHERE Id IN :documentsToDelete];
        }
    }

    // Fetches a fresh OAuth token without touching metadata (no DML)
    private String fetchToken(SharePointIntegrationConfig.SharePointConfig config) {
        try {
            String endpoint = 'https://login.microsoftonline.com/' + config.tenantId + '/oauth2/v2.0/token';
            String body = 'grant_type=client_credentials'
                + '&client_id='     + EncodingUtil.urlEncode(config.clientId,     'UTF-8')
                + '&client_secret=' + EncodingUtil.urlEncode(config.clientSecret, 'UTF-8')
                + '&scope='         + EncodingUtil.urlEncode('https://graph.microsoft.com/.default', 'UTF-8');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(body);
            req.setTimeout(30000);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                System.debug('Token fetch failed: ' + res.getStatusCode() + ' ' + res.getBody());
                return null;
            }

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) parsed.get('access_token');
        } catch (Exception e) {
            System.debug('fetchToken error: ' + e.getMessage());
            return null;
        }
    }
}
