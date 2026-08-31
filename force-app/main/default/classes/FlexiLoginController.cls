public with sharing class FlexiLoginController {
    
    @AuraEnabled
    public static String handleSiteLogin(String username, String password) {
        String result = null;
        try {
            ApexPages.PageReference pageRefLogin = Site.login(username, password, '');
            result = (pageRefLogin != null) ? pageRefLogin.getUrl() : null;
        } catch (Exception ex) {
            result = ex.getMessage();
        }
        return result;
    }
    
    @AuraEnabled
    public static String handlePasswordReset(String username) {
        try {
            Boolean resetSuccess = Site.forgotPassword(username);
            if (resetSuccess) {
                return 'success';
            } else {
                return 'error';
            }
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
}