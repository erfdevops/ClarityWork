/**
 * Thin GraphQL client for the Monday.com API.
 * Every call goes through the "Monday" Named Credential (per-user OAuth via the
 * "Monday" External Credential), so no tokens or secrets live in code or metadata.
 */
public with sharing class MondayApiClient {

    private static final String ENDPOINT    = 'callout:Monday';
    private static final String API_VERSION = '2025-04';

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
