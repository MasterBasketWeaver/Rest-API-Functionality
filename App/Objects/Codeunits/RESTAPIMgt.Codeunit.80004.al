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
        ResponseObj: JsonObject;
        JsonTkn: JsonToken;
        ErrorText, ResponseText : Text;
    begin
        if not TryGetResponseAsJsonToken(Method, URL, TokenName, JsonBody, RequestHeaders, ContentHeaders, JsonTkn, ResponseObj, ResponseText, ErrorText) then
            Error(ErrorText);
        exit(JsonTkn);
    end;

    /// <summary>
    /// Non-throwing overload. Returns false and populates ErrorText instead of raising an error,
    /// so the caller can log or otherwise handle the failure. ResponseText holds the raw response
    /// body on both success and failure; ResponseObj holds the full parsed response.
    /// </summary>
    procedure TryGetResponseAsJsonToken(Method: Text; URL: Text; TokenName: Text; JsonBody: JsonObject; var RequestHeaders: HttpHeaders; var ContentHeaders: HttpHeaders; var JsonTkn: JsonToken; var ResponseObj: JsonObject; var ResponseText: Text; var ErrorText: Text): Boolean
    var
        TokenText: Text;
    begin
        Clear(JsonTkn);
        if not TrySendAndParse(Method, URL, JsonBody, RequestHeaders, ContentHeaders, ResponseObj, ResponseText, ErrorText) then
            exit(false);
        if not ResponseObj.Get(TokenName, JsonTkn) then begin
            ResponseObj.WriteTo(TokenText);
            ErrorText := StrSubstNo(TokenMisserErr, TokenName, TokenText);
            exit(false);
        end;
        exit(true);
    end;


    /// <summary>
    /// Returns the complete response body as a JsonObject, for endpoints whose payload is not
    /// wrapped in a named token. Raises an error on failure.
    /// </summary>
    procedure GetResponseAsJsonObject(Method: Text; URL: Text; var JsonBody: JsonObject): Variant
    var
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
    begin
        exit(GetResponseAsJsonObject(Method, URL, JsonBody, RequestHeaders, ContentHeaders));
    end;

    procedure GetResponseAsJsonObject(Method: Text; URL: Text; var JsonBody: JsonObject; var RequestHeaders: HttpHeaders; var ContentHeaders: HttpHeaders): Variant
    var
        ResponseObj: JsonObject;
        ErrorText, ResponseText : Text;
    begin
        if not TryGetResponseAsJsonObject(Method, URL, JsonBody, RequestHeaders, ContentHeaders, ResponseObj, ResponseText, ErrorText) then
            Error(ErrorText);
        exit(ResponseObj);
    end;

    /// <summary>
    /// Non-throwing overload of GetResponseAsJsonObject. See TryGetResponseAsJsonToken.
    /// </summary>
    procedure TryGetResponseAsJsonObject(Method: Text; URL: Text; var JsonBody: JsonObject; var RequestHeaders: HttpHeaders; var ContentHeaders: HttpHeaders; var ResponseObj: JsonObject; var ResponseText: Text; var ErrorText: Text): Boolean
    begin
        exit(TrySendAndParse(Method, URL, JsonBody, RequestHeaders, ContentHeaders, ResponseObj, ResponseText, ErrorText));
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
        ResponseObj: JsonObject;
        JsonArry: JsonArray;
        ErrorText, ResponseText : Text;
    begin
        if not TryGetResponseAsJsonArray(Method, URL, TokenName, JsonBody, RequestHeaders, ContentHeaders, JsonArry, ResponseObj, ResponseText, ErrorText) then
            Error(ErrorText);
        exit(JsonArry);
    end;

    /// <summary>
    /// Non-throwing overload. Returns false and populates ErrorText instead of raising an error,
    /// so the caller can log or otherwise handle the failure. ResponseText holds the raw response
    /// body on both success and failure; ResponseObj holds the full parsed response.
    /// </summary>
    procedure TryGetResponseAsJsonArray(Method: Text; URL: Text; TokenName: Text; var JsonBody: JsonObject; var RequestHeaders: HttpHeaders; var ContentHeaders: HttpHeaders; var JsonArry: JsonArray; var ResponseObj: JsonObject; var ResponseText: Text; var ErrorText: Text): Boolean
    var
        JsonTkn: JsonToken;
        TokenText: Text;
    begin
        Clear(JsonArry);
        if not TrySendAndParse(Method, URL, JsonBody, RequestHeaders, ContentHeaders, ResponseObj, ResponseText, ErrorText) then
            exit(false);
        if not ResponseObj.Get(TokenName, JsonTkn) then begin
            ResponseObj.WriteTo(TokenText);
            if TokenText.Contains('"result":"error"') then
                ErrorText := TokenText
            else
                ErrorText := StrSubstNo(TokenMisserErr, TokenName, TokenText);
            exit(false);
        end;
        JsonArry := JsonTkn.AsArray();
        exit(true);
    end;


    /// <summary>
    /// Sends a request and parses the response body as a JsonObject. See TrySendRequest.
    /// </summary>
    procedure TrySendJsonRequest(Method: Text; URL: Text; ContentType: Text; RequestBody: Text; var RequestHeaderValues: Dictionary of [Text, Text]; var ResponseObj: JsonObject; var ResponseText: Text; var ErrorText: Text): Boolean
    begin
        Clear(ResponseObj);
        if not TrySendRequest(Method, URL, ContentType, RequestBody, RequestHeaderValues, ResponseText, ErrorText) then
            exit(false);
        if not ResponseObj.ReadFrom(ResponseText) then begin
            ErrorText := StrSubstNo(UnableToReadResponseErr, ResponseText);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Sends a request and returns the raw response body. Prefer this over the HttpHeaders-based
    /// overloads: request headers are taken as a Dictionary and applied straight to the request
    /// message, so nothing is staged on caller-supplied HttpHeaders. Staging is unsafe, because two
    /// staged HttpHeaders keep separate key lists but share a single value pool - GetValues then
    /// returns another header's value, and BC rejects the request as an invalid HTTP header.
    /// An empty RequestBody sends no content. Never raises; reports failure through ErrorText.
    /// </summary>
    procedure TrySendRequest(Method: Text; URL: Text; ContentType: Text; RequestBody: Text; var RequestHeaderValues: Dictionary of [Text, Text]; var ResponseText: Text; var ErrorText: Text): Boolean
    var
        Client: HttpClient;
        Content: HttpContent;
        RequestMsg: HttpRequestMessage;
        ResponseMsg: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
        HeaderKey: Text;
    begin
        ErrorText := '';
        ResponseText := '';
        RequestMsg.SetRequestUri(URL);
        RequestMsg.Method(Method);
        RequestMsg.GetHeaders(RequestHeaders);
        foreach HeaderKey in RequestHeaderValues.Keys() do begin
            if RequestHeaders.Contains(HeaderKey) then
                RequestHeaders.Remove(HeaderKey);
            RequestHeaders.Add(HeaderKey, RequestHeaderValues.Get(HeaderKey));
        end;
        if RequestBody <> '' then begin
            Content.WriteFrom(RequestBody);
            // content headers must be set before the content is assigned to the request message:
            // assigning copies the content, so anything added afterwards is dropped
            Content.GetHeaders(ContentHeaders);
            if ContentHeaders.Contains('Content-Type') then
                ContentHeaders.Remove('Content-Type');
            if ContentType <> '' then
                ContentHeaders.Add('Content-Type', ContentType);
            RequestMsg.Content(Content);
        end;
        if not Client.Send(RequestMsg, ResponseMsg) then begin
            ErrorText := StrSubstNo(UnableToSendRequestMsg, GetLastErrorText());
            exit(false);
        end;
        ResponseMsg.Content().ReadAs(ResponseText);
        if not ResponseMsg.IsSuccessStatusCode() then begin
            if ResponseText = '' then
                ResponseText := StrSubstNo('%1 - %2', ResponseMsg.HttpStatusCode(), ResponseMsg.ReasonPhrase());
            ErrorText := ResponseText;
            exit(false);
        end;
        exit(true);
    end;


    /// <summary>
    /// Shared send-and-parse core. Never raises; reports failure through ErrorText.
    /// </summary>
    local procedure TrySendAndParse(Method: Text; URL: Text; var JsonBody: JsonObject; var RequestHeaders: HttpHeaders; var ContentHeaders: HttpHeaders; var ResponseObj: JsonObject; var ResponseText: Text; var ErrorText: Text): Boolean
    var
        Sent: Boolean;
    begin
        Clear(ResponseObj);
        ErrorText := '';
        ResponseText := '';
        if JsonBody.Keys.Count() > 0 then
            Sent := SendRequestWithJsonBody(Method, URL, JsonBody, ResponseText, RequestHeaders, ContentHeaders)
        else
            Sent := SendRequest(Method, URL, ResponseText, RequestHeaders, ContentHeaders);
        if not Sent then begin
            ErrorText := ResponseText;
            exit(false);
        end;
        if not ResponseObj.ReadFrom(ResponseText) then begin
            ErrorText := StrSubstNo(UnableToReadResponseErr, ResponseText);
            exit(false);
        end;
        exit(true);
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
                NewRequestHeaders.GetValues(HeaderKey, Values);
                RequestHeaders.Add(HeaderKey, Values.Get(1));
            end;
        end;

        if ContentLength > 0 then begin
            // Content headers must be set before the content is assigned to the request
            // message: assigning copies the content, so any header added afterwards is
            // dropped and the request goes out as text/plain.
            // bound unconditionally: Content-Length below is also a content header, so
            // ContentHeaders must be attached to the content even when no headers were passed in
            Content.GetHeaders(ContentHeaders);
            foreach HeaderKey in NewContentHeaders.Keys() do begin
                if ContentHeaders.Contains(HeaderKey) then
                    ContentHeaders.Remove(HeaderKey);
                NewContentHeaders.GetValues(HeaderKey, Values);
                ContentHeaders.Add(HeaderKey, Values.Get(1));
            end;
            if ContentHeaders.Contains('Content-Length') then
                ContentHeaders.Remove('Content-Length');
            ContentHeaders.Add('Content-Length', Format(ContentLength));
            HttpRequestMessage.Content(Content);
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
        UnableToReadResponseErr: Label 'Unable to read response:\%1', Comment = '%1 = Response Text';
        UnableToSendRequestMsg: Label 'Unable to send request:\%1', Comment = '%1 = Error Text';
}