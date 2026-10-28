/**
 * LWC entry points for the Clarity Work ↔ Monday.com integration (see MondayService).
 * Kept separate from TaskKanbanController so the Monday work stays in its own files
 * on the monday-integration branch and can be removed without touching shared code.
 */
public with sharing class MondayController {

    // Non-cacheable: each call checks the live Monday connection.
    @AuraEnabled
    public static MondayService.MondayContext getMondayContext() {
        return MondayService.getContext();
    }

    @AuraEnabled
    public static List<MondayService.Option> getMyMondayBoards() {
        try {
            return MondayService.getMyBoards();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static MondayService.MondayContext connectMondayBoard(String boardId) {
        try {
            return MondayService.connectBoard(boardId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Returns the task's Monday fields; Monday_Sync_Status__c = 'Error' when the item could not be created
    @AuraEnabled
    public static Task createMondayItem(String taskId, String groupId) {
        try {
            return MondayService.createItemForTask(taskId, groupId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
