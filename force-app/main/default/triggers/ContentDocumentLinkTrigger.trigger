/**
 * @description       : This class is the Trigger Handler for the ContentDocumentLink object
 * @author            : Pablo Castro 12-09-2025
 * @group             : 
 * @last modified on  : 12-09-2025
 * @last modified by  : Pablo Castro
**/

trigger ContentDocumentLinkTrigger on ContentDocumentLink (before insert) {
    for (ContentDocumentLink newContentDocumentLink : Trigger.new) {
        newContentDocumentLink.Visibility = 'AllUsers';
    }
}