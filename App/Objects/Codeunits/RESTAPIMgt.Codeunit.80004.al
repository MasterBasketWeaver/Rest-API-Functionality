codeunit 79990 "BAAPI REST API Mgt."
{
    procedure GetResponseAsJsonToken(Method: Text; URL: Text; TokenName: Text): Variant
    var
        JsonBody: JsonObject;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
    begin
        exit(GetResponseAsJsonToken(Method, URL, TokenName, JsonBody, RequestHeaders, ContentHeaders));
    end;

    procedure GetResponseAsJsonToken(Method: Text; URL: Text; TokenName: Text; JsonBody: JsonObject; var RequestHeaders: HttpHeaders; var ContentHeaders: HttpHeaders): Variant
    var
        ResponseText: Text;
        JsonObj: JsonObject;
        JsonTkn: JsonToken;
        Sent: Boolean;
    begin
        if JsonBody.Keys.Count() > 0 then
            Sent := SendRequestWithJsonBody(Method, URL, JsonBody, ResponseText, RequestHeaders, ContentHeaders)
        else
            Sent := SendRequest(Method, URL, ResponseText, RequestHeaders, ContentHeaders);
        if not Sent then
            Error(ResponseText);
        JsonObj.ReadFrom(ResponseText);
        if not JsonObj.Get(TokenName, JsonTkn) then begin
            JsonObj.WriteTo(ResponseText);
            // if ResponseText.Contains('"result":"error"') then
            //     Error(ResponseText);
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
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
    begin
        exit(GetResponseAsJsonArray(URL, TokenName, Method, JsonBody, RequestHeaders, ContentHeaders));
    end;

    procedure GetResponseAsJsonArray(URL: Text; TokenName: Text; Method: Text; var JsonBody: JsonObject; var RequestHeaders: HttpHeaders; var ContentHeaders: HttpHeaders): Variant
    var
        ResponseText: Text;
        JsonObj: JsonObject;
        JsonArry: JsonArray;
        JsonTkn: JsonToken;
        Result, Sent : Boolean;
    begin
        if JsonBody.Keys.Count() > 0 then
            Sent := SendRequestWithJsonBody(Method, URL, JsonBody, ResponseText, RequestHeaders, ContentHeaders)
        else
            Sent := SendRequest(Method, URL, ResponseText, RequestHeaders, ContentHeaders);
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
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
    begin
        exit(SendRequestWithJsonBody(Method, URL, JsonObj, ResponseText, RequestHeaders, ContentHeaders));
    end;

    local procedure SendRequestWithJsonBody(Method: Text; URL: Text; var JsonObj: JsonObject; var ResponseText: Text; var RequestHeaders: HttpHeaders; var ContentHeaders: HttpHeaders): Boolean
    var
        Content: HttpContent;
        s: Text;
    begin
        JsonObj.WriteTo(s);
        Content.WriteFrom(s);
        exit(SendRequest(Method, URL, ResponseText, Content, StrLen(s), RequestHeaders, ContentHeaders));
    end;

    local procedure SendRequest(Method: Text; URL: Text; var ResponseText: Text): Boolean
    var
        Content: HttpContent;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
    begin
        exit(SendRequest(Method, URL, ResponseText, Content, 0, RequestHeaders, ContentHeaders));
    end;

    local procedure SendRequest(Method: Text; URL: Text; var ResponseText: Text; var RequestHeaders: HttpHeaders; var ContentHeaders: HttpHeaders): Boolean
    var
        Content: HttpContent;
    begin
        exit(SendRequest(Method, URL, ResponseText, Content, 0, RequestHeaders, ContentHeaders));
    end;

    local procedure SendRequest(Method: Text; URL: Text; var ResponseText: Text; var Content: HttpContent; ContentLength: Integer; var NewRequestHeaders: HttpHeaders; var NewContentHeaders: HttpHeaders): Boolean
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        Values: List of [Text];
        HeaderKey: Text;
    begin
        HttpRequestMessage.SetRequestUri(URL);
        HttpRequestMessage.Method(Method);

        if NewRequestHeaders.Keys().Count() > 0 then begin
            HttpRequestMessage.GetHeaders(RequestHeaders);
            foreach HeaderKey in NewRequestHeaders.Keys() do begin
                if RequestHeaders.Contains(HeaderKey) then
                    RequestHeaders.Remove(HeaderKey);
                RequestHeaders.GetValues(HeaderKey, Values);
                RequestHeaders.Add(HeaderKey, Values.Get(1));
            end;
        end;

        if ContentLength > 0 then begin
            HttpRequestMessage.Content(Content);
            if NewContentHeaders.Keys().Count() > 0 then begin
                Content.GetHeaders(ContentHeaders);
                foreach HeaderKey in NewContentHeaders.Keys() do begin
                    if ContentHeaders.Contains(HeaderKey) then
                        ContentHeaders.Remove(HeaderKey);
                    ContentHeaders.GetValues(HeaderKey, Values);
                    ContentHeaders.Add(HeaderKey, Values.Get(1));
                end;
            end;
            if ContentHeaders.Contains('Content-Length') then
                ContentHeaders.Remove('Content-Length');
            ContentHeaders.Add('Content-Length', Format(ContentLength));
        end;

        if not HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
            ResponseText := StrSubstNo(UnableToSendRequestMsg, GetLastErrorText());
            exit(false);
        end;

        HttpResponseMessage.Content().ReadAs(ResponseText);
        if not HttpResponseMessage.IsSuccessStatusCode() then begin
            if ResponseText = '' then
                ResponseText := StrSubstNo('%1 - %2', HttpResponseMessage.HttpStatusCode(), HttpResponseMessage.ReasonPhrase());
            exit(false);
        end;
        exit(true);
    end;


    var
        TokenMisserErr: Label 'Token %1 not found in response:\%2', Comment = '%1 = Token Name, %2 = Response Text';
        UnableToSendRequestMsg: Label 'Unable to send request:\%1', Comment = '%1 = Error Text';
}