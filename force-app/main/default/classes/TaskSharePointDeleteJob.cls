public class TaskSharePointDeleteJob implements Queueable, Database.AllowsCallouts {

    private String taskId;

    public TaskSharePointDeleteJob(String taskId) {
        this.taskId = taskId;
    }

    public void execute(QueueableContext context) {
        // ── 1. SOQL: check for synced files ───────────────────────────────────
        List<SharePoint_Sync__c> syncRecords = [
            SELECT Id, Folder_Name__c
            FROM SharePoint_Sync__c
            WHERE Related_Record_Id__c = :taskId
            LIMIT 1
        ];

        if (syncRecords.isEmpty()) return;

        String folderPath = syncRecords[0].Folder_Name__c;

        SharePointIntegrationConfig.SharePointConfig config = SharePointIntegrationConfig.getConfig();
        if (String.isBlank(config.driveId)) return;

        // ── 2. Callout: fetch token ────────────────────────────────────────────
        String accessToken = fetchToken(config);
        if (String.isBlank(accessToken)) return;

        // ── 3. Callout: delete the SharePoint folder ──────────────────────────
        deleteFolder(config.driveId, folderPath, accessToken);

        // ── 4. DML: remove orphaned sync records ──────────────────────────────
        delete [SELECT Id FROM SharePoint_Sync__c WHERE Related_Record_Id__c = :taskId];
    }

    private void deleteFolder(String driveId, String folderPath, String accessToken) {
        try {
            String encodedPath = folderPath
                .replace(' ', '%20')
                .replace('&', '%26')
                .replace('#', '%23')
                .replace('+', '%2B');

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://graph.microsoft.com/v1.0/drives/' + driveId + '/root:/' + encodedPath);
            req.setMethod('DELETE');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setTimeout(30000);

            HttpResponse res = new Http().send(req);
            // 204 = deleted, 404 = folder never existed — both are fine
            if (res.getStatusCode() != 204 && res.getStatusCode() != 404) {
                System.debug('SharePoint folder delete failed: ' + res.getStatusCode() + ' ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('deleteFolder error: ' + e.getMessage());
        }
    }

    private String fetchToken(SharePointIntegrationConfig.SharePointConfig config) {
        try {
            String body = 'grant_type=client_credentials'
                + '&client_id='     + EncodingUtil.urlEncode(config.clientId,     'UTF-8')
                + '&client_secret=' + EncodingUtil.urlEncode(config.clientSecret, 'UTF-8')
                + '&scope='         + EncodingUtil.urlEncode('https://graph.microsoft.com/.default', 'UTF-8');

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://login.microsoftonline.com/' + config.tenantId + '/oauth2/v2.0/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(body);
            req.setTimeout(30000);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) return null;

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) parsed.get('access_token');
        } catch (Exception e) {
            System.debug('fetchToken error: ' + e.getMessage());
            return null;
        }
    }
}
