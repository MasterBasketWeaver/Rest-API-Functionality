codeunit 79990 "BAAPI REST API Mgt."
{
    procedure GetResponseAsJsonToken(Method: Text; URL: Text; TokenName: Text): Variant
    var
        JsonBody: JsonObject;
    begin
        exit(GetResponseAsJsonToken(Method, URL, TokenName, JsonBody));
    end;

    procedure GetResponseAsJsonToken(Method: Text; URL: Text; TokenName: Text; JsonBody: JsonObject): Variant
    var
        ResponseText: Text;
        JsonObj: JsonObject;
        JsonTkn: JsonToken;
        Sent: Boolean;
    begin
        if JsonBody.Keys.Count() > 0 then
            Sent := SendRequestWithJsonBody(Method, URL, JsonBody, ResponseText)
        else
            Sent := SendRequest(Method, URL, ResponseText);
        if not Sent then
            Error(ResponseText);
        JsonObj.ReadFrom(ResponseText);
        if not JsonObj.Get(TokenName, JsonTkn) then begin
            JsonObj.WriteTo(ResponseText);
            if ResponseText.Contains('"result":"error"') then
                Error(ResponseText);
            Error(TokenMisserErr, TokenName, ResponseText);
        end;
        exit(JsonTkn);
    end;


    procedure GetResponseAsJsonArray(URL: Text; TokenName: Text): Variant
    var
        JsonBody: JsonObject;
    begin
        exit(GetResponseAsJsonArray(URL, TokenName, 'GET', JsonBody));
    end;

    [TryFunction]
    procedure TryToGetResponseAsJsonArray(URL: Text; TokenName: Text; Method: Text; var JsonBody: JsonObject; var ResponseArray: JsonArray)
    begin
        ResponseArray := GetResponseAsJsonArray(URL, TokenName, Method, JsonBody);
    end;

    procedure GetResponseAsJsonArray(URL: Text; TokenName: Text; Method: Text; var JsonBody: JsonObject): Variant
    var
        ResponseText: Text;
        JsonObj: JsonObject;
        JsonArry: JsonArray;
        JsonTkn: JsonToken;
        Result, Sent : Boolean;
    begin
        if JsonBody.Keys.Count() > 0 then
            Sent := SendRequestWithJsonBody(Method, URL, JsonBody, ResponseText)
        else
            Sent := SendRequest(Method, URL, ResponseText);
        if not Sent then
            Error(ResponseText);

        JsonObj.ReadFrom(ResponseText);
        if not JsonObj.Get(TokenName, JsonTkn) then begin
            JsonObj.WriteTo(ResponseText);
            if ResponseText.Contains('"result":"error"') then
                Error(ResponseText);
            Error(TokenMisserErr, TokenName, ResponseText);
        end;
        JsonArry := JsonTkn.AsArray();
        exit(JsonArry);
    end;

    local procedure SendRequestWithJsonBody(Method: Text; URL: Text; var JsonObj: JsonObject; var ResponseText: Text): Boolean
    var
        Content: HttpContent;
        s: Text;
    begin
        JsonObj.WriteTo(s);
        Content.WriteFrom(s);
        exit(SendRequest(Method, URL, ResponseText, Content, StrLen(s)));
    end;

    local procedure SendRequest(Method: Text; URL: Text; var ResponseText: Text): Boolean
    var
        Content: HttpContent;
    begin
        exit(SendRequest(Method, URL, ResponseText, Content, 0));
    end;

    local procedure SendRequest(Method: Text; URL: Text; var ResponseText: Text; var Content: HttpContent; ContentLength: Integer): Boolean
    var
        HttpClient: HttpClient;
        Headers: HttpHeaders;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
    begin
        HttpRequestMessage.SetRequestUri(URL);
        HttpRequestMessage.Method(Method);

        if (Method <> 'GET') and (ContentLength > 0) then begin
            HttpRequestMessage.Content(Content);
            Content.GetHeaders(Headers);
            if Headers.Contains('Content-Type') then
                Headers.Remove('Content-Type');
            Headers.Add('Content-Type', 'application/json');
            if Headers.Contains('Content-Length') then
                Headers.Remove('Content-Length');
            Headers.Add('Content-Length', Format(ContentLength));
        end;


        if not HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            ResponseText := StrSubstNo(UnableToSendRequestMsg, GetLastErrorText());
            exit(false);
        end;

        HttpResponseMessage.Content().ReadAs(ResponseText);
        exit(HttpResponseMessage.IsSuccessStatusCode());
    end;


    var
        TokenMisserErr: Label 'Token %1 not found in response:\%2', Comment = '%1 = Token Name, %2 = Response Text';
        UnableToSendRequestMsg: Label 'Unable to send request:\%1', Comment = '%1 = Error Text';
}