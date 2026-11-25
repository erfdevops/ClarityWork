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
        Id userId = UserInfo.getUserId();
        List<Monday_Board__c> boards = Database.query(BOARD_QUERY + ' WHERE OwnerId = :userId ORDER BY LastModifiedDate DESC LIMIT 1');
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
        if (String.isNotBlank(t.Monday_Item_Id__c)) {
            throw new MondayApiClient.MondayException('This task is already linked to a Monday.com item.');
        }

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

    // ─── Clarity Work "Post to Monday" switch ─────────────────────────────────

    public static final String NO_GOAL_GROUP = 'No SMART Goal';

    public class MondayPrefs {
        @AuraEnabled public Boolean hasBoard = false;
        @AuraEnabled public String  boardName;
        @AuraEnabled public String  boardUrl;
        @AuraEnabled public Boolean postByDefault = true;
    }

    public class TaskMondayState {
        @AuraEnabled public Boolean enabled = false;
        @AuraEnabled public String  status;
        @AuraEnabled public String  url;
        @AuraEnabled public String  error;
        @AuraEnabled public List<ItemLink> items = new List<ItemLink>();
    }

    // One posted Monday item (one per SMART goal on the task)
    public class ItemLink {
        @AuraEnabled public String goal;
        @AuraEnabled public String url;
        @AuraEnabled public String status;
        @AuraEnabled public String error;
    }

    // The running user's Monday preferences (no callouts)
    public static MondayPrefs getPrefs() {
        MondayPrefs p = new MondayPrefs();
        Monday_Board__c b = getMyBoard();
        if (b != null) {
            p.hasBoard      = true;
            p.boardName     = b.Name;
            p.boardUrl      = b.Board_URL__c;
            p.postByDefault = b.Post_To_Monday_By_Default__c;
        }
        return p;
    }

    // Saves whether "Post to Monday" starts On for the user's new tasks
    public static MondayPrefs setPostByDefault(Boolean postByDefault) {
        Monday_Board__c b = getMyBoard();
        if (b == null) throw new MondayApiClient.MondayException('Connect a Monday.com board first.');
        update new Monday_Board__c(Id = b.Id, Post_To_Monday_By_Default__c = postByDefault == true);
        return getPrefs();
    }

    public static TaskMondayState getTaskState(Id taskId) {
        return stateOf(taskForSync(taskId));
    }

    // Called by Clarity Work after a task is saved.
    // enabled = false: records the choice and stops posting (existing Monday items are left as they are).
    // enabled = true: one Monday item per SMART goal on the task (Task_Smart_Goal__c, plus the primary
    //   Task.Smart_Goal__c), each in the group named after its goal (Initiative name; matched ignoring
    //   case/spacing, created if missing). No goals → one item in the "No SMART Goal" group.
    //   Existing items are updated (name, columns) and moved if needed; deleted ones are recreated;
    //   items for goals removed from the task are archived in Monday.
    // Items go on the task OWNER's board. Each item is tracked by a Monday_Item_Link__c; the Task's
    // Monday_* fields summarize the first item and the overall status. Failures are recorded, never thrown.
    public static TaskMondayState syncTask(Id taskId, Boolean enabled) {
        Task t = taskForSync(taskId);
        Task upd = new Task(Id = taskId, Post_To_Monday__c = (enabled == true));

        if (enabled != true) {
            if (t.Post_To_Monday__c) update upd;
            t.Post_To_Monday__c = false;
            return stateOf(t);
        }

        Monday_Board__c board = new BoardLookup().forUser(t.OwnerId);
        if (board == null) {
            upd.Monday_Sync_Status__c = 'Not Connected';
            upd.Monday_Sync_Error__c  = 'The task owner has not connected a Monday.com board.';
            update upd;
            return stateOf(taskForSync(taskId));
        }

        List<Goal> goals = goalsOf(t);
        Map<String, Monday_Item_Link__c> existing = new Map<String, Monday_Item_Link__c>();
        for (Monday_Item_Link__c l : linksOf(taskId)) existing.put(keyOf(l.Goal__c), l);
        // A task posted before per-goal links keeps its item as the first goal's link
        if (existing.isEmpty() && String.isNotBlank(t.Monday_Item_Id__c)) {
            existing.put(goals[0].key, new Monday_Item_Link__c(
                Task_Id__c = taskId, Goal__c = goals[0].id, Board_Id__c = t.Monday_Board_Id__c,
                Item_Id__c = t.Monday_Item_Id__c, Item_URL__c = t.Monday_Item_URL__c));
        }

        List<Monday_Item_Link__c> toUpsert = new List<Monday_Item_Link__c>();
        List<Monday_Item_Link__c> toDelete = new List<Monday_Item_Link__c>();
        String boardError;

        // ── 1. Callouts ──────────────────────────────────────────────────────
        Map<String, Object> mondayBoard;
        String ownerId;
        try {
            mondayBoard = MondayApiClient.getBoard(board.Board_Id__c);
            if (mondayBoard == null) {
                throw new MondayApiClient.MondayException('Monday.com board "' + board.Name + '" was not found or is not shared.');
            }
            ownerId = ownerMondayId(t, board);
        } catch (Exception e) {
            boardError = e.getMessage().left(255);
        }

        if (boardError == null) {
            Map<String, String> groupIds = new Map<String, String>();
            for (Goal g : goals) {
                Monday_Item_Link__c link = existing.remove(g.key);
                if (link == null) link = new Monday_Item_Link__c(Task_Id__c = taskId, Goal__c = g.id);
                try {
                    String groupKey = normalize(g.name);
                    String groupId = groupIds.get(groupKey);
                    if (groupId == null) groupId = groupIdFor(mondayBoard, g.name);
                    if (groupId == null) groupId = MondayApiClient.createGroup(board.Board_Id__c, g.name.trim().left(255));
                    groupIds.put(groupKey, groupId);

                    // An item left on a previous owner's board is archived there and recreated on this one
                    if (String.isNotBlank(link.Item_Id__c) && link.Board_Id__c != board.Board_Id__c) {
                        archiveQuietly(link.Item_Id__c);
                        link.Item_Id__c = null;
                    }
                    String currentGroup = String.isNotBlank(link.Item_Id__c) ? MondayApiClient.getItemGroupId(link.Item_Id__c) : null;
                    if (currentGroup == null) {
                        Map<String, Object> item = MondayApiClient.createItem(
                            board.Board_Id__c, groupId, t.Subject, JSON.serialize(columnValues(t, board, ownerId)));
                        link.Item_Id__c  = String.valueOf(item.get('id'));
                        link.Item_URL__c = (String) item.get('url');
                    } else {
                        Map<String, Object> vals = columnValues(t, board, ownerId);
                        vals.put('name', t.Subject);
                        MondayApiClient.updateItem(board.Board_Id__c, link.Item_Id__c, JSON.serialize(vals));
                        if (currentGroup != groupId) MondayApiClient.moveItemToGroup(link.Item_Id__c, groupId);
                    }
                    link.Board_Id__c    = board.Board_Id__c;
                    link.Sync_Status__c = 'Synced';
                    link.Sync_Error__c  = null;
                    link.Last_Synced__c = System.now();
                } catch (Exception e) {
                    link.Board_Id__c    = board.Board_Id__c;
                    link.Sync_Status__c = 'Error';
                    link.Sync_Error__c  = e.getMessage().left(255);
                }
                toUpsert.add(link);
            }
            // Goals removed from the task: archive their items
            for (Monday_Item_Link__c old : existing.values()) {
                if (String.isNotBlank(old.Item_Id__c)) archiveQuietly(old.Item_Id__c);
                if (old.Id != null) toDelete.add(old);
            }
        }

        // ── 2. DML ───────────────────────────────────────────────────────────
        if (boardError != null) {
            upd.Monday_Sync_Status__c = 'Error';
            upd.Monday_Sync_Error__c  = boardError;
        } else {
            Monday_Item_Link__c first = toUpsert[0];
            upd.Monday_Board_Id__c    = board.Board_Id__c;
            upd.Monday_Item_Id__c     = first.Item_Id__c;
            upd.Monday_Item_URL__c    = first.Item_URL__c;
            upd.Monday_Sync_Status__c = 'Synced';
            upd.Monday_Sync_Error__c  = null;
            for (Monday_Item_Link__c l : toUpsert) {
                if (l.Sync_Status__c == 'Error') {
                    upd.Monday_Sync_Status__c = 'Error';
                    upd.Monday_Sync_Error__c  = l.Sync_Error__c;
                    break;
                }
            }
            if (upd.Monday_Sync_Status__c == 'Synced') upd.Monday_Last_Synced__c = System.now();
            upsert toUpsert;
            if (!toDelete.isEmpty()) delete toDelete;
        }
        update upd;
        return stateOf(taskForSync(taskId));
    }

    private class Goal {
        Id id; String name; String key;
        Goal(Id id, String name) { this.id = id; this.name = name; this.key = keyOf(id); }
    }

    private static String keyOf(Id goalId) {
        return goalId == null ? 'none' : String.valueOf(goalId).left(15);
    }

    // The task's goals, primary first, without duplicates; [No SMART Goal] when there are none
    private static List<Goal> goalsOf(Task t) {
        List<Goal> goals = new List<Goal>();
        Set<String> seen = new Set<String>();
        if (t.Smart_Goal__c != null && String.isNotBlank(t.Smart_Goal__r.Initiative_Name__c)) {
            goals.add(new Goal(t.Smart_Goal__c, t.Smart_Goal__r.Initiative_Name__c));
            seen.add(keyOf(t.Smart_Goal__c));
        }
        String id18 = String.valueOf(t.Id);
        for (Task_Smart_Goal__c j : [
            SELECT Smart_Goal__c, Smart_Goal__r.Initiative_Name__c FROM Task_Smart_Goal__c
            WHERE (Task__c = :id18 OR Task__c = :id18.left(15)) AND Smart_Goal__c != null
            ORDER BY CreatedDate ASC
        ]) {
            if (String.isBlank(j.Smart_Goal__r.Initiative_Name__c) || seen.contains(keyOf(j.Smart_Goal__c))) continue;
            goals.add(new Goal(j.Smart_Goal__c, j.Smart_Goal__r.Initiative_Name__c));
            seen.add(keyOf(j.Smart_Goal__c));
        }
        if (goals.isEmpty()) goals.add(new Goal(null, NO_GOAL_GROUP));
        return goals;
    }

    private static List<Monday_Item_Link__c> linksOf(Id taskId) {
        return [
            SELECT Id, Task_Id__c, Goal__c, Goal__r.Initiative_Name__c, Board_Id__c, Item_Id__c, Item_URL__c,
                   Sync_Status__c, Sync_Error__c, Last_Synced__c
            FROM Monday_Item_Link__c WHERE Task_Id__c = :String.valueOf(taskId)
            ORDER BY CreatedDate ASC
        ];
    }

    private static void archiveQuietly(String itemId) {
        try { MondayApiClient.archiveItem(itemId); } catch (Exception e) { /* already gone in Monday */ }
    }

    private static TaskMondayState stateOf(Task t) {
        TaskMondayState s = new TaskMondayState();
        s.enabled = t.Post_To_Monday__c;
        s.status  = t.Monday_Sync_Status__c;
        s.url     = t.Monday_Item_URL__c;
        s.error   = t.Monday_Sync_Error__c;
        for (Monday_Item_Link__c l : linksOf(t.Id)) {
            ItemLink i = new ItemLink();
            i.goal   = l.Goal__c == null ? NO_GOAL_GROUP : l.Goal__r.Initiative_Name__c;
            i.url    = l.Item_URL__c;
            i.status = l.Sync_Status__c;
            i.error  = l.Sync_Error__c;
            s.items.add(i);
        }
        return s;
    }

    // A task can be assigned to someone else, whose board record the running user cannot see
    // (Monday_Board__c is Private), so the owner's board is read without sharing.
    private without sharing class BoardLookup {
        Monday_Board__c forUser(Id userId) {
            List<Monday_Board__c> boards = Database.query(BOARD_QUERY + ' WHERE OwnerId = :userId ORDER BY LastModifiedDate DESC LIMIT 1');
            return boards.isEmpty() ? null : boards[0];
        }
    }

    private static final String BOARD_QUERY =
        'SELECT Id, Name, Board_Id__c, Board_URL__c, Status_Column_Id__c, Priority_Column_Id__c, ' +
        'Date_Column_Id__c, Description_Column_Id__c, Link_Column_Id__c, Owner_Column_Id__c, ' +
        'Default_Group_Id__c, Status_Labels__c, Priority_Labels__c, Post_To_Monday_By_Default__c ' +
        'FROM Monday_Board__c';

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
        return [
            SELECT Id, Subject, Description, ActivityDate, Kanban_Status__c, Priority, OwnerId,
                   Smart_Goal__c, Smart_Goal__r.Initiative_Name__c, Post_To_Monday__c,
                   Monday_Item_Id__c, Monday_Board_Id__c, Monday_Item_URL__c, Monday_Sync_Status__c, Monday_Sync_Error__c
            FROM Task WHERE Id = :taskId LIMIT 1
        ];
    }

    // Monday user Id of the task owner (matched by email), or null; never throws
    private static String ownerMondayId(Task t, Monday_Board__c board) {
        if (String.isBlank(board.Owner_Column_Id__c)) return null;
        try {
            // Task.Owner is polymorphic (Name), so read the email from User directly
            List<User> owners = [SELECT Email FROM User WHERE Id = :t.OwnerId LIMIT 1];
            return owners.isEmpty() ? null : MondayApiClient.findUserIdByEmail(owners[0].Email);
        } catch (Exception e) {
            return null; // an unassigned item is better than no item
        }
    }

    // Callouts only: creates the item (assigned to the owner) and fills the link fields on upd
    private static void postItem(Task t, Monday_Board__c board, String groupId, Task upd) {
        Map<String, Object> item = MondayApiClient.createItem(
            board.Board_Id__c, groupId, t.Subject, JSON.serialize(columnValues(t, board, ownerMondayId(t, board)))
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
