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

    // ─── "Post to Monday" switch + preference ────────────────────────────────

    @AuraEnabled
    public static MondayService.MondayPrefs getMondayPrefs() {
        try {
            return MondayService.getPrefs();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static MondayService.MondayPrefs setMondayPostByDefault(Boolean postByDefault) {
        try {
            return MondayService.setPostByDefault(postByDefault);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static MondayService.TaskMondayState getTaskMondayState(String taskId) {
        try {
            return MondayService.getTaskState(taskId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Called after Clarity Work saves a task. Monday problems come back in the state (status 'Error'), not as exceptions.
    @AuraEnabled
    public static MondayService.TaskMondayState syncTaskToMonday(String taskId, Boolean enabled) {
        try {
            return MondayService.syncTask(taskId, enabled);
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
