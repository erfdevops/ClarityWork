/**
 * Clarity Work ↔ Monday.com rules: connecting a user's board (column detection),
 * and creating a Monday item from a Task.
 * Callouts always run before DML in each method — Apex forbids callouts after
 * uncommitted DML in the same transaction.
 */
public with sharing class MondayService {

    public static final String DESC_COLUMN_TITLE = 'Description';
    public static final String LINK_COLUMN_TITLE = 'Clarity Work';

    // Clarity value → candidate Monday labels; the first one that exists on the board wins
    private static final Map<String, List<String>> STATUS_LABELS = new Map<String, List<String>>{
        'Queue'       => new List<String>{ 'Not Started', 'To Do', 'Queue' },
        'In Progress' => new List<String>{ 'Working on it', 'In Progress' },
        'Complete'    => new List<String>{ 'Done', 'Complete', 'Completed' }
    };
    private static final Map<String, List<String>> PRIORITY_LABELS = new Map<String, List<String>>{
        'High'   => new List<String>{ 'High', 'Critical' },
        'Normal' => new List<String>{ 'Medium', 'Normal' },
        'Low'    => new List<String>{ 'Low' }
    };

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option(String label, String value) { this.label = label; this.value = value; }
    }

    public class MondayContext {
        @AuraEnabled public Boolean connected = false;
        @AuraEnabled public String  accountName;
        @AuraEnabled public String  error;
        @AuraEnabled public String  boardId;
        @AuraEnabled public String  boardName;
        @AuraEnabled public String  boardUrl;
        @AuraEnabled public String  defaultGroupId;
        @AuraEnabled public List<Option> groups = new List<Option>();
    }

    // The running user's connected board, or null
    public static Monday_Board__c getMyBoard() {
        List<Monday_Board__c> boards = [
            SELECT Id, Name, Board_Id__c, Board_URL__c, Status_Column_Id__c, Priority_Column_Id__c,
                   Date_Column_Id__c, Description_Column_Id__c, Link_Column_Id__c, Owner_Column_Id__c,
                   Default_Group_Id__c, Status_Labels__c, Priority_Labels__c
            FROM Monday_Board__c
            WHERE OwnerId = :UserInfo.getUserId()
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return boards.isEmpty() ? null : boards[0];
    }

    // Connection status + board + groups for the New Task modal. Never throws.
    public static MondayContext getContext() {
        MondayContext ctx = new MondayContext();
        try {
            ctx.accountName = (String) MondayApiClient.getMe().get('name');
            ctx.connected = true;
        } catch (Exception e) {
            ctx.error = 'Your Monday.com account is not connected. (' + e.getMessage() + ')';
            return ctx;
        }
        Monday_Board__c rec = getMyBoard();
        if (rec == null) return ctx;
        try {
            Map<String, Object> board = MondayApiClient.getBoard(rec.Board_Id__c);
            if (board == null) {
                ctx.error = 'Your Monday.com board "' + rec.Name + '" was not found or is no longer shared with you.';
                return ctx;
            }
            applyBoard(ctx, rec, board);
        } catch (Exception e) {
            ctx.error = e.getMessage();
        }
        return ctx;
    }

    // Active boards the user can see — their own boards first
    public static List<Option> getMyBoards() {
        Map<String, Object> data = MondayApiClient.getMeAndBoards();
        String meId = String.valueOf(((Map<String, Object>) data.get('me')).get('id'));
        List<Option> owned = new List<Option>();
        List<Option> others = new List<Option>();
        for (Object o : (List<Object>) data.get('boards')) {
            Map<String, Object> b = (Map<String, Object>) o;
            if (b.get('type') != null && b.get('type') != 'board') continue; // skip sub-item boards and docs
            Option opt = new Option((String) b.get('name'), String.valueOf(b.get('id')));
            Boolean mine = false;
            for (Object ow : (List<Object>) b.get('owners')) {
                if (String.valueOf(((Map<String, Object>) ow).get('id')) == meId) mine = true;
            }
            if (mine) owned.add(opt); else others.add(opt);
        }
        owned.addAll(others);
        return owned;
    }

    // Detects the board's columns (adding Description / Clarity Work link columns if missing)
    // and saves them as the running user's Monday_Board__c.
    public static MondayContext connectBoard(String boardId) {
        if (String.isBlank(boardId)) throw new MondayApiClient.MondayException('Choose a Monday.com board.');
        boardId = boardId.trim();

        // ── 1. Callouts ──────────────────────────────────────────────────────
        Map<String, Object> board = MondayApiClient.getBoard(boardId);
        if (board == null) {
            throw new MondayApiClient.MondayException('Board ' + boardId + ' was not found or is not shared with you.');
        }
        Monday_Board__c rec = new Monday_Board__c(
            Name        = ((String) board.get('name')).left(80),
            Board_Id__c = boardId,
            Board_URL__c = (String) board.get('url')
        );
        for (Object o : (List<Object>) board.get('columns')) {
            Map<String, Object> c = (Map<String, Object>) o;
            String type  = (String) c.get('type');
            String title = ((String) c.get('title')).toLowerCase();
            String id    = (String) c.get('id');
            if (type == 'status') {
                if (title.contains('priority')) {
                    if (rec.Priority_Column_Id__c == null) {
                        rec.Priority_Column_Id__c = id;
                        rec.Priority_Labels__c = JSON.serialize(labelsOf(c));
                    }
                } else if (rec.Status_Column_Id__c == null || title == 'status') {
                    rec.Status_Column_Id__c = id;
                    rec.Status_Labels__c = JSON.serialize(labelsOf(c));
                }
            } else if (type == 'date') {
                if (rec.Date_Column_Id__c == null || title.contains('due')) rec.Date_Column_Id__c = id;
            } else if (type == 'long_text' && title == DESC_COLUMN_TITLE.toLowerCase()) {
                // Only a column actually titled "Description" — other long-text columns
                // (e.g. "Measure of Success") hold the user's own content and must not be overwritten.
                rec.Description_Column_Id__c = id;
            } else if (type == 'people' && rec.Owner_Column_Id__c == null
                       && (title.contains('owner') || title.contains('assign') || title == 'person')) {
                rec.Owner_Column_Id__c = id;
            } else if (type == 'link' && title == LINK_COLUMN_TITLE.toLowerCase()) {
                rec.Link_Column_Id__c = id;
            }
        }
        if (rec.Description_Column_Id__c == null) {
            rec.Description_Column_Id__c = MondayApiClient.createColumn(boardId, DESC_COLUMN_TITLE, 'long_text');
        }
        if (rec.Link_Column_Id__c == null) {
            rec.Link_Column_Id__c = MondayApiClient.createColumn(boardId, LINK_COLUMN_TITLE, 'link');
        }

        // ── 2. DML — one board per user, so replace any previous connection ──
        List<Monday_Board__c> existing = [
            SELECT Id, Board_Id__c, Default_Group_Id__c FROM Monday_Board__c
            WHERE OwnerId = :UserInfo.getUserId()
        ];
        List<Monday_Board__c> toDelete = new List<Monday_Board__c>();
        for (Monday_Board__c e : existing) {
            if (rec.Id == null && e.Board_Id__c == boardId) {
                rec.Id = e.Id;
                rec.Default_Group_Id__c = e.Default_Group_Id__c;
            } else {
                toDelete.add(e);
            }
        }
        upsert rec;
        if (!toDelete.isEmpty()) delete toDelete;

        MondayContext ctx = new MondayContext();
        ctx.connected = true;
        applyBoard(ctx, rec, board);
        return ctx;
    }

    // Creates the Monday item for a task on the running user's board and links the two.
    // Monday failures are recorded on the task (Monday_Sync_Status__c = 'Error') rather than thrown,
    // so the Salesforce task is never lost.
    public static Task createItemForTask(Id taskId, String groupId) {
        Monday_Board__c board = getMyBoard();
        if (board == null) throw new MondayApiClient.MondayException('Connect a Monday.com board first.');
        if (String.isBlank(groupId)) throw new MondayApiClient.MondayException('Choose a Monday.com group.');
        Task t = taskForSync(taskId);

        // ── 1. Callouts ──────────────────────────────────────────────────────
        Task upd = new Task(Id = taskId, Monday_Board_Id__c = board.Board_Id__c);
        try {
            postItem(t, board, groupId, upd);
        } catch (Exception e) {
            recordError(upd, e);
        }

        // ── 2. DML ───────────────────────────────────────────────────────────
        update upd;
        if (board.Default_Group_Id__c != groupId) {
            update new Monday_Board__c(Id = board.Id, Default_Group_Id__c = groupId);
        }
        return upd;
    }

    // Creates the Monday item in the group named after the task's SMART goal (its Initiative name),
    // creating that group on the user's board the first time the goal is used.
    // Group names match ignoring case and extra spaces, so renaming a Monday group to the goal's
    // name links it. Uses the task's primary goal (Task.Smart_Goal__c); one item per linked goal
    // (Task_Smart_Goal__c) is a later step.
    public static Task createItemInGoalGroup(Id taskId) {
        Monday_Board__c board = getMyBoard();
        if (board == null) throw new MondayApiClient.MondayException('Connect a Monday.com board first.');
        Task t = taskForSync(taskId);
        String goalName = t.Smart_Goal__c == null ? null : t.Smart_Goal__r.Initiative_Name__c;
        if (String.isBlank(goalName)) {
            throw new MondayApiClient.MondayException('This task has no SMART goal, so there is no goal group to post it to.');
        }

        // ── 1. Callouts ──────────────────────────────────────────────────────
        Task upd = new Task(Id = taskId, Monday_Board_Id__c = board.Board_Id__c);
        try {
            Map<String, Object> mondayBoard = MondayApiClient.getBoard(board.Board_Id__c);
            if (mondayBoard == null) {
                throw new MondayApiClient.MondayException('Monday.com board ' + board.Board_Id__c + ' was not found or is not shared.');
            }
            String groupId = groupIdFor(mondayBoard, goalName);
            if (groupId == null) groupId = MondayApiClient.createGroup(board.Board_Id__c, goalName.trim().left(255));
            postItem(t, board, groupId, upd);
        } catch (Exception e) {
            recordError(upd, e);
        }

        // ── 2. DML ───────────────────────────────────────────────────────────
        update upd;
        return upd;
    }

    // Id of the board group whose title matches the goal name (case/spacing-insensitive), or null
    @TestVisible
    private static String groupIdFor(Map<String, Object> mondayBoard, String goalName) {
        String want = normalize(goalName);
        for (Object o : (List<Object>) mondayBoard.get('groups')) {
            Map<String, Object> g = (Map<String, Object>) o;
            if (normalize((String) g.get('title')) == want) return (String) g.get('id');
        }
        return null;
    }

    private static String normalize(String s) {
        return s == null ? '' : s.trim().replaceAll('\\s+', ' ').toLowerCase();
    }

    private static Task taskForSync(Id taskId) {
        Task t = [
            SELECT Id, Subject, Description, ActivityDate, Kanban_Status__c, Priority, Monday_Item_Id__c,
                   OwnerId, Smart_Goal__c, Smart_Goal__r.Initiative_Name__c
            FROM Task WHERE Id = :taskId LIMIT 1
        ];
        if (String.isNotBlank(t.Monday_Item_Id__c)) {
            throw new MondayApiClient.MondayException('This task is already linked to a Monday.com item.');
        }
        return t;
    }

    // Callouts only: looks up the owner's Monday user, creates the item, and fills the link fields on upd
    private static void postItem(Task t, Monday_Board__c board, String groupId, Task upd) {
        String mondayUserId = null;
        if (String.isNotBlank(board.Owner_Column_Id__c)) {
            try {
                // Task.Owner is polymorphic (Name), so read the email from User directly
                List<User> owners = [SELECT Email FROM User WHERE Id = :t.OwnerId LIMIT 1];
                mondayUserId = owners.isEmpty() ? null : MondayApiClient.findUserIdByEmail(owners[0].Email);
            } catch (Exception e) {
                mondayUserId = null; // an unassigned item is better than no item
            }
        }
        Map<String, Object> item = MondayApiClient.createItem(
            board.Board_Id__c, groupId, t.Subject, JSON.serialize(columnValues(t, board, mondayUserId))
        );
        upd.Monday_Item_Id__c     = String.valueOf(item.get('id'));
        upd.Monday_Item_URL__c    = (String) item.get('url');
        upd.Monday_Sync_Status__c = 'Synced';
        upd.Monday_Sync_Error__c  = null;
        upd.Monday_Last_Synced__c = System.now();
    }

    private static void recordError(Task upd, Exception e) {
        upd.Monday_Sync_Status__c = 'Error';
        upd.Monday_Sync_Error__c  = e.getMessage().left(255);
    }

    // Monday column_values payload for a task, using only columns/labels that exist on the board
    @TestVisible
    private static Map<String, Object> columnValues(Task t, Monday_Board__c board, String mondayUserId) {
        Map<String, Object> vals = new Map<String, Object>();
        if (String.isNotBlank(mondayUserId) && String.isNotBlank(board.Owner_Column_Id__c)) {
            vals.put(board.Owner_Column_Id__c, new Map<String, Object>{ 'personsAndTeams' => new List<Object>{
                new Map<String, Object>{ 'id' => Long.valueOf(mondayUserId), 'kind' => 'person' } } });
        }
        if (t.ActivityDate != null && String.isNotBlank(board.Date_Column_Id__c)) {
            vals.put(board.Date_Column_Id__c, new Map<String, Object>{ 'date' => String.valueOf(t.ActivityDate) });
        }
        if (String.isNotBlank(t.Description) && String.isNotBlank(board.Description_Column_Id__c)) {
            vals.put(board.Description_Column_Id__c, new Map<String, Object>{ 'text' => t.Description.left(2000) });
        }
        if (String.isNotBlank(board.Link_Column_Id__c)) {
            vals.put(board.Link_Column_Id__c, new Map<String, Object>{
                'url'  => URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/Task/' + t.Id + '/view',
                'text' => 'Open in Clarity Work'
            });
        }
        String status = matchLabel(STATUS_LABELS.get(t.Kanban_Status__c), board.Status_Labels__c);
        if (status != null && String.isNotBlank(board.Status_Column_Id__c)) {
            vals.put(board.Status_Column_Id__c, new Map<String, Object>{ 'label' => status });
        }
        String priority = matchLabel(PRIORITY_LABELS.get(t.Priority), board.Priority_Labels__c);
        if (priority != null && String.isNotBlank(board.Priority_Column_Id__c)) {
            vals.put(board.Priority_Column_Id__c, new Map<String, Object>{ 'label' => priority });
        }
        return vals;
    }

    // First candidate present on the board (case-insensitive), returned with the board's own spelling
    @TestVisible
    private static String matchLabel(List<String> candidates, String boardLabelsJson) {
        if (candidates == null || String.isBlank(boardLabelsJson)) return null;
        Map<String, String> byLower = new Map<String, String>();
        for (Object o : (List<Object>) JSON.deserializeUntyped(boardLabelsJson)) {
            byLower.put(String.valueOf(o).toLowerCase(), String.valueOf(o));
        }
        for (String c : candidates) {
            if (byLower.containsKey(c.toLowerCase())) return byLower.get(c.toLowerCase());
        }
        return null;
    }

    // Non-blank labels from a status column's settings_str ({"labels":{"0":"Working on it",...}})
    private static List<String> labelsOf(Map<String, Object> column) {
        List<String> labels = new List<String>();
        String settings = (String) column.get('settings_str');
        if (String.isBlank(settings)) return labels;
        Object raw = ((Map<String, Object>) JSON.deserializeUntyped(settings)).get('labels');
        if (raw instanceof Map<String, Object>) {
            for (Object v : ((Map<String, Object>) raw).values()) {
                if (v != null && String.isNotBlank(String.valueOf(v))) labels.add(String.valueOf(v));
            }
        }
        return labels;
    }

    private static void applyBoard(MondayContext ctx, Monday_Board__c rec, Map<String, Object> board) {
        ctx.boardId        = rec.Board_Id__c;
        ctx.boardName      = (String) board.get('name');
        ctx.boardUrl       = (String) board.get('url');
        ctx.defaultGroupId = rec.Default_Group_Id__c;
        for (Object o : (List<Object>) board.get('groups')) {
            Map<String, Object> g = (Map<String, Object>) o;
            ctx.groups.add(new Option((String) g.get('title'), (String) g.get('id')));
        }
    }
}
