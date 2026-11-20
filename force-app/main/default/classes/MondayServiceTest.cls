@IsTest
private class MondayServiceTest {

    // Routes each GraphQL request to a canned Monday.com response
    private class MondayMock implements HttpCalloutMock {
        Boolean fail = false;
        List<String> bodies = new List<String>();

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
            if (body.contains('create_item')) {
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
            'groups' => new List<Object>{ new Map<String, Object>{ 'id' => 'topics', 'title' => 'This Week' } },
            'columns' => new List<Object>{
                column('status', 'Status', 'status', new Map<String, Object>{ '0' => 'Working on it', '1' => 'Done', '5' => '' }),
                column('priority', 'Priority', 'status', new Map<String, Object>{ '0' => 'High', '1' => 'Medium', '2' => 'Low' }),
                column('date4', 'Due date', 'date', null)
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
        Assert.areEqual('long_text_new', rec.Description_Column_Id__c);
        Assert.areEqual('link_new', rec.Link_Column_Id__c);
        Assert.isFalse(rec.Status_Labels__c.contains('""'), 'blank labels are dropped');
        Assert.areEqual(1, ctx.groups.size());
        Assert.areEqual('topics', ctx.groups[0].value);
    }

    @IsTest
    static void createItemLinksTask() {
        MondayMock mock = new MondayMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Task t = [SELECT Id FROM Task LIMIT 1];

        Test.startTest();
        MondayController.createMondayItem(t.Id, 'topics');
        Test.stopTest();

        t = [SELECT Monday_Item_Id__c, Monday_Item_URL__c, Monday_Sync_Status__c, Monday_Board_Id__c FROM Task WHERE Id = :t.Id];
        Assert.areEqual('555', t.Monday_Item_Id__c);
        Assert.areEqual('Synced', t.Monday_Sync_Status__c);
        Assert.areEqual('123', t.Monday_Board_Id__c);
        String sent = mock.bodies[0];
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
        Task t = [SELECT Id FROM Task LIMIT 1];

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
        Assert.areEqual(1, ctx.groups.size());
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
        Task t = [SELECT Id FROM Task LIMIT 1];

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
            Description_Column_Id__c = 'long_text_new', Link_Column_Id__c = 'link_new',
            Status_Labels__c = '["Working on it","Done"]', Priority_Labels__c = '["High","Medium","Low"]'
        );
    }
}
