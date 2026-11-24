/**
 * Thin GraphQL client for the Monday.com API.
 * Every call goes through the "Monday" Named Credential, which uses the shared "Service" principal of the
 * "Monday" External Credential. The API token is entered in Setup on that principal and merged into the
 * Authorization header by Salesforce, so no tokens or secrets live in code or metadata.
 */
public with sharing class MondayApiClient {

    private static final String ENDPOINT    = 'callout:Monday';
    private static final String API_VERSION = '2025-04';
    private static final String AUTH_HEADER = '{!$Credential.Monday.Token}';

    public class MondayException extends Exception {}

    // Posts a GraphQL query/mutation and returns the "data" node; throws on any API error.
    public static Map<String, Object> query(String gql, Map<String, Object> variables) {
        Map<String, Object> body = new Map<String, Object>{ 'query' => gql };
        if (variables != null) body.put('variables', variables);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('API-Version', API_VERSION);
        // Salesforce substitutes the saved principal token server-side (Named Credential allows header merge fields).
        // The External Credential's own custom header was not being applied, so the header is set here instead.
        req.setHeader('Authorization', AUTH_HEADER);
        req.setTimeout(30000);
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        Map<String, Object> parsed;
        try {
            parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } catch (Exception e) {
            throw new MondayException('Monday.com returned HTTP ' + res.getStatusCode() + '.');
        }
        if (res.getStatusCode() != 200 || parsed.containsKey('errors') || parsed.containsKey('error_message')) {
            throw new MondayException(errorMessage(res.getStatusCode(), parsed));
        }
        return (Map<String, Object>) parsed.get('data');
    }

    // The authenticated Monday user plus the active boards they can see, in one round trip
    public static Map<String, Object> getMeAndBoards() {
        return query(
            'query { me { id name email } ' +
            'boards (limit: 200, state: active, order_by: used_at) { id name url type owners { id } } }',
            null
        );
    }

    public static Map<String, Object> getMe() {
        return (Map<String, Object>) query('query { me { id name email } }', null).get('me');
    }

    // Board with its groups and columns; null when the board is missing or not shared with the user
    public static Map<String, Object> getBoard(String boardId) {
        Map<String, Object> data = query(
            'query ($ids: [ID!]) { boards (ids: $ids) { id name url ' +
            'groups { id title } columns { id title type settings_str } } }',
            new Map<String, Object>{ 'ids' => new List<String>{ boardId } }
        );
        List<Object> boards = (List<Object>) data.get('boards');
        return (boards == null || boards.isEmpty()) ? null : (Map<String, Object>) boards[0];
    }

    // Returns { id, url } of the new item
    public static Map<String, Object> createItem(String boardId, String groupId, String itemName, String columnValuesJson) {
        Map<String, Object> data = query(
            'mutation ($board: ID!, $group: String!, $name: String!, $values: JSON) { ' +
            'create_item (board_id: $board, group_id: $group, item_name: $name, column_values: $values) { id url } }',
            new Map<String, Object>{
                'board'  => boardId,
                'group'  => groupId,
                'name'   => itemName,
                'values' => columnValuesJson
            }
        );
        return (Map<String, Object>) data.get('create_item');
    }

    // Sets several columns at once; the 'name' key renames the item
    public static void updateItem(String boardId, String itemId, String columnValuesJson) {
        query(
            'mutation ($board: ID!, $item: ID!, $values: JSON!) { ' +
            'change_multiple_column_values (board_id: $board, item_id: $item, column_values: $values) { id } }',
            new Map<String, Object>{ 'board' => boardId, 'item' => itemId, 'values' => columnValuesJson }
        );
    }

    // The item's current group Id, or null when the item no longer exists (deleted/archived in Monday)
    public static String getItemGroupId(String itemId) {
        Map<String, Object> data = query(
            'query ($ids: [ID!]) { items (ids: $ids) { id state group { id } } }',
            new Map<String, Object>{ 'ids' => new List<String>{ itemId } }
        );
        List<Object> items = (List<Object>) data.get('items');
        if (items == null || items.isEmpty()) return null;
        Map<String, Object> item = (Map<String, Object>) items[0];
        if (item.get('state') != null && item.get('state') != 'active') return null;
        Map<String, Object> grp = (Map<String, Object>) item.get('group');
        return grp == null ? null : (String) grp.get('id');
    }

    public static void moveItemToGroup(String itemId, String groupId) {
        query(
            'mutation ($item: ID!, $group: String!) { move_item_to_group (item_id: $item, group_id: $group) { id } }',
            new Map<String, Object>{ 'item' => itemId, 'group' => groupId }
        );
    }

    // Returns the new group's Id
    public static String createGroup(String boardId, String groupName) {
        Map<String, Object> data = query(
            'mutation ($board: ID!, $name: String!) { create_group (board_id: $board, group_name: $name) { id } }',
            new Map<String, Object>{ 'board' => boardId, 'name' => groupName }
        );
        return (String) ((Map<String, Object>) data.get('create_group')).get('id');
    }

    // Monday user Id for an email address, or null when no Monday user has that email
    public static String findUserIdByEmail(String email) {
        if (String.isBlank(email)) return null;
        Map<String, Object> data = query(
            'query ($emails: [String]) { users (emails: $emails) { id email } }',
            new Map<String, Object>{ 'emails' => new List<String>{ email } }
        );
        List<Object> users = (List<Object>) data.get('users');
        return (users == null || users.isEmpty()) ? null : String.valueOf(((Map<String, Object>) users[0]).get('id'));
    }

    // columnType is a Monday ColumnType enum value, e.g. 'long_text' or 'link'; returns the new column Id
    public static String createColumn(String boardId, String title, String columnType) {
        Map<String, Object> data = query(
            'mutation ($board: ID!, $title: String!, $type: ColumnType!) { ' +
            'create_column (board_id: $board, title: $title, column_type: $type) { id } }',
            new Map<String, Object>{ 'board' => boardId, 'title' => title, 'type' => columnType }
        );
        return (String) ((Map<String, Object>) data.get('create_column')).get('id');
    }

    private static String errorMessage(Integer statusCode, Map<String, Object> parsed) {
        if (parsed.get('error_message') != null) return String.valueOf(parsed.get('error_message'));
        Object errors = parsed.get('errors');
        if (errors instanceof List<Object> && !((List<Object>) errors).isEmpty()) {
            Object first = ((List<Object>) errors)[0];
            if (first instanceof Map<String, Object>) {
                return String.valueOf(((Map<String, Object>) first).get('message'));
            }
        }
        return 'Monday.com returned HTTP ' + statusCode + '.';
    }
}
