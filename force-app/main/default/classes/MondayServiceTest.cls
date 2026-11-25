@IsTest
private class MondayServiceTest {

    // Routes each GraphQL request to a canned Monday.com response
    private class MondayMock implements HttpCalloutMock {
        Boolean fail = false;
        Boolean itemMissing = false;
        List<String> bodies = new List<String>();

        // True when some request contained the operation and the text
        Boolean sent(String operation, String text) {
            for (String b : bodies) if (b.contains(operation) && b.contains(text)) return true;
            return false;
        }

        Integer count(String operation) {
            Integer n = 0;
            for (String b : bodies) if (b.contains(operation)) n++;
            return n;
        }

        public HttpResponse respond(HttpRequest req) {
            String body = req.getBody();
            bodies.add(body);
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (fail) {
                res.setStatusCode(401);
                res.setBody('{"error_message":"Not Authenticated"}');
                return res;
            }
            res.setStatusCode(200);
            Object data;
            if (body.contains('archive_item')) {
                data = new Map<String, Object>{ 'archive_item' => new Map<String, Object>{ 'id' => '888' } };
            } else if (body.contains('change_multiple_column_values')) {
                data = new Map<String, Object>{ 'change_multiple_column_values' => new Map<String, Object>{ 'id' => '555' } };
            } else if (body.contains('move_item_to_group')) {
                data = new Map<String, Object>{ 'move_item_to_group' => new Map<String, Object>{ 'id' => '555' } };
            } else if (body.contains('items (ids')) {
                data = new Map<String, Object>{ 'items' => itemMissing ? new List<Object>() : new List<Object>{
                    new Map<String, Object>{ 'id' => '555', 'state' => 'active',
                        'group' => new Map<String, Object>{ 'id' => 'topics' } } } };
            } else if (body.contains('create_group')) {
                data = new Map<String, Object>{ 'create_group' => new Map<String, Object>{ 'id' => 'new_group' } };
            } else if (body.contains('users (emails')) {
                data = new Map<String, Object>{ 'users' => new List<Object>{ new Map<String, Object>{ 'id' => '77' } } };
            } else if (body.contains('create_item')) {
                data = new Map<String, Object>{ 'create_item' => new Map<String, Object>{
                    'id' => '555', 'url' => 'https://dallaserf.monday.com/boards/123/pulses/555' } };
            } else if (body.contains('create_column')) {
                data = new Map<String, Object>{ 'create_column' => new Map<String, Object>{
                    'id' => body.contains('long_text') ? 'long_text_new' : 'link_new' } };
            } else if (body.contains('boards (ids')) {
                data = new Map<String, Object>{ 'boards' => new List<Object>{ boardJson() } };
            } else if (body.contains('boards (limit')) {
                data = new Map<String, Object>{
                    'me' => new Map<String, Object>{ 'id' => '1', 'name' => 'Jody' },
                    'boards' => new List<Object>{
                        new Map<String, Object>{ 'id' => '9', 'name' => 'Shared', 'type' => 'board',
                            'owners' => new List<Object>{ new Map<String, Object>{ 'id' => '2' } } },
                        new Map<String, Object>{ 'id' => '8', 'name' => 'Subitems of Mine', 'type' => 'sub_items_board',
                            'owners' => new List<Object>{ new Map<String, Object>{ 'id' => '1' } } },
                        new Map<String, Object>{ 'id' => '123', 'name' => 'Mine', 'type' => 'board',
                            'owners' => new List<Object>{ new Map<String, Object>{ 'id' => '1' } } }
                    }
                };
            } else {
                data = new Map<String, Object>{ 'me' => new Map<String, Object>{ 'id' => '1', 'name' => 'Jody' } };
            }
            res.setBody(JSON.serialize(new Map<String, Object>{ 'data' => data }));
            return res;
        }
    }

    private static Map<String, Object> boardJson() {
        return new Map<String, Object>{
            'id' => '123', 'name' => 'Mine', 'url' => 'https://dallaserf.monday.com/boards/123',
            'groups' => new List<Object>{
                new Map<String, Object>{ 'id' => 'topics', 'title' => 'This Week' },
                new Map<String, Object>{ 'id' => 'goal_grp', 'title' => '  technology support |  user support ' }
            },
            'columns' => new List<Object>{
                column('status', 'Status', 'status', new Map<String, Object>{ '0' => 'Working on it', '1' => 'Done', '5' => '' }),
                column('priority', 'Priority', 'status', new Map<String, Object>{ '0' => 'High', '1' => 'Medium', '2' => 'Low' }),
                column('date4', 'Due date', 'date', null),
                column('mos', 'Measure of Success', 'long_text', null),
                column('mgr', 'Manager', 'people', null),
                column('person', 'Owner', 'people', null)
            }
        };
    }

    private static Map<String, Object> column(String id, String title, String type, Map<String, Object> labels) {
        return new Map<String, Object>{
            'id' => id, 'title' => title, 'type' => type,
            'settings_str' => labels == null ? '{}' : JSON.serialize(new Map<String, Object>{ 'labels' => labels })
        };
    }

    @TestSetup
    static void setup() {
        insert new Task(Subject = 'Monday test', Kanban_Status__c = 'In Progress', Status = 'In Progress',
                        Priority = 'High', ActivityDate = Date.newInstance(2026, 11, 3),
                        Description = 'Details');
        Initiative__c goal = new Initiative__c(Initiative_Name__c = 'Technology Support | User Support');
        insert goal;
        insert new Task(Subject = 'Goal task', Kanban_Status__c = 'Queue', Status = 'Not Started',
                        Priority = 'Normal', Smart_Goal__c = goal.Id);
        // Set up here, not in each test: DML in the test body would block the later callout
        insertBoard();
    }

    @IsTest
    static void connectBoardDetectsAndAddsColumns() {
        MondayMock mock = new MondayMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        MondayService.MondayContext ctx = MondayController.connectMondayBoard('123');
        Test.stopTest();

        Monday_Board__c rec = MondayService.getMyBoard();
        Assert.areEqual('123', rec.Board_Id__c);
        Assert.areEqual('status', rec.Status_Column_Id__c);
        Assert.areEqual('priority', rec.Priority_Column_Id__c);
        Assert.areEqual('date4', rec.Date_Column_Id__c);
        Assert.areEqual('long_text_new', rec.Description_Column_Id__c, 'Measure of Success is not reused as Description');
        Assert.areEqual('link_new', rec.Link_Column_Id__c);
        Assert.areEqual('person', rec.Owner_Column_Id__c, 'Owner column chosen, not Manager');
        Assert.isFalse(rec.Status_Labels__c.contains('""'), 'blank labels are dropped');
        Assert.areEqual(2, ctx.groups.size());
        Assert.areEqual('topics', ctx.groups[0].value);
    }

    @IsTest
    static void createItemLinksTask() {
        MondayMock mock = new MondayMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task WHERE Subject = 'Monday test' LIMIT 1];

        Test.startTest();
        MondayController.createMondayItem(t.Id, 'topics');
        Test.stopTest();

        t = [SELECT Monday_Item_Id__c, Monday_Item_URL__c, Monday_Sync_Status__c, Monday_Board_Id__c FROM Task WHERE Id = :t.Id];
        Assert.areEqual('555', t.Monday_Item_Id__c);
        Assert.areEqual('Synced', t.Monday_Sync_Status__c);
        Assert.areEqual('123', t.Monday_Board_Id__c);
        String sent = '';
        for (String b : mock.bodies) if (b.contains('create_item')) sent = b;
        Assert.isTrue(sent.contains('Working on it'), 'status label mapped');
        Assert.isTrue(sent.contains('High'), 'priority label mapped');
        Assert.isTrue(sent.contains('2026-11-03'), 'due date sent');
        Assert.areEqual('topics', MondayService.getMyBoard().Default_Group_Id__c);
    }

    @IsTest
    static void createItemFailureKeepsTaskAndRecordsError() {
        MondayMock mock = new MondayMock();
        mock.fail = true;
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task WHERE Subject = 'Monday test' LIMIT 1];

        Test.startTest();
        MondayService.createItemForTask(t.Id, 'topics');
        Test.stopTest();

        t = [SELECT Monday_Item_Id__c, Monday_Sync_Status__c, Monday_Sync_Error__c FROM Task WHERE Id = :t.Id];
        Assert.isNull(t.Monday_Item_Id__c);
        Assert.areEqual('Error', t.Monday_Sync_Status__c);
        Assert.areEqual('Not Authenticated', t.Monday_Sync_Error__c);
    }

    @IsTest
    static void contextReportsNotConnected() {
        MondayMock mock = new MondayMock();
        mock.fail = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        MondayService.MondayContext ctx = MondayService.getContext();
        Test.stopTest();

        Assert.isFalse(ctx.connected);
        Assert.isNotNull(ctx.error);
    }

    @IsTest
    static void contextLoadsBoardGroups() {
        Test.setMock(HttpCalloutMock.class, new MondayMock());

        Test.startTest();
        MondayService.MondayContext ctx = MondayController.getMondayContext();
        Test.stopTest();

        Assert.isTrue(ctx.connected);
        Assert.areEqual('123', ctx.boardId);
        Assert.areEqual(2, ctx.groups.size());
    }

    @IsTest
    static void syncCreatesItemInGoalGroupAndAssignsOwner() {
        MondayMock mock = new MondayMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task WHERE Subject = 'Goal task' LIMIT 1];

        Test.startTest();
        MondayService.TaskMondayState s = MondayController.syncTaskToMonday(t.Id, true);
        Test.stopTest();

        Assert.isTrue(s.enabled);
        Assert.areEqual('Synced', s.status);
        Assert.areEqual('https://dallaserf.monday.com/boards/123/pulses/555', s.url);
        t = [SELECT Monday_Item_Id__c, Post_To_Monday__c FROM Task WHERE Id = :t.Id];
        Assert.areEqual('555', t.Monday_Item_Id__c);
        Assert.isTrue(t.Post_To_Monday__c, 'choice saved on the task');
        String created = '';
        for (String b : mock.bodies) {
            Assert.isFalse(b.contains('create_group'), 'existing group reused despite case/spacing differences');
            if (b.contains('create_item')) created = b;
        }
        Assert.isTrue(created.contains('goal_grp'), 'posted to the goal group');
        Assert.isTrue(created.contains('personsAndTeams') && created.contains('77'), 'owner assigned');
    }

    @IsTest
    static void syncCreatesMissingGoalGroup() {
        MondayMock mock = new MondayMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task WHERE Subject = 'Goal task' LIMIT 1];
        Initiative__c goal = [SELECT Id FROM Initiative__c LIMIT 1];
        goal.Initiative_Name__c = 'Brand New Goal';
        update goal;

        Test.startTest();
        MondayService.syncTask(t.Id, true);
        Test.stopTest();

        Assert.isTrue(mock.sent('create_group', 'Brand New Goal'), 'missing goal group is created');
        Assert.isTrue(mock.sent('create_item', 'new_group'), 'item posted to the new group');
    }

    @IsTest
    static void syncWithoutGoalUsesNoGoalGroup() {
        MondayMock mock = new MondayMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task WHERE Subject = 'Monday test' LIMIT 1];

        Test.startTest();
        MondayService.syncTask(t.Id, true);
        Test.stopTest();

        Assert.isTrue(mock.sent('create_group', MondayService.NO_GOAL_GROUP));
        Assert.isTrue(mock.sent('create_item', 'new_group'));
    }

    @IsTest
    static void syncUpdatesLinkedItemAndMovesGroup() {
        MondayMock mock = new MondayMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task WHERE Subject = 'Goal task' LIMIT 1];
        update new Task(Id = t.Id, Monday_Item_Id__c = '555', Monday_Board_Id__c = '123', Post_To_Monday__c = true,
                        Subject = 'Renamed task');

        Test.startTest();
        MondayService.TaskMondayState s = MondayService.syncTask(t.Id, true);
        Test.stopTest();

        Assert.areEqual('Synced', s.status);
        Assert.isFalse(mock.sent('create_item', ''), 'linked item is updated, not duplicated');
        Assert.isTrue(mock.sent('change_multiple_column_values', 'Renamed task'), 'name and columns updated');
        Assert.isTrue(mock.sent('move_item_to_group', 'goal_grp'), 'moved from This Week to the goal group');
    }

    @IsTest
    static void syncRecreatesItemDeletedInMonday() {
        MondayMock mock = new MondayMock();
        mock.itemMissing = true;
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task WHERE Subject = 'Goal task' LIMIT 1];
        update new Task(Id = t.Id, Monday_Item_Id__c = '999', Monday_Board_Id__c = '123', Post_To_Monday__c = true);

        Test.startTest();
        MondayService.syncTask(t.Id, true);
        Test.stopTest();

        Assert.isTrue(mock.sent('create_item', 'goal_grp'));
        Assert.areEqual('555', [SELECT Monday_Item_Id__c FROM Task WHERE Id = :t.Id].Monday_Item_Id__c);
    }

    @IsTest
    static void syncOffSavesChoiceWithoutCallouts() {
        MondayMock mock = new MondayMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task WHERE Subject = 'Goal task' LIMIT 1];
        update new Task(Id = t.Id, Post_To_Monday__c = true);

        Test.startTest();
        MondayService.TaskMondayState s = MondayController.syncTaskToMonday(t.Id, false);
        Test.stopTest();

        Assert.isFalse(s.enabled);
        Assert.areEqual(0, mock.bodies.size(), 'nothing sent to Monday');
        Assert.isFalse([SELECT Post_To_Monday__c FROM Task WHERE Id = :t.Id].Post_To_Monday__c);
        Assert.isFalse(MondayController.getTaskMondayState(t.Id).enabled);
    }

    @IsTest
    static void syncRecordsNotConnectedWhenOwnerHasNoBoard() {
        Test.setMock(HttpCalloutMock.class, new MondayMock());
        delete [SELECT Id FROM Monday_Board__c];
        Task t = [SELECT Id FROM Task WHERE Subject = 'Goal task' LIMIT 1];

        MondayService.TaskMondayState s = MondayService.syncTask(t.Id, true);

        Assert.areEqual('Not Connected', s.status);
        Assert.isNotNull(s.error);
    }

    @IsTest
    static void syncFailureIsRecordedNotThrown() {
        MondayMock mock = new MondayMock();
        mock.fail = true;
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task WHERE Subject = 'Goal task' LIMIT 1];

        Test.startTest();
        MondayService.TaskMondayState s = MondayService.syncTask(t.Id, true);
        Test.stopTest();

        Assert.areEqual('Error', s.status);
        Assert.areEqual('Not Authenticated', s.error);
    }

    @IsTest
    static void syncPostsOneItemPerGoal() {
        MondayMock mock = new MondayMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id, Smart_Goal__c FROM Task WHERE Subject = 'Goal task' LIMIT 1];
        Initiative__c second = new Initiative__c(Initiative_Name__c = 'Second Goal');
        insert second;
        insert new List<Task_Smart_Goal__c>{
            new Task_Smart_Goal__c(Task__c = t.Id, Smart_Goal__c = t.Smart_Goal__c),
            new Task_Smart_Goal__c(Task__c = t.Id, Smart_Goal__c = second.Id)
        };

        Test.startTest();
        MondayService.TaskMondayState s = MondayService.syncTask(t.Id, true);
        Test.stopTest();

        Assert.areEqual('Synced', s.status);
        Assert.areEqual(2, mock.count('create_item'), 'one item per goal (primary not duplicated)');
        Assert.isTrue(mock.sent('create_item', 'goal_grp'), 'item in the existing goal group');
        Assert.isTrue(mock.sent('create_group', 'Second Goal'), 'group created for the second goal');
        Assert.isTrue(mock.sent('create_item', 'new_group'), 'item in the second goal group');
        Assert.areEqual(2, [SELECT COUNT() FROM Monday_Item_Link__c WHERE Task_Id__c = :t.Id]);
        Assert.areEqual(2, s.items.size());
        Assert.areEqual('Technology Support | User Support', s.items[0].goal);
    }

    @IsTest
    static void syncArchivesItemsForRemovedGoals() {
        MondayMock mock = new MondayMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task WHERE Subject = 'Goal task' LIMIT 1];
        Initiative__c removed = new Initiative__c(Initiative_Name__c = 'Removed Goal');
        insert removed;
        insert new Monday_Item_Link__c(Task_Id__c = t.Id, Goal__c = removed.Id, Board_Id__c = '123', Item_Id__c = '888');

        Test.startTest();
        MondayService.syncTask(t.Id, true);
        Test.stopTest();

        Assert.isTrue(mock.sent('archive_item', '888'), 'item for the removed goal is archived');
        List<Monday_Item_Link__c> links = [SELECT Goal__c FROM Monday_Item_Link__c WHERE Task_Id__c = :t.Id];
        Assert.areEqual(1, links.size(), 'only the current goal keeps a link');
        Assert.areNotEqual(removed.Id, links[0].Goal__c);
    }

    @IsTest
    static void prefsDefaultOnAndCanBeTurnedOff() {
        MondayService.MondayPrefs p = MondayController.getMondayPrefs();
        Assert.isTrue(p.hasBoard);
        Assert.isTrue(p.postByDefault, 'new boards default to posting');
        p = MondayController.setMondayPostByDefault(false);
        Assert.isFalse(p.postByDefault);
        Assert.isFalse(MondayController.getMondayPrefs().postByDefault);

        delete [SELECT Id FROM Monday_Board__c];
        Assert.isFalse(MondayController.getMondayPrefs().hasBoard);
        Boolean threw = false;
        try { MondayController.setMondayPostByDefault(true); } catch (AuraHandledException e) { threw = true; }
        Assert.isTrue(threw, 'no board to save the preference on');
    }

    @IsTest
    static void myBoardsListsOwnedFirstAndSkipsSubitems() {
        Test.setMock(HttpCalloutMock.class, new MondayMock());

        Test.startTest();
        List<MondayService.Option> boards = MondayController.getMyMondayBoards();
        Test.stopTest();

        Assert.areEqual(2, boards.size());
        Assert.areEqual('123', boards[0].value);
        Assert.areEqual('9', boards[1].value);
    }

    @IsTest
    static void controllerReturnsReadableErrors() {
        MondayMock mock = new MondayMock();
        mock.fail = true;
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task WHERE Subject = 'Monday test' LIMIT 1];

        Test.startTest();
        List<String> messages = new List<String>();
        try { MondayController.connectMondayBoard(' '); } catch (AuraHandledException e) { messages.add(e.getMessage()); }
        try { MondayController.getMyMondayBoards(); } catch (AuraHandledException e) { messages.add(e.getMessage()); }
        try { MondayController.createMondayItem(t.Id, ''); } catch (AuraHandledException e) { messages.add(e.getMessage()); }
        Test.stopTest();

        Assert.areEqual(3, messages.size(), 'each failure surfaces as an AuraHandledException');
    }

    @IsTest
    static void matchLabelIsCaseInsensitive() {
        Assert.areEqual('Done', MondayService.matchLabel(new List<String>{ 'done' }, '["Working on it","Done"]'));
        Assert.isNull(MondayService.matchLabel(new List<String>{ 'Stuck' }, '["Done"]'));
        Assert.isNull(MondayService.matchLabel(null, '["Done"]'));
    }

    private static void insertBoard() {
        insert new Monday_Board__c(
            Name = 'Mine', Board_Id__c = '123',
            Status_Column_Id__c = 'status', Priority_Column_Id__c = 'priority', Date_Column_Id__c = 'date4',
            Description_Column_Id__c = 'long_text_new', Link_Column_Id__c = 'link_new', Owner_Column_Id__c = 'person',
            Status_Labels__c = '["Working on it","Done"]', Priority_Labels__c = '["High","Medium","Low"]'
        );
    }
}
